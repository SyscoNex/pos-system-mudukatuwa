# P1-02 database execution review — 28 November 2026

Execution refinement: SQL/checksum input normalizes UTF-8/LF across platforms; RFC/big-endian UUID conversion is tested explicitly. No reviewed DDL changed. Review MySQL enables log-bin-trust-function-creators locally for triggers, avoiding global privileges on the migrator. After migration, grant-runtime.sh explicitly installs mutable-table DML, event SELECT/INSERT and journal SELECT only; runtime cannot modify migration metadata. This narrows the originally proposed database-wide DML grant. Execution/initial 1419 inspection and results are recorded in docs/19.
**Owner approval received 28 November 2026: “Approve isolated database execution and synthetic tests.” Only the target/package below is authorized. Execution evidence is recorded in docs/19_AUTH_BUSINESS_IMPLEMENTATION.md. No production, historical SQL or unrelated project is included.**

## Concrete package
Review the exact SQL, not the historical 160-table file:
- [0000 migration journal](../database/migrations/0000_migration_journal.sql): checksum/version/name/applied-time metadata.
- [0001 identity and business](../database/migrations/0001_identity_business.sql): seven application tables: tenants, users, companies, tenant_memberships, auth_sessions, audit_events, security_events.
- [0002 guards](../database/migrations/0002_identity_guards.sql): append-only audit/security events; immutable tenant/company/member/session/user identities; fixed absolute session expiry, no unrevocation and locked-currency protection.

Idempotency table is deferred: unique provisioning_operation_id plus code/email constraints, atomic provisioning and optimistic profile versions cover this slice. No unused posting/document/inventory tables. auth_sessions adds a scoped selected-membership/user FK and context_version to reject stale cross-tab business requests. Company currency_locked_at is the explicit latch later amount-posting commands must set; it is not an accounting period.

All internal IDs are BIGINT UNSIGNED/string JSON. UUIDs use BINARY(16), documented big-endian/RFC bytes. Session secrets are SHA-256 hashes only in SQL, with the opaque secret inside a protected HttpOnly cookie. Exact scope FKs tie audit to its company and actor membership. Unique companies.tenant_id enforces one default company. All events use UTC DATETIME(6); application commands use parameterized asynchronous SQL and transaction/row locks. No default password/account/tenant seed exists.

## Runner and safeguards
Proposed focused administrative mode in the existing API executable: validate/list package without connecting; explicit migrate command uses separate migration connection-string secret file, expected-database assertion, reviewed-file hashes, MySQL named lock, journal checksums and strict UTC/SQL sessions. SQL is split only on statement-break markers so trigger bodies remain intact. API startup never migrates.
MySQL DDL auto-commits. Failed partial installation stops and retains evidence; no automatic DROP, FK disabling, blind replay, repair or reset. A package already applied must have the same hash. Runtime credentials have scoped DML only; migration credentials have DDL on the disposable database only; root credentials stay in the MySQL bootstrap container. No credentials in source or CLI arguments.

## Isolated disposable target requested
Prepare project conex360-auth-review, container/service mysql, database conex360_auth_review, pinned official MySQL 8.4 image (manifest digest recorded in the dedicated review Compose file). It has its own network/volume, no published MySQL port and no production connections. API/tools/tests run on its internal network. Existing conex360-foundation and all unrelated Docker projects remain untouched.
Starting MySQL itself initializes a database, so even container startup is held for approval. Preparing files/configuration, secret-file scaffolding and code/build/unit/HTTP contract/UI tests can continue independently.

Approval requested: initialize only this new disposable target; create its dedicated accounts; execute only 0000-0002 using the reviewed migration runner; provision independent synthetic tenants; run real MySQL isolation/atomicity/constraint/auth/profile/logo tests and isolated runtime persistence tests. No production access, historical SQL, other databases, destructive cleanup or later tables are included. Tables/runner SQL may be refined during static review; any material change will be called out before execution.
