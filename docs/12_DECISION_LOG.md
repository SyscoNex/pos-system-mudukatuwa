# Decision log — Phase 1

P34 (approved and verified, 29 November 2026). SysConex approved migrations 0010–0011 and runtime grants on conex360-auth-review and private conex360-p106-clean. Whole-request FEFO reservation, source cancellation of the undisbursed remainder and return into HOLD at the original source were approved. Both schema installations, focused MySQL verification and the browser transfer and stock-take workflow passed. [Policy and migration review](28_P1_06_DATABASE_REVIEW.md)

P33 (approved and verified, 28 November 2026). SysConex approved all P1-05 inventory policies and separately authorized migrations 0008–0009 and runtime grants on conex360-auth-review and private conex360-p105-clean. Both installations and focused MySQL tests passed. Posting was enabled on the review API after verification and the browser receipt workflow passed. P1-06 follows owner review. [Approved policies](26_P1_05_DATABASE_REVIEW.md) · [Verification results](25_INVENTORY_INCOMING_IMPLEMENTATION.md)

P31 (owner-authorized/implemented): P1-03 accepted; P1-04a/b/c plus docs/24's 0006–0007, catalogue grants, review upgrade and private p104-clean tests separately approved on 28 November 2026. Stop before P1-05. Six scoped tables; no new package, ORM or service. This supersedes earlier milestone gates below.

P32 (approved catalogue safeguards): Base UOM is immutable from creation, stricter than the original after-use proposal; correct a wrong base identity with a replacement SKU. First configured price including zero locks company currency. Both refinements were disclosed in the approved database question/package. Exact explicit factors allow count packaging without density assumptions or a different-SKU manufacturing shortcut. Blank and zero prices differ. Staff DTOs follow transaction-revalidated membership. Exact before/after product/unit/price/barcode audit snapshots use the existing private audit table. Future document tables must add immutable transaction snapshots and used-SKU/tracking checks. Evidence/open decisions: docs/23_CATALOG_SUPPLIERS_IMPLEMENTATION.md.

P29 (owner-authorized/implemented): P1-02 accepted, P1-03a/b authorized; separate 0003–0005/review+clean target/grants approval received. Four tables plus scoped session fields; no classification hierarchy or stock. P30 (technical policies): one default per outlet; explicit deactivation cascades warehouses/grants with audit; reactivation revives default only. Canonical transit per company is hidden and immutable. Last-active Administrator protected by company serialization; existing-identity linking remains controlled with consent/password proof. Full evidence: docs/21_OUTLETS_WAREHOUSES_USERS_IMPLEMENTATION.md. Stop before P1-04.

