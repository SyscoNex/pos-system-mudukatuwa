# P1-04 database execution review — 28 November 2026

Owner separately approved this exact package and both isolated targets on 28 November 2026. Migrations 0006–0007 applied successfully to conex360-auth-review; a clean 0000–0007 installation also succeeded in conex360-p104-clean. The clean target's first connection attempt failed before any SQL, confirmed empty before retry. Runtime grant scripts applied in sequence. Further SQL/targets remain gated; results and commands: docs/23_CATALOG_SUPPLIERS_IMPLEMENTATION.md.

Exact package: database/migrations/0006_catalog_suppliers.sql (six scoped tables) and 0007_catalog_guards.sql (immutable ownership/identity and no-delete guards). Runtime change: infrastructure/mysql/grant-catalog.sh, SELECT/INSERT/UPDATE only on those six tables. Existing migrations/checksums, runtime journal restrictions, audit and Workbench read-only grants remain unchanged. No stock, document, lot or sales/manufacturing tables.

units has company-normalized codes, dimension and discrete-quantity flag; category parent uses a scoped self-FK, with cycles rejected under company serialization. items has SKU/type/independent operation flags/base UOM/tracking/expiry. Expiry implies LOT. Base UOM is deliberately immutable after creation (a conservative identity restriction before inventory); correcting it requires a new SKU, avoiding unsafe implicit rebasing. Unit dimension/discrete semantics cannot change once referenced.

item_units uses DECIMAL(24,9) factors and nullable DECIMAL(24,6) prices; NULL is unset, zero is explicitly free. A composite item/base FK and CHECK enforce factor one for the base row. Generated unique keys permit at most one active purchase/sale default. Aggregate commands require an active base row and exactly one permitted default for each enabled operation, so minimum-count invariants are transactional application rules. Existing item-unit identity/ownership is immutable; edits/deactivation retain history. Parent and child versions prevent stale prices/conversions. Future documents must snapshot all applicable values.

item_barcodes has an exact, no-padding binary collation; leading zeros retained. Its scoped item/unit FK prevents ambiguous mappings. Codes remain reserved while inactive. parties supports supplier/customer flags, but only supplier management is exposed now.

Product-specific COUNT packaging factors may explicitly relate count packages to the product base measure. Direct MASS/VOLUME cross-dimension conversions are rejected; no density assumption or automatic pack quantity. Exact conversion uses scaled integer arithmetic, rejects excessive precision/overflow, and respects discrete input/base quantities.

Prices are denominated in the company's single currency. First explicit price (including zero) sets the existing companies.currency_locked_at latch, audited in the same transaction; this prevents silent currency reinterpretation. Staff responses use an explicit allowlist and omit purchase-price fields entirely.

No mandatory seed or invented product/supplier data. Optional idempotent default-UOM setup creates only standard unit definitions after an Administrator action, never client packaging factors. Deactivation rejects active dependencies rather than cascading product meanings; inactive child/barcode history is retained. Future inventory usage checks must be implemented with actual transaction tables, and cannot be inferred now.

Upgrade target: existing conex360-auth-review / conex360_auth_review, retaining its volume/data and Workbench localhost 3307 using both Compose files. Clean-install verification: new private conex360-p104-clean project/volume, same database name within its isolated network, no published DB port, migrations 0000–0007, synthetic fixtures only. SchoolGrid/production/other projects excluded.

Use the existing explicit migration runner, expected target assertion, checksums, named lock and migration identity. DDL auto-commits: stop and inspect partial failures, never DROP/reset or disable FKs. Runtime never migrates. Approval requested for this package, scoped grants, isolated upgrade, clean installation and focused synthetic real-MySQL tests.
