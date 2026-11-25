# Phase 1 engineering standards
Professional quality means secure, understandable and tested working features. Do not substitute infrastructure volume for delivery.

## Design and code
Follow SOLID and separation of concerns pragmatically. Four backend projects and feature folders are sufficient. Small use-case services and focused parameterized queries; no mandatory mediator, generic repository/unit-of-work framework, event bus, Worker, outbox, microservices or future-module abstractions.
Domain rules are deterministic and independent of HTTP/SQL. Application owns transactions. Use DTO validation plus rechecks under locks, async I/O/cancellation, nullable reference types, explicit disposal and safe structured errors/logging.
C# decimal/MySQL DECIMAL/JSON strings; test exact UOM, rounding, residual and bounds. Stable lock order/whole-command retries. Inventory owns stock entries/projections; no arbitrary balance updates. Basic operational prices/payments/costs are independent of accounting.
TypeScript strict, no any by default, typed API contracts, server-authoritative totals, one lockfile and explicit lint/typecheck. Keep secrets server-only. Add libraries only for a current problem; verify versions/licenses/security before pinning.

## Git and CI
Propose protected main and short-lived feature/fix branches, small PRs and review before merge. No develop branch required initially. Do not commit/push/merge or configure production deployment without request.
CI starts with backend restore/build/analyzers/tests and frontend locked install/lint/typecheck/tests/build. Add real MySQL constraint/migration/concurrency/rollback checks when the first DB slice is approved. Add production-image/proxy smoke and dependency/secrets checks appropriate to release.
No production secrets on PR jobs. Pin reviewed tool/action/image versions; record artifact identity. Do not add a registry/deploy platform or scan service merely to satisfy a diagram. Never report skipped tests as passed.

## Definition of done per slice
A working authorized screen/API flow, requirements satisfied, focused tests including tenant/adverse cases, relevant stock/money invariants, reviewed schema/guard changes, docs/open decisions updated, actual commands/results and limitations recorded.
Posting changes require real MySQL replay/concurrency/rollback/reconciliation tests. Auth changes require scope/session/revocation/CSRF tests. Backup claims require restore evidence. Do not delay all testing until P1-10.
No accounting approval, journal or period gate is required for operational stock. Business cost/rounding/discount and correction policies still need explicit acceptance.
Migrations are dedicated reviewed operations, not API startup. No generic rollback deleting business facts; use compatible application rollback or reviewed compensating migration/correction.
