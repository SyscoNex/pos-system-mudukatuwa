# Historical reference — Database_Design.docx

Extracted from the original 23 November 2026 document. Text/table conversion only; not a new approval. Current pack clarifies outlet transfers and missing SQL prerequisites. See README and decision log.

POS and Manufacturing Database Design

Version 1.0 | 23 November 2026

This database supports a shared software platform for independent businesses. Its first customer manufactures coconut products using coconut and other ingredients, then sells through shops or wholesale channels. The foundation combines traceable production, inventory, POS, purchasing and accounting. Optional workforce, asset, quality, planning and customer modules use the same organization and document model.

The design contains 160 tables. The accompanying SQL defines every column, key, foreign key and row check. The field dictionary describes all 1,784 columns. The business rules in this document are part of the design contract: database constraints alone cannot validate quantities or totals across multiple records.

## 1 Scope and design decisions

| Decision | Selected design | Reason |
| --- | --- | --- |
| Commercial model | Shared application and shared MySQL database with tenant isolation | Supports selling one maintained product to many businesses |
| Organization | Tenant contains one or more legal companies; company contains branches and warehouses | Separates subscriptions from legal accounting boundaries |
| Application | Modular .NET application with a web frontend | Keeps stock and finance in one database transaction |
| Database | MySQL 8.4 LTS using InnoDB | Transactional storage and enforced relational constraints |
| Inventory | Append only movements plus locked balance projections | Preserves history while supporting fast checkout |
| Manufacturing | Approved recipe versions and actual batch events | Records actual ingredients, outputs, yield and cost |
| Cost valuation | FIFO by company, warehouse, item and inventory owner | Keeps purchasing and production cost traceable |
| Physical picking | FEFO for expiring stock, with authorized overrides | Chooses safe stock independently of accounting cost policy |
| Accounting | Double entry journals plus customer and supplier open items | Makes stock, sales, payments and balances reconcilable |
| Offline billing | Registered devices, exclusive stock allocations and ordered synchronization | Supports disconnection without silently sharing the same reserved stock |
| Frontend | React and TypeScript proposed; API remains independent | Frontend selection can change without redesigning the database |

The shared platform is the confirmed deployment model. Multiple factories and shops, batches, expiry, weighing and offline operations are included as supported capabilities. Product formulas, actual yields, tax registrations, payroll rules, hardware protocols and operational volumes are configuration and implementation inputs. No coconut processing yield or statutory percentage is assumed.

## 2 Business coverage

| Area | Included capability | Principal tables |
| --- | --- | --- |
| Platform | Tenants, subscriptions, feature flags | tenants, subscriptions, tenant_features |
| Access | Memberships, company and branch grants, permissions | users, tenant_memberships, roles, company_role_grants, membership_branches |
| Organization | Legal companies, branches, warehouses, bins | companies, branches, warehouses, locations |
| Catalog | Ingredients, packaging, intermediates, products, services and barcodes | items, item_units, item_barcodes, item_attributes |
| Contacts | Customers, suppliers, addresses and credit limits | parties, party_roles, party_addresses, party_credit_policies |
| Procurement | Requisitions, supplier quotes, orders, receipts, invoices, returns and costs | purchase_requisitions, supplier_quotes, purchase_orders, goods_receipts, supplier_invoices, landed_costs |
| Inventory | Lots, ownership, reservations, transfers, counts and writeoffs | lots, stock_buckets, stock_entries, stock_balances, stock_reservations |
| Production | Recipes, substitutions, routings, batch execution, WIP and outsourcing | recipe_versions, production_orders, production_events, production_costs, subcontract_orders |
| Quality | Specifications, measurements, release and recalls | quality_specs, quality_inspections, lot_status_events, recalls |
| Planning | Reorder policies, material requirements and supply suggestions | reorder_policies, planning_runs, supply_suggestions |
| Sales | Quotes, orders, delivery, invoicing, returns and credits | sales_orders, deliveries, sales_invoices, customer_returns, sales_credits |
| POS | Till sessions, cash movement, split tenders and scales | pos_registers, pos_sessions, cash_movements, payment_tenders, weighing_events |
| Finance | Chart of accounts, journals, receivables, payables, settlement and budgets | accounts, journal_entries, journal_lines, open_items, settlements, budgets |
| Banking | Bank imports and reconciliation | bank_accounts, bank_statement_lines, bank_matches |
| Expenses | Overhead, petty cash and claims | expenses, expense_lines |
| Workforce | Employees, terms, time, leave and payroll components | employees, employment_terms, time_entries, payroll_runs, payslips |
| Assets | Machinery, depreciation and maintenance | assets, asset_depreciations, maintenance_orders |
| Customers | Loyalty and complaints linked to lots or invoices | loyalty_accounts, loyalty_entries, service_cases |
| Operations | Audit, idempotency, offline inbox, outbox and integration deduplication | audit_events, idempotency_keys, offline_operations, outbox_messages |

