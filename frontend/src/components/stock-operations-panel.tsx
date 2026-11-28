"use client";

import Link from "next/link";
import {
  useCallback,
  useEffect,
  useRef,
  useState,
  type FormEvent,
} from "react";
import { api, ApiError, type Session } from "@/lib/api/identity";

export type StockMode = "transfers" | "adjustments" | "waste" | "counts";
type Warehouse = { id: string; name: string; version: string };
type TransferWarehouse = {
  id: string;
  name: string;
  outlet: string;
  authorized: boolean;
};
type Product = {
  id: string;
  sku: string;
  name: string;
  version: string;
  isActive: boolean;
  trackingMode: string;
  expiryRequired: boolean;
};
type ItemUnit = {
  id: string;
  unitId: string;
  version: string;
  isActive: boolean;
};
type ProductDetail = { product: Product; units: ItemUnit[] };
type Unit = { id: string; name: string };
type SourceRow = {
  id: string;
  itemId: string;
  sku: string;
  lot: string;
  condition: string;
  onHand: string;
  reserved: string;
};
type Transfer = {
  id: string;
  number: string;
  source: string;
  destination: string;
  reference?: string;
  confirmed: boolean;
  cancelled: boolean;
  sourceAccess: boolean;
  destinationAccess: boolean;
};
type Progress = {
  id: string;
  sku: string;
  unit: string;
  requested: string;
  reserved: string;
  dispatched: string;
  received: string;
  cancelled: string;
  lost: string;
  returned: string;
  inTransit: string;
};
type TransferDetail = {
  transfer: Transfer;
  lines: Progress[];
  reservations: { id: string; sku: string; lot: string; remaining: string }[];
  dispatches: {
    id: string;
    sku: string;
    lot: string;
    expiresOn?: string;
    outstanding: string;
    outstandingValue?: string;
  }[];
};
type Count = {
  id: string;
  number: string;
  warehouse: string;
  status: string;
  version: string;
};
type CountDetail = {
  count: Count;
  lines: {
    bucketId: string;
    sku: string;
    lot: string;
    unit: string;
    condition: string;
    expected: string;
    actual?: string;
    variance?: string;
    positiveUnitCost?: string;
  }[];
};
type Posted = { id: string; number: string };
const prefix = "/inventory/operations";
const issueModes = ["dispatch", "receive", "loss", "return"] as const;
type IssueMode = (typeof issueModes)[number];
const labels: Record<StockMode, string> = {
  transfers: "Stock transfers",
  adjustments: "Stock adjustments",
  waste: "Stock waste",
  counts: "Stock takes",
};
const describe = (e: unknown) =>
  e instanceof Error ? e.message : "The request failed.";
const field = (data: FormData, name: string) =>
  String(data.get(name) ?? "").trim();

function Disposition({ name = "condition" }: { name?: string }) {
  return (
    <select
      name={name}
      aria-label={name === "condition" ? "Condition" : undefined}
      defaultValue="AVAILABLE"
    >
      <option value="AVAILABLE">Accepted</option>
      <option value="HOLD">Hold</option>
      <option value="DAMAGED">Damaged</option>
    </select>
  );
}

