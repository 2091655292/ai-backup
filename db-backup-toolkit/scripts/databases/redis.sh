# shellcheck shell=bash
# Redis dumper. Streams an RDB snapshot into $RAW_DIR.

dump() {
  require_cmd redis-cli

  local args=(-h "${DB_HOST:-127.0.0.1}" -p "${DB_PORT:-6379}")
  [ -n "${DB_PASSWORD:-}" ] && args+=(-a "$DB_PASSWORD" --no-auth-warning)

  info "requesting RDB snapshot from redis"
  redis-cli "${args[@]}" --rdb "$RAW_DIR/dump.rdb" >/dev/null
  [ -s "$RAW_DIR/dump.rdb" ] || die "redis returned an empty RDB"
}

restore_hint() {
  printf 'copy dump.rdb into the redis data dir (dir in redis.conf) and restart redis\n'
}
