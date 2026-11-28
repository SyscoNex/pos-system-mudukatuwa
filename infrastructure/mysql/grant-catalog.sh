#!/usr/bin/env bash
set -euo pipefail
# P1-04 approved execution only, fixed isolated target.
MYSQL_PWD="$(cat /run/secrets/mysql_root_password)" mysql --protocol=socket --user=root <<'SQL'
GRANT SELECT, INSERT, UPDATE ON conex360_auth_review.units TO 'conex_runtime'@'%';
GRANT SELECT, INSERT, UPDATE ON conex360_auth_review.item_categories TO 'conex_runtime'@'%';
GRANT SELECT, INSERT, UPDATE ON conex360_auth_review.items TO 'conex_runtime'@'%';
GRANT SELECT, INSERT, UPDATE ON conex360_auth_review.item_units TO 'conex_runtime'@'%';
GRANT SELECT, INSERT, UPDATE ON conex360_auth_review.item_barcodes TO 'conex_runtime'@'%';
GRANT SELECT, INSERT, UPDATE ON conex360_auth_review.parties TO 'conex_runtime'@'%';
SQL