These are product modules, not a requirement to release every screen at once. Jurisdiction specific payroll calculations, statutory filing formats, regulated label certification, advanced finite capacity scheduling, ecommerce storefronts and consolidated group accounting require their own implementation specifications. The schema provides source records and integration points; it does not claim those workflows are already implemented.

## 3 Tenant isolation and company boundaries

A tenant is a subscribing business. A company is a legal entity inside that business. A branch is an operating site. Company catalogs, accounting periods and stock belong to one legal company. A tenant with two companies deliberately has two company catalogs; mappings for group reporting can be added later.

Global tables contain only shared reference data or login identities: tenants, users, permissions and currencies. Tenant tables contain memberships, roles, companies and subscription configuration. Every operational company table contains both tenant_id and company_id.

Company records have a unique key on tenant_id, company_id and id. Every company scoped relationship includes those same scope columns. A sales line therefore cannot point at an item belonging to another tenant or legal company, even if its numeric ID is known. Company itself is checked against tenant through a composite foreign key. Tenant role and membership references are also tenant scoped.

These keys prevent invalid cross business relationships. They do not filter SELECT statements. The API must resolve tenant from authenticated membership, resolve an authorized company and branch, and apply scope to every read, update, export, background job, report, cache entry and attachment URL. Never trust a client supplied tenant_id. Query filters in an ORM are a convenience and must not be the only isolation boundary. Platform support access must use an explicit, time limited, audited support workflow.

Users can join multiple tenants through distinct memberships. Company role grants restrict a role to one company. Branch grants further restrict the allowed sites. Tenant wide roles are explicit administrative grants. A branchless role must not accidentally imply access to every branch. Sensitive payroll data requires a separate permission from ordinary employee or cashier access.

Stock cannot transfer directly across legal companies. An intercompany movement is a sale and purchase, with tax and financial treatment configured for each company. One tenant cannot transfer to another tenant through internal inventory APIs.

## 4 Identity and storage conventions

Internal keys are BIGINT UNSIGNED. Expose numeric identifiers as JSON strings because JavaScript cannot represent all BIGINT values exactly. Documents, users and devices also have BINARY(16) public UUIDs. Public IDs are identifiers, not authorization credentials. UUID byte ordering must be fixed and tested between .NET and MySQL.

Every table contains created_at, updated_at and row_version. Timestamps are DATETIME(6) in UTC. The application increments row_version and changes updated_at on mutable updates; MySQL does not automatically update these fields. An optimistic update includes the expected row_version and treats zero affected rows as a conflict. Immutable tables retain their original metadata.

Business dates are DATE values interpreted in the company timezone, initially Asia/Colombo where appropriate. A sale at 01:00 local time must use its local business date even when UTC is the preceding day. Device event time, server receipt time and accounting date remain distinct.

Use utf8mb4 for Sinhala, Tamil and English. Human labels use the database collation. Machine identifiers including barcodes, serials and idempotency keys use an exact binary collation. Define normalization for SKUs and company codes in the application.

