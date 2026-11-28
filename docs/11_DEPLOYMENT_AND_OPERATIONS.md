# Phase 1 deployment and operations

P1-04 local review setup/approved upgrade commands: docs/23_CATALOG_SUPPLIERS_IMPLEMENTATION.md. Enable Catalog__Enabled=true only after reviewed schema 0007 and catalogue grants are applied; readiness then requires version 7. Runtime never receives migration credentials. Use both auth-review and Workbench Compose files for the existing review stack (localhost 3307 read-only); private p104-clean has no published ports. Earlier slice evidence below is historical. Production/new SQL remain gated.

P1-02 local runtime/first-business/recovery procedure is in [docs/19](19_AUTH_BUSINESS_IMPLEMENTATION.md). Only conex360-auth-review execution is approved; original foundation stack is preserved. Persistent volume holds private logos and certificate-encrypted Data Protection keys; PFX/password remain separate secrets. MySQL is unpublished, runtime journal/evidence permissions are restricted, migrations explicit and never startup. Production requires VerifyFull database TLS, explicit HTTPS origins/trusted proxy IPs and host certificates/permissions. Restart/dependency tests are not a full encrypted off-host backup/restore rehearsal; production launch and MFA remain separate owner decisions.
Use isolated local/CI synthetic data, staging/test credentials and production on a Linux VPS. A single host with Next.js Node, .NET API, MySQL and reverse proxy is sufficient to start; it is a single failure domain. No Worker/broker/replica/offline service is required.
Docker Compose is proposed where it simplifies repeatability. Choose host/storage from actual client usage; the historical 4 vCPU/8 GB and RPO/RTO targets are not approved Phase 1 guarantees.

## Minimum production controls
HTTPS/restricted SSH, private MySQL (no public 3306), patched OS/images, non-root services, disk/log limits and restart/health checks. Separate runtime/migration/backup credentials, protected secret injection, no real secrets in examples.
API liveness tests process; readiness tests required dependencies with bounded cheap calls. Data Protection keys persist securely across restart; private branding/receipt assets persist separately. Trust forwarded headers only from the proxy; reserve /api for .NET; no shared cache for authenticated responses.
Build pinned Node/Next production output with assets, .NET runtime and reviewed DB image. Smoke actual images rather than only development servers. Environment values must not place secrets in NEXT_PUBLIC_. No automatic migration at startup.

## Release
Review small change/tests/schema/guard impact; identify artifact/version. Rehearse reviewed migrations on an isolated copy, confirm backup and single migrator, execute only against explicitly approved target, deploy compatible app, smoke role/scoped flows, reconcile affected operational data.
MySQL DDL auto-commits. Stop on partial failure; no blind retry/drop or fictional transactional rollback. Roll application back only when schema-compatible; data corrections need an approved forward migration or linked business correction. Production deploy/migration approval remains explicit.

## Backup and restore
Before launch agree acceptable data-loss window, recovery time, retention, storage and who checks failures. Proposed simple starting policy is encrypted nightly off-host full backup of DB plus versioned branding assets and recoverable key material, with retention agreed; add binlog/PITR if the business needs a shorter loss window. Nightly alone cannot meet a 15-minute RPO. Do not promise the historical targets.
Keep keys/backup credentials separate from public app access. Check backup age/failure and disk usage. Rehearse an isolated full restore, verify roles/tenant isolation, quantity/value/reservation/transit, completed manufacture, documents/receipt assets and manual payment totals. Revoke restored sessions before service resumes; restored revocation/password state and post-backup real-world sales must be reconciled.
Keep immutable logo assets referenced by posted receipt snapshots; do not delete an old asset still used by history. Describe DB/file snapshot consistency and test missing-file recovery.
A tenant-only restore in a shared database is not supported by overwriting the whole database. Restore full backup into isolation, review a consistent tenant extraction and later operations if such recovery is needed; do not promise a self-service recovery product.

## Minimal monitoring and incidents
Structured redacted errors/correlation IDs, health, disk/backup age, DB connections/lock waits, failed transactions and stock/transit reconciliation. No analytics/observability platform required.
If stock integrity is threatened, stop affected posting, preserve evidence, inspect original idempotent operation/documents/entries, approve correction, reconcile and record incident. Never edit balances manually.
For a lost response retry/query original operation. For restore data loss compare actual stock, printed receipts and manually received money before reopening; online-only does not remove real-world recovery work. No provider/offline reconciliation runbook is required in Phase 1.
