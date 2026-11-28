# Phase 1 database starting design

P1-05 prepares nine application tables in 0008–0009 plus a scoped location key. Opening/GRN posting uses one ledger entry per input line and bucket, durable actor/command replay, and immutable posted facts. See [the proposed SQL and policies](26_P1_05_DATABASE_REVIEW.md).

## P1-04 implemented refinement
Separately approved migrations 0006–0007 introduce units, item_categories, items, item_units, item_barcodes and parties: 17 application tables in total, plus schema_migrations. All six use scoped company FKs, unique machine keys, row versions and immutable ownership/no-delete guards. Details: docs/24_P1_04_DATABASE_REVIEW.md; evidence: docs/23_CATALOG_SUPPLIERS_IMPLEMENTATION.md. Existing SQL 0000–0005 is unchanged. No compulsory seed; standard UOM setup is an optional idempotent Administrator command.

Base UOM is immutable from creation (stricter than the original after-use proposal). Product-specific factors use DECIMAL(24,9), nullable prices DECIMAL(24,6), with base factor one and unique active default slots. Exactly one active base/purchase/sale default where enabled and category acyclicity are guarded application transaction rules. Barcode exact NO PAD binary collation preserves leading zeros. First explicit price including zero locks company currency, rather than waiting for a stock/sales posting. Snapshot/used-SKU/tracking-change checks must be added alongside future document tables. These refinements supersede the corresponding proposals below; no historical transaction tables exist yet.

P1-03 adds only branches, membership_branches, warehouses and locations through reviewed 0003–0005, plus nullable scoped outlet context fields on auth_sessions. Scope/kind composite FKs, generated default/transit unique keys and immutable/no-delete guards protect structure. Locations are three immutable ordinary system nodes (STORAGE/HOLD/DAMAGED) or one TRANSIT; operational activation derives from parent. Optional branch classification is omitted until a concrete rule requires it. Exact SQL/review: docs/22_P1_03_DATABASE_REVIEW.md. Historical SQL and applied 0000–0002 unchanged.

**Starting design approved 25 November 2026. P1-02 introduced seven application tables, P1-03 four and P1-04 six, plus separate migration bookkeeping. Reviewed SQL reaches 0007; remaining stock/document tables are design only. Exact current package: docs/24; earlier evidence docs/19 and docs/21.**

Phase 1 is designed as an independently installable operational database, not a reduced set of screens on the enterprise database. Its approved starting baseline has 38 application tables: 33 adapted historical names and five new tables. This is not a fixed limit; justify/review additional tables against real requirements. Migration-tool bookkeeping, if selected, is separate. Add tables by functional slice; do not generate them all during foundation.

No accounts, journals, periods, open items, settlements, tax tables, WIP, cost layers, offline or advanced-module FKs/seeds are required. The original SQL remains unchanged. See [complete mapping](15_PHASE1_SCHEMA_MAPPING.md).

## Proposed table inventory
Columns below describe essential design fields, not executable DDL or a complete field dictionary. Common keys/metadata/constraints below are mandatory. Final DDL and safeguards require review.

