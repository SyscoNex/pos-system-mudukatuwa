#!/usr/bin/env bash
set -euo pipefail
MYSQL_PWD="$(cat /run/secrets/mysql_root_password)" mysql --protocol=socket --user=root <<'SQL'
GRANT SELECT, INSERT ON conex360_auth_review.documents TO 'conex_runtime'@'%';
GRANT SELECT, INSERT ON conex360_auth_review.document_lines TO 'conex_runtime'@'%';
GRANT SELECT, INSERT ON conex360_auth_review.goods_receipts TO 'conex_runtime'@'%';
GRANT SELECT, INSERT ON conex360_auth_review.lots TO 'conex_runtime'@'%';
GRANT SELECT, INSERT ON conex360_auth_review.stock_buckets TO 'conex_runtime'@'%';
GRANT SELECT, INSERT ON conex360_auth_review.stock_entries TO 'conex_runtime'@'%';
GRANT SELECT, INSERT ON conex360_auth_review.idempotency_keys TO 'conex_runtime'@'%';
GRANT SELECT, INSERT, UPDATE ON conex360_auth_review.document_sequences TO 'conex_runtime'@'%';
GRANT SELECT, INSERT, UPDATE ON conex360_auth_review.stock_balances TO 'conex_runtime'@'%';
SQL
