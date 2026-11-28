# Revised Phase 1 implementation plan

Current authorization supersedes the earlier P1-02 stop: P1-03a/b and separate SQL 0003–0005/isolated upgrade+clean tests approved. Scope and evidence: docs/21_OUTLETS_WAREHOUSES_USERS_IMPLEMENTATION.md. Stop for owner review before P1-04. No inventory/transfer/manufacture/POS/display operations are authorized by P1-03.


## P1-08d customer display
Alongside billing implement Open Customer Display and read-only fullscreen route, random per-checkout BroadcastChannel, allowlisted DTO, provisional versus committed totals/payment, transaction/revision ordering, resync/heartbeat and clear/reset. Test two windows, multiple cashier instances, stale/reconnect and logout/context isolation. No real-time server or pairing table initially. [Full specification](20_CUSTOMER_DISPLAY.md).

**P1-02 accepted. P1-03a/b and isolated 0003–0005 execution approved 28 November 2026. Stop before P1-04. Actual progress: docs/21_OUTLETS_WAREHOUSES_USERS_IMPLEMENTATION.md.**

## Goal and delivery boundary
Deliver a useful online operational system for a coconut manufacturer with one or two operators. Accuracy/isolation/transactional history remain essential; full accounting, advanced manufacturing/QC and offline/integration platforms are future scope. Requirements: docs/01_REQUIREMENTS.md. Proposed 38-table design: docs/03_DATABASE_DESIGN.md. Original requirements and SQL remain preserved.

## Approval boundaries
1. The owner accepted P1-02 and authorized P1-03a/b only. Stop at P1-03 completion for review; do not infer permission for all stages.
2. The owner approved docs/22_P1_03_DATABASE_REVIEW.md's 0003–0005 package, review upgrade and isolated clean install/tests. New SQL/targets and production remain separately gated.
3. Before each later posting slice approve its business rules, schema differences and focused tests. A planned future feature does not authorize implementation now.
4. Production deployment and live data import remain separate gates after operational acceptance/recovery verification.

## P1-01 minimal foundation — authorized implementation
Dependencies satisfied: owner approval, pinned compatible tools and .NET 10. Docker Linux engine is now available; previous unavailability is historical. Actual files/versions/checks are in the foundation report.
Deliver:
- Preserve existing work; establish a short feature branch when implementation is authorized, with no automatic commit/push.
- Pin .NET SDK/runtime and compatible Node/Next/React/TypeScript/npm versions. One package lockfile. No app dependencies installed during this documentation revision.
- Create four backend projects with enforced dependency direction, nullable/analyzer settings and a minimal API health/problem-details contract. No empty future modules, Finance, Worker, outbox, auth provider framework or generic repository layer.
- Create Next.js App Router shell, a typed API health call, accessible loading/error states and server-only configuration boundary. No fake login/dashboard or unfinished menus.
- Minimal editor/build settings and GitHub CI for reproducible backend/frontend checks, explicit lint/typecheck and production build. Pin reviewed tools/actions.
- Prepare small local Docker/Compose/proxy configuration and instructions where useful; starting containers with an empty database volume/credentials is not authorized by this scaffold task. No migration files/stubs or database bootstrap hook.
Acceptance: restore/build/analyzers and appropriate focused tests; frontend locked install/lint/typecheck/production build; shell/API routing smoke if runtime available. Document failed/unavailable checks. A container MySQL test is deferred until execution is approved; do not call DB readiness complete.
Exit: reproducible minimal shell/API and an evidence report. No business functionality claim. The first real use case follows in P1-02.

