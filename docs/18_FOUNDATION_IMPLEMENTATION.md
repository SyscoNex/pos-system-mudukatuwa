# P1-01 Minimal Project Foundation — implementation record
**SysConex / Conex360 v0.1.0 — 25 November 2026. Foundation review gate; authentication/business management not started.**

## Delivered scope and files
- Root: pinned global.json, .editorconfig, .gitattributes, expanded .gitignore, .dockerignore, scripts/Use-LocalNode.ps1 and loopback-only scripts/Test-Foundation.ps1. A short local branch feature/p1-01-foundation; no commit/push/merge.
- backend/Conex360.sln: Domain, Application, Infrastructure and Api projects plus UnitTests and IntegrationTests. Directory.Build.props enables nullable/analyzers/warnings-as-errors/version/lockfiles. Directory.Packages.props centralizes exact package versions; six packages.lock.json files enable locked restore.
- Domain/Application/Infrastructure intentionally have no business entities/use cases/SQL adapter yet. Dependency graph is Domain <- Application <- Infrastructure, with API referencing Application/Infrastructure; architecture tests enforce the graph.
- API Program.cs, Health/HealthEndpoints.cs, Errors/GlobalExceptionHandler.cs and Serialization/*StringConverter.cs: process-only health, standard safe problem codes/trace IDs, request/error JSON logs, validation registration and exact decimal/unsigned-ID wire strings. appsettings and launchSettings are safe local configuration; backend/.env.example documents environment variables without secrets.
- frontend/: Next.js App Router/strict TypeScript, Conex360 responsive shell, native-vector brand/receipt illustration, live API health/retry/timeout/cancellation, read-only build journey, keyboard quick-guide dialog and mobile navigation. No pretend transaction metrics, user login or connected business records. error/not-found pages and favicon included.
- frontend/src/lib/api/health.ts: typed same-origin transport with no-store, cancellation and runtime contract checks. next.config.ts contains a fixed server-only local proxy, baseline security headers, standalone output and no powered-by header. Authenticated content remains .NET-authorized when introduced; there is no Next API business handler/MySQL access.
- Frontend exact package/lock/tool configs, Node unit tests, Playwright actual-API/browser tests, standalone asset preparation/start scripts and environment example.
- infrastructure/: two multi-stage non-root image builds, Nginx fixed routing, project-isolated Compose with loopback-only public port, read-only roots/tmpfs, dropped capabilities, log limits and proxy healthcheck. No DB service/volume/migration, no production DNS/TLS setup.
- .github/workflows/foundation.yml: pinned action commits, locked restores, formatting/lint/type/build/tests and browser verification; read-only repository permissions and no deployment. Workflow prepared locally, not executed on GitHub.
- Current guidance, requirements/architecture/security/API/roadmap/environment/decision records updated; original historical SQL and enterprise archive remain unchanged.

## Selected versions
| Component | Pin |
|---|---|
| .NET SDK / target / runtime | 10.0.404 / net10.0 / 10.0.15 |
| ASP.NET OpenAPI | 10.0.15 |
| Test SDK / xUnit / VS runner | 18.12.0 / 2.9.3 / 4.0.1 |
| API integration host | Microsoft.AspNetCore.Mvc.Testing 10.0.15 |
| Workspace Node LTS / bundled npm | 26.13.1 / 11.20.0 |
| Next.js / React / React DOM | 16.4.6 / 19.3.1 / 19.3.1 |
| TypeScript | 6.0.3 |
| ESLint / @eslint/js | 10.15.0 / 10.0.1 |
| Next lint plugin / typescript-eslint / React Hooks plugin | 16.4.6 / 8.74.0 / 7.1.1 |
| Prettier / ESLint Prettier config | 3.10.1 / 10.1.8 |
| Lucide React | 1.79.0 |
| Playwright | 1.65.1; project-local Chromium test binaries |
| Type definitions: Node / React / React DOM | 26.6.7 / 19.3.1 / 19.3.0 |
| Docker client/engine / Compose | observed 29.8.2 / 5.5.1 |
| Nginx unprivileged | 1.30.6-alpine |

Docker Node, SDK, ASP.NET and Nginx references are pinned by version and registry manifest digest in their files. SDK/NuGet and npm dependencies are exact/locked. MySQL 8.4 remains approved future storage; no MySQL package/image/database was introduced solely for this scaffold. MySqlConnector is added when an approved database slice actually needs it.
Version evidence: official Node release index/SHASUMS, npm registry engine/peer metadata, NuGet stable package metadata and registry image manifests. The active system Node stays unchanged; ignored .tools holds the verified runtime/browser binaries.

## Decisions and boundaries
- App Router/production standalone Node with included assets; same-origin browser calls, fixed local Next proxy, Nginx sends /api directly to .NET in Compose.
- Four straightforward backend projects; no generic repository, mediator, Worker, outbox, event bus or unused ORM/DB credentials.
- Business operations absent; default secure scope/tenant enforcement will be implemented and tested in P1-02 before business routes. Public health contains no business data.
- Strict decimal strings reject numeric tokens, exponent/localized syntax, overflow and silently rounded input. Unsigned ID strings preserve values above JavaScript integer precision. Module-specific quantity/price limits remain future DTO rules.
- Safe problem details for unmatched routes and unexpected failures; raw exception messages/payloads are excluded from the custom error log/response. Request logging captures method/endpoint/status/duration/correlation, not query/body/credentials.
- Nginx access logs contain only method/status/duration/generated request ID; no raw URL/query, client IP, referrer or request body is included in the access-log format.
- .NET 10 built-in validation is registered; the only API endpoint has no input DTO. No business validation/authorization is claimed complete.
- /health/live and /health/ready both assert process only at this stage; the response explicitly says scope=process. Required DB readiness must be added with the database slice.
- Company/stock/cost/manufacture/authentication scope is approved, but no schema, migration, session, user or transaction functionality is implemented in this milestone.

## Commands and actual evidence
Commands ran from the repository root unless noted; full routine output is not checked into source.
| Command/group | Result |
|---|---|
| git status, file/guidance inspection, tool --version/--info and docker ps | Inspected/preserved pre-existing changes; SDK 10 and Docker engine available; no running containers at initial check |
| Official registry metadata and SHA-256 checks | Compatible package versions/digests selected; Node Windows archive verified before extraction |
| git switch -c feature/p1-01-foundation | Succeeded, no commit/push |
| dotnet new sln/classlib/web/xunit --no-restore and sln add | Four source/two test projects created; template sample classes/tests replaced with focused foundation code |
| dotnet restore backend/Conex360.sln | Succeeded after removing redundant validation package reference already provided by the framework |
| dotnet build backend/Conex360.sln --no-restore -c Release | Succeeded, zero warnings/errors |
| dotnet format backend/Conex360.sln --no-restore; --verify-no-changes | Formatted; verification passed |
| dotnet test backend/Conex360.sln -c Release --no-restore | 22 unit + 7 real API-host integration tests passed; zero skipped; not database integration tests |
| dotnet list backend/Conex360.sln package --vulnerable --include-transitive | No known vulnerable packages reported by configured sources |
| Workspace Node helper; npm install and fresh npm ci in frontend | Final supported dependency graph installed/locked and reproduced, no forced peer overrides; no global npm/Node installation |
| npm run format and format:check | Passed |
| npm run lint | Passed with zero warnings under ESLint 10 |
| npm run typecheck | Passed |
| npm test | 9 Node API-client contract/failure/cancellation tests passed |
| npm run build (including standalone asset postbuild) | Passed; root is dynamic SSR; assets available to standalone runtime |
| npx playwright install chromium | Browser binaries installed under project .tools |
| npm run test:e2e | 4 tests passed against built standalone frontend and actual .NET process; mobile/desktop, no-store, retry, dialog keyboard/focus and navigation/overflow |
| npm audit --audit-level=high | No known vulnerabilities reported |
| docker compose -p conex360-foundation -f infrastructure/compose.yaml config --quiet | Passed |
| Docker image builds and isolated compose up -d --no-build | Final API/frontend production builds and proxy startup succeeded |
| scripts/Test-Foundation.ps1 | Page/API/assets/favicon/private cache/safe 404 all passed through production Nginx |
| docker compose ps, inspect, volume listing | Proxy healthy; API/frontend/proxy non-root and read-only; only 127.0.0.1:3600 published; no project DB volumes |

Local screenshots: artifacts/frontend-desktop.png and artifacts/frontend-mobile.png (ignored generated evidence). Visual review prompted mobile whitespace/focus and text-contrast corrections; subsequent browser checks passed. The shell deliberately shows an uninitialized database rather than fake sales/stock metrics.

Resolved setup failures: SDK flagged a redundant validation PackageReference; supported lint versions required removing legacy incompatible peers and regenerating the new dependency graph; React lint caught synchronous effect state; standalone startup needed explicit asset packaging. These were corrected, not waived. Playwright emits a harmless inherited NO_COLOR/FORCE_COLOR warning; it does not affect tests.
The first dotnet template invocation emitted SDK first-run development-certificate creation; no certificate trust command was run and local setup uses HTTP. No machine-wide Node upgrade, profile edit or Docker daemon setting change was made.

## Docker runtime smoke
Passed on project conex360-foundation: HTML 200 with private/no-store, /api/v1/health 200 with scope=process and no-store, built JavaScript 200, favicon 200, unknown API 404 with NOT_FOUND/traceId. Nginx proxy health became healthy. Runtime users are API 1654, frontend node and proxy 101; all roots are read-only. API/frontend have no published host port; only proxy binds 127.0.0.1:3600. Project volume listing is empty. No other projects were stopped/reconfigured.

The first ad-hoc smoke comparison exposed PowerShell treating application/problem+json as bytes; the checked-in smoke script explicitly decodes it and then passed. No API change or waived assertion was needed. Docker configuration deliberately has no MySQL service, database volume or initialization.

The task-owned Compose services were stopped after verification to release local ports/resources; their images and stopped containers remain available. No volumes, images, user data or unrelated project were deleted. Playwright also stopped its own host processes. Restart using README instructions.

The in-app preview browser host was unavailable when opening the localhost URL. This limits live handoff only: actual production HTTP smoke and standalone desktop/mobile Playwright checks/screenshots succeeded. No production deployment, TLS setup, database/hardware/restore/load or remote GitHub workflow execution is claimed.

## Running and next gate
Follow README.md for two local terminals, pinned workspace Node, checks or isolated Compose. Local ports: frontend/proxy 3600, host API 5180; Compose publishes only loopback 3600. API_PROXY_TARGET is server-only and resolved at Next build time. Production requires a separately reviewed TLS/host/trusted-proxy/secrets setup; this local HTTP Compose is not a live deployment.
Stop at this foundation review. Next milestone is P1-02 controlled tenant/default-company setup, secure cookie authentication/revocable sessions and business profile with two-tenant tests. Before DB execution, review concrete incremental DDL/guards and explicitly authorize a disposable target. No 38-table initialization, historical schema execution, production access, accounting/offline code, hardware integration, restore test or business performance validation has occurred.
