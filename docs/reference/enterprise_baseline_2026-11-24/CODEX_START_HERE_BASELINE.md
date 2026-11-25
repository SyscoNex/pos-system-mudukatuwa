# First Codex session
Open the cloned repository root in VS Code, with AGENTS.md and docs/ present. Send the prompt below. Review its plan before asking for implementation.

```text
Read AGENTS.md, README.md, docs/00_PROJECT_OVERVIEW.md, docs/02_ARCHITECTURE.md,
docs/03_DATABASE_DESIGN.md, docs/04_INVENTORY_AND_TRANSFERS.md,
docs/12_DECISION_LOG.md, docs/13_ROADMAP.md and database/README.md.
Inspect the existing repository and local tools. We are building Conex360 for
SysConex as a commercial multi-tenant business management and POS platform.
Do not write application code, initialize a database or install packages yet.
First give me a phased M0/M1 implementation plan, proposed project tree,
version compatibility checks (Next.js, React, Node LTS, TypeScript, .NET and MySQL), schema gaps (including missing guards and seeds),
security boundary, migration strategy, tests and explicit open decisions.
Use Next.js with TypeScript, not Angular or React/Vite. Plan an App Router
frontend, a Node runtime container and a same-origin .NET API; do not duplicate
backend business logic or access MySQL from Next.js. Review tenant-safe caching,
authentication and offline device boundaries.
Preserve the historical schema; validate actual table names before proposing changes.
Inventory at each outlet and same-company transfers including dispatch, transit,
partial receiving and reconciliation are mandatory. Show how these will be tested.
Stop after the plan for my review.
```

After reviewing, ask Codex: `Implement only the approved M0 scaffold. No production access. Run local validation and report commands/results. Leave later modules unimplemented and feature-gated.`

Use one feature branch and one narrow task at a time. A suggested second task is the M1 tenant/company/branch authorization slice with two-tenant integration tests, not checkout or a 160-table CRUD generator.
