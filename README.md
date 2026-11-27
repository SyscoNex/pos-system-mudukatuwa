# Conex360 — Phase 1 development knowledge pack
**SysConex | P1-02 / application v0.1.0 / knowledge pack v0.5 | 28 November 2026**

Conex360 has a comprehensive long-term product vision. The immediate delivery is a lightweight, reliable online POS and stock/manufacturing system for a coconut business operated initially by one or two people.

The owner accepted P1-01 and authorized P1-02 Authentication, Tenant Isolation and Business Setup. The existing foundation is preserved and extended with cookie sessions, controlled onboarding, private business settings/logos and protected frontend routes. Database execution was separately approved for the disposable conex360-auth-review target and synthetic tests only. See [P1-02 implementation/runbook](docs/19_AUTH_BUSINESS_IMPLEMENTATION.md), [concrete database review](docs/21_P1_02_DATABASE_REVIEW.md), and [P1-01 evidence](docs/18_FOUNDATION_IMPLEMENTATION.md). Stop for owner review before P1-03; no production access or automatic startup migrations.

## Start here
1. Read AGENTS.md, docs/00_PROJECT_OVERVIEW.md and docs/12_DECISION_LOG.md.
2. Review docs/14_PHASE1_IMPLEMENTATION_PLAN.md and docs/03_DATABASE_DESIGN.md.
3. Review docs/15_PHASE1_SCHEMA_MAPPING.md and docs/16_ENVIRONMENT_READINESS.md.
4. Review P1-02 evidence before authorizing P1-03. The 38 tables remain a starting design; only seven application tables are introduced now. Same-computer customer display is mandatory Phase 1, reserved for P1-08; see docs/20_CUSTOMER_DISPLAY.md.

## Run locally
Prerequisites: .NET SDK 10.0.404 and Node 26.13.1/npm 11.20.0. The Node selection is workspace-local on Windows; the system Node installation is unchanged.

From the repository root in PowerShell:
```powershell
. .\scripts\Use-LocalNode.ps1 -Install
dotnet restore backend/Conex360.sln --locked-mode
dotnet run --project backend/src/Conex360.Api
```
Keep the API terminal running. In a second terminal from the same root:
```powershell
. .\scripts\Use-LocalNode.ps1
Set-Location frontend
npm ci
npm run dev
```
Open http://127.0.0.1:3600. The API is http://127.0.0.1:5180/api/v1/health; development OpenAPI is /openapi/v1.json on the API. No database or secrets are required. On Linux/macOS use the same pinned tools; the Windows helper is optional tooling, not an application dependency.

For the built production frontend use npm run build then npm start from frontend. The postbuild step includes standalone assets; start uses the generated Node server. API_PROXY_TARGET is a server-only fixed rewrite target resolved at build time; production Nginx sends /api directly to .NET. The browser always calls the same origin.

## Local Docker alternative
For MySQL Workbench inspection of the existing auth-review database, see [local Workbench setup](docs/LOCAL_MYSQL_WORKBENCH.md). Its optional override enables localhost port 3307 and a separate read-only account; the base Compose files retain their original defaults.

```powershell
docker compose -p conex360-foundation -f infrastructure/compose.yaml up --build -d --wait --wait-timeout 60
.\scripts\Test-Foundation.ps1
```
Open http://127.0.0.1:3600. Stop an existing host frontend first, or set CONEX360_HTTP_PORT to another free port in this shell. Only the proxy is published, on loopback; API/frontend remain on the project network. This original foundation Compose file has no MySQL/migration hook; the separately approved P1-02 auth-review file is described in docs/19.
```powershell
docker compose -p conex360-foundation -f infrastructure/compose.yaml stop
```
Always name this project/file. Do not stop/prune unrelated projects. This is local HTTP smoke configuration, not a production TLS/secrets deployment.

## Development checks
```powershell
dotnet format backend/Conex360.sln --verify-no-changes --no-restore
dotnet build backend/Conex360.sln --no-restore -c Release
dotnet test backend/Conex360.sln --no-build -c Release
```
In frontend with the pinned Node shell:
```powershell
npm run format:check
npm run lint
npm run typecheck
npm test
npm run build
npx playwright install chromium
npm run test:e2e
```
Browser tests start/stop their own built frontend and Release API on 3600/5180; keep those ports free. They do not reuse other servers or touch MySQL. Reports/screenshots live in ignored artifacts/test directories. The GitHub workflow runs these checks when committed/pushed; no commit, push or deployment was performed by this task.

