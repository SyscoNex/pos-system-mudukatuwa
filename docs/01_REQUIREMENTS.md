# Phase 1 requirements
The owner approved Phase 1 scope/design on 25 November 2026 and authorized P1-01 foundation only. Earlier FIN/OFF/advanced requirements are future scope, preserved in the archive. All rows below are Phase 1 requirements, not completed functionality. Remaining operational policy choices appear in the plan/decision log.

| ID | Capability | Acceptance outcome |
|---|---|---|
| P1-AUTH-01 | Login/logout, secure sessions, password change/reset and revocation | Disabled user/session cannot call APIs; password reset revokes sessions; no browser-stored long-lived token |
| P1-TEN-01 | Tenant isolation and automatic default company | Two tenants can use identical SKU/outlet codes; foreign IDs never disclose or mutate data; business and company setup is atomic |
| P1-USER-01 | Administrator/Staff, outlet grants, enable/disable | Administrator manages own business; Staff operates granted outlets only; no platform powers implied |
| P1-BIZ-01 | Profile, logo, receipt contact details, currency/timezone | Branding is scoped; historical receipts keep posting-time snapshots; one company UI |
| P1-LOC-01 | Outlets and warehouses | Separate balances; warehouse/outlet choices authorized; transit is system-managed |
| P1-CAT-01 | Categories, items/SKUs, barcodes, base/alternate UOM | Exact conversions; barcode points to correct item unit; stocked identity/base UOM cannot be rewritten after use |
| P1-PRICE-01 | Purchase/sale defaults and controlled discounts | Server uses current approved price and retains snapshots; changing a default does not rewrite old transactions |
| P1-PARTY-01 | Suppliers/customers | One party may be both; inactive references remain in history; walk-in sales allowed |
| P1-INV-01 | Opening and incoming stock, basic costs | Posted once into selected warehouse/lot; positive quantity and explicit nonnegative cost; no AP/journal prerequisite |
| P1-INV-02 | Lots, manufacture/expiry dates, held/damaged/blocked state | Required dates enforced; ordinary sale/consumption rejects ineligible stock; transfer preserves identity/dates |
| P1-INV-03 | Stock history, balances and availability | Entries reconcile to quantities and operational values; no direct quantity editing, negative stock or hidden clamping |
| P1-TRF-01 | Request/reserve/dispatch/full or partial receipt | Source/storage and transit/destination change at correct steps; exact allocations cap cumulative quantities |
| P1-TRF-02 | Damage, discrepancy, return/loss and cancellation | Outstanding quantity remains visible until authorized resolution; linked immutable evidence; no invented overage |
| P1-ADJ-01 | Adjustments, waste and stock takes | Administrator posts reasoned changes; short warehouse freeze proposed for counts; count variance posts once |
| P1-MFG-01 | Actual raw/packaging consumption and finished output | One completed run proposed; all actual lot issues and output commit together; input cost carried into output, no WIP accounting |
| P1-POS-01 | Online search/scan, UOM/quantity/weight entry, discount, receipt/reprint | Server totals and issues stock once; print failure cannot create duplicate sale; exact manual weight initially |
| P1-PAY-01 | Cash and manually confirmed other payments | Applied/tender/change amounts reconcile; partial/split payments supported; no payment-provider integration or claim of bank reconciliation |
| P1-RET-01 | Linked sales returns and recorded refunds | Concurrent return/refund caps enforced; original sale/lot and prices retained; held/damaged return cannot silently become sellable |
| P1-REP-01 | Dashboard and bounded operational reports | Stock by outlet/warehouse/lot, transit, expiry, incoming, manufacture, sales/payments/returns; authorized totals reconcile to facts |
| P1-AUD-01 | Audit/security history | Who/when/where/reason and source relationships retained; no credentials or card data |
| P1-OPS-01 | Secure deployment, backup and restore | Isolated restore rehearsal verifies stock, transfers, documents, payments, branding and access; recovery time measured |

## Proposed operational limits requiring confirmation
Single currency per company; prices have no tax breakdown/calculation. No multi-currency, complex promotions, purchase orders/AP matching, supplier settlement, AR ledger, credit-limit engine, customer-credit transfer, register/shift cash management or external card capture.
Partial payments produce an operational outstanding balance per original sale; they are not an accounting subledger. Refunds require recorded receipts and authorized linked returns. Initial returns require original sale and identifiable original issue allocation.
Barcode keyboard scanners and browser print are proposed; manually entered exact weights avoid device integration. Direct scale/printer integration requires separately approved equipment scope.

## Non-functional essentials
Exact decimals/limits/rounding, transactions/idempotency, scoped authorization/cache/files, HTTPS/CSRF/rate limits, accessible recoverable screens, least-privilege secrets, reproducible builds, concurrent real MySQL tests, audit and restore.
No service levels, throughput, legal invoice suitability, tax treatment or backup guarantees are assumed. Configure actual business currency/timezone/rounding and agree receipt requirements before checkout release. Tests accompany every slice; P1-10 is final verification, not the first testing stage.
