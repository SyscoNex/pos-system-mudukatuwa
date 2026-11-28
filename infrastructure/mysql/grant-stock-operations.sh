#!/usr/bin/env bash
set -euo pipefail
MYSQL_PWD="$(cat /run/secrets/mysql_root_password)" mysql --protocol=socket --user=root <<'SQL'
GRANT SELECT, INSERT ON conex360_auth_review.transfer_dispatch_allocations TO 'conex_runtime'@'%';
GRANT SELECT, INSERT ON conex360_auth_review.transfer_receipt_allocations TO 'conex_runtime'@'%';
GRANT SELECT, INSERT ON conex360_auth_review.transfer_resolution_allocations TO 'conex_runtime'@'%';
GRANT SELECT, INSERT, UPDATE ON conex360_auth_review.stock_transfers TO 'conex_runtime'@'%';
GRANT SELECT, INSERT, UPDATE ON conex360_auth_review.stock_reservations TO 'conex_runtime'@'%';
GRANT SELECT, INSERT, UPDATE ON conex360_auth_review.stock_counts TO 'conex_runtime'@'%';
GRANT SELECT, INSERT, UPDATE ON conex360_auth_review.stock_count_lines TO 'conex_runtime'@'%';
SQL
