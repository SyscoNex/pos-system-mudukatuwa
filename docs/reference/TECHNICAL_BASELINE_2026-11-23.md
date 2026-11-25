# Historical reference — Technical_Document.docx

Extracted from the original 23 November 2026 document. Text/table conversion only; not a new approval. Current pack clarifies outlet transfers and missing SQL prerequisites. See README and decision log.

POS Platform Technical Implementation

Version 1.0 | 23 November 2026

This document specifies how to implement the accompanying 160 table database as a shared manufacturing and POS platform. The first deployment serves a coconut product business, with modules and company configuration suitable for later customers in other industries. The implementation priority is consistent stock, traceability and financial records across online and offline sales.

## 1 Proposed stack and deployment shape

| Layer | Selection | Implementation requirement |
| --- | --- | --- |
| Backend | ASP.NET Core on .NET 10 LTS | Pin a supported patched runtime and SDK |
| Application | Modular monolith with API and worker processes | One primary database transaction for core posting |
| Database | MySQL 8.4 LTS and InnoDB | UTC sessions, strict SQL mode, utf8mb4 and fixed precision decimals |
| SQL access | MySqlConnector with explicit parameterized commands | One connection and transaction per posting command |
| ORM | Optional after provider compatibility validation | Do not assume matching EF Core and MySQL provider versions exist |
| Frontend | React and TypeScript proposed | Shared API contracts; decimal values and BIGINT IDs use strings |
| Offline host | Packaged till or local service with SQLite | Encrypted durable local storage and transaction outbox |
| Reverse proxy | Nginx or equivalent | TLS termination, request limits and routed static assets |
| Files | Private object storage or private backed up volume | Tenant scoped metadata and short lived authorized access |
| Integration | HTTP callbacks plus transactional outbox | Idempotent consumers and explicit provider reconciliation |
| Delivery | Versioned immutable application packages or containers | Separate deployment, migration and runtime credentials |

.NET 10 is a current LTS baseline according to the Microsoft support policy reviewed on 23 November 2026. Runtime and database patch versions are operational inputs and must be pinned at implementation. MySqlConnector provides ADO.NET transaction primitives without requiring an EF provider decision. If an ORM is chosen later, verify its actual supported server and runtime matrix and run the full schema against it.

Use a single deployable application organized by domain, with a separate worker process if useful. Microservices would introduce cross service consistency work before the product needs it. A later extraction must preserve the posting boundary or introduce an explicitly designed distributed workflow.

## 2 Modules and ownership

| Module | Owns | Public commands |
| --- | --- | --- |
| Identity and tenancy | Membership, permissions and scopes | Invite, grant role, select authorized company |
| Catalog | Items, units, barcodes and prices | Create item, update price, approve conversion |
| Procurement | Requisition, order, receipt and supplier billing | Approve order, receive goods, match invoice |
| Inventory | Buckets, movements, reservations and cost layers | Reserve, issue, receive, transfer, adjust |
| Manufacturing | Recipe versions, orders, operations and WIP | Approve formula, release order, issue, output, settle |
| Quality | Specifications, lot status and recalls | Record test, release lot, start recall |
| Sales and POS | Orders, invoices, returns and cashier sessions | Checkout, deliver, credit, close shift |
| Payments and finance | Tenders, journals, open items and settlements | Confirm payment, allocate, reverse, close period |
| Offline and integrations | Device inbox, quotas, outbox and callbacks | Allocate quota, upload operation, resolve conflict |
| Workforce and assets | Staff, payroll, equipment and maintenance | Approve time, post payroll, depreciate asset |

Only Inventory creates stock_entries or updates stock_balances. Only Finance creates journal_entries and journal_lines. A Sales or Manufacturing command invokes those modules in the same application transaction. Domain modules do not update each other's tables through arbitrary repositories.

The codebase should contain Domain, Application, Infrastructure, Api and Worker projects or equivalent folders with enforced dependency direction. Domain logic must not depend on HTTP, UI or SQL libraries. Application handlers own transaction scope and call narrow domain services. Infrastructure implements SQL, object storage and external providers.

