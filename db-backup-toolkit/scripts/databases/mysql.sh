# shellcheck shell=bash
# MySQL dumper (mysqldump / mysqlsh fallback). Writes SQL into $RAW_DIR.

mysql_conn_args() {
  MY_ARGS=(--host="${DB_HOST:-127.0.0.1}" --port="${DB_PORT:-3306}" --user="${DB_USER:-root}")
  if [ -n "${DB_SOCKET:-}" ]; then
    MY_ARGS+=(--socket="${DB_SOCKET}")
  fi
  [ -n "${DB_PASSWORD:-}" ] && MY_ARGS+=(--password="${DB_PASSWORD}")
}

dump() {
  require_cmd mysqldump
  mysql_conn_args

  local common=(--single-transaction --quick --skip-lock-tables
                --routines --triggers --events --hex-blob --set-gtid-purged=OFF)

  if env_bool "${DB_ALL:-false}"; then
    info "running mysqldump for all databases"
    mysqldump "${MY_ARGS[@]}" "${common[@]}" --all-databases \
      | gzip -9 > "$RAW_DIR/all-databases.sql.gz"
  else
    require_var DB_NAME
    info "running mysqldump for database '${DB_NAME}'"
    mysqldump "${MY_ARGS[@]}" "${common[@]}" --databases "$DB_NAME" \
      | gzip -9 > "$RAW_DIR/${DB_NAME}.sql.gz"
  fi
}

restore_hint() {
  printf 'gunzip -c <dump>.sql.gz | mysql --host=<h> --user=<u> -p\n'
}
