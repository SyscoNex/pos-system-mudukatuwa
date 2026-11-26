# API design — proposed contracts
Base `/api/v1/companies/{companyId}`; authenticated tenant/membership resolved server-side. Company route ID must be authorized. Branch/warehouse IDs are validated from server lookup, not assumed trusted. Use JSON DTOs with string IDs and decimal strings, ISO dates, UTC timestamps. Standard problem details with stable code, traceId and field errors; no internal SQL. Use 401 unauthenticated, 403 denied (or consistent 404 for inaccessible resource), 409 version/state/idempotency conflict, 422 valid structure but rejected policy, 400 malformed. Cursor pagination (stable indexed date/id), filter allowlists, bounded page/export sizes. Mutable edits require expectedVersion or If-Match. Posting commands require Idempotency-Key and canonical payload hash. API paths below are proposed; generate OpenAPI and contract tests at implementation.

| Verb/path relative to base | Purpose |
|---|---|
| GET /branches; GET /warehouses | Authorized scope choices |
| GET /items; POST /items | Catalog; scoped creation |
| GET /inventory/balances | Filters branchId, warehouseId, itemId, lotId, condition; available/reserved/transit |
| GET /inventory/movements | Ledger detail/date range |
| GET /inventory/expiry; GET /inventory/reorder | Alerts |
| POST /transfers | Draft request |
| POST /transfers/{requestId}/submit; /approve | Workflow approval |
| POST /transfers/{requestId}/dispatches | Post actual lot allocations |
| POST /transfers/{requestId}/dispatches/{dispatchId}/receipts | Post partial actual receipt |
| POST /transfers/{requestId}/dispatches/{dispatchId}/resolutions | Approved discrepancy resolution |
| POST /transfers/{requestId}/cancel-remainder | Cancel undisbursed remainder |
| GET /transfers; GET /transfers/{requestId} | Status, manifests, history and balances |
| POST /stock-counts; POST /stock-counts/{id}/post | Approved variance |
| POST /purchase-orders; POST /goods-receipts | Procurement |
| POST /supplier-invoices; POST /supplier-returns | AP and receipt matching |
| POST /production-orders/{id}/release; /events | Freeze plan; actual manufacturing |
| POST /lots/{id}/release; GET /lots/{id}/trace | QC release and recall tracing |
| POST /pos/sessions; POST /pos/sessions/{id}/close | Register control |
| POST /sales/checkout | Atomic sale/confirmed cash posting |
| POST /sales/{id}/credits; POST /payments | Corrections/payment |
| POST /devices/{id}/operations | Durable upload and outcome |
| GET /devices/{id}/changes | Scoped sync feed/checkpoint |
| GET /reports/{reportKey}; POST /exports | Scoped report and async export |

## Example transfer dispatch command (illustrative, not implemented)
```json
{
  "expectedVersion": "3",
  "businessDate": "2026-11-24",
  "lines": [
    {"requestLineId": "124", "allocations": [
      {"sourceBucketId": "881", "quantityBase": "30.000000000"}
    ]}
  ],
  "notes": "Delivery to Outlet A"
}
```
Server resolves source/destination, item/lot, tenant and company from request and bucket; rejects inconsistent routes. Receipt example:
```json
{
  "businessDate": "2026-11-24",
  "allocations": [
    {"dispatchAllocationId": "556", "destinationLocationId": "904", "quantityBase": "20.000000000", "condition": "AVAILABLE"}
  ]
}
```
Exact allocation ID is a proposed API abstraction; storage representation needs approved migration. The response includes stable request/dispatch/receipt IDs, document number, posted timestamp, updated cumulative quantities and current derived status; include only authorized detail. An incomplete delivery is not a loss without resolution.

Problem response example: `{"type":"about:blank","title":"Stock conflict","status":409,"code":"INSUFFICIENT_AVAILABLE_STOCK","traceId":"..."}`. Never expose another tenant's record details. Replayed exact requests return original business identity, not a new receipt.
