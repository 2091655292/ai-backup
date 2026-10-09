#!/usr/bin/env bash
# Restore a backup produced by scripts/backup.sh.
#
# Usage:
#   scripts/restore.sh --target s3 [--name <artifact>] [--latest]
#
# Target credentials and RESTORE_* destination variables come from the
# environment (same variables as backup.sh).

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
. "$SCRIPT_DIR/lib/common.sh"
# shellcheck source=lib/crypto.sh
. "$SCRIPT_DIR/lib/crypto.sh"

TARGET=""
NAME=""
LATEST=0
CONFIG_FILE=""
while [ $# -gt 0 ]; do
  case "$1" in
    --target) TARGET="$2"; shift 2 ;;
    --name) NAME="$2"; shift 2 ;;
    --latest) LATEST=1; shift ;;
    --config) CONFIG_FILE="$2"; shift 2 ;;
    -h|--help) sed -n '2,10p' "$0"; exit 0 ;;
    *) die "unknown argument: $1" ;;
  esac
done

if [ -n "$CONFIG_FILE" ]; then
  set -a
  # shellcheck disable=SC1090
  . "$CONFIG_FILE"
  set +a
fi

DB_TYPE="${DB_TYPE:?DB_TYPE is required}"
[ -n "$TARGET" ] || die "--target is required"

make_workdir

load_target() {
  local file="$SCRIPT_DIR/targets/${1}.sh"
  [ -f "$file" ] || die "unknown target: $1"
  # shellcheck disable=SC1090
  . "$file"
}

resolve_artifact() {
  [ -n "$NAME" ] && { printf '%s' "$NAME"; return; }
  [ "$LATEST" -eq 1 ] || die "provide --name or --latest"
  local prefix
  prefix="$(sanitize_name "$DB_TYPE")_"
  local candidate
  candidate="$(target_list | grep -E "^${prefix}" | grep -Ev '\.sha256$' | sort | tail -n1 || true)"
  [ -n "$candidate" ] || die "no backups found for DB_TYPE=${DB_TYPE}"
  printf '%s' "$candidate"
}

restore_local_archive() {
  local archive="$1" work="$2"
  local plain="$archive"
  case "$archive" in
    *.gpg|*.age)
      plain="$work/decrypted.tar.gz"
      info "decrypting $(basename "$archive")"
      decrypt_file "$archive" "$plain"
      ;;
  esac
  mkdir -p "$work/raw"
  tar -C "$work/raw" -xf "$plain"
  printf '%s' "$work/raw"
}

do_restore() {
  local raw="$1"
  case "$(echo "$DB_TYPE" | tr '[:upper:]' '[:lower:]')" in
    postgres|postgresql|cockroach|timescale)
      require_cmd pg_restore psql
      local url="${RESTORE_DB_URL:-${DB_URL:-$DATABASE_URL}}"
      if [ -f "$raw/database.dump" ]; then
        pg_restore --clean --if-exists --no-owner --no-privileges \
          --dbname "$url" "$raw/database.dump"
      elif [ -f "$raw/all-databases.sql" ]; then
        psql "$url" -f "$raw/all-databases.sql"
      else
        die "no postgres dump found in archive"
      fi
      ;;
    mysql|mariadb)
      require_cmd mysql
      local sql
      sql="$(find "$raw" -name '*.sql.gz' | head -n1)"
      [ -n "$sql" ] || die "no .sql.gz found in archive"
      local my_args=(
        --host="${RESTORE_DB_HOST:-${DB_HOST:-127.0.0.1}}"
        --port="${RESTORE_DB_PORT:-${DB_PORT:-3306}}"
        --user="${RESTORE_DB_USER:-${DB_USER:-root}}"
      )
      [ -n "${DB_PASSWORD:-}" ] && my_args+=(--password="${DB_PASSWORD}")
      gunzip -c "$sql" | mysql "${my_args[@]}"
      ;;
    mongodb|mongo)
      require_cmd mongorestore
      local arc
      arc="$(find "$raw" -name '*.archive.gz' | head -n1)"
      [ -n "$arc" ] || die "no mongo archive found"
      mongorestore --uri="${RESTORE_DB_URL:-${DB_URL:-$MONGO_URI}}" \
        --gzip --archive="$arc" ${RESTORE_MONGO_DROP:+--drop}
      ;;
    sqlite|sqlite3)
      require_var RESTORE_DB_FILE
      local db
      db="$(find "$raw" -type f -name '*.db' -o -name '*.sqlite*' | head -n1)"
      [ -n "$db" ] || die "no sqlite file found"
      cp "$db" "$RESTORE_DB_FILE"
      ok "restored sqlite to $RESTORE_DB_FILE"
      ;;
    redis)
      require_var RESTORE_REDIS_DIR
      cp "$raw/dump.rdb" "$RESTORE_REDIS_DIR/dump.rdb"
      ok "copied dump.rdb to $RESTORE_REDIS_DIR (restart redis to load)"
      ;;
    mssql|sqlserver)
      require_cmd sqlpackage
      local bac
      bac="$(find "$raw" -name '*.bacpac' | head -n1)"
      sqlpackage /Action:Import "/SourceFile:$bac" \
        "/TargetConnectionString:${RESTORE_DB_URL:-}"
      ;;
    oracle)
      require_cmd imp
      local dmp
      dmp="$(find "$raw" -name '*.dmp' | head -n1)"
      imp "userid=${RESTORE_DB_USER:-$DB_USER}/${RESTORE_DB_PASSWORD:-$DB_PASSWORD}@${RESTORE_DB_HOST:-$DB_HOST}:${RESTORE_DB_PORT:-1521}/${DB_SERVICE:-ORCL}" \
        file="$dmp" full=y
      ;;
    *)
      warn "automatic restore for DB_TYPE=${DB_TYPE} is not implemented"
      warn "extracted files are in ${raw}"
      ;;
  esac
}

main() {
  load_target "$TARGET"
  target_init
  local name file
  name="$(resolve_artifact)"
  info "restoring artifact: ${name}"
  file="$WORK_ROOT/$name"
  target_get "$name" "$file"

  local sha_file="${file}.sha256"
  if target_get "${name}.sha256" "$sha_file" 2>/dev/null && [ -s "$sha_file" ]; then
    local expected actual
    expected="$(awk '{print $1}' "$sha_file")"
    actual="$(sha256_of "$file")"
    [ "$expected" = "$actual" ] || die "checksum mismatch for ${name}"
    ok "checksum verified"
  else
    warn "checksum file not found, skipping verification"
  fi

  local raw
  raw="$(restore_local_archive "$file" "$WORK_ROOT")"
  do_restore "$raw"
  ok "restore complete"
}

main "$@"
