# shellcheck shell=bash
# Oracle dumper using the legacy client-side `exp` utility.
# For modern deployments prefer RMAN/Data Pump and set DB_DUMP_COMMAND instead.

dump() {
  require_cmd exp
  require_var DB_USER DB_PASSWORD
  local conn="${DB_USER}/${DB_PASSWORD}@${DB_HOST:-127.0.0.1}:${DB_PORT:-1521}/${DB_SERVICE:-ORCL}"

  if env_bool "${DB_ALL:-false}"; then
    info "running exp full database export"
    exp "userid=${conn}" file="$RAW_DIR/full.dmp" full=y consistent=y log="$RAW_DIR/exp.log"
  else
    require_var DB_NAME
    info "running exp schema export for '${DB_NAME}'"
    exp "userid=${conn}" file="$RAW_DIR/${DB_NAME}.dmp" owner="${DB_NAME}" consistent=y log="$RAW_DIR/exp.log"
  fi
}

restore_hint() {
  printf 'imp userid=<user>/<pass>@<host>:<port>/<service> file=<dump>.dmp full=y\n'
}
