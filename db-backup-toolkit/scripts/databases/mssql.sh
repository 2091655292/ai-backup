# shellcheck shell=bash
# Microsoft SQL Server dumper using sqlpackage (bacpac export, schema + data).
# Requires the `sqlpackage` CLI (installed by scripts/lib/install.sh).

mssql_conn_string() {
  local db="$1"
  printf 'Server=%s,%s;Database=%s;User ID=%s;Password=%s;TrustServerCertificate=True;Encrypt=%s' \
    "${DB_HOST:-127.0.0.1}" "${DB_PORT:-1433}" "$db" \
    "${DB_USER:-sa}" "${DB_PASSWORD:-}" "${MSSQL_ENCRYPT:-True}"
}

dump() {
  require_cmd sqlpackage
  require_var DB_NAME

  info "running sqlpackage Export for database '${DB_NAME}'"
  sqlpackage /Action:Export \
    "/SourceConnectionString:$(mssql_conn_string "$DB_NAME")" \
    "/TargetFile:$RAW_DIR/${DB_NAME}.bacpac" \
    /p:VerifyFullTextDocumentTypesSupported=false \
    /p:ExtractAllTableData=true
}

restore_hint() {
  printf 'sqlpackage /Action:Import /SourceFile:<dump>.bacpac /TargetConnectionString:"<target>"\n'
}
