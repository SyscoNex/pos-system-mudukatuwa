#!/usr/bin/env bash
set -euo pipefail
# Approved P1-03 execution only; fixed isolated target. No schema changes.
MYSQL_PWD="$(cat /run/secrets/mysql_root_password)" mysql --protocol=socket --user=root <<'SQL'
GRANT SELECT, INSERT, UPDATE ON conex360_auth_review.branches TO 'conex_runtime'@'%';
GRANT SELECT, INSERT, UPDATE ON conex360_auth_review.membership_branches TO 'conex_runtime'@'%';
GRANT SELECT, INSERT, UPDATE ON conex360_auth_review.warehouses TO 'conex_runtime'@'%';
GRANT SELECT, INSERT, UPDATE ON conex360_auth_review.locations TO 'conex_runtime'@'%';
SQL
