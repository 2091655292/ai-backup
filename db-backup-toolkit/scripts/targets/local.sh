# shellcheck shell=bash
# Local directory target. Useful for tests and for runners that mount a volume.

LOCAL_PATH="${LOCAL_PATH:-./backups}"

target_init() {
  mkdir -p "$LOCAL_PATH"
  LOCAL_PATH="$(cd "$LOCAL_PATH" && pwd)"
  info "target: local dir=${LOCAL_PATH}"
}

target_put() {
  local file="$1" name="$2"
  cp "$file" "$LOCAL_PATH/$name"
  ok "stored local:${LOCAL_PATH}/${name}"
}

target_prune() {
  local days="${RETENTION_DAYS:-0}"
  [ "$days" -gt 0 ] || return 0
  info "pruning local files older than ${days} days"
  find "$LOCAL_PATH" -type f -mtime "+${days}" -print -delete || true
}

target_list() {
  find "$LOCAL_PATH" -type f -printf '%f\n' 2>/dev/null | sort
}

target_get() {
  local name="$1" out="$2"
  cp "$LOCAL_PATH/$name" "$out"
}
