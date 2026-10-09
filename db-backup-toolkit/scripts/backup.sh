#!/usr/bin/env bash
# db-backup-toolkit - dump a database, package + optionally encrypt it, and ship
# it to one or more targets (local, S3, WebDAV, private Git repo).
#
# Usage:
#   scripts/backup.sh [--config FILE] [--targets s3,webdav,git,local]
#
# All behaviour is driven by environment variables. See config.example.env.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
. "$SCRIPT_DIR/lib/common.sh"
# shellcheck source=lib/crypto.sh
. "$SCRIPT_DIR/lib/crypto.sh"

CONFIG_FILE=""
while [ $# -gt 0 ]; do
  case "$1" in
    --config) CONFIG_FILE="$2"; shift 2 ;;
    --targets) BACKUP_TARGETS="$2"; shift 2 ;;
    -h|--help) sed -n '2,12p' "$0"; exit 0 ;;
    *) die "unknown argument: $1" ;;
  esac
done

if [ -n "$CONFIG_FILE" ]; then
  [ -f "$CONFIG_FILE" ] || die "config file not found: $CONFIG_FILE"
  set -a
  # shellcheck disable=SC1090
  . "$CONFIG_FILE"
  set +a
fi

DB_TYPE="${DB_TYPE:?DB_TYPE is required (postgres|mysql|mariadb|mongodb|sqlite|redis|mssql|oracle|custom)}"
BACKUP_TARGETS="${BACKUP_TARGETS:-local}"

resolve_dumper() {
  case "$1" in
    postgres|postgresql|cockroach|cockroachdb|timescale) echo "postgres" ;;
    mysql) echo "mysql" ;;
    mariadb) echo "mariadb" ;;
    mongodb|mongo) echo "mongodb" ;;
    sqlite|sqlite3) echo "sqlite" ;;
    redis) echo "redis" ;;
    mssql|sqlserver|sql-server) echo "mssql" ;;
    oracle) echo "oracle" ;;
    custom) echo "custom" ;;
    *) die "unsupported DB_TYPE: $1" ;;
  esac
}

db_dump() {
  if [ -n "${DB_DUMP_COMMAND:-}" ]; then
    info "running custom DB_DUMP_COMMAND"
    export RAW_DIR
    bash -c "$DB_DUMP_COMMAND"
    return 0
  fi
  local dumper
  dumper="$(resolve_dumper "$DB_TYPE")"
  local file="$SCRIPT_DIR/databases/${dumper}.sh"
  [ -f "$file" ] || die "no dumper for DB_TYPE=${DB_TYPE}"
  # shellcheck disable=SC1090
  . "$file"
  dump
}

load_target() {
  local name="$1"
  local file="$SCRIPT_DIR/targets/${name}.sh"
  [ -f "$file" ] || die "unknown backup target: $name"
  # shellcheck disable=SC1090
  . "$file"
}

target_finalize() { :; }

write_summary() {
  local line="$1"
  if [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then
    printf '%s\n' "$line" >> "$GITHUB_STEP_SUMMARY"
  fi
}

main() {
  info "db-backup-toolkit starting (type=${DB_TYPE}, targets=${BACKUP_TARGETS})"
  make_workdir

  local stamp base
  stamp="$(utc_stamp)"
  local db_label="${DB_NAME:-${DB_FILE:+$(basename "$DB_FILE")}}"
  base="$(artifact_name "$DB_TYPE" "${db_label:-all}" "$stamp")"

  db_dump

  if [ -z "$(ls -A "$RAW_DIR" 2>/dev/null)" ]; then
    die "dumper produced no files in RAW_DIR"
  fi

  local fmt="${COMPRESS_FORMAT:-tar.gz}"
  local ext="tar.gz"
  [ "$fmt" = "tar.zst" ] && ext="tar.zst"
  local archive="$OUT_DIR/${base}.${ext}"
  info "packaging ${base}.${ext}"
  create_archive "$RAW_DIR" "$archive" "$fmt"

  local final_file
  final_file="$(maybe_encrypt "$archive")"
  local final_name
  final_name="$(basename "$final_file")"

  local checksum_file="${final_file}.sha256"
  printf '%s  %s\n' "$(sha256_of "$final_file")" "$final_name" > "$checksum_file"

  local size
  size="$(du -h "$final_file" | awk '{print $1}')"
  ok "created ${final_name} (${size})"

  local keep_dir="${BACKUP_OUTPUT_DIR:-}"
  if [ -z "$keep_dir" ] && [ -n "${GITHUB_ACTIONS:-}" ]; then
    keep_dir="${RUNNER_TEMP:-/tmp}/db-backup-output"
  fi
  local published_file="$final_file"
  if [ -n "$keep_dir" ]; then
    mkdir -p "$keep_dir"
    cp "$final_file" "$checksum_file" "$keep_dir/"
    published_file="$keep_dir/$final_name"
    info "published artifact to ${published_file}"
  fi

  IFS=',' read -r -a targets <<< "$BACKUP_TARGETS"
  local t
  for t in "${targets[@]}"; do
    t="$(echo "$t" | tr -d '[:space:]')"
    [ -n "$t" ] || continue
    target_finalize() { :; }
    load_target "$t"
    target_init
    target_put "$final_file" "$final_name"
    target_put "$checksum_file" "$(basename "$checksum_file")"
    target_prune
    target_finalize
  done

  printf 'ARTIFACT_NAME=%s\nARTIFACT_PATH=%s\nARTIFACT_SIZE=%s\n' \
    "$final_name" "$published_file" "$size" > "$OUT_DIR/result.env"
  [ -n "${GITHUB_OUTPUT:-}" ] && {
    printf 'artifact_name=%s\n' "$final_name" >> "$GITHUB_OUTPUT"
    printf 'artifact_path=%s\n' "$published_file" >> "$GITHUB_OUTPUT"
  }

  write_summary "### Database backup succeeded"
  write_summary ""
  write_summary "- Type: \`${DB_TYPE}\`"
  write_summary "- Artifact: \`${final_name}\` (${size})"
  write_summary "- Targets: \`${BACKUP_TARGETS}\`"
  write_summary "- SHA256: \`$(sha256_of "$final_file")\`"
  ok "backup complete: ${final_name}"
}

main "$@"
