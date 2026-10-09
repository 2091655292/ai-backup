# shellcheck shell=bash
# Shared helpers for db-backup-toolkit.

set -Eeuo pipefail

if [ -t 1 ]; then
  C_RESET=$'\033[0m'; C_RED=$'\033[31m'; C_GREEN=$'\033[32m'; C_YELLOW=$'\033[33m'; C_BLUE=$'\033[34m'
else
  C_RESET=''; C_RED=''; C_GREEN=''; C_YELLOW=''; C_BLUE=''
fi

log()   { printf '%s[%s]%s %s\n' "$C_BLUE"   "$(date -u +%H:%M:%S)" "$C_RESET" "$*" >&2; }
info()  { log "$*"; }
ok()    { printf '%s[%s] %s%s\n' "$C_GREEN"  "ok"   "$*" "$C_RESET" >&2; }
warn()  { printf '%s[warn] %s%s\n' "$C_YELLOW" "$*" "$C_RESET" >&2; }
err()   { printf '%s[error] %s%s\n' "$C_RED"   "$*" "$C_RESET" >&2; }
die()   { err "$*"; exit 1; }

on_error() {
  local exit_code=$?
  err "failed at line ${BASH_LINENO[0]} (exit ${exit_code})"
  exit "${exit_code}"
}
trap on_error ERR

require_cmd() {
  local missing=0 c
  for c in "$@"; do
    command -v "$c" >/dev/null 2>&1 || { err "required command not found: $c"; missing=1; }
  done
  [ "$missing" -eq 0 ] || die "install missing dependencies (see scripts/lib/install.sh)"
}

require_var() {
  local name
  for name in "$@"; do
    [ -n "${!name:-}" ] || die "required variable not set: $name"
  done
}

env_bool() {
  case "${1:-}" in
    1|true|TRUE|True|yes|YES|on|ON) return 0 ;;
    *) return 1 ;;
  esac
}

utc_stamp() { date -u +"%Y%m%dT%H%M%SZ"; }

sha256_of() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print $1}'
  else
    shasum -a 256 "$1" | awk '{print $1}'
  fi
}

make_workdir() {
  WORK_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/db-backup.XXXXXX")"
  RAW_DIR="$WORK_ROOT/raw"
  OUT_DIR="$WORK_ROOT/out"
  mkdir -p "$RAW_DIR" "$OUT_DIR"
  trap 'cleanup_workdir' EXIT
}

cleanup_workdir() {
  [ -n "${WORK_ROOT:-}" ] && [ -d "$WORK_ROOT" ] && rm -rf "$WORK_ROOT"
}

sanitize_name() {
  printf '%s' "$1" | tr -c 'A-Za-z0-9._-' '_' | sed 's/__*/_/g; s/^_//; s/_$//'
}

# Build the artifact base name, e.g. postgres_mydb_20260101T000000Z
artifact_name() {
  local type="$1" db="$2" stamp="$3"
  printf '%s_%s_%s' "$(sanitize_name "$type")" "$(sanitize_name "${db:-all}")" "$stamp"
}

# Print repo root (two levels up from this file).
repo_root() {
  local d
  d="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
  printf '%s' "$d"
}
