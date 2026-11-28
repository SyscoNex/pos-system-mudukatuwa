"use client";

import { useEffect, useState, type FormEvent } from "react";
import Link from "next/link";
import { api, ApiError, type Session } from "@/lib/api/identity";

export type InventoryMode =
  "inventory" | "opening-stock" | "goods-receipts" | "movements";
type Warehouse = { id: string; name: string; version: string };
type Named = { id: string; name: string; isActive: boolean };
type Product = Named & {
  sku: string;
  version: string;
  purchaseEnabled: boolean;
  trackingMode: string;
  expiryRequired: boolean;
};
type ProductUnit = {
  id: string;
  unitId: string;
  version: string;
  isActive: boolean;
  isPurchaseDefault: boolean;
  purchasePrice?: string | null;
};
type ProductDetail = { product: Product; units: ProductUnit[] };
type Row = {
  key: string;
  product?: Product;
  units: ProductUnit[];
  unit: string;
  quantity: string;
  cost: string;
  zero: boolean;
  condition: string;
  lot: string;
  supplierLot: string;
  manufacture: string;
  expiry: string;
};
type Preview = {
  lines: {
    sku: string;
    baseQuantity: string;
    baseUnitCost: string;
    carriedValue: string;
  }[];
  displayTotal: string;
  currency: string;
};
type Receipt = {
  id: string;
  number: string;
  type: string;
  warehouse: string;
  businessDate: string;
  postedAt: string;
  currency: string;
  supplier?: string;
  supplierReference?: string;
  displayTotal?: string;
};
type Detail = {
  document: Receipt;
  notes?: string;
  lines: {
    sku: string;
    name: string;
    lot: string;
    condition: string;
    quantity: string;
    unit: string;
    factor: string;
    baseQuantity: string;
    manufacturedOn?: string;
    expiresOn?: string;
    enteredUnitCost?: string;
    carriedValue?: string;
  }[];
};
type Stock = {
  id: string;
  warehouse: string;
  sku: string;
  product: string;
  baseUnit: string;
  lot: string;
  manufacturedOn?: string;
  expiresOn?: string;
  condition: string;
  blocked: boolean;
  expired: boolean;
  onHand: string;
  reserved?: string;
  available: string;
  operationalValue?: string;
  averageCost?: string;
};
type Movement = {
  id: string;
  documentId: string;
  number: string;
  warehouse: string;
  sku: string;
  lot: string;
  condition: string;
  postedAt: string;
  quantity: string;
  value?: string;
};
type Difference = {
  bucketId: string;
  ledgerQuantity: string;
  projectedQuantity?: string;
  ledgerValue: string;
  projectedValue?: string;
};

const emptyLine = (): Row => ({
  key: crypto.randomUUID(),
  units: [],
  unit: "",
  quantity: "",
  cost: "",
  zero: false,
  condition: "AVAILABLE",
  lot: "",
  supplierLot: "",
  manufacture: "",
  expiry: "",
});
const message = (error: unknown) =>
  error instanceof Error ? error.message : "The request failed. Try again.";

