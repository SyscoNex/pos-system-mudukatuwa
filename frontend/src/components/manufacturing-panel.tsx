"use client";

import { useEffect, useState, type FormEvent } from "react";
import { api, ApiError, type Session } from "@/lib/api/identity";

type Product = {
  id: string;
  sku: string;
  name: string;
  kind: string;
  version: string;
  trackingMode: string;
  expiryRequired: boolean;
  isActive: boolean;
  manufactureEnabled: boolean;
};
type Unit = { id: string; unitId: string; version: string; isActive: boolean };
type ProductDetail = { product: Product; units: Unit[] };
type Warehouse = {
  id: string;
  branchId: string;
  name: string;
  version: string;
};
type Stock = {
  id: string;
  lot: string;
  available: string;
  baseUnit: string;
  expiresOn?: string;
};
type Allocation = {
  group: number;
  sku: string;
  product: string;
  unit: string;
  enteredQuantity: string;
  factor: string;
  baseQuantity: string;
  lotId: string;
  lot: string;
  expiresOn?: string;
  carriedValue?: string;
};
type Run = {
  id: string;
  number: string;
  warehouse: string;
  productionDate: string;
  reference?: string;
  outputSku: string;
  outputName: string;
  outputQuantity: string;
  outputUnit: string;
  baseOutputQuantity: string;
  outputLotId: string;
  outputLot: string;
  tracked: boolean;
  expiresOn?: string;
  currency: string;
  totalCost?: string;
  outputBaseUnitCost?: string;
};
type Detail = {
  run: Run;
  operator: string;
  notes?: string;
  materials: Allocation[];
};
type Preview = {
  materials: Allocation[];
  baseOutputQuantity: string;
  outputSku: string;
  lot: string;
  currency: string;
  totalCost?: string;
  outputBaseUnitCost?: string;
};
type Finding = { kind: string; id: string };

const path = "/inventory/manufacturing";
const errorText = (e: unknown) =>
  e instanceof Error ? e.message : "Manufacturing request failed.";
const text = (f: FormData, key: string) => String(f.get(key) ?? "").trim();

