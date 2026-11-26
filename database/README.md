# Phase 1 database boundary
The Phase 1 starting design is approved in [database design](../docs/03_DATABASE_DESIGN.md), with complete historical mapping in [schema differences](../docs/15_PHASE1_SCHEMA_MAPPING.md). No active migration or DDL for it is supplied yet. P1-01 contains no MySQL dependency, connection, service, volume or initialization; database work begins only after the next slice's DDL/target authorization.

## Independent operational database
Propose 38 application tables, introduced by functional slice, plus migration-tool bookkeeping if needed. Retain tenant/company keys but provision one company per tenant. No accounts, journals, accounting periods, WIP, tax, offline or enterprise seed dependencies.
After design and execution approval, create versioned reviewed Phase 1 migrations for a NEW isolated database. Never run the enterprise SQL and then add fake financial rows or disable constraints.
Use strict SQL, UTC, InnoDB, utf8mb4, parameterized queries and a separate migration identity. Verify each slice's checks, composite FKs, immutability protections, reference setup and reconciliation on real MySQL before enabling its operations.
A checked-in migration is not permission to execute it. No startup migrations, production credentials or automated database deletion.

## Preserved historical reference
reference/01_schema.sql remains the exact 23 November enterprise schema: 160 tables, 1,784 columns, 636 FKs and 173 CHECKs by static inspection; no triggers or seed INSERTs. SHA-256:
1810fe5af34702fa8b475aa1cbe3cb16f87b0e00a8b3d9f6361ce2fcc0f3fd32
It has not been executed or validated by this task.

Historical companion files 02_guards.sql, 03_reference_seed.sql and 04_reconciliation_queries.sql remain unavailable. Preserve that fact for future enterprise work. Recovering/recreating all enterprise scripts does not block the independent Phase 1 implementation; its own safeguards are mandatory.

## Execution and evolution
Use checksum-tracked migrations in a controlled job/command, not every API instance. Check the target identity and environment before execution. Test clean install and upgrades from the preceding implemented slice/release; first release has no real prior-release upgrade.
MySQL DDL auto-commits: stop on partial failure and preserve evidence. No blind rerun, FK disabling, destructive reset or pretending DDL rolls back. Any removal of a failed disposable database needs explicit authorization.
The Phase 1 schema is the future migration starting point. Extend it using reviewed additive/backfill/constraint migrations; never overlay the 160-table file onto it. Operational cost history is not a historical general ledger.
