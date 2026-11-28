"use client";
import { useEffect, useRef, useState, type FormEvent } from "react";
import {
  api,
  ApiError,
  invalidateTabs,
  type Session,
} from "@/lib/api/identity";

export type Outlet = {
  id: string;
  code: string;
  name: string;
  address: string | null;
  phone: string | null;
  description: string | null;
  isActive: boolean;
  version: string;
};
type Warehouse = {
  id: string;
  branchId: string;
  code: string;
  name: string;
  description: string | null;
  isActive: boolean;
  isDefault: boolean;
  version: string;
};
type Member = {
  membershipId: string;
  displayName: string;
  email: string;
  role: string;
  isActive: boolean;
  identityEnabled: boolean;
  mustChangePassword: boolean;
  version: string;
  branchIds: string[];
};
export type OutletContext = {
  selectedBranchId: string | null;
  contextVersion: string;
  outlets: Outlet[];
};
type Kind = "outlets" | "warehouses" | "users";
type Row = Outlet | Warehouse | Member;
const isMember = (r: Row): r is Member => "membershipId" in r;
const isWarehouse = (r: Row): r is Warehouse => "branchId" in r;
const reload = () => {
  invalidateTabs();
  window.location.reload();
};

export function OutletSelector({ session }: { session: Session }) {
  const [context, setContext] = useState<OutletContext | null>(null);
  const [error, setError] = useState("");
  const [busy, setBusy] = useState(false);
  useEffect(() => {
    let live = true;
    void api<OutletContext>("/organization/context", {}, session.contextVersion)
      .then((c) => {
        if (live) setContext(c);
      })
      .catch((e) => {
        if (
          live &&
          !(e instanceof ApiError && e.code === "ORGANIZATION_UNAVAILABLE")
        )
          if (e instanceof ApiError && e.code === "CONTEXT_CHANGED")
            window.location.reload();
          else
            setError(
              e instanceof Error ? e.message : "Outlet selection unavailable.",
            );
      });
    return () => {
      live = false;
    };
  }, [session.contextVersion]);
  if (error)
    return (
      <p className="outlet-context-error" role="status">
        {error} <button onClick={reload}>Refresh</button>
      </p>
    );
  if (!context) return null;
  if (!context.outlets.length)
    return (
      <span className="outlet-empty">
        No active outlets available
        {session.memberships.find((m) => m.id === session.selectedMembershipId)
          ?.role === "ADMINISTRATOR"
          ? " — create an outlet in Settings."
          : " — ask your Administrator for access."}
      </span>
    );
  const admin =
    session.memberships.find((m) => m.id === session.selectedMembershipId)
      ?.role === "ADMINISTRATOR";
  return (
    <label className="outlet-selector">
      <span>Working outlet</span>
      <select
        aria-label="Working outlet"
        value={context.selectedBranchId ?? ""}
        disabled={busy}
        onChange={(e) => {
          setBusy(true);
          void api<OutletContext>(
            "/organization/context",
            {
              method: "POST",
              body: JSON.stringify({ branchId: e.target.value || null }),
            },
            session.contextVersion,
          )
            .then(reload)
            .catch((e) => {
              setError(e instanceof Error ? e.message : "Selection failed.");
              setBusy(false);
            });
        }}
      >
        {admin ? (
          <option value="">All outlets · management</option>
        ) : (
          <option value="" disabled>
            Choose an assigned outlet
          </option>
        )}
        {context.outlets.map((b) => (
          <option key={b.id} value={b.id}>
            {b.name}
          </option>
        ))}
      </select>
    </label>
  );
}

