# Conex360 — continue from the foundation
The owner accepted P1-01 and authorized P1-02a/b/c on 28 November 2026. The separate database gate was approved for only the isolated conex360-auth-review target and synthetic tests, migrations 0000–0002. Stop after P1-02 for owner review before P1-03. No production or unrelated Docker changes, commit/push/merge or destructive reset.

## Current starting point
Read AGENTS.md, README.md, docs/12_DECISION_LOG.md, docs/14_PHASE1_IMPLEMENTATION_PLAN.md and docs/18_FOUNDATION_IMPLEMENTATION.md. The report distinguishes actual checks from future acceptance requirements.
The foundation is retained. P1-02 adds focused Identity services/SQL adapters, secure cookie sessions, controlled onboarding, business profile/private logos and protected frontend routes. Read docs/19_AUTH_BUSINESS_IMPLEMENTATION.md for actual validation and limits, docs/21_P1_02_DATABASE_REVIEW.md for SQL review and docs/20_CUSTOMER_DISPLAY.md for the mandatory P1-08 dual-monitor display specification. No POS/customer-display operational code is authorized during P1-02.
Use the pinned SDK/Node/dependencies and one npm lockfile. The Windows Node helper changes only the current shell and stores its runtime in ignored .tools. No global Node upgrade is required.

## Next session after foundation approval
Implement only the explicitly authorized P1-02 slice: controlled business/default-company setup, secure cookie sessions and tenant isolation, followed by business profile. First review concrete slice DDL/safeguards and an isolated execution target. The 38-table starting baseline is not a fixed restriction; propose additional tables only for actual justified requirements.
No historical enterprise bootstrap, fake journal/period rows, automatic startup migration, generic CRUD generator, production access or later module implementation. Existing Docker projects must not be stopped or reconfigured.

## Required evidence
Small working flow, tests and actual commands/results. Tenant/company/branch authorization must precede business CRUD; real MySQL tests precede any inventory posting. No accounting/offline/advanced-module dependency.
No commit/push/deploy unless asked. Preserve historical SQL/archive hashes and update current progress without claiming future functionality is implemented.
