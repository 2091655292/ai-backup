# shellcheck shell=bash
# SQLite dumper. Uses the online backup API when the sqlite3 CLI is present.

dump() {
  require_var DB_FILE
  [ -f "$DB_FILE" ] || die "SQLite file not found: $DB_FILE"

  local base
  base="$(basename "$DB_FILE")"

  if command -v sqlite3 >/dev/null 2>&1; then
    info "running sqlite3 .backup for '$DB_FILE'"
    sqlite3 "$DB_FILE" ".backup '$RAW_DIR/$base'"
  else
    warn "sqlite3 CLI not found, doing a raw file copy (WAL may be inconsistent)"
    cp "$DB_FILE" "$RAW_DIR/$base"
    for ext in -wal -shm; do
      [ -f "${DB_FILE}${ext}" ] && cp "${DB_FILE}${ext}" "$RAW_DIR/"
    done
  fi
}

restore_hint() {
  printf 'sqlite3 <target.db> ".restore <dump-file>"  (or copy the file back)\n'
}