## Phase 1
Authentication/sessions; isolated tenants with one automatic default company; Administrator/Staff; business branding; outlets/warehouses; products/categories/SKUs/UOM/barcodes/basic prices; suppliers/customers; opening/incoming stock; batches/expiry; reservations/transfers/transit/partial receipt; adjustments/waste/counts; basic actual-input/output manufacturing; online POS/receipts/manual payments/returns; operational dashboards/audit/backups.

Stock and operational cost/payment records are accurate transactions. They do not require double-entry accounting. No general ledger, journals, financial periods, tax engine, WIP accounting, advanced QC, offline billing, subscriptions, HR/loyalty or complex integrations are Phase 1 dependencies.

## Documentation map
| File | Purpose |
|---|---|
| AGENTS.md / CODEX_START_HERE.md | Current agent rules and approval gate |
| docs/00_PROJECT_OVERVIEW.md | Scope, hierarchy and terms |
| docs/01_REQUIREMENTS.md | Phase 1 requirements and acceptance outcomes |
| docs/02_ARCHITECTURE.md | Lightweight modular monolith and proposed tree |
| docs/03_DATABASE_DESIGN.md | Proposed 38-table operational schema and relationships |
| docs/04_INVENTORY_AND_TRANSFERS.md | Stock, operational cost, transfer and count invariants |
| docs/05_BUSINESS_WORKFLOWS.md | Incoming stock, manufacture, checkout, payments, returns |
| docs/06_API_CONTRACTS.md | Proposed scoped APIs and exact-value conventions |
| docs/07_SECURITY_AND_TENANCY.md | Authentication, two roles, scope and files/cache |
| docs/08_FRONTEND_AND_UX.md | Practical screens and device limitations |
| docs/09_ENGINEERING_STANDARDS.md | Coding, Git, CI and done criteria |
| docs/10_TEST_AND_ACCEPTANCE.md | Real MySQL, browser and recovery gates |
| docs/11_DEPLOYMENT_AND_OPERATIONS.md | VPS, secrets, release and restore |
| docs/12_DECISION_LOG.md | Confirmed scope, proposals and open choices |
| docs/13_ROADMAP.md | Owner-requested ten-stage sequence |
| docs/14_PHASE1_IMPLEMENTATION_PLAN.md | Reviewable slices, dependencies and approvals |
| docs/15_PHASE1_SCHEMA_MAPPING.md | Every historical table disposition and design differences |
| docs/16_ENVIRONMENT_READINESS.md | Actual local checks and minimum next steps |
| docs/17_FUTURE_PRODUCT.md | Deferred product opportunities |
| docs/18_FOUNDATION_IMPLEMENTATION.md | Foundation files, pins, commands, results and remaining gates |
| docs/19_AUTH_BUSINESS_IMPLEMENTATION.md | P1-02 functionality, endpoints, security decisions, actual evidence and local onboarding |
| docs/20_CUSTOMER_DISPLAY.md | Mandatory P1-08 same-computer dual-screen requirements, protocol and acceptance |
| docs/21_P1_02_DATABASE_REVIEW.md | Concrete seven-table SQL, isolated execution approval and safeguards |
| database/README.md | Phase 1 migration boundary and historical warning |
| docs/reference/enterprise_baseline_2026-11-24/README.md | Hash-verified snapshot of the superseded knowledge pack |
| docs/reference/*2026-11-23.md / SCHEMA_INDEX.md | Original historical design texts/index |
| database/reference/01_schema.sql | Unchanged 160-table historical SQL |

## Precedence and preservation
Current user instructions take precedence, followed by current root guidance and Phase 1 specifications. A proposal is not an approved decision. Historical requirements remain available for future expansion; they do not impose current functionality.
The 24 November guidance was archived before this revision. The original SQL remains unchanged (SHA-256: 1810fe5af34702fa8b475aa1cbe3cb16f87b0e00a8b3d9f6361ce2fcc0f3fd32). The historical missing companion scripts are not a Phase 1 prerequisite; Phase 1 requires its own reviewed safeguards and reference setup.

Foundation evidence is historical; P1-02 database/auth/business evidence is recorded separately in docs/19_AUTH_BUSINESS_IMPLEMENTATION.md. No inventory, production deployment, hardware integration or full backup restore is claimed. Historical SQL and archived references remain unchanged. Authenticated local review instructions use separate ports 3602/5182 and the isolated review project; the original no-database foundation mode above remains available.