Quantities and conversion factors use DECIMAL(24,9). Money and costs use DECIMAL(24,6). Rates use fixed precision decimals. C# uses decimal. JavaScript submits decimal strings and uses a decimal arithmetic library for display calculations. FLOAT and DOUBLE are unsuitable for ledger quantities or money.

Round payable totals to currencies.minor_units; retain six decimal places for cost calculations. Define one rounding algorithm, line versus document tax rounding and a deterministic residual allocation rule. A cash rounding difference is an explicit document and journal amount. Exchange rate is functional currency units per one document currency unit, frozen when posted.

Status columns are constrained VARCHAR values rather than MySQL ENUM types. Adding a state requires a reviewed migration of the CHECK constraint and transition rules. JSON is limited to versioned integration payloads, metadata and validated rules. Quantities, invoice amounts, stock and ledger relationships remain relational.

## 5 Document roots and line identity

documents stores common numbering, scope, business date, currency, creator and lifecycle. A subtype such as sales_invoices shares the same primary ID as its documents row. It does not allocate a second ID. document_lines similarly provides stable line identity, and a subtype such as sales_invoice_lines shares that line ID.

Create the document root, then its typed header. Create each document_lines row, then its typed line using the same ID and document_id. Composite keys enforce that the source line belongs to the correct document. This lets stock_entries and document_taxes reference a real constrained source line without an unchecked source_type and source_id pair.

The guards verify subtype document_type on insertion. A posting command must additionally verify exactly one correct subtype, the expected typed lines and a valid transition. A generic root alone is not a valid sale. Journal only events such as depreciation or settlement can use a root type with no commercial subtype, provided its posting contract is registered.

Lifecycle is DRAFT, SUBMITTED, APPROVED, POSTED, REVERSED or VOID. A confirmed order can remain APPROVED while receipt or delivery progress is derived from later documents. A production order remains APPROVED during execution; each issue or output is a separately posted production event. Do not post and freeze the order header at production release.

POSTED content is immutable. Correct a posted invoice, receipt or journal through a new compensating document with an explicit relationship to the original. A credit is not automatically a physical return; a return is not automatically a cash refund. REVERSED marks the original after a valid compensating transaction has committed. Preserve both sides for reporting.

Allocate document numbers inside a transaction by locking document_sequences. Never use MAX(number)+1. Auto increment internal IDs can have gaps. Legal numbering rules and required treatment of voided numbers are configurable localization requirements. Offline receipt numbers use a registered device prefix and monotonic local sequence; the server retains the original offline reference.

## 6 Items and units

items is a general catalog, with role RAW, PACKAGING, INTERMEDIATE, FINISHED, BYPRODUCT or SERVICE and independent purchase, sale and manufacturing flags. A finished coconut oil product can be purchased from another supplier as well as manufactured internally. Services have no physical stock movements. New sectors use the same catalog rather than coconut specific columns.

Each stock item has exactly one base unit. item_units supplies per item purchase and sale conversions. A carton of 12 bottles converts to 12 EA for that bottled SKU. A bulk oil SKU uses liters as its base unit. Bottling bulk oil into a 500 ml retail SKU is a production event with bottles, caps and labels; it is not merely a unit conversion between two unrelated SKUs.

Mass to volume conversion is item specific and can depend on a measured density. Do not define a universal kg to liter conversion. Purchasing coconuts by count and consuming by weight requires a measured or explicitly approved per item conversion. For variable weight goods, weighing_events retains gross, tare, net and scale identity. Price quantity is derived from the accepted net weight and a frozen conversion.

Item variants with distinct stock, recipe, price or barcode are separate SKUs. Attributes hold descriptive metadata such as flavor, grade or pack style. The barcode must reference an item_unit belonging to that same item. Historical lines retain item name, SKU, quantity conversion, price, discount and tax snapshots, so later catalog changes do not rewrite history.

## 7 Physical stock and ownership

Physical batch records and accounting cost allocations use separate relationships.