function ProductInput({
  index,
  products,
  units,
  context,
  incoming = false,
  fixed,
  remember,
}: {
  index: string;
  products: Product[];
  units: Unit[];
  context: string;
  incoming?: boolean;
  fixed?: string;
  remember: (id: string, detail: ProductDetail) => void;
}) {
  const [selected, setSelected] = useState(fixed ?? "");
  const [detail, setDetail] = useState<ProductDetail>();
  const [error, setError] = useState("");
  useEffect(() => {
    const id = fixed ?? selected;
    if (!id) return;
    let live = true;
    void api<ProductDetail>(`/catalog/products/${id}`, {}, context)
      .then((value) => {
        if (live) {
          remember(id, value);
          setDetail(value);
        }
      })
      .catch((e) => {
        if (live) setError(describe(e));
      });
    return () => {
      live = false;
    };
  }, [context, fixed, remember, selected]);
  const productId = fixed ?? selected;
  const product = detail?.product.id === productId ? detail.product : undefined;
  return (
    <div className="settings-fields">
      {!fixed ? (
        <label className="auth-field">
          <span>Product</span>
          <select
            name={`product-${index}`}
            aria-label={`Product ${index}`}
            value={selected}
            required
            onChange={(e) => {
              setSelected(e.target.value);
              setError("");
            }}
          >
            <option value="">Select product</option>
            {products.map((p) => (
              <option key={p.id} value={p.id}>
                {p.sku} · {p.name}
              </option>
            ))}
          </select>
        </label>
      ) : (
        <input type="hidden" name={`product-${index}`} value={fixed} />
      )}
      <label className="auth-field">
        <span>Configured unit</span>
        <select
          key={productId}
          name={`unit-${index}`}
          aria-label={`Unit ${index}`}
          required
        >
          <option value="">Select unit</option>
          {product &&
            detail?.units
              .filter((u) => u.isActive)
              .map((u) => (
                <option key={u.id} value={u.id}>
                  {units.find((m) => m.id === u.unitId)?.name ?? u.id}
                </option>
              ))}
        </select>
      </label>
      <label className="auth-field">
        <span>Quantity</span>
        <input
          name={`quantity-${index}`}
          aria-label={`Quantity ${index}`}
          inputMode="decimal"
          required
        />
      </label>
      {incoming && (
        <>
          <label className="auth-field">
            <span>Actual cost per selected unit</span>
            <input name={`cost-${index}`} inputMode="decimal" required />
          </label>
          <label className="auth-field">
            <span>Condition</span>
            <Disposition name={`condition-${index}`} />
          </label>
          <label className="org-check">
            <input name={`zero-${index}`} type="checkbox" /> Confirm intentional
            zero cost
          </label>
          {product?.trackingMode === "LOT" && (
            <>
              <label className="auth-field">
                <span>Lot code</span>
                <input name={`lot-${index}`} required maxLength={128} />
              </label>
              <label className="auth-field">
                <span>Supplier lot reference</span>
                <input name={`supplier-lot-${index}`} maxLength={128} />
              </label>
              <label className="auth-field">
                <span>Manufactured</span>
                <input name={`made-${index}`} type="date" />
              </label>
              <label className="auth-field">
                <span>Expiry</span>
                <input
                  name={`expiry-${index}`}
                  type="date"
                  required={product.expiryRequired}
                />
              </label>
            </>
          )}
        </>
      )}
      {error && <p role="alert">{error}</p>}
    </div>
  );
}

export function StockOperationNav({ admin }: { admin: boolean }) {
  return (
    <nav className="inventory-nav" aria-label="Stock operations">
      <Link href="/inventory">Stock</Link>
      <Link href="/inventory/transfers">Transfers</Link>
      <Link href="/inventory/counts">Stock takes</Link>
      {admin && (
        <>
          <Link href="/inventory/adjustments">Adjustments</Link>
          <Link href="/inventory/waste">Waste</Link>
        </>
      )}
    </nav>
  );
}

