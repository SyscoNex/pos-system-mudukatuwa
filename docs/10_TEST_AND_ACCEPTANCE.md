# Phase 1 acceptance and release gates
Tests accompany each vertical slice. Use deterministic unit tests for math/policy, real MySQL 8.4 for constraints/locking/transactions, API contracts and focused browser tests. SQLite/in-memory stores do not prove InnoDB behavior.
Fixtures: two tenants with identical codes, default companies, factory/outlet warehouses, Admin and Staff with differing grants, several lots/expiry dates and exact costs. Include a shared global user to exercise membership boundaries. No production data.

| ID | Test | Required result |
|---|---|---|
| P1-T01 | Versioned schema clean install and next-slice/release upgrade | Only approved Phase 1 tables/constraints/guards/setup; no financial or historical-schema dependency; record first-release upgrade limitation |
| P1-T02 | Login/session/logout/reset/disable/CSRF/rate limits | No stale or revoked session writes; no tenant Admin takeover of shared identity |
| P1-T03 | Foreign tenant/company/outlet IDs across SQL/API/reports/files | No disclosure/mutation; branchless Staff has no stock access; no transit bypass |
| P1-T04 | Atomic business/default-company/first Admin setup | Exactly one company per tenant; failed setup leaves no partial business |
| P1-T05 | Catalog/UOM/barcode/price and immutable snapshots | Exact conversions and item-unit pairing; old receipt/stock evidence survives edits |
| P1-T06 | Opening/incoming replay and missing cost/date | One document and stock effect; missing cost rejected, explicit zero distinguished; required lot/date validated |
| P1-T07 | Concurrent last-unit issue/dispatch/manufacture/sale | Only eligible quantity succeeds; no negative or over-reserved balance |
| P1-T08 | Response lost / same key / changed payload | Original result on identical retry; changed hash conflicts; durable operation reference |
| P1-T09 | Fault after entries/balance/payment/audit before commit | No partial committed facts/projections/payment/result |
| P1-T10 | 100/20 transfer example including partial receipt/loss | Quantity and carried-value reconciliation after each step; no destination availability before receipt |
| P1-T11 | Concurrent dispatch/receipt/resolve/cancel | Request and allocation quantity/value caps; no released reservation still dispatched |
| P1-T12 | Same-SKU multi-lot/multi-shipment pooled transit | Exact referenced lot/origin/value only; wrong destination/allocation/stage denied |
| P1-T13 | Damage/hold/expiry/blocking | Ordinary sale/manufacture denied; authorized disposition preserves identity/value/evidence |
| P1-T14 | Average-cost and allocation rounding residuals | No cumulative value drift; full depletion zeroes quantity/value; transfer/return carries exact original residual |
| P1-T15 | Count freeze with concurrent operation/cancel | Posting occurs before snapshot or is blocked; no long DB transaction; one variance and audited unfreeze |
| P1-T16 | Adjustment/waste versus reservations | Cannot silently consume reserved stock; authorized reason and actual cost; no direct balance repair |
| P1-T17 | Completed actual-input/output manufacture and packaging | All input/output or none; correct lot trace and carried value; reject missing/zero output or insufficient inputs |
| P1-T18 | Online checkout/discount/cash/change/split/partial payment | Exact totals, one stock issue and recorded payment; no tax/journal dependencies; unpaid-customer policy enforced |
| P1-T19 | Concurrent return/refund/correction | Source quantity/credit/cash caps; original prices/costs; held/damaged returns unavailable; immutable evidence |
| P1-T20 | Operational reports and projection reconciliation | Bucket quantity/value, transit/reservations, purchase/sales/return/payment totals agree with facts; no GL/WIP claims |
| P1-T21 | Browser/private API/HTML/RSC caches and context switch | No cross-user/outlet data; clear drafts/stale reads; revoked grants enforced by API |
| P1-T22 | Built Node/API images and reverse proxy | Pages/assets and /api routing work, secure cookie/forwarded HTTPS, no bundle secrets, no public DB |
| P1-T23 | Browser print/scanner/manual weight/network loss | Reprint original; no second sale; keyboard usable; unavailable network cannot create queued checkout |
| P1-T24 | Encrypted off-host backup and isolated restore | Restore DB, logos/receipt assets and keys; revoke restored sessions; reconcile stock/transit/documents/payments/users; measure loss/recovery |
| P1-T25 | Small representative workload and access/UX | Agreed outlet/SKU/history use is responsive; errors/accessibility recoverable; no untested throughput claim |
| P1-T26 | Direct DB guard and privilege checks | Posted document/line/entry/allocation/payment/audit facts cannot be edited/deleted; authorized projections remain mutable; runtime cannot migrate |

Posting tests must exercise actual server integration, not only mocks of repository calls. Reconciliation is a read/check, never a test that fixes balances to match. Run rollback and concurrent conflicts on independent MySQL connections. Include deadlock/timeout retry and uncertain-commit replay.
Reports can use a consistent read snapshot. Do not confuse an AUTO_INCREMENT ID with a committed cutoff or silently combine business-date and posting-time views.

## Pilot acceptance
Client accepts actual outlets, item units/costs, lot/expiry policy, simple manufacture limitations, discount/payment/return rules and receipt appearance. Dry-run: receive ingredients/packaging, manufacture bulk and bottled output, partial factory/outlet transfer, damage/loss resolution, sale/payment, return/refund, count/waste, operational reconciliation, backup restore and Staff permissions.
No double-entry/GL/period/tax/offline/advanced-QC test gate exists in Phase 1. Legal suitability of intended receipt use is not a software compliance claim.
Record commands, environment, versions, fixture outcomes, failures and deferred tests. The original documentation-only revision ran no application/MySQL tests. P1-01 now has 22 unit, 7 API-host integration, 9 frontend contract and 4 browser tests passing; see [actual evidence](18_FOUNDATION_IMPLEMENTATION.md). These do not claim the future Phase 1 matrix above or real MySQL inventory tests are complete.