lots identifies item batches, supplier lot numbers, production and expiry dates, and quality status. Even an untracked stocked item receives one internal SYSTEM lot per item. This makes lot_id mandatory in stock buckets and avoids nullable uniqueness gaps. The item tracking setting controls business facing traceability requirements.

A stock bucket is the unique combination of lot, location, inventory owner and condition. None of these dimensions is nullable. inventory_owners explicitly distinguishes company owned stock from third party owned consignment. Company owned material held at a subcontractor remains company owned and is represented in a dedicated location. Ownership and location are separate facts.

stock_entries is the immutable source of physical quantities. Positive entries receive stock; negative entries issue stock. An internal transfer creates paired entries, linked by movement_group. stock_balances is a fast projection, updated atomically with the ledger. It can be rebuilt from ledger totals; operators never repair it directly without an investigated reconciliation process.

Available quantity is on_hand minus the unconsumed portion of ACTIVE stock_reservations. Release status, condition, expiry, location, ownership and permissions determine eligibility before that quantity is usable. Quarantined, recalled, rejected, blocked and expired lots cannot be sold or consumed through normal commands. A quality override requires authorization and an audit reason.

Reserve or issue stock using a transaction that locks each applicable stock_balances row. Ensure the row exists first with a unique bucket key, then lock it. Lock rows in deterministic ascending bucket order. Validate quantity and reservation ownership, append entries, update projections and reservations, then commit. Concurrent checkout must not perform an unlocked read then unconditional write.

Normal physical balances cannot become negative. A local offline quota is already reserved centrally, so other tills cannot consume it. Unexpected offline events outside that quota enter a visible reconciliation queue and never silently bypass the central rule. Serial items require one unit per serial movement, matching lot, with one current location derived from chronological movements; serial uniqueness and balances are validated by the service.

## 8 Stock costing and adjustments

FIFO valuation operates within company, warehouse, item and inventory owner. stock_cost_layers records external receipt, opening, return or production output cost. stock_cost_consumptions records which layers fund an issue and the exact allocated value. Layer remaining quantity and value are locked projections; original quantities and values remain unchanged.

FEFO chooses physical lots by expiry. FIFO chooses accounting cost layers in the same item cost pool. They can select different lots, so traceability and valuation queries must not assume one issue always consumes the cost layer of its picked lot. A future actual lot costing policy is possible, but the first implementation should ship one validated valuation method. Changing valuation method requires a controlled conversion and accounting decision.

Transfers consume layers in the origin pool and create destination or transit layers with exactly the carried cost. Transfers do not create profit. Dispatch and receipt are separate posted documents with a transit location, supporting partial receipts and transport loss. Branch and transit inventory remain reconcilable while goods are in motion.

A supplier invoice can arrive after the goods receipt. Receive at an approved provisional cost and recognize goods received not invoiced. Match invoiced quantities through purchase_matches. Allocate freight, duty and other capitalizable charges through landed_cost_allocations. Post append only stock_value_adjustments: inventory_delta_base affects remaining inventory, while consumed_delta_base affects the relevant expense, cost of sales or downstream WIP. Update remaining layer value in the same transaction.

For ingredients already transformed into finished goods, a late cost variance needs propagation through recorded consumption and production settlement, or an approved variance expense policy. Do not place the entire late invoice difference on a nearly empty raw material layer. The costing service must retain its allocation calculation and reconcile the resulting journal.

Reversing an issue creates a return layer valued from the original consumption, rather than deleting the old consumption or valuing it at today's purchase price. Reversing an inbound receipt requires checking subsequent consumption and dependent documents. When direct reversal is no longer possible, use the applicable return, credit and adjustment workflow.

## 9 Recipes and production

Actual stock movements connect the production batch to its ingredient and output lots.

recipes identifies a formula family. recipe_versions records the approved formula and yield basis. recipe_inputs contains coconut ingredients, other ingredients and packaging. recipe_outputs identifies the primary product, coproducts, byproducts and scrap. routing_steps gives ordered operations and work centers. recipe_substitutions records approved alternatives and their equivalence factors.

