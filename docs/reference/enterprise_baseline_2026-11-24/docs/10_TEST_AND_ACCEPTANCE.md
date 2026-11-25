# Quality and acceptance plan
Use unit tests for domain math/rules, real MySQL 8.4 integration tests for SQL, constraints, transactions and concurrency (not EF InMemory/SQLite as substitute), API contract tests and browser end-to-end tests for critical operator flows. Testcontainers or equivalent disposable DB proposed. Seed synthetic tenants A/B with same SKU and overlapping business IDs/codes; companies and outlets in each. Use deterministic clocks, fixture data and isolated DB state. Fault-inject process/DB/network failures safely in test environment. Test both happy and adverse paths.

| Test ID | Scenario | Acceptance |
|---|---|---|
| T01 | Fresh migrations + upgrade | All expected tables, FKs, guards and seed exist; failure detected; no partial unsafe release. |
| T02 | Cross-tenant/company route/body IDs, FK, export, cache, file, worker | No foreign data or mutation; scope verified. |
| T03 | Unauthorized branch register/transfer receipt | Denied; no ledger or data leak. |
| T04 | Two tills last unit | One succeeds, other controlled conflict; no negative. |
| T05 | Duplicate checkout after response lost, changed payload | One invoice/payment/issue; exact response, changed hash conflict. |
| T06 | Inventory movement rollback after injected error | No partial balance/entry/journal/outbox effect. |
| T07 | Factory to outlet dispatch/partial receipts | Correct source, transit, destination and total at every step. |
| T08 | Two simultaneous dispatches/receipts | Quantity caps enforced under concurrency. |
| T09 | Multi-lot transfer, damage/loss/return, wrong lot or destination | Exact allocation lineage, non-sellable damage, approved loss only. |
| T10 | Transfer cost lineage, rounding and FIFO/FEFO difference | Same total value before loss, correct physical trace; no revenue/COGS. |
| T11 | Reservations/offline quota vs transfer/sale | No double allocation, quota not auto released. |
| T12 | Count cutoff with concurrent sale | Variance computed from correct snapshot and posted once. |
| T13 | PO partial receipts and invoice/return | No duplicate quantity; supplier matching and balances reconcile. |
| T14 | Recipe version edit after release; packaging, waste and partial output | Frozen plan, correct lot links, WIP settled. |
| T15 | QC hold/expiry/recall | Sale blocked; input-to-customer recall trace scoped. |
| T16 | Concurrent return/credit and delivery matching | Quantity and refund caps; invoice no duplicate issue. |
| T17 | Captured external payment + crash before commit | Provider reconciliation posts once, no second charge. |
| T18 | Offline restart/ack loss, gap, changed replay, revoked device | Durable original evidence, one post or review state, no lost cash. |
| T19 | Period close races with posting | Correct lock outcome; no posting into closed period. |
| T20 | Rebuild stock balances, journals, WIP and subledgers | Reconcile all projections to immutable facts. |
| T21 | Backup restore isolated; replay logs | Recovery measured, stock/financial/device state validated. |
| T22 | Checkout scanner, print failure, reprint, weighed item | Committed receipt only, no duplicate sale; real hardware verified. |
| T23 | Load with representative outlets and history | Record p50/p95/p99 latency, errors, DB locks, resource use; agreed targets met. |
| T24 | Browser keyboard/accessibility and network failures | Clear states, safe retry, no cross-context stale data. |
| T25 | Next.js authenticated SSR/RSC, prefetch, logout, outlet switch and reverse-proxy caching | No tenant data from another user; no shared cache of private content; revoked sessions denied by API. |
| T26 | Production Next.js Node image and Nginx routing | Pages/assets load, /api routes reach .NET, server-side API reads enforce scope, no client bundle secrets. |

## Pilot go-live gates
Approve client process/configuration, tax and accounting, opening stocks by outlet/lot/cost, opening AR/AP and cash, actual recipe/QC, printer/scale, users and grants, offline readiness if needed. Dry-run purchases, production, factory-to-outlet partial transfer, sale, return, shift close and period reporting with reconciliations. Run security and restore checks, staging smoke, monitoring alerts and support training. Sign off module-by-module with client; no production readiness claim until all agreed gates pass. Record test commands, build/version, environment, failures and evidence in PR/release record.
