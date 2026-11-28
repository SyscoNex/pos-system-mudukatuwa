# AGENTS.md — Conex360 Phase 1

P1-06 is accepted. P1-07 and its approved migration 0012, scoped runtime grants and isolated tests are complete. Stop before P1-08 for owner review. Preserve Workbench on localhost:3307, historical references, and SchoolGrid. [Current handoff](docs/29_MANUFACTURING_IMPLEMENTATION.md) · [SQL review](docs/30_P1_07_DATABASE_REVIEW.md)

P1-05 is accepted. P1-06 implementation and separate 0010–0011 execution were approved for conex360-auth-review and private conex360-p106-clean. Both schema installations passed. Stop before P1-07. Preserve read-only Workbench on localhost:3307 and exclude SchoolGrid and production. [Current implementation](docs/27_STOCK_OPERATIONS_IMPLEMENTATION.md) · [SQL review](docs/28_P1_06_DATABASE_REVIEW.md)

P1-05 is implemented and verified. SysConex approved the inventory policies, SQL 0008–0009 and associated grants on 28 November 2026 for conex360-auth-review and private conex360-p105-clean. Stop at P1-05 for owner review. Preserve Workbench localhost:3307 and exclude SchoolGrid. [Implementation handoff](docs/25_INVENTORY_INCOMING_IMPLEMENTATION.md)
These instructions apply to the repository. Owner: SysConex. Current scope was revised by the product owner on 25 November 2026. Deliver a reliable operational system for a coconut manufacturer with one or two operators; retain a maintainable product foundation.

## Authority and current task gate
- P1-03 accepted; P1-04a/b/c implementation and the concrete docs/24_P1_04_DATABASE_REVIEW.md package separately approved on 28 November 2026. Execution covers only 0006–0007, scoped catalogue grants, conex360-auth-review upgrade and private conex360-p104-clean installation/synthetic tests. Current handoff: docs/23_CATALOG_SUPPLIERS_IMPLEMENTATION.md. Stop before P1-05; new SQL remains gated. Preserve Workbench localhost 3307 and exclude SchoolGrid. Earlier milestone gates below are historical authorization records superseded by this current boundary.
- P1-02 accepted; P1-03a/b implementation authorized on 28 November 2026. Owner separately approved 0003–0005, scoped runtime grants, upgrade of conex360-auth-review and private conex360-p103-clean tests; see docs/22_P1_03_DATABASE_REVIEW.md. Other SQL/targets remain gated. Preserve existing Workbench documentation. Stop before P1-04. SchoolGrid's Docker project `database` is excluded from all changes. Current handoff: docs/21_OUTLETS_WAREHOUSES_USERS_IMPLEMENTATION.md.
- Read README.md, docs/00_PROJECT_OVERVIEW.md, docs/12_DECISION_LOG.md and the relevant module specification before work.
- The owner's Phase 1 scope supersedes the earlier enterprise baseline. Historical references, including archived AGENTS_BASELINE.md, are not current instructions.
- On 28 November 2026 the owner accepted P1-01 and authorized P1-02a/b/c code, dependencies, incremental migration preparation and isolated local tooling. Database initialization/migration execution still requires separate review/approval of the concrete DDL and disposable target. Continue independent work while awaiting it; no production data or unrelated Docker changes. Stop after P1-02 for review before P1-03.
- The owner subsequently approved executing 0000–0002 and synthetic tests only in the new conex360-auth-review target, database conex360_auth_review, with no published MySQL port. This does not authorize production, historical SQL, other databases or P1-03. Evidence/runbook: docs/19_AUTH_BUSINESS_IMPLEMENTATION.md; concrete review: docs/21_P1_02_DATABASE_REVIEW.md.
- The owner subsequently requested MySQL Workbench inspection on 28 November 2026. Optional infrastructure/compose.workbench.yaml publishes only 127.0.0.1:3307 for this existing review database; scripts/Enable-WorkbenchAccess.ps1 provisions a separate SSL-required SELECT/SHOW VIEW account. This refines the earlier no-port boundary only for local inspection, not production, schema migrations or later milestones. Runbook: docs/LOCAL_MYSQL_WORKBENCH.md.
- State the small slice, affected modules, security/stock/cost impact, assumptions and validation. Do not generate the whole application or all proposed tables at once.
- Preserve database/reference/01_schema.sql byte-for-byte. Phase 1 has its own proposed smaller schema; review its design and migrations independently. Do not bootstrap the historical 160-table schema or fabricate records to satisfy its dependencies.

