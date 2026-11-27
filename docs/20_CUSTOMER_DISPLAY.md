# Customer Facing Display — mandatory Phase 1 / P1-08

Owner requirement accepted 28 November 2026. This is an active Phase 1 requirement. Operational implementation and tests belong to P1-08, alongside billing. P1-02 introduces no POS/display route, synchronization code, pairing table or real-time service.

## Operator and customer experience

Cashier route `/pos`: product search and barcode scanning, add/remove lines, permitted quantity/price changes, discounts, payment processing/recording and **Open Customer Display**. Customer route `/pos/customer-display`: read-only, fullscreen-capable presentation on the second monitor, with business name/logo/welcome message; product names, quantities, unit prices, line totals, discounts, subtotal and grand total; amount paid/cash change; confirmed completion/thank-you message and automatic reset for the next transaction. Opening/fullscreen may require a user gesture; the cashier moves the window to the second extended desktop. Do not promise browser placement/fullscreen without permission.

Disconnected, stale cart, reconnecting, empty/welcome, provisional cart, server-confirmed totals, processing, failed/uncertain payment and confirmed completion must be visibly distinct and accessible. A failed/unknown response never becomes payment success. Display content clears on cancellation, transaction reset, logout, invalid session or outlet/context change. Completion remains briefly visible for an agreed configurable duration, then clears; exact timing is a P1-08 UX decision.

## Initial topology

Two monitors on the same computer, same origin and browser profile/storage partition. Prefer browser BroadcastChannel; no SignalR, broker, sockets service or persistent synchronization tables initially. BroadcastChannel cannot synchronize independent devices, browser profiles or origins; browser partitioning/private modes may impose further limits. Closing/suspending the cashier tab stops updates. Feature detection supplies a clear unsupported message, never a silent stale display. See [MDN BroadcastChannel](https://developer.mozilla.org/en-US/docs/Web/API/BroadcastChannel).

Each cashier checkout instance generates at least 256 random bits using Web Crypto for its channel identity. Use a new identity when the cashier session/context is replaced. Never reuse a global tenant/outlet channel. Share the capability with the opened window using a non-logged fragment or an explicitly origin-checked opener handshake; do not put it in API paths, query logs, analytics or persistent storage. Clear the fragment after capture. No secrets go to cross-origin windows; use noopener unless an explicitly reviewed opener handshake requires otherwise. A capability is routing isolation, not backend authorization. Same-origin script compromise remains a security boundary; do not claim BroadcastChannel provides encryption or protection from malicious scripts running in the same origin.

## Versioned, allowlisted message contract (specification, not implemented)

Envelope: protocol version, checkout-instance identity, transaction identity, monotonic revision, message type, sender-instance identity and freshness evidence. Types: HELLO/SNAPSHOT_REQUEST, SNAPSHOT, HEARTBEAT/ACK, CLEAR, COMPLETION. Validate message shape, string/array limits and numeric string formats. Treat all payloads as untrusted; render text, never HTML. Do not copy the backend entity or entire cashier state.

Allowlisted display DTO: sanitized public business branding/welcome; line description, quantity/unit label, unit price, discount and line total; subtotal, total discount, grand total, currency/minor units; provisional/confirmed state; authoritative sale confirmation reference when needed, paid amount/change and public thank-you text. Exact decimals travel as strings. No credentials, cookies, CSRF/auth tokens, internal costs/margins, stock balances, customer PII, staff names/permissions or privileged identifiers/commands. Use a public branding projection; never forward private profile contacts or arbitrary storage paths.

The .NET backend owns prices, permissions, discounts, exact totals and completed payments. Provisional input may be shown with explicit provisional wording. Server-confirmed quote/revision and committed sale/payment result replace it only after the backend validates/commits. Display never creates sales, alters inventory, records payment or invokes privileged endpoints. A display-originated request is only a resynchronization request to its paired cashier. Opening the display does not grant business API privileges.

## Ordering, recovery and isolation

The cashier publishes complete bounded snapshots after edits; it remains the source for provisional UI state while .NET remains the business authority. Use transaction identity plus monotonically increasing revision; reject duplicates/out-of-order snapshots. A new transaction needs an explicit clear/reset or approved replacement snapshot, preventing an old payment result appearing on the next cart. Keep a completed/cancelled transaction tombstone for the channel lifetime so late messages cannot resurrect it. Reopening/refresh creates a new display receiver instance, requests a fresh complete snapshot and stays empty until verified. Receiver/sender instance checks and ACKs prevent delayed replies from replacing current state.

Use a bounded heartbeat and resynchronization timeout, specified/tested during P1-08 (proposed heartbeat 2 seconds, stale after 6 seconds, clear after 15 seconds). Monotonic local elapsed time determines stale status; wall-clock timestamp alone is insufficient. Hidden tabs may be throttled; stale state must fail visibly and clear sensitive content. On reconnect, request a full snapshot, do not replay partial deltas. Detect session invalidation, route unload, logout and context change; send CLEAR when possible, and expire locally when delivery is impossible. No refresh/login/session poll should indefinitely extend an idle authenticated session.

A cashier tab owns exactly one active instance/context/transaction sequence. Test concurrent independent cashier tabs and two tenants/outlets; no shared cart globals or cross-channel listeners. Do not infer trust from a client tenant ID. Any future backend display pairing must bind tenant/outlet/register/session and enforce expiry/revocation independently.

## P1-08 acceptance

Two real windows on extended displays; multiple simultaneous cashier instances and transactions; rapid scans/removals/quantity/price edits and discounts; exact provisional versus confirmed totals; partial/manual payments, backend rejection/failure/uncertain result, no early success; completion/thank-you/reset; duplicate/out-of-order/delayed messages, wrong-channel/wrong-transaction messages, refresh/reopen, stale timeout/reconnect, session expiry/revocation/logout, outlet/tenant switch, cancellation and next sale. Verify DTO allowlist and DOM sanitization, no PII/secrets/costs, no privileged commands from display. Verify keyboard/fullscreen support and clear browser capability limitations.

Independent tablet/network displays are future expansion: propose secure short-lived display pairing and SignalR only when that requirement is approved. Pairing/register tables require a concrete migration review; none are justified solely for initial same-computer synchronization.