## 3 Tenant context and authorization

Authenticate the global user, then validate an ACTIVE tenant_membership. Resolve the requested company and branch against grants. Produce an immutable request context containing tenant ID, company ID, membership ID, permitted branches and permissions. Public request DTOs must not bind internal tenant_id columns.

Every repository method requires this context. Every SQL predicate and join includes the relevant tenant and company keys. A raw query, report endpoint or worker is subject to the same rule. Never use a single unscoped GetById method for business records. Composite foreign keys prevent cross company relationships but cannot prevent a developer from issuing an unscoped SELECT.

Authorization is command and data specific. A cashier needs sale.post for the selected branch and an open assigned session. A lot release requires quality.release. A credit beyond a threshold needs a separate return approval. A purchasing preparer does not automatically approve their own spend. Tenant administration must not grant platform operations access.

Cache keys include tenant, company, branch where applicable, and policy version. File access resolves attachments through scoped metadata before issuing a signed URL. Exports and search results follow the same rules. Do not include tenant names, customer data, payroll or full SQL parameters in general diagnostic logs.

## 4 Database creation and migration rules

Create a new empty database with an infrastructure account and select it explicitly. Apply 01_schema.sql, then 02_guards.sql, then 03_reference_seed.sql. The scripts do not create or drop an existing database. 04_reconciliation_queries.sql contains parameterized diagnostic SELECT statements and is not a migration.

The schema uses 160 CREATE TABLE statements followed by 636 ALTER TABLE foreign key statements. Creating all tables first resolves forward references. Never disable foreign key checks to hide an ordering problem. MySQL DDL auto commits, so a failed initial creation is not an atomic rollback. For a failed empty database initialization, recreate that empty database under an operator controlled procedure; do not rerun the file blindly against partial state.

Convert the initial scripts into reviewed versioned migrations when the repository is established. Store migration checksum and applied version. Test installation from empty and upgrade from the previous released version. Do not run database migrations automatically from every web instance on startup. One controlled deploy job owns migration execution.

Use expand and contract changes: add compatible columns and code, backfill in bounded scoped batches, verify, then remove obsolete structures in a later release. Avoid large unplanned blocking table alterations during checkout hours. Back up and rehearse restoration before risky transformations. A data migration rollback may require a compensating migration or restore rather than reversing a DDL file.

## 5 Common posting transaction

A posting command begins with authentication, structural request validation and policy resolution. Never hold a database transaction while waiting for a customer, printer, email service or payment gateway.

Within the transaction, reserve the idempotency record under its unique key. For an existing COMPLETED key with the same request hash, return the recorded response; a different hash is a conflict. The idempotency row, result and business effects commit together. Offline received payloads are durably stored in their inbox before a separate posting attempt.

Lock the accounting period row first, then the document or original source documents in stable order, then the device or register and party credit policy as applicable, then inventory balances and reservations in ascending ID order, then FIFO layers and settlement sources. Every handler must use the same lock hierarchy. Validate status, date, permissions, source identity, quantities, totals, credit exposure and current row versions using locking reads where needed.

Create the document root, typed header, line registry and typed lines. Add frozen tax rows. Invoke Inventory for movements and cost allocations. Invoke Finance for journals, open items and settlements. Assert that journal debits equal credits in both currencies and all side totals reconcile. Write audit and outbox records. Change the root to POSTED as the final domain mutation, record the idempotent response and commit.

If any step fails, roll back all posting effects. Use bounded retries with jitter for recognized deadlocks or lock timeouts, restarting the whole command with its idempotency key. Do not retry arbitrary validation failures or unknown gateway charges. READ COMMITTED is a proposed command isolation level, subject to concurrency tests; explicitly locked critical rows provide serialization for stock and credit checks. Reporting can use a consistent read snapshot.

