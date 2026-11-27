# Phase 1 product overview
**Owner-approved Phase 1 scope/design: 25 November 2026; P1-01 accepted and P1-02 authorized 28 November. Only the disposable auth-review database execution is approved. Stop before P1-03.**

Conex360 is owned by SysConex. Its first release serves a coconut manufacturer with initially one or two operators. Provide useful daily workflows and accurate stock without delivering the full future enterprise platform.

## Organization
Tenant -> one automatically created default company -> branches/outlets -> warehouses -> locations.
The database retains tenant_id and company_id. A UNIQUE tenant_id on companies initially enforces one company per tenant. The UI presents Business settings and outlets/warehouses, with no legal-company selector or administration.
A STORE branch is an outlet; FACTORY and WAREHOUSE branches are operating sites. Ordinary warehouses belong to branches. A proposed hidden company transit warehouse has no branch and is accessible only through scoped transfer workflows. The ordinary UI can use default storage/held/damaged locations without exposing a bin-management module.

## Immediate capability
Secure login/sessions, Administrator/Staff, business profile/logo, outlets/warehouses, products/categories/SKUs/barcodes/UOM, basic purchase/selling prices, suppliers/customers, opening/incoming stock, batches/dates, reservations/transfers/partial receipts, adjustment/waste/counts, actual-input/output manufacturing, online POS/receipts/manual payments/returns, basic reports/audit/backups.

The initial manufacturing proposal posts one completed run with actual input lots and one finished SKU/output lot, including packaging as input. Bulk production and packaging can be separate completed runs. Confirm this limitation with the client before P1-07; multistage WIP and joint-product costing remain future work.

## Explicit future scope
Full accounting/journals/financial periods, tax/statutory engines, multi-company UI, advanced costing/WIP/QC/approvals, HR/payroll, loyalty, subscriptions, advanced analytics, offline/sync, integrations and distributed architecture are deferred. See [future product](17_FUTURE_PRODUCT.md). Their enterprise baseline remains in [the archive](reference/enterprise_baseline_2026-11-24/README.md).

## Terms
| Term | Phase 1 meaning |
|---|---|
| Item/SKU | Stock identity; 500 ml and 1 L packs are separate items |
| Lot | Actual purchase/production batch, or deterministic SYSTEM lot for untracked stock |
| Bucket | Lot + location + condition; all stock is company-owned initially |
| Storage on-hand | Physical stock in ordinary warehouse locations, including held/damaged stock |
| Available | Eligible released, unexpired, unblocked storage quantity minus active reservations |
| Transit | Dispatched stock outstanding receipt/resolution; separate from source/destination storage |
| Operational value | Exact carried purchase/input cost estimate; not GL, COGS or statutory valuation |
| Posted | Committed immutable business facts; corrections are new linked records |
| Business date | Configured local operational date, distinct from UTC occurrence/posting timestamps |

Success is reliable outlet stock, safe transfers, simple manufacture/checkout, operational transaction evidence, secure tenant isolation and demonstrated recovery. A receipt or cost report is not a claim of statutory or audited accounting compliance.
