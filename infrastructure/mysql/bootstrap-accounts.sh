#!/bin/bash
# Executed by the official image ONLY on the separately approved disposable init.
set -euo pipefail
runtime_password="$(cat /run/secrets/mysql_runtime_password)"
migration_password="$(cat /run/secrets/mysql_migration_password)"
[[ "$runtime_password" =~ ^[A-Za-z0-9_-]{32,128}$ ]] || exit 1
[[ "$migration_password" =~ ^[A-Za-z0-9_-]{32,128}$ ]] || exit 1
# Root is used only inside the bootstrap container. No password is a CLI argument;
# SQL passwords travel through stdin and shell tracing stays disabled.
MYSQL_PWD="$(cat /run/secrets/mysql_root_password)" mysql --protocol=socket --user=root <<SQL
CREATE USER 'conex_runtime'@'%' IDENTIFIED BY '$runtime_password';
CREATE USER 'conex_migration'@'%' IDENTIFIED BY '$migration_password';
-- Runtime grants are installed explicitly after reviewed migrations, by grant-runtime.sh.
GRANT ALL PRIVILEGES ON conex360_auth_review.* TO 'conex_migration'@'%';
SQL
unset runtime_password migration_password