## Phase 1 boundaries
Include authentication/sessions, tenant isolation, Administrator/Staff, business branding, outlets/warehouses, catalog/UOM/barcodes/prices, suppliers/customers, operational stock, transfers, counts/waste/adjustments, basic manufacture, online POS/receipts/payments/returns, same-computer customer-facing display, reports/audit/backups. Customer-display operational code belongs to P1-08, not P1-02; see docs/20_CUSTOMER_DISPLAY.md.
Exclude general ledger, journals, accounting periods, tax engines, statutory modules, advanced costing/WIP/QC, approval hierarchies, payroll, loyalty, subscriptions, offline billing/sync, integrations and microservices. See docs/17_FUTURE_PRODUCT.md. Do not add infrastructure for these features.
One default company is created per tenant; retain company scope internally and expose Business settings instead of legal-company administration.

## Non-negotiable invariants
1. Resolve scope from authenticated user, active membership and authorized resource. Every business query/join/mutation/file/cache/report uses tenant and company, plus branch/warehouse restrictions. Client IDs are selectors, never authority. Ordinary transfers cannot cross tenant or company.
2. Inventory alone appends stock_entries and updates locked stock_balances. Exact decimal base quantities; no negative physical stock or over-reservation. Posted facts are immutable. Opening stock and corrections are documents, never direct balance edits.
3. Dispatch atomically moves source to dedicated transit; receipt consumes the exact dispatch allocation and preserves lot, quantity, condition and carried cost. Partial receipts, damage, loss and returns have explicit evidence. No double decrement, duplicate receipt or unexplained disappearance.
4. FEFO physical selection considers expiry/hold eligibility. Per-bucket moving-average operational cost with carried transfer costs is approved; detailed rounding/expiry policies remain to be finalized before posting. Do not silently implement enterprise FIFO, cost layers, COGS, journals or WIP.
5. One command commits document/lines, inventory entries/projections/reservations, relevant operational payment records, audit and idempotent result in one MySQL transaction. There is no general-ledger dependency. Never insert fake financial entries.
6. Online only. No service-worker checkout, offline stock quotas, device sync, background payment provider or last-write-wins stock.
7. Use C# decimal, MySQL DECIMAL, decimal strings and string IDs in JSON; no JavaScript floating-point money/quantity arithmetic. Validate precision, limits and intermediate overflow. UTC timestamps and configured local business dates.
8. Secrets never enter source, browser bundles or logs. No destructive actions, production migrations/deployment, commit/push/merge or paid service setup without explicit authorization. Report only actual test results.

## Engineering
ASP.NET Core/.NET 10 LTS, MySQL 8.4/InnoDB, Next.js/TypeScript, modular monolith; Clean Architecture where useful. Follow SOLID without generic repository frameworks, mandatory mediator/event-bus layers or empty future modules. Use explicit parameterized MySqlConnector SQL for inventory; an ORM needs compatibility review.
Domain has no HTTP/SQL dependencies; application use cases own transaction boundaries; infrastructure implements focused adapters. DTOs are not database entities. Async I/O, cancellation, nullable reference types, structured errors/logging.
Use expected versions for mutable edits and stable locking order for commands. Scoped composite FKs and supporting indexes supplement authorization. Test nullable relationships and cross-row business rules.
Real MySQL tests are mandatory for inventory concurrency, rollback, constraints and replay. No SQLite/in-memory substitute for InnoDB behavior. Keep migration identity separate from runtime; no automatic API-startup migrations.

## Frontend
Next.js App Router, same-origin .NET API and Node production runtime are approved. Next.js never connects to MySQL or owns authorization/posting. Prefer direct browser calls to .NET and limited server reads; do not add a separate BFF without need.
Private HTML/RSC/API data must not enter shared caches. Clear scoped client state on logout/outlet change and enforce permissions again in .NET. Use supported cache controls for pinned versions; keep secrets server-only, never NEXT_PUBLIC_.
Pin compatible Node, Next.js, React, TypeScript and one package manager/lockfile after verification. Treat any Server Action/Route Handler as externally callable.

## End of task
Report files, commands/results/failures, migration impact, security/inventory risks, open decisions and untested behavior. A scaffold is not completed functionality. Follow docs/09_ENGINEERING_STANDARDS.md.
