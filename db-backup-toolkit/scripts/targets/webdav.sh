# shellcheck shell=bash
# WebDAV target (Nextcloud, ownCloud, Synology, Box, generic WebDAV).
# Uses rclone as the transport so directories are created automatically.

WEBDAV_REMOTE="dbbackup"
WEBDAV_PATH="${WEBDAV_PATH:-db-backups}"

target_init() {
  require_cmd rclone
  require_var WEBDAV_URL WEBDAV_USER WEBDAV_PASSWORD

  local obscured
  obscured="$(rclone obscure "$WEBDAV_PASSWORD")"

  export RCLONE_CONFIG_${WEBDAV_REMOTE^^}_TYPE="webdav"
  export RCLONE_CONFIG_${WEBDAV_REMOTE^^}_URL="$WEBDAV_URL"
  export RCLONE_CONFIG_${WEBDAV_REMOTE^^}_VENDOR="${WEBDAV_VENDOR:-other}"
  export RCLONE_CONFIG_${WEBDAV_REMOTE^^}_USER="$WEBDAV_USER"
  export RCLONE_CONFIG_${WEBDAV_REMOTE^^}_PASS="$obscured"

  info "target: webdav url=${WEBDAV_URL} path=${WEBDAV_PATH}"
}

target_put() {
  local file="$1" name="$2"
  rclone copyto "$file" "${WEBDAV_REMOTE}:${WEBDAV_PATH}/${name}" --stats-one-line
  ok "uploaded ${WEBDAV_REMOTE}:${WEBDAV_PATH}/${name}"
}

target_prune() {
  local days="${RETENTION_DAYS:-0}"
  [ "$days" -gt 0 ] || return 0
  info "pruning webdav files older than ${days} days"
  rclone delete "${WEBDAV_REMOTE}:${WEBDAV_PATH}" --min-age "${days}d" -v
}

target_list() {
  rclone lsf "${WEBDAV_REMOTE}:${WEBDAV_PATH}" --files-only
}

target_get() {
  local name="$1" out="$2"
  rclone copyto "${WEBDAV_REMOTE}:${WEBDAV_PATH}/${name}" "$out" --stats-one-line
}