The idempotency unique key is scoped by tenant, company, actor namespace, command and client key. Durable operation and document references prevent duplicate business events beyond the short HTTP retry retention period. An automatic TTL cleanup must not remove the only evidence needed to reject a delayed offline replay.

## 6 Checkout workflow

Online checkout submits item, quantity, selected UOM, optional scale evidence, claimed price version, discount request and tenders. The server recalculates the approved price and tax policy before obtaining a final payment confirmation. Unexpected price differences return a requote response for customer acceptance. Do not silently increase a captured amount.

Confirm an open cashier session and branch. Lock and allocate eligible lot stock, choose FEFO physical picks and FIFO cost layers in the appropriate warehouse and ownership pool. For an immediate POS invoice, create the invoice's stock issues. For separately delivered wholesale goods, only match the existing delivery; do not issue stock twice.

Record the sale receivable, revenue, tax and cost of goods sold. A captured payment posts separately with its own PAYMENT root, tender split and clearing entry, then settles the sale open item. For synchronous cash checkout, both documents can be created in one MySQL transaction. For external payment, use the recovery workflow below. Every payment and invoice has a stable independent business identity.

After commit, print or download the receipt. A printer failure does not roll back a completed sale or trigger a second charge. Reprinting uses the original invoice and creates an audit event. The UI shows committed receipt number, remaining balance and any payment state awaiting confirmation.

## 7 Production workflow

Approve a recipe only after verifying dimensions, positive inputs, output allocation, effective dates, substitutions and graph acyclicity. Release a production order by exploding the approved multilevel formula into production_material_plans and frozen production_operations. Reserve eligible ingredient and packaging stock.

Each actual issue, leftover return, output, waste or rework creates a PRODUCTION_EVENT document and production_event_lines. Inventory links movements to those line IDs and records actual lot evidence. Material issues debit WIP at consumed cost. Production costs record direct labor and approved applied overhead without double charging the subsequent payroll or supplier invoice.

Output creates new lots and stock entries, initially quarantined. Partial output may use a documented provisional cost. Final settlement allocates the remaining batch cost across output entries and posts layer value adjustments when required. The service validates that allocation and abnormal losses exhaust the eligible WIP balance. It must not recognize revenue from production itself.

Genealogy links actual input and output entries independently of accounting cost layers. QC test and release commands update current status, append lot_status_events and move bucket condition atomically. Packaging can be a second production order consuming bulk output plus bottle, cap and label SKUs. A batch is closed only after costs, quantities, trace links and quality exceptions reconcile.

## 8 Returns credits and financial corrections

Lock original invoice and relevant source lines before computing remaining returnable or creditable quantities. Confirm customer, item, tax snapshot and original lot where known. A physical return receives stock into quarantine unless an approved inspection allows immediate restock. Value it using the original issue cost and approved recoverability policy.

Create a separate SALES_CREDIT document for revenue and tax reversal. Create an outgoing PAYMENT for actual refund and settle the customer's available credit. A price correction may create a credit without a physical return. A replacement may create a return and a new delivery with financial treatment configured independently.

If the requested correction affects a closed period, post the authorized correction in an open period with a relationship to the original. Do not edit old journals, change original tender evidence, delete stock entries or toggle a paid flag to repair balances.

## 9 External payments and integrations

Create a payment_intent with a stable provider idempotency key. Authorize or capture outside the MySQL posting transaction. Persist callback receipt with integration_inbox, deduplicated by provider and event ID. Validate provider signature and compare currency, amount and merchant account before applying the event.

After a confirmed capture, post the payment and allocate it to the invoice using idempotent commands. A process crash between capture and posting is recovered by polling or replaying the confirmed provider event. A timeout remains pending until reconciled; it must not automatically generate a second capture. A captured payment whose stock cannot be fulfilled requires a visible exception and approved fulfillment or refund path.

The outbox worker publishes committed events for notifications, reporting and integrations. Claim rows with a bounded lease, deliver outside the posting transaction and mark success idempotently. A lease expiry permits retry, so delivery is at least once. Every consumer deduplicates by event UUID. Failed events use bounded backoff and a reviewed dead letter process, with no secret or card data in payloads.

