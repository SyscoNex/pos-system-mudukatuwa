# Conex360 — continue from the foundation
The owner approved Phase 1 scope/design on 25 November 2026 and authorized only P1-01 Minimal Project Foundation. Application files and project-level dependencies are permitted for that milestone. Stop at its completion for review; do not begin authentication/business management automatically.

## Current starting point
Read AGENTS.md, README.md, docs/12_DECISION_LOG.md, docs/14_PHASE1_IMPLEMENTATION_PLAN.md and docs/18_FOUNDATION_IMPLEMENTATION.md. The report distinguishes actual checks from future acceptance requirements.
The foundation is a branded Next.js App Router shell and process-health .NET API with error/logging/JSON conventions, tests and isolated Docker configuration. Domain/Application/Infrastructure have no business services or database adapters yet.
Use the pinned SDK/Node/dependencies and one npm lockfile. The Windows Node helper changes only the current shell and stores its runtime in ignored .tools. No global Node upgrade is required.

## Next session after foundation approval
Implement only the explicitly authorized P1-02 slice: controlled business/default-company setup, secure cookie sessions and tenant isolation, followed by business profile. First review concrete slice DDL/safeguards and an isolated execution target. The 38-table starting baseline is not a fixed restriction; propose additional tables only for actual justified requirements.
No historical enterprise bootstrap, fake journal/period rows, automatic startup migration, generic CRUD generator, production access or later module implementation. Existing Docker projects must not be stopped or reconfigured.

## Required evidence
Small working flow, tests and actual commands/results. Tenant/company/branch authorization must precede business CRUD; real MySQL tests precede any inventory posting. No accounting/offline/advanced-module dependency.
No commit/push/deploy unless asked. Preserve historical SQL/archive hashes and update current progress without claiming future functionality is implemented.
