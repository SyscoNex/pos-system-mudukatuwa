# Phase 1 architecture
P1-01 now contains the four backend projects, Next.js App Router shell, process-health API and isolated local runtime configuration. Domain/Application/Infrastructure intentionally contain no business services or database adapter yet. See [foundation evidence](18_FOUNDATION_IMPLEMENTATION.md).
The agreed stack is ASP.NET Core/.NET 10 LTS, Next.js/TypeScript, MySQL 8.4/InnoDB, a modular monolith, GitHub and Linux VPS deployment. Docker/Compose are appropriate for local MySQL and repeatable hosting.

## Small runtime
Browser -> HTTPS reverse proxy -> Next.js pages/assets or /api/* -> .NET API -> MySQL.
The API also serves authorized branding files from private storage. Backups copy database/files/key material to encrypted off-host storage using operational tooling.
No Worker project, durable outbox/inbox, broker, distributed service, offline device service, Redis, replica or generic job platform is needed initially. Reports are bounded synchronous reads; add a background export only when a concrete requirement justifies it.

## Project layout (foundation generated; later folders added only as needed)
```text
backend/
  Conex360.sln
  src/
    Conex360.Domain/          # exact math and business invariants
    Conex360.Application/     # focused use cases and transaction coordination
    Conex360.Infrastructure/  # MySqlConnector, auth session store, files
    Conex360.Api/             # HTTP/auth composition, DTOs, OpenAPI
  tests/
    Conex360.UnitTests/
    Conex360.IntegrationTests/
frontend/
  src/app/                   # shell; feature routes added per slice
  src/features/
  src/lib/api/
  src/components/
  tests/
database/reference/          # untouched enterprise reference
database/migrations/         # approved Phase 1 scripts added by slice
database/reconciliation/     # operational diagnostics as needed
infrastructure/              # Docker/Compose/proxy and short runbooks
docs/
.github/workflows/
```

Domain depends on no infrastructure. Application uses Domain and only necessary interfaces; Infrastructure implements SQL/storage adapters; API composes them. Prefer direct use-case services and focused queries over mediator/CQRS frameworks, generic repositories or projects per module.

## Modules
| Module | Responsibility |
|---|---|
| Identity/Business | users, membership roles, sessions, default company, outlets/grants, profile |
| Catalog/Contacts | products/UOM/prices/barcodes, suppliers/customers |
| Inventory | lots, immutable movements, locked balances, reservations, costs, transfers/counts/waste |
| Manufacturing | validate and coordinate actual input/output run through Inventory |
| Sales | price snapshots, online checkout, operational payments, linked returns/receipts |
| Reporting/Audit | authorized committed-data reads and immutable evidence |

Inventory is the only stock writer. Application use cases share one connection/transaction for documents, Inventory, relevant manual payment records, audit and idempotency. No Finance module or journal/period validation is required in Phase 1. No waiting for printer/customer/network service inside a DB transaction.

## Web/auth boundary
Approved direction is .NET cookie authentication with server-revocable sessions, ASP.NET Core password hashing/Data Protection and static Administrator/Staff policies; implementation starts only after foundation review. Prefer browser-to-/api requests for protected feature data, avoiding an unnecessary BFF/session authority in Next.js.
Public shell/assets may be cached; private API/HTML/RSC payloads may not. Any server-side API read forwards only the current user's required cookie/context to an internal allowlisted API address, never a privileged service credential.
Nginx reserves /api for .NET and routes pages/assets to the Node production runtime. Test exact path/forwarded HTTPS behavior and cookie CSRF controls.

Use MySqlConnector parameterized SQL for stock commands. Do not add EF/provider dependencies solely for scaffolding. Pin compatible SDK/runtime/Node/Next/React/TypeScript/package manager/images after verification. See the environment report.
