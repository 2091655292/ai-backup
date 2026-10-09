# shellcheck shell=bash
# MariaDB dumper. Prefers mariadb-dump, falls back to mysqldump.

dump() {
  local bin="mariadb-dump"
  command -v "$bin" >/dev/null 2>&1 || bin="mysqldump"
  require_cmd "$bin"

  local args=(--host="${DB_HOST:-127.0.0.1}" --port="${DB_PORT:-3306}" --user="${DB_USER:-root}")
  [ -n "${DB_SOCKET:-}" ] && args+=(--socket="${DB_SOCKET}")
  [ -n "${DB_PASSWORD:-}" ] && args+=(--password="${DB_PASSWORD}")

  local common=(--single-transaction --quick --skip-lock-tables
                --routines --triggers --events --hex-blob)

  if env_bool "${DB_ALL:-false}"; then
    info "running $bin for all databases"
    "$bin" "${args[@]}" "${common[@]}" --all-databases \
      | gzip -9 > "$RAW_DIR/all-databases.sql.gz"
  else
    require_var DB_NAME
    info "running $bin for database '${DB_NAME}'"
    "$bin" "${args[@]}" "${common[@]}" --databases "$DB_NAME" \
      | gzip -9 > "$RAW_DIR/${DB_NAME}.sql.gz"
  fi
}

restore_hint() {
  printf 'gunzip -c <dump>.sql.gz | mariadb --host=<h> --user=<u> -p\n'
}
