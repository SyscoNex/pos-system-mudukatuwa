# Phase 1 schema differences and future extension
**Starting design approved 25 November 2026. No DDL execution is authorized by P1-01; additional tables need actual justification/review.**

The 160-table reference is unchanged. Phase 1 proposes 38 application tables: 33 adapted historical tables and five new ones; 127 historical tables are deferred or folded into simpler structures. This inventory enumerates every original table so omitted dependencies cannot silently return. Reuse of a name does not mean byte-compatible DDL.

## Important design differences
| Area | Phase 1 difference | Future extension/migration |
|---|---|---|
| Installation | Independent Phase 1 baseline; no enterprise schema, guards/seeds, disabled FKs or placeholder financial rows | Extend the Phase 1 migration chain; never overlay original SQL |
| Organization | UNIQUE company tenant; create one default company and hide legal-company UI | Remove one-company uniqueness, add reviewed company grants/UI; existing scope/IDs remain |
| Authentication | Local vetted .NET password/cookie primitives with revocable sessions; separate global security events | Add vetted external identity/MFA/recovery storage only when approved; issuer/subject uniqueness required for federation |
| Roles | Role on membership plus branch grants; no dynamic roles/permissions/hierarchy | Seed role tables and backfill membership roles preserving current effective grants; test no privilege expansion |
| Transit | Hidden company warehouse, nullable branch only for transit, exact allocation events | Add richer shipment metadata/routing without changing quantity evidence; review unique transit constraint in DDL |
| Master data | Basic item units/prices, supplier/customer flags/address; no price/tax/credit modules | Add price lists/party roles/addresses, backfill existing fields; old snapshots remain authoritative |
| Currency | One company currency/minor-unit/rounding policy; no currencies/FX/period tables | Add shared currency reference and transaction FX only after validating existing codes and a cutover policy |
| Documents | Nullable draft number, company-wide type/series posting sequence, operation UUID, minimal lifecycle | Add states/typed headers with reviewed guards; do not renumber posted history |
| Lines | Shared item/quantity/UOM/price snapshot rows replace repetitive typed lines | Add typed line extensions and backfill stable line IDs if needed; never create an incompatible second line registry |
| Corrections | Posted content/status immutable; compensating documents with bounded source links | Add relation taxonomy/document_links if actual many-to-many use needs it; retain original evidence |
| Ownership | Own-company stock only, no inventory_owners dimension | Add default owner rows and nonnullable scoped bucket ownership via backfill/unique-key migration before third-party stock |
| Costs | Signed quantity/value entries and per-bucket average; no FIFO layers/consumptions/value-adjustment engine | New costing policy needs reconciled quantity/value opening layers, cutover date and policy version; cannot reconstruct historical FIFO from averages |
| Transfer value | Allocation-specific source/transit/receipt/resolution quantities and values | Preserve these origin links if later finance/cost layers are added; do not value from pooled transit |
| Reservations | Actual transfer bucket allocations; released/consumed residuals; no offline device or timeout release | New reservation types need explicit ownership/cumulative tests; offline requires a separately approved durable protocol |
| Transfer lifecycle | REQUEST/DISPATCH/RECEIPT plus explicit RESOLUTION/CANCEL; no approval table | Add configurable approval/transport workflows only with a concrete client need |
| Counting | Warehouse freeze/snapshot and posted difference; no concurrent roll-forward | Add roll-forward only with verified committed cutoff/movement semantics; preserve original count snapshots |
| Manufacture | One completed actual-input/output run; no recipe/order/routing/partial WIP or joint output | Add recipes/orders and nullable event links; old completed runs remain valid standalone events; cost cutover must not rewrite them |
| Trace/QC | Actual run input/output stock evidence plus simple blocked/held/damaged controls | Backfill genealogy from actual run links; add inspections/recall cases if needed; do not label old evidence as unperformed QC |
| Sales | Immediate online sale; warehouse chosen from grants; no register/shift/device/wholesale delivery | Add register/session/delivery tables and typed fulfillment paths later; old immediate issues must not be duplicated |
| Payments | Manual immutable amounts/tender/change/refund/correction linked to original sale; no accounting documents or gateway | Add provider-intent/inbox only for actual integration; migrate manual evidence explicitly, not invented confirmations |
| Returns | Original sale/lot issue allocation and original amount/cost, with refund caps | Add no-receipt/price-only credit/exchange/customer-credit policies separately; do not infer credit instruments from current totals |
| Finance/tax | No accounts/GL/journals/periods/subledgers/tax engine | Establish approved opening/cutover balances and mappings; never fabricate historical journals or tax snapshots from operational totals |
| Reliability | Idempotency + one transactional DB boundary; no Worker/outbox/feed/inbox | Add outbox atomically at future integration boundary; no retroactive promise of delivered events |
| Branding/files | Company key plus immutable receipt snapshots and private versioned assets | Add attachments metadata for general document files if required; preserve old referenced logos |
| Reporting | Bounded synchronous operational SQL/CSV/print, not financial statements | Add measured projections/jobs/analytics with checkpoints and rebuilding only when needed |
| Seeds/guards | Small per-slice defaults/static policies and explicit Phase 1 guards; no enterprise permissions/GL/tax seed | Add required reference/guard coverage with each future module; missing historical companion SQL remains historical |

