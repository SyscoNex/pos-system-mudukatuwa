# P1-05 Inventory and Incoming Stock

P1-04 was accepted on 28 November 2026. P1-05 code is prepared for review. The posting policies and execution of migrations 0008–0009 are separately gated. [Concrete SQL and policy review](26_P1_05_DATABASE_REVIEW.md)

The implementation adds exact-cost opening and GRN previews and posting, posted document details and printing, warehouse and lot stock views, movement history, and read-only ledger reconciliation. The posting transaction commits numbering, document/lines, lot and bucket identities, ledger entries, balance projections, audit and idempotency together. The current company, outlet permissions, warehouse and catalogue versions, and expected company currency are checked before new effects. Opening stock is Administrator-only. Staff can receive and read quantities in granted ordinary outlets. Historical cost fields and reconciliation are Administrator-only.

Reused modules now guard physical stock from outlet, warehouse and product deactivation. Posted items retain their base UOM, tracking/expiry rules and historically used conversion factors. Active default replacements preserve access to stock in the old warehouse. P1-06 will add pending transfers/reservation checks. P1-08 customer display remains as specified.

## Files and database

- `0008_inventory.sql` adds document_sequences, documents, document_lines, goods_receipts, lots, stock_buckets, stock_balances, stock_entries and idempotency_keys, plus a scoped location key.
- `0009_inventory_guards.sql` protects immutable facts. Runtime grants are scoped to read/append, with updates on balance projections and numbering. Separate migration credentials are used by the existing runner.
- Domain `ReceiptMath`, Application inventory contracts, Infrastructure `InventoryStore`, API `InventoryEndpoints` and private Next.js inventory routes extend the existing projects. No dependency changes.
- `InventoryTests.cs`, `ReceiptMathTests.cs` and `inventory.spec.ts` cover the critical paths using existing fixtures and tooling.

## API and local use

Under `/api/v1/inventory`, GET `warehouses`, `stock`, `movements`, `documents`, `documents/{id}` and Administrator-only `reconcile`. POST `opening-stock/preview`, `opening-stock`, `goods-receipts/preview` and `goods-receipts`. All use the existing session/context headers and CSRF rules. POST uses an actor-scoped UUID in the body. Retry an uncertain request with the same UUID and payload while the form is open. Verify posted history before re-entering a request if the browser loses its pending form. Currency, quantity and cost values come from the server or exact decimal strings.

After policy and execution approval, upgrade the review database using both auth-review and Workbench Compose files. Apply the new runtime grant script and verify the private clean target. Enable `Inventory__Enabled=true` on the review API only after migration verification. Readiness then requires schema version 9. Use the review app on `http://127.0.0.1:3602`, select an outlet and choose Inventory. Enter opening stock before the first movement for that product and warehouse. For a receipt, choose an active supplier, enter units, quantity, confirmed cost and lot/disposition, preview, confirm and open the committed document. Workbench uses the existing read-only loopback port 3307.

Prepared MySQL test: run the existing approval-gated tools service with both `CONEX360_MYSQL_APPROVED=1` and `CONEX360_INVENTORY_MYSQL_APPROVED=1`, filtering `MySqlIdentityTests`. The focused inventory case creates the synthetic warehouse, product and supplier used by the opt-in Playwright case. The browser workflow covers receipt confirmation, posted document and stock at desktop and mobile widths. It writes screenshots after a successful run. Run both against the approved isolated targets only.

## Verification

| Check | Result |
|---|---|
| `dotnet format --verify-no-changes --no-restore` and Release build | Passed with zero build warnings or errors |
| `dotnet test --no-build -c Release` | 33 unit tests and 10 HTTP integration tests passed. 11 opt-in MySQL tests skipped |
| Frontend lint, typecheck, unit tests and production build | Passed. 10 frontend unit tests. The build includes the private printable document route |
| Compose config-only validation | Review and private clean configs passed. Existing review MySQL still publishes only to localhost port 3307 |
| Protected files and whitespace | Previous migrations, historical references and customer display specification unchanged. Git diff check passed |

The separate owner approval remains pending. Schema upgrade and clean install, real MySQL integration cases, browser receipt posting and screenshots are outstanding. The next milestone after P1-05 verification and owner review is P1-06 Transfers, Adjustments, Waste and Stock Takes.
