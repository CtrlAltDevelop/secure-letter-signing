#!/bin/sh
# Runs once on an EMPTY Postgres volume (docker-entrypoint-initdb.d). Creates the least-privilege role the running
# server uses: no superuser/createdb/createrole, owns nothing, so a compromised app cannot ALTER/DROP tables or the
# immutability triggers. Migrations run as the owner role ($POSTGRES_USER) from the server's start command.
# Existing deployment: run the same SQL once by hand with psql as the owner, then set APP_DB_PASSWORD.
set -eu
: "${APP_DB_PASSWORD:?set APP_DB_PASSWORD}"
psql -v ON_ERROR_STOP=1 -v app_pw="$APP_DB_PASSWORD" --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<'SQL'
CREATE ROLE letters_app LOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE PASSWORD :'app_pw';
GRANT CONNECT ON DATABASE letters TO letters_app;
GRANT USAGE ON SCHEMA public TO letters_app;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO letters_app;
GRANT USAGE, SELECT, UPDATE ON ALL SEQUENCES IN SCHEMA public TO letters_app;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO letters_app;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT USAGE, SELECT, UPDATE ON SEQUENCES TO letters_app;
SQL
