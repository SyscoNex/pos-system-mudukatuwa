#!/usr/bin/env bash
set -euo pipefail
# Fixed approved target only. No global privileges, passwords in arguments, or DDL.
MYSQL_PWD="$(cat /run/secrets/mysql_root_password)" mysql --protocol=socket --user=root <<'SQL'
REVOKE ALL PRIVILEGES, GRANT OPTION FROM 'conex_runtime'@'%';
GRANT SELECT ON conex360_auth_review.schema_migrations TO 'conex_runtime'@'%';
GRANT SELECT, INSERT, UPDATE, DELETE ON conex360_auth_review.tenants TO 'conex_runtime'@'%';
GRANT SELECT, INSERT, UPDATE, DELETE ON conex360_auth_review.users TO 'conex_runtime'@'%';
GRANT SELECT, INSERT, UPDATE, DELETE ON conex360_auth_review.companies TO 'conex_runtime'@'%';
GRANT SELECT, INSERT, UPDATE, DELETE ON conex360_auth_review.tenant_memberships TO 'conex_runtime'@'%';
GRANT SELECT, INSERT, UPDATE, DELETE ON conex360_auth_review.auth_sessions TO 'conex_runtime'@'%';
GRANT SELECT, INSERT ON conex360_auth_review.audit_events TO 'conex_runtime'@'%';
GRANT SELECT, INSERT ON conex360_auth_review.security_events TO 'conex_runtime'@'%';
SQL
