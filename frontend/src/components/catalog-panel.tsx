"use client";
import {
  useEffect,
  useRef,
  useState,
  type FormEvent,
  type ReactNode,
} from "react";
import {
  api,
  ApiError,
  invalidateTabs,
  type Session,
} from "@/lib/api/identity";

type Kind = "products" | "categories" | "units" | "suppliers";
type Common = { id: string; name: string; isActive: boolean; version: string };
type Unit = Common & { code: string; dimension: string; isDiscrete: boolean };
type Category = Common & {
  code: string;
  description: string | null;
  parentId: string | null;
};
type Supplier = Common & {
  code: string;
  phone: string | null;
  email: string | null;
  address: string | null;
  contactPerson: string | null;
  notes?: string | null;
};
type Product = Common & {
  sku: string;
  description: string | null;
  categoryId: string | null;
  baseUnitId: string;
  kind: string;
  purchaseEnabled: boolean;
  saleEnabled: boolean;
  manufactureEnabled: boolean;
  trackingMode: string;
  expiryRequired: boolean;
};
type Row = Unit | Category | Supplier | Product;
type Barcode = {
  id: string;
  itemUnitId: string;
  value: string;
  isActive: boolean;
  version: string;
};
type ItemUnit = {
  id: string;
  unitId: string;
  toBaseFactor: string;
  purchasePrice?: string | null;
  sellingPrice: string | null;
  isPurchaseDefault: boolean;
  isSaleDefault: boolean;
  isActive: boolean;
  version: string;
};
type Detail = {
  product: Product;
  units: ItemUnit[];
  barcodes: Barcode[];
  currencyCode: string;
};
type DraftBarcode = {
  id: string | null;
  value: string;
  isActive: boolean;
  expectedVersion: string;
};
type DraftUnit = {
  id: string | null;
  unitId: string;
  toBaseFactor: string;
  purchasePrice: string;
  sellingPrice: string;
  isPurchaseDefault: boolean;
  isSaleDefault: boolean;
  isActive: boolean;
  expectedVersion: string;
  barcodes: DraftBarcode[];
};
const newUnit = (unitId = "", base = false): DraftUnit => ({
  id: null,
  unitId,
  toBaseFactor: "1",
  purchasePrice: "",
  sellingPrice: "",
  isPurchaseDefault: base,
  isSaleDefault: base,
  isActive: true,
  expectedVersion: "0",
  barcodes: [],
});
function Field({ label, children }: { label: string; children: ReactNode }) {
  return (
    <label className="auth-field">
      <span>{label}</span>
      {children}
    </label>
  );
}
function hasSku(row: Row): row is Product {
  return "sku" in row;
}