export function StockOperationsPanel({
  mode,
  session,
  currency,
}: {
  mode: StockMode;
  session: Session;
  currency: string;
}) {
  const context = session.contextVersion;
  const admin = session.memberships.some(
    (m) => m.id === session.selectedMembershipId && m.role === "ADMINISTRATOR",
  );
  const [warehouses, setWarehouses] = useState<Warehouse[]>([]);
  const [counterparts, setCounterparts] = useState<TransferWarehouse[]>([]);
  const [products, setProducts] = useState<Product[]>([]);
  const [units, setUnits] = useState<Unit[]>([]);
  const [transfers, setTransfers] = useState<Transfer[]>([]);
  const [counts, setCounts] = useState<Count[]>([]);
  const [history, setHistory] = useState<
    { id: string; number: string; warehouse: string; businessDate: string }[]
  >([]);
  const [transfer, setTransfer] = useState<TransferDetail>();
  const [count, setCount] = useState<CountDetail>();
  const [warehouse, setWarehouse] = useState("");
  const [buckets, setBuckets] = useState<SourceRow[]>([]);
  const [bucket, setBucket] = useState("");
  const [direction, setDirection] = useState("remove");
  const [query, setQuery] = useState("");
  const [productQuery, setProductQuery] = useState("");
  const [formLines, setFormLines] = useState([1]);
  const [unexpected, setUnexpected] = useState(false);
  const [step, setStep] = useState<IssueMode>("dispatch");
  const [error, setError] = useState("");
  const [notice, setNotice] = useState("");
  const [busy, setBusy] = useState(false);
  const [loading, setLoading] = useState(true);
  const [revision, setRevision] = useState(0);
  const [pending, setPending] = useState<{
    path: string;
    body: string;
    show?: "transfer" | "count";
    uncertain: boolean;
  }>();
  const details = useRef(new Map<string, ProductDetail>());
  const remember = useCallback((id: string, detail: ProductDetail) => {
    details.current.set(id, detail);
  }, []);
  const [reconciliation, setReconciliation] =
    useState<{ kind: string; id: string }[]>();

  useEffect(() => {
    let live = true;
    void Promise.all([
      api<Warehouse[]>("/inventory/warehouses", {}, context),
      api<Product[]>("/catalog/products", {}, context),
      api<Unit[]>("/catalog/units", {}, context),
      mode === "transfers"
        ? api<TransferWarehouse[]>(prefix + "/transfer-warehouses", {}, context)
        : Promise.resolve([]),
    ])
      .then(([w, p, u, t]) => {
        if (live) {
          setWarehouses(w);
          setProducts(p.filter((x) => x.isActive));
          setUnits(u);
          setCounterparts(t);
        }
      })
      .catch((e) => {
        if (live) setError(describe(e));
      })
      .finally(() => {
        if (live) setLoading(false);
      });
    return () => {
      live = false;
    };
  }, [context, mode]);

  useEffect(() => {
    let live = true;
    if (mode === "transfers")
      void api<Transfer[]>(prefix + "/transfers", {}, context)
        .then((x) => {
          if (live) setTransfers(x);
        })
        .catch((e) => {
          if (live) setError(describe(e));
        });
    else if (mode === "counts")
      void api<Count[]>(prefix + "/counts", {}, context)
        .then((x) => {
          if (live) setCounts(x);
        })
        .catch((e) => {
          if (live) setError(describe(e));
        });
    else if (admin)
      void api<typeof history>(
        `/inventory/documents?type=${mode === "waste" ? "WASTE" : "ADJUST"}`,
        {},
        context,
      )
        .then((x) => {
          if (live) setHistory(x);
        })
        .catch((e) => {
          if (live) setError(describe(e));
        });
    return () => {
      live = false;
    };
  }, [admin, context, mode, revision]);

  useEffect(() => {
    if (!warehouse || !(mode === "adjustments" || mode === "waste")) return;
    let live = true;
    void api<SourceRow[]>(
      `/inventory/stock?warehouseId=${warehouse}`,
      {},
      context,
    )
      .then((rows) => {
        if (live) setBuckets(rows.filter((row) => row.onHand !== "0"));
      })
      .catch((e) => {
        if (live) setError(describe(e));
      });
    return () => {
      live = false;
    };
  }, [context, mode, warehouse, revision]);

  useEffect(() => {
    if (!pending?.uncertain && !(busy && pending)) return;
    const unload = (e: BeforeUnloadEvent) => e.preventDefault();
    window.addEventListener("beforeunload", unload);
    return () => window.removeEventListener("beforeunload", unload);
  }, [busy, pending]);

  async function loadTransfer(id: string) {
    setTransfer(
      await api<TransferDetail>(prefix + "/transfers/" + id, {}, context),
    );
  }
  async function loadCount(id: string) {
    setCount(await api<CountDetail>(prefix + "/counts/" + id, {}, context));
  }

  function prepare(
    e: FormEvent<HTMLFormElement>,
    path: string,
    payload: (data: FormData) => object,
    show?: "transfer" | "count",
  ) {
    e.preventDefault();
    if (busy || pending) return;
    setError("");
    setNotice("");
    try {
      setPending({
        path,
        body: JSON.stringify({
          operationId: crypto.randomUUID(),
          ...payload(new FormData(e.currentTarget)),
        }),
        show,
        uncertain: false,
      });
    } catch (e) {
      setError(describe(e));
    }
  }

  async function post() {
    if (!pending || busy) return;
    setBusy(true);
    setError("");
    try {
      const result = await api<Posted>(
        prefix + pending.path,
        { method: "POST", body: pending.body },
        context,
      );
      setPending(undefined);
      setNotice(`Posted ${result.number}.`);
      setRevision((x) => x + 1);
      if (pending.show === "transfer")
        void loadTransfer(result.id).catch((e) => setError(describe(e)));
      else if (pending.show === "count")
        void loadCount(result.id).catch((e) => setError(describe(e)));
      else if (transfer)
        void loadTransfer(transfer.transfer.id).catch((e) =>
          setError(describe(e)),
        );
      else if (count)
        void loadCount(count.count.id).catch((e) => setError(describe(e)));
    } catch (e) {
      const uncertain =
        pending.uncertain || !(e instanceof ApiError) || e.status >= 500;
      setPending({ ...pending, uncertain });
      setError(
        uncertain
          ? "Posting is unconfirmed. Retry this exact operation before entering it again."
          : describe(e),
      );
    } finally {
      setBusy(false);
    }
  }

  function line(data: FormData, index: string) {
    const id = field(data, `product-${index}`);
    const item = details.current.get(id);
    const unit = item?.units.find((x) => x.id === field(data, `unit-${index}`));
    if (!item || !unit)
      throw new Error("Choose a product and configured unit.");
    return {
      itemId: id,
      itemUnitId: unit.id,
      itemVersion: item.product.version,
      unitVersion: unit.version,
      quantity: field(data, `quantity-${index}`),
    };
  }

  function incoming(data: FormData, index: string) {
    return {
      ...line(data, index),
      enteredUnitCost: field(data, `cost-${index}`),
      confirmZeroCost: data.has(`zero-${index}`),
      condition: field(data, `condition-${index}`),
      lotCode: field(data, `lot-${index}`) || null,
      supplierLot: field(data, `supplier-lot-${index}`) || null,
      manufacturedOn: field(data, `made-${index}`) || null,
      expiresOn: field(data, `expiry-${index}`) || null,
    };
  }

  async function saveCount(e: FormEvent<HTMLFormElement>) {
    e.preventDefault();
    if (!count || busy || pending) return;
    const data = new FormData(e.currentTarget);
    const lines = count.lines
      .filter((x) => field(data, `actual-${x.bucketId}`) !== "")
      .map((x) => ({
        bucketId: x.bucketId,
        quantity: field(data, `actual-${x.bucketId}`),
        positiveUnitCost: field(data, `cost-${x.bucketId}`) || null,
        confirmZeroCost: data.has(`zero-${x.bucketId}`),
      }));
    if (!lines.length) {
      setError("Enter at least one counted quantity.");
      return;
    }
    setBusy(true);
    setError("");
    try {
      await api(
        prefix + "/counts/" + count.count.id,
        {
          method: "PUT",
          body: JSON.stringify({ version: count.count.version, lines }),
        },
        context,
      );
      await loadCount(count.count.id);
      setNotice("Count quantities saved.");
    } catch (e) {
      setError(describe(e));
    } finally {
      setBusy(false);
    }
  }

  const warehouseOptions = (
    <>
      <option value="">Select warehouse</option>
      {warehouses.map((w) => (
        <option key={w.id} value={w.id}>
          {w.name}
        </option>
      ))}
    </>
  );
  const productOptions = products.filter((p) =>
    `${p.sku} ${p.name}`.toLowerCase().includes(productQuery.toLowerCase()),
  );
  const selectedBucket = buckets.find((x) => x.id === bucket);
  const disabled = !!pending || busy || loading;
  const openReservations = transfer?.reservations ?? [];
  const openDispatches =
    transfer?.dispatches.filter((x) => x.outstanding !== "0") ?? [];
  const stepRows =
    step === "dispatch"
      ? openReservations.map((x) => ({ ...x, outstanding: x.remaining }))
      : openDispatches;
  const canStep =
    transfer &&
    (step === "dispatch"
      ? transfer.transfer.sourceAccess && !transfer.transfer.cancelled
      : step === "receive"
        ? transfer.transfer.destinationAccess
        : admin);

  return (
    <div className="inventory-panel">
      <header className="private-page-heading">
        <h1>{labels[mode]}</h1>
        <StockOperationNav admin={admin} />
      </header>
      {error && (
        <p className="auth-error" role="alert">
          {error}
        </p>
      )}
      {notice && <p role="status">{notice}</p>}
      {admin && mode === "transfers" && (
        <section className="settings-card">
          <button
            className="auth-secondary"
            disabled={disabled}
            onClick={() => {
              void api<{ kind: string; id: string }[]>(
                prefix + "/reconcile",
                {},
                context,
              )
                .then(setReconciliation)
                .catch((e) => setError(describe(e)));
            }}
          >
            Check company stock reconciliation
          </button>
          {reconciliation && (
            <div role="status">
              {reconciliation.length === 0 ? (
                "No discrepancies found."
              ) : (
                <ul>
                  {reconciliation.map((x, i) => (
                    <li key={i}>
                      {x.kind} · record {x.id}
                    </li>
                  ))}
                </ul>
              )}
            </div>
          )}
        </section>
      )}
      {loading && <p role="status">Loading stock operations…</p>}
      {pending && (
        <section className="settings-card" aria-label="Confirm stock operation">
          <h2>Confirm stock operation</h2>
          <p>Check the quantities before submitting.</p>
          <div className="inventory-controls">
            <button
              className="auth-primary"
              disabled={busy}
              onClick={() => void post()}
            >
              {pending.uncertain ? "Retry exact operation" : "Confirm and post"}
            </button>
            {!pending.uncertain && (
              <button
                className="auth-secondary"
                disabled={busy}
                onClick={() => setPending(undefined)}
              >
                Back to edit
              </button>
            )}
          </div>
        </section>
      )}
      {mode === "transfers" && (
        <>
          <section className="settings-card">
            <h2>New transfer request</h2>
            <form
              onSubmit={(e) =>
                prepare(
                  e,
                  "/transfers",
                  (data) => ({
                    sourceWarehouseId: field(data, "source"),
                    destinationWarehouseId: field(data, "destination"),
                    reference: field(data, "reference") || null,
                    notes: field(data, "notes") || null,
                    lines: formLines.map((i) => line(data, String(i))),
                  }),
                  "transfer",
                )
              }
            >
              <fieldset className="catalog-fields" disabled={disabled}>
                <div className="settings-fields">
                  <label className="auth-field">
                    <span>Source warehouse</span>
                    <select
                      name="source"
                      aria-label="Source warehouse"
                      required
                    >
                      <option value="">Select source</option>
                      {counterparts.map((w) => (
                        <option key={w.id} value={w.id}>
                          {w.outlet} · {w.name}
                        </option>
                      ))}
                    </select>
                  </label>
                  <label className="auth-field">
                    <span>Destination warehouse</span>
                    <select
                      name="destination"
                      aria-label="Destination warehouse"
                      required
                    >
                      <option value="">Select destination</option>
                      {counterparts
                        .filter((w) => w.authorized)
                        .map((w) => (
                          <option key={w.id} value={w.id}>
                            {w.outlet} · {w.name}
                          </option>
                        ))}
                    </select>
                  </label>
                  <label className="auth-field">
                    <span>Reference</span>
                    <input name="reference" maxLength={120} />
                  </label>
                  <label className="auth-field">
                    <span>Notes</span>
                    <input name="notes" maxLength={700} />
                  </label>
                </div>
                <label className="auth-field">
                  <span>Search products</span>
                  <input
                    value={productQuery}
                    onChange={(e) => setProductQuery(e.target.value)}
                  />
                </label>
                {formLines.map((i) => (
                  <fieldset className="catalog-unit-card" key={i}>
                    <legend>Line {i}</legend>
                    <ProductInput
                      index={String(i)}
                      products={productOptions}
                      units={units}
                      context={context}
                      remember={remember}
                    />
                    {formLines.length > 1 && (
                      <button
                        type="button"
                        className="auth-text-link"
                        onClick={() =>
                          setFormLines((rows) => rows.filter((x) => x !== i))
                        }
                      >
                        Remove line
                      </button>
                    )}
                  </fieldset>
                ))}
                <div className="inventory-controls">
                  <button
                    type="button"
                    className="auth-secondary"
                    disabled={formLines.length >= 50}
                    onClick={() =>
                      setFormLines((rows) => [...rows, Math.max(...rows) + 1])
                    }
                  >
                    Add line
                  </button>
                  <button className="auth-primary">Review request</button>
                </div>
              </fieldset>
            </form>
          </section>
          <section className="settings-card">
            <h2>Transfer history</h2>
            <label className="auth-field">
              <span>Search transfers</span>
              <input value={query} onChange={(e) => setQuery(e.target.value)} />
            </label>
            {transfers.length === 0 && !loading && (
              <p>No transfers for this outlet context.</p>
            )}
            <ul>
              {transfers
                .filter((x) =>
                  `${x.number} ${x.source} ${x.destination} ${x.reference ?? ""}`
                    .toLowerCase()
                    .includes(query.toLowerCase()),
                )
                .map((x) => (
                  <li key={x.id}>
                    <button
                      className="auth-text-link"
                      disabled={disabled}
                      onClick={() => {
                        setStep(x.sourceAccess ? "dispatch" : "receive");
                        void loadTransfer(x.id).catch((e) =>
                          setError(describe(e)),
                        );
                      }}
                    >
                      {x.number} · {x.source} → {x.destination}
                      {x.reference ? " · " + x.reference : ""}
                    </button>
                  </li>
                ))}
            </ul>
          </section>
          {transfer && (
            <section className="settings-card" aria-label="Transfer detail">
              <h2>{transfer.transfer.number}</h2>
              <p>
                {transfer.transfer.source} → {transfer.transfer.destination}
              </p>
              <div className="organization-table-wrap">
                <table className="organization-table">
                  <thead>
                    <tr>
                      <th>SKU</th>
                      <th>Requested</th>
                      <th>Reserved</th>
                      <th>Dispatched</th>
                      <th>Received</th>
                      <th>Outstanding</th>
                      <th>Lost</th>
                      <th>Returned</th>
                      <th>Cancelled</th>
                    </tr>
                  </thead>
                  <tbody>
                    {transfer.lines.map((x) => (
                      <tr key={x.id}>
                        <td>
                          {x.sku} ({x.unit})
                        </td>
                        <td>{x.requested}</td>
                        <td>{x.reserved}</td>
                        <td>{x.dispatched}</td>
                        <td>{x.received}</td>
                        <td>{x.inTransit}</td>
                        <td>{x.lost}</td>
                        <td>{x.returned}</td>
                        <td>{x.cancelled}</td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
              {transfer.transfer.sourceAccess &&
                !transfer.transfer.cancelled &&
                (!transfer.transfer.confirmed ||
                  transfer.lines.some((x) => x.reserved !== "0")) && (
                  <form
                    onSubmit={(e) =>
                      prepare(
                        e,
                        `/transfers/${transfer.transfer.id}/${transfer.transfer.confirmed ? "cancel" : "confirm"}`,
                        (data) => ({ reason: field(data, "reason") || null }),
                      )
                    }
                  >
                    <fieldset className="catalog-fields" disabled={disabled}>
                      <label className="auth-field">
                        <span>Reason</span>
                        <input
                          name="reason"
                          maxLength={300}
                          required={transfer.transfer.confirmed}
                        />
                      </label>
                      <button className="auth-secondary">
                        {transfer.transfer.confirmed
                          ? "Review cancellation"
                          : "Review reservation"}
                      </button>
                    </fieldset>
                  </form>
                )}
              {!transfer.transfer.confirmed &&
                transfer.transfer.sourceAccess &&
                !transfer.transfer.cancelled && (
                  <form
                    onSubmit={(e) =>
                      prepare(
                        e,
                        `/transfers/${transfer.transfer.id}/cancel`,
                        (data) => ({ reason: field(data, "reason") }),
                      )
                    }
                  >
                    <fieldset className="catalog-fields" disabled={disabled}>
                      <label className="auth-field">
                        <span>Cancellation reason</span>
                        <input name="reason" required maxLength={300} />
                      </label>
                      <button className="auth-secondary">
                        Review cancellation
                      </button>
                    </fieldset>
                  </form>
                )}
              {transfer.transfer.confirmed && (
                <form
                  key={transfer.transfer.id + step + revision}
                  onSubmit={(e) =>
                    prepare(
                      e,
                      `/transfers/${transfer.transfer.id}/${step}`,
                      (data) => ({
                        reason: field(data, "reason") || null,
                        lines: stepRows
                          .filter((x) => field(data, "amount-" + x.id))
                          .map((x) => ({
                            id: x.id,
                            quantity: field(data, "amount-" + x.id),
                            condition:
                              step === "receive"
                                ? field(data, "condition-" + x.id)
                                : null,
                          })),
                      }),
                    )
                  }
                >
                  <fieldset className="catalog-fields" disabled={disabled}>
                    <label className="auth-field">
                      <span>Transfer action</span>
                      <select
                        aria-label="Transfer action"
                        value={step}
                        onChange={(e) => setStep(e.target.value as IssueMode)}
                      >
                        {issueModes.map((x) => (
                          <option key={x} value={x}>
                            {
                              {
                                dispatch: "Dispatch",
                                receive: "Receive",
                                loss: "Resolve loss",
                                return: "Return to source",
                              }[x]
                            }
                          </option>
                        ))}
                      </select>
                    </label>
                    {canStep &&
                      stepRows.map((x) => (
                        <fieldset className="catalog-unit-card" key={x.id}>
                          <legend>
                            {x.sku} · {x.lot} · {x.outstanding} base units
                            remaining
                          </legend>
                          {"expiresOn" in x && x.expiresOn && (
                            <p>Expires {x.expiresOn}</p>
                          )}
                          {"outstandingValue" in x &&
                            x.outstandingValue !== undefined && (
                              <p>
                                {currency} {x.outstandingValue} operational
                                value
                              </p>
                            )}
                          <label className="auth-field">
                            <span>
                              {step === "dispatch"
                                ? "Dispatch quantity"
                                : "Allocation quantity"}
                            </span>
                            <input
                              name={"amount-" + x.id}
                              inputMode="decimal"
                            />
                          </label>
                          {step === "receive" && (
                            <label className="auth-field">
                              <span>Receipt condition</span>
                              <Disposition name={"condition-" + x.id} />
                            </label>
                          )}
                        </fieldset>
                      ))}
                    {canStep && stepRows.length > 0 && (
                      <>
                        <label className="auth-field">
                          <span>Posting reason</span>
                          <input
                            name="reason"
                            maxLength={300}
                            required={step === "loss" || step === "return"}
                          />
                        </label>
                        <button className="auth-primary">Review {step}</button>
                      </>
                    )}
                    {(!canStep || !stepRows.length) && (
                      <p>No accessible allocations for this action.</p>
                    )}
                  </fieldset>
                </form>
              )}
            </section>
          )}
        </>
      )}
      {(mode === "adjustments" || mode === "waste") &&
        (admin ? (
          <>
            <section className="settings-card">
              <h2>Record {mode === "waste" ? "disposal" : "adjustment"}</h2>
              <form
                onSubmit={(e) =>
                  prepare(e, "/" + mode, (data) => {
                    const selected = warehouses.find((w) => w.id === warehouse);
                    if (!selected) throw new Error("Choose a warehouse.");
                    return {
                      warehouseId: warehouse,
                      warehouseVersion: selected.version,
                      expectedCurrency: currency,
                      reason: field(data, "reason"),
                      notes: field(data, "notes") || null,
                      ...(mode === "adjustments" && direction === "add"
                        ? { incoming: incoming(data, "stock") }
                        : { bucketId: bucket, ...line(data, "stock") }),
                    };
                  })
                }
              >
                <fieldset className="catalog-fields" disabled={disabled}>
                  <label className="auth-field">
                    <span>Warehouse</span>
                    <select
                      value={warehouse}
                      required
                      onChange={(e) => {
                        setWarehouse(e.target.value);
                        setBuckets([]);
                        setBucket("");
                      }}
                    >
                      {warehouseOptions}
                    </select>
                  </label>
                  {mode === "adjustments" && (
                    <label className="auth-field">
                      <span>Adjustment direction</span>
                      <select
                        value={direction}
                        onChange={(e) => setDirection(e.target.value)}
                      >
                        <option value="remove">Decrease</option>
                        <option value="add">Increase</option>
                      </select>
                    </label>
                  )}
                  {mode === "waste" || direction === "remove" ? (
                    <>
                      <label className="auth-field">
                        <span>Stock bucket</span>
                        <select
                          required
                          value={bucket}
                          onChange={(e) => setBucket(e.target.value)}
                        >
                          <option value="">Select stock</option>
                          {buckets.map((x) => (
                            <option key={x.id} value={x.id}>
                              {x.sku} · {x.lot} · {x.condition} · {x.onHand} on
                              hand · {x.reserved} reserved
                            </option>
                          ))}
                        </select>
                      </label>
                      {selectedBucket && (
                        <ProductInput
                          key={selectedBucket.id}
                          fixed={selectedBucket.itemId}
                          index="stock"
                          products={products}
                          units={units}
                          context={context}
                          remember={remember}
                        />
                      )}
                    </>
                  ) : (
                    <ProductInput
                      key="positive"
                      index="stock"
                      incoming
                      products={products}
                      units={units}
                      context={context}
                      remember={remember}
                    />
                  )}
                  <label className="auth-field">
                    <span>Reason</span>
                    <select name="reason" required>
                      <option value="">Choose reason</option>
                      {(mode === "waste"
                        ? [
                            "Damaged",
                            "Expired",
                            "Contaminated",
                            "Other unusable stock",
                          ]
                        : [
                            "Recording correction",
                            "Unrecorded inventory",
                            "Physical discrepancy",
                          ]
                      ).map((r) => (
                        <option key={r}>{r}</option>
                      ))}
                    </select>
                  </label>
                  <label className="auth-field">
                    <span>Notes</span>
                    <input name="notes" maxLength={700} />
                  </label>
                  <button className="auth-primary">
                    Review {mode === "waste" ? "waste" : "adjustment"}
                  </button>
                </fieldset>
              </form>
            </section>
            <section className="settings-card">
              <h2>Posted history</h2>
              {!history.length && <p>No matching documents.</p>}
              <ul>
                {history.map((x) => (
                  <li key={x.id}>
                    <Link href={`/inventory/documents/${x.id}`}>
                      {x.number} · {x.warehouse} · {x.businessDate}
                    </Link>
                  </li>
                ))}
              </ul>
            </section>
          </>
        ) : (
          <p>Only an Administrator can post this operation.</p>
        ))}
      {mode === "counts" && (
        <>
          <section className="settings-card">
            <h2>Start a stock take</h2>
            <form
              onSubmit={(e) =>
                prepare(
                  e,
                  "/counts",
                  (data) => ({ warehouseId: field(data, "warehouse") }),
                  "count",
                )
              }
            >
              <fieldset className="catalog-fields" disabled={disabled}>
                <label className="auth-field">
                  <span>Count warehouse</span>
                  <select
                    name="warehouse"
                    aria-label="Count warehouse"
                    required
                  >
                    {warehouseOptions}
                  </select>
                </label>
                <p>
                  Starting the count freezes stock changes for this warehouse
                  until it is completed or cancelled.
                </p>
                <button className="auth-primary">Review stock take</button>
              </fieldset>
            </form>
          </section>
          <section className="settings-card">
            <h2>Count history</h2>
            {!counts.length && <p>No stock takes for this outlet context.</p>}
            <ul>
              {counts.map((x) => (
                <li key={x.id}>
                  <button
                    className="auth-text-link"
                    disabled={disabled}
                    onClick={() =>
                      void loadCount(x.id).catch((e) => setError(describe(e)))
                    }
                  >
                    {x.number} · {x.warehouse} · {x.status}
                  </button>
                </li>
              ))}
            </ul>
          </section>
          {count && (
            <section className="settings-card" aria-label="Count detail">
              <h2>{count.count.number}</h2>
              <p>
                {count.count.status} ·{" "}
                {
                  count.lines.filter(
                    (x) => x.actual !== null && x.actual !== undefined,
                  ).length
                }
                /{count.lines.length} counted
              </p>
              <form
                onSubmit={saveCount}
                key={count.count.id + ":" + count.count.version}
              >
                <fieldset
                  className="catalog-fields"
                  disabled={disabled || count.count.status !== "COUNTING"}
                >
                  <div className="organization-table-wrap">
                    <table className="organization-table">
                      <thead>
                        <tr>
                          <th>Stock</th>
                          <th>Expected</th>
                          <th>Actual</th>
                          <th>Variance</th>
                          {admin && <th>Positive variance cost</th>}
                        </tr>
                      </thead>
                      <tbody>
                        {count.lines.map((x) => (
                          <tr key={x.bucketId}>
                            <td>
                              {x.sku} · {x.lot} · {x.condition}
                            </td>
                            <td>
                              {x.expected} {x.unit}
                            </td>
                            <td>
                              <input
                                name={"actual-" + x.bucketId}
                                aria-label={`Counted ${x.sku} ${x.lot} ${x.condition}`}
                                inputMode="decimal"
                                defaultValue={x.actual ?? ""}
                              />
                            </td>
                            <td>{x.variance ?? "—"}</td>
                            {admin && (
                              <td>
                                <input
                                  name={"cost-" + x.bucketId}
                                  aria-label={`Positive cost ${x.sku} ${x.lot}`}
                                  inputMode="decimal"
                                  defaultValue={x.positiveUnitCost ?? ""}
                                />
                                <label className="org-check">
                                  <input
                                    type="checkbox"
                                    name={"zero-" + x.bucketId}
                                    defaultChecked={x.positiveUnitCost === "0"}
                                  />{" "}
                                  Confirm zero
                                </label>
                              </td>
                            )}
                          </tr>
                        ))}
                      </tbody>
                    </table>
                  </div>
                  {count.lines.length > 0 && (
                    <button className="auth-secondary">
                      Save actual counts
                    </button>
                  )}
                </fieldset>
              </form>
              {admin && count.count.status === "COUNTING" && (
                <>
                  <form
                    onSubmit={(e) =>
                      prepare(
                        e,
                        `/counts/${count.count.id}/complete`,
                        (data) => ({
                          version: count.count.version,
                          expectedCurrency: currency,
                          reason: field(data, "reason"),
                          unexpected: unexpected
                            ? [incoming(data, "unexpected")]
                            : null,
                        }),
                      )
                    }
                  >
                    <fieldset className="catalog-fields" disabled={disabled}>
                      <label className="org-check">
                        <input
                          type="checkbox"
                          checked={unexpected}
                          onChange={(e) => setUnexpected(e.target.checked)}
                        />{" "}
                        Record unexpected stock
                      </label>
                      {unexpected && (
                        <ProductInput
                          index="unexpected"
                          incoming
                          products={products}
                          units={units}
                          context={context}
                          remember={remember}
                        />
                      )}
                      <label className="auth-field">
                        <span>Completion reason</span>
                        <input name="reason" required maxLength={300} />
                      </label>
                      <button className="auth-primary">
                        Review completion
                      </button>
                    </fieldset>
                  </form>
                  <form
                    onSubmit={(e) =>
                      prepare(
                        e,
                        `/counts/${count.count.id}/cancel`,
                        (data) => ({
                          version: count.count.version,
                          expectedCurrency: currency,
                          reason: field(data, "reason"),
                        }),
                      )
                    }
                  >
                    <fieldset className="catalog-fields" disabled={disabled}>
                      <label className="auth-field">
                        <span>Cancellation reason</span>
                        <input name="reason" required maxLength={300} />
                      </label>
                      <button className="auth-secondary">
                        Review cancellation
                      </button>
                    </fieldset>
                  </form>
                </>
              )}
            </section>
          )}
        </>
      )}
    </div>
  );
}
