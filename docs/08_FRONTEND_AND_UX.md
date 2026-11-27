# Phase 1 frontend and UX

## Mandatory P1-08 dual-screen checkout
Cashier /pos supports Open Customer Display; /pos/customer-display is fullscreen-capable read-only content on a second extended monitor. Branding/welcome, cart lines/discounts/totals, paid/change and authoritative completion/thank-you/reset, with visible provisional/stale/disconnected/reconnect states. No operational code in P1-02. [Complete UX/protocol](20_CUSTOMER_DISPLAY.md).

Next.js/TypeScript App Router and Node runtime are retained. The P1-01 foundation overview remains; P1-02 adds branded login, password/forced change, protected workspace/account menu, verified business selection and Administrator business settings/logo. Outlet and operational modules remain later milestones. No fabricated dashboard statistics. See docs/19 for actual validation.

## Screens added by slice
Login/password change; Business profile/logo; Administrator user list and Staff outlet grants; outlets/warehouses; product/category/unit/barcode/prices; suppliers/customers; opening/incoming stock; warehouse/lot stock/history/expiry; transfer request/reserve/dispatch/partial receipt/discrepancy; adjustment/waste/count; completed manufacturing run; online POS/payment/receipt/return; dashboard/basic reports/audit.
Do not render legal-company management, Finance/tax/payroll/QC/offline/subscription menus or empty placeholders. One default company is invisible as an administrative concept.
Default storage/held/damaged locations keep normal entry simple; only expose lot/bin detail when relevant. Transit is read-only through transfer manifests.

## Operational behavior
Show quantity unit and exact decimal formatting, on-hand/available/reserved/held/damaged/transit separately, and partial-transfer remainder. Explain conflicts and provide safe refresh/retry with original command identity. Disable duplicate buttons for UX, while backend provides actual idempotency.
POS supports keyboard/barcode scanner, price/discount/quantity entry, customer, cash/tender/change and manually recorded noncash. Server totals are authoritative. Show partial/unpaid status accurately. Receipt reprint retains original snapshots; receipt print failure never resubmits checkout.
Propose browser print and keyboard-wedge scanners; manual exact weight with unit/gross/tare/net notes if needed. No direct scale/printer/cash-drawer integration is promised. Confirm actual paper/browser/hardware before checkout acceptance.
Offline UI states that checkout is unavailable; an uncertain server result is resolved by querying the original operation. Do not queue a new sale in localStorage/IndexedDB/service worker.

## Structure and accessibility
Use src/app routes, feature-local forms, small shared accessible components and a typed API client. Server Components suit the public shell; interactive operator features are Client Components. Fetch protected feature data from .NET where this avoids extra session forwarding.
Visible focus/labels, keyboard navigation, error/empty/loading states, status text beyond color, bounded lists and locale-aware dates. Strings should be easy to localize; initial language and Sinhala/Tamil needs need client confirmation.
Clear carts/drafts with confirmation on outlet change; scope cache keys and cancel stale reads. Private API/HTML/RSC are non-cacheable; public assets may be cached. Keep minimal state/UI dependencies and choose styling after review, not an enterprise design-system project.
