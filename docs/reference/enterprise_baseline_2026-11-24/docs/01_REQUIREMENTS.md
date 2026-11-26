# Requirements and acceptance baseline
Priority: **Core** = necessary foundation or first-client scope; **Pilot** = required capability to plan and validate before agreed go-live; **Later** = advanced capability, not promised for launch. Offline billing is pilot scope but must follow its own readiness gate. Final client contract and sequencing remain to be approved.

| ID | Capability | Priority | Acceptance outcome |
|---|---|---|---|
| TEN-01 | Tenant signup/admin, company and branch setup, branding | Core | Two separate tenants can configure identical SKU codes without access to each other. |
| TEN-02 | Users, roles, company/outlet grants, register assignment, audit | Core | Cashier restricted to assigned outlet; company owner has permitted consolidated view. |
| CAT-01 | Product, variants, categories, base/alternate UOM, barcodes, prices, taxes | Core | 500 ml and 1 L packs are separate SKUs; carton converts exactly to base quantity; historical sales retain snapshots. |
| CAT-02 | Supplier/customer profiles, addresses, credit policies | Core | Supplier and customer roles can coexist; outstanding balances reconcile. |
| INV-01 | Warehouse/bin stock per outlet, lot, owner, condition | Core | Every posted transaction affects the correct outlet; company view separates on-hand, available, held and transit. |
| INV-02 | Request, approval, dispatch, partial receipt and exception resolution between outlets/factory | Core | Source decreases at dispatch, destination only at receipt, transit reconciles; audit identifies responsible users. |
| INV-03 | Count sheets, opening balances, adjustments, wastage and write-off | Core | Count difference posted only by authorized variance document; no direct stock editing. |
| INV-04 | Low stock, reorder levels, expiry alerts, stock ledger and valuation | Core | Per-outlet thresholds and batch expiry report use correct availability and date cutoff. |
| PUR-01 | PO, partial delivery, goods receipt, supplier invoice matching, return/credit | Core | Receipt changes quantity once; invoice/payment affects liability without a duplicate receipt. |
| PUR-02 | Purchase requisitions, supplier quote comparison, landed costs | Pilot/Later | Approved allocations reconcile cost; advanced planning deferred by flag. |
| MFG-01 | Versioned recipes, manufacturing orders, actual input/output, packaging, WIP | Pilot | Actual ingredient/packaging consumption and output lot reconcile; recipe edits do not change released order. |
| MFG-02 | Yield, byproducts, waste, cost settlement, rework | Pilot | Output and loss values exhaust WIP according to approved costing policy. |
| QC-01 | Incoming/output QC, quarantine/release, expiry and recall genealogy | Pilot | Recalled/expired/held goods cannot be sold; trace input lot to output and deliveries. |
| POS-01 | Barcode/search, quantities/weight, price/tax, discount, cash/card/manual tender, receipt | Core | Server prices and posts correct branch inventory; retry produces same receipt once. |
| POS-02 | Sessions, opening float, cash movement, shift close, cash variance | Core | Expected cash derived from committed movements; actual counted and approved difference retained. |
| SAL-01 | Quotations/orders, partial delivery, invoice, credit sales and payments | Pilot | Delivery and invoice cannot issue stock twice; allocation matches open items. |
| SAL-02 | Returns, refunds, exchange via linked documents, reprint | Core | Concurrent returns cannot exceed original eligible quantity/refund. |
| FIN-01 | Double-entry journals, tax snapshots, AR/AP, payments, settlements, expenses | Core | Trial balance reconciles stock and customer/supplier subledgers; no unbalanced posting. |
| FIN-02 | Period close, financial reports, cash and bank reconciliation | Pilot | Closed period locked; reports reconcile; late entries handled with approved policy. |
| OFF-01 | Offline device registration, encrypted local journal, stock quotas, sync conflict queue | Pilot | Disconnection/restart/retry cannot double-post; stock not oversold by online devices. |
| REP-01 | Outlet and company dashboards; stock, transfer, sales, purchasing, margins, aging, yield | Core/Pilot | Reports respect grants, show dates/currency and reconcile to ledgers. |
| REP-02 | Export to CSV/Excel-compatible data and printable PDF, audit history | Pilot | Scoped export job, expiry and authorized download; no spreadsheet formula injection. |
| ADV-01 | Replenishment/MRP, capacity, advanced production planning, subcontracting | Later | Plans do not silently change actual stock. |
| ADV-02 | Loyalty, customer service, promotions, budgets, asset/equipment maintenance | Later | Feature-gated modules with independent tests. |
| ADV-03 | Staff, time/leave, payroll localization | Later | Sensitive data scoped and localized rules approved. |
| SAAS-01 | Subscription and module entitlements, onboarding, support operations | Core/Later | No cross-tenant data access; payment automation and plan enforcement finalized later. |

## Non-functional requirements
- Security by default; isolation across CRUD, raw SQL, exports, background processing, files and cache. MFA for admins, HTTPS, least privilege.
- Correctness before throughput: decimal arithmetic, atomic posting, idempotency and concurrency handling. No duplicate payment/stock effect.
- Clear UX at checkout with keyboard/scanner support, responsive back-office screens, local business timezone; localization/extensibility. Accessibility and error recovery.
- Backup and restore rehearsal; provisional RPO <= 15 min, RTO <= 4 h subject to agreed infrastructure. No unverified uptime/latency commitments.
- Observability: scoped trace IDs, metrics, durable business exceptions and reconciliation reports.
- Product configuration instead of tenant-specific source forks. Tenant flags and permissions enforced server-side. No mock functionality exposed as completed.

See [previous client feature scope](reference/CLIENT_SCOPE_2026-11-23.md) for full business descriptions. This is a proposed delivery baseline, not a signed client scope.
