# Phase 1 inventory, transfers and operational costs
**Approved Phase 1 stock/cost direction; detailed business policies still need validation with the dependent slice.** Inventory can post independently of financial accounting. No journal, chart of accounts or financial-period dependency exists. No inventory code is implemented in P1-01.

## Stock and eligibility
A lot belongs to one item; a bucket is lot + location + AVAILABLE/HOLD/DAMAGED condition. All stock is company-owned initially. SYSTEM lots support untracked items; expiring/batch items require actual lots and applicable dates.
For each bucket: on_hand = SUM(signed posted quantity); carried value = SUM(signed value_delta). A locked balance projects both. Reservation remaining = original - consumed - released for active rows. Available = eligible ordinary-storage on-hand minus outstanding reservations. Transit/held/damaged/blocked/expired stock has zero ordinary availability. Offline allocations do not exist.
Show storage on-hand, reserved, available, held/damaged and transit separately; no double-counting or clamping negative differences. POS and manufacturing use their authorized selected warehouse, never pooled company stock.
FEFO chooses eligible earliest expiry, then deterministic lot/bucket IDs; nonexpiring lots follow an agreed tie-break. Propose expiry date inclusive (unusable when local business date is later than expiry); approve before release. A blocked lot is checked on every issue. Admin can post explicit disposal/return of ineligible goods, not sell it through an override.

## Approved minimal operational cost direction
Retain original entered purchase/base unit cost and immutable carried value on entries. No financial FIFO, COGS, cost-layer engine, WIP or ledger accounts.
- Incoming/opening: quantity times explicit base unit cost, rounded to six-place value under the approved mode. Zero cost is explicit and audited, never the fallback for missing cost.
- Ordinary issue: lock bucket quantity/value; issue value = round(current value * issued quantity / current quantity, 6). A complete depletion carries the exact remaining value. This gives a per-bucket moving-average cost, with deterministic residuals.
- Transfers and condition moves: paired entries have exactly equal opposite quantity/value. Dispatch allocation owns the carried amount. Partial receipts/resolutions consume the allocation's remaining value proportionally; the final consumption takes its exact residual. Never recalculate from a pooled transit average or destination selling price.
- Destination receives carried cost; a pre-existing bucket blends remaining quantity/value. A later ordinary issue uses its current average.
- Sales returns restore original issue-allocation cost, with cumulative quantity/value bounds and final residual. Return into held/damaged storage unless Admin explicitly accepts sellable disposition.
- Manufacture: one atomic completed run consumes actual input/packaging allocations and carries their total value to one finished item/output lot. Normal yield loss is represented by actual input versus good output; the chosen simple policy absorbs all run input value into output. Separately discarded stock uses a WASTE document. Confirm waste treatment; do not imply abnormal-loss accounting.
- No late supplier-invoice revaluation or historic average recalculation initially. Incorrect costs need reviewed linked corrections considering downstream use, not edits to old entries.
Current carried value is an operational stock estimate, not audited inventory valuation. Margin estimates, if later shown, must be labelled accordingly. Input/output quantities of different UOM dimensions are never summed as a false yield metric.

## Transfer workflow
A request identifies same-company, distinct ordinary source/destination warehouses and positive item/base quantities. Admin or Staff with destination grant may request; source Staff can see only the necessary counterpart/manifest. Confirming request may atomically reserve selected source buckets under locks; propose source-authorized confirmation, no approval chain. A destination requester cannot reserve source stock without source authority; source confirmation reserves it.
Posted REQUEST facts are immutable. Each DISPATCH references request lines and one or more exact bucket allocations; RECEIPT references exact dispatch allocations. RESOLUTION records authorized loss/return; CANCEL records only undisbursed remainder and releases its unconsumed reservations. UI progress is derived.

| Event | Quantity/value effect |
|---|---|
| Reserve | Physical quantity/value unchanged; source availability reduced |
| Dispatch | Source issue and equal receipt into hidden company transit location; consume its reservation once |
| Receive | Issue only referenced dispatch transit and receive equal actual quantity/value into destination |
| Damage | Receipt into destination HOLD/DAMAGED, preserving actual lot and carried amount |
| Missing goods | Remain in transit until counted receipt or authorized resolution |
| Loss | Admin posts referenced transit issue and reason; no destination stock and no journal |
| Return to source | Admin posts transit issue + original-source receipt, preserving cost/lot |
| Cancel remainder | Linked cancellation, bounded by undisbursed request quantity; release only its own remaining reservations |

