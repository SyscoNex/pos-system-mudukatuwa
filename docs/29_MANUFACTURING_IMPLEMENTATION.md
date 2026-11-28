# P1-07 Basic Manufacturing

P1-07 is complete and ready for owner review. SysConex approved migration 0012, the scoped grant and the manufacturing policies on 29 November 2026. The existing review database and private clean target both passed verification. Manufacturing is enabled on the running review stack. [Concrete SQL and policy review](30_P1_07_DATABASE_REVIEW.md)

## Delivered

- Multiple actual raw, packaging or intermediate inputs produce one active, manufacture-enabled finished or intermediate SKU in an authorized ordinary warehouse. Staff can post for assigned outlets.
- Eligible FEFO or explicitly selected lots are checked under the inventory transaction lock. Repeated inputs share running bucket balances, reservations remain protected, and active stock takes block posting.
- Each allocation records its exact base quantity, lot, input group and carried issue value. The output absorbs the sum of those values. The preview shows provisional quantities and derived unit cost to authorized users. The backend recalculates at posting.
- Tracked output gets a new lot with its production date and required expiry. Untracked output uses SYSTEM. History follows an actual lot one hop backward or forward through completed runs, including packaging of an intermediate lot.
- One atomic PROD event commits the document, signed movements, stock projections, lot, audit and durable idempotency result. Previously posted transactions and roles remain immutable.
- Administrator-only reconciliation compares production events and lines against entries, checks input group conversions and carried-value conservation, then checks the existing ledger and balance projections.
- Manufacturing navigation opens the production form, history and trace views. Staff responses omit cost fields. No dependencies were added.

## Migration and policy details

Migration 0012 adds one production_events table, nullable explicit line roles and a scoped output entry link. Earlier migrations and stock history retain their checksums and contents. Operators are referenced by the existing immutable actor membership. The displayed operator name comes from the current display name linked to that actor. No physical trace is inferred for SYSTEM lots. Preview may change after intervening stock movement. If posting is unconfirmed, retry the same payload and operation ID or verify history before re-entering it. Manufacturing history has no line editing or undo operation.

## API and review usage

The cookie-authenticated API uses CSRF on mutations, the existing context revision header and exact decimal/string ID conventions.

| Path under /api/v1/inventory/manufacturing | Purpose |
|---|---|
| POST /preview | Plan inputs and output with current authorization and stock |
| POST /runs | Post a completed run using an actor-scoped UUID |
| GET /runs | History, optional warehouseId, inputLot, outputLot and before filters |
| GET /runs/{id} | Posted output, operator, notes and material allocations |
| GET /reconcile | Administrator production and ledger findings |

After approval and verification, set `CONEX360_REVIEW_MANUFACTURING_ENABLED=true` for the review API. Retain `CONEX360_REVIEW_STOCK_OPERATIONS_ENABLED=true` when recreating that API and use both the auth-review and Workbench Compose files. Readiness requires 0012 with manufacturing enabled. Open Manufacturing at `http://127.0.0.1:3602/inventory/manufacturing`, choose an authorized warehouse, enter actual input lines and good output, then preview and confirm. Use a new tracked output lot and record explicit expiry where required. Verify the posted history and inventory. Read-only Workbench stays on localhost:3307.

## Verification

The P1-07 MySQL scenario uses both `CONEX360_MYSQL_APPROVED=1` and `CONEX360_MANUFACTURING_MYSQL_APPROVED=1` and filters `ManufacturingConservesValueAndTracesBulkLots`. It covers multi-lot FEFO consumption, bulk-to-packaging value and trace, Staff permissions and redaction, replay and conflicts, ineligible inputs, late rollback, reservation and concurrent over-consumption protection, count freeze and read-only immutable history. The matching opt-in Playwright case uses the synthetic review fixture to post a multi-material run, verify details and output stock, and check the mobile viewport.

| Check | Actual result |
|---|---|
| Backend CI formatter and Release build | Passed with zero build warnings or errors |
| Host tests | 33 unit and 10 HTTP integration tests passed. 13 opt-in database tests skipped |
| Frontend | Lint, type check, 10 unit tests and production build passed |
| Local Compose config and protected files | Review and clean configurations validated without starting services. Workbench binding remains 127.0.0.1:3307. No prior migration, historical reference or customer display specification changed |
| Approved MySQL migration and privileges | Review upgrade 0011→0012 and private 0000→0012 clean install passed. Clean checksum replay passed. Review retained 60 tenants and 70 documents before synthetic testing. Runtime privileges on production_events are SELECT and INSERT only |
| Focused MySQL integrity | 1 passed on each target after limiting the planning lock to stock balances. Tested FEFO, bulk-to-packaging lineage, 11,200 carried into 20 units, count freezes, reservations, concurrency, replay, scoped access, redaction, immutable history and rollback after a late stock overflow. Production and ledger reconciliation returned no discrepancies |
| Review runtime and browser | API and frontend Docker builds passed. Database readiness was healthy after enabling manufacturing. One Playwright workflow posted two materials into two finished units with LKR 1,120 carried value, verified history and stock and passed the mobile overflow check. [Manufacturing screenshot](../artifacts/auth-review/p107-manufacturing.png) |
| Environment preservation | SSL Workbench on localhost:3307 saw 35 tables and migration 0012. SchoolGrid container IDs and status matched the baseline. The private clean target published no ports and was stopped with its volume retained |

The clean target initially reported a connection failure while MySQL was starting. Inspection confirmed an empty database, and retry succeeded. The first integrity run exposed an overly broad lock on immutable tables. Locking the balance alias fixed it while retaining the approved grants.

There are no remaining P1-07 blockers. P1-08 POS and the mandatory Customer Facing Display follow owner review.
