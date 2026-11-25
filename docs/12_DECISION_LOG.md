# Decision log — Phase 1
**25 November 2026.** Confirmed = owner-approved direction; Proposed = awaits design approval; Open = unresolved before dependent slice; Partial = implemented/decided in part; Superseded = historical gate. P1-01 application/dependency work is explicitly authorized; database execution and P1-02 are not.
The complete D01-D20 enterprise decision log is preserved in [the archived baseline](reference/enterprise_baseline_2026-11-24/docs/12_DECISION_LOG.md).

## Supersession
D01/D02/D04/D19 remain: Conex360/SysConex, isolated multi-tenant platform, outlet transfers, .NET/MySQL/VPS and Next.js/TypeScript.
D03's offline delivery and D07's mandatory FIFO/finance/offline bundle are deferred; batch/manufacture scope is simplified. D05 retains tenant/company/branch/warehouse/location structure with one company initially. D09's allocation integrity remains but no accounting posting. D12's missing enterprise SQL is historical, not a Phase 1 blocker. D14-D18 inputs apply only where relevant; finance/tax/offline/advanced policies no longer block operational foundation. D08/D10/D13/D20 proposals are not automatically approved.

| ID | Status | Decision / impact |
|---|---|---|
| P01 | Confirmed | Lightweight first-client operational release for one/two operators; broader product remains future scope |
| P02 | Confirmed | Authentication/sessions, Admin/Staff, isolated tenants, branding, outlets/warehouses, catalog/prices/contacts, stock/transfers/counts/waste, basic manufacture/POS/payments/returns/reports/audit/recovery |
| P03 | Confirmed | No GL/double-entry/journals/financial periods/tax engines/WIP/advanced QC/approvals/HR/loyalty/subscriptions/offline/sync/integrations/microservices initially |
| P04 | Confirmed | Preserve historical SQL; propose independent smaller Phase 1 schema reusing sound names/relationships; remove financial/advanced dependencies |
| P05 | Confirmed | Keep company internally, auto-create one per tenant; no legal-company UI |
| P06 | Confirmed | Exact decimals, immutable inventory history, locked projections, no negatives/duplicates/cross-tenant transfer; transit, partial receipt/damage/corrections and carried cost remain mandatory |
| P07 | Confirmed | .NET 10 LTS, Next.js/TypeScript, MySQL 8.4, modular monolith, practical Clean Architecture/SOLID, GitHub/Linux VPS and Docker/Compose where appropriate; .NET owns business/authz |
| P08 | Superseded | Original documentation-only gate was replaced by the owner authorization of P1-01; database/authentication work is still gated |
| P09 | Confirmed | 38 application tables, introduced by slice; one-company unique key, shared item/quantity line snapshots and explicit transfer allocations |
| P10 | Confirmed | Per-bucket moving-average operational carried value, FEFO physical picking; exact transfer/return allocation residuals; no FIFO layers/accounting |
| P11 | Confirmed direction | Completed manufacture with actual inputs/packaging and one finished SKU/lot in one factory warehouse; input value absorbed by output; bulk/packaging as separate runs |
| P12 | Confirmed | Two static membership roles; Staff ordinary outlet grants; Admin posts sensitive corrections/returns/refunds, no second approver |
| P13 | Confirmed direction | .NET secure cookie + revocable server sessions, vetted password hashing/Data Protection, CSRF; controlled onboarding/local password handoff, no external identity provider dependency |
| P14 | Confirmed | App Router, Node production runtime, same-origin /api routing; direct browser API for protected feature data; four backend projects, no Worker/outbox/broker |
| P15 | Confirmed | Short logical warehouse freeze for counts; movement snapshots and once-only variance completion |
| P16 | Confirmed direction | Single currency; simple unit prices/discounts; manual cash/card/bank records and partial payments; original-sale/lot returns, held by default; no tax components or cross-sale credits |
| P17 | Partial | Short feature branch, npm lockfile, CI and isolated Compose implemented in P1-01; remote main protection not configured and no commit/push/deploy performed |
| P18 | Partial | Revised scope/architecture and P1-01 approved; final DDL/safeguards/target execution and authentication implementation still require their next-slice gate |
| P19 | Partial | SDK/runtime/frontend/test/image pins selected and validated in P1-01; workspace Node 26.13.1 leaves system Node unchanged; Docker engine now available; migration tool remains for P1-02 |
| P20 | Open | Actual outlets/warehouse grants, item/unit/lot/opening data, expiry boundary, cost/rounding and count/transfer exception policies |
| P21 | Open | Session duration/password/recovery/Admin MFA launch policy, safe shared-user management, branding/receipt details and audit/privacy retention |
| P22 | Open | One-output completed-run fit, waste treatment, unpaid sales/discount/return/refund permissions, customer credit treatment, scanner/print/manual-weight fit |
| P23 | Open | VPS/domain/secrets/off-host backup storage/retention and acceptable loss/recovery window; measured restore and client UAT |

Do not invent currency/tax/rounding/expiry rates or business policies. Open P20-P23 choices gate dependent features or launch, not documentation or an otherwise approved minimal scaffold.
For a design change record context, proposal/alternatives, scope, security/stock/cost/data impact, test evidence and owner acceptance. A short ADR is sufficient; do not add one per routine code decision.

## P1-01 authorization and implementation record
The owner authorized application files and project-level dependencies for Minimal Project Foundation on 25 November 2026 and required stopping before authentication/business management. The 38-table design is an approved starting baseline, not a fixed table limit.
Implementation uses four backend projects, Next.js App Router/standalone Node, same-origin fixed proxy/Nginx, strict API decimal/ID strings and process-only health. No database/ORM/MySqlConnector dependency is installed until actual database use. Details/pins/evidence: [foundation implementation](18_FOUNDATION_IMPLEMENTATION.md).
ESLint 10 uses supported Next/TypeScript/React Hooks plugins directly; the legacy React plugin's peer range excludes 10. TypeScript 6.0.3 is selected because the current TypeScript ESLint parser supports versions below 6.1, not TypeScript 7. Versions were selected from actual package metadata and locked; no forced peer overrides.
