# P1-06 Stock Transfers, Adjustments, Waste and Stock Takes

P1-06 is complete and ready for owner review. On 29 November 2026 SysConex separately approved the migrations, runtime grants and isolated targets. The review upgrade and private clean install passed. Stock operations are enabled on the running review stack. [Migration and policy review](28_P1_06_DATABASE_REVIEW.md)

- Requests record exact converted base quantities and immutable request facts. Destination staff request. Source staff confirm, reserve by FEFO, dispatch and cancel the undisbursed remainder. Warehouse and grant checks run again inside the existing tenant/company transaction.
- Dispatch posts equal source and transit movements with an immutable allocation. Partial receipts, damage, hold, loss and return use the allocation's own carried residual. Return goes to the original source's HOLD location. Missing quantities remain in transit.
- Adjustments and waste post through the ledger with an explicit reason. Positive stock uses the P1-05 receiving validation and explicit unit cost. Decreases use the current bucket's carried value and cannot consume reservations.
- Stock takes capture an immutable expected snapshot and freeze the warehouse without holding a transaction open between requests. Staff can start and enter counts. Administrator posts the nonzero variances or cancels. Positive variances require an explicit cost. Unexpected identified stock can be entered at completion.
- Inventory shows reserved and available quantities. Transfer views show inspection and settlement progress and redact historical costs from Staff. Company reconciliation reports ledger, reservation, request, allocation, transit and count discrepancies. Outlet/warehouse deactivation checks stock, open transfers and active counts.

## Files and behavior

Migrations 0010–0011 add seven tables, a TRANSIT bucket constraint, scoped supporting keys and immutable guards. Existing documents, entries, projections, lots, audit and idempotency are reused. Two scoped immutable documents represent the ordinary and transit legs of a movement. The existing P1-05 permissions and migration safeguards apply. No dependencies were added.

The focused `InventoryStore` partials share one transaction guard and signed movement writer with receiving. New Domain issue arithmetic consumes exact residual on full depletion. New Application contracts, API routes and four private Next.js pages extend the existing workspace.

## API and local use

Routes below use `/api/v1/inventory/operations`, the existing cookie, CSRF and context header. Posting uses a UUID operation ID and exact JSON decimal strings. Repeat the same operation and payload after an uncertain result.

| Path | Access and behavior |
|---|---|
| GET `transfer-warehouses`, `transfers`, `transfers/{id}` | Scoped warehouse choices and transfer manifest. No unrestricted counterpart inventory |
| POST `transfers` | Destination-authorized request |
| POST `transfers/{id}/confirm`, `cancel`, `dispatch` | Source-authorized steps |
| POST `transfers/{id}/receive` | Destination-authorized settlement |
| POST `transfers/{id}/loss`, `return` | Administrator resolution |
| POST `adjustments`, `waste` | Administrator corrections and disposals |
| GET `counts`, `counts/{id}`; POST `counts`; PUT `counts/{id}` | Authorized warehouse count preparation and versioned actuals |
| POST `counts/{id}/complete`, `cancel`; GET `reconcile` | Administrator terminal actions and company reconciliation |

After approved migration and verification, set `CONEX360_REVIEW_STOCK_OPERATIONS_ENABLED=true` for only the review API. Use the existing review address `http://127.0.0.1:3602` and open Inventory, then Transfers, Adjustments, Waste or Stock Takes. Administrators can use the all-outlets management context to step through both sides. If the warehouse has an active count, resolve the count before posting another stock operation. If a variance conflicts with reservations, cancel the count, resolve the indicated transfer and restart. Keep both review Compose files for read-only Workbench access on localhost:3307.

To recreate the review API and frontend with this feature enabled, run the following from the repository root after the review images are built.

```powershell
$env:CONEX360_REVIEW_STOCK_OPERATIONS_ENABLED = 'true'
$review = @('-p', 'conex360-auth-review', '-f', 'infrastructure/compose.auth-review.yaml', '-f', 'infrastructure/compose.workbench.yaml', '--profile', 'database-approved', '--profile', 'runtime')
docker compose @review up -d --no-build --no-deps --wait api frontend
docker compose @review restart proxy
```

## Verification

The new P1-06 MySQL and browser tests are opt-in with `CONEX360_STOCK_OPERATIONS_MYSQL_APPROVED=1`. MySQL test execution also uses the existing general MySQL opt-in. The focused scenario prepares browser fixtures and tests conservation, replay, competing reserve/dispatch/receipt calls, rolled-back writes, held/damaged and returned stock, redaction, reserved-stock protection, freeze races, count completion and reconciliation. The browser workflow checks transfer request to partial settlement and completion, then starts and cancels a count.

| Check | Actual result |
|---|---|
| Release backend build | Passed with zero warnings or errors |
| Host regression | 33 unit tests and 10 HTTP integration tests passed. 12 opt-in MySQL tests were skipped in the host run |
| Approved P1-05 regression at schema 0009 | Passed on its existing private MySQL target after fixing the reserved-quantity fallback to retain its decimal SQL type |
| Frontend | Lint, type check, 10 unit tests and production build passed |
| MySQL migration and privileges | Review upgrade 0009→0011 and private 0000→0011 clean install passed. Clean checksum replay passed. Review retained 57 tenants and five documents before synthetic tests. Runtime grants allow INSERT/SELECT on allocation tables and INSERT/SELECT/UPDATE on four workflow tables |
| Focused MySQL integrity | P1-06 passed on both targets. P1-05 receiving regression also passed on the upgraded review target. The P1-06 scenario verified final source 70, destination 48 and transit zero, with exact 40 and 16 receipt values and 4 loss value |
| Read-only verification | SSL Workbench on localhost:3307 saw 34 tables and versions 0010–0011. Prior migration files and historical references match the worktree baseline. The clean target had no published ports and was stopped with its volume retained. SchoolGrid container IDs and status match the baseline |
| Review deployment | API and frontend images built successfully. Database readiness was healthy with stock operations enabled |
| Browser workflow | Passed transfer request, FEFO reservation, dispatch, partial receipt, final receipt, and stock-take start and cancellation. The first browser run assumed a two-warehouse fixture. Selecting the actual destination by ID fixed the smoke test without a product change. [Transfer screenshot](../artifacts/auth-review/p106-transfer.png) |

There are no remaining P1-06 blockers. P1-07 Basic Manufacturing follows owner review.
