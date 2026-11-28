# P1-03 Outlets, Warehouses and User/Outlet Management

28 November 2026. P1-02 accepted; P1-03a/b authorized. Owner separately approved SQL 0003–0005, scoped runtime grants, review upgrade and private clean-install/synthetic tests. Stop for review before P1-04. SchoolGrid project `database` is excluded.

## Implemented

- Administrator outlet create/edit/search/status management using branches; no separate outlets table or mandatory business classification. Outlet creation atomically creates its default ordinary warehouse and STORAGE/HOLD/DAMAGED locations plus audit.
- Ordinary warehouses have immutable owning outlet/type; editable code/name/description/status. Generated uniqueness allows one default per outlet. Default removal/deactivation requires an active same-outlet replacement. Internal transit is hidden from ordinary lists, selectors and location access.
- Explicit outlet deactivation disables its ordinary warehouses and grants with audit, clears selected outlets and advances affected session context revisions. Reactivation restores the designated default warehouse only; other warehouses and Staff grants need explicit restoration. Locations are immutable system-managed nodes; their operational availability derives from active warehouse/outlet rather than separate bin administration.
- Exactly one canonical branchless transit warehouse per initialized company, one TRANSIT location, company-lock/idempotent initializer and database uniqueness. Existing companies backfilled; future enabled onboarding initializes transit in its existing atomic transaction. No stock or transfer operations.
- Staff creation atomically creates a new global identity, tenant membership and validated outlet grants. A cryptographically random temporary password is returned once to an Administrator-only, no-store response and ephemeral handoff dialog; first login requires password change. It is never stored in logs, audit or browser persistence.
- Current-tenant membership listing/search/status/role/grant management; only static Administrator/Staff. Existing global identity is never linked by email alone. Controlled SysConex linkage requires public user identity, normalized email, existing-password proof, operator and consent reference. Global recovery/disable remains separate from tenant management.
- Company-serialized membership edits protect the last enabled active Administrator, including concurrent ordinary demotions/deactivations. Membership version and authorization are rechecked in the command transaction. Changes affect selected sessions for that membership, not global credentials or unrelated memberships.
- Working-outlet selector distinguishes current business from operational outlet and Administrator all-outlets management. Staff sees active granted outlets only; no grants means no operational access. A single authorized outlet is selected through a CSRF-protected command. Backend never treats selection as authority.

## Files, schema and boundaries

New SQL: database/migrations/0003_organization.sql, 0004_organization_guards.sql, 0005_transit_backfill.sql. Exact execution review: [22_P1_03_DATABASE_REVIEW.md](22_P1_03_DATABASE_REVIEW.md). Old 0000–0002 files/checksums and historical SQL are unchanged.

Four new application tables: branches, membership_branches, warehouses, locations. Scoped composite FKs protect company/outlet/warehouse/location relationships. Generated unique keys enforce canonical transit and one default per branch. Guards prevent physical deletion and changing ownership/kinds/identity; canonical transit cannot be updated. Additional auth_sessions fields selected_branch_id/selected_branch_tenant_id/selected_branch_company_id bind outlet context to the existing selected membership; no new auth system or permission framework. No additional application table or inventory structures.

New backend files: Application/Organization/OrganizationContracts.cs, Infrastructure/Identity/OrganizationStore.cs, Api/Identity/OrganizationEndpoints.cs and focused integration OrganizationTests.cs. Existing Identity model/store/setup, CLI, readiness and migration-package assertion were extended. No dependency changes or fifth source project.

Frontend adds organization-panel.tsx, /settings/outlets, /settings/warehouses, /settings/users, scoped selector/navigation/styles and one essential organization browser workflow. Existing branding/business/password screens retained. Same-origin API, no-store HTML/RSC/API and decimal/string-ID contracts retained. Client search/status filters suit this pilot; lists are bounded to 1,000 records, with pagination a later measured requirement.

Runtime grants: infrastructure/mysql/grant-organization.sh gives SELECT/INSERT/UPDATE on four new tables, no DELETE/DDL/journal writes. Existing grant-runtime.sh resets original grants: when rerunning it on P1-03, follow it with grant-organization.sh. Workbench retains SELECT/SHOW VIEW through optional localhost 3307; no public MySQL. Compose/script changes retain both review and Workbench files. Clean-install override reuses existing tool image and publishes no database port.

## API and access matrix

All routes below start `/api/v1/organization`. Every request requires active identity/session/membership/tenant/default company, completed password change and current X-Conex360-Context. Mutations require CSRF and origin validation. SQL adapters revalidate scope/role inside the transaction; company locking serializes management invariants. IDs are strings in JSON.

| Route | Methods | Administrator | Staff |
|---|---|---|---|
| /context | GET, POST | Active own outlets or all-outlets management | Active explicitly granted outlet selection |
| /outlets | GET, POST | List all; create | List active granted only; no create |
| /outlets/{id} | PUT | Versioned edit/status | Denied |
| /warehouses | GET, POST | Ordinary own-company list/create | Active granted-outlet ordinary list only |
| /warehouses/{id} | PUT | Versioned edit/default/status | Denied |
| /warehouses/{id}/locations | GET | Own ordinary locations | Active granted ordinary warehouse locations |
| /users | GET, POST | Own tenant; create Staff | Denied |
| /users/{id} | PUT | Versioned membership role/status/grant edit | Denied |

Transit is unavailable through all ordinary resource routes, including guessed IDs and NULL-branch cases. No warehouse-level grants. Future dispatch uses source grant; receipt uses destination grant; transit visibility must derive from transfer participation in P1-06.

