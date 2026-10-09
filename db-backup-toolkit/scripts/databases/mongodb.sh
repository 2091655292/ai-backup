# shellcheck shell=bash
# MongoDB dumper. Writes a compressed archive into $RAW_DIR.

mongo_uri() {
  if [ -n "${DB_URL:-}${MONGO_URI:-}${MONGODB_URI:-}" ]; then
    printf '%s' "${DB_URL:-${MONGO_URI:-$MONGODB_URI}}"
    return 0
  fi
  local scheme="mongodb"
  env_bool "${MONGO_SRV:-false}" && scheme="mongodb+srv"
  local auth=""
  if [ -n "${DB_USER:-}" ]; then
    auth="$(printf '%s' "$DB_USER" | jq -sRr @uri 2>/dev/null || printf '%s' "$DB_USER")"
    [ -n "${DB_PASSWORD:-}" ] && auth="${auth}:$(printf '%s' "$DB_PASSWORD" | jq -sRr @uri 2>/dev/null || printf '%s' "$DB_PASSWORD")"
    auth="${auth}@"
  fi
  printf '%s://%s%s:%s/%s?authSource=%s' \
    "$scheme" "$auth" "${DB_HOST:-127.0.0.1}" "${DB_PORT:-27017}" \
    "${DB_NAME:-admin}" "${DB_AUTH_SOURCE:-admin}"
}

dump() {
  require_cmd mongodump
  local uri
  uri="$(mongo_uri)"

  if env_bool "${DB_ALL:-false}"; then
    info "running mongodump for the whole server"
    mongodump --uri="$uri" --gzip --archive="$RAW_DIR/all-databases.archive.gz"
  else
    require_var DB_NAME
    info "running mongodump for database '${DB_NAME}'"
    mongodump --uri="$uri" --db="$DB_NAME" --gzip --archive="$RAW_DIR/${DB_NAME}.archive.gz"
  fi
}

restore_hint() {
  printf 'mongorestore --uri=<target> --gzip --archive=<dump>.archive.gz\n'
}
