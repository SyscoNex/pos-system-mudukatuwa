# Decision log / unresolved inputs
Status: Confirmed = user-established; Baseline = prior design direction retained; Proposed = recommendation for review; Open = decision required before dependent work. Dates refer to planning, not release dates.

| ID | Status | Decision / rationale |
|---|---|---|
| D01 | Confirmed | Product name Conex360; SysConex parent company. Customer business name/logo configurable. |
| D02 | Confirmed | Shared multi-business platform with each business isolated; .NET, MySQL and VPS hosting. |
| D03 | Confirmed | First customer coconut manufacturing/business; support products/ingredients/packaging, batches, expiry, weighing, multiple locations and offline billing. |
| D04 | Confirmed | Businesses manage their outlet inventories and transfer their own goods/products between outlets. |
| D05 | Baseline | Tenant → companies → branches → warehouses → locations; outlet is STORE branch. Ordinary transfer only within same legal company. |
| D06 | Baseline | .NET 10 LTS modular monolith, MySQL 8.4/InnoDB; explicit MySqlConnector posting; frontend framework superseded by D19. |
| D07 | Baseline | Append-only stock entries, locked balances, FIFO valuation and independent FEFO/lot trace, double-entry accounting, offline quota/outbox. |
| D08 | Proposed | Docker Compose, Ubuntu LTS, Nginx, private GitHub repo and GitHub Actions; branch/release workflow to review. |
| D09 | Proposed | Transfer request/dispatch/receipt with allocation linkage, transit and exceptions; review historical schema gaps via ADR and migration before coding. |
| D10 | Proposed | Pilot VPS 4 vCPU/8 GB; offsite backups RPO <=15 min/RTO <=4 h pending benchmarks/restore test. |
| D11 | Proposed | Tagline Your Entire Business. Connected.; blue branding draft; no trademark/domain validation. |
| D12 | Open | Recover historical guard/seed/reconciliation SQL or design replacements and validate them. |
| D13 | Open | Exact Next.js/React/Node/TypeScript and SDK/DB patch versions, authentication provider/session, ORM compatibility, API paths and CI branch policy. |
| D14 | Open | Client outlets, warehouse layout, user roles, approval thresholds, SKU/UOM/recipes, expiry policy, costing pools/transfer origin ordering and opening data. |
| D15 | Open | Tax, currency rounding, invoice requirements, accounting mappings, fiscal periods, payroll/local legal compliance; get accountant/client approval. |
| D16 | Open | Printer/scanner/scale models, offline OS and encryption/key storage, permitted offline payments, receipt numbering and conflict policy. |
| D17 | Open | Hosting provider/domain/DNS, expected load, backup retention and recovery SLA, support and subscription pricing/entitlements. |
| D18 | Open | Exact signed client scope, rollout, priorities and delivery dates; advanced modules not automatically promised. |
| D19 | Confirmed | 24 Nov 2026: Next.js with TypeScript selected as frontend by product owner, replacing Angular/earlier React/Vite proposals. .NET and MySQL remain unchanged. |
| D20 | Proposed | Next.js App Router, Node runtime on existing VPS, same-origin Nginx /api routing, feature-based UI; confirm session architecture and supported versions at M0. |

## ADR template
Create `docs/adr/NNNN-short-title.md` with status, date, context, alternatives, decision, consequences, migration/security/stock/accounting impact, tests, owner approval and superseded ADR. Record changes before implementing deviations. Update this index when decisions are approved. Do not silently convert proposals to confirmed decisions.