An approved recipe version and its components are frozen. A change creates a new version. The service validates effective date overlap, one primary output, positive input quantities, valid substitutions, and no cycles in a multilevel recipe graph. A database foreign key cannot detect a recursive recipe cycle. Freeze the exploded material plan and operation instructions on production release.

production_orders plans one batch using an approved version. production_material_plans contains the exploded input snapshot. production_operations records the actual execution. production_events separates ISSUE, RETURN, OUTPUT, WASTE and REWORK; every posted event has independent document and line identities. Actual stock entries determine actual consumed lots and produced lots.

Record actual consumption, approved substitutions, leftover material returns and output quantities. Do not assume actual input equals the planned formula. Reject an unapproved substitution or record its authorized approval. Record normal process loss separately from abnormal loss. Manufacturing produces one or more quarantined output lots until quality release.

Production cost consists of actual consumed material, direct labor and approved machine, energy, subcontract and overhead charges. Issue posts to WIP; output and settlement move eligible WIP into finished goods. production_cost_allocations records the allocation to each output stock entry. Unsettled production keeps a visible WIP balance. Closing an order requires all charges, returns, output valuation, losses and settlements to reconcile.

For joint outputs, choose one policy per approved recipe. Cost shares for cost bearing outputs must sum to one after any approved byproduct credit. Do not apply both full joint allocation and a duplicate byproduct credit. Abnormal waste goes to the configured loss expense, rather than inflating the remaining good output. Preserve allocation shares and actual cost on the production records.

Multilevel processing can use a bulk intermediate SKU, then a separate packaging order. Rework consumes the old lot and produces a new lot with its own cost and traceability. Outsourcing uses subcontract_orders for company owned inputs sent to a supplier location; record the service invoice as a production cost and the resulting output through the same production event model.

## 10 Traceability quality and recall

lot_genealogy links actual input stock entries to output entries through a production order. This supports both backward tracing from a sold bottle to ingredient lots and forward tracing from a suspect ingredient to every affected output. In blended batches, the conservative rule is that every actual input lot can affect every output lot unless the process records a narrower verified allocation.

The physical lot graph is separate from the cost consumption graph. Never use FIFO cost layers as evidence of which supplier lot entered a particular batch. quantity allocations must be meaningful within each input unit and must not be summed across incompatible dimensions.

quality_specs and quality_spec_tests hold versioned criteria. quality_inspections ties the lot, specification and source document to an inspector. quality_results freezes the measured result and criteria. lot_status_events is the append only release and recall history; lots.release_status is the current projection. Release and corresponding stock condition moves commit atomically.

A recall case includes seed lots in recall_lots, expands through lot_genealogy, blocks affected remaining stock and identifies delivery or invoice stock entries for notification. Affected stock already sold must remain in the trace report. Returns from a recall enter quarantine and are destroyed or released only through an authorized process.

## 11 Purchasing and material planning

The purchasing flow is requisition, supplier comparison, purchase order, physical receipt, supplier invoice, match and payment. Purchasing these stages separately supports partial deliveries, one invoice covering several receipts and invoices arriving before all goods. The system must not receive physical stock again when an already received supplier invoice is posted.

goods_receipt_lines and purchase_matches retain ordered, received and billed links. Service validation checks the same supplier, item and unit basis, cumulative quantities, accepted tolerance and invoice uniqueness. supplier_items supplies supplier SKU, lead days and minimum quantities. Duplicate supplier invoice numbers are prevented per supplier and company.

Physical supplier returns use supplier_returns and stock movements. Supplier financial credits use supplier_credits and credit open items. Relate them when appropriate, while allowing damaged goods to be replaced without a credit or a price adjustment without a physical return. Cheque or bank payment affects settlement only when its configured confirmation condition is met.

