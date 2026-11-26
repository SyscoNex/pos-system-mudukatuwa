# Development roadmap — ordered backlog
No dates estimated; milestones depend on client scope, capacity and review. Build vertical slices, not all 160 tables as CRUD endpoints. No production go-live until agreed essential workflows and offline readiness (if required) pass.

| Milestone | Work | Exit gate |
|---|---|---|
| M0 — Foundation | Repo, AGENTS, version verification, scaffold solution/UI, CI, local MySQL, migration strategy, missing companion SQL review | Build and reproducible test environment; architecture ADR; no unsafe DB bootstrap. |
| M1 — Tenant & document core | Auth, tenant/company/branch/warehouse setup, roles/grants, brand config, catalog/UOM, document sequences/status, audit/outbox/idempotency, finance account/period primitives | Two-tenant isolation, role tests, migration install and guard coverage. |
| M2 — Inventory & purchasing | Buckets/lots/ledger/balances/reservations, opening stock, PO/receipt/supplier match, count/adjustment, reorder/expiry, outlet stock dashboards, transfer request/approve/dispatch/receive/exception and cost/accounting | T04–T13, T20 pass; factory-to-outlet partial transfer demo; stock/value reconcile. |
| M3 — Production and QC | Recipes/versions, plans, material issue/return, bulk & packaging output, waste/yield, WIP, inspections/release, recall | Multi-lot trace and WIP settlement demo, tests T14–T15. |
| M4 — Sales/POS & finance | Checkout, registers/sessions, price/tax, weighing, print, wholesale delivery/invoice, payments, credit/returns, expenses, AR/AP reports and period close | T04–T06, T16–T17, T19, T22; finance approval, no duplicate stock/payment. |
| M5 — Offline & devices | Managed device identity, local encrypted DB, quota, feed/sync, durable inbox, supervisor recovery, hardware validation | T11/T18/T22; lost device/restart/replay tested; pilot policy signed off. |
| M6 — Pilot readiness | Reports/exports, migration/import rehearsal, staging UAT, backup restore, load/security checks, documentation/training | T21–T24; client sign-off, release runbook, support readiness. |
| M7 — Growth modules | Planning/MRP, loyalty/promotions, subscriptions automation, banking, assets, staff/payroll, other integrations | Each module separately scoped, feature-gated and tested. |

## First sprint proposed backlog (not committed)
- M0-01 review docs and establish ADR for stack/provider versions and branch strategy.
- M0-02 scaffold modular .NET projects and Next.js + TypeScript App Router shell (proposed routing convention); add editorconfig, gitignore, dependency lock and CI checks.
- M0-03 local disposable DB setup, schema comparison, guard/seed/reconciliation recovery or approved reconstruction; record checksums and migration plan.
- M0-04 integration harness with two tenant fixtures; verify DB installation, no production credentials, baseline build.
- M1-01 implement tenant context and grants; isolation tests before business CRUD.

For each milestone create issue IDs, user story, acceptance criteria, dependencies, tests and owner. Commit documentation and ADRs along with approved code. Keep incomplete modules disabled. Start with M0 planning using CODEX_START_HERE.md.

M0 frontend acceptance: pinned compatible Node/Next.js/React/TypeScript versions, committed lockfile, approved folder/routing/session plan, successful lint/typecheck/test/build, production Node container smoke, Nginx route validation, and tenant-safe caching test plan. No offline checkout implementation during scaffold.
