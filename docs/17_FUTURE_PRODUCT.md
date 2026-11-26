# Future Conex360 product opportunities
These capabilities remain part of the long-term vision, not Phase 1 requirements, implementation dependencies or launch gates. The original detailed descriptions are preserved in [the 24 November knowledge-pack snapshot](reference/enterprise_baseline_2026-11-24/README.md), original 23 November references, and the unchanged database/reference/01_schema.sql.

| Future area | Possible scope | Prerequisite before a later implementation |
|---|---|---|
| Finance | Double entry, chart of accounts, journals, open items, settlements, financial periods/reports, banking/FX | Explicit scope/accounting policy and opening cutover; no fabricated historical entries from operational costs |
| Tax/statutory | Tax engines, invoice localization/filing, statutory/legal/payroll compliance | Approved jurisdiction rules and validated implementation; no Phase 1 tax claims |
| Multiple companies | Legal-company UI/grants/intercompany/consolidation | Remove one-company unique constraint, add grants and accounting/legal boundaries; transfers remain same-company |
| Advanced purchasing/sales | PO/requisitions/quotes, supplier invoice/AP matching/returns/credits, wholesale orders/delivery/invoice split | New type-specific quantity/amount caps and no double stock issue/receipt |
| Advanced manufacture/costing | Recipes/versions, routing/planning, joint products/byproducts, WIP, labor/overhead/late cost/FIFO layers, outsourcing | Reviewed costing conversion/cutover, lot trace, actual process and reconciliations |
| Advanced quality/recall | Specifications/results, inspection approval, recall cases/genealogy notifications | Process evidence, controlled stock blocking and verified trace; do not infer past inspections |
| Workforce/assets | HR/payroll/time/leave, machinery/depreciation/maintenance | Separate sensitive access and approved localization/accounting |
| Loyalty/promotions | Points, gifts, complex prices/promotions and customer credits | Explicit rules, caps and abuse/reversal tests |
| SaaS automation | Subscription billing, self-service onboarding, entitlements/support console | Product/commercial policy and explicit audited support boundaries |
| Offline/devices | Managed till, encrypted SQLite, quotas, durable operations, ordered sync/conflicts | Separate reviewed durable device design; no browser-cache last-write-wins checkout |
| Integrations | Provider payments, scales/printers/local services, ecommerce/accounting/export jobs | Actual vendor/protocol and recovery/idempotency/security scope; outbox/worker only when needed |
| Advanced reporting/planning | Analytics/MRP/replenishment/capacity/forecasts | Measured requirement, correct source facts and rebuildable projections |
| Scaling architecture | Separate workers/read replicas/shards or extracted services | Measured limits and approved consistency/operations design; not initial infrastructure |

Sound invariants survive expansion: tenant/company keys, stable item/document/line IDs, immutable movements with quantities/cost evidence, source-linked transfer/return facts and explicit migrations.
Some Phase 1 proposals deliberately differ from the historical schema: average operational cost, shared simple lines, one-output completed manufacture, local sessions and static roles. Future migration may require backfill, unique/FK changes and a controlled policy cutover; no promise that the 160-table DDL can be applied unchanged.
Historical guards/seeds/reconciliation files remain unavailable. Their recovery is future reference work, not permission to skip the smaller Phase 1 protections or delay operational inventory for full accounting.