Role/grant/outlet status changes increment affected selected-session context revisions and clear outlet scope; stale requests conflict or fail authorization immediately. Other tenants' sessions remain valid. Browser state clears on own context change/logout and cross-tab invalidation; server-originated changes are reflected on the next request/focus/20-second session poll. No real-time infrastructure. Some concurrent commands can roll back on a MySQL deadlock; clients refresh instead of blindly replaying non-idempotent creation.

## Local setup and usage

Existing review database is upgraded; no new setup is needed on this workspace. Start/resume with both Compose files so Workbench access remains:

```powershell
docker compose -p conex360-auth-review -f infrastructure/compose.auth-review.yaml -f infrastructure/compose.workbench.yaml --profile database-approved --profile runtime up -d --no-build api frontend proxy
```

Open http://127.0.0.1:3602/login. As Administrator, use Outlets → Add outlet, Warehouses → Add warehouse, Users & access → Add Staff. Privately hand off the one-time password and close the dialog. Edit membership to promote Administrator, deactivate or change Staff outlet assignments. Staff logs in, changes temporary password, and selects an assigned outlet; no assigned outlet shows a clear empty state.

Organization__Enabled=true enables P1-03 in the dedicated review API/tools after migration. Other configurations default false, preserving standalone no-database foundation and accepted 0002 test mode. When enabled readiness requires journal version 0005. Never migrate automatically at startup.

Controlled CLI additions in the existing API executable (Operations must be explicitly enabled in tools):
- --admin-initialize-transit --input /evidence/transit.json: tenantPublicId, operatorReference, reason; idempotent company initialization.
- --admin-link-membership --input /evidence/link.json: tenantPublicId, userPublicId, email, role, operatorReference, consentReference; current password read through hidden prompt or explicit protected stdin. New Staff linkage has no outlet grants until assigned. No public linkage endpoint or reset.

Before inventory posting, deactivation commands must add locked checks for balances, reservations, pending documents/transfers and count freezes. P1-03 does not assert those checks without stock tables. No products/prices/contacts/stock/manufacture/POS/register/accounting/tax/offline code. Customer display remains mandatory P1-08; docs/20 is preserved unchanged.

## Validation

| Required check | Actual result |
|---|---|
| Backend Release build | Passed, zero warnings/errors; pinned dependencies unchanged |
| Backend unit / HTTP regression | 31 unit and 10 HTTP integration tests passed; nine database facts skipped only in the host run |
| Real MySQL regression | All nine database tests passed in the approved review target, including the combined organization scenario. The final mixed concurrent demotion/deactivation assertion was expanded and its affected test rerun successfully |
| Upgrade / clean installation | Review upgraded from 0002 to 0005; separate private conex360-p103-clean installed 0000–0005 successfully and passed the same focused organization scenario. Clean service stopped afterward; volume retained |
| Frontend checks | Formatting, ESLint, TypeScript, production build and all 10 existing Node tests passed |
| Browser regression | All four existing foundation tests passed against the known running review stack; all six authenticated tests passed, including five existing tests and the one new outlet/warehouse/Staff workflow |
| Responsive smoke / screenshots | 390px mobile overflow check passed; representative desktop/mobile screenshots visually inspected |
| Runtime / Workbench | API readiness 200; Workbench TLS verified at localhost 3307, all 12 tables visible, SELECT/SHOW VIEW only |
| Preservation | 0000–0002 and historical/archive/display-spec files have no diff. Historical SQL SHA256 remains 1810fe5af34702fa8b475aa1cbe3cb16f87b0e00a8b3d9f6361ce2fcc0f3fd32. SchoolGrid container identity/stopped timestamp unchanged; existing foundation stack not modified |

No skipped/unexecuted result counts as real-MySQL proof. The focused test combines CRUD, default/location initialization, duplicate/conflict/rollback, FK and privilege rejection, concurrent transit/last-Administrator protection, assigned/unassigned Staff, immediate revocation, private resource access and verified linkage. It reuses existing fixtures and their independent tenants/shared-user setup; no SQLite or duplicate test framework.

Actual commands: dotnet build/test/format; approved explicit migration runner and grant-organization.sh; clean-target installation; opt-in Docker vstest; npm format/lint/typecheck/test/build; existing Playwright configurations. Logs are ignored artifacts/auth-review/p103-*.log. Original host browser startup found port 5180 occupied, so it was not stopped/reused implicitly: CONEX360_E2E_EXTERNAL_URL=http://127.0.0.1:3602 explicitly targeted the known review stack. The default isolated CI startup is preserved. Browser configurations now keep separate output directories.

Browser verification corrected an initial single-outlet selection race: initialization now finishes before protected forms become available. Read-only context conflicts reload fresh scope; business commands are never silently replayed. The responsive check also corrected hidden table-header content escaping its scroll container. Only affected checks were rerun during fixes; final authenticated regression passed. No tests were weakened or removed.

Screenshots: [desktop Users & outlet access](../artifacts/auth-review/p103-users-desktop.png), [mobile outlets](../artifacts/auth-review/p103-outlets-mobile.png). Test credentials remain in ignored synthetic artifacts; no passwords appear in screenshots or source.

## Remaining decisions / next milestone

No P1-03 implementation blocker remains. Owner review gates P1-04 Products, Units, Prices and Suppliers. Existing production decisions from P1-02 remain open (Administrator MFA, recovery/session policy, HTTPS/certificates and backup/restore); no production readiness is claimed. Inventory-era deactivation checks and transfer participation authorization must be added alongside their actual tables/workflows. Optional classification, bin management, extensive browser compatibility/load testing and advanced performance work remain deferred.
