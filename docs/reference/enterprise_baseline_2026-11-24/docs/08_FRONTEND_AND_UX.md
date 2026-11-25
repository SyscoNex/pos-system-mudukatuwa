# Frontend and UX direction
Next.js with TypeScript is confirmed; App Router is the proposed default. React is the UI library within Next.js, not a separate Vite application. Responsive web dashboard plus dedicated fast POS layout; offline till packaging is a separate validated decision. Build reusable accessible components, keyboard navigation, visible focus, clear labels and status text. Do not make users infer stock availability from color alone. Preserve SysConex/Conex360 identity and tenant-specific name/logo, receipt address and branch info. Tagline proposed; visual identity not finalized.

## Navigation and screens
| Module | Screens |
|---|---|
| Onboarding | company, outlets, warehouses, users, roles, features, opening balances |
| Dashboard | authorized company/outlet selector, sales, cash, stock alerts, expiry, pending transfers |
| POS | scan/search, quantity/weight, cart, discount approval, customer, split tender, payment status, receipt/reprint |
| Products | SKUs, units, barcode, category, pricing and tax configuration |
| Inventory | stock by outlet/bin/lot, available/reserved/held/transit, movements, count, adjustment, reorder |
| Transfers | request list, source/dest picker, approval, dispatch pick list, receive outstanding lots, discrepancy resolution, history/print |
| Procurement | supplier, order, receipt, invoice match, return, credit |
| Manufacturing | recipe, plan, issue, output, packaging, cost and yield |
| Quality | QC queues, release/hold, expiry, genealogy/recall |
| Sales | order, delivery, invoice, credit/return, customer balance |
| Finance | payments, expenses, journals, AR/AP, cash sessions, close, reports |
| Administration | identity, permissions, branding, devices, audit, config |

## UI contracts
- A visible current business/company/outlet context; clear cart/draft scope on switch with confirmation. Server still enforces context. No cached data between unauthorized contexts; cancel in-flight queries on switching and key cache by scope.
- Stock table columns: item, unit, outlet, on-hand, available, reserved, held, transit (separate ownership/pool where relevant), expiry and last updated. Totals must not double count transit or reservations. Drill into batches and history.
- Transfer status shows requested, approved, dispatched, received, damaged/exception-resolved, outstanding, business dates and responsible actor; partial receive quantity cannot exceed remaining allocation. Server authoritative; show actionable 409 conflict and refresh. Do not mark complete from UI alone.
- Cashier keyboard/scanner friendly; no unbounded auto-fetch, explicit loading/error/empty state, safe retry; disable duplicate clicks but rely on API idempotency. Money and quantities formatted for display from exact decimal strings using approved library; server totals authoritative. Handle rounding, currency, weight and receipt reprints.
- Hardware adapters behind interfaces; browser print first only if pilot accepts it. Receipt printer, barcode scanner and weighing scale models/protocol, offline host OS, paper format and network requirements must be tested. No direct assumption that a browser can access all devices.
- Offline: prominent connected/disconnected/queued/conflict state, remaining authorized stock and policy validity, durable receipt evidence. Do not imply a locally queued payment is server-confirmed. Supervisor conflict workflow.
- Use local dates/locale and translation keys (English initial proposed, Sinhala/Tamil later if required). Do not embed strings throughout business logic. UI validation helpful but never substitutes backend rules.

## Proposed application structure
```text
frontend/
  src/
    app/
      layout.tsx
      (auth)/login/page.tsx
      (business)/layout.tsx
      (business)/dashboard/page.tsx
      (business)/pos/page.tsx
      (business)/inventory/page.tsx
      (business)/transfers/page.tsx
    features/                 # module UI, hooks, forms
    components/               # shared accessible UI
    lib/api/                  # typed API client and server-only transport
    lib/auth/                 # session integration, no authorization bypass
  public/
  tests/
  next.config.ts
  package.json
  tsconfig.json
```
Use feature-local components and route-level loading/error states. Use Server Components for suitable layouts and authorized reads; Client Components for POS cart, scanner events, forms and interactive tables. Use browser-only APIs inside client components. Never use Server Actions or Next.js route handlers as substitutes for the .NET business API. Keep `/api/` reserved for .NET under the proposed same-origin reverse proxy. Use generated or validated OpenAPI types and exact decimal strings. State/form/UI libraries and styling approach remain open; choose after reviewing accessibility, bundle size and maintenance.

## Rendering, sessions and caching
- Authenticated pages and sensitive fetches must be explicitly dynamic and non-cacheable using supported APIs for the pinned Next.js version. Never statically generate or share tenant-specific data. Do not cache authenticated responses at Nginx/CDN; use private/no-store response policies. Public static assets may use normal caching.
- Use a reviewed session design with server-side authorization in .NET. Forward only required credentials on server-side API reads; do not leak server-only secrets to Client Components or NEXT_PUBLIC_ variables. Treat Next.js route handlers and Server Actions as independent security boundaries if used. Use CSRF controls for cookie-authenticated mutations.
- Invalidate browser query/router state, drafts and in-flight requests on scope switch, logout or permission revocation; use tenant/company/outlet/user-aware cache keys. Test RSC payloads, prefetching, navigation and direct URL access for cross-user data leakage.
- Prioritize fast POS interaction and scanner support over SSR of the checkout cart. Next.js service-worker/PWA options may improve shell availability, but no offline posting until durable SQLite/quota/sync design is approved and tested.
