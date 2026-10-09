# shellcheck shell=bash
# Packaging, compression and encryption helpers.

# create_archive <raw_dir> <out_file> [format]
# format: tar.gz (default) | tar.zst (if zstd available)
create_archive() {
  local raw_dir="$1" out_file="$2" fmt="${3:-tar.gz}"
  case "$fmt" in
    tar.zst)
      require_cmd tar zstd
      tar -C "$raw_dir" -cf - . | zstd -q -T0 -19 -o "$out_file"
      ;;
    tar.gz|*)
      require_cmd tar
      tar -C "$raw_dir" -czf "$out_file" .
      ;;
  esac
  [ -s "$out_file" ] || die "archive is empty: $out_file"
}

# maybe_encrypt <file> -> echoes final path on stdout, writes logs to stderr
# Supports:
#   BACKUP_PASSPHRASE        -> gpg symmetric (AES-256)
#   BACKUP_AGE_RECIPIENT     -> age public key
maybe_encrypt() {
  local in="$1"

  if [ -n "${BACKUP_PASSPHRASE:-}" ]; then
    require_cmd gpg
    local out="${in}.gpg"
    local passfile="$WORK_ROOT/.passphrase"
    umask 077
    printf '%s' "$BACKUP_PASSPHRASE" > "$passfile"
    gpg --batch --yes --quiet \
        --symmetric --cipher-algo AES256 \
        --passphrase-file "$passfile" \
        --output "$out" "$in"
    rm -f "$passfile"
    log "encrypted with gpg (AES-256) -> $(basename "$out")" >&2
    printf '%s' "$out"
    return 0
  fi

  if [ -n "${BACKUP_AGE_RECIPIENT:-}" ]; then
    require_cmd age
    local out="${in}.age"
    age --recipient "$BACKUP_AGE_RECIPIENT" --output "$out" "$in"
    log "encrypted with age -> $(basename "$out")" >&2
    printf '%s' "$out"
    return 0
  fi

  printf '%s' "$in"
}

# decrypt_file <in> <out> - uses the same config as maybe_encrypt
decrypt_file() {
  local in="$1" out="$2"
  case "$in" in
    *.gpg)
      require_cmd gpg
      require_var BACKUP_PASSPHRASE
      local passfile="$WORK_ROOT/.passphrase"
      umask 077
      printf '%s' "$BACKUP_PASSPHRASE" > "$passfile"
      gpg --batch --yes --quiet --decrypt \
          --passphrase-file "$passfile" \
          --output "$out" "$in"
      rm -f "$passfile"
      ;;
    *.age)
      require_cmd age
      require_var BACKUP_AGE_IDENTITY
      age --decrypt --identity "$BACKUP_AGE_IDENTITY" --output "$out" "$in"
      ;;
    *)
      cp "$in" "$out"
      ;;
  esac
}
