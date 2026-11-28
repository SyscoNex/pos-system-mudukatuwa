# P1-04 Products, Units, Prices and Suppliers — 28 November 2026

P1-03 was accepted. P1-04a/b/c implementation and the concrete database package in [docs/24](24_P1_04_DATABASE_REVIEW.md) were separately approved. Stop here for owner review before P1-05. Production, SchoolGrid and additional SQL remain excluded.

## Delivered

- Company-wide units, optional idempotent standard-unit setup, simple parent categories and cycle prevention.
- Products with SKU, category, fixed base UOM, RAW/PACKAGING/INTERMEDIATE/FINISHED type, independent operation flags, NONE/LOT tracking and expiry configuration.
- Versioned product-unit aggregate with positive exact conversions, base factor one, whole-unit restrictions, active purchase/sale defaults and nullable purchase/selling prices. Blank is unset; zero is explicitly configured.
- Multiple exact barcodes per product unit, company uniqueness, leading zeros and soft deactivation; scoped lookup returns the matched unit.
- Supplier CRUD/contact details, search/filter/status, and retained supplier/customer flags for future customer management.
- Existing protected workspace extended with Products, Categories, Units and Suppliers. Administrator edits; Staff reads active records without purchase prices/internal supplier notes. Native dialogs, loading/error/empty states and progressive optional settings reuse the current design.
- Atomic business/audit writes; product audit JSON contains exact before/after product, conversion, price and barcode snapshots. No credentials or unnecessary personal data are added to audit.

No stock, batches, receiving, valuation, sales/customer workflow, manufacturing or POS functionality was introduced. The mandatory [P1-08 customer display specification](20_CUSTOMER_DISPLAY.md) is unchanged.

## Files and database

| Area | Files |
|---|---|
| Domain/application | `Domain/Catalog/CatalogNumbers.cs`, `Application/Catalog/CatalogContracts.cs` |
| Focused SQL/API | `Infrastructure/Identity/CatalogStore.cs`, `Api/Identity/CatalogEndpoints.cs`; existing IdentitySetup/Program wire them in |
| Existing audit | IdentityStore.Audit accepts optional details JSON in the existing column; other callers retain their behavior |
| Database | `database/migrations/0006_catalog_suppliers.sql`, `0007_catalog_guards.sql` |
| Local tooling | `infrastructure/mysql/grant-catalog.sh`, auth-review Compose feature flags/mount; `compose.catalog-clean.yaml` reuses the existing tools image with a separate evidence folder |
| Frontend | `catalog-panel.tsx`, four `src/app/settings` pages; workspace navigation, safe return paths and shared CSS extended |
| Tests | `CatalogNumbersTests.cs`, `CatalogTests.cs`, `tests/auth-e2e/catalog.spec.ts`; existing migration-package assertion extends through 0007 |
| Active knowledge pack | AGENTS, README, CODEX_START_HERE and relevant requirements/architecture/database/API/security/UX/acceptance/roadmap/decisions/environment/schema mapping |

Only six application tables added: units, item_categories, items, item_units, item_barcodes, parties. Total: **17 application tables + schema_migrations**, versions 0000–0007. Scoped FKs, code/SKU/barcode uniqueness, generated unique active-default keys, immutable ownership/base identities, exact DECIMAL checks and no-delete guards supplement application validation. No existing migration/checksum or historical schema was altered. Runtime gains SELECT/INSERT/UPDATE on the six tables; no DELETE, DDL or migration-journal write permission.

The approved review target was upgraded from 0005, and private conex360-p104-clean installed 0000–0007 with no published port. The original 0002→0005 upgrade was already verified in P1-03; this slice verifies the next incremental upgrade. Workbench still uses its SSL-required read-only account at **127.0.0.1:3307**. The clean target keeps separate evidence so it cannot overwrite review browser fixtures.

## Endpoints and authorization

All paths below start `/api/v1/catalog`. Existing cookie authentication, active session/membership/tenant/company checks, no-store, CSRF and `X-Conex360-Context` apply. Master mutations also require Administrator. Context/role revalidation occurs in the guarded transaction, not only middleware.