## 10 Offline till protocol

The first offline implementation supports preallocated stock, preapproved price and tax versions and cash tenders. Offline card acceptance requires explicit support and rules from the chosen payment provider; the application must not pretend that caching a card request confirms payment. Credit sales, broad stock overrides and offline returns stay disabled until separate controls exist.

Register the device through an authorized process and retain only its public verification key on the server. Store device credentials and the local encryption key in the host's protected credential facility. Bind data to tenant, company and branch. Local database backups and crash recovery must preserve committed receipts and the next sequence number.

Download a versioned catalog, pricing and policy snapshot plus exclusive stock allocations. Each local sale decrements its allowed quota and atomically writes receipt, cash evidence and an immutable operation outbox entry. A UUID is globally unique within its scope; a monotonic device sequence detects gaps. A client signature can protect transport evidence, but it does not make a malicious or compromised device automatically trustworthy.

Upload operations in sequence. The server first stores the canonical payload and hash in offline_operations. Duplicate UUID or sequence with identical content returns the original acknowledgement. A different payload under the same identity is rejected and audited. Gaps cause later dependent operations to wait or enter an explicit review state.

For a valid operation, lock the device and reservation, verify the quota and accepted policy versions, consume centrally reserved stock and post the sale and payment once. Acknowledge only committed results. The client marks its local operation synchronized after receiving that acknowledgement. Lost acknowledgements are safe to retry.

Never auto release disconnected quotas. Reconciliation closes an allocation only after all related operations are acknowledged and unused quota is confirmed. A lost or revoked device needs a supervised stock and cash review before releasing its allocation. Limit permitted offline duration because new recalls, price restrictions and tax rules cannot reach a disconnected device immediately.

Write change_feed through a serialized per company relay after the source outbox transaction commits. Assign feed IDs and commit sequentially under that relay lease; an arbitrary concurrent AUTO_INCREMENT insert stream is not a safe commit ordered cursor. Devices apply entity versions idempotently and retain tombstones. Snapshot download needs a consistent cutoff plus replay from that cutoff, so catalog changes during the download are not missed.

Conflicts preserve the original payload and cash evidence. The till and supervisor dashboard show RECEIVED, ACCEPTED, POSTED, CONFLICT or REJECTED. A conflicting cash sale cannot disappear simply because stock posting failed. Resolution creates an approved adjustment, fulfillment or refund document and links it to the preserved operation. Do not implement last write wins for stock, payments or journals.

## 11 API contracts and user interface

| Endpoint pattern | Purpose | Required safeguards |
| --- | --- | --- |
| POST /api/v1/companies/{company}/sales/checkout | Immediate sale and confirmed tender posting | Idempotency key, branch permission, price policy, stock locks |
| POST /api/v1/companies/{company}/goods-receipts | Receive supplier lots | Source order checks, expiry and QC rules |
| POST /api/v1/companies/{company}/production-orders/{id}/release | Freeze recipe plan | Approval and version conflict check |
| POST /api/v1/companies/{company}/production-orders/{id}/events | Actual material and output event | Lot authorization, WIP posting and idempotency |
| POST /api/v1/companies/{company}/lots/{id}/release | QC disposition | Quality permission and atomic condition move |
| POST /api/v1/companies/{company}/sales/{id}/credits | Financial correction | Original source locks and credit cap |
| POST /api/v1/companies/{company}/payments | Confirm money movement | Tender confirmation and settlement checks |
| POST /api/v1/companies/{company}/devices/{id}/operations | Durable offline upload | Device identity, sequence, hash and scope |
| POST /api/v1/companies/{company}/stock-counts/{id}/post | Approved count variance | Cutoff handling, approval and valuation |
| GET /api/v1/companies/{company}/lots/{id}/trace | Recall and batch trace | Scoped graph traversal and export permission |

