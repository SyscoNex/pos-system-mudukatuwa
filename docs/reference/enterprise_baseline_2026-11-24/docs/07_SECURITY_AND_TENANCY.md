# Security, access and tenant isolation
## Identity and permissions
Use vetted identity/session implementation (provider vs ASP.NET Core identity to be decided); secure password hash, reset, revocation, MFA for platform/tenant admins and sensitive actions. Resolve global user → active tenant membership → granted company → granted branch/warehouse → permission → resource ownership. Cache authorization with policy version and invalidate changes. Disabled tenant/user/device denied; no permission inferred from menu visibility. Platform support access separately authorized, time-bound, reasoned and audited; never a hidden tenant-admin bypass. Do not allow tenant owner to create platform roles.

| Role (starter templates, customizable) | Scope / actions |
|---|---|
| SysConex platform admin | tenant onboarding, entitlements, infrastructure; no ordinary access to business records |
| Tenant owner | company/branch config, users, approved company-wide reporting |
| Company manager | authorized outlets, approvals, reports |
| Branch manager | assigned outlet, transfers, counts, discount/return approvals |
| Cashier | assigned register/session, checkout and permitted returns; not cost/payroll by default |
| Storekeeper | authorized warehouse receiving/dispatch/count prep |
| Production supervisor/operator | assigned factory, order release/actual operations as granted |
| Quality officer | inspection/release/recall disposition |
| Accountant | journal and settlement/close permissions, financial reports |
| Auditor | scoped read-only records/exports |
| Device/service principal | narrow permitted command scope, revocable, no global interactive admin |

Permissions granular (e.g. `inventory.read`, `inventory.adjust.approve`, `transfer.request`, `transfer.approve`, `transfer.dispatch`, `transfer.receive`, `transfer.resolve`, `sale.post`, `quality.release`, `finance.period.close`). Role and permission codes are proposals until seed reviewed. Enforce segregation where configured: creator vs approver, cash variance, stock loss, sensitive grants. Separate company and branch grants; counterpart transfer data disclosed minimally.

## Threat controls
- IDOR/tenant leakage: scoped composite filters and joins, independent server checks; isolation tests for route IDs, reports, cache, file downloads, jobs and exports. Workers carry explicit trusted tenant/company scope, not ambient request leftovers.
- Injection: parameterized SQL, allowlisted sorts/filters, validate types and bounds; encode UI output; CSV formula injection defense. No dynamic untrusted SQL identifiers.
- Session/web: TLS, secure HttpOnly cookies/CSRF if using cookies, strict origin CORS, CSP, login and sensitive endpoint rate limits; token expiration/rotation/revocation; don't put long-lived credentials in browser storage.
- Secrets: env/secret manager, separate restricted app/migrator/backup roles, no public MySQL, SSH keys, no passwords in code/commits. Log redacted metadata, not access tokens, customer/payroll details or card info.
- Files: private storage, scoped metadata, type/size validation, malware scan where applicable, signed short-lived download only after authorization.
- Integrity: append-only posted facts, controlled reversal, immutable audit event; capture actor, scope, timestamp, reason, action/entity, safe before/after or event diff, correlation ID. Audit access also scoped; no raw secrets.
- Payment: verify signed callbacks, provider idempotency, reconcile; no full card data/CVV. Offline: encrypted managed device storage, quota, revocation and supervised lost-device review.
- Dependency scanning, patch process, secrets scanning and security review before release. Establish privacy retention, export/deletion rules, legal accounting retention and breach procedure with local advice. No customer production data in developer/test environments.

## Next.js boundary
Next.js is not an authorization authority. Keep .NET scope checks on every API request, including server-side reads. Do not trust navigation guards, middleware/proxy or hidden UI. Prevent shared caching of authenticated HTML, RSC payloads and API responses; explicit no-store/dynamic settings and reverse-proxy cache policies must be verified. Do not serialize secrets or excessive business data into client props. Keep server-only modules out of client bundles. Apply authorization, input validation and CSRF protections to any Server Action or Route Handler. Test session revocation, prefetch and cross-tenant context transitions.