function ProductQuantity({
  index,
  products,
  unitNames,
  context,
  warehouse,
  search,
  output = false,
}: {
  index: string;
  products: Product[];
  unitNames: Record<string, string>;
  context: string;
  warehouse: string;
  search: string;
  output?: boolean;
}) {
  const [selection, setSelection] = useState("");
  const [unitId, setUnitId] = useState("");
  const [bucketId, setBucketId] = useState("");
  const [loaded, setLoaded] = useState<{
    product: ProductDetail;
    stock: Stock[];
    warehouse: string;
  }>();
  const [error, setError] = useState("");
  useEffect(() => {
    if (!selection) return;
    let active = true;
    const stock =
      !output && warehouse
        ? api<Stock[]>(
            `/inventory/stock?warehouseId=${warehouse}&itemId=${selection}`,
            {},
            context,
          )
        : Promise.resolve([]);
    void Promise.all([
      api<ProductDetail>(`/catalog/products/${selection}`, {}, context),
      stock,
    ])
      .then(([product, stock]) => {
        if (active) {
          setLoaded({ product, stock, warehouse });
          setError("");
        }
      })
      .catch((e) => {
        if (active) setError(errorText(e));
      });
    return () => {
      active = false;
    };
  }, [context, output, selection, warehouse]);

  const ready =
    loaded?.product.product.id === selection && loaded.warehouse === warehouse
      ? loaded
      : undefined;
  const product = ready?.product.product;
  const options = ready?.product.units.filter((u) => u.isActive) ?? [];
  const selectedUnit = options.find((u) => u.id === unitId) ?? options[0];
  const lots =
    ready?.stock.filter(
      (x) => x.available !== "0" && !x.available.startsWith("-"),
    ) ?? [];
  const lot = lots.find((x) => x.id === bucketId);
  const matching = products.filter(
    (x) =>
      x.id === selection ||
      `${x.sku} ${x.name}`.toLowerCase().includes(search.toLowerCase()),
  );

  return (
    <div className="settings-fields">
      <label className="auth-field">
        <span>{output ? "Output product" : "Material " + index}</span>
        <select
          name={`item-${index}`}
          aria-label={output ? "Output product" : "Material " + index}
          required
          value={selection}
          onChange={(e) => {
            setSelection(e.target.value);
            setUnitId("");
            setBucketId("");
            setError("");
          }}
        >
          <option value="">Select product</option>
          {matching.map((x) => (
            <option key={x.id} value={x.id}>
              {x.sku} · {x.name}
            </option>
          ))}
        </select>
      </label>
      <label className="auth-field">
        <span>{output ? "Output unit" : "Material unit " + index}</span>
        <select
          name={`unit-${index}`}
          aria-label={output ? "Output unit" : "Material unit " + index}
          required
          value={selectedUnit?.id ?? ""}
          onChange={(e) => setUnitId(e.target.value)}
        >
          <option value="">Select unit</option>
          {options.map((x) => (
            <option key={x.id} value={x.id}>
              {unitNames[x.unitId] ?? x.id}
            </option>
          ))}
        </select>
      </label>
      <input
        type="hidden"
        name={`product-version-${index}`}
        value={product?.version ?? ""}
      />
      <input
        type="hidden"
        name={`unit-version-${index}`}
        value={selectedUnit?.version ?? ""}
      />
      <label className="auth-field">
        <span>
          {output ? "Actual output quantity" : "Material quantity " + index}
        </span>
        <input name={`quantity-${index}`} inputMode="decimal" required />
      </label>
      {!output && (
        <label className="auth-field">
          <span>Input lot</span>
          <select
            name={`bucket-${index}`}
            value={lot?.id ?? ""}
            onChange={(e) => setBucketId(e.target.value)}
          >
            <option value="">Automatic FEFO</option>
            {lots.map((x) => (
              <option key={x.id} value={x.id}>
                {x.lot} · {x.available} {x.baseUnit} available
                {x.expiresOn ? " · expires " + x.expiresOn : ""}
              </option>
            ))}
          </select>
        </label>
      )}
      {!output && ready && (
        <p className="auth-help">
          {lots.length > 0
            ? lots
                .map((x) => `${x.lot}: ${x.available} ${x.baseUnit}`)
                .join(" · ")
            : "No eligible unreserved stock in the displayed lots."}
        </p>
      )}
      {output && product?.trackingMode === "LOT" && (
        <>
          <label className="auth-field">
            <span>New production lot</span>
            <input name="lot" maxLength={128} required />
          </label>
          <label className="auth-field">
            <span>Output expiry</span>
            <input
              name="expiry"
              type="date"
              required={product.expiryRequired}
            />
          </label>
        </>
      )}
      {error && <p role="alert">{error}</p>}
    </div>
  );
}