| # | Table | Essential fields and relationships |
|---|---|---|
| 1 | tenants | code, name, ACTIVE/SUSPENDED status; unique normalized code |
| 2 | users | public UUID, normalized unique email, vetted password hash, enabled, security stamp, forced-password-change/lockout fields; global login identity only |
| 3 | auth_sessions | NEW; users FK, opaque public session identity, security-stamp/version binding, created/last-used/absolute expiry, revoked_at; no business records or reusable plaintext secrets |
| 4 | tenant_memberships | tenant/user FKs, ACTIVE/DISABLED status, role ADMINISTRATOR or STAFF; unique tenant/user |
| 5 | companies | tenant FK, UNIQUE tenant_id initially; internal code, business/display name, contact/address, logo object key, currency code/minor units/rounding policy, IANA timezone |
| 6 | branches | company scope, code/name/address, kind FACTORY/STORE/WAREHOUSE; scoped unique code |
| 7 | membership_branches | tenant membership + scoped branch; unique grant; Staff access list, Admin covers own default company |
| 8 | warehouses | company scope, code/name, kind ORDINARY/TRANSIT; ordinary branch FK required; branch NULL only for hidden transit warehouse |
| 9 | locations | scoped warehouse FK, code, kind STORAGE/TRANSIT/HOLD/DAMAGED; default locations created, transit restricted to transit warehouse |
| 10 | units | scoped code/name/dimension; no universal mass-volume conversion |
| 11 | item_categories | scoped code/name and optional same-company parent; prohibit cycles |
| 12 | items | scoped unique SKU, name, category/base-UOM FKs, RAW/PACKAGING/INTERMEDIATE/FINISHED kind, purchase/sale/manufacture/active flags, NONE/LOT tracking, expiry-required flag |
| 13 | item_units | item/unit FKs, positive to_base_factor, purchase/sale default flags, basic purchase_price/selling_price per unit; base unit factor exactly one; unique item/unit and supporting item/id key |
| 14 | item_barcodes | exact-collation barcode, item + item_unit FKs tied to same item; scoped unique barcode |
| 15 | parties | scoped code/name, supplier/customer flags (one or both), phone/email/address, active flag; no credit policies/subledger |
| 16 | document_sequences | company/type/calendar-series key, prefix and locked next_value; numbers unique across outlets in a company/type |
| 17 | documents | public UUID, durable operation UUID, type, nullable document number while draft, business date, occurred/posted UTC, branch and optional warehouse, currency snapshot, actor, DRAFT/POSTED/VOID, optional source document/reason |
| 18 | document_lines | document FK, line number, item + item_unit FKs, role, quantity/UOM-factor/base-quantity snapshots, item/SKU/UOM descriptions, optional unit price/discount/line total and explicit cost input; optional scoped source line |
| 19 | goods_receipts | shares document PK; supplier FK, supplier delivery/reference text, operational purchase total; warehouse from document; no PO/AP/invoice match |
| 20 | lots | item FK, scoped item/lot number, PURCHASED/PRODUCED/SYSTEM, supplier lot ref, manufactured_on/expires_on, simple blocked flag/reason; no QC workflow |
| 21 | stock_buckets | lot/location FKs, AVAILABLE/HOLD/DAMAGED condition; nonnullable unique lot/location/condition; ownership is own-company only |
| 22 | stock_balances | unique bucket FK, on_hand_base, operational_value_base, last entry reference/version; locked rebuildable quantity/value projection |
| 23 | stock_reservations | bucket + transfer request line FKs, original quantity, consumed and released quantities, ACTIVE/CLOSED; active remainder = original - consumed - released; no device/expiry release |
| 24 | stock_entries | document/line/bucket FKs, signed quantity_base and signed value_delta_base, occurred/posted metadata, movement_group UUID, optional original/source entry for corrections/returns; immutable |
| 25 | stock_transfers | shares document PK; same-company distinct source/destination warehouse FKs; stage REQUEST/DISPATCH/RECEIPT/RESOLUTION/CANCEL; scoped request and applicable dispatch references |
| 26 | transfer_dispatch_allocations | NEW; request/dispatch lines, source issue and transit receipt entry FKs, dispatched quantity/value; one allocation per actual source bucket issue; immutable original facts |
| 27 | transfer_receipt_allocations | NEW; dispatch allocation + receipt line, transit issue + destination receipt entries, received quantity/value; split damage/hold separately; immutable |
| 28 | transfer_resolution_allocations | NEW; dispatch allocation + resolution line, LOSS or RETURN_TO_SOURCE, transit issue and optional source-return entry, quantity/value/reason; immutable |
| 29 | stock_counts | shares document PK; warehouse, COUNTING/COMPLETED/CANCELLED, freeze start/cutoff evidence; only one active count per warehouse under warehouse lock |
| 30 | stock_count_lines | count/bucket FKs, frozen expected quantity/value, counted quantity, explicit positive-variance cost if needed, variance; optional document line for nonzero posted variance; unique count/bucket |
| 31 | production_events | shares document PK; completed run reference; input/output warehouse identity validated against document; Phase 1 same factory warehouse, one output item/lot; no production order/recipe/WIP FK |
| 32 | sales_invoices | shares document PK; optional customer, customer/business/address snapshots, subtotal/discount/total; immediate online sale only; selling warehouse from document |
| 33 | customer_returns | shares document PK; original sales_invoice FK, reason and return total; original customer/snapshots validated |
| 34 | customer_return_lines | shares return document_line PK; original sale document/line and original issue entry reference, disposition, return amount; one line per original lot issue allocation |
| 35 | payments | original sales_invoice FK, optional linked return FK for refund, direction IN/OUT, method CASH/CARD_MANUAL/BANK_MANUAL, tender/change/applied amount, safe reference, actor/time/operation UUID, optional original payment for correction |
| 36 | audit_events | immutable scoped actor/action/entity/time/reason/correlation and redacted details; all business mutations, grants and corrections |
| 37 | security_events | NEW; global authentication/session events, optional user, action/outcome/time/correlation; no tenant business payload; restricted support access and retention |
| 38 | idempotency_keys | scoped actor/command/key, canonical request hash, response/result references and completion; effects/result commit together; no Phase 1 automatic TTL deletion |

## Core relationships and integrity
Tenant -> membership -> user; tenant -> exactly one default company. Company -> branches -> ordinary warehouses -> locations -> stock buckets; lots -> items; a hidden company transit warehouse holds only transit locations. P1-02 atomically provisions tenant/company/initial Administrator/membership/audit. Locations belong to P1-03 and are not an onboarding dependency now. No public signup/billing platform.

A document root owns stable document_lines. Typed headers share its ID. The shared line registry now also holds the few common item/quantity/price snapshots; typed line tables are retained only for count evidence and return-source constraints. Every type has a specific posting handler: no public generic document CRUD/post endpoint.

