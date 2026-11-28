# Conex360 — continue from the foundation

P1-06 is accepted. P1-07 is complete with approved isolated 0012 execution and browser verification. Stop before P1-08 for owner review. [Handoff](docs/29_MANUFACTURING_IMPLEMENTATION.md) · [Migration review](docs/30_P1_07_DATABASE_REVIEW.md)

P1-05 is accepted. P1-06 schema 0011 and focused tests are verified under the isolated execution approval. Stop before P1-07 for owner review. [Handoff](docs/27_STOCK_OPERATIONS_IMPLEMENTATION.md) · [Database review](docs/28_P1_06_DATABASE_REVIEW.md)

P1-05 is complete and the approved review environment has posting enabled. Earlier milestone gates below are historical. Stop for owner review before P1-06. [Implementation and evidence](docs/25_INVENTORY_INCOMING_IMPLEMENTATION.md)

Current authority: P1-03 accepted; P1-04a/b/c code and isolated 0006–0007 execution approved on 28 November 2026. Read docs/23_CATALOG_SUPPLIERS_IMPLEMENTATION.md and docs/24_P1_04_DATABASE_REVIEW.md. Stop before P1-05. Do not touch SchoolGrid project database or alter original migrations/references.

P1-04 extends the accepted implementation without regeneration. Database execution covers reviewed 0000–0007 only in the existing review and approved private clean-test projects. No production or unrelated Docker changes, commit/push/merge or destructive reset.

## Current starting point
Read AGENTS.md, README.md, docs/12_DECISION_LOG.md, docs/14_PHASE1_IMPLEMENTATION_PLAN.md and docs/18_FOUNDATION_IMPLEMENTATION.md. The report distinguishes actual checks from future acceptance requirements.
The foundation is retained. P1-02 adds focused Identity services/SQL adapters, secure cookie sessions, controlled onboarding, business profile/private logos and protected frontend routes. Read docs/19_AUTH_BUSINESS_IMPLEMENTATION.md for actual validation and limits, docs/21_P1_02_DATABASE_REVIEW.md for SQL review and docs/20_CUSTOMER_DISPLAY.md for the mandatory P1-08 dual-monitor display specification. No POS/customer-display operational code is authorized during P1-02.
Use the pinned SDK/Node/dependencies and one npm lockfile. The Windows Node helper changes only the current shell and stores its runtime in ignored .tools. No global Node upgrade is required.

## Next session after P1-04 review
P1-05 Inventory and Incoming Stock requires owner authorization, final stock/cost/rounding rules and a separate review of its migration package before execution. The 38-table baseline remains a starting design, not permission to scaffold later modules. Preserve catalogue semantics, exact factors/prices, private Staff DTOs, outlet grants, canonical transit and existing authentication/branding. Base UOM is immutable from creation; the first configured price locks company currency. Actual receiving valuation and transaction snapshots remain P1-05/P1-08 work.
No historical enterprise bootstrap, fake journal/period rows, automatic startup migration, generic CRUD generator, production access or later module implementation. Existing Docker projects must not be stopped or reconfigured.

## Required evidence
Small working flow, tests and actual commands/results. Tenant/company/branch authorization must precede business CRUD; real MySQL tests precede any inventory posting. No accounting/offline/advanced-module dependency.
No commit/push/deploy unless asked. Preserve historical SQL/archive hashes and update current progress without claiming future functionality is implemented.
