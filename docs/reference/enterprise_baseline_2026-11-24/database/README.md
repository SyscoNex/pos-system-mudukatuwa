# Database reference and bootstrap warning
`reference/01_schema.sql` is the exact original schema from 23 November 2026. It creates 160 tables and adds 636 foreign keys on a NEW EMPTY selected MySQL 8.4 database. No DROP. It is a historical reference, not an approved active migration. Do not run it against an existing database, automatically from startup, or with application runtime credentials.

The earlier technical document calls for these companion files, which were not available in the retrieved project materials:
- `02_guards.sql` — database protections for posted/immutable facts and lifecycle rules.
- `03_reference_seed.sql` — validated reference currencies, permissions, and other required seed records (review actual intended content).
- `04_reconciliation_queries.sql` — parameterized diagnostics; not a migration.

Recover the originals if possible; otherwise design and review equivalent versioned scripts. Do not create empty placeholders, pretend they exist, or relax safeguards to make a demo work. Verify actual guards, reference data, and reconciliation logic on MySQL before any posting feature is enabled. Review transfer allocation/linkage and cost lineage gaps as outlined in docs/04_INVENTORY_AND_TRANSFERS.md. No new active migration is supplied in this pack.

M0: inspect all DDL and actual relationships, pin MySQL version, create an isolated empty disposable DB, apply reviewed migrations using dedicated account, verify schema/constraints/guards, test upgrade and reconciliation, document checksum/version and failure handling. MySQL DDL auto-commits; discard only a known disposable failed initialization with explicit approval, never a live database. Use strict SQL and UTC sessions. No disabling FK checks to conceal issues. Production migrations use a controlled deployment job and backup readiness.
