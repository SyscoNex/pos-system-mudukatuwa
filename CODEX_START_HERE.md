# Conex360 — continue from the foundation

Current authority: P1-02 accepted; P1-03a/b code and isolated 0003–0005 execution approved on 28 November 2026. Read docs/21_OUTLETS_WAREHOUSES_USERS_IMPLEMENTATION.md and docs/22_P1_03_DATABASE_REVIEW.md. Stop before P1-04. Do not touch SchoolGrid project database or alter original migrations/references.

P1-03 extends the accepted foundation/authentication without regeneration. Database execution covers reviewed 0000–0005 only in the existing review and separate clean-test projects. No production or unrelated Docker changes, commit/push/merge or destructive reset.

## Current starting point
Read AGENTS.md, README.md, docs/12_DECISION_LOG.md, docs/14_PHASE1_IMPLEMENTATION_PLAN.md and docs/18_FOUNDATION_IMPLEMENTATION.md. The report distinguishes actual checks from future acceptance requirements.
The foundation is retained. P1-02 adds focused Identity services/SQL adapters, secure cookie sessions, controlled onboarding, business profile/private logos and protected frontend routes. Read docs/19_AUTH_BUSINESS_IMPLEMENTATION.md for actual validation and limits, docs/21_P1_02_DATABASE_REVIEW.md for SQL review and docs/20_CUSTOMER_DISPLAY.md for the mandatory P1-08 dual-monitor display specification. No POS/customer-display operational code is authorized during P1-02.
Use the pinned SDK/Node/dependencies and one npm lockfile. The Windows Node helper changes only the current shell and stores its runtime in ignored .tools. No global Node upgrade is required.

## Next session after P1-03 review
P1-04 Products, Units, Prices and Suppliers requires owner authorization and a separate review of its migration package before execution. The 38-table baseline remains a starting design, not permission to scaffold later modules. Preserve the implemented outlet grants, canonical transit and existing authentication/branding.
No historical enterprise bootstrap, fake journal/period rows, automatic startup migration, generic CRUD generator, production access or later module implementation. Existing Docker projects must not be stopped or reconfigured.

## Required evidence
Small working flow, tests and actual commands/results. Tenant/company/branch authorization must precede business CRUD; real MySQL tests precede any inventory posting. No accounting/offline/advanced-module dependency.
No commit/push/deploy unless asked. Preserve historical SQL/archive hashes and update current progress without claiming future functionality is implemented.
