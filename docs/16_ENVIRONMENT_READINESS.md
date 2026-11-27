# Current foundation environment — 25 November 2026

## P1-02 recheck — 28 November 2026
SDK 10.0.404/runtime 10.0.15, workspace Node 26.13.1/npm 11.20.0 and all foundation dependency pins retained. Machine Node 22.9.0 unchanged. Docker Linux engine available; original foundation containers remained running. New isolated conex360-auth-review uses MySQL 8.4.13.1 by digest, no published SQL port, separate volumes/secrets, review HTTP 3602/API 5182. MySqlConnector 3.0.0 and SkiaSharp/native 4.158.0 added only for real P1-02 requirements. Owner approved reviewed migrations 0000–0002 and synthetic tests; production/other databases remain excluded. Actual commands/results and runbook: [docs/19](19_AUTH_BUSINESS_IMPLEMENTATION.md). Tables below describe the earlier foundation observation, not current absence of database work.
This current recheck supersedes the earlier planning snapshot preserved below.

| Component | Current foundation result |
|---|---|
| .NET | Installed SDK 10.0.404 / ASP.NET runtime 10.0.15; SDK pinned in global.json |
| Machine Node/npm | Still 22.9.0 / 10.8.3; not upgraded or reconfigured globally |
| Workspace Node/npm | Official checksum-verified 26.13.1 LTS / bundled npm 11.20.0 under ignored .tools; helper affects only its shell |
| Frontend | Next 16.4.6, React/DOM 19.3.1, TypeScript 6.0.3, ESLint 10.15.0 with compatible plugins; locked dependencies |
| Docker | Client/engine 29.8.2, Docker Desktop 4.94.0, Compose 5.5.1; Linux engine is now available |
| Running projects at initial implementation check | docker ps returned no running containers; all task commands use conex360-foundation project, no global stop/prune/reset |
| MySQL | Not installed/initialized/connected by this milestone; no Docker DB service/volume or migration |

Independent backend/frontend builds and tests are implemented and passing. Image/production-proxy evidence, exact commands and remaining gates are recorded in [the foundation report](18_FOUNDATION_IMPLEMENTATION.md). No Docker engine setting was changed by this task. Git branch is feature/p1-01-foundation; no commit/push/deploy.
The smallest environment action for another Windows shell is dot-sourcing scripts/Use-LocalNode.ps1 (with -Install only for its first verified download). No further .NET major install, external identity service or host MySQL install is required for the foundation.

---

## Earlier documentation-only snapshot (historical observations)
# Local environment readiness
**Observed 25 November 2026, Asia/Colombo. Read-only inspection; no installations or database execution.**
Repository: C:/Sysconex/Conex360/pos-system-mudukatuwa (Git root inside the workspace).

| Tool/check | Actual result | Minimum next action after approval |
|---|---|---|
| dotnet --info | SDKs 10.0.404 and 9.0.311; host/ASP.NET Core/.NET runtime 10.0.15 available | .NET 10 major is ready; select/pin SDK in global.json and packages/images, then build the actual scaffold |
| node --version | v22.9.0 | Select a current supported patched Node LTS and verify the full Next/React/TypeScript/build tool matrix; this old patch should not be the new production pin |
| npm --version | 10.8.3 | Select a compatible npm version, one lockfile and reproducible clean install; no pnpm/yarn installation needed |
| docker version | Client 29.8.2; desktop-linux context; server failed: DockerDesktopLinuxEngine named pipe absent | Make Docker Desktop Linux engine available and verify server; do not initialize MySQL or a volume yet |
| docker compose version | v5.5.1 | Compose CLI exists; actual container support depends on working engine |
| mysql command lookup | Not available on PATH | Host MySQL installation unnecessary if approved isolated MySQL 8.4 container supplies tools |
| git --version | 2.53.0.windows.2 | Git available; confirm existing repo/branch policy; no commit/push performed |
| Project manifests/lockfiles | No application projects/package manifests/global.json or CI currently implemented | Create only approved P1-01 scaffold after review |

The earlier 24 November assessment found .NET SDK 9 and Node 14; those observations are historical and are superseded by this recheck. No tool was upgraded by the documentation task.

## Compatibility evidence and exact pins
Official documentation reviewed on 25 November:
- [.NET support policy](https://dotnet.microsoft.com/en-us/platform/support/policy/dotnet-core): .NET 10 LTS remains supported; observed runtime 10.0.15 matches the listed supported release at review.
- [Next.js installation](https://nextjs.org/docs/app/getting-started/installation): documented minimum Node 20.9 and TypeScript 5.1; current docs show 16.x. Node 22.9 exceeds the minimum but minimum-version compliance does not establish patch security or complete dependency compatibility.
- [Node release schedule](https://github.com/nodejs/Release#release-schedule): Node 22 maintenance LTS ends April 2027; 24 maintenance LTS and 26 active LTS provide longer options. Choose a patched LTS based on supported Next/testing/native dependencies, not an unverified latest tag.
- [MySqlConnector compatibility](https://mysqlconnector.net/) and [version history](https://mysqlconnector.net/overview/version-history/): MySQL 8.4 and .NET 10 are supported directions; exact package/version behavior still needs real tests.

No Next.js/React/TypeScript/package-manager/database-image version is pinned or installed by this revision. Proposed P1-01 selection: supported stable Next.js with matching React peer versions, stable supported TypeScript and patched Node LTS, locked npm dependencies; supported .NET 10 SDK/runtime and MySQL 8.4 image. Verify actual package metadata/security releases and build/smoke before recording exact pins.

## Minimal prerequisite sequence
1. Owner approves revised plan and first slice.
2. Select/pin already available .NET 10 and supported frontend tools. Updating/selecting Node and npm may be necessary; no blanket OS/IDE reinstall or .NET major upgrade is needed.
3. Restore Docker engine availability if using container development/tests; alternatively propose an isolated MySQL 8.4 test service before choosing it. Do not substitute SQLite for inventory tests.
4. Create and verify approved minimal foundation. No standalone host MySQL, external IdP, cloud account, Redis, broker, Worker or payment service needed.
5. Later, obtain explicit Phase 1 migration/target execution approval before database initialization or real MySQL tests. Credentials must be synthetic/local and separate from runtime/migration roles.

Docker availability currently blocks container-backed MySQL concurrency/rollback validation and built-container smoke, not documentation review. Missing historical enterprise guard/seed scripts and future tax/accounting/offline decisions do not block this Phase 1 scaffold.

## Commands and limits
Ran Get-Content/rg/file inventory, git status --short --branch, dotnet --info, node --version, npm --version, docker version, docker compose version, command lookup for mysql, git --version, read-only Python SQL/name parsing and SHA-256 checks. Documentation writing/copying was the only filesystem mutation.
Docker server query failed as described; Compose version succeeded. No SQL connection, build, package restore/install, application/concurrency test, hardware test, deployment or backup restore was run. Exact version pins remain unvalidated proposals.

