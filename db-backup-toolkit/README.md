# db-backup-toolkit

Back up almost any database from **GitHub Actions** and ship the encrypted dump
to a **private Git repository**, **S3-compatible object storage**, or **WebDAV**
(and/or keep it on the runner). One reusable composite action, no servers to run.

```yaml
- uses: your-org/db-backup-toolkit@v1
  with:
    db_type: postgres
    db_host: ${{ secrets.DB_HOST }}
    db_user: ${{ secrets.DB_USER }}
    db_password: ${{ secrets.DB_PASSWORD }}
    db_name: myapp
    targets: s3,webdav,git
    backup_passphrase: ${{ secrets.BACKUP_PASSPHRASE }}
```

## Why another tool?

Existing pieces are scattered: `pg_dump | aws s3 cp` snippets, `Databasement`
(needs a self-hosted server + API), Terraform modules for GitHub-to-S3 repo
mirroring, and `restic`/`rclone` guides for generic files. This project unifies
those ideas into a single, dependency-light toolkit that:

- supports the mainstream relational, document, key-value and embedded databases;
- writes to all three requested destinations from one run;
- encrypts before upload (GPG or age), verifies the dump where the engine allows it, and stores a SHA-256 checksum next to every artifact;
- installs only the client tools the selected engine and targets actually need.

## Supported databases

| `db_type` | Client used | Notes |
|---|---|---|
| `postgres` (alias `postgresql`, `cockroach`, `timescale`) | `pg_dump` / `pg_dumpall` | custom format, integrity-checked with `pg_restore --list` |
| `mysql` | `mysqldump` | `--single-transaction`, routines/triggers/events |
| `mariadb` | `mariadb-dump` | falls back to `mysqldump` |
| `mongodb` (alias `mongo`) | `mongodump` | compressed `--archive` |
| `sqlite` (alias `sqlite3`) | `sqlite3 .backup` | falls back to a file copy |
| `redis` | `redis-cli --rdb` | streams an RDB snapshot |
| `mssql` (alias `sqlserver`) | `sqlpackage` | schema + data `.bacpac` |
| `oracle` | `exp` | client-side export; see caveats below |
| `custom` | `DB_DUMP_COMMAND` | any command that writes files into `$RAW_DIR` |

Anything not listed can be handled with `db_type: custom` and a `db_dump_command`.

## Storage targets

Set `targets` to any comma-separated combination of `local,s3,webdav,git`.

- **s3** — AWS S3 or any S3-compatible endpoint (Cloudflare R2, MinIO, Wasabi, Backblaze B2) via `AWS_ENDPOINT_URL`-style `s3_endpoint`.
- **webdav** — Nextcloud, ownCloud, Synology, Box or any WebDAV share, transported with `rclone` (directories are created automatically).
- **git** — pushes into a dedicated branch of a private repository. By default it force-pushes a single squashed commit so multi-GB dumps never bloat the repo history, while still honouring `retention_days`. Set `GIT_REMOTE_URL` to target any git remote (self-hosted or SSH).
- **local** — a directory on the runner (also used to publish a workflow artifact).

## Usage

### 1. As a reusable action

Fork/clone this repository, then in the target repository add a scheduled
workflow. A ready-to-edit template lives in
`.github/workflows/backup.yml`.

### 2. Directly with the scripts

```bash
cp config.example.env config.env
# edit config.env, then:
DB_TYPE=postgres BACKUP_TARGETS=local ./scripts/backup.sh --config config.env
```

The scripts are plain Bash and run anywhere `tar` + the relevant client exist.

## Configuration reference

Everything is driven by environment variables (see `config.example.env`).
The most important ones:

| Variable | Purpose |
|---|---|
| `DB_TYPE` | database engine (see table) |
| `DB_HOST`, `DB_PORT`, `DB_USER`, `DB_PASSWORD`, `DB_NAME` | connection |
| `DB_URL` / `DATABASE_URL` | single connection string, overrides host/port/user |
| `DB_ALL` | dump every database on the server |
| `DB_FILE` | SQLite file path |
| `DB_DUMP_COMMAND` | custom dump command |
| `BACKUP_TARGETS` | `local,s3,webdav,git` |
| `BACKUP_PASSPHRASE` | GPG symmetric encryption (AES-256) |
| `BACKUP_AGE_RECIPIENT` | age public-key encryption |
| `COMPRESS_FORMAT` | `tar.gz` (default) or `tar.zst` |
| `RETENTION_DAYS` | delete older backups on every target (`0` keeps forever) |

Secrets belong in **GitHub Secrets**, never in the workflow file. The example
workflow reads `DB_PASSWORD`, `BACKUP_PASSPHRASE`, `AWS_*`, `WEBDAV_*`,
`BACKUP_REPO_TOKEN`, etc.

## Restoring

```bash
DB_TYPE=postgres \
BACKUP_PASSPHRASE=... \
S3_BUCKET=my-backups AWS_ACCESS_KEY_ID=... AWS_SECRET_ACCESS_KEY=... \
RESTORE_DB_URL=postgresql://user:pass@host/target \
./scripts/restore.sh --target s3 --latest
```

`restore.sh` downloads the checksum first, verifies SHA-256, decrypts, extracts
and then runs the engine-specific restore (`pg_restore`, `mysql`, `mongorestore`,
`sqlpackage /Action:Import`, ...). Use `--name <artifact>` to restore a specific
file. Redis and SQLite restores place the file where you point
`RESTORE_REDIS_DIR` / `RESTORE_DB_FILE`.

## Encrypting the backups

Set `BACKUP_PASSPHRASE` (GPG, AES-256) **or** `BACKUP_AGE_RECIPIENT` (age). The
passphrase/key is never written to logs. Without the matching secret the uploaded
artifacts are unreadable, so store it somewhere safe. For age decryption set
`BACKUP_AGE_IDENTITY` to the private key when restoring.

## Scheduling and safety

- The sample workflow runs daily at `02:00 UTC` and on manual dispatch.
- Use a `concurrency` group (already set) to avoid overlapping runs.
- Give the database a **read-only backup user** where possible.
- `oracle` uses the legacy client-side `exp`; for modern deployments set
  `DB_DUMP_COMMAND` to wrap `expdp`/RMAN instead.
- GitHub-hosted runners have limited resources. Very large databases (hundreds of
  GB) are better handled by a self-hosted runner or a native snapshot process.

## Repository layout

```
action.yml                  composite GitHub Action
.github/workflows/backup.yml  scheduled example
.github/workflows/ci.yml      matrix tests against real DB service containers
scripts/backup.sh           main entrypoint
scripts/restore.sh          restore entrypoint
scripts/lib/                shared helpers, packaging, crypto, client installer
scripts/databases/*.sh      one dumper per engine
scripts/targets/*.sh        local, s3, webdav, git uploaders
config.example.env          all settings with defaults
```

## License

MIT. See `LICENSE`.
