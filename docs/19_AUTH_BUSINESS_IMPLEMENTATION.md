# P1-02 Authentication, Tenant Isolation and Business Setup

Implementation record, 28 November 2026. Owner accepted P1-01 and authorized P1-02a/b/c. The separate concrete database execution approval was received for **conex360-auth-review** only, with synthetic data and no published MySQL port. No production/historical schema or unrelated Docker project is included. Stop for owner review before P1-03.

## Delivered structure

Four source projects retained. Domain/Identity holds session/lockout rules and identities. Application/Identity contains focused authentication/business use cases and adapter contracts. Infrastructure/Identity implements parameterized MySqlConnector transactions, hashing, raster logo storage and explicit migrations. Api/Identity composes cookie/CSRF/role/context policies, HTTP endpoints and controlled OS commands. No ORM, generic repository, fifth source project, Next.js auth authority or external identity service.

Frontend extends the original brand with `/login`, `/app`, `/account/password`, `/select-business`, `/settings/business`. Public foundation overview remains. Protected pages render generic non-cacheable HTML/RSC and fetch private data from .NET; no fabricated operational statistics/menus. Minimal React state; cross-tab channel sends invalidation only, never business data or credentials. This is unrelated to future checkout-display synchronization.

New dependencies: MySqlConnector 3.0.0; SkiaSharp 4.158.0 and SkiaSharp.NativeAssets.Linux.NoDependencies 4.158.0 (MIT image decoding/re-encoding). Existing pins retained. MySQL 8.4.13.1 image pinned by digest in review Compose. Password hashing uses ASP.NET Core IdentityV3 (PBKDF2-SHA512, 210,000 iterations), cookie authentication/Data Protection and antiforgery from the shared .NET framework. Sources: [MySqlConnector](https://mysqlconnector.net/), [SkiaSharp NuGet](https://www.nuget.org/packages/SkiaSharp/4.158.0), [ASP.NET Core cookie authentication](https://learn.microsoft.com/en-us/aspnet/core/security/authentication/cookie?view=aspnetcore-10.0).

## Database and consistency

Seven application tables: tenants, users, companies, tenant_memberships, auth_sessions, audit_events, security_events. Migration journal is additional tooling metadata. Exact DDL: database/migrations/0000–0002. No later inventory, payment, outlet or idempotency tables created. Unique provisioning operation/code/email, one company per tenant, membership/user session FK, scoped audit FKs, append-only events, immutable identity/session expiry and currency latch guards. No finance prerequisite, default account or fake entries.

Explicit embedded SQL runner uses UTF-8/LF-normalized SHA256 (portable across checkout line endings), expected database/version, named migration lock and journal validation. Markers delimit compound trigger statements. DDL auto-commits: a failure stops; an operator investigates partial evidence before a separately reviewed repair. No automatic startup migration or rollback/reset/DROP/FK disabling. Runtime account has DML only; separate migration account holds schema privileges in the isolated target. UUID bytes are RFC/big-endian; unsigned IDs and decimals retain string JSON conventions. Optimistic profile versions and context revisions reject stale edits/tabs. SQL commands revalidate active identity/session/membership/tenant/company and role inside their transaction.

## API

All `/api/v1` routes; browser uses same-origin `/api` proxy.

| Method | Route | Access / purpose |
|---|---|---|
| GET | /auth/csrf | Anonymous permitted; antiforgery request token, no-store |
| POST | /auth/login | CSRF + origin/rate limits, generic credential failures |
| GET | /auth/session | Active server session; no idle extension |
| POST | /auth/logout | Active session + CSRF, revoke and delete cookie |
| POST | /auth/password | Current password + CSRF/rate limit, rotate stamp/session and revoke all previous sessions |
| POST | /auth/context | Verified membership + expectedContextVersion; increment revision |
| POST | /auth/activity | CSRF; genuine UI activity, bounded idle touch |
| GET | /business/ | Selected active company, password change complete; X-Conex360-Context required |
| GET | /business/options | Scoped configured currencies |
| PUT | /business/ | Administrator, CSRF/context/expectedVersion |
| POST | /business/logo | Administrator, CSRF/context/X-Conex360-Version, raw image body |
| GET | /business/logo?context=… | Authorized current logo; no arbitrary path/tenant selector |
| GET | /health/live, /api/v1/health | Independent process liveness |
| GET | /health/ready | When DB enabled: migration readiness check; 503 on unavailable dependency |

## Security and owner launch decisions

Opaque 256-bit session secret is only in an authenticated/encrypted HttpOnly cookie; SQL stores SHA256. Every request checks current user/stamp/session and active memberships. Static Administrator/Staff backend policies; Staff/outlet administration remains P1-03. Global disable/recovery is an OS-controlled SysConex operation, not a tenant Administrator endpoint. Existing identity linkage requires explicit consent/operator reason and proof of the existing password; email alone never links. Provisioning atomically commits tenant/company/user/membership and audits. Retrying the exact onboarding operation requires password proof and matching payload; conflicting retry returns safely.

Proposed configurable defaults for production owner review: password 15–128 characters with variety, idle 30 minutes, absolute 8 hours, 5 failures/15-minute account lockout; process-local 12 login attempts/minute per proxy peer and 6 password attempts/minute. Backend polling does not extend idle lifetime. Shared proxy throttling is acceptable for this pilot but deployment capacity must be assessed before wider use. No email/SMS recovery; verified SysConex operator resets to a securely handed-off temporary passphrase, forces change and revokes sessions. Establish support identity-verification procedure and audit/privacy retention before live operation. **Administrator MFA launch policy remains undecided; MFA is not implemented. Do not treat this milestone as production launch approval.**

Production cookies use __Host prefix, Secure/HttpOnly/SameSite=Lax; antiforgery cookie Strict. Only explicit Development configuration allows separate non-Secure local cookie names. Unsafe commands validate CSRF including login/logout and reject supplied foreign origins. Production origin allowlist must contain the actual HTTPS origin. Trusted proxy IPs must be configured explicitly for forwarded HTTPS; never trust arbitrary X-Forwarded-* headers. See [Microsoft proxy guidance](https://learn.microsoft.com/en-us/aspnet/core/host-and-deploy/proxy-load-balancer?view=aspnetcore-10.0).

Persistent Data Protection keys require an encryption certificate/private key and separate password file. Back up both protected key ring and encryption certificate/password securely; retain old certificates for key rotation before deploying a replacement. Logos use private tenant/company directories, random server filenames, 2 MiB/2048px limits, PNG/JPEG decode and PNG re-encode stripping metadata. SVG/animated/invalid files denied. Only current authorized logo served. Failed SQL edits remove the newly written file; old files remain for later retention policy. DB and filesystem are not one transaction: crash-orphan files may remain but are never served unless referenced. No public static logo folder.

## Validation and run instructions

Actual test evidence and final commands are appended after verification below. No SQLite/in-memory result is presented as MySQL evidence.

Keep existing foundation project on port 3600. Review API uses loopback 5182, frontend review 3602; SQL has no published port. From repo PowerShell:

Subsequent owner-requested Workbench inspection uses the optional [localhost-only override and read-only account](LOCAL_MYSQL_WORKBENCH.md). The commands below describe the original base configuration; include the Workbench override when recreating MySQL to retain inspection port 3307.

```powershell
. .\scripts\Use-LocalNode.ps1
.\scripts\Initialize-AuthReviewSecrets.ps1
docker compose -p conex360-auth-review -f infrastructure/compose.auth-review.yaml --profile database-approved up -d --wait mysql
dotnet restore backend/Conex360.sln --locked-mode
dotnet build backend/Conex360.sln -c Release --no-restore
docker compose -p conex360-auth-review -f infrastructure/compose.auth-review.yaml --profile database-approved build tools
docker compose -p conex360-auth-review -f infrastructure/compose.auth-review.yaml --profile database-approved run --rm tools backend/src/Conex360.Api/bin/Release/net10.0/Conex360.Api.dll --admin-validate-migrations
docker compose -p conex360-auth-review -f infrastructure/compose.auth-review.yaml --profile database-approved run --rm tools backend/src/Conex360.Api/bin/Release/net10.0/Conex360.Api.dll --admin-migrate --expected-database conex360_auth_review
docker compose -p conex360-auth-review -f infrastructure/compose.auth-review.yaml exec -T mysql bash /opt/conex360/grant-runtime.sh
docker compose -p conex360-auth-review -f infrastructure/compose.auth-review.yaml --profile database-approved --profile runtime up --build -d api frontend proxy
```

Open **http://127.0.0.1:3602/login**. There is no seeded/default login. Provision an approved business first. One-shot storage-init sets ownership on this project's new private volume only. Non-root API persists keys/logos; API/proxy ports are loopback-only; DB unpublished. Do not use down -v/prune; stop only this named project and retain volumes/secrets to resume.

The explicit grant step gives runtime CRUD on five mutable app tables, SELECT/INSERT on events and SELECT only on the journal. Runtime cannot migrate or edit/delete evidence. Bootstrap creates accounts; migrations use the separate DDL identity; fixed local root grant script installs runtime permissions after installation. Local log-bin-trust-function-creators permits trigger creation without global migrator privileges. Initial error 1419 left journal 0000/0001 and zero triggers; these were inspected before resuming 0002. No destructive repair or changed DDL.

Synthetic verification after the approved migrations:

```powershell
docker compose -p conex360-auth-review -f infrastructure/compose.auth-review.yaml --profile database-approved run --rm -e CONEX360_MYSQL_APPROVED=1 tools vstest backend/tests/Conex360.IntegrationTests/bin/Release/net10.0/Conex360.IntegrationTests.dll --TestCaseFilter:FullyQualifiedName~MySqlIdentityTests --logger:trx --ResultsDirectory:/evidence/results
.\scripts\Prepare-AuthBrowserFixture.ps1
$env:PLAYWRIGHT_BROWSERS_PATH=Join-Path (Get-Location) '.tools/playwright'
Set-Location frontend
npx playwright test --config playwright.auth.config.ts
```

Tests append independent synthetic businesses, never reset/delete the database. Synthetic fixture passwords/cookies stay in ignored artifacts; protect them and never copy them into source/issues/logs. Browser tests use the review stack. Foundation browser tests start a separate host API/frontend; CONEX360_E2E_PORT=3603 avoids the existing 3600 stack. Nginx routes review /api directly to .NET despite the frontend's fixed development rewrite.

The tools bind current compiled backend files read-only to avoid copying developer secrets into images. The local secrets script writes ignored `.local/auth-review` files and a development encryption PFX; it changes no machine-wide settings. Its self-signed certificate and SSL Mode=Required are isolated-development choices. Production requires VerifyFull MySQL validation, managed filesystem permissions, real TLS/hostnames, protected cert distribution and off-host backups; these are launch prerequisites.

Controlled provisioning: prepare a **non-secret** JSON with operationId UUID, tenantCode, businessName, displayName, administratorEmail/name, timezone, currencyCode, currencyMinorUnits, operatorReference, reason. Supply it read-only as `/input/business.json`; invoke `--admin-provision --input /input/business.json`. Password is read by masked prompt, never an argument/source/default. In a protected non-echoed pipe, `--password-stdin` explicitly reads one line. Handoff privately to the verified owner; require first-login password change. For a new business linking an existing identity, additionally use `--link-existing` only after consent and read the existing password through the same prompt. No public registration.

Recovery/disable: controlled non-secret JSON identifies userPublicId **and** email, operatorReference/reason; `--admin-recover` requires new temporary password, `--admin-disable-user` revokes globally. Tenant-scoped `--admin-disable-membership` input has tenantId/membershipId/operatorReference/reason; it leaves other memberships/global identity intact. Runtime API does not enable Operations; only isolated tools configuration does. Protect OS/container/Docker access as platform authority. Never use these commands against production without its separate approval.

For an operator-created non-secret `.local/auth-review/business.json` file, the concrete masked-prompt invocation is:

```powershell
$businessInput=(Resolve-Path .local/auth-review/business.json).Path
docker compose -p conex360-auth-review -f infrastructure/compose.auth-review.yaml --profile database-approved run --rm --volume "${businessInput}:/input/business.json:ro" tools backend/src/Conex360.Api/bin/Release/net10.0/Conex360.Api.dll --admin-provision --input /input/business.json
```

Use synthetic details for this disposable review database. Securely hand the entered passphrase to the verified recipient; it must be changed at first login. No public registration or default credentials. The browser fixture helper automates only synthetic data through a protected stdin pipe; it is not a real-client onboarding shortcut.

Next milestone recommendation: P1-03 outlets/warehouses and basic user/outlet grants, only after P1-02 owner review. No P1-03 operational code introduced. Customer display is specified in [20_CUSTOMER_DISPLAY.md](20_CUSTOMER_DISPLAY.md) and reserved for P1-08.

## Final execution evidence — 28 November 2026

| Check | Actual result |
|---|---|
| Locked .NET restore / Release build / analyzers | Passed; SDK 10.0.404, zero build warnings/errors |
| dotnet format --verify-no-changes --no-restore | Passed |
| Unit tests | 31 passed, including original 22 foundation tests |
| HTTP host integration | 10 passed, including original seven foundation tests; no SQL substitute used for database claims |
| Real MySQL 8.4 integration | Eight passed, zero skipped in explicit approved Docker run; separate host run skips these eight by design |
| Frontend Prettier / ESLint / TypeScript / production build | Passed |
| Frontend Node tests | 10 passed, including original nine health contracts |
| Foundation Playwright | Four passed against separate real host API/frontend on 5180/3603; health/retry/keyboard/mobile preserved. Only outdated “no database” copy/assertion was updated |
| Auth/business Playwright | Five passed against Nginx/Next/.NET/real MySQL review stack: controlled CLI onboarding/forced password replacement, multi-membership selection, private HTML/RSC/API caching, profile/unsafe and valid logo/mobile, password mismatch, two-window logout, generic invalid credentials/return URL |
| Runtime persistence/dependency rehearsal | Passed: existing cookie and PNG hash before/after MySQL stop/start and API restart/replacement; live 200 while DB stopped, readiness/private requests 503 then recovered; encryptedSecret verified in persistent key ring |
| Migrations / privileges | 0000/0001/0002 journal present; eight tables total (seven app + journal), nine triggers. Idempotent migration rerun passed with no new statements applied. Runtime journal/evidence write denial verified |
| Dependency advisory checks | npm audit: zero vulnerabilities; dotnet list package --vulnerable --include-transitive: none reported by current sources. This is a point-in-time advisory result |
| Preservation | Original historical SQL SHA256 still 1810fe5af34702fa8b475aa1cbe3cb16f87b0e00a8b3d9f6361ce2fcc0f3fd32; no archive/reference diff. Existing foundation containers left running; same Git branch, no commit/push/merge/discard |

Real MySQL scenarios cover atomic provisioning/replay/duplicate-company constraint and a forced failure after tenant creation; real rollback leaves no tenant; concurrent optimistic edits allow one winner; successful/wrong/disabled/locked login; idle/absolute expiry; password/session rotation and global disabling; missing/foreign CSRF, logout and replay revocation; foreign membership rejection/stale-context conflict; shared-user tenant suspension/membership disabling without global effect; Administrator/Staff API restrictions; private scoped logo reads/unsafe uploads; immutable identity guards and runtime privilege denial. Separate unit tests check dimension/file limits, salted password verification and expiry boundaries.

Initial failures were corrected and rerun: MySQL trigger permission 1419 was inspected before non-destructive resumption; static PNG codec frame count is zero on this decoder; generic sign-in failures now remain on login; browser cross-tab invalidation uses one channel object per window so its own form commands do not reload themselves; native Node TypeScript tests use erasable class field syntax. Final results above supersede failed intermediate logs; no unavailable test is counted as passed.

Test evidence stays in ignored `artifacts/auth-review`: host-tests.log, mysql-tests.log and results/*.trx, foundation-browser-tests.log, browser-tests.log, persistence-tests.log, image build logs and screenshots. Screenshot artifacts: [desktop login](../artifacts/auth-review/login-desktop.png), [desktop workspace](../artifacts/auth-review/workspace-desktop.png), [desktop business settings](../artifacts/auth-review/business-desktop.png), [mobile business settings](../artifacts/auth-review/business-mobile.png). Screens were visually inspected. Synthetic fixture/cookie files are deliberately excluded from Git and Docker build contexts.

Additional commands executed: git status/diff/hash checks; dotnet restore/build/test/format/list package; npm format/lint/typecheck/test/build/audit; Playwright foundation/auth configurations; isolated Compose mysql/tools/api/frontend/proxy builds/start/restart; explicit migration validation/application/replay; fixed grant-runtime script; Prepare-AuthBrowserFixture.ps1; Test-AuthReviewPersistence.ps1. No production data, original schema execution, automatic migrations, global installations or unrelated Docker operations.

To repeat persistence checks after a successful auth browser run, from repo root use `.\scripts\Test-AuthReviewPersistence.ps1`. It stops/starts only the review MySQL service, verifies 200/503 behavior, restarts only review API and checks the persisted cookie/PNG hash and encrypted key ring. It restores MySQL in a finally block when the failure-phase assertions fail.

## Remaining decisions and limits

No remaining local database-engine blocker. Owner review gates P1-03. Before production approve Administrator MFA policy, concrete password/session/support recovery rules, audit/privacy/old-logo retention, actual business/currency/timezone, HTTPS/domain/proxy trust, database CA validation, protected certificate/secret permissions/rotation and off-host backup/restore/RPO/RTO. Self-signed local keys and relaxed local cookie/TLS verification are Development-only; production configuration rejects those relaxations. Current rate limits share the reverse-proxy peer and reset process-local counters on restart; persistent account lockout remains. Confirm pilot limits before larger deployment. No external recovery messages or MFA implementation is claimed.

This validates existing-database restarts and runtime asset/key persistence, not clean reinstall onto another host, encrypted off-host backup restore or future inventory correctness. First release has no preceding production schema to upgrade. Old image files/crash-orphan uploads await retention policy; referenced files remain private. No outlets/grants UI, catalogue, inventory, manufacture, POS/display operations, accounting/tax or offline functionality was added. Administrator membership administration and last-Administrator ordinary-management rules belong to P1-03.

Initial/recovery passwords are forced-change credentials, without a separate activation-expiry timestamp/token workflow in this slice; require prompt private handoff and revoke unused credentials. Agree whether a timed activation window is required before production. Data Protection configuration currently accepts one encryption certificate: keep it stable across restarts/releases. Certificate rollover needs a separately verified decryption/rotation procedure before replacing it; retaining a backup alone does not configure old-key decryption in a new container.

## File manifest

Tracked changes and newly created files for this milestone (historical references excluded):

- `.dockerignore`
- `.gitattributes`
- `.gitignore`
- `AGENTS.md`
- `backend/.env.example`
- `backend/Directory.Packages.props`
- `backend/src/Conex360.Api/Errors/GlobalExceptionHandler.cs`
- `backend/src/Conex360.Api/Health/HealthEndpoints.cs`
- `backend/src/Conex360.Api/Identity/AdministrativeCommands.cs`
- `backend/src/Conex360.Api/Identity/IdentityEndpoints.cs`
- `backend/src/Conex360.Api/Identity/IdentitySetup.cs`
- `backend/src/Conex360.Api/packages.lock.json`
- `backend/src/Conex360.Api/Program.cs`
- `backend/src/Conex360.Application/Identity/IdentityContracts.cs`
- `backend/src/Conex360.Application/Identity/IdentityService.cs`
- `backend/src/Conex360.Domain/Identity/IdentityModels.cs`
- `backend/src/Conex360.Infrastructure/Conex360.Infrastructure.csproj`
- `backend/src/Conex360.Infrastructure/Identity/Database.cs`
- `backend/src/Conex360.Infrastructure/Identity/IdentityStore.cs`
- `backend/src/Conex360.Infrastructure/Identity/LogoStore.cs`
- `backend/src/Conex360.Infrastructure/Identity/Migrations.cs`
- `backend/src/Conex360.Infrastructure/Identity/PasswordService.cs`
- `backend/src/Conex360.Infrastructure/packages.lock.json`
- `backend/tests/Conex360.IntegrationTests/IdentityHttpTests.cs`
- `backend/tests/Conex360.IntegrationTests/IdentityTestHost.cs`
- `backend/tests/Conex360.IntegrationTests/MySqlIdentityTests.cs`
- `backend/tests/Conex360.IntegrationTests/packages.lock.json`
- `backend/tests/Conex360.UnitTests/IdentityRulesTests.cs`
- `backend/tests/Conex360.UnitTests/packages.lock.json`
- `CODEX_START_HERE.md`
- `database/migrations/0000_migration_journal.sql`
- `database/migrations/0001_identity_business.sql`
- `database/migrations/0002_identity_guards.sql`
- `database/README.md`
- `docs/00_PROJECT_OVERVIEW.md`
- `docs/01_REQUIREMENTS.md`
- `docs/02_ARCHITECTURE.md`
- `docs/03_DATABASE_DESIGN.md`
- `docs/05_BUSINESS_WORKFLOWS.md`
- `docs/06_API_CONTRACTS.md`
- `docs/07_SECURITY_AND_TENANCY.md`
- `docs/08_FRONTEND_AND_UX.md`
- `docs/10_TEST_AND_ACCEPTANCE.md`
- `docs/11_DEPLOYMENT_AND_OPERATIONS.md`
- `docs/12_DECISION_LOG.md`
- `docs/13_ROADMAP.md`
- `docs/14_PHASE1_IMPLEMENTATION_PLAN.md`
- `docs/15_PHASE1_SCHEMA_MAPPING.md`
- `docs/16_ENVIRONMENT_READINESS.md`
- `docs/17_FUTURE_PRODUCT.md`
- `docs/19_AUTH_BUSINESS_IMPLEMENTATION.md`
- `docs/20_CUSTOMER_DISPLAY.md`
- `docs/21_P1_02_DATABASE_REVIEW.md`
- `frontend/next.config.ts`
- `frontend/playwright.auth.config.ts`
- `frontend/playwright.config.ts`
- `frontend/scripts/check-auth-persistence.mjs`
- `frontend/src/app/account/password/page.tsx`
- `frontend/src/app/app/page.tsx`
- `frontend/src/app/auth.css`
- `frontend/src/app/layout.tsx`
- `frontend/src/app/login/page.tsx`
- `frontend/src/app/select-business/page.tsx`
- `frontend/src/app/settings/business/page.tsx`
- `frontend/src/components/auth-workspace.tsx`
- `frontend/src/components/foundation-workspace.tsx`
- `frontend/src/lib/api/identity.ts`
- `frontend/tests/auth-e2e/business.spec.ts`
- `frontend/tests/e2e/workspace.spec.ts`
- `frontend/tests/unit/identity.test.ts`
- `infrastructure/compose.auth-review.yaml`
- `infrastructure/docker/api.Dockerfile`
- `infrastructure/docker/auth-tools.Dockerfile`
- `infrastructure/mysql/bootstrap-accounts.sh`
- `infrastructure/mysql/grant-runtime.sh`
- `infrastructure/nginx/auth-review.conf`
- `README.md`
- `scripts/Initialize-AuthReviewSecrets.ps1`
- `scripts/Prepare-AuthBrowserFixture.ps1`
- `scripts/Test-AuthReviewPersistence.ps1`