Incoming/opening/adjustment/waste, completed manufacturing, sales and returns produce stock entries referencing real document lines. Opening/adjustment/waste need no extra header table: document type, warehouse, structured reason and lines suffice. Counts create movement lines only for nonzero variances. Commercial amounts are required for sale/return/receipt types and absent when inapplicable. Header/line totals and permitted line roles are validated before posting.

All internal PKs remain BIGINT UNSIGNED; expose IDs as strings. Public UUIDs remain BINARY(16) with one tested byte order. All business tables except tenants and tenant-level memberships contain tenant_id/company_id; companies uses tenant_id/id. Global users/auth_sessions/security_events contain identity/security data only. Tenant-level rows cannot refer to a membership from another tenant.

Mutable rows have created_at, updated_at and application-incremented row_version; edits compare the expected version. Immutable facts retain their original metadata. Once stock uses a lot, ordinary edits cannot change its item, lot identity or manufacture/expiry dates; an exceptional metadata correction needs a separately reviewed authorized command retaining original evidence.

Company children use UNIQUE(tenant_id, company_id, id) and FKs including the same scope. Document/line keys additionally enforce line membership in the referenced root. Allocations enforce referenced entry/line membership in their document with supporting scoped unique keys. Application checks still verify subtype, item, lot, location, branch, stage, source/destination and positive/signed effects; composite FKs alone cannot express them.

All normal warehouses must match their branch/company; transit warehouse is hidden and managed by the system. At most one canonical transit warehouse per company must be enforced by a reviewed unique constraint design and bootstrap transaction. Transfers never expose arbitrary transit storage or other-outlet stock to Staff.

## Types, snapshots and policies
Use DECIMAL(24,9) quantities/factors and DECIMAL(24,6) costs/values/prices, C# decimal and JSON decimal strings. Reject overprecision/overflow; multiplication/division needs bounded deterministic rounding. All quantities are base units before stock writes. Prices are per selected item unit and stored as entered final operational amounts; there is no tax component or tax-exempt claim.

Propose one company currency; validate supported currency/minor units without a currencies table. Freeze currency/quantity identity after first relevant posting unless an approved migration handles conversion. Base UOM cannot be changed after use. Alternate conversion/price changes are versioned mutable master data; old documents retain factors/prices/names. Status/code normalization and exact machine-key collations are explicit.

Use DATETIME(6) UTC events and DATE local business/expiry dates. Do not reorder posted stock/cost history when a user enters an earlier business date. Company timezone and expiry boundary require approval. No accounting calendar/period lock.

Propose currency minor-unit rounding for payable totals, six-place operational cost residuals and a documented midpoint rule; exact mode/line versus total discount rounding remains open. Posting rejects a missing policy rather than inventing one. No tax/rate/GL seeds.

## Posting, cost and balances
Inventory owns writes. Lock and validate scope, idempotency, roots/source records, participating warehouses (including count freeze), lots, allocations, buckets/reservations and values in one deterministic order; see inventory specification. Roll back all effects, including payments/audit/result, on failure.

Proposed cost policy is per-bucket moving-average carried value for ordinary issues, not enterprise FIFO or a cost-layer engine. Immutable entries include quantity and signed carried value; balances project both. Transfers/returns use their explicit source allocation value, not the transit/destination average. See exact residual and manufacture rules in docs/04_INVENTORY_AND_TRANSFERS.md. This is operational cost information, not financial accounting.

Check on_hand >= 0, operational value >= 0, zero quantity => zero value, reservation remainder >= 0, positive allocations, valid enums and valid date ordering. Bound sums under locks; at zero stock issue the complete residual value. Posted fact updates/deletes are blocked by reviewed Phase 1 guards; mutable projection/session/reservation fields have separate rules. Restrict runtime privileges, but do not mistake that for row-level tenant security.

Reconcile SUM(entries.quantity) and SUM(entries.value_delta) to each bucket balance; outstanding reservation <= on-hand; dispatch quantity/value minus all receipts/resolutions = tagged transit outstanding; manufacture inputs' carried value = output value; sale totals/payments/refunds and return caps reconcile to immutable documents. Report differences; never overwrite history or clamp a discrepancy away.

## Drafts, corrections and future migration
Drafts use public UUIDs and NULL document_number; allocate company-wide type/series number only when posting, never MAX+1. Posted number/content never changes. DRAFT may become VOID; posted cancellation/correction is a new linked document. Transfer progress/cancelled remainder derives from allocation/cancellation facts, not edited posted roots.

A full correction is allowed only after checking all dependent consumption, receipts, manufacture and returns. Otherwise use linked partial return/adjustment/resolution with bounded quantities; do not generically negate a document. Payment corrections append opposite-direction records with original links and original caps.

Later add typed document lines if a module outgrows shared snapshots, backfilling existing stable IDs rather than renumbering history. Add companies by removing the one-company unique restriction and adding company grants/UI. Add ownership, FIFO layers or finance only with explicit conversion/opening cutover and reconciliations; never fabricate historic accounting or apply the enterprise SQL over Phase 1. Full change inventory is in the mapping document.
