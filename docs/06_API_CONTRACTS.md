# Proposed Phase 1 API contracts

P1-03 actual /api/v1/organization routes and access matrix: docs/21_OUTLETS_WAREHOUSES_USERS_IMPLEMENTATION.md. Outlets/warehouses/users GET/POST and versioned PUT, authorized warehouse locations, GET/POST working context. Existing cookie/CSRF/origin/active-membership/company/context-revision checks apply. One-time Staff credentials never enter logs/browser persistence; no public existing-identity linkage.


## Implemented P1-02 / future display contracts
Actual authentication/business endpoints, CSRF headers, string IDs, context/row versions and errors: [implementation report](19_AUTH_BUSINESS_IMPLEMENTATION.md). Later endpoint proposals below remain unimplemented. No public registration or client-tenant-ID authorization.
P1-08 distinguishes provisional cart from server-confirmed totals and committed payment. Customer display receives a separate sanitized allowlisted DTO over BroadcastChannel, never backend entities or privileged commands. See [display protocol](20_CUSTOMER_DISPLAY.md).

P1-01 implements only GET /api/v1/health (plus process-only /health/live and /health/ready). It returns status/service/version/scope/timestamp; scope=process does not assert database or business readiness. Development-only /openapi/v1.json describes health. All business routes below remain unimplemented. Browser requests use same-origin /api/v1. In P1-02, tenant and the one default company will resolve from authenticated active membership; no company selector or tenant/company body binding. For a multi-membership user, a server-validated context-selection command may choose a granted membership; it never accepts arbitrary tenant authority.

Implemented foundation conventions: private/no-store API responses, safe problem details with code/traceId, structured redacted request/error logs, .NET validation registration and strict decimal/ulong string converters. There is no request-body business endpoint yet; module-specific bounds and authorization belong in their future slices.

| Endpoint group | Proposed behavior |
|---|---|
| POST /auth/login, /auth/logout, /auth/change-password; GET /auth/session | .NET owns cookie/session, revocation and CSRF behavior |
| GET/PATCH /business | Profile/logo reference/currency/timezone; prohibit unsafe currency changes after use |
| GET/POST/PATCH /users; POST /users/{id}/reset-password | Own-tenant Administrator; protect last active Admin, global-user reset boundaries |
| GET/POST/PATCH /outlets, /warehouses | Authorized lists and Admin setup; internal transit excluded |
| GET/POST/PATCH /items, /categories, /units, /suppliers, /customers | Scoped catalog/contacts; no generic cross-module CRUD |
| POST /opening-stock, /goods-receipts | Explicit quantities/lots/costs; once-only Inventory posting |
| GET /inventory/balances, /inventory/movements, /inventory/expiry | Bounded authorized warehouse/lot data and separate availability/transit |
| POST /transfers; POST /transfers/{id}/confirm | Draft then source-authorized reservation; destination requester cannot reserve arbitrary source stock |
| POST /transfers/{id}/dispatches | Exact source bucket allocations, approved request remainder |
| POST /transfers/{id}/dispatches/{dispatchId}/receipts | Partial/full exact dispatch-allocation receipt |
| POST /transfers/{id}/dispatches/{dispatchId}/resolutions | Admin loss/return with reason and original allocation |
| POST /transfers/{id}/cancel-remainder | Undisbursed remainder only; linked cancellation/reservation release |
| POST /stock-adjustments, /stock-waste | Admin, reason and cost/reservation rules |
| POST /stock-counts; POST /stock-counts/{id}/complete or /cancel | Logical freeze/snapshot, Admin variance posting or audited release |
| POST /manufacturing/runs | Completed actual input/output transaction; no WIP/order planning |
| POST /sales/quote, /sales/checkout | Server price/discount math and once-only online sale/manual payments |
| GET /sales/{id}/receipt | Posted immutable snapshots; reprints audited |
| POST /sales/{id}/payments, /sales/{id}/returns | Original-source locks and cumulative amount/quantity caps |
| POST /sales/{id}/refunds | Manual confirmed refund linked to return and capped by recorded receipts |
| GET /reports/{allowlistedKey}, /audit | Authorized bounded operational views; CSV escaping where enabled |

New routes require idempotency on business mutations; edits require expectedVersion/If-Match. Not every master-data operation needs a durable document, but all mutations need audit. POST /sales/quote has no side effects.

Use JSON string IDs and decimal strings, ISO local dates and UTC ISO timestamps. Define one canonical idempotency hash version with normalized validated DTO values; repeated identical key/hash returns original business identity/result, changed payload conflicts. Scope by tenant/company/membership/command and persist result in the transaction.
Use 401 unauthenticated; 403 or consistently non-disclosing 404 for inaccessible resources; 409 state/version/idempotency/stock conflict; 400 malformed input; 422 rejected valid policy input. Stable problem code, traceId and safe field errors; never raw SQL.
Bound page size and date range with allowlisted filters/sorts; stable date/id cursor. No unbounded company exports or user-supplied SQL/report names.

Illustrative receipt allocation: dispatchAllocationId string, destinationLocationId string, quantityBase decimal string and AVAILABLE/HOLD/DAMAGED disposition. Backend derives item/lot/company/remaining value; it rejects substituted references and unavailable quantity. Warehouse/type/stage/source relationships are independently checked.
Exact payload fields, path names, cookie/CSRF details and OpenAPI generation need approval with each slice. No tax, GL, period, offline operation, subscription or provider webhook routes in Phase 1.
