#!/usr/bin/env bash
# Install the client tools required for the selected DB_TYPE and targets.
# Designed for Debian/Ubuntu GitHub-hosted runners.
#
# Usage:
#   scripts/lib/install.sh --db postgres --targets s3,webdav,git

set -Eeuo pipefail
export DEBIAN_FRONTEND=noninteractive

DB=""
TARGETS="local"
while [ $# -gt 0 ]; do
  case "$1" in
    --db) DB="$2"; shift 2 ;;
    --targets) TARGETS="$2"; shift 2 ;;
    *) echo "unknown argument: $1" >&2; exit 1 ;;
  esac
done

have() { command -v "$1" >/dev/null 2>&1; }
log() { printf '[install] %s\n' "$*"; }

apt_install() {
  log "apt-get install: $*"
  sudo apt-get update -qq
  sudo apt-get install -y -qq --no-install-recommends "$@"
}

install_db_client() {
  case "$(echo "${DB:-}" | tr '[:upper:]' '[:lower:]')" in
    postgres|postgresql|cockroach|timescale)
      have pg_dump || apt_install postgresql-client ;;
    mysql)
      have mysqldump || apt_install default-mysql-client ;;
    mariadb)
      have mariadb-dump || have mysqldump || apt_install mariadb-client ;;
    sqlite|sqlite3)
      have sqlite3 || apt_install sqlite3 ;;
    redis)
      have redis-cli || apt_install redis-tools ;;
    mongodb|mongo)
      if ! have mongodump; then
        local ubuntu_codename
        ubuntu_codename="$(. /etc/os-release && echo "${UBUNTU_CODENAME:-jammy}")"
        log "installing mongodb-database-tools"
        curl -fsSL https://www.mongodb.org/static/pgp/server-7.0.asc \
          | sudo gpg --dearmor -o /usr/share/keyrings/mongodb-server-7.0.gpg
        echo "deb [signed-by=/usr/share/keyrings/mongodb-server-7.0.gpg] https://repo.mongodb.org/apt/ubuntu ${ubuntu_codename}/mongodb-org/7.0 multiverse" \
          | sudo tee /etc/apt/sources.list.d/mongodb-org-7.0.list >/dev/null
        apt_install mongodb-database-tools
      fi
      ;;
    mssql|sqlserver|sql-server)
      install_sqlpackage ;;
    oracle)
      log "Oracle client (Instant Client + exp/imp) must be installed manually; skipping"
      ;;
    custom|"")
      log "no database client to install"
      ;;
    *)
      log "unknown DB_TYPE '${DB}', skipping client install"
      ;;
  esac
}

install_sqlpackage() {
  have sqlpackage && return 0
  log "installing sqlpackage"
  apt_install unzip libunwind8
  curl -fsSL -o /tmp/sqlpackage.zip https://aka.ms/sqlpackage-linux
  sudo unzip -o -q /tmp/sqlpackage.zip -d /opt/sqlpackage
  sudo ln -sf /opt/sqlpackage/sqlpackage /usr/local/bin/sqlpackage
}

install_aws() {
  have aws && return 0
  log "installing AWS CLI v2"
  apt_install unzip curl
  curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o /tmp/awscliv2.zip
  unzip -q -o /tmp/awscliv2.zip -d /tmp
  sudo /tmp/aws/install --update
}

install_rclone() {
  have rclone && return 0
  log "installing rclone"
  curl -fsSL https://rclone.org/install.sh | sudo bash
}

for t in ${TARGETS//,/ }; do
  case "$t" in
    s3) install_aws ;;
    webdav) install_rclone ;;
    git) apt_install git ;;
    local) : ;;
    *) log "unknown target '${t}'" ;;
  esac
done

install_db_client
log "done"