export function OrganizationPanel({
  kind,
  session,
}: {
  kind: Kind;
  session: Session;
}) {
  const [rows, setRows] = useState<Row[]>([]);
  const [outlets, setOutlets] = useState<Outlet[]>([]);
  const [warehouses, setWarehouses] = useState<Warehouse[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  const [busy, setBusy] = useState(false);
  const [query, setQuery] = useState("");
  const [status, setStatus] = useState("all");
  const [editing, setEditing] = useState<Row | null>(null);
  const [credential, setCredential] = useState<{
    email: string;
    temporaryPassword: string;
  } | null>(null);
  const dialog = useRef<HTMLDialogElement>(null);
  const handoff = useRef<HTMLDialogElement>(null);
  const admin =
    session.memberships.find((m) => m.id === session.selectedMembershipId)
      ?.role === "ADMINISTRATOR";
  useEffect(() => {
    let live = true;
    setTimeout(() => {
      if (live) setLoading(true);
    }, 0);
    void Promise.all([
      api<Row[]>(`/organization/${kind}`, {}, session.contextVersion),
      api<Outlet[]>("/organization/outlets", {}, session.contextVersion),
      kind === "warehouses"
        ? api<Warehouse[]>(
            "/organization/warehouses",
            {},
            session.contextVersion,
          )
        : Promise.resolve([]),
    ])
      .then(([r, o, w]) => {
        if (live) {
          setRows(r);
          setOutlets(o);
          setWarehouses(w);
        }
      })
      .catch((e) => {
        if (live)
          setError(e instanceof Error ? e.message : "Could not load records.");
      })
      .finally(() => {
        if (live) setLoading(false);
      });
    return () => {
      live = false;
    };
  }, [kind, session.contextVersion]);
  const title =
    kind === "outlets"
      ? "Outlets"
      : kind === "warehouses"
        ? "Warehouses"
        : "Users & outlet access";
  const open = (row: Row | null) => {
    setEditing(row);
    setError("");
    dialog.current?.showModal();
  };
  async function save(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (busy) return;
    setBusy(true);
    setError("");
    const data = new FormData(event.currentTarget);
    const str = (key: string) => String(data.get(key) ?? "");
    const checked = (key: string) => data.has(key);
    const branchIds = data.getAll("branchIds").map(String);
    let body: object;
    if (kind === "users")
      body = editing
        ? {
            role: str("role"),
            isActive: checked("isActive"),
            branchIds,
            expectedVersion: editing.version,
            reason: str("reason"),
          }
        : {
            email: str("email"),
            displayName: str("displayName"),
            branchIds,
            reason: str("reason"),
          };
    else if (kind === "outlets")
      body = {
        code: str("code"),
        name: str("name"),
        address: str("address"),
        phone: str("phone"),
        description: str("description"),
        isActive: editing ? checked("isActive") : true,
        expectedVersion: editing?.version ?? "0",
        reason: str("reason"),
      };
    else
      body = {
        branchId: str("branchId"),
        code: str("code"),
        name: str("name"),
        description: str("description"),
        isActive: checked("isActive"),
        isDefault: checked("isDefault"),
        replacementWarehouseId: str("replacement") || null,
        expectedVersion: editing?.version ?? "0",
        reason: str("reason"),
      };
    try {
      const id = editing
        ? isMember(editing)
          ? editing.membershipId
          : editing.id
        : null;
      const result = await api<{ email: string; temporaryPassword: string }>(
        `/organization/${kind}${id ? `/${id}` : ""}`,
        { method: editing ? "PUT" : "POST", body: JSON.stringify(body) },
        session.contextVersion,
      );
      dialog.current?.close();
      if (kind === "users" && !editing) {
        setCredential(result);
        handoff.current?.showModal();
        invalidateTabs();
      } else reload();
    } catch (e) {
      setError(e instanceof Error ? e.message : "Save failed.");
    } finally {
      setBusy(false);
    }
  }
  const filtered = rows.filter((r) => {
    const label = isMember(r)
      ? `${r.displayName} ${r.email} ${r.role}`
      : `${r.name} ${r.code}`;
    return (
      label.toLowerCase().includes(query.toLowerCase()) &&
      (status === "all" || (status === "active") === r.isActive)
    );
  });
  return (
    <>
      <div className="private-page-heading">
        <span className="auth-eyebrow">BUSINESS SETTINGS</span>
        <h1>{title}</h1>
        <p>
          {kind === "outlets"
            ? "Your shops, factory and business locations."
            : kind === "warehouses"
              ? "Organize ordinary storage within each outlet. Stock quantities are introduced later."
              : "Manage membership roles and Staff outlet assignments for this business."}
        </p>
      </div>
      {error && (
        <div className="auth-error" role="alert">
          {error}{" "}
          <button className="auth-text-link" onClick={reload}>
            Refresh
          </button>
        </div>
      )}
      {!admin ? (
        <section className="settings-card">
          <h2>Administrator access required</h2>
        </section>
      ) : (
        <section className="settings-card">
          <div className="organization-toolbar">
            <label className="auth-field">
              <span>Search {kind}</span>
              <input
                value={query}
                onChange={(e) => setQuery(e.target.value)}
                placeholder="Search by name or code"
              />
            </label>
            <label className="auth-field">
              <span>Status</span>
              <select
                value={status}
                onChange={(e) => setStatus(e.target.value)}
              >
                <option value="all">All</option>
                <option value="active">Active</option>
                <option value="inactive">Inactive</option>
              </select>
            </label>
            <button className="auth-primary" onClick={() => open(null)}>
              {kind === "users"
                ? "Add Staff"
                : kind === "outlets"
                  ? "Add outlet"
                  : "Add warehouse"}
            </button>
          </div>
          {loading ? (
            <p role="status">Loading {kind}…</p>
          ) : !filtered.length ? (
            <p className="organization-empty">
              {rows.length
                ? "No matching records."
                : `No ${kind} yet. Add your first ${kind === "users" ? "Staff member" : kind === "outlets" ? "outlet" : "warehouse"}.`}
            </p>
          ) : (
            <div className="organization-table-wrap">
              <table className="organization-table">
                <thead>
                  <tr>
                    <th>{kind === "users" ? "User" : "Name"}</th>
                    <th>{kind === "users" ? "Role" : "Code"}</th>
                    {kind !== "outlets" && (
                      <th>{kind === "users" ? "Outlet access" : "Outlet"}</th>
                    )}
                    <th>Status</th>
                    <th>
                      <span className="sr-only">Actions</span>
                    </th>
                  </tr>
                </thead>
                <tbody>
                  {filtered.map((r) => (
                    <tr key={isMember(r) ? r.membershipId : r.id}>
                      <td>
                        <strong>{isMember(r) ? r.displayName : r.name}</strong>
                        <small>
                          {isMember(r)
                            ? r.email
                            : isWarehouse(r) && r.isDefault
                              ? "Default warehouse"
                              : ""}
                        </small>
                      </td>
                      <td>{isMember(r) ? r.role : r.code}</td>
                      {kind !== "outlets" && (
                        <td>
                          {isMember(r)
                            ? r.role === "ADMINISTRATOR"
                              ? "All ordinary outlets"
                              : r.branchIds
                                  .map(
                                    (id) =>
                                      outlets.find((b) => b.id === id)?.name ??
                                      "Inactive outlet",
                                  )
                                  .join(", ") || "No outlet access"
                            : isWarehouse(r)
                              ? outlets.find((b) => b.id === r.branchId)?.name
                              : ""}
                        </td>
                      )}
                      <td>
                        <span
                          className={`org-badge ${r.isActive ? "active" : ""}`}
                        >
                          {r.isActive ? "Active" : "Inactive"}
                        </span>
                        {isMember(r) &&
                          (!r.identityEnabled || r.mustChangePassword) && (
                            <small>
                              {!r.identityEnabled
                                ? "Identity disabled by SysConex"
                                : "Password change required"}
                            </small>
                          )}
                      </td>
                      <td>
                        <button
                          className="auth-text-link"
                          onClick={() => open(r)}
                        >
                          Edit
                        </button>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}
        </section>
      )}
      <dialog
        ref={dialog}
        className="organization-dialog"
        onCancel={() => {
          setEditing(null);
          setError("");
        }}
      >
        <div className="organization-dialog-heading">
          <h2>
            {editing ? "Edit" : "Add"}{" "}
            {kind === "users"
              ? editing
                ? "membership"
                : "Staff member"
              : kind === "outlets"
                ? "outlet"
                : "warehouse"}
          </h2>
          <button
            type="button"
            className="auth-secondary"
            disabled={busy}
            onClick={() => dialog.current?.close()}
            aria-label="Close dialog"
          >
            ×
          </button>
        </div>
        {error && (
          <div className="auth-error" role="alert">
            {error}
          </div>
        )}
        <form
          onSubmit={save}
          key={
            editing
              ? isMember(editing)
                ? editing.membershipId
                : editing.id
              : "new"
          }
        >
          {kind === "users" ? (
            <>
              {!editing ? (
                <>
                  <label className="auth-field">
                    <span>Display name</span>
                    <input name="displayName" required maxLength={120} />
                  </label>
                  <label className="auth-field">
                    <span>Email address</span>
                    <input
                      name="email"
                      type="email"
                      required
                      maxLength={254}
                      autoComplete="off"
                    />
                  </label>
                  <p className="auth-help">
                    A unique temporary password is generated once after
                    creation. Existing global identities require verified
                    SysConex linkage.
                  </p>
                </>
              ) : (
                <>
                  <p className="auth-help">
                    {isMember(editing) ? editing.email : ""}. Identity passwords
                    and global disabling remain controlled by SysConex.
                  </p>
                  <label className="auth-field">
                    <span>Role</span>
                    <select
                      name="role"
                      defaultValue={isMember(editing) ? editing.role : "STAFF"}
                    >
                      <option value="ADMINISTRATOR">Administrator</option>
                      <option value="STAFF">Staff</option>
                    </select>
                  </label>
                </>
              )}
              <fieldset className="org-grants">
                <legend>Staff outlet assignments</legend>
                <p>
                  Administrators can access all ordinary outlets. Staff need
                  explicit active assignments.
                </p>
                {outlets
                  .filter((b) => b.isActive)
                  .map((b) => (
                    <label key={b.id}>
                      <input
                        type="checkbox"
                        name="branchIds"
                        value={b.id}
                        defaultChecked={
                          editing && isMember(editing)
                            ? editing.branchIds.includes(b.id)
                            : false
                        }
                      />
                      {b.name}
                    </label>
                  ))}
                {!outlets.some((b) => b.isActive) && (
                  <p>Create an active outlet before assigning access.</p>
                )}
              </fieldset>
            </>
          ) : (
            <>
              {kind === "warehouses" && (
                <label className="auth-field">
                  <span>Outlet</span>
                  <select
                    name="branchId"
                    required
                    defaultValue={
                      editing && isWarehouse(editing) ? editing.branchId : ""
                    }
                    disabled={!!editing}
                  >
                    <option value="" disabled>
                      Select outlet
                    </option>
                    {outlets
                      .filter(
                        (b) =>
                          b.isActive ||
                          (editing &&
                            isWarehouse(editing) &&
                            editing.branchId === b.id),
                      )
                      .map((b) => (
                        <option key={b.id} value={b.id}>
                          {b.name}
                        </option>
                      ))}
                  </select>
                  {editing && isWarehouse(editing) && (
                    <input
                      type="hidden"
                      name="branchId"
                      value={editing.branchId}
                    />
                  )}
                </label>
              )}
              <label className="auth-field">
                <span>Name</span>
                <input
                  name="name"
                  required
                  maxLength={200}
                  defaultValue={
                    editing && !isMember(editing) ? editing.name : ""
                  }
                />
              </label>
              <label className="auth-field">
                <span>Code</span>
                <input
                  name="code"
                  required
                  maxLength={kind === "outlets" ? 40 : 60}
                  pattern="[A-Za-z0-9_-]+"
                  defaultValue={
                    editing && !isMember(editing) ? editing.code : ""
                  }
                />
              </label>
              {kind === "outlets" && (
                <>
                  <label className="auth-field">
                    <span>Address</span>
                    <textarea
                      name="address"
                      maxLength={700}
                      defaultValue={
                        editing && !isMember(editing) && !isWarehouse(editing)
                          ? (editing.address ?? "")
                          : ""
                      }
                    />
                  </label>
                  <label className="auth-field">
                    <span>Contact number</span>
                    <input
                      name="phone"
                      maxLength={50}
                      defaultValue={
                        editing && !isMember(editing) && !isWarehouse(editing)
                          ? (editing.phone ?? "")
                          : ""
                      }
                    />
                  </label>
                </>
              )}
              <label className="auth-field">
                <span>Description</span>
                <textarea
                  name="description"
                  maxLength={500}
                  defaultValue={
                    editing && !isMember(editing)
                      ? (editing.description ?? "")
                      : ""
                  }
                />
              </label>
              {kind === "warehouses" && (
                <>
                  <label className="org-check">
                    <input
                      type="checkbox"
                      name="isDefault"
                      defaultChecked={
                        editing && isWarehouse(editing)
                          ? editing.isDefault
                          : false
                      }
                    />
                    Default warehouse for this outlet
                  </label>
                  {editing && isWarehouse(editing) && editing.isDefault && (
                    <label className="auth-field">
                      <span>
                        Replacement default (required if clearing default or
                        deactivating)
                      </span>
                      <select name="replacement">
                        <option value="">Choose replacement</option>
                        {warehouses
                          .filter(
                            (w) =>
                              w.branchId === editing.branchId &&
                              w.id !== editing.id &&
                              w.isActive,
                          )
                          .map((w) => (
                            <option key={w.id} value={w.id}>
                              {w.name}
                            </option>
                          ))}
                      </select>
                    </label>
                  )}
                  <p className="auth-help">
                    STORAGE, HOLD and DAMAGED locations are initialized
                    automatically. Internal transit is system-managed.
                  </p>
                </>
              )}
            </>
          )}
          {(editing || kind === "warehouses") && (
            <label className="org-check">
              <input
                name="isActive"
                type="checkbox"
                defaultChecked={editing ? editing.isActive : true}
              />
              Active
            </label>
          )}
          <label className="auth-field">
            <span>Reason</span>
            <input
              name="reason"
              required
              maxLength={300}
              placeholder="Reason for this change"
            />
          </label>
          {editing && (
            <label className="org-check">
              <input type="checkbox" required />I confirm this change. Outlet
              deactivation also disables its warehouses and grants.
            </label>
          )}
          <button className="auth-primary" disabled={busy}>
            {busy ? "Saving…" : editing ? "Save changes" : "Create"}
          </button>
        </form>
      </dialog>
      <dialog
        ref={handoff}
        aria-label="Staff account created"
        className="organization-dialog"
        onCancel={(e) => {
          e.preventDefault();
          setCredential(null);
          reload();
        }}
      >
        <h2>Staff account created</h2>
        <p className="auth-help">
          Hand this credential privately to the verified person. It is shown
          once and must be changed at first login.
        </p>
        <label className="auth-field">
          <span>Email</span>
          <input readOnly value={credential?.email ?? ""} />
        </label>
        <label className="auth-field">
          <span>Temporary password</span>
          <input
            readOnly
            value={credential?.temporaryPassword ?? ""}
            autoComplete="off"
          />
        </label>
        <button
          className="auth-primary"
          onClick={() => {
            setCredential(null);
            reload();
          }}
        >
          I have handed it over securely
        </button>
      </dialog>
    </>
  );
}