Planning considers confirmed demand, released production plans, available released stock, reservations, open purchase orders, expected production receipts, lead times and safety stock. Quotes do not become demand until confirmed. planning_runs records a reproducible watermark; supply_suggestions proposes BUY, MAKE or TRANSFER actions. Accepting a suggestion creates a reviewed business document. A planning run must not post stock movements itself.

## 12 Sales returns payments and cash

sales_orders stores quotes and confirmed orders. deliveries stores physical dispatch. sales_invoices stores financial recognition. For an immediate POS sale, fulfillment_mode is IMMEDIATE and posting the invoice issues stock. For wholesale fulfillment_mode is SEPARATE; delivery issues stock, and sales_delivery_matches links the invoice quantity. Invoicing a delivered item must not issue it again.

Prices, discounts, addresses, tax bases and rates are frozen at posting. Promotions are validated versioned rules; sale_discounts retains what actually applied. Manual price and discount overrides require permissions, thresholds and audit. Credit sales require an identified customer, an allowed credit policy and an atomic check of outstanding exposure including concurrent orders or invoices.

customer_returns records physical quantities and disposition, normally referencing original invoice lines. sales_credits reverses revenue, tax and receivables. payments records actual incoming or outgoing funds. A refund is an outgoing payment allocated to an available credit. Cap cumulative returned, credited and refunded quantities or values using locked source records; an authorized no receipt return follows a separate controlled policy.

payments and payment_tenders support cash plus card or other split tenders. Tender applied amount equals tendered less change; change is allowed only for a configured cash tender. Each captured payment creates an open item or explicit cash sale allocation, and settlements connects opposite signed balances. Unallocated customer receipts remain advances. Never store a paid flag as the financial source of truth.

pos_sessions records one cashier shift and opening float. Enforce one OPEN session per register by locking the register row; the schema deliberately does not rely on nullable uniqueness for that rule. Expected closing cash equals opening float plus captured cash receipts less cash refunds plus signed cash movements. Opening float is represented once: either as the session opening value or the corresponding opening movement in reporting, never both. Closing variance posts to an approved cash over or short account.

External payment capture cannot be atomic with a MySQL commit. Use payment_intents and provider idempotency, capture confirmation, integration_inbox deduplication and a recovery workflow. The posting service must be able to complete a confirmed captured payment after a retry without charging it again. A provider timeout is an unknown state to reconcile, not proof of failure.

## 13 Accounting contract

journal_entries references one posting document, with journal_lines containing the double entry. The sum of debits equals credits in document currency and in functional currency. Base only adjustment lines are supported for exchange and rounding effects. At least two nonzero lines are required. These are service invariants because a MySQL row CHECK cannot sum sibling rows.

| Event | Debit | Credit |
| --- | --- | --- |
| Accepted owned goods receipt | Raw or packaging inventory | Goods received not invoiced |
| Matched supplier invoice | Goods received not invoiced and eligible input tax | Supplier payable |
| Production material issue | Work in progress | Raw or packaging inventory |
| Applied production labor or overhead | Work in progress | Configured payroll clearing or overhead absorption |
| Finished goods settlement | Finished goods inventory | Work in progress |
| Abnormal loss | Production loss expense | Work in progress or inventory |
| Sale on credit | Customer receivable | Revenue and output tax |
| Sale stock issue | Cost of goods sold | Finished goods inventory |
| Customer payment | Cash bank or tender clearing | Customer receivable or advance |
| Supplier payment | Supplier payable or advance | Bank or payment clearing |
| Customer financial credit | Returns revenue and applicable tax | Customer receivable or credit balance |
| Depreciation | Depreciation expense | Accumulated depreciation |

Actual mapping depends on company policy and tax configuration. Expenses and supplier invoices must not both recognize the same cost. Payroll labor capitalized in WIP must be cleared or absorbed consistently when payroll posts, so the same labor is not charged twice. Stock owned by third parties is tracked physically without recognizing company inventory assets until ownership changes under an approved transaction.