function AllocationTable({
  rows,
  trace,
}: {
  rows: Allocation[];
  trace?: (input: boolean, lot: string) => void;
}) {
  const cost = rows.some((x) => x.carriedValue !== undefined);
  return (
    <div className="organization-table-wrap">
      <table className="organization-table">
        <thead>
          <tr>
            <th>Material</th>
            <th>Entered group</th>
            <th>Lot and expiry</th>
            <th>Allocated base quantity</th>
            {cost && <th>Carried value</th>}
          </tr>
        </thead>
        <tbody>
          {rows.map((row, index) => (
            <tr key={index}>
              <td>
                {row.sku} · {row.product}
              </td>
              <td>
                {row.group}: {row.enteredQuantity} {row.unit} (× {row.factor})
              </td>
              <td>
                {row.lot === "SYSTEM" ? "SYSTEM (untracked)" : row.lot}{" "}
                {row.expiresOn}
                {trace && row.lot !== "SYSTEM" && (
                  <div className="inventory-controls">
                    <button
                      className="auth-text-link"
                      onClick={() => trace(false, row.lotId)}
                    >
                      Find producing run
                    </button>
                    <button
                      className="auth-text-link"
                      onClick={() => trace(true, row.lotId)}
                    >
                      Find consumption
                    </button>
                  </div>
                )}
              </td>
              <td>{row.baseQuantity}</td>
              {cost && <td>{row.carriedValue}</td>}
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}

export function ManufacturingPanel({
  session,
  currency,
  timezone,
}: {
  session: Session;
  currency: string;
  timezone: string;
}) {
  const context = session.contextVersion;
  const admin = session.memberships.some(
    (m) => m.id === session.selectedMembershipId && m.role === "ADMINISTRATOR",
  );
  const [warehouses, setWarehouses] = useState<Warehouse[]>([]);
  const [products, setProducts] = useState<Product[]>([]);
  const [unitNames, setUnitNames] = useState<Record<string, string>>({});
  const [outletNames, setOutletNames] = useState<Record<string, string>>({});
  const [warehouse, setWarehouse] = useState("");
  const [materials, setMaterials] = useState([1]);
  const [search, setSearch] = useState("");
  const [runs, setRuns] = useState<Run[]>([]);
  const [detail, setDetail] = useState<Detail>();
  const [filter, setFilter] = useState<{ input: boolean; lot: string }>();
  const [findings, setFindings] = useState<Finding[]>();
  const [pending, setPending] = useState<{
    body: string;
    preview: Preview;
    uncertain: boolean;
  }>();
  const [busy, setBusy] = useState(false);
  const [loading, setLoading] = useState(true);
  const [formVersion, setFormVersion] = useState(0);
  const [historyRevision, setHistoryRevision] = useState(0);
  const [error, setError] = useState("");
  const [notice, setNotice] = useState("");
  const date = new Intl.DateTimeFormat("sv-SE", { timeZone: timezone }).format(
    new Date(),
  );

  useEffect(() => {
    let live = true;
    void Promise.all([
      api<Warehouse[]>("/inventory/warehouses", {}, context),
      api<Product[]>("/catalog/products", {}, context),
      api<{ id: string; name: string }[]>("/catalog/units", {}, context),
      api<{ id: string; name: string }[]>("/organization/outlets", {}, context),
    ])
      .then(([warehouses, products, units, outlets]) => {
        if (live) {
          setWarehouses(warehouses);
          setProducts(products.filter((x) => x.isActive));
          setUnitNames(Object.fromEntries(units.map((x) => [x.id, x.name])));
          setOutletNames(
            Object.fromEntries(outlets.map((x) => [x.id, x.name])),
          );
        }
      })
      .catch((e) => {
        if (live) setError(errorText(e));
      })
      .finally(() => {
        if (live) setLoading(false);
      });
    return () => {
      live = false;
    };
  }, [context]);

  const history =
    path +
    "/runs?" +
    (filter ? `${filter.input ? "inputLot" : "outputLot"}=${filter.lot}` : "");
  useEffect(() => {
    let live = true;
    void api<Run[]>(history, {}, context)
      .then((r) => {
        if (live) setRuns(r);
      })
      .catch((e) => {
        if (live) setError(errorText(e));
      });
    return () => {
      live = false;
    };
  }, [context, history, historyRevision]);

  useEffect(() => {
    if (!pending?.uncertain && !(pending && busy)) return;
    const warning = (event: BeforeUnloadEvent) => event.preventDefault();
    window.addEventListener("beforeunload", warning);
    return () => window.removeEventListener("beforeunload", warning);
  }, [busy, pending]);

  function line(data: FormData, index: string) {
    const result = {
      itemId: text(data, `item-${index}`),
      itemUnitId: text(data, `unit-${index}`),
      itemVersion: text(data, `product-version-${index}`),
      unitVersion: text(data, `unit-version-${index}`),
      quantity: text(data, `quantity-${index}`),
    };
    if (!Object.values(result).every(Boolean))
      throw new Error("Choose a product and configured unit on each line.");
    return result;
  }

  async function preview(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (busy || pending) return;
    setError("");
    setNotice("");
    setBusy(true);
    const data = new FormData(event.currentTarget);
    try {
      const chosen = warehouses.find((x) => x.id === warehouse);
      if (!chosen) throw new Error("Choose an authorized warehouse.");
      const body = JSON.stringify({
        operationId: crypto.randomUUID(),
        warehouseId: chosen.id,
        warehouseVersion: chosen.version,
        expectedCurrency: currency,
        productionDate: text(data, "date"),
        reference: text(data, "reference") || null,
        notes: text(data, "notes") || null,
        materials: materials.map((i) => ({
          ...line(data, String(i)),
          bucketId: text(data, `bucket-${i}`) || null,
        })),
        output: {
          ...line(data, "output"),
          lotCode: text(data, "lot") || null,
          expiresOn: text(data, "expiry") || null,
        },
      });
      setPending({
        body,
        preview: await api<Preview>(
          path + "/preview",
          { method: "POST", body },
          context,
        ),
        uncertain: false,
      });
    } catch (e) {
      setError(errorText(e));
    } finally {
      setBusy(false);
    }
  }

  async function open(id: string) {
    try {
      setDetail(await api<Detail>(path + "/runs/" + id, {}, context));
    } catch (e) {
      setError(errorText(e));
    }
  }

  async function post() {
    if (!pending || busy) return;
    setBusy(true);
    setError("");
    try {
      const posted = await api<{ id: string; number: string }>(
        path + "/runs",
        { method: "POST", body: pending.body },
        context,
      );
      setPending(undefined);
      setNotice(`Posted ${posted.number}.`);
      setFilter(undefined);
      setHistoryRevision((x) => x + 1);
      setFormVersion((x) => x + 1);
      setMaterials([1]);
      await open(posted.id);
    } catch (e) {
      const uncertain =
        pending.uncertain || !(e instanceof ApiError) || e.status >= 500;
      setPending({ ...pending, uncertain });
      setError(
        uncertain
          ? "Posting is unconfirmed. Retry the exact operation before entering it again."
          : errorText(e),
      );
    } finally {
      setBusy(false);
    }
  }

  function trace(input: boolean, lot: string) {
    setFilter({ input, lot });
    setDetail(undefined);
  }

  const materialOptions = products.filter((x) =>
    ["RAW", "PACKAGING", "INTERMEDIATE"].includes(x.kind),
  );
  const outputs = products.filter(
    (x) =>
      x.manufactureEnabled && ["FINISHED", "INTERMEDIATE"].includes(x.kind),
  );

  return (
    <div className="inventory-panel">
      <header className="private-page-heading">
        <h1>Manufacturing</h1>
      </header>
      {error && (
        <p role="alert" className="auth-error">
          {error}
        </p>
      )}
      {notice && <p role="status">{notice}</p>}
      {loading && <p role="status">Loading manufacturing workspace…</p>}
      {!loading && warehouses.length === 0 && (
        <p>No active warehouse in this outlet context.</p>
      )}
      <section className="settings-card">
        <h2>New production run</h2>
        <form key={formVersion} onSubmit={preview}>
          <fieldset
            className="catalog-fields"
            disabled={busy || !!pending || loading}
          >
            <div className="settings-fields">
              <label className="auth-field">
                <span>Production warehouse</span>
                <select
                  aria-label="Production warehouse"
                  required
                  value={warehouse}
                  onChange={(e) => setWarehouse(e.target.value)}
                >
                  <option value="">Select warehouse</option>
                  {warehouses.map((x) => (
                    <option key={x.id} value={x.id}>
                      {outletNames[x.branchId]
                        ? outletNames[x.branchId] + " · "
                        : ""}
                      {x.name}
                    </option>
                  ))}
                </select>
              </label>
              <label className="auth-field">
                <span>Production date</span>
                <input
                  type="date"
                  name="date"
                  defaultValue={date}
                  max={date}
                  required
                />
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
              <span>Search materials</span>
              <input
                value={search}
                onChange={(e) => setSearch(e.target.value)}
              />
            </label>
            {materials.map((i) => (
              <fieldset className="catalog-unit-card" key={i}>
                <legend>Material line {i}</legend>
                <ProductQuantity
                  index={String(i)}
                  products={materialOptions}
                  unitNames={unitNames}
                  context={context}
                  warehouse={warehouse}
                  search={search}
                />
                {materials.length > 1 && (
                  <button
                    type="button"
                    className="auth-text-link"
                    onClick={() =>
                      setMaterials((rows) => rows.filter((x) => x !== i))
                    }
                  >
                    Remove material
                  </button>
                )}
              </fieldset>
            ))}
            <button
              type="button"
              className="auth-secondary"
              disabled={materials.length >= 50}
              onClick={() =>
                setMaterials((rows) => [...rows, Math.max(...rows) + 1])
              }
            >
              Add material
            </button>
            <fieldset className="catalog-unit-card">
              <legend>Good output</legend>
              <ProductQuantity
                index="output"
                output
                products={outputs}
                unitNames={unitNames}
                context={context}
                warehouse={warehouse}
                search=""
              />
            </fieldset>
            <button className="auth-primary" disabled={!warehouse}>
              Preview production
            </button>
          </fieldset>
        </form>
        {pending && (
          <section aria-label="Confirm manufacturing">
            <h3>Review production</h3>
            <p>
              The final posting checks current availability and recalculates
              allocations and cost.
            </p>
            <AllocationTable rows={pending.preview.materials} />
            <p>
              {pending.preview.outputSku} · {pending.preview.baseOutputQuantity}{" "}
              base units · {pending.preview.lot}
            </p>
            {pending.preview.totalCost !== undefined && (
              <p>
                Production cost {pending.preview.currency}{" "}
                {pending.preview.totalCost} ·{" "}
                {pending.preview.outputBaseUnitCost} per base unit
              </p>
            )}
            <div className="inventory-controls">
              <button
                className="auth-primary"
                onClick={() => void post()}
                disabled={busy}
              >
                {pending.uncertain
                  ? "Retry exact operation"
                  : "Confirm and post production"}
              </button>
              {!pending.uncertain && (
                <button
                  className="auth-secondary"
                  onClick={() => setPending(undefined)}
                  disabled={busy}
                >
                  Back to edit
                </button>
              )}
            </div>
          </section>
        )}
      </section>
      <section className="settings-card">
        <h2>Production history</h2>
        {filter && (
          <p>
            {filter.input
              ? "Consumption of selected lot"
              : "Origin of selected lot"}{" "}
            ·{" "}
            <button
              className="auth-text-link"
              onClick={() => setFilter(undefined)}
            >
              Clear trace
            </button>
          </p>
        )}
        {runs.length ? (
          <div className="organization-table-wrap">
            <table className="organization-table">
              <thead>
                <tr>
                  <th>Run</th>
                  <th>Warehouse</th>
                  <th>Output</th>
                  <th>Lot and expiry</th>
                  {admin && <th>Operational cost</th>}
                </tr>
              </thead>
              <tbody>
                {runs.map((r) => (
                  <tr key={r.id}>
                    <td>
                      <button
                        className="auth-text-link"
                        onClick={() => void open(r.id)}
                      >
                        {r.number}
                      </button>
                      <br />
                      {r.productionDate} {r.reference}
                    </td>
                    <td>{r.warehouse}</td>
                    <td>
                      {r.outputSku} · {r.outputQuantity} {r.outputUnit}
                    </td>
                    <td>
                      {r.tracked ? r.outputLot : "SYSTEM (untracked)"}{" "}
                      {r.expiresOn}
                    </td>
                    {admin && (
                      <td>
                        {r.totalCost === undefined
                          ? "—"
                          : `${r.currency} ${r.totalCost}`}
                      </td>
                    )}
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        ) : (
          <p>No matching production runs.</p>
        )}
        {runs.length === 50 && (
          <button
            className="auth-secondary"
            onClick={() =>
              void api<Run[]>(
                history + "&before=" + runs.at(-1)!.id,
                {},
                context,
              )
                .then(setRuns)
                .catch((e) => setError(errorText(e)))
            }
          >
            Older runs
          </button>
        )}
      </section>
      {detail && (
        <section className="settings-card" aria-label="Production details">
          <h2>{detail.run.number}</h2>
          <p>
            {detail.run.warehouse} · {detail.run.productionDate} ·{" "}
            {detail.operator}
          </p>
          <p>
            {detail.run.outputName} · {detail.run.outputQuantity}{" "}
            {detail.run.outputUnit} ({detail.run.baseOutputQuantity} base) ·{" "}
            {detail.run.tracked ? detail.run.outputLot : "SYSTEM (untracked)"}{" "}
            {detail.run.expiresOn}
          </p>
          {detail.notes && <p>{detail.notes}</p>}
          {detail.run.totalCost !== undefined && (
            <p>
              Total operational cost {detail.run.currency}{" "}
              {detail.run.totalCost} · {detail.run.outputBaseUnitCost} per base
              unit
            </p>
          )}
          {detail.run.tracked && (
            <button
              className="auth-text-link"
              onClick={() => trace(true, detail.run.outputLotId)}
            >
              Find runs consuming this output lot
            </button>
          )}
          <h3>Material allocations</h3>
          <AllocationTable rows={detail.materials} trace={trace} />
        </section>
      )}
      {admin && (
        <section className="settings-card">
          <button
            className="auth-secondary"
            onClick={() => {
              void api<Finding[]>(path + "/reconcile", {}, context)
                .then(setFindings)
                .catch((e) => setError(errorText(e)));
            }}
          >
            Check production reconciliation
          </button>
          {findings && (
            <div role="status">
              {findings.length ? (
                <ul>
                  {findings.map((f) => (
                    <li key={f.id}>
                      {f.kind} · record {f.id}
                    </li>
                  ))}
                </ul>
              ) : (
                "No production discrepancies found."
              )}
            </div>
          )}
        </section>
      )}
    </div>
  );
}
