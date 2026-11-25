# Phase 1 security and tenant isolation
The smaller feature set does not reduce isolation or stock integrity. Shared MySQL does not provide automatic per-tenant SELECT filtering.

## Approved authentication direction — not implemented in foundation
Use ASP.NET Core cookie authentication, its vetted password hasher and Data Protection; no custom password cryptography, browser JWT storage or separate Next.js auth authority. auth_sessions is a server-revocable identity store; cookie contains a protected opaque session identity, not business permissions as permanent truth.
Persist/protect Data Protection keys and revoke sessions on password reset/disable. Validate absolute/idle expiry and active user/membership on API calls; recheck authorization for posting and sensitive changes. Cookie Secure, HttpOnly, appropriate SameSite/path, CSRF token plus Origin validation for cookie mutations; login CSRF and return-URL allowlisting included.
Login rate limits, lockout/backoff, generic failures, strong configurable password policy and secure initial-password change. Proposed first release uses controlled Admin onboarding and in-person secure Staff password handoff, not email integrations. Administrator resets only a user exclusive to their tenant; a shared global identity needs verified user/support recovery, never a tenant Admin reset affecting another business. Protect the last active Administrator.

Tenant Admin disable/role/grant operations affect only that tenant_membership, never the global user's other memberships. Linking an existing global login requires verified user consent or controlled support provisioning; do not expose another tenant's identity details through duplicate-email errors or auto-link an account solely from a supplied email. Global user disable/recovery is a separate controlled security action.
Exact session durations, password policy, recovery procedure and Admin MFA launch policy are decisions before live use, not reasons to add an external identity platform to the scaffold. No public self-service signup.

## Two roles and scope
| Action | Administrator | Staff |
|---|---|---|
| Business/users/grants/outlet/catalog/default prices | Own tenant/default company | Read necessary operational data only |
| Incoming stock, request/confirm/dispatch/receive, manufacture | All own ordinary outlets | Granted branches and action-specific source/destination scope |
| POS/manual incoming payments | Own outlets | Granted selling warehouse/outlet |
| Count preparation | Yes | Granted warehouse |
| Opening, adjustment, waste, count completion, transfer loss/return, sales return/refund, price override | Yes, with reason | No initially |
| Reports/audit | Own company; sensitive costs/audit | Operational records for granted outlets; no unrestricted cost/audit report |
| Transit editing/platform administration | No ordinary endpoint or implicit platform role | No |

Permissions are static backend policies over two membership roles; no role/permission management tables or approval hierarchy. Admin may prepare and post; a second approver is not mandatory.
Branch grants restrict Staff to ordinary warehouses of that branch; no separate warehouse-grant UI initially. Confirm whether finer warehouse restrictions are needed. A user with no branch grants has no Staff operational access.
Resolve user -> active membership -> default company -> resource branch/warehouse -> action policy. Include tenant/company on every SQL predicate, join and update, and enforce scoped composite FKs. Never trust route/body tenant/company IDs.
For transfers, source grant governs confirmation/dispatch and destination grant governs receipt. Permit minimal counterpart identity/manifest to participants without exposing unrelated stock/costs. Transit access derives from the allocation and participant grants, never a NULL branch meaning unrestricted access.

## Audit and data protection
Business mutations, grants, stock/cost changes, returns/refunds and corrections append audit_events in the same transaction. Keep scoped actor/time/reason/source/correlation metadata; avoid raw passwords, tokens and complete PII payloads. security_events captures global authentication/session actions separately without invented tenant/company rows.
Platform support has no hidden business-data bypass. Exceptional support access needs explicit authorization, reason, time limit and audit when introduced. Do not build a support console prematurely.
Parameterized SQL; allowlisted sorts/report keys; typed bounds; output encoding; safe CSV cells. No PAN/CVV or payment-provider credentials. Manual payment reference is evidence, not provider authorization.
Logo upload: size/type limits, re-encode/validate safe raster format, random server object key and scoped profile lookup. Do not allow arbitrary SVG/HTML/script uploads, filesystem paths or remote-URL fetches. Private files and backups use scoped authorization/access controls; bound synchronous CSV/receipt responses.

## Next.js and runtime
.NET authorizes every browser and server-side request. Use private/no-store for authenticated HTML/RSC/API output and supported dynamic rendering controls; do not enable shared cache components for private data. Test prefetch, browser history, outlet switch, logout and revoked grants. Clear scoped client state and cancel in-flight requests on context changes.
Server-only config stays outside client bundles/NEXT_PUBLIC_. Do not forward cookies to user-supplied URLs. Same-origin proxy keeps CORS narrow; explicitly configure trusted proxy headers, HTTPS/security headers/CSP and request limits.
Use separate runtime/migration/backup DB credentials; MySQL private, non-root containers, secret injection, dependency/secrets checks, restricted GitHub environments. No production customer data in local/CI fixtures. Privacy, audit retention, backup retention and incident procedures require a practical launch decision.