open_items is the AR, AP and advance subledger. Original amounts are immutable. settlements records partial matching, cross currency amounts, functional settlement and realized exchange differences. Outstanding balance is derived from signed original amount and non reversed allocations. A settlement reversal is a new compensating settlement linked to the original.

Use a consistent sign convention: customer debit balances and supplier debit adjustments are positive; opposing credits are negative. The kind and control account identify whether the balance belongs to AR, AP or advances. The posting service must validate opposite signs, the same party and compatible control account treatment. Cross currency settlement records both item currency amounts and posts the exchange difference explicitly.

accounting_periods controls posting dates. Lock the relevant period while posting and while closing it. Reject overlapping periods and changes to closed dates through normal APIs. Backdating across a closed inventory or financial period requires an authorized correction in an open period. Reporting includes opening equity, tax, rounding, suspense and control account mappings before launch.

## 14 Offline operation and reconciliation

Each till has a device identity, receipt prefix and monotonic operation sequence. The local application stores an encrypted durable database, cached scoped catalog and prices, accepted policy versions, open local shift and an immutable operation outbox. A browser cache alone is not enough to promise durable offline sales. Choose a supported local SQLite host through a packaged desktop or local service, or explicitly validate a browser storage design before offering equivalent guarantees.

Before disconnecting, allocate specific released stock buckets to that device using stock_reservations and offline_stock_allocations. Centrally available stock decreases by the reserved amount. The device can sell only its remaining allocation and permitted cash tenders while offline. It cannot invent credit approvals, obtain fresh bank or card authorizations, override tax policies or confirm stock at other locations.

Offline allocations do not auto release merely because a time limit expires. A disconnected device may still hold legitimate unsynchronized receipts. Release requires acknowledged reconciliation or a supervised lost device procedure that revokes the device and resolves outstanding stock and cash. New recall or tax changes cannot instantly reach a disconnected device, so define a maximum permitted offline period and require reconnection before further sales after that period.

The user sees whether a receipt is local and awaiting synchronization. A device upload includes UUID, sequence, canonical payload hash, price and tax versions, allocation consumption and tender evidence. An identical retry returns the original result. The same operation key with a different hash is rejected. Preserve received operations before processing so a crash cannot lose a completed cash sale.

Server processing follows device sequence and locks the relevant allocation and source stock. A valid preapproved event posts exactly once using its original receipt reference. A stale price may be accepted under a preapproved offline policy; it must not be silently repriced after payment. Disallowed, duplicate, insufficient allocation, changed tax or revoked device events enter a visible conflict state. Cash evidence remains preserved even when financial posting awaits a supervisor. No conflict is silently dropped or rewritten with last write wins.

Offline returns, gift instruments, loyalty redemption, credit extension and complex promotions should initially require online confirmation. If a business needs those fully offline, specify dedicated quotas and fraud controls before enabling them. Operating offline cannot guarantee immediate knowledge of recalls or activity at other disconnected devices; the product must show these limits clearly.

## 15 Constraints and service responsibilities

| Invariant | Database enforcement | Required service enforcement |
| --- | --- | --- |
| Tenant and company relationship | Composite foreign keys | Scope every query and authorize membership |
| Duplicate document or supplier reference | Unique business keys | Normalize input and return useful conflict errors |
| Valid row status and positive quantities | CHECK constraints | Validate transitions and cumulative quantities |
| Immutable ledgers | Update and delete guards | Only insert through approved posting commands |
| Correct document subtype | Root FK and insertion trigger | Require complete subtype and correct lines before posting |
| Stock availability | Unique balance row | Lock balance and reservation rows and check quantity |
| Balanced journal | Nonnegative and one sided row checks | Sum both currencies before commit |
| Valid recipe | Scope keys and basic quantities | No cycles, version freeze, output allocation sum |
| One active till session | Register and status index | Lock register and reject a second open shift |
| Return and refund cap | Original source links | Lock sources and cap all prior returns and allocations |
| Closed period | Period FK | Lock period and validate business date and status |
| Tax or price effective range | Start date keys | Prevent unintended overlaps and resolve priority |
| Valid serial movement | Serial identity and movement links | Enforce one current unit and matching lot |
| Exactly once financial effect | Idempotency and source uniqueness | One transaction for result, ledger, projection and outbox |