**Updated 28 November 2026.** Confirmed = owner-approved direction; Proposed = awaits approval; Open = unresolved before dependent slice; Partial = implemented/decided in part; Superseded = historical gate. P1-01 through P1-03 are accepted; P1-04 is implemented under the isolated approval above. Stop before P1-05.
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
| P08 | Superseded | Original documentation-only/foundation gates replaced by P1-02 authorization and the isolated execution approval P25; later milestones/production remain gated |
| P09 | Confirmed | 38 application tables, introduced by slice; one-company unique key, shared item/quantity line snapshots and explicit transfer allocations |
| P10 | Confirmed | Per-bucket moving-average operational carried value, FEFO physical picking; exact transfer/return allocation residuals; no FIFO layers/accounting |
| P11 | Confirmed direction | Completed manufacture with actual inputs/packaging and one finished SKU/lot in one factory warehouse; input value absorbed by output; bulk/packaging as separate runs |
| P12 | Confirmed | Two static membership roles; Staff ordinary outlet grants; Admin posts sensitive corrections/returns/refunds, no second approver |
| P13 | Confirmed direction | .NET secure cookie + revocable server sessions, vetted password hashing/Data Protection, CSRF; controlled onboarding/local password handoff, no external identity provider dependency |
| P14 | Confirmed | App Router, Node production runtime, same-origin /api routing; direct browser API for protected feature data; four backend projects, no Worker/outbox/broker |
| P15 | Confirmed | Short logical warehouse freeze for counts; movement snapshots and once-only variance completion |
| P16 | Confirmed direction | Single currency; simple unit prices/discounts; manual cash/card/bank records and partial payments; original-sale/lot returns, held by default; no tax components or cross-sale credits |
| P17 | Partial | Short feature branch, npm lockfile, CI and isolated Compose implemented in P1-01; remote main protection not configured and no commit/push/deploy performed |
| P18 | Partial | P1-01 accepted, P1-02 authorized and 0000–0002/auth-review separately approved; owner review required before P1-03 |
| P19 | Implemented | Pinned SDK/runtime/frontend/test/images retained; workspace Node leaves system unchanged; Docker available and explicit migration runner added in P1-02 |
| P20 | Open | Actual outlets/warehouse grants, item/unit/lot/opening data, expiry boundary, cost/rounding and count/transfer exception policies |
| P21 | Open | Session duration/password/recovery/Admin MFA launch policy, safe shared-user management, branding/receipt details and audit/privacy retention |
| P22 | Open | One-output completed-run fit, waste treatment, unpaid sales/discount/return/refund permissions, customer credit treatment, scanner/print/manual-weight fit |
| P23 | Open | VPS/domain/secrets/off-host backup storage/retention and acceptable loss/recovery window; measured restore and client UAT |
| P24 | Confirmed | Mandatory Phase 1 same-computer dual-monitor Customer Facing Display, implemented only in P1-08. Per-checkout unguessable BroadcastChannel, sanitized DTO, authoritative backend payment confirmation, revision/transaction ordering, resync/heartbeat/reset; no real-time server or persistent pairing table. Full specification docs/20 |
| P25 | Confirmed execution boundary | Owner separately approved only reviewed 0000–0002, new conex360-auth-review database and synthetic tests; no published DB port, production/historical SQL/other projects excluded. P1-02 code is authorized; P1-03 still gated |
| P26 | Implemented technical choice | Focused MySqlConnector 3.0.0 SQL and explicit embedded/checksummed migration command, no ORM/startup migration. Seven app tables + journal; tenant-operation UUID/uniques cover onboarding replay, idempotency table deferred. Runtime DML and migrator DDL identities separate |
| P27 | Implemented technical choice | SkiaSharp 4.158.0 MIT raster decoder/re-encoder, private immutable scoped PNG files, certificate-encrypted persistent Data Protection key ring. No arbitrary image URL/SVG or public uploads |
| P28 | Proposed production defaults | Password 15–128, 210k PBKDF2-SHA512, idle 30m/absolute 8h, five failures/15m lockout, controlled verified support recovery. Administrator MFA launch policy remains open; this is not production approval |

Do not invent currency/tax/rounding/expiry rates or business policies. Open P20-P23 choices gate dependent features or launch, not documentation or an otherwise approved minimal scaffold.
For a design change record context, proposal/alternatives, scope, security/stock/cost/data impact, test evidence and owner acceptance. A short ADR is sufficient; do not add one per routine code decision.

## P1-01 authorization and implementation record
The owner authorized application files and project-level dependencies for Minimal Project Foundation on 25 November 2026 and required stopping before authentication/business management. The 38-table design is an approved starting baseline, not a fixed table limit.
Implementation uses four backend projects, Next.js App Router/standalone Node, same-origin fixed proxy/Nginx, strict API decimal/ID strings and process-only health. No database/ORM/MySqlConnector dependency is installed until actual database use. Details/pins/evidence: [foundation implementation](18_FOUNDATION_IMPLEMENTATION.md).
ESLint 10 uses supported Next/TypeScript/React Hooks plugins directly; the legacy React plugin's peer range excludes 10. TypeScript 6.0.3 is selected because the current TypeScript ESLint parser supports versions below 6.1, not TypeScript 7. Versions were selected from actual package metadata and locked; no forced peer overrides.
