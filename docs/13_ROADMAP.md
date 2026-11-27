# Phase 1 roadmap
This ten-stage order replaces the enterprise M0-M7 delivery commitment. Build a useful tested vertical slice each time; no dates promised without capacity/client decisions. Details: [implementation plan](14_PHASE1_IMPLEMENTATION_PLAN.md).

P1-01 is accepted. P1-02 is authorized with separately approved auth-review database execution; evidence is in docs/19. Stop for owner review before P1-03. Customer Facing Display is mandatory in P1-08 (docs/20), not a P1-02 deliverable. Later stages remain future work.

| Stage | Working result | Exit gate |
|---|---|---|
| P1-01 Foundation | Minimal four-project .NET solution, Next.js shell, pinned tools, basic CI/local runtime instructions | Builds/checks work; no business scaffold generator, DB execution or future infrastructure |
| P1-02 Auth/tenancy/business | Login/session, controlled tenant/default-company setup, profile/logo | Two-tenant isolation, revocation/CSRF, atomic setup and private branding |
| P1-03 Outlets/warehouses/roles | Admin/Staff, scoped grants, ordinary/default and hidden transit locations | Staff scope enforced, no company UI or transit bypass |
| P1-04 Products/UOM/suppliers | Catalog/categories/SKUs/item units/barcodes/basic prices and supplier entry | Exact conversion, scoped uniqueness and historical snapshot contract |
| P1-05 Inventory/incoming | Opening/incoming documents, lots/dates, ledger/balances/basic costs, stock view | Real MySQL replay/concurrency/rollback/guards; quantity/value reconcile without finance |
| P1-06 Transfers/adjustment/waste/counts | Reserve/dispatch/transit/partial receive/resolution; Admin changes and count freeze | Numerical transfer story, allocation residuals, races and correction evidence |
| P1-07 Basic manufacture | Actual inputs and one finished output lot per completed run | Atomic consumption/output, cost carry and batch trace; no WIP/recipe/QC platform |
| P1-08 POS/payments/customers/returns/display | Online sale, discounts/manual payments/receipt, returns/refunds and dual-screen customer display | Exact snapshots/totals, caps, safe retry/print/stock permissions; isolated display DTO, two-window ordering/reconnect and authoritative payment confirmation |
| P1-09 Dashboard/reports | Bounded operational stock/transit/expiry/incoming/manufacture/sales/payments/audit reports | Authorized totals reconcile; no financial-statement/analytics claims |
| P1-10 Deployment/recovery | Client UAT, production runtime/proxy, secure VPS, tested off-host backup/restore | Launch checklist, hardware acceptance, restore evidence, training/support responsibility |

Every stage includes relevant tests, audit, migration/guard review and documentation. Stage 10 consolidates deployment and recovery acceptance; it does not defer security, tests or backup design until the end.
Database migrations are incremental Phase 1 scripts reviewed for each dependent slice; approving P1-01 does not authorize creating/running any database. Recheck tool availability before implementation.
Future modules and historical prerequisites are [separate opportunities](17_FUTURE_PRODUCT.md), not additional Phase 1 gates.