Future change can be structurally additive, but multi-company, ownership, valuation and finance transitions still need reviewed data backfills/cutovers and reconciliation. Future-compatible does not mean a free migration or exact enterprise-schema compatibility. Starting-design approval does not authorize DDL execution or later modules; only P1-01 application scaffolding is currently authorized.

## All historical table dispositions
“Adapt” means keep the historical name with Phase 1 fields/constraints as specified. “Fold” means evidence moves to an explicitly named simpler structure, not a dropped invariant. “Defer” means no current table or FK dependency.

| Historical table | Disposition | Phase 1 handling / future purpose |
|---|---|---|
| tenants | Adapt | Retain isolated business/status; no subscription dependency. |
| users | Adapt | Retain global identity; add practical password/session security metadata; no provider dependency. |
| tenant_memberships | Adapt | Add static Administrator/Staff role; replace configurable role/permission grants. |
| roles | Fold | Static tenant_memberships.role; dynamic roles later. |
| permissions | Fold | Static backend policies; configurable permission vocabulary later. |
| role_permissions | Fold | Static Administrator/Staff matrix; no dynamic assignments. |
| membership_roles | Fold | tenant_memberships.role initially; migrate explicit grants later. |
| companies | Adapt | One per tenant enforced initially; business branding/currency/rounding profile added; currency lookup FK removed. |
| branches | Adapt | Retain outlet/factory organization; no multi-company UI. |
| membership_branches | Adapt | Retain explicit Staff outlet grants; scoped membership and branch. |
| company_role_grants | Fold | One default company plus membership/branch scope; add before multi-company. |
| warehouses | Adapt | Add ORDINARY/TRANSIT kind; branch nullable only for unique hidden company transit warehouse. |
| locations | Adapt | Default storage/transit/held/damaged locations; no parent-bin UI/WIP/scrap hierarchy. |
| tenant_features | Defer | Future product only; no Phase 1 table, FK or seed dependency. |
| subscriptions | Defer | Future product only; no Phase 1 table, FK or seed dependency. |
| currencies | Defer | Future product only; no Phase 1 table, FK or seed dependency. |
| units | Adapt | Retain scoped dimensions and codes; exact item-specific conversions. |
| item_categories | Adapt | Retain scoped hierarchy; cycle checks. |
| items | Adapt | Retain SKU/base UOM/category/stock flags; NONE/LOT only initially, no serial/service/byproduct module. |
| item_units | Adapt | Retain exact conversions; add simple per-unit purchase/sale defaults instead of price lists. |
| item_barcodes | Adapt | Retain exact barcode uniqueness and same-item unit FK. |
| item_attributes | Defer | Future product only; no Phase 1 table, FK or seed dependency. |
| item_attribute_values | Defer | Future product only; no Phase 1 table, FK or seed dependency. |
| parties | Adapt | Supplier/customer flags and basic contact/address replace role/address/credit tables. |
| party_roles | Fold | parties supplier/customer flags; richer roles later. |
| party_addresses | Fold | One basic parties address plus document snapshots; multiple addresses later. |
| party_credit_policies | Defer | Future product only; no Phase 1 table, FK or seed dependency. |
| supplier_items | Defer | Future product only; no Phase 1 table, FK or seed dependency. |
| tax_codes | Defer | Future product only; no Phase 1 table, FK or seed dependency. |
| tax_rates | Defer | Future product only; no Phase 1 table, FK or seed dependency. |
| item_tax_rules | Defer | Future product only; no Phase 1 table, FK or seed dependency. |
| price_lists | Fold | item_units basic purchase/sale defaults; price-list rules later. |
| price_list_lines | Fold | item_units prices plus immutable document_lines price snapshots. |
| promotions | Defer | Future product only; no Phase 1 table, FK or seed dependency. |
| document_sequences | Adapt | Company/type/calendar series, not fiscal periods/branch counters; unique posted numbering. |
| documents | Adapt | Add operation UUID and optional warehouse; draft number nullable; DRAFT/POSTED/VOID; linked corrections, no financial root requirement. |
| document_lines | Adapt | Expand registry with common item/UOM/price snapshots and line roles; replaces most simple typed line tables. |
| document_links | Defer | Future product only; no Phase 1 table, FK or seed dependency. |
| document_taxes | Defer | Future product only; no Phase 1 table, FK or seed dependency. |
| document_approvals | Defer | Future product only; no Phase 1 table, FK or seed dependency. |
| attachments | Defer | Future product only; no Phase 1 table, FK or seed dependency. |
| purchase_orders | Defer | Future product only; no Phase 1 table, FK or seed dependency. |
| purchase_order_lines | Defer | Future product only; no Phase 1 table, FK or seed dependency. |
| goods_receipts | Adapt | Actual incoming stock only; remove PO/AP matching dependencies; basic costs/totals. |
| goods_receipt_lines | Fold | Shared document_lines for actual receipt quantity/cost input. |
| supplier_invoices | Defer | Future product only; no Phase 1 table, FK or seed dependency. |
| supplier_invoice_lines | Defer | Future product only; no Phase 1 table, FK or seed dependency. |
| purchase_matches | Defer | Future product only; no Phase 1 table, FK or seed dependency. |
| supplier_returns | Defer | Future product only; no Phase 1 table, FK or seed dependency. |
| supplier_return_lines | Defer | Future product only; no Phase 1 table, FK or seed dependency. |
| supplier_credits | Defer | Future product only; no Phase 1 table, FK or seed dependency. |
| supplier_credit_lines | Defer | Future product only; no Phase 1 table, FK or seed dependency. |
| landed_costs | Defer | Future product only; no Phase 1 table, FK or seed dependency. |
| landed_cost_allocations | Defer | Future product only; no Phase 1 table, FK or seed dependency. |
| lots | Adapt | Retain item/lot/dates; simple blocked evidence instead of quality/recall state machine. |
| inventory_owners | Defer | Future product only; no Phase 1 table, FK or seed dependency. |
| stock_buckets | Adapt | Remove inventory_owner_id; company-owned lot/location/condition remains nonnullable unique. |
| stock_balances | Adapt | Add exact operational value projection beside quantity; no direct operator updates. |
| stock_reservations | Adapt | Transfer request/bucket only; consumed/released tracking; remove device and expiry auto-release concepts. |
| stock_entries | Adapt | Add signed carried value and bounded source-entry links; immutable quantity/value history, no journal/cost-layer FK. |
| stock_cost_layers | Defer | Future product only; no Phase 1 table, FK or seed dependency. |
| stock_cost_consumptions | Defer | Future product only; no Phase 1 table, FK or seed dependency. |
| stock_value_adjustments | Defer | Future product only; no Phase 1 table, FK or seed dependency. |
| serial_numbers | Defer | Future product only; no Phase 1 table, FK or seed dependency. |
| serial_movements | Defer | Future product only; no Phase 1 table, FK or seed dependency. |
| stock_transfers | Adapt | Explicit request/dispatch references and REQUEST/DISPATCH/RECEIPT/RESOLUTION/CANCEL stages; new allocation evidence. |
| stock_transfer_lines | Fold | Shared document_lines plus three explicit allocation tables. |
| stock_counts | Adapt | Short logical freeze; remove roll-forward/entry-ID-as-commit-cutoff assumptions. |
| stock_count_lines | Adapt | Independent count evidence with expected value/cost and optional nonzero variance movement line. |
| stock_adjustments | Fold | documents OPENING_STOCK/STOCK_ADJUSTMENT/WASTE types and structured reasons. |
| stock_adjustment_lines | Fold | Shared document_lines and immutable stock_entries. |
| reorder_policies | Defer | Future product only; no Phase 1 table, FK or seed dependency. |
| recipes | Defer | Future product only; no Phase 1 table, FK or seed dependency. |
| recipe_versions | Defer | Future product only; no Phase 1 table, FK or seed dependency. |
| recipe_inputs | Defer | Future product only; no Phase 1 table, FK or seed dependency. |
| recipe_substitutions | Defer | Future product only; no Phase 1 table, FK or seed dependency. |
| recipe_outputs | Defer | Future product only; no Phase 1 table, FK or seed dependency. |
| work_centers | Defer | Future product only; no Phase 1 table, FK or seed dependency. |
| routing_steps | Defer | Future product only; no Phase 1 table, FK or seed dependency. |
| production_orders | Defer | Future product only; no Phase 1 table, FK or seed dependency. |
| production_material_plans | Defer | Future product only; no Phase 1 table, FK or seed dependency. |
| production_operations | Defer | Future product only; no Phase 1 table, FK or seed dependency. |
| production_events | Adapt | Completed actual run; remove production_order FK; shared lines retain actual inputs/output and cost trace. |
| production_event_lines | Fold | Shared document_lines INPUT/OUTPUT roles; actual lot entries. |
| production_costs | Defer | Future product only; no Phase 1 table, FK or seed dependency. |
| production_cost_allocations | Defer | Future product only; no Phase 1 table, FK or seed dependency. |
| lot_genealogy | Fold | Actual input/output entries joined by the one-output production_events run; explicit graph later. |
| quality_specs | Defer | Future product only; no Phase 1 table, FK or seed dependency. |
| quality_spec_tests | Defer | Future product only; no Phase 1 table, FK or seed dependency. |
| quality_inspections | Defer | Future product only; no Phase 1 table, FK or seed dependency. |
| quality_results | Defer | Future product only; no Phase 1 table, FK or seed dependency. |
| lot_status_events | Defer | Future product only; no Phase 1 table, FK or seed dependency. |
| recalls | Defer | Future product only; no Phase 1 table, FK or seed dependency. |
| recall_lots | Defer | Future product only; no Phase 1 table, FK or seed dependency. |
| sales_orders | Defer | Future product only; no Phase 1 table, FK or seed dependency. |
| sales_order_lines | Defer | Future product only; no Phase 1 table, FK or seed dependency. |
| deliveries | Defer | Future product only; no Phase 1 table, FK or seed dependency. |
| delivery_lines | Defer | Future product only; no Phase 1 table, FK or seed dependency. |
| sales_invoices | Adapt | Immediate online sale and snapshots; no session/device/wholesale/offline/tax dependencies. |
| sales_invoice_lines | Fold | Shared document_lines with original item/unit/price/discount snapshots. |
| sales_delivery_matches | Defer | Future product only; no Phase 1 table, FK or seed dependency. |
| customer_returns | Adapt | Original-sale linked operational return/credit total; no sales-credit/open-item dependency. |
| customer_return_lines | Adapt | Original sale line plus issue allocation/disposition; shared quantity/amount line; cumulative caps. |
| sales_credits | Defer | Future product only; no Phase 1 table, FK or seed dependency. |
| sales_credit_lines | Defer | Future product only; no Phase 1 table, FK or seed dependency. |
| sale_discounts | Fold | Simple original line discount snapshot and Admin authorization/audit; promotion engine later. |
| pos_registers | Defer | Future product only; no Phase 1 table, FK or seed dependency. |
| pos_sessions | Defer | Future product only; no Phase 1 table, FK or seed dependency. |
| cash_movements | Defer | Future product only; no Phase 1 table, FK or seed dependency. |
| weighing_events | Defer | Future product only; no Phase 1 table, FK or seed dependency. |
| accounts | Defer | Future product only; no Phase 1 table, FK or seed dependency. |
| accounting_periods | Defer | Future product only; no Phase 1 table, FK or seed dependency. |
| account_mappings | Defer | Future product only; no Phase 1 table, FK or seed dependency. |
| journal_entries | Defer | Future product only; no Phase 1 table, FK or seed dependency. |
| journal_lines | Defer | Future product only; no Phase 1 table, FK or seed dependency. |
| open_items | Defer | Future product only; no Phase 1 table, FK or seed dependency. |
| settlements | Defer | Future product only; no Phase 1 table, FK or seed dependency. |
| payment_methods | Fold | Validated CASH/CARD_MANUAL/BANK_MANUAL codes on payments; no account FK. |
| payments | Adapt | Independent immutable operational receipt/refund records linked to sale/return; no PAYMENT root, tender/method/account/settlement FK. |
| payment_tenders | Fold | Each payments row contains method/tender/change/applied amount; split = multiple rows. |
| payment_intents | Defer | Future product only; no Phase 1 table, FK or seed dependency. |
| bank_accounts | Defer | Future product only; no Phase 1 table, FK or seed dependency. |
| bank_statement_lines | Defer | Future product only; no Phase 1 table, FK or seed dependency. |
| bank_matches | Defer | Future product only; no Phase 1 table, FK or seed dependency. |
| expenses | Defer | Future product only; no Phase 1 table, FK or seed dependency. |
| expense_lines | Defer | Future product only; no Phase 1 table, FK or seed dependency. |
| budgets | Defer | Future product only; no Phase 1 table, FK or seed dependency. |
| employees | Defer | Future product only; no Phase 1 table, FK or seed dependency. |
| employment_terms | Defer | Future product only; no Phase 1 table, FK or seed dependency. |
| time_entries | Defer | Future product only; no Phase 1 table, FK or seed dependency. |
| leave_requests | Defer | Future product only; no Phase 1 table, FK or seed dependency. |
| pay_components | Defer | Future product only; no Phase 1 table, FK or seed dependency. |
| payroll_runs | Defer | Future product only; no Phase 1 table, FK or seed dependency. |
| payslips | Defer | Future product only; no Phase 1 table, FK or seed dependency. |
| payslip_lines | Defer | Future product only; no Phase 1 table, FK or seed dependency. |
| assets | Defer | Future product only; no Phase 1 table, FK or seed dependency. |
| asset_depreciations | Defer | Future product only; no Phase 1 table, FK or seed dependency. |
| maintenance_orders | Defer | Future product only; no Phase 1 table, FK or seed dependency. |
| maintenance_costs | Defer | Future product only; no Phase 1 table, FK or seed dependency. |
| loyalty_accounts | Defer | Future product only; no Phase 1 table, FK or seed dependency. |
| loyalty_entries | Defer | Future product only; no Phase 1 table, FK or seed dependency. |
| service_cases | Defer | Future product only; no Phase 1 table, FK or seed dependency. |
| devices | Defer | Future product only; no Phase 1 table, FK or seed dependency. |
| offline_operations | Defer | Future product only; no Phase 1 table, FK or seed dependency. |
| offline_stock_allocations | Defer | Future product only; no Phase 1 table, FK or seed dependency. |
| sync_cursors | Defer | Future product only; no Phase 1 table, FK or seed dependency. |
| change_feed | Defer | Future product only; no Phase 1 table, FK or seed dependency. |
| idempotency_keys | Adapt | Retain command/hash/result atomicity; no TTL removal in Phase 1; durable document/payment operation UUIDs. |
| outbox_messages | Defer | Future product only; no Phase 1 table, FK or seed dependency. |
| integration_inbox | Defer | Future product only; no Phase 1 table, FK or seed dependency. |
| audit_events | Adapt | Business-scoped immutable events; global authentication events moved to new security_events. |
| api_credentials | Defer | Future product only; no Phase 1 table, FK or seed dependency. |
| planning_runs | Defer | Future product only; no Phase 1 table, FK or seed dependency. |
| supply_suggestions | Defer | Future product only; no Phase 1 table, FK or seed dependency. |
| purchase_requisitions | Defer | Future product only; no Phase 1 table, FK or seed dependency. |
| purchase_requisition_lines | Defer | Future product only; no Phase 1 table, FK or seed dependency. |
| supplier_quotes | Defer | Future product only; no Phase 1 table, FK or seed dependency. |
| supplier_quote_lines | Defer | Future product only; no Phase 1 table, FK or seed dependency. |
| subcontract_orders | Defer | Future product only; no Phase 1 table, FK or seed dependency. |
| subcontract_order_lines | Defer | Future product only; no Phase 1 table, FK or seed dependency. |

## New Phase 1 tables
| New table | Why necessary now |
|---|---|
| auth_sessions | Revocable login sessions without external identity infrastructure |
| security_events | Authentication/security audit outside a fake business/company scope |
| transfer_dispatch_allocations | Lock exact request/source/transit quantity and carried value |
| transfer_receipt_allocations | Reconcile full/partial receipt to original dispatch lots/value |
| transfer_resolution_allocations | Account operationally for explicit loss/return without silent shortage |

## Migration review checklist
For each introduced table, review final columns/types/defaults, scoped unique/FK paths, nullable/check behavior, indexes, lifecycle/immutability guards and synthetic fixtures. Verify line/header/stage/item/lot/warehouse semantic relationships that SQL FKs alone cannot enforce. For folded structures review existing query/report/constraint assumptions against the new schema.
Do not carry old required FKs into Phase 1 and populate fake parents. No FK disabling, competing active enterprise baseline, startup migration or silent reinterpretation of old money/cost semantics. All final DDL remains to be authored and approved after this plan.
