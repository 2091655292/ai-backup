# shellcheck shell=bash
# PostgreSQL / CockroachDB dumper. Writes a custom-format dump into $RAW_DIR.

pg_conn_args() {
  PG_ARGS=()
  if [ -n "${DB_URL:-}${DATABASE_URL:-}" ]; then
    PG_ARGS+=(--dbname "${DB_URL:-$DATABASE_URL}")
  else
    PG_ARGS+=(--host "${DB_HOST:-127.0.0.1}" --port "${DB_PORT:-5432}" --username "${DB_USER:-postgres}")
    [ -n "${DB_NAME:-}" ] && PG_ARGS+=(--dbname "$DB_NAME")
  fi
}

dump() {
  require_cmd pg_dump
  export PGPASSWORD="${DB_PASSWORD:-}"
  [ -n "$PGPASSWORD" ] || unset PGPASSWORD

  if env_bool "${DB_ALL:-false}"; then
    require_cmd pg_dumpall
    info "running pg_dumpall (all databases)"
    pg_dumpall --host "${DB_HOST:-127.0.0.1}" --port "${DB_PORT:-5432}" \
      --username "${DB_USER:-postgres}" --no-owner --no-privileges \
      > "$RAW_DIR/all-databases.sql"
  else
    require_var DB_NAME
    pg_conn_args
    info "running pg_dump for database '${DB_NAME}'"
    pg_dump "${PG_ARGS[@]}" \
      --format=custom --no-owner --no-privileges --compress=6 \
      --file "$RAW_DIR/database.dump"
    pg_restore --list "$RAW_DIR/database.dump" >/dev/null \
      || die "pg_dump archive failed integrity check"
  fi
}

restore_hint() {
  printf 'pg_restore --clean --if-exists --no-owner --no-privileges -d <target> database.dump\n'
}