| Routes | Purpose |
|---|---|
| GET/POST `/units`, PUT `/units/{id}` | List/create/edit/deactivate units |
| POST `/units/defaults` | Optional idempotent standard-unit setup |
| GET/POST `/categories`, PUT `/categories/{id}` | Categories and optional parent |
| GET/POST `/products`, GET/PUT `/products/{id}` | Product list/detail/full retained unit/barcode aggregate |
| GET `/barcode?value=...` | Exact active mapping; `matchedItemUnitId` plus sanitized product detail |
| POST `/products/{id}/convert` | Exact preview `{itemUnitId, quantity}` → `{baseQuantity}`; CSRF protected, no mutation |
| GET/POST `/suppliers`, PUT `/suppliers/{id}` | Supplier contacts and status |

| Action | Administrator | Staff |
|---|---|---|
| Active catalogue and supplier contacts | Yes | Yes, company-wide |
| Inactive records | Yes | No |
| Purchase-price fields/internal supplier notes | Yes | Omitted from API DTOs |
| Master data, factors, prices, barcodes | Manage | Read only |
| Outlet stock/operations | No new capability | No new capability; grants still required |

Unsigned IDs/versions, factors, quantities and prices remain JSON strings. Product writes require every retained child ID/version; deactivation replaces deletion. Safe 400/403/404/409 errors cover invalid configuration, authority, foreign IDs, duplicates and stale edits. Product/supplier lists currently return at most 1,000 rows, with local search/filtering; larger catalogues need server pagination before use.

## Technical decisions and limits

- No dependencies changed: SDK 10.0.404/runtime 10.0.15, MySqlConnector 3.0.0, Next 16.4.6/React 19.3.1/TypeScript 6.0.3, workspace Node 26.13.1/npm 11.20.0 and all locks/image pins retained. No machine-wide configuration changed.
- Base UOM is immutable immediately, deliberately stricter than the original after-use proposal. Correct a wrong stock identity with a replacement SKU. Used-SKU/tracking restrictions must be added when transaction tables exist.
- First explicit price, including zero, sets the existing audited currency lock. Changing the currency would reinterpret stored prices. This safeguard and fixed base UOM were disclosed in the owner-approved SQL review.
- Conversion factors are product-specific. Explicit COUNT packaging can relate to the base measure; no automatic density, universal packaging quantity or different-SKU manufacturing shortcut. BigInteger-scaled arithmetic rejects intermediate precision loss and DECIMAL overflow; frontend does no floating-point quantity/money calculation.
- Company serialization follows existing management patterns; parent and child expected versions reject stale edits. Category acyclicity and minimum active defaults are application transaction rules in addition to SQL maximum/default and relationship constraints.
- Staff price visibility follows the role revalidated inside the SQL transaction; internal values are redacted too. Existing context revision/revocation, CSRF and private cache handling remain intact. No new persistent browser state.
- Catalogue prices are defaults, not inventory valuation. Future documents must snapshot description, unit, factor and price. Actual receiving cost/moving average/FEFO/lot and quantity history remain P1-05 onward.
- Production MFA/session/recovery review, client UOM/packaging data, backup restore and production deployment are still separate decisions. No blocker remains for reviewing this slice; P1-05 requires approved inventory/cost/rounding rules and a new concrete migration gate.

## Local use

Existing operators can open **http://127.0.0.1:3602**, sign in, and use the four new navigation links. Confirm Business currency before entering prices. Start with **Units → Set up standard units**, then Categories, Products and Suppliers. Create a product with a base unit; open **Units, prices & barcodes** for explicit package factors/prices/barcodes. Each enabled purchase/sale operation needs exactly one active default. Leave prices blank when unknown. Use status filters and versioned edits to deactivate records; active dependent products prevent unsafe unit/category deactivation.

To restart the already approved local review stack, from the repository root:
```powershell
docker compose -p conex360-auth-review -f infrastructure/compose.auth-review.yaml -f infrastructure/compose.workbench.yaml --profile database-approved --profile runtime up -d --no-build
```
After replacing API/frontend containers, restart only this project's proxy if it retained old upstream addresses. Do not run `down -v`, resets, global Docker stop/prune or any SchoolGrid command.

For host API configuration, retain the existing auth/database/storage setup and add `Catalog__Enabled=true` only after schema 0007/grants are ready. Readiness then requires schema version 7. Auth disabled foundation development still works without MySQL. Existing onboarding/secure password handoff instructions are in docs/19; P1-03 Staff and outlet setup remains in docs/21. No public registration or new seeding is needed.

## Commands and verification