export function InventoryPanel({
  mode,
  session,
  timezone,
  currency,
  documentId,
}: {
  mode: InventoryMode;
  session: Session;
  timezone: string;
  currency: string;
  documentId?: string;
}) {
  const context = session.contextVersion;
  const admin = session.memberships.some(
    (m) => m.id === session.selectedMembershipId && m.role === "ADMINISTRATOR",
  );
  const opening = mode === "opening-stock";
  const receiving = mode === "goods-receipts";
  const posting = receiving || (opening && admin);
  const [warehouses, setWarehouses] = useState<Warehouse[]>([]);
  const [products, setProducts] = useState<Product[]>([]);
  const [units, setUnits] = useState<Named[]>([]);
  const [categories, setCategories] = useState<Named[]>([]);
  const [suppliers, setSuppliers] = useState<Named[]>([]);
  const [warehouse, setWarehouse] = useState("");
  const [rows, setRows] = useState<Row[]>([]);
  const [date, setDate] = useState("");
  const [supplier, setSupplier] = useState("");
  const [reference, setReference] = useState("");
  const [notes, setNotes] = useState("");
  const [query, setQuery] = useState("");
  const [item, setItem] = useState("");
  const [category, setCategory] = useState("");
  const [batch, setBatch] = useState("");
  const [expiry, setExpiry] = useState("");
  const [data, setData] = useState<(Stock | Receipt | Movement)[]>([]);
  const [detail, setDetail] = useState<Detail>();
  const [pending, setPending] = useState<{
    payload: string;
    preview: Preview;
  }>();
  const [uncertain, setUncertain] = useState(false);
  const [result, setResult] = useState<{ id: string; number: string }>();
  const [differences, setDifferences] = useState<Difference[]>();
  const [loading, setLoading] = useState(true);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState("");

  useEffect(() => {
    if (documentId) return;
    let live = true;
    const today = new Intl.DateTimeFormat("en-CA", {
      timeZone: timezone,
      year: "numeric",
      month: "2-digit",
      day: "2-digit",
    }).format(new Date());
    void Promise.all([
      api<Warehouse[]>("/inventory/warehouses", {}, context),
      api<Product[]>("/catalog/products", {}, context),
      api<Named[]>("/catalog/units", {}, context),
      api<Named[]>("/catalog/categories", {}, context),
      posting && !opening
        ? api<Named[]>("/catalog/suppliers", {}, context)
        : Promise.resolve([]),
    ])
      .then(([warehouses, products, units, categories, suppliers]) => {
        if (!live) return;
        setWarehouses(warehouses);
        setProducts(products.filter((x) => x.isActive));
        setUnits(units);
        setCategories(categories);
        setSuppliers(suppliers.filter((x) => x.isActive));
        setDate(today);
        setRows([emptyLine()]);
      })
      .catch((e) => {
        if (live) setError(message(e));
      });
    return () => {
      live = false;
    };
  }, [context, documentId, opening, posting, timezone]);

  const resource =
    mode === "inventory"
      ? "stock"
      : mode === "movements"
        ? "movements"
        : "documents";
  const feed = `/inventory/${resource}?${new URLSearchParams(
    Object.fromEntries(
      Object.entries({
        warehouseId: warehouse,
        itemId: item,
        categoryId: category,
        batch,
        expiry,
        type: resource === "documents" ? (opening ? "OPEN" : "GRN") : "",
      }).filter(([, value]) => value),
    ),
  )}`;
  useEffect(() => {
    if (!uncertain && !(busy && pending)) return;
    const warn = (event: BeforeUnloadEvent) => event.preventDefault();
    window.addEventListener("beforeunload", warn);
    return () => window.removeEventListener("beforeunload", warn);
  }, [busy, pending, uncertain]);
  useEffect(() => {
    let live = true;
    if (documentId) {
      void api<Detail>(`/inventory/documents/${documentId}`, {}, context)
        .then((value) => {
          if (live) setDetail(value);
        })
        .catch((e) => {
          if (live) setError(message(e));
        })
        .finally(() => {
          if (live) setLoading(false);
        });
      return () => {
        live = false;
      };
    }
    void api<(Stock | Receipt | Movement)[]>(feed, {}, context)
      .then((rows) => {
        if (live) setData(rows);
      })
      .catch((e) => {
        if (live) {
          setData([]);
          setError(message(e));
        }
      })
      .finally(() => {
        if (live) setLoading(false);
      });
    return () => {
      live = false;
    };
  }, [context, documentId, feed]);

  function update(key: string, fields: Partial<Row>) {
    setRows((all) =>
      all.map((row) => (row.key === key ? { ...row, ...fields } : row)),
    );
  }

  async function pick(key: string, id: string, barcode?: string) {
    setBusy(true);
    setError("");
    try {
      const found = barcode
        ? await api<{ matchedItemUnitId: string; detail: ProductDetail }>(
            `/catalog/barcode?value=${encodeURIComponent(barcode)}`,
            {},
            context,
          )
        : null;
      const detail =
        found?.detail ??
        (await api<ProductDetail>(`/catalog/products/${id}`, {}, context));
      if (
        !detail.product.isActive ||
        (!opening && !detail.product.purchaseEnabled)
      )
        throw new Error("Choose a product allowed for this receipt.");
      const options = detail.units.filter((unit) => unit.isActive);
      const selected =
        found?.matchedItemUnitId ??
        options.find((unit) => unit.isPurchaseDefault)?.id ??
        options[0]?.id ??
        "";
      update(key, {
        product: detail.product,
        units: options,
        unit: selected,
        cost: "",
        lot: "",
        supplierLot: "",
        manufacture: "",
        expiry: "",
      });
    } catch (e) {
      setError(message(e));
    } finally {
      setBusy(false);
    }
  }

  const postingPath = `/inventory/${opening ? "opening-stock" : "goods-receipts"}`;
  async function preview(e: FormEvent) {
    e.preventDefault();
    const selected = warehouses.find((x) => x.id === warehouse);
    if (
      !selected ||
      rows.some(
        (row) =>
          !row.product || !row.units.some((unit) => unit.id === row.unit),
      )
    ) {
      setError("Choose a warehouse, product and unit for every line.");
      return;
    }
    setBusy(true);
    setError("");
    setResult(undefined);
    try {
      const payload = JSON.stringify({
        operationId: crypto.randomUUID(),
        warehouseId: warehouse,
        warehouseVersion: selected.version,
        expectedCurrency: currency,
        businessDate: date,
        supplierId: opening ? null : supplier,
        supplierReference: opening ? null : reference,
        notes,
        lines: rows.map((row) => ({
          itemId: row.product!.id,
          itemVersion: row.product!.version,
          itemUnitId: row.unit,
          unitVersion: row.units.find((unit) => unit.id === row.unit)!.version,
          quantity: row.quantity.trim(),
          enteredUnitCost: row.cost.trim(),
          confirmZeroCost: row.zero,
          condition: row.condition,
          lotCode: row.lot || null,
          supplierLot: row.supplierLot || null,
          manufacturedOn: row.manufacture || null,
          expiresOn: row.expiry || null,
        })),
      });
      const computed = await api<Preview>(
        postingPath + "/preview",
        { method: "POST", body: payload },
        context,
      );
      setPending({ payload, preview: computed });
    } catch (e) {
      setError(message(e));
    } finally {
      setBusy(false);
    }
  }

  async function post() {
    if (!pending || busy) return;
    setBusy(true);
    setError("");
    try {
      const posted = await api<{ id: string; number: string }>(
        postingPath,
        { method: "POST", body: pending.payload },
        context,
      );
      setResult(posted);
      setPending(undefined);
      setUncertain(false);
      setRows([emptyLine()]);
      setReference("");
      setNotes("");
    } catch (e) {
      const mayHaveCommitted =
        uncertain || !(e instanceof ApiError) || e.status >= 500;
      setUncertain(mayHaveCommitted);
      setError(
        mayHaveCommitted
          ? "Posting is unconfirmed. Retry this exact request or verify its outcome before entering it again."
          : message(e),
      );
      return;
    } finally {
      setBusy(false);
    }
    void api<Receipt[]>(feed, {}, context)
      .then(setData)
      .catch((e) => setError(message(e)));
  }

  const title = documentId
    ? "Inventory document"
    : mode === "inventory"
      ? "Warehouse inventory"
      : opening
        ? "Opening stock"
        : receiving
          ? "Goods receipts"
          : "Stock movements";
  const matching = products.filter(
    (x) =>
      (opening || x.purchaseEnabled) &&
      `${x.sku} ${x.name}`.toLowerCase().includes(query.toLowerCase()),
  );

  return (
    <div className="inventory-panel">
      <header className="private-page-heading">
        <h1>{title}</h1>
        <nav className="inventory-nav" aria-label="Inventory pages">
          <Link href="/inventory">Stock</Link>
          {admin && <Link href="/inventory/opening-stock">Opening stock</Link>}
          <Link href="/inventory/goods-receipts">Goods receipts</Link>
          <Link href="/inventory/movements">Movements</Link>
          <Link href="/inventory/transfers">Transfers</Link>
          <Link href="/inventory/counts">Stock takes</Link>
          {admin && (
            <>
              <Link href="/inventory/adjustments">Adjustments</Link>
              <Link href="/inventory/waste">Waste</Link>
            </>
          )}
        </nav>
      </header>
      {error && (
        <p className="auth-error" role="alert">
          {error}
        </p>
      )}
      {result && (
        <p role="status">
          Posted {result.number}.{" "}
          <Link href={`/inventory/documents/${result.id}`}>View document</Link>{" "}
          · <Link href="/inventory">View updated stock</Link>
        </p>
      )}
      {detail && (
        <section className="settings-card inventory-document">
          <h2>{detail.document.number}</h2>
          <p>
            {detail.document.warehouse} · {detail.document.businessDate} ·{" "}
            {detail.document.postedAt}
          </p>
          {detail.document.supplier && (
            <p>
              {detail.document.supplier} {detail.document.supplierReference}
            </p>
          )}
          {detail.notes && <p>{detail.notes}</p>}
          {detail.document.type === "PROD" && (
            <p>
              See <Link href="/inventory/manufacturing">Manufacturing</Link> for
              input groups, lot lineage and output details.
            </p>
          )}
          <div className="organization-table-wrap">
            <table className="organization-table">
              <thead>
                <tr>
                  <th>Product</th>
                  <th>Lot and dates</th>
                  <th>Quantity</th>
                  <th>Base quantity</th>
                  {admin && <th>Operational cost</th>}
                </tr>
              </thead>
              <tbody>
                {detail.lines.map((line, index) => (
                  <tr key={index}>
                    <td>
                      {line.sku} · {line.name}
                    </td>
                    <td>
                      {line.lot} · {line.condition}
                      <br />
                      {line.manufacturedOn} {line.expiresOn}
                    </td>
                    <td>
                      {detail.document.type === "PROD" ? (
                        "—"
                      ) : (
                        <>
                          {line.quantity} {line.unit}
                        </>
                      )}
                    </td>
                    <td>
                      {line.baseQuantity} (× {line.factor})
                    </td>
                    {admin && (
                      <td>
                        {line.enteredUnitCost != null && (
                          <>{line.enteredUnitCost} per unit / </>
                        )}
                        {line.carriedValue} carried
                      </td>
                    )}
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
          {detail.document.displayTotal !== undefined && (
            <p>
              Total: {detail.document.currency} {detail.document.displayTotal}
            </p>
          )}
          <div className="inventory-controls">
            <button className="auth-secondary" onClick={() => window.print()}>
              Print
            </button>
            <Link
              className="auth-secondary"
              href={
                detail.document.type === "OPEN"
                  ? "/inventory/opening-stock"
                  : "/inventory/goods-receipts"
              }
            >
              Back to history
            </Link>
          </div>
        </section>
      )}
      {documentId ? (
        loading && <p role="status">Loading document…</p>
      ) : (
        <>
          <label className="auth-field">
            <span>Warehouse</span>
            <select
              value={warehouse}
              disabled={!!pending || busy}
              onChange={(e) => {
                setWarehouse(e.target.value);
                setDifferences(undefined);
              }}
            >
              <option value="">All authorized warehouses</option>
              {warehouses.map((w) => (
                <option key={w.id} value={w.id}>
                  {w.name}
                </option>
              ))}
            </select>
          </label>
          {!loading && !warehouses.length && (
            <p>No active warehouse is available for your outlet access.</p>
          )}
          {posting && warehouses.length > 0 && (
            <section className="settings-card inventory-form">
              <h2>
                {opening ? "Enter initial physical stock" : "Receive goods"}
              </h2>
              <form onSubmit={preview}>
                <fieldset
                  disabled={busy || !!pending}
                  className="catalog-fields"
                >
                  <div className="settings-fields">
                    <label className="auth-field">
                      <span>Business date</span>
                      <input
                        type="date"
                        required
                        value={date}
                        onChange={(e) => setDate(e.target.value)}
                      />
                    </label>
                    {!opening && (
                      <>
                        <label className="auth-field">
                          <span>Supplier</span>
                          <select
                            value={supplier}
                            required
                            onChange={(e) => setSupplier(e.target.value)}
                          >
                            <option value="">Choose supplier</option>
                            {suppliers.map((s) => (
                              <option key={s.id} value={s.id}>
                                {s.name}
                              </option>
                            ))}
                          </select>
                        </label>
                        <label className="auth-field">
                          <span>Supplier reference</span>
                          <input
                            value={reference}
                            maxLength={120}
                            onChange={(e) => setReference(e.target.value)}
                          />
                        </label>
                      </>
                    )}
                    <label className="auth-field">
                      <span>Notes</span>
                      <input
                        value={notes}
                        maxLength={700}
                        onChange={(e) => setNotes(e.target.value)}
                      />
                    </label>
                  </div>
                  <label className="auth-field">
                    <span>Search products by SKU or name</span>
                    <input
                      value={query}
                      onChange={(e) => setQuery(e.target.value)}
                    />
                  </label>
                  {rows.map((row, index) => (
                    <fieldset className="catalog-unit-card" key={row.key}>
                      <legend>Line {index + 1}</legend>
                      <div className="settings-fields">
                        <label className="auth-field">
                          <span>Product</span>
                          <select
                            aria-label={`Product ${index + 1}`}
                            required
                            value={row.product?.id ?? ""}
                            onChange={(e) => void pick(row.key, e.target.value)}
                          >
                            <option value="" disabled>
                              Choose product
                            </option>
                            {[
                              ...matching,
                              ...(row.product &&
                              !matching.some((x) => x.id === row.product?.id)
                                ? [row.product]
                                : []),
                            ].map((p) => (
                              <option key={p.id} value={p.id}>
                                {p.sku} · {p.name}
                              </option>
                            ))}
                          </select>
                        </label>
                        <label className="auth-field">
                          <span>Scan barcode and press Enter</span>
                          <input
                            onKeyDown={(e) => {
                              if (e.key === "Enter") {
                                e.preventDefault();
                                const code = e.currentTarget.value;
                                if (code) void pick(row.key, "", code);
                              }
                            }}
                          />
                        </label>
                        <label className="auth-field">
                          <span>Unit</span>
                          <select
                            aria-label={`Unit ${index + 1}`}
                            required
                            value={row.unit}
                            onChange={(e) =>
                              update(row.key, {
                                unit: e.target.value,
                                cost: "",
                              })
                            }
                          >
                            <option value="" disabled>
                              Choose unit
                            </option>
                            {row.units.map((u) => (
                              <option key={u.id} value={u.id}>
                                {units.find((x) => x.id === u.unitId)?.name ??
                                  u.unitId}
                              </option>
                            ))}
                          </select>
                        </label>
                        <label className="auth-field">
                          <span>Received quantity</span>
                          <input
                            inputMode="decimal"
                            required
                            value={row.quantity}
                            onChange={(e) =>
                              update(row.key, { quantity: e.target.value })
                            }
                          />
                        </label>
                        <label className="auth-field">
                          <span>Actual cost per selected unit</span>
                          <input
                            inputMode="decimal"
                            required
                            value={row.cost}
                            onChange={(e) =>
                              update(row.key, { cost: e.target.value })
                            }
                          />
                        </label>
                        <label className="auth-field">
                          <span>Disposition</span>
                          <select
                            value={row.condition}
                            onChange={(e) =>
                              update(row.key, { condition: e.target.value })
                            }
                          >
                            <option value="AVAILABLE">Accepted</option>
                            <option value="HOLD">Hold</option>
                            <option value="DAMAGED">Damaged</option>
                          </select>
                        </label>
                        {row.product?.trackingMode === "LOT" && (
                          <>
                            <label className="auth-field">
                              <span>Lot code</span>
                              <input
                                required
                                maxLength={128}
                                value={row.lot}
                                onChange={(e) =>
                                  update(row.key, { lot: e.target.value })
                                }
                              />
                            </label>
                            <label className="auth-field">
                              <span>Supplier lot</span>
                              <input
                                maxLength={128}
                                value={row.supplierLot}
                                onChange={(e) =>
                                  update(row.key, {
                                    supplierLot: e.target.value,
                                  })
                                }
                              />
                            </label>
                            <label className="auth-field">
                              <span>Manufacturing date</span>
                              <input
                                type="date"
                                value={row.manufacture}
                                onChange={(e) =>
                                  update(row.key, {
                                    manufacture: e.target.value,
                                  })
                                }
                              />
                            </label>
                            <label className="auth-field">
                              <span>Expiry date</span>
                              <input
                                type="date"
                                required={row.product.expiryRequired}
                                value={row.expiry}
                                onChange={(e) =>
                                  update(row.key, { expiry: e.target.value })
                                }
                              />
                            </label>
                          </>
                        )}
                      </div>
                      <label className="org-check">
                        <input
                          type="checkbox"
                          checked={row.zero}
                          onChange={(e) =>
                            update(row.key, { zero: e.target.checked })
                          }
                        />{" "}
                        Confirm intentional zero cost
                      </label>
                      {rows.length > 1 && (
                        <button
                          type="button"
                          className="auth-text-link"
                          onClick={() =>
                            setRows((all) =>
                              all.filter((x) => x.key !== row.key),
                            )
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
                      disabled={rows.length >= 100}
                      onClick={() => setRows((all) => [...all, emptyLine()])}
                    >
                      Add line
                    </button>
                    <button
                      className="auth-primary"
                      disabled={!warehouse || !rows.length}
                    >
                      Preview posting
                    </button>
                  </div>
                </fieldset>
              </form>
              {pending && (
                <section aria-label="Confirm posting">
                  <h3>Confirm posting</h3>
                  <ul>
                    {pending.preview.lines.map((line, index) => (
                      <li key={index}>
                        {line.sku}: {line.baseQuantity} base units ·{" "}
                        {line.carriedValue} carried value
                      </li>
                    ))}
                  </ul>
                  <p>
                    {pending.preview.currency} {pending.preview.displayTotal}{" "}
                    total
                  </p>
                  <div className="inventory-controls">
                    <button
                      className="auth-primary"
                      disabled={busy}
                      onClick={() => void post()}
                    >
                      {uncertain ? "Retry same posting" : "Confirm and post"}
                    </button>
                    {!uncertain && (
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
            </section>
          )}
          {mode === "inventory" && (
            <section className="settings-card">
              <div className="settings-fields">
                <label className="auth-field">
                  <span>Product filter</span>
                  <select
                    value={item}
                    onChange={(e) => setItem(e.target.value)}
                  >
                    <option value="">All products</option>
                    {products.map((p) => (
                      <option key={p.id} value={p.id}>
                        {p.sku} · {p.name}
                      </option>
                    ))}
                  </select>
                </label>
                <label className="auth-field">
                  <span>Category filter</span>
                  <select
                    value={category}
                    onChange={(e) => setCategory(e.target.value)}
                  >
                    <option value="">All categories</option>
                    {categories.map((c) => (
                      <option key={c.id} value={c.id}>
                        {c.name}
                      </option>
                    ))}
                  </select>
                </label>
                <label className="auth-field">
                  <span>Exact batch</span>
                  <input
                    value={batch}
                    onChange={(e) => setBatch(e.target.value)}
                    maxLength={128}
                  />
                </label>
                <label className="auth-field">
                  <span>Expiry filter</span>
                  <select
                    value={expiry}
                    onChange={(e) => setExpiry(e.target.value)}
                  >
                    <option value="">All dates</option>
                    <option value="expired">Expired</option>
                    <option value="dated">Dated</option>
                    <option value="undated">No expiry</option>
                  </select>
                </label>
              </div>
              {admin && (
                <button
                  className="auth-secondary"
                  onClick={() => {
                    void api<Difference[]>(
                      `/inventory/reconcile?${warehouse ? `warehouseId=${warehouse}` : ""}`,
                      {},
                      context,
                    )
                      .then(setDifferences)
                      .catch((e) => setError(message(e)));
                  }}
                >
                  Check ledger reconciliation
                </button>
              )}
              {differences && (
                <div role="status">
                  {differences.length ? (
                    <ul>
                      {differences.map((d) => (
                        <li key={d.bucketId}>
                          Bucket {d.bucketId}: ledger {d.ledgerQuantity} /{" "}
                          {d.ledgerValue}, projection{" "}
                          {d.projectedQuantity ?? "missing"} /{" "}
                          {d.projectedValue ?? "missing"}
                        </li>
                      ))}
                    </ul>
                  ) : (
                    "No quantity or value discrepancies found."
                  )}
                </div>
              )}
            </section>
          )}
          <section className="settings-card inventory-results">
            <h2>
              {mode === "inventory"
                ? "Stock by warehouse and lot"
                : "Posted history"}
            </h2>
            {loading && <p role="status">Loading inventory…</p>}
            {!loading && !data.length && !error && (
              <p>No matching stock records.</p>
            )}
            {data.length > 0 && (
              <div className="organization-table-wrap">
                <table className="organization-table">
                  <thead>
                    <tr>
                      <th>{mode === "inventory" ? "Product" : "Document"}</th>
                      <th>Warehouse</th>
                      <th>Details</th>
                      <th>Quantity / status</th>
                      {admin && <th>Operational cost</th>}
                    </tr>
                  </thead>
                  <tbody>
                    {data
                      .filter(
                        (row) =>
                          !("type" in row) ||
                          row.type === (opening ? "OPEN" : "GRN"),
                      )
                      .map((row) => (
                        <tr key={row.id}>
                          {"onHand" in row ? (
                            <>
                              <td>
                                {row.sku} · {row.product}
                              </td>
                              <td>{row.warehouse}</td>
                              <td>
                                {row.lot}
                                <br />
                                {row.manufacturedOn &&
                                  `Made ${row.manufacturedOn}`}{" "}
                                {row.expiresOn && `Expires ${row.expiresOn}`}
                              </td>
                              <td>
                                {row.onHand} {row.baseUnit} on hand
                                {row.reserved && row.reserved !== "0" && (
                                  <> · {row.reserved} reserved</>
                                )}
                                <br />
                                {row.available} available · {row.condition}
                                {row.expired && " · Expired"}
                                {row.blocked && " · Blocked"}
                              </td>
                              {admin && (
                                <td>
                                  {row.operationalValue} carried
                                  <br />
                                  {row.averageCost ?? "—"} average
                                </td>
                              )}
                            </>
                          ) : "type" in row ? (
                            <>
                              <td>
                                <Link href={`/inventory/documents/${row.id}`}>
                                  {row.number}
                                </Link>
                              </td>
                              <td>{row.warehouse}</td>
                              <td>
                                {row.businessDate} · {row.supplier}
                              </td>
                              <td>Posted</td>
                              {admin && (
                                <td>
                                  {row.currency} {row.displayTotal}
                                </td>
                              )}
                            </>
                          ) : (
                            <>
                              <td>
                                <Link
                                  href={`/inventory/documents/${row.documentId}`}
                                >
                                  {row.number}
                                </Link>
                              </td>
                              <td>{row.warehouse}</td>
                              <td>
                                {row.sku} · {row.lot} · {row.postedAt}
                              </td>
                              <td>
                                {row.quantity} base · {row.condition}
                              </td>
                              {admin && <td>{row.value}</td>}
                            </>
                          )}
                        </tr>
                      ))}
                  </tbody>
                </table>
              </div>
            )}
            {data.length >= 50 && (
              <button
                className="auth-secondary"
                onClick={() => {
                  const cursor = resource === "stock" ? "after" : "before";
                  void api<(Stock | Receipt | Movement)[]>(
                    `${feed}&${cursor}=${data.at(-1)!.id}`,
                    {},
                    context,
                  )
                    .then(setData)
                    .catch((e) => setError(message(e)));
                }}
              >
                Next page
              </button>
            )}
          </section>
        </>
      )}
    </div>
  );
}
