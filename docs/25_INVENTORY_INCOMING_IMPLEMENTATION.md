# P1-05 Inventory and Incoming Stock

P1-05 is complete and ready for owner review. SysConex approved the posting policies, migrations 0008–0009 and associated grants on 28 November 2026 for conex360-auth-review and private conex360-p105-clean. [Concrete SQL and policy review](26_P1_05_DATABASE_REVIEW.md)

The implementation adds exact-cost opening and GRN previews and posting, posted document details and printing, warehouse and lot stock views, movement history, and read-only ledger reconciliation. The posting transaction commits numbering, document/lines, lot and bucket identities, ledger entries, balance projections, audit and idempotency together. The current company, outlet permissions, warehouse and catalogue versions, and expected company currency are checked before new effects. Opening stock is Administrator-only. Staff can receive and read quantities in granted ordinary outlets. Historical cost fields and reconciliation are Administrator-only.

Reused modules now guard physical stock from outlet, warehouse and product deactivation. Posted items retain their base UOM, tracking/expiry rules and historically used conversion factors. Active default replacements preserve access to stock in the old warehouse. P1-06 will add pending transfers/reservation checks. P1-08 customer display remains as specified.

## Files and database

- `0008_inventory.sql` adds document_sequences, documents, document_lines, goods_receipts, lots, stock_buckets, stock_balances, stock_entries and idempotency_keys, plus a scoped location key.
- `0009_inventory_guards.sql` protects immutable facts. Runtime grants are scoped to read/append, with updates on balance projections and numbering. Separate migration credentials are used by the existing runner.
- Domain `ReceiptMath`, Application inventory contracts, Infrastructure `InventoryStore`, API `InventoryEndpoints` and private Next.js inventory routes extend the existing projects. No dependency changes.
- `InventoryTests.cs`, `ReceiptMathTests.cs` and `inventory.spec.ts` cover the critical paths using existing fixtures and tooling.

## API and local use

Under `/api/v1/inventory`, GET `warehouses`, `stock`, `movements`, `documents`, `documents/{id}` and Administrator-only `reconcile`. POST `opening-stock/preview`, `opening-stock`, `goods-receipts/preview` and `goods-receipts`. All use the existing session/context headers and CSRF rules. POST uses an actor-scoped UUID in the body. Retry an uncertain request with the same UUID and payload while the form is open. Verify posted history before re-entering a request if the browser loses its pending form. Currency, quantity and cost values come from the server or exact decimal strings.

Posting is enabled on the review API after schema and integrity verification. Readiness requires schema version 9. Open `http://127.0.0.1:3602`, select an outlet and choose Inventory. Enter opening stock before the first movement for that product and warehouse. For a receipt, choose an active supplier, enter unit, quantity, cost, lot and disposition, preview and confirm, then open the committed document. Workbench uses read-only loopback port 3307. To disable posting if an integrity issue is discovered, set `CONEX360_REVIEW_INVENTORY_ENABLED=false` and recreate only the review API using both review Compose files.

The existing tools service ran with both `CONEX360_MYSQL_APPROVED=1` and `CONEX360_INVENTORY_MYSQL_APPROVED=1`, filtering `InventoryPosting`. The focused case created the synthetic warehouse, product and supplier used by the opt-in Playwright case. The browser run used `playwright.auth.config.ts inventory.spec.ts`. [Desktop receipt](../artifacts/auth-review/p105-receipt-desktop.png) · [Mobile stock](../artifacts/auth-review/p105-stock-mobile.png)

## Verification

| Check | Result |
|---|---|
| `dotnet format --verify-no-changes --no-restore` and Release build | Passed with zero build warnings or errors |
| `dotnet test --no-build -c Release` | 33 unit tests and 10 HTTP integration tests passed in the previous pass. Opt-in MySQL coverage was run separately as listed below |
| Frontend lint, typecheck, unit tests and production build | Passed. 10 frontend unit tests. The build includes the private printable document route |
| Compose config-only validation | Review and private clean configs passed. Existing review MySQL still publishes only to localhost port 3307 |
| Protected files and whitespace | Previous migrations, historical references and customer display specification unchanged. Git diff check passed |
| Approved MySQL migrations and grants | Upgrade 0007→0009 passed with the same 54 tenants and six items before synthetic tests. Clean 0000→0009 install and checksum replay passed. Review journal contains 10 versions and 14 new immutability triggers. Private clean port bindings were empty |
| Focused real MySQL integration | Passed once on each target. Covered opening stock, expiry and lot identity, concurrent identical and distinct receipts, changed payload rejection, rollback, stock reconciliation, cross-tenant and outlet denial, Staff cost redaction, immutable writes and deactivation guards |
| Review runtime | API and frontend Docker builds passed, database readiness healthy, authorized inventory posting confirmed. Existing SSL read-only Workbench account saw 27 tables and journal entries 0008–0009 on localhost:3307 |
| Browser GRN and responsive smoke | One workflow passed. On the inclusive expiry date, 2 cartons × 24 yielded 48 available base units. Display total was LKR 24.69 and the ledger and projection both retained 24.691356 carried value. Desktop and 390px mobile screenshots captured |

The first streamed grant command encountered a PowerShell trailing carriage return. Reapplying the same script through LF-normalized stdin succeeded. Only the review API, frontend and proxy were restarted. The clean database was stopped with its volume retained. SchoolGrid containers kept their original IDs and status.

There are no remaining P1-05 failures or blockers. P1-06 Transfers, Adjustments, Waste and Stock Takes follows owner review.
