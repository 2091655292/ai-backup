# shellcheck shell=bash
# Git target: pushes backups into a dedicated branch of a (private) repository.
# Default mode squashes history (single commit + force push) to avoid repo bloat
# while still honouring RETENTION_DAYS across runs.

BACKUP_BRANCH="${BACKUP_BRANCH:-db-backups}"
GIT_PREFIX="${GIT_PREFIX:-backups}"
GIT_SQUASH="${GIT_SQUASH:-true}"
GIT_BASE_URL="${GIT_BASE_URL:-https://github.com}"

GIT_DIR=""

target_init() {
  require_cmd git
  local url
  if [ -n "${GIT_REMOTE_URL:-}" ]; then
    url="$GIT_REMOTE_URL"
  else
    local repo="${BACKUP_REPO:-${GITHUB_REPOSITORY:-}}"
    [ -n "$repo" ] || die "git target requires BACKUP_REPO (owner/repo) or GIT_REMOTE_URL"
    local token="${BACKUP_REPO_TOKEN:-${GITHUB_TOKEN:-}}"
    [ -n "$token" ] || die "git target requires BACKUP_REPO_TOKEN or GITHUB_TOKEN"
    local server="${GIT_BASE_URL#https://}"
    url="https://x-access-token:${token}@${server}/${repo}.git"
  fi

  GIT_DIR="$WORK_ROOT/git-repo"
  mkdir -p "$GIT_DIR"
  git -C "$GIT_DIR" init -q
  git -C "$GIT_DIR" remote add origin "$url"
  git -C "$GIT_DIR" config user.email "${GIT_USER_EMAIL:-db-backup-bot@users.noreply.github.com}"
  git -C "$GIT_DIR" config user.name "${GIT_USER_NAME:-db-backup-bot}"

  if git -C "$GIT_DIR" fetch -q --depth 1 origin "$BACKUP_BRANCH" 2>/dev/null; then
    git -C "$GIT_DIR" checkout -q -B "$BACKUP_BRANCH" FETCH_HEAD
  else
    warn "branch '${BACKUP_BRANCH}' not found, creating it"
    git -C "$GIT_DIR" checkout -q --orphan "$BACKUP_BRANCH"
  fi
  mkdir -p "$GIT_DIR/$GIT_PREFIX"
  info "target: git branch=${BACKUP_BRANCH} prefix=${GIT_PREFIX}"
}

target_put() {
  local file="$1" name="$2"
  cp "$file" "$GIT_DIR/$GIT_PREFIX/$name"
  ok "staged git:${GIT_PREFIX}/${name}"
}

target_prune() {
  local days="${RETENTION_DAYS:-0}"
  [ "$days" -gt 0 ] || return 0
  info "pruning git files older than ${days} days"
  find "$GIT_DIR/$GIT_PREFIX" -type f -mtime "+${days}" -print -delete || true
}

git_commit_and_push() {
  git -C "$GIT_DIR" add -A
  if git -C "$GIT_DIR" diff --cached --quiet; then
    info "no changes to commit"
    return 0
  fi

  if env_bool "$GIT_SQUASH"; then
    git -C "$GIT_DIR" checkout -q --orphan db-backups-tmp
    git -C "$GIT_DIR" add -A
    git -C "$GIT_DIR" commit -q -m "backup: $(utc_stamp)"
    git -C "$GIT_DIR" branch -M "$BACKUP_BRANCH"
    git -C "$GIT_DIR" push -q -f origin "$BACKUP_BRANCH"
  else
    git -C "$GIT_DIR" commit -q -m "backup: $(utc_stamp)"
    git -C "$GIT_DIR" push -q origin "$BACKUP_BRANCH" || {
      git -C "$GIT_DIR" pull -q --rebase origin "$BACKUP_BRANCH"
      git -C "$GIT_DIR" push -q origin "$BACKUP_BRANCH"
    }
  fi
  ok "pushed git branch ${BACKUP_BRANCH}"
}

target_finalize() {
  git_commit_and_push
}

target_list() {
  find "$GIT_DIR/$GIT_PREFIX" -type f -printf '%f\n' 2>/dev/null | sort
}

target_get() {
  local name="$1" out="$2"
  cp "$GIT_DIR/$GIT_PREFIX/$name" "$out"
}