These routes are proposed contracts, not generated controllers. Resolve every route company against the authenticated membership. Use ISO dates, UTC timestamps, decimal strings and string IDs. Return structured problem responses with stable error code, trace ID and field details, without SQL internals. Use 409 for version or business state conflicts, 403 for denied actions and 422 for validly structured but unacceptable business data where the API convention adopts it.

Paginate large lists with a stable cursor ordered by business date and ID or another indexed key. Return one explicit record version for edits. Do not use unbounded exports from the request thread; queue scoped export jobs with expiry controlled private files. A tax or price calculation preview is not a posted transaction.

The cashier UI needs fast scan and search, unit and weight display, lot or expiry warning, tender split, credit balance, return references and safe reprint. The production UI needs expected versus actual input, substitution approval, output lots, waste and QC state. The supervisor UI needs cash variance, offline conflicts, low stock, expiry, WIP and reconciliation exceptions. Show business states clearly rather than SQL table names.

## 12 VPS security and operations

Begin with a Linux VPS sized through measured workload. A provisional pilot starting point is 4 vCPU, 8 GB RAM and SSD storage, with disk capacity based on retention, logs and backup growth. This is a planning assumption, not a capacity guarantee or hosting quotation. Do not allocate all memory to MySQL; reserve capacity for API, workers, operating system and backup activity.

Expose HTTPS through the reverse proxy. Keep MySQL on a private interface or loopback, inaccessible from the public internet. Use least privilege database users, separate migration credentials, environment or secret manager injected credentials and restricted administrator access. Use SSH keys and a controlled administrative network path. Never place connection strings or signing keys in frontend bundles or source control.

Use secure session handling, strong password hashing or a supported identity provider, MFA for administrative and sensitive operations, CSRF protection where cookie authentication is used, rate limiting and permission checks. Do not store full card data or CVV; retain approved provider tokens and safe references. Encrypt backups and protect workforce and financial data at application and storage layers.

Single VPS deployment has a single failure domain. Process restart policies and health checks improve recovery but do not make it highly available. As customer importance or volume grows, separate database hosting, independent application instances and a tested failover design can be introduced. Any shared connection pool must be bounded against database capacity; one slow tenant needs rate and job concurrency limits.

Readiness checks validate essential dependencies without running expensive ledger queries. Liveness checks only confirm process responsiveness. Monitor API error rate and latency, pool exhaustion, lock wait and deadlock rates, database disk space, slow queries, worker lag, offline backlog and reconciliation differences. Set alerts around sustained failure and data integrity exceptions, not every transient retry.

## 13 Backups restore and tenant recovery

Use encrypted offsite full backups plus continuous or frequent binary log archiving for point in time recovery. Establish business agreed recovery objectives; proposed initial targets are RPO at most 15 minutes and RTO at most 4 hours, subject to restore rehearsal and infrastructure capability. A backup stored only on the same VPS is insufficient.

Document retention, encryption key recovery, backup verification and access ownership. Rehearse full restore in an isolated environment and reconcile stock, journals, open items and device checkpoints before returning service. Backup success logs alone do not demonstrate that restoration works.

Restoring one tenant in a shared database requires loading the backup into isolation, extracting a consistent tenant graph, replaying eligible later events and reconciling external payments and offline devices. Never overwrite all customers to recover one customer. Global user identity and shared reference tables need separate mapping rather than uncontrolled tenant deletion and reinsertion. Maintain a runbook and exercise it with a test tenant before promising self service recovery.

## 14 Reporting and growth

Use company scoped queries and indexed cutoffs for sales, stock, batch yield, gross margin, supplier balances, customer aging, WIP, expiry, cash and production cost. Reports must distinguish physical movement date from financial posting date and retain reversal visibility. Cross company group reports require an explicit account and currency translation model.

Build projections from committed outbox events with recorded checkpoints and a rebuild procedure. Heavy reports can later move to a replica or warehouse; transactional stock and credit decisions remain on the primary. Cache catalog and pricing with versions, while stock availability and captured payment state require authoritative checks.

