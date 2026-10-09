# shellcheck shell=bash
# Amazon S3 / S3-compatible (R2, MinIO, Wasabi, B2) target.

S3_PREFIX="${S3_PREFIX:-db-backups}"

s3_aws() {
  local args=()
  [ -n "${S3_ENDPOINT:-}" ] && args+=(--endpoint-url "$S3_ENDPOINT")
  [ -n "${S3_REGION:-}" ] && args+=(--region "$S3_REGION")
  aws "${args[@]}" "$@"
}

target_init() {
  require_cmd aws
  require_var S3_BUCKET
  info "target: s3 bucket=${S3_BUCKET} prefix=${S3_PREFIX}"
}

target_put() {
  local file="$1" name="$2"
  s3_aws s3 cp "$file" "s3://${S3_BUCKET}/${S3_PREFIX}/${name}" --only-show-errors
  ok "uploaded s3://${S3_BUCKET}/${S3_PREFIX}/${name}"
}

target_prune() {
  local days="${RETENTION_DAYS:-0}"
  [ "$days" -gt 0 ] || return 0
  local cutoff
  cutoff="$(date -u -d "${days} days ago" +%s)"
  info "pruning s3 objects older than ${days} days"

  while read -r date_str time_str _size key; do
    [ -n "${key:-}" ] || continue
    local epoch
    epoch="$(date -u -d "${date_str} ${time_str}" +%s 2>/dev/null || echo 0)"
    if [ "$epoch" -gt 0 ] && [ "$epoch" -lt "$cutoff" ]; then
      s3_aws s3 rm "s3://${S3_BUCKET}/${key}" --only-show-errors
      ok "pruned s3://${S3_BUCKET}/${key}"
    fi
  done < <(s3_aws s3 ls "s3://${S3_BUCKET}/${S3_PREFIX}/" --recursive || true)
}

target_list() {
  s3_aws s3 ls "s3://${S3_BUCKET}/${S3_PREFIX}/" --recursive | awk '{print $4}' | sed "s#^${S3_PREFIX}/##"
}

target_get() {
  local name="$1" out="$2"
  s3_aws s3 cp "s3://${S3_BUCKET}/${S3_PREFIX}/${name}" "$out" --only-show-errors
}