A dispatch can contain many lots; one request can have multiple dispatches and each dispatch multiple receipts. Allocation facts bind request/dispatch line, source/transit entries, lot through bucket, quantity and carried value. Receipt/resolution facts bind allocation and their paired entries. Lock the original allocation before summing all committed receipts/resolutions. Totals cannot exceed either dispatched quantity or value; remaining exactly reconciles to tagged transit. No expiry timers close allocations.
Destination changes, substitutions, over-receipts, same-warehouse ordinary transfers and cross-tenant/company links are rejected. Investigate unexplained extra goods separately; Admin can create a separate evidenced incoming/adjustment document, never enlarge a dispatch.
Source Staff dispatch and destination Staff receive only with their own outlet grants. Admin may perform both for a two-person business; no mandatory second approver. Transit has no ordinary edit/receive/sale endpoint. Partial downstream receipt/consumption prevents blind dispatch reversal.

## Required numerical scenario
| Step | Factory storage | Outlet storage | Transit | Total quantity |
|---|---:|---:|---:|---:|
| Opening | 100 | 20 | 0 | 120 |
| Reserve 30 | 100 (70 available) | 20 | 0 | 120 |
| Dispatch 30 | 70 | 20 | 30 | 120 |
| Receive 20 | 70 | 40 | 10 | 120 |
| Receive 8 | 70 | 48 | 2 | 120 |
| Authorized loss 2 | 70 | 48 | 0 | 118 |

With source unit cost 2, dispatch carries 60; receipts carry 40 and 16; loss carries 4. Destination's existing cost may differ: total value is unchanged through each transfer/receipt and decreases only by the evidenced loss of 4. Damage receipts change availability, not total quantity/value.

## Opening, adjustment, waste and count
Opening is an Admin-posted document per warehouse/lot with explicit quantities/costs. It cannot overwrite existing balances; correction requires linked effects.
Positive adjustment needs an identified lot and explicit cost; negative adjustment/waste must respect reservations/eligibility and carries actual bucket value. Release/reassign affected reservations explicitly before a decrease below reserved quantity; never silently take another transfer's reserved stock.
Propose a short logical warehouse freeze for counts: begin under warehouse lock, verify no competing count and save exact bucket quantity/value snapshots, then commit. Do not hold a DB transaction while people count. Every stock/reservation-changing command locks participating warehouses and rejects a COUNTING warehouse. In-flight posting either commits before snapshot or waits and fails after freeze.
Transit is reconciled through allocations, not physical warehouse counts. Staff may prepare counts; Admin finalizes under locks, validates new/positive variance costs, writes nonzero variance document lines/entries once and unfreezes. Completion/cancellation of that active count is the explicit exception to its own freeze. Zero variance has no movement. Cancel with audit and unfreeze. Previously unknown goods/lots need identified evidence and explicit cost before acceptance.

If the counted quantity is below outstanding reservations, completion rejects with the affected request references. Initially cancel the count, explicitly resolve/release the reservation through its own workflow and restart the count; never silently release reservations inside a variance or leave the warehouse permanently frozen.

## Common command transaction and concurrency
Authenticate and validate DTO/active membership; use canonical hash and actor/command idempotency key. Proposed lock hierarchy for every handler: membership/security state as needed; idempotency; existing/new root and source documents in ID order plus applicable document sequence; participating warehouses in ID order; lots in ID order; dispatch allocations/source return/payment records in stable IDs; bucket balances in canonical key order; their reservations. Finalize the hierarchy before SQL and test all cross-command combinations. Create missing bucket/balance rows under unique keys, then lock/recheck.
Recheck status/version, grants, freeze, quantities, original caps, expiry/blocked state and costs under locks. Append document/lines/entries/allocation evidence, update projections/reservations, record applicable manual payment facts, audit and idempotent result, mark new root POSTED, commit. No general ledger call. Failure rolls back everything.
Recognized deadlock/lock timeout may retry the whole command with bounded jitter; unknown commit outcome is resolved by idempotency, not a new command key. A changed payload on an existing key conflicts. Keep durable operation identities after HTTP response loss.

## Acceptance essentials
Real MySQL tests: concurrent last-unit sale/dispatch, reservation/adjustment contention, concurrent partial receipts/returns, multi-lot same-SKU shipments sharing transit, exact carried-value residuals, duplicate and altered replay, wrong scope/stage/destination/lot, count freeze races, and injected failure before commit.
Reconcile quantities, values, reservations and allocation transit after every scenario. Tenant/company/grants must reject before disclosing costs or creating effects. Rebuild projections only as a reviewed recovery procedure, not routine direct editing.