Scale by measuring latency, query plans, hot rows, retained data and per tenant workload. Do not use table partitioning as the first scaling step for this FK related InnoDB schema. Whole tenant database routing supports later sharding, but it requires a platform routing catalog, tenant migration workflow and a no cross shard business transaction rule. Billing metadata and identity coordination can be separated from operational shards when needed.

## 15 Test and acceptance plan

| Test group | Required example | Expected result |
| --- | --- | --- |
| Installation | Apply schema, triggers and seed on pinned MySQL | Clean rebuild with all constraints and guards active |
| Isolation | Use tenant A membership with tenant B IDs in every API and export | Denied or no scoped record; no foreign data returned |
| Company scope | Link company A invoice line to company B item | Composite FK and service reject |
| Concurrency | Two tills sell the last available unit | One accepted issue; second gets a controlled stock conflict |
| Idempotency | Retry same checkout and hash after lost response | Original receipt returned; one stock and financial effect |
| Replay mismatch | Reuse device sequence with changed payload | Rejected and audited |
| Production | Partial output, ingredient return, waste and late charge | Correct trace, reconciled WIP and output cost |
| Costing | FEFO pick differs from FIFO layer | Correct physical trace and matching FIFO financial cost |
| Procurement | Partial receipt with freight billed after production | Matched invoice and approved downstream cost variance |
| Returns | Two concurrent credits against one invoice line | Cumulative quantity and refund cap preserved |
| Payment recovery | Capture succeeds and process crashes before DB commit | Reconciliation posts once without a second charge |
| Offline crash | Lose acknowledgement and restart device | Durable local receipt retried and acknowledged once |
| Offline conflict | Oversized quota consumption or revoked device | Visible preserved exception with approved resolution |
| Recall | Recalled ingredient used in two batches and sold partly | Remaining and sold affected output identified |
| Period closing | Post concurrently while closing the date period | Deterministic locking with no post after closure |
| Restore | Restore backup and replay selected logs | Reconciled ledgers and agreed recovery objectives |

Use real MySQL integration tests for relational and locking behavior. An in memory substitute cannot validate InnoDB foreign keys, triggers or concurrency. Add focused unit tests for recipe explosion, tax rounding, cost allocation and settlement arithmetic. UI tests should exercise the critical cashier and production paths without duplicating every lower level invariant.

Load test representative tenants with realistic history, lots, items, till concurrency and report activity. Agree latency targets only after measuring the selected VPS and payment provider. Avoid making a throughput promise from table count alone. A schema build and a successful happy path are insufficient release evidence.

## 16 Delivery milestones

The first milestone establishes tenancy, access, document identity, migrations and core posting tests. The second delivers purchasing, lots and inventory with accounting alongside it. The third delivers recipe based production, QC, packaging and traceability. The fourth delivers sales, returns, payment allocation and till closing. The fifth delivers offline quota allocation and conflict reconciliation. Subsequent milestones enable planning, banking, assets, workforce and localized payroll as complete modules.

At each milestone, require working user flows, scoped API contracts, database migrations, reconciliation queries, tests and an operator runbook. Keep feature flags disabled for unfinished modules. Trial with opening stock, opening customer and supplier balances, sample production and at least one accounting period close before importing all live history.

Hardware model and scale protocol, receipt paper format, supported offline host OS, payment provider, exact tax and payroll localization, actual product formulas, expected data volume and service recovery objectives are implementation decisions to resolve before their dependent module is released. The database already provides the boundaries and source records for those decisions.

## 17 Official technical references

.NET support policy: https://dotnet.microsoft.com/en-us/platform/support/policy

MySqlConnector: https://mysqlconnector.net/

MySQL locking reads: https://dev.mysql.com/doc/refman/8.4/en/innodb-locking-reads.html

MySQL foreign keys: https://dev.mysql.com/doc/refman/8.4/en/create-table-foreign-keys.html

MySQL release model: https://dev.mysql.com/doc/refman/8.4/en/mysql-releases.html