export function CatalogPanel({
  kind,
  session,
  currencyCode,
}: {
  kind: Kind;
  session: Session;
  currencyCode: string;
}) {
  const admin =
    session.memberships.find((m) => m.id === session.selectedMembershipId)
      ?.role === "ADMINISTRATOR";
  const [rows, setRows] = useState<Row[]>([]),
    [units, setUnits] = useState<Unit[]>([]),
    [categories, setCategories] = useState<Category[]>([]);
  const [loading, setLoading] = useState(true),
    [busy, setBusy] = useState(false),
    [error, setError] = useState("");
  const [query, setQuery] = useState(""),
    [status, setStatus] = useState("all"),
    [type, setType] = useState("all");
  const [editing, setEditing] = useState<Row | null>(null),
    [unitDrafts, setUnitDrafts] = useState<DraftUnit[]>([]),
    [baseId, setBaseId] = useState("");
  const dialog = useRef<HTMLDialogElement>(null);
  const [formKey, setFormKey] = useState(0);
  useEffect(() => {
    let live = true;
    void Promise.all([
      api<Row[]>(`/catalog/${kind}`, {}, session.contextVersion),
      api<Unit[]>("/catalog/units", {}, session.contextVersion),
      api<Category[]>("/catalog/categories", {}, session.contextVersion),
    ])
      .then(([r, u, c]) => {
        if (live) {
          setRows(r);
          setUnits(u);
          setCategories(c);
          setEditing(null);
          dialog.current?.close();
        }
      })
      .catch((e) => {
        if (live)
          setError(
            e instanceof Error ? e.message : "Could not load catalogue.",
          );
      })
      .finally(() => {
        if (live) setLoading(false);
      });
    return () => {
      live = false;
    };
  }, [kind, session.contextVersion]);
  async function refresh() {
    invalidateTabs();
    window.location.reload();
  }
  async function open(row: Row | null) {
    if (busy) return;
    setError("");
    setBusy(true);
    try {
      if (kind === "products" && row) {
        const d = await api<Detail>(
          `/catalog/products/${row.id}`,
          {},
          session.contextVersion,
        );
        setEditing(d.product);
        setBaseId(d.product.baseUnitId);
        setUnitDrafts(
          d.units.map((u) => ({
            id: u.id,
            unitId: u.unitId,
            toBaseFactor: u.toBaseFactor,
            purchasePrice: u.purchasePrice ?? "",
            sellingPrice: u.sellingPrice ?? "",
            isPurchaseDefault: u.isPurchaseDefault,
            isSaleDefault: u.isSaleDefault,
            isActive: u.isActive,
            expectedVersion: u.version,
            barcodes: d.barcodes
              .filter((b) => b.itemUnitId === u.id)
              .map((b) => ({
                id: b.id,
                value: b.value,
                isActive: b.isActive,
                expectedVersion: b.version,
              })),
          })),
        );
      } else {
        setEditing(row);
        setBaseId("");
        setUnitDrafts([newUnit("", true)]);
      }
      setFormKey((value) => value + 1);
      dialog.current?.showModal();
    } catch (e) {
      setError(e instanceof Error ? e.message : "Unable to open record.");
    } finally {
      setBusy(false);
    }
  }
  function updateUnit(index: number, change: Partial<DraftUnit>) {
    setUnitDrafts((all) =>
      all.map((u, i) => (i === index ? { ...u, ...change } : u)),
    );
  }
  async function save(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (!admin || busy) return;
    setError("");
    setBusy(true);
    const data = new FormData(event.currentTarget),
      text = (key: string) => String(data.get(key) ?? ""),
      flag = (key: string) => data.has(key);
    const common = {
      name: text("name"),
      isActive: flag("isActive"),
      expectedVersion: editing?.version ?? "0",
      reason: text("reason"),
    };
    let body: object;
    if (kind === "units")
      body = {
        ...common,
        code: text("code"),
        dimension: text("dimension"),
        isDiscrete: flag("isDiscrete"),
      };
    else if (kind === "categories")
      body = {
        ...common,
        code: text("code"),
        description: text("description"),
        parentId: text("parentId") || null,
      };
    else if (kind === "suppliers")
      body = {
        ...common,
        code: text("code"),
        phone: text("phone"),
        email: text("email"),
        address: text("address"),
        contactPerson: text("contactPerson"),
        notes: text("notes"),
      };
    else
      body = {
        ...common,
        sku: text("code"),
        description: text("description"),
        categoryId: text("categoryId") || null,
        baseUnitId: baseId,
        kind: text("kind"),
        purchaseEnabled: flag("purchaseEnabled"),
        saleEnabled: flag("saleEnabled"),
        manufactureEnabled: flag("manufactureEnabled"),
        trackingMode: text("trackingMode"),
        expiryRequired: flag("expiryRequired"),
        units: unitDrafts.map((u) => ({
          ...u,
          purchasePrice: u.purchasePrice.trim() || null,
          sellingPrice: u.sellingPrice.trim() || null,
        })),
      };
    try {
      await api(
        `/catalog/${kind}${editing ? `/${editing.id}` : ""}`,
        { method: editing ? "PUT" : "POST", body: JSON.stringify(body) },
        session.contextVersion,
      );
      dialog.current?.close();
      await refresh();
    } catch (e) {
      setError(e instanceof Error ? e.message : "Save failed.");
      if (e instanceof ApiError && e.code === "CONTEXT_CHANGED")
        dialog.current?.close();
    } finally {
      setBusy(false);
    }
  }
  const title = kind[0]!.toUpperCase() + kind.slice(1),
    singular = kind === "categories" ? "category" : kind.slice(0, -1);
  const filtered = rows.filter(
    (r) =>
      `${r.name} ${hasSku(r) ? r.sku : r.code}`
        .toLowerCase()
        .includes(query.toLowerCase()) &&
      (status === "all" || r.isActive === (status === "active")) &&
      (kind !== "products" || type === "all" || (hasSku(r) && r.kind === type)),
  );
  return (
    <>
      <div className="private-page-heading">
        <span className="auth-eyebrow">COMPANY CATALOGUE</span>
        <h1>{title}</h1>
        <p>
          {kind === "products"
            ? "Product identities, explicit units and price defaults. Stock is managed in a later milestone."
            : kind === "suppliers"
              ? "Supplier contacts for your business. No payable balances or accounting."
              : kind === "units"
                ? "Define measurements and whole-unit rules. Packaging factors belong to individual products."
                : "Keep your catalogue organized with simple categories."}
        </p>
      </div>
      {error && (
        <div className="auth-error" role="alert">
          {error}{" "}
          <button className="auth-text-link" onClick={refresh}>
            Refresh
          </button>
        </div>
      )}
      <section className="settings-card">
        <div className="organization-toolbar">
          <Field label={`Search ${kind}`}>
            <input
              value={query}
              onChange={(e) => setQuery(e.target.value)}
              placeholder="Name or code"
            />
          </Field>
          <Field label="Status">
            <select
              aria-label="Status"
              value={status}
              onChange={(e) => setStatus(e.target.value)}
            >
              <option value="all">All</option>
              <option value="active">Active</option>
              <option value="inactive">Inactive</option>
            </select>
          </Field>
          {kind === "products" && (
            <Field label="Product type">
              <select
                aria-label="Product type filter"
                value={type}
                onChange={(e) => setType(e.target.value)}
              >
                <option value="all">All types</option>
                {["RAW", "PACKAGING", "INTERMEDIATE", "FINISHED"].map((k) => (
                  <option key={k}>{k}</option>
                ))}
              </select>
            </Field>
          )}
          {admin && (
            <button
              className="auth-primary"
              disabled={busy || loading}
              onClick={() => void open(null)}
            >
              Add {singular}
            </button>
          )}
        </div>
        {kind === "units" && admin && (
          <p className="auth-help">
            Start with standard units, without any client products or packaging
            factors.{" "}
            <button
              className="auth-text-link"
              disabled={busy || loading}
              onClick={() => {
                setBusy(true);
                void api(
                  "/catalog/units/defaults",
                  { method: "POST" },
                  session.contextVersion,
                )
                  .then(refresh)
                  .catch((e) => {
                    setError(e instanceof Error ? e.message : "Setup failed.");
                    setBusy(false);
                  });
              }}
            >
              Set up standard units
            </button>
          </p>
        )}
        {loading ? (
          <p role="status">Loading {kind}…</p>
        ) : !filtered.length ? (
          <p className="organization-empty">
            {rows.length
              ? "No matching records."
              : `No ${kind} yet.${admin ? ` Add your first ${singular}.` : " Ask your Administrator to configure the catalogue."}`}
          </p>
        ) : (
          <div className="organization-table-wrap">
            <table className="organization-table">
              <thead>
                <tr>
                  <th>Name</th>
                  <th>{kind === "products" ? "SKU" : "Code"}</th>
                  <th>
                    {kind === "products"
                      ? "Type"
                      : kind === "units"
                        ? "Measure"
                        : "Details"}
                  </th>
                  <th>Status</th>
                  <th aria-label="Actions" />
                </tr>
              </thead>
              <tbody>
                {filtered.map((r) => (
                  <tr key={r.id}>
                    <td>
                      <strong>{r.name}</strong>
                    </td>
                    <td>{hasSku(r) ? r.sku : r.code}</td>
                    <td>
                      {hasSku(r)
                        ? r.kind
                        : "dimension" in r
                          ? `${r.dimension}${r.isDiscrete ? " · whole units" : ""}`
                          : "phone" in r
                            ? r.phone || "—"
                            : "parentId" in r && r.parentId
                              ? categories.find((c) => c.id === r.parentId)
                                  ?.name
                              : "—"}
                    </td>
                    <td>
                      <span
                        className={`org-badge ${r.isActive ? "active" : ""}`}
                      >
                        {r.isActive ? "Active" : "Inactive"}
                      </span>
                    </td>
                    <td>
                      <button
                        className="auth-text-link"
                        onClick={() => void open(r)}
                      >
                        {admin ? "Edit" : "View"}
                      </button>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </section>
      <dialog
        ref={dialog}
        className={`organization-dialog ${kind === "products" ? "catalog-product-dialog" : ""}`}
        aria-label={`${editing ? (admin ? "Edit" : "View") : "Add"} ${singular}`}
      >
        <div className="organization-dialog-heading">
          <h2>
            {editing ? (admin ? "Edit" : "View") : "Add"} {singular}
          </h2>
          <button
            type="button"
            className="auth-secondary"
            aria-label="Close dialog"
            disabled={busy}
            onClick={() => dialog.current?.close()}
          >
            ×
          </button>
        </div>
        {error && (
          <div className="auth-error" role="alert">
            {error}
          </div>
        )}
        <form onSubmit={save} key={formKey}>
          <fieldset disabled={!admin || busy} className="catalog-fields">
            <div className="settings-fields">
              <Field label="Name">
                <input
                  name="name"
                  required
                  maxLength={
                    kind === "units" ? 100 : kind === "categories" ? 150 : 200
                  }
                  defaultValue={editing?.name ?? ""}
                />
              </Field>
              <Field label={kind === "products" ? "SKU" : "Code"}>
                <input
                  name="code"
                  required
                  maxLength={kind === "units" ? 20 : 60}
                  defaultValue={
                    editing
                      ? hasSku(editing)
                        ? editing.sku
                        : editing.code
                      : ""
                  }
                />
              </Field>
            </div>
            {kind === "units" && (
              <>
                <Field label="Measurement dimension">
                  <select
                    name="dimension"
                    aria-label="Measurement dimension"
                    defaultValue={
                      editing && "dimension" in editing
                        ? editing.dimension
                        : "COUNT"
                    }
                  >
                    {["COUNT", "MASS", "VOLUME", "OTHER"].map((d) => (
                      <option key={d}>{d}</option>
                    ))}
                  </select>
                </Field>
                <label className="org-check">
                  <input
                    type="checkbox"
                    name="isDiscrete"
                    defaultChecked={
                      editing && "isDiscrete" in editing
                        ? editing.isDiscrete
                        : true
                    }
                  />
                  Whole-number quantities only
                </label>
                <p className="auth-help">
                  Referenced measurement semantics cannot change. Create another
                  unit for a different meaning.
                </p>
              </>
            )}
            {kind === "categories" && (
              <>
                <Field label="Parent category">
                  <select
                    name="parentId"
                    aria-label="Parent category"
                    defaultValue={
                      editing && "parentId" in editing
                        ? (editing.parentId ?? "")
                        : ""
                    }
                  >
                    <option value="">No parent</option>
                    {categories
                      .filter((c) => c.id !== editing?.id)
                      .map((c) => (
                        <option key={c.id} value={c.id}>
                          {c.name}
                          {c.isActive ? "" : " (inactive)"}
                        </option>
                      ))}
                  </select>
                </Field>
                <Field label="Description">
                  <textarea
                    name="description"
                    maxLength={500}
                    defaultValue={
                      editing && "description" in editing
                        ? (editing.description ?? "")
                        : ""
                    }
                  />
                </Field>
              </>
            )}
            {kind === "suppliers" && (
              <>
                <div className="settings-fields">
                  <Field label="Contact number">
                    <input
                      name="phone"
                      maxLength={50}
                      defaultValue={
                        editing && "phone" in editing
                          ? (editing.phone ?? "")
                          : ""
                      }
                    />
                  </Field>
                  <Field label="Email">
                    <input
                      name="email"
                      type="email"
                      maxLength={254}
                      defaultValue={
                        editing && "email" in editing
                          ? (editing.email ?? "")
                          : ""
                      }
                    />
                  </Field>
                </div>
                <Field label="Address">
                  <textarea
                    name="address"
                    maxLength={700}
                    defaultValue={
                      editing && "address" in editing
                        ? (editing.address ?? "")
                        : ""
                    }
                  />
                </Field>
                <details className="catalog-details">
                  <summary>Optional contact details</summary>
                  <Field label="Contact person">
                    <input
                      name="contactPerson"
                      maxLength={120}
                      defaultValue={
                        editing && "contactPerson" in editing
                          ? (editing.contactPerson ?? "")
                          : ""
                      }
                    />
                  </Field>
                  {admin && (
                    <Field label="Internal notes">
                      <textarea
                        name="notes"
                        maxLength={700}
                        defaultValue={
                          editing && "notes" in editing
                            ? (editing.notes ?? "")
                            : ""
                        }
                      />
                    </Field>
                  )}
                </details>
              </>
            )}
            {kind === "products" && (
              <>
                <div className="settings-fields">
                  <Field label="Category">
                    <select
                      name="categoryId"
                      aria-label="Category"
                      defaultValue={
                        editing && hasSku(editing)
                          ? (editing.categoryId ?? "")
                          : ""
                      }
                    >
                      <option value="">Uncategorized</option>
                      {categories.map((c) => (
                        <option key={c.id} value={c.id}>
                          {c.name}
                          {c.isActive ? "" : " (inactive)"}
                        </option>
                      ))}
                    </select>
                  </Field>
                  <Field label="Base unit">
                    <select
                      aria-label="Base unit"
                      required
                      value={baseId}
                      disabled={!!editing}
                      onChange={(e) => {
                        setBaseId(e.target.value);
                        setUnitDrafts((all) => {
                          const existing = all.find(
                            (u) => u.unitId === e.target.value,
                          );
                          return [
                            existing
                              ? { ...existing, toBaseFactor: "1" }
                              : newUnit(e.target.value, true),
                            ...all.filter(
                              (u) => u.unitId && u.unitId !== e.target.value,
                            ),
                          ];
                        });
                      }}
                    >
                      <option value="" disabled>
                        Select base unit
                      </option>
                      {units.map((u) => (
                        <option key={u.id} value={u.id}>
                          {u.name} ({u.code}){u.isActive ? "" : " · inactive"}
                        </option>
                      ))}
                    </select>
                  </Field>
                </div>
                <Field label="Product type">
                  <select
                    name="kind"
                    aria-label="Product type"
                    defaultValue={
                      editing && hasSku(editing) ? editing.kind : "FINISHED"
                    }
                  >
                    {["RAW", "PACKAGING", "INTERMEDIATE", "FINISHED"].map(
                      (k) => (
                        <option key={k}>{k}</option>
                      ),
                    )}
                  </select>
                </Field>
                <Field label="Description">
                  <textarea
                    name="description"
                    maxLength={700}
                    defaultValue={
                      editing && hasSku(editing)
                        ? (editing.description ?? "")
                        : ""
                    }
                  />
                </Field>
                <details className="catalog-details">
                  <summary>Operations, batch and expiry settings</summary>
                  {(
                    [
                      "purchaseEnabled",
                      "saleEnabled",
                      "manufactureEnabled",
                    ] as const
                  ).map((flag) => (
                    <label className="org-check" key={flag}>
                      <input
                        name={flag}
                        type="checkbox"
                        defaultChecked={
                          editing && hasSku(editing)
                            ? editing[flag]
                            : flag !== "manufactureEnabled"
                        }
                      />
                      {flag === "purchaseEnabled"
                        ? "Purchasing enabled"
                        : flag === "saleEnabled"
                          ? "Selling enabled"
                          : "Manufacturing output enabled"}
                    </label>
                  ))}
                  <Field label="Batch tracking">
                    <select
                      name="trackingMode"
                      aria-label="Batch tracking"
                      defaultValue={
                        editing && hasSku(editing)
                          ? editing.trackingMode
                          : "NONE"
                      }
                    >
                      <option value="NONE">Not batch tracked</option>
                      <option value="LOT">Lot / batch tracked</option>
                    </select>
                  </Field>
                  <label className="org-check">
                    <input
                      name="expiryRequired"
                      type="checkbox"
                      defaultChecked={
                        editing && hasSku(editing)
                          ? editing.expiryRequired
                          : false
                      }
                    />
                    Expiry date required (requires lot tracking)
                  </label>
                </details>
                <details className="catalog-details" open={!!editing}>
                  <summary>Units, prices & barcodes</summary>
                  <p className="auth-help">
                    Factors and prices are exact decimal strings. Blank price =
                    unset; 0 = explicitly zero. Prices use {currencyCode}. First
                    configured price locks company currency. Base unit identity
                    stays fixed. Packaging of a different SKU requires
                    manufacturing, not a unit conversion.
                  </p>
                  {unitDrafts.map((u, index) => (
                    <section
                      className="catalog-unit-card"
                      key={u.id ?? `new-${index}`}
                    >
                      <div className="settings-fields">
                        <Field label={`Unit ${index + 1}`}>
                          <select
                            aria-label={`Unit ${index + 1}`}
                            required
                            disabled={!!u.id || u.unitId === baseId}
                            value={u.unitId}
                            onChange={(e) =>
                              updateUnit(index, { unitId: e.target.value })
                            }
                          >
                            <option value="" disabled>
                              Select unit
                            </option>
                            {units.map((m) => (
                              <option key={m.id} value={m.id}>
                                {m.name} ({m.code})
                              </option>
                            ))}
                          </select>
                        </Field>
                        <Field label={`Conversion factor ${index + 1}`}>
                          <input
                            aria-label={`Conversion factor ${index + 1}`}
                            inputMode="decimal"
                            required
                            value={u.toBaseFactor}
                            readOnly={u.unitId === baseId}
                            onChange={(e) =>
                              updateUnit(index, {
                                toBaseFactor: e.target.value,
                              })
                            }
                          />
                        </Field>
                        {admin && (
                          <Field label={`Purchase price ${index + 1}`}>
                            <input
                              aria-label={`Purchase price ${index + 1}`}
                              inputMode="decimal"
                              placeholder="Unset"
                              value={u.purchasePrice}
                              onChange={(e) =>
                                updateUnit(index, {
                                  purchasePrice: e.target.value,
                                })
                              }
                            />
                          </Field>
                        )}
                        <Field label={`Selling price ${index + 1}`}>
                          <input
                            aria-label={`Selling price ${index + 1}`}
                            inputMode="decimal"
                            placeholder="Unset"
                            value={u.sellingPrice}
                            onChange={(e) =>
                              updateUnit(index, {
                                sellingPrice: e.target.value,
                              })
                            }
                          />
                        </Field>
                      </div>
                      <div className="catalog-defaults">
                        <label>
                          <input
                            type="radio"
                            name="purchaseDefault"
                            checked={u.isPurchaseDefault}
                            onChange={() =>
                              setUnitDrafts((all) =>
                                all.map((v, i) => ({
                                  ...v,
                                  isPurchaseDefault: i === index,
                                })),
                              )
                            }
                          />
                          Default purchase
                        </label>
                        <label>
                          <input
                            type="radio"
                            name="saleDefault"
                            checked={u.isSaleDefault}
                            onChange={() =>
                              setUnitDrafts((all) =>
                                all.map((v, i) => ({
                                  ...v,
                                  isSaleDefault: i === index,
                                })),
                              )
                            }
                          />
                          Default sale
                        </label>
                        <label>
                          <input
                            type="checkbox"
                            checked={u.isActive}
                            disabled={u.unitId === baseId}
                            onChange={(e) =>
                              updateUnit(index, {
                                isActive: e.target.checked,
                                ...(!e.target.checked
                                  ? {
                                      isPurchaseDefault: false,
                                      isSaleDefault: false,
                                    }
                                  : {}),
                              })
                            }
                          />
                          Active unit
                        </label>
                      </div>
                      {u.barcodes.map((b, bi) => (
                        <div
                          className="catalog-barcode-row"
                          key={b.id ?? `new-${bi}`}
                        >
                          <Field label={`Barcode ${index + 1}.${bi + 1}`}>
                            <input
                              aria-label={`Barcode ${index + 1}.${bi + 1}`}
                              required
                              maxLength={128}
                              autoComplete="off"
                              spellCheck={false}
                              value={b.value}
                              onChange={(e) =>
                                updateUnit(index, {
                                  barcodes: u.barcodes.map((v, i) =>
                                    i === bi
                                      ? { ...v, value: e.target.value }
                                      : v,
                                  ),
                                })
                              }
                            />
                          </Field>
                          <label className="org-check">
                            <input
                              type="checkbox"
                              checked={b.isActive}
                              onChange={(e) =>
                                updateUnit(index, {
                                  barcodes: u.barcodes.map((v, i) =>
                                    i === bi
                                      ? { ...v, isActive: e.target.checked }
                                      : v,
                                  ),
                                })
                              }
                            />
                            Active barcode
                          </label>
                          {!b.id && (
                            <button
                              type="button"
                              className="auth-text-link"
                              onClick={() =>
                                updateUnit(index, {
                                  barcodes: u.barcodes.filter(
                                    (v, i) => i !== bi,
                                  ),
                                })
                              }
                            >
                              Remove
                            </button>
                          )}
                        </div>
                      ))}
                      <button
                        type="button"
                        className="auth-text-link"
                        onClick={() =>
                          updateUnit(index, {
                            barcodes: [
                              ...u.barcodes,
                              {
                                id: null,
                                value: "",
                                isActive: true,
                                expectedVersion: "0",
                              },
                            ],
                          })
                        }
                      >
                        Add barcode to unit {index + 1}
                      </button>
                      {!u.id && u.unitId !== baseId && (
                        <button
                          type="button"
                          className="auth-text-link catalog-remove"
                          onClick={() =>
                            setUnitDrafts((all) =>
                              all.filter((v, i) => i !== index),
                            )
                          }
                        >
                          Remove new unit
                        </button>
                      )}
                    </section>
                  ))}
                  <button
                    type="button"
                    className="auth-secondary"
                    onClick={() => setUnitDrafts((all) => [...all, newUnit()])}
                  >
                    Add alternative unit
                  </button>
                  <p className="auth-help">
                    Each enabled purchase/sale operation needs exactly one
                    active default. Before disabling an operation, clear its
                    default below.
                  </p>
                  <div className="catalog-defaults">
                    <button
                      type="button"
                      className="auth-text-link"
                      onClick={() =>
                        setUnitDrafts((all) =>
                          all.map((v) => ({ ...v, isPurchaseDefault: false })),
                        )
                      }
                    >
                      Clear purchase default
                    </button>
                    <button
                      type="button"
                      className="auth-text-link"
                      onClick={() =>
                        setUnitDrafts((all) =>
                          all.map((v) => ({ ...v, isSaleDefault: false })),
                        )
                      }
                    >
                      Clear sale default
                    </button>
                  </div>
                </details>
              </>
            )}
            <label className="org-check">
              <input
                name="isActive"
                type="checkbox"
                defaultChecked={editing?.isActive ?? true}
              />
              Active
            </label>
            {admin && (
              <>
                <Field label="Reason">
                  <input
                    name="reason"
                    required
                    maxLength={300}
                    placeholder="Reason for this change"
                  />
                </Field>
                {editing && (
                  <label className="org-check">
                    <input type="checkbox" required />I confirm these catalogue
                    changes.
                  </label>
                )}
                <button className="auth-primary" disabled={busy}>
                  {busy ? "Saving…" : editing ? "Save changes" : "Create"}
                </button>
              </>
            )}
          </fieldset>
          {!admin && (
            <button
              type="button"
              className="auth-secondary"
              onClick={() => dialog.current?.close()}
            >
              Close
            </button>
          )}
        </form>
      </dialog>
    </>
  );
}