## Functional stages and smaller review slices
| Stage | Narrow delivery slices | Prerequisites and database boundary | Essential acceptance |
|---|---|---|---|
| P1-02 Auth/business | 02a reviewed identity/default-company schema and controlled setup; 02b login/logout/password/session; 02c profile/logo | Approve cookie/recovery policy, initial DDL/safeguards, isolated MySQL target; identity/membership/company/audit/idempotency tables only as needed | Two-tenant and shared-user boundaries, atomic company setup, secure cookies/CSRF/revocation, scoped file/profile and no shared private cache |
| P1-03 Locations/roles | 03a outlets/ordinary warehouses/default locations; 03b Staff grants and hidden transit | Simple Admin/Staff matrix; no warehouse-level grants UI unless client requires it | Staff only granted outlets, no NULL-branch transit bypass, exactly one internal company/transit warehouse |
| P1-04 Catalog/suppliers | 04a categories/items/base units; 04b alternate units/barcodes/prices; 04c supplier records | Item list, dimensions/conversions and company currency; parties supports later customer flag/UI | Scoped uniqueness, positive exact conversion, correct barcode-item unit, price versions and no historical rewrite |
| P1-05 Stock/incoming | 05a document/line/number/guard foundation and opening stock; 05b incoming receipt/batches/cost; 05c warehouse stock/history | Approve decimal/rounding/expiry/cost policy; introduce document, receipt, lot and stock tables; no enterprise seeds | Real MySQL concurrent last stock/rollback/replay, required lot/date/cost, quantity/value reconciliation, immutable facts |
| P1-06 Transfers/counts | 06a request/reserve/cancel; 06b dispatch/full/partial receipt; 06c damage/loss/return resolution; 06d adjustment/waste; 06e stock take | Exact allocation/cumulative/value design and count-freeze policy; add reservation/allocation/count tables incrementally | 100/20 example, concurrent receipts/dispatches, pooled-transit isolation, residuals, reserved-stock protection and freeze race |
| P1-07 Manufacture | 07a one actual-input/output run; 07b bulk-to-packaging run and basic trace | Client accepts completed-run, one finished item/lot, same-factory-warehouse and input-cost policy; production_events header only | All inputs/output commit or none; original lots/dates trace; carried input/output cost reconciles; no WIP or recipe engine |
| P1-08 POS/contacts/payments | 08a customer UI and cash sale/receipt; 08b manual split/partial payments/discount; 08c linked returns/refunds | Prices/rounding, Staff/Admin limits, unpaid-sale policy, original-issue returns and browser print accepted; sales/return/payment tables | Last-unit race, original receipt on retry/reprint, exact change/totals, return/refund caps and damaged/expired stock rules |
| P1-09 Reports | 09a stock/transit/expiry and incoming; 09b manufacture/sales/payment/outstanding/audit | Existing committed facts; bounded current SQL/CSV/print, no report warehouse or job system | Scope, date/currency and quantity/value/amount reconciliation; no accounting-statement claims |
| P1-10 Launch/recovery | 10a staging/client workflow UAT; 10b secure production runtime/proxy; 10c off-host backup/restore/training | Agreed scope, actual hardware, VPS/secrets, loss/recovery/retention and opening data | Isolated restore, sessions revoked after restore, stock/transit/sale/payment reconciliation, measured recovery and client sign-off |

Every stage includes unit/integration/browser checks relevant to its changes. Tests and security do not wait until stage 10. Tables are introduced for working features, not as a 38-table scaffold/CRUD generator.

## Approved technical directions and foundation choices
- Four-project modular monolith, focused use cases and parameterized MySqlConnector stock commands; no mandatory ORM/mediator.
- Next.js App Router/Node runtime and same-origin /api to .NET; private data not shared-cached; no direct frontend DB.
- Vetted .NET cookie/password primitives with revocable sessions; controlled onboarding/reset and simple two-role outlet policy.
- Independent Phase 1 schema with one company per tenant, reusable scoped document/stock identities and exact allocation records.
- Per-bucket moving-average operational carried cost, six-place residual allocation, FEFO physical choice; no accounting valuation claim.
- Short warehouse count freeze and completed one-output manufacturing instead of concurrent roll-forward counts/WIP.
- Single currency and final operational prices/discounts, manual payment evidence, original-sale returns; browser print/manual weights initially.
- Short branches/protected main, one npm lockfile and minimal CI/Compose; reviewed dedicated migration tool selected before DB work.
The owner approved the Phase 1 architectural directions and starting schema; additional tables are allowed when justified. Operational policy values/final DDL still need the dependent slice's review. GitHub main protection and actual production setup are not configured by a local scaffold.

## Open inputs by dependency
Foundation: approved; versions pinned, .NET 10 available and Docker engine restored independently before this task. Workspace Node avoids any machine-wide upgrade. No remaining planning approval blocks P1-01.
Before auth/live: password/session/recovery/MFA launch policy and safe shared-identity operations; actual business name/logo/currency/timezone/rounding and contacts.
Before stock/transfers: actual outlet/warehouse layout, items/UOMs, opening lots/costs, expiry boundary, default dispositions and correction/reservation rules.
Before manufacture/POS: completed-run fit and waste policy; permitted discounts/unpaid sales/manual tenders/returns/refunds, paper/browser/scanner/manual-weight suitability. No direct scale integration without separate scope.
Before launch: hosting/DNS/access, backup location/keys/retention/loss window/recovery target and client acceptance. No tax/accountant/journal/period/offline readiness prerequisite for stock; do not claim receipts meet an unreviewed legal use.

## Validation and change report
The original revision archived/hash-verified enterprise references; P1-01 delivered the accepted foundation. P1-02 now introduces reviewed identity/business SQL and functionality under explicit code and isolated execution approvals; actual evidence is in docs/19. Historical SQL remains untouched. Inventory concurrency, hardware integration, full backup restore and production launch are not claimed by P1-02.
