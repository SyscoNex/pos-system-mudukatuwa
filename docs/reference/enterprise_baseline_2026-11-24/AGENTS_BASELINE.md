# AGENTS.md — Conex360
These instructions apply to the entire repository unless a more specific approved instruction file applies. Product owner: SysConex. The goal is commercial-grade, maintainable software, not a throwaway demo.

## Before changing code
- Read README.md, docs/00_PROJECT_OVERVIEW.md, docs/12_DECISION_LOG.md and the relevant module specification. Inspect existing code, migrations and tests before proposing changes.
- State scope, affected modules, security/stock/accounting impact, assumptions and test plan. Make a small vertical slice; do not implement every planned feature in one pass.
- Use the original schema reference as a design input. Do not run it on an existing DB or generate a competing schema. Missing guards/seeds must be reviewed and tested before posting is enabled.
- Do not invent business policies (tax rates, rounding, QC thresholds, credit limits, receipt requirements, approval thresholds). Use configurable, validated policies and record unresolved decisions.

## Non-negotiable invariants
1. Shared multi-tenant platform. Every business record, join, cache, background job, search, export and file access is scoped by authenticated tenant and company, with branch/warehouse permission where required. No trusting a tenant ID from a request body. No cross-tenant transfer; same legal company only for ordinary transfers.
2. Inventory owns stock entries, locked balances, reservations and cost layers. All quantities are exact decimal base units. Never mutate stock directly from POS, procurement, production or UI; no negative stock or implicit adjustment. A posted movement is immutable and corrected with a linked compensating document. Opening stock is also a posted document.
3. Transfer dispatch moves stock from the source to a dedicated transit location; receipt moves that same stock to destination, including actual lot, owner, quantity and condition. Partial receipts are supported. No double decrement, silent loss, negative transit, or premature destination availability. All posting operations are idempotent and concurrency-safe.
4. FEFO physical lot picking (subject to QC/expiry eligibility); FIFO valuation in defined pools. Traceability and financial costing are separate. Transfers preserve value, not sales/revenue/COGS. Cost pool and origin lineage decisions must be tested.
5. Finance owns balanced immutable journals and open items. Stock and financial postings that belong to one command commit together. A payment provider call is outside the DB transaction and must be reconciled. Closed periods cannot be silently reopened or bypassed.
6. Offline sales are allowed only through a reviewed durable device/outbox/quota design. Never implement last-write-wins stock or payment sync. No unconstrained browser-cache checkout.
7. Secrets never enter source control, frontend code, logs or examples. No destructive commands, production migrations/deploys or external paid service setup without explicit approval. No invented test results.

## Implementation standards
- ASP.NET Core/.NET 10 LTS, MySQL 8.4/InnoDB, modular monolith, Next.js with TypeScript (confirmed frontend framework; App Router proposed). Prefer MySqlConnector explicit parameterized SQL for critical posting; ORM adoption needs provider validation and an ADR. Pin supported versions after verification.
- Domain is independent of infrastructure; application handlers coordinate modules and transactions; APIs use DTOs, not DB entities. Prefer straightforward maintainable designs over unnecessary patterns. Async I/O, cancellation tokens, nullable reference types, structured error handling.
- Use decimal (C#), DECIMAL (MySQL), decimal strings for quantities/money and string IDs in JSON; no JS floating point financial arithmetic. UTC event times and separately configured local business dates.
- Enforce optimistic versions for mutable data; locking reads and stable lock order for posting. Parameterize every query. Add composite scoped FKs and supporting indexes; ensure nullable/composite constraints really enforce the intended relationships.
- Unit, real MySQL integration and end-to-end tests as appropriate. Include tenant isolation, permission, duplicate/replay, concurrency, rollback and reconciliation tests for any posting change.
- Follow docs/09_ENGINEERING_STANDARDS.md. Do not modify unrelated code or rewrite history. Do not commit/push/merge unless asked. Update documentation and decision log when behavior changes.

## End of task report
Summarize implemented files, commands actually run, results and failures, migration impact, risks and open decisions. State what was not tested. Do not describe a scaffold as complete functionality.

## Frontend rules
- Use Next.js, not Angular or a standalone React/Vite scaffold. Use App Router unless an approved ADR changes it. Keep ASP.NET Core as the sole authority for business operations, tenancy, stock, payments and finance. Never connect Next.js directly to MySQL or duplicate posting logic in route handlers or Server Actions.
- Use Server Components for suitable read-only layouts/views and Client Components for interactive POS, scanners and device integrations. Authenticated tenant-specific pages/API reads must not enter shared caches; explicitly opt out of caching and prevent stale context data on tenant/outlet changes. Treat every Server Action/Route Handler as an externally callable endpoint requiring appropriate authorization. Keep secrets server-only; never expose them via NEXT_PUBLIC_ variables.
- Verify compatible Next.js, React, Node LTS and TypeScript versions, commit one package-manager lockfile, and build a production Node runtime image. Do not replace the .NET API with Next.js API routes.