Approved schema/grant commands used (not API startup):
```powershell
docker compose -p conex360-auth-review -f infrastructure/compose.auth-review.yaml -f infrastructure/compose.workbench.yaml --profile database-approved run --rm --pull never tools backend/src/Conex360.Api/bin/Release/net10.0/Conex360.Api.dll --admin-migrate --expected-database conex360_auth_review
docker compose -p conex360-auth-review -f infrastructure/compose.auth-review.yaml -f infrastructure/compose.workbench.yaml exec -T mysql sh /opt/conex360/grant-catalog.sh
```
Clean install used `-p conex360-p104-clean`, base plus `compose.catalog-clean.yaml`, then grant-runtime.sh, grant-organization.sh and grant-catalog.sh inside only that MySQL container. The evidence folder is `artifacts/p104-clean`. New targets/SQL are not authorized by this runbook alone.

Build/check commands used:
```powershell
dotnet format backend/Conex360.sln --verify-no-changes --no-restore
dotnet build backend/Conex360.sln --no-restore -c Release
dotnet test backend/Conex360.sln --no-build -c Release
. ./scripts/Use-LocalNode.ps1
```
From frontend: `npm run lint`, `npm run typecheck`, `npm test`, `npm run format:check`, `npm run build`. Docker review `build api frontend`, then `up -d --no-build --wait` with both profiles/files. API was rebuilt once for the stale-role/audit correction, frontend once for the dialog loading-race correction; tools image was reused throughout.

Real MySQL used the existing tools service, `CONEX360_MYSQL_APPROVED=1`, `vstest backend/tests/Conex360.IntegrationTests/bin/Release/net10.0/Conex360.IntegrationTests.dll --TestCaseFilter:FullyQualifiedName~MySqlIdentityTests`. Focused clean-target execution filtered `CatalogPrecision`. Playwright uses the existing auth configuration after `scripts/Prepare-AuthBrowserFixture.ps1`, workspace browsers in `.tools/playwright`, and foundation external URL http://127.0.0.1:3602.

Initial failures: clean-target connection failed before SQL (empty schema verified before retry); an overbroad Linux test command ran host-only HTTP fixtures with Windows content paths (host checks and filtered MySQL rerun pass); formatting was corrected; first browser attempts hit Nginx's stale upstream after container replacement (review proxy restarted). The new browser workflow also found a Supplier-dialog loading race; catalogue panels now reset by route and creation waits for initial loading. No tests/constraints were weakened.

| Final check | Actual result |
|---|---|
| Backend format/build | Passed; Release build 0 warnings/errors |
| Backend unit tests | 32 passed |
| Host HTTP integration | 10 passed; 10 opt-in MySQL cases correctly skipped here |
| Approved review real-MySQL regression | All 10 passed, including catalogue scenario after security/audit corrections |
| Private clean install | 0000–0007 applied; focused catalogue test passed; checksum replay succeeds without reapplying SQL |
| Frontend lint/typecheck/format/unit/audit | Passed; 10 unit tests; npm audit --audit-level=high reports 0 vulnerabilities |
| Production builds | Host Next.js build and actual final Docker API/frontend production builds passed |
| Foundation browser regression | 4 passed against running review stack |
| Auth/organization/catalogue browser | All 7 workflows passed across initial successful cases and the 4 affected reruns; no unresolved failure |
| Responsive smoke | Desktop 1440×1050 and mobile 390×844; product form has no page overflow |
| Local readiness/inspection | API database readiness healthy; SSL read-only Workbench sees 18 tables and migration versions 0–7 |
| Preservation | Old SQL 0000–0005, archived references and customer display unchanged; historical schema SHA256 remains 1810fe5af34702fa8b475aa1cbe3cb16f87b0e00a8b3d9f6361ce2fcc0f3fd32 |

Representative synthetic screenshots, visually checked: [desktop product form](../artifacts/auth-review/p104-product-desktop.png), [mobile product form](../artifacts/auth-review/p104-product-mobile.png). Evidence is ignored local output, not production data. Existing foundation stack and SchoolGrid were left untouched. Private p104-clean MySQL is stopped after verification, with its volume preserved; review stack remains running. No commit/push/deploy was performed.

No P1-04 blocker remains. Recommended next milestone after owner review: **P1-05 Inventory and Incoming Stock**, with real operational receiving costs, lot/date rules, immutable transaction snapshots, ledger/balance invariants and approved rounding policy before its separately reviewed SQL execution.
