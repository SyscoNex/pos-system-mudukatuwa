# Conex360 — development knowledge pack
**SysConex | Working baseline v0.2 | 24 November 2026**

Conex360 is a cloud-based, multi-tenant POS and business management platform. One deployment serves independently subscribing businesses. The initial pilot is a coconut-product manufacturer with factories, stores, outlets, stock, production, batches and sales. This repository is intended to become the shared source of truth for humans and coding agents.

## Start here
1. Extract this ZIP directly into the root of your cloned private repository (do not leave `AGENTS.md` inside an extra folder). Preserve an existing README by merging it if needed.
2. Review `AGENTS.md`, `docs/00_PROJECT_OVERVIEW.md` and `docs/12_DECISION_LOG.md`.
3. Read `docs/01_REQUIREMENTS.md` and the module-specific documents before implementation.
4. Open the repository in VS Code and give Codex the prompt in `CODEX_START_HERE.md`.
5. Commit this documentation as the initial baseline; create a feature branch for implementation.

## Document map
| File | Purpose |
| --- | --- |
| AGENTS.md | Standing instructions for coding agents |
| CODEX_START_HERE.md | Initial Codex task and acceptance gates |
| docs/00_PROJECT_OVERVIEW.md | Product scope, tenant hierarchy, terminology |
| docs/01_REQUIREMENTS.md | Functional requirements with priority and acceptance criteria |
| docs/02_ARCHITECTURE.md | Stack, module ownership, application structure |
| docs/03_DATABASE_DESIGN.md | Schema conventions, mapping, migration readiness |
| docs/04_INVENTORY_AND_TRANSFERS.md | Mandatory outlet inventory, stock movement and transfers |
| docs/05_BUSINESS_WORKFLOWS.md | Purchasing, manufacturing, POS, finance and offline flows |
| docs/06_API_CONTRACTS.md | API conventions and initial route contracts |
| docs/07_SECURITY_AND_TENANCY.md | Authorization, threat controls and audit |
| docs/08_FRONTEND_AND_UX.md | Navigation, design conventions, device workflows |
| docs/09_ENGINEERING_STANDARDS.md | Code, Git, review, CI rules |
| docs/10_TEST_AND_ACCEPTANCE.md | Test matrix and release gates |
| docs/11_DEPLOYMENT_AND_OPERATIONS.md | VPS, environments, backups and incident runbooks |
| docs/12_DECISION_LOG.md | Confirmed, proposed and unresolved decisions |
| docs/13_ROADMAP.md | Ordered build backlog and milestone gates |
| docs/reference/ | Prior technical/client/database design text and generated table index |
| database/reference/01_schema.sql | Unmodified original MySQL schema, not an active migration |
| database/README.md | Database bootstrap prerequisites and missing companion files |

## Status and precedence
This is a planning and engineering baseline, not a working application or production deployment. User-confirmed decisions and the mandatory invariants in AGENTS.md take precedence. The confirmed frontend is Next.js + TypeScript (superseding earlier frontend proposals); the App Router and Node container approach are proposed implementation defaults. The inventory/transfer specification clarifies the older documents. Historical references are retained unchanged and do not override current decisions. The historical SQL is the reference for actual table/column names; if design and DDL disagree, record the gap, propose a migration and test it. No silent schema replacement. Proposed decisions require review before production release.

The prior guard, reference-seed and reconciliation scripts could not be retrieved; the schema alone is insufficient for safe posting. See database/README.md. No MySQL execution, application build, tax verification, hardware test or production performance validation has been performed for this pack.
