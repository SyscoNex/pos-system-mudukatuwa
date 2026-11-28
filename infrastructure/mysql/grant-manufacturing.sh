#!/usr/bin/env bash
set -euo pipefail
MYSQL_PWD="$(cat /run/secrets/mysql_root_password)" mysql --protocol=socket --user=root <<'SQL'
GRANT SELECT, INSERT ON conex360_auth_review.production_events TO 'conex_runtime'@'%';
SQL