The included guards are defense in depth, not a complete posting engine. Restrict the runtime database user from DDL, DROP, TRUNCATE and disabling constraints. A migration identity owns schema changes. Posted data is corrected through commands; a privileged database operator can still bypass application policy, so restrict access and retain database audit or operational evidence.

## 16 Indexes reporting and growth

Business queries begin with tenant and company. Important paths include document branch and business date, bucket movement history, account ledger by ID, pending offline operations and outbox scheduling. MySQL creates supporting child foreign key indexes when needed. Review generated and explicit indexes against real query plans to avoid retaining redundant indexes at high volume.

Report stock as of a date from stock_entries and cost history, not current stock_balances. Report aged receivables from open items and settlements at the cutoff. Separate financial invoice reporting from physical delivery reporting. Keep original and reversal documents visible so net reporting remains correct without erasing history.

Start on one primary database. Heavy reports can use asynchronous projections and later a replica, but checkout and immediate credit availability must read the authoritative primary. Stock projections are not a license to accept stale payment or availability data. Add incremental summary tables only after a measured query need and a defined rebuild process.

Do not initially partition these foreign key related InnoDB tables: MySQL 8.4 does not support foreign keys on user partitioned InnoDB tables. Growth options are better indexes, archival of eligible operational payloads, reporting separation and routing whole tenants to database shards. Tenant and company keys provide a migration boundary. A single tenant restore from shared backups is a scoped extraction and replay operation with reconciliation, not a whole database overwrite.

## 17 Implementation sequence

- Build identity, tenants, companies, access scopes, reference data, document lifecycle and audit.

- Build catalog, units, suppliers, purchasing, lots and the stock posting engine.

- Add accounts, journals, open items, settlements and automatic posting mappings alongside stock operations.

- Add recipes, production events, WIP valuation, packaging, quality release and recall traceability.

- Add POS, sales, returns, split payments, credit policies and cash closing.

- Add device registration, durable offline storage, stock quotas, synchronization and conflict review.

- Add planning, workforce, payroll localization, assets, banking, loyalty and advanced reporting in controlled releases.

For the coconut business, launch requires at least reliable procurement, production, expiry and quality handling, inventory, sales, payments and financial reconciliation. Optional modules can stay disabled until their screens and posting contracts are implemented.

## 18 Required validation before production

Execute all migrations and guard triggers on the exact MySQL 8.4 patch selected for deployment. Verify seed data and clean rebuild. Run negative tenant and company relationship tests, raw SQL isolation tests, concurrent checkout and duplicate synchronization tests. The supplied validation report distinguishes static checks already performed from runtime tests required before release.

Reconcile stock balances to movements, remaining FIFO values to layers and adjustments, journals in both currencies, WIP to production costs, stock control accounts to owned valuation, receivables and payables to their control accounts, and till expected cash to tenders and movements. A release with unexplained differences is incomplete.

Run a full acceptance story: purchase coconut and non coconut ingredients, receive two supplier lots with expiry, record packaging, release a recipe, produce and package multiple output lots, test quality, sell through two tills, process partial credit and cash refund, record a physical count variance, and trace a recalled ingredient to remaining stock and sold products. Repeat with a deliberately interrupted offline device and duplicate uploads.

## 19 Official technical references

MySQL LTS release model: https://dev.mysql.com/doc/refman/8.4/en/mysql-releases.html

MySQL foreign keys and partition limitations: https://dev.mysql.com/doc/refman/8.4/en/create-table-foreign-keys.html

MySQL locking reads: https://dev.mysql.com/doc/refman/8.4/en/innodb-locking-reads.html

.NET support policy: https://dotnet.microsoft.com/en-us/platform/support/policy

MySqlConnector documentation: https://mysqlconnector.net/
