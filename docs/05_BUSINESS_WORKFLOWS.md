# Phase 1 operational workflows

P1-07 provides one completed run with actual materials and one intermediate or finished output. Use the same warehouse for consumption and output. A subsequent packaging run consumes the actual intermediate lot. Preview before confirming and use posted history to trace tracked lots. [Manufacturing handoff](29_MANUFACTURING_IMPLEMENTATION.md)

P1-06 adds destination transfer requests, source confirmation/reservation and dispatch, destination settlement, Administrator discrepancy resolution, adjustment, waste and stock take finalization. Stock takes block warehouse stock changes until completion or cancellation. [Current handoff](27_STOCK_OPERATIONS_IMPLEMENTATION.md)

P1-05 prepares Administrator opening stock and granted-outlet goods receiving. Choose an ordinary warehouse, enter actual quantity and cost by unit, and select disposition and lot dates. Review the server preview, then confirm with the same operation ID. Committed details support browser printing. See [posting policies](26_P1_05_DATABASE_REVIEW.md).

P1-08 checkout includes the mandatory Customer Facing Display: open a separate same-computer window, publish sanitized provisional cart snapshots, replace totals/payment only after backend confirmation, show thank-you and reset. Cancellation/logout/outlet/context changes clear the display; stale/reconnected windows request a current snapshot with transaction/revision checks. No display command mutates business data. [Full specification and acceptance](20_CUSTOMER_DISPLAY.md). No checkout/display operational code belongs to P1-02.
All posting uses the common transaction in docs/04_INVENTORY_AND_TRANSFERS.md. No workflow calls journals, accounting periods, tax engines or external payment providers.

## Setup and users
A controlled onboarding operation creates tenant, its one default company, first Administrator, business settings and audit atomically. No public subscription signup. Administrator creates Staff, assigns outlets and can also operate the system. Simple password reset/first-login flow is proposed in security docs.
Create ordinary outlets/warehouses with default locations; bootstrap hidden transit storage. Profile/currency/timezone and receipt information are validated before operational use.

## Products and incoming stock
Create category, item, base unit plus alternate item_units/barcodes and basic purchase/selling price. Bulk liters and bottled packs are separate SKUs; packaging consumes bulk plus bottles/caps/labels rather than pretending it is a UOM conversion.
Admin posts opening stock. Incoming receipt records supplier, actual items/UOMs, warehouse, lots/dates, entered unit costs and supplier reference; Inventory increases quantity/value once. There is no purchase order, supplier invoice matching, AP, supplier payment or landed-cost allocation in Phase 1. Defaults help entry but actual receipt prices are frozen.
The simple blocked/held/damaged states prevent unsafe normal sale/use. Admin disposition is audited; no lab criteria, inspection queue or recall case module.

## Manufacturing
Select actual raw/ingredient/bulk/packaging inputs, quantities and eligible lots in one factory warehouse; declare positive finished output quantity and new lot/manufacture/expiry data. Propose one finished SKU/output lot per completed run.
The server locks and consumes actual inputs, creates output at summed carried input value, retains input/output lines and entries under one production_events document, and commits atomically. No partial intermediate commits, long-running reservation, WIP, labor/overhead allocation, joint products or recipe explosion.
Input/output linkage through the run supports basic backward/forward lot tracing; do not claim advanced recall/QC functionality. A separate packaging run consumes bulk and packaging. Zero-output failure is a reasoned waste/adjustment workflow, not a manufacture with invented output.
Do not blindly reverse production after output has transferred/sold/been consumed; inspect dependencies and use approved linked corrections.

## POS and receipt
Select authorized selling warehouse. Search/scan items; enter exact quantity/UOM or manual accepted weight; server resolves price/version and permitted discount, validates stock, and returns exact totals. No tax engine or tax breakdown.
Posting an immediate sale freezes business/customer/item/unit/price/discount/currency snapshots and issues stock once. Cash/split manually confirmed payment records may commit in the same transaction. Requote changed prices before accepting payment.
Print/render receipt only after commit; printer failure leaves a completed sale and reprint uses its original number/snapshots. Network failure blocks new checkout; an uncertain result is queried/retried using the same idempotency identity. No queued/offline sales.
No register hardware identity, shift float/closing, promotions, wholesale delivery/invoice split or payment capture integration initially.

## Manual payments and outstanding sales
payments records money the operator confirms received/refunded; it is not a journal or provider confirmation. Cash stores tendered/change/applied; noncash has no change. Record multiple/partial payments with exact amount, method, safe reference, actor and immutable operation UUID.
Every payment links the original sale; refunds also link authorized return evidence. No PAN/CVV. A manual-card label records operator evidence only, not bank verification.
Operational sale outstanding = original sale total - posted return totals - net recorded payments (incoming minus outgoing, including explicit payment corrections). Positive is unpaid, negative is credit awaiting permitted resolution; do not silently discard credit or auto-transfer it to another sale. Unpaid sales require an identified customer and approved business policy; no credit-limit/AR engine.
Lock original sale/payment/return sources before amount caps. Corrections append opposite-direction linked records; never edit a paid flag or erase a payment. Supplier balances and cross-sale credit settlement are future scope.

## Sales return/refund
Require original sale and identifiable original issue lot allocation initially. Lock source sale/lines/issues and cumulative prior returns. Use original conversion, net unit amount/discount and issue cost, with deterministic final residual; cap physical returns and return credit separately.
Receive into HOLD/DAMAGED by default; Admin may explicitly accept sellable condition. Return still needs expiry/blocked checks for resale. Linked return record reduces operational sale amount. Refund is a separate recorded outgoing payment, capped by available return credit and net money received. Posting return plus confirmed cash refund may be atomic.
Price-only credits, no-receipt/unknown-lot returns, cross-sale customer credit and exchanges are future scope unless separately designed. A replacement can be a linked return and new normal sale, without automatic netting.

## Reports and corrections
Read stock movements, current warehouse/lot quantity/value/availability, outstanding transit, expiry, incoming quantities/costs, manufacturing actuals, sales/net returns and payment/outstanding totals. Show business date and UTC posting cutoff where relevant; old receipt snapshots survive master-data edits.
Report disagreements become investigation tasks with preserved facts. No backdated stock reordering, silent balance repair or finance report claims. Use current scoped queries and bounded CSV/print output; no analytics platform or async export infrastructure.
