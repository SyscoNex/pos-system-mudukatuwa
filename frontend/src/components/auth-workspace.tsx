"use client";

import {
  useEffect,
  useRef,
  useState,
  type FormEvent,
  type ReactNode,
} from "react";
import Link from "next/link";
import Image from "next/image";
import { useRouter } from "next/navigation";
import {
  ArrowRight,
  Building2,
  Check,
  ChevronDown,
  CircleUserRound,
  KeyRound,
  LayoutGrid,
  LogOut,
  ShieldCheck,
} from "lucide-react";
import {
  api,
  ApiError,
  invalidateTabs,
  sessionInvalidations,
  safeReturnPath,
  type Business,
  type Session,
} from "@/lib/api/identity";

import {
  OrganizationPanel,
  OutletSelector,
  type OutletContext,
} from "./organization-panel";
import { CatalogPanel } from "./catalog-panel";
import { InventoryPanel, type InventoryMode } from "./inventory-panel";
type Mode =
  | "login"
  | "home"
  | "business"
  | "password"
  | "select"
  | "outlets"
  | "warehouses"
  | "users"
  | "products"
  | "categories"
  | "units"
  | "suppliers"
  | InventoryMode;
function Brand() {
  return (
    <Link href="/" className="auth-brand" aria-label="Conex360 home">
      <span className="brand-mark" aria-hidden="true">
        <span />
      </span>
      <span>
        Conex<span className="brand-360">360</span>
      </span>
    </Link>
  );
}
function Field({ label, children }: { label: string; children: ReactNode }) {
  return (
    <label className="auth-field">
      <span>{label}</span>
      {children}
    </label>
  );
}

export function AuthWorkspace({
  mode,
  inventoryDocumentId,
}: {
  mode: Mode;
  inventoryDocumentId?: string;
}) {
  const router = useRouter();
  const [session, setSession] = useState<Session | null>(null);
  const [business, setBusiness] = useState<Business | null>(null);
  const [currencies, setCurrencies] = useState<string[]>([]);
  const [loading, setLoading] = useState(true);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState("");
  const [notice, setNotice] = useState("");
  const generation = useRef(0);
  const lastActivity = useRef(0);
  useEffect(() => {
    let live = true;
    const load = async (reset = false) => {
      const current = ++generation.current;
      if (reset) {
        setSession(null);
        setBusiness(null);
        setLoading(true);
      }
      try {
        let s = await api<Session>("/auth/session");
        if (!live || current !== generation.current) return;
        if (mode === "login") {
          router.replace(
            s.user.mustChangePassword
              ? "/account/password"
              : s.selectedMembershipId
                ? "/app"
                : "/select-business",
          );
          return;
        }
        if (s.user.mustChangePassword && mode !== "password") {
          router.replace("/account/password");
          return;
        }
        if (
          !s.selectedMembershipId &&
          mode !== "password" &&
          mode !== "select"
        ) {
          router.replace("/select-business");
          return;
        }
        if (s.selectedMembershipId && !s.user.mustChangePassword) {
          try {
            const outlets = await api<OutletContext>(
              "/organization/context",
              {},
              s.contextVersion,
            );
            if (!live || current !== generation.current) return;
            if (outlets.outlets.length === 1 && !outlets.selectedBranchId) {
              await api<OutletContext>(
                "/organization/context",
                {
                  method: "POST",
                  body: JSON.stringify({ branchId: outlets.outlets[0]!.id }),
                },
                s.contextVersion,
              );
              s = await api<Session>("/auth/session");
            }
          } catch (e) {
            if (!(
              e instanceof ApiError && e.code === "ORGANIZATION_UNAVAILABLE"
            ))
              throw e;
          }
        }
        const b =
          s.selectedMembershipId && !s.user.mustChangePassword
            ? await api<Business>("/business/", {}, s.contextVersion)
            : null;
        if (!live || current !== generation.current) return;
        setSession(s);
        setBusiness(b);
        if (mode === "business") {
          const options = await api<{ currencies: string[] }>(
            "/business/options",
            {},
            s.contextVersion,
          );
          if (live && current === generation.current)
            setCurrencies(options.currencies);
        }
      } catch (e) {
        if (!live || current !== generation.current) return;
        if (e instanceof ApiError && e.code === "CONTEXT_CHANGED") {
          setSession(null);
          setBusiness(null);
          window.location.reload();
          return;
        }
        if (e instanceof ApiError && e.status === 401) {
          setSession(null);
          setBusiness(null);
          if (
            mode === "login" &&
            new URLSearchParams(window.location.search).has("expired")
          )
            setNotice("Your session has ended. Sign in to continue.");
          if (mode !== "login")
            router.replace(
              `/login?expired=1&returnTo=${encodeURIComponent(window.location.pathname)}`,
            );
        } else {
          setError(
            e instanceof Error ? e.message : "Unable to connect. Try again.",
          );
        }
      } finally {
        if (live && current === generation.current) setLoading(false);
      }
    };
    void load();
    const refresh = () => {
      void load(true);
    };
    const focus = () => {
      if (document.visibilityState === "visible") void load();
    };
    const channel = sessionInvalidations();
    const invalidate = (event: MessageEvent<unknown>) => {
      if (event.data === "invalidate") {
        setSession(null);
        setBusiness(null);
        window.location.reload();
      }
    };
    channel?.addEventListener("message", invalidate);
    const resume = (event: PageTransitionEvent) => {
      if (event.persisted) refresh();
    };
    window.addEventListener("pageshow", resume);
    window.addEventListener("focus", focus);
    const timer = window.setInterval(() => {
      if (document.visibilityState === "visible" && mode !== "login")
        void load();
    }, 20_000);
    return () => {
      live = false;

      channel?.removeEventListener("message", invalidate);
      clearInterval(timer);
      window.removeEventListener("focus", focus);
      window.removeEventListener("pageshow", resume);
    };
  }, [mode, router]);

  async function action(work: () => Promise<void>) {
    if (busy) return;
    setBusy(true);
    setError("");
    setNotice("");
    try {
      await work();
    } catch (e) {
      if (
        e instanceof ApiError &&
        ((e.status === 401 && mode !== "login") || e.code === "CONTEXT_CHANGED")
      ) {
        setSession(null);
        setBusiness(null);
        invalidateTabs();
        router.replace("/login?expired=1");
      } else
        setError(
          e instanceof Error ? e.message : "Unable to complete the request.",
        );
    } finally {
      setBusy(false);
    }
  }
  const submit =
    (fn: (data: FormData) => Promise<void>) =>
    (event: FormEvent<HTMLFormElement>) => {
      event.preventDefault();
      const data = new FormData(event.currentTarget);
      void action(() => fn(data));
    };
  const text = (data: FormData, key: string) => String(data.get(key) ?? "");
  const membership = session?.memberships.find(
    (m) => m.id === session.selectedMembershipId,
  );
  const admin = membership?.role === "ADMINISTRATOR";
  const logout = () =>
    void action(async () => {
      await api<void>("/auth/logout", { method: "POST" });

      setSession(null);
      setBusiness(null);
      invalidateTabs();
      router.replace("/login");
      router.refresh();
    });
  const activity = () => {
    if (!session || Date.now() - lastActivity.current < 60_000) return;
    lastActivity.current = Date.now();
    void api<void>("/auth/activity", { method: "POST" }).catch(() => {
      /* session polling handles expiry without extending idle time */
    });
  };
  const feedback = (
    <>
      <div role="alert" className={error ? "auth-error" : undefined}>
        {error}
      </div>
      <div role="status" className={notice ? "auth-success" : undefined}>
        {notice}
      </div>
    </>
  );

  if (mode === "login")
    return (
      <main className="login-layout">
        <section className="login-story">
          <Brand />
          <div>
            <span className="auth-eyebrow">YOUR BUSINESS, CONNECTED</span>
            <h1>
              A clear start.
              <br />A connected day.
            </h1>
            <p>Your people and your business, together in one workspace.</p>
            <div className="login-art" aria-hidden="true">
              <div className="login-art-card">
                <Building2 size={32} />
                <span>Conex360 workspace</span>
                <strong>Made for your everyday.</strong>
                <i />
                <i />
                <i />
              </div>
              <div className="login-art-seal">
                <ShieldCheck size={22} /> Secure by design
              </div>
            </div>
          </div>
          <small>CONEX360 BY SYSCONEX</small>
        </section>
        <section className="login-form-panel">
          <div className="login-form-wrap">
            <span className="auth-icon">
              <KeyRound size={23} />
            </span>
            <h2>Welcome back</h2>
            <p>Sign in to your business workspace.</p>
            {feedback}
            <form
              onSubmit={submit(async (data) => {
                const s = await api<Session>("/auth/login", {
                  method: "POST",
                  body: JSON.stringify({
                    email: text(data, "email"),
                    password: text(data, "password"),
                  }),
                });
                invalidateTabs();
                router.replace(
                  s.user.mustChangePassword
                    ? "/account/password"
                    : !s.selectedMembershipId
                      ? "/select-business"
                      : safeReturnPath(
                          new URLSearchParams(window.location.search).get(
                            "returnTo",
                          ),
                        ),
                );
              })}
            >
              <Field label="Email address">
                <input
                  name="email"
                  type="email"
                  autoComplete="username"
                  required
                  maxLength={254}
                  placeholder="you@yourbusiness.com"
                />
              </Field>
              <Field label="Password">
                <input
                  name="password"
                  type="password"
                  autoComplete="current-password"
                  maxLength={128}
                  required
                />
              </Field>
              <button className="auth-primary" disabled={busy || loading}>
                {busy ? "Signing in…" : "Sign in"}
                <ArrowRight size={18} />
              </button>
            </form>
            <p className="auth-help">
              Need access or a password reset? Contact your SysConex support
              representative.
            </p>
            <Link className="auth-text-link" href="/">
              View Conex360 overview
            </Link>
          </div>
          <small>Protected sessions. Business access stays with you.</small>
        </section>
      </main>
    );

  if (loading)
    return (
      <main className="auth-loading" aria-busy="true">
        <Brand />
        <p role="status">Opening your workspace…</p>
      </main>
    );
  if (!session)
    return (
      <main className="auth-loading">
        <Brand />
        {feedback}
        <button
          className="auth-primary"
          onClick={() => window.location.reload()}
        >
          Try again
        </button>
        <Link href="/login">Back to sign in</Link>
      </main>
    );

  return (
    <div
      className="private-workspace"
      onPointerDown={activity}
      onKeyDown={activity}
    >
      <a className="skip-link" href="#workspace-main">
        Skip to content
      </a>
      <aside className="private-sidebar">
        <Brand />
        <span className="auth-eyebrow">WORKSPACE</span>
        <nav aria-label="Application">
          {session.selectedMembershipId && !session.user.mustChangePassword && (
            <Link
              href="/inventory"
              aria-current={mode === "inventory" ? "page" : undefined}
            >
              <LayoutGrid size={18} /> Inventory
            </Link>
          )}
          {!session.user.mustChangePassword &&
            session.selectedMembershipId &&
            (["products", "categories", "units", "suppliers"] as const).map(
              (page) => (
                <Link
                  key={page}
                  href={`/settings/${page}`}
                  aria-current={mode === page ? "page" : undefined}
                >
                  <LayoutGrid size={18} />
                  {page.charAt(0).toUpperCase() + page.slice(1)}
                </Link>
              ),
            )}
          {admin &&
            !session.user.mustChangePassword &&
            (["outlets", "warehouses", "users"] as const).map((page) => (
              <Link
                key={page}
                href={`/settings/${page}`}
                aria-current={mode === page ? "page" : undefined}
              >
                <Building2 size={18} />
                {page === "outlets"
                  ? "Outlets"
                  : page === "warehouses"
                    ? "Warehouses"
                    : "Users & access"}
              </Link>
            ))}
          <Link href="/app" aria-current={mode === "home" ? "page" : undefined}>
            <LayoutGrid size={18} />
            Overview
          </Link>
          {admin && !session.user.mustChangePassword && (
            <Link
              href="/settings/business"
              aria-current={mode === "business" ? "page" : undefined}
            >
              <Building2 size={18} />
              Business settings
            </Link>
          )}
          <Link
            href="/account/password"
            aria-current={mode === "password" ? "page" : undefined}
          >
            <KeyRound size={18} />
            Password & security
          </Link>
        </nav>
        <div className="private-sidebar-footer">
          <ShieldCheck size={18} />
          <span>
            Your business.
            <br />
            Securely connected.
          </span>
        </div>
      </aside>
      <div className="private-body">
        <header className="private-header">
          <div className="business-identity">
            {business?.logoKey ? (
              <Image
                unoptimized
                src={`/api/v1/business/logo?context=${session.contextVersion}&v=${business.version}`}
                alt="Business logo"
                width="38"
                height="38"
              />
            ) : (
              <span className="business-avatar">
                <Building2 size={20} />
              </span>
            )}
            <div>
              <strong>
                {business?.displayName ??
                  membership?.businessName ??
                  "Conex360 workspace"}
              </strong>
              <span>
                {membership?.role === "ADMINISTRATOR"
                  ? "Administrator"
                  : membership
                    ? "Staff"
                    : "Choose your business"}
              </span>
            </div>
          </div>
          {session.selectedMembershipId && !session.user.mustChangePassword && (
            <OutletSelector session={session} />
          )}
          <details className="account-menu">
            <summary aria-label="Account menu">
              <CircleUserRound size={22} />
              <span>{session.user.displayName}</span>
              <ChevronDown size={15} />
            </summary>
            <div>
              <Link href="/account/password">Change password</Link>
              {session.memberships.length > 1 && (
                <Link href="/select-business">Switch business</Link>
              )}
              <button onClick={logout} disabled={busy}>
                <LogOut size={16} />
                Sign out
              </button>
            </div>
          </details>
        </header>
        <main id="workspace-main" className="private-main">
          {(mode === "inventory" ||
            mode === "opening-stock" ||
            mode === "goods-receipts" ||
            mode === "movements") &&
            business && (
              <InventoryPanel
                key={
                  mode + session.contextVersion + (inventoryDocumentId ?? "")
                }
                mode={mode}
                session={session}
                documentId={inventoryDocumentId}
                timezone={business.timezone}
                currency={business.currencyCode}
              />
            )}
          {(mode === "products" ||
            mode === "categories" ||
            mode === "units" ||
            mode === "suppliers") && (
            <CatalogPanel
              key={mode}
              kind={mode}
              session={session}
              currencyCode={business?.currencyCode ?? ""}
            />
          )}
          {(mode === "outlets" ||
            mode === "warehouses" ||
            mode === "users") && (
            <OrganizationPanel kind={mode} session={session} />
          )}
          {feedback}
          {mode === "home" && (
            <>
              <div className="private-page-heading">
                <span className="auth-eyebrow">YOUR WORKSPACE</span>
                <h1>Welcome, {session.user.displayName.split(" ")[0]}.</h1>
                <p>A good day starts with the essentials.</p>
              </div>
              <section className="workspace-welcome">
                <div>
                  <span className="auth-icon">
                    <Check size={24} />
                  </span>
                  <h2>Your business is connected.</h2>
                  <p>
                    Manage your business profile and keep your account secure.
                    Operational modules will appear here as they become
                    available.
                  </p>
                  {admin && (
                    <Link className="auth-primary" href="/settings/business">
                      Review business settings
                      <ArrowRight size={18} />
                    </Link>
                  )}
                </div>
                <div className="welcome-grid" aria-hidden="true">
                  <Building2 size={70} />
                  <span>{business?.displayName}</span>
                </div>
              </section>
              <div className="private-cards">
                <section>
                  <ShieldCheck />
                  <h3>Account security</h3>
                  <p>
                    Update your password and sign out when you finish using a
                    shared computer.
                  </p>
                  <Link className="auth-text-link" href="/account/password">
                    Manage password →
                  </Link>
                </section>
                <section>
                  <Building2 />
                  <h3>Business essentials</h3>
                  <p>
                    {business?.timezone} · {business?.currencyCode}
                  </p>
                  <p>
                    Your stock and sales workspace is being prepared in the next
                    milestones.
                  </p>
                </section>
              </div>
            </>
          )}
          {mode === "password" && (
            <>
              <div className="private-page-heading">
                <span className="auth-eyebrow">ACCOUNT SECURITY</span>
                <h1>
                  {session.user.mustChangePassword
                    ? "Set your own password"
                    : "Change your password"}
                </h1>
                <p>
                  {session.user.mustChangePassword
                    ? "Replace your temporary password before accessing your business."
                    : "A long, unique passphrase helps keep your account secure."}
                </p>
              </div>
              <section className="settings-card narrow">
                <form
                  onSubmit={submit(async (data) => {
                    if (text(data, "newPassword") !== text(data, "confirm"))
                      throw new Error("The new passwords do not match.");
                    const s = await api<Session>("/auth/password", {
                      method: "POST",
                      body: JSON.stringify({
                        currentPassword: text(data, "current"),
                        newPassword: text(data, "newPassword"),
                      }),
                    });

                    setSession(s);
                    setBusiness(null);
                    invalidateTabs();
                    router.replace(
                      s.selectedMembershipId ? "/app" : "/select-business",
                    );
                    router.refresh();
                  })}
                >
                  <Field label="Current or temporary password">
                    <input
                      name="current"
                      type="password"
                      required
                      autoComplete="current-password"
                      maxLength={128}
                    />
                  </Field>
                  <Field label="New password">
                    <input
                      name="newPassword"
                      type="password"
                      required
                      minLength={15}
                      maxLength={128}
                      autoComplete="new-password"
                    />
                  </Field>
                  <Field label="Confirm new password">
                    <input
                      name="confirm"
                      type="password"
                      required
                      minLength={15}
                      maxLength={128}
                      autoComplete="new-password"
                    />
                  </Field>
                  <p className="auth-help">
                    Use 15–128 characters. Choose a unique passphrase. Changing
                    it signs out your other sessions.
                  </p>
                  <button className="auth-primary" disabled={busy}>
                    {busy ? "Updating…" : "Update password"}
                  </button>
                </form>
              </section>
            </>
          )}
          {mode === "select" && (
            <>
              <div className="private-page-heading">
                <h1>Choose your business</h1>
                <p>Only businesses you have verified access to are listed.</p>
              </div>
              <section className="settings-card narrow">
                {session.memberships.map((m) => (
                  <button
                    className="business-choice"
                    disabled={busy}
                    key={m.id}
                    onClick={() =>
                      void action(async () => {
                        const s = await api<Session>("/auth/context", {
                          method: "POST",
                          body: JSON.stringify({
                            membershipId: m.id,
                            expectedContextVersion: session.contextVersion,
                          }),
                        });

                        setSession(s);
                        setBusiness(null);
                        invalidateTabs();
                        router.replace(
                          s.user.mustChangePassword
                            ? "/account/password"
                            : "/app",
                        );
                        router.refresh();
                      })
                    }
                  >
                    <Building2 />
                    <span>
                      <strong>{m.businessName}</strong>
                      <small>
                        {m.role === "ADMINISTRATOR" ? "Administrator" : "Staff"}
                      </small>
                    </span>
                    <ArrowRight size={18} />
                  </button>
                ))}
              </section>
            </>
          )}
          {mode === "business" &&
            (!admin ? (
              <section className="settings-card">
                <h1>Administrator access required</h1>
                <p>
                  Contact your business Administrator to update these settings.
                </p>
              </section>
            ) : (
              business && (
                <>
                  <div className="private-page-heading">
                    <span className="auth-eyebrow">BUSINESS SETTINGS</span>
                    <h1>Make it your business.</h1>
                    <p>
                      The details that introduce your business to your team and
                      customers.
                    </p>
                  </div>
                  <section className="settings-card">
                    <div className="settings-section-title">
                      <h2>Business profile</h2>
                      <span>Administrator access</span>
                    </div>
                    <form
                      key={`${business.id}-${business.version}`}
                      onSubmit={submit(async (data) => {
                        const b = await api<Business>(
                          "/business/",
                          {
                            method: "PUT",
                            body: JSON.stringify({
                              businessName: text(data, "businessName"),
                              displayName: text(data, "displayName"),
                              phone: text(data, "phone"),
                              email: text(data, "email"),
                              address: text(data, "address"),
                              timezone: text(data, "timezone"),
                              currencyCode: text(data, "currencyCode"),
                              expectedVersion: business.version,
                            }),
                          },
                          session.contextVersion,
                        );
                        setBusiness(b);
                        setNotice("Business profile saved.");
                        invalidateTabs();
                      })}
                    >
                      <div className="settings-fields">
                        <Field label="Business name">
                          <input
                            name="businessName"
                            defaultValue={business.businessName}
                            required
                            maxLength={200}
                          />
                        </Field>
                        <Field label="Display name">
                          <input
                            name="displayName"
                            defaultValue={business.displayName}
                            required
                            maxLength={200}
                          />
                        </Field>
                        <Field label="Contact number">
                          <input
                            name="phone"
                            type="tel"
                            defaultValue={business.phone ?? ""}
                            maxLength={50}
                          />
                        </Field>
                        <Field label="Business email">
                          <input
                            name="email"
                            type="email"
                            defaultValue={business.email ?? ""}
                            maxLength={254}
                          />
                        </Field>
                        <Field label="Timezone (IANA)">
                          <input
                            name="timezone"
                            defaultValue={business.timezone}
                            required
                            maxLength={64}
                            placeholder="Region/City"
                          />
                        </Field>
                        <Field label="Currency">
                          <select
                            name="currencyCode"
                            defaultValue={business.currencyCode}
                          >
                            {currencies.map((c) => (
                              <option key={c}>{c}</option>
                            ))}
                          </select>
                        </Field>
                      </div>
                      <Field label="Business address">
                        <textarea
                          name="address"
                          defaultValue={business.address ?? ""}
                          rows={3}
                          maxLength={700}
                        />
                      </Field>
                      <p className="auth-help">
                        Choose your operating currency carefully. It is locked
                        when a price is first configured or operational
                        transactions begin.
                      </p>
                      <button className="auth-primary" disabled={busy}>
                        {busy ? "Saving…" : "Save changes"}
                      </button>
                    </form>
                  </section>
                  <section className="settings-card">
                    <h2>Business logo</h2>
                    <p className="auth-help">
                      PNG or JPEG · up to 2 MiB · maximum 2048 × 2048 pixels
                    </p>
                    <form
                      className="logo-form"
                      onSubmit={submit(async (data) => {
                        const file = data.get("logo");
                        if (!(file instanceof File) || file.size === 0)
                          throw new Error("Choose a PNG or JPEG logo.");
                        if (file.size > 2 * 1024 * 1024)
                          throw new Error(
                            "The logo must be no larger than 2 MiB.",
                          );
                        const b = await api<Business>(
                          "/business/logo",
                          {
                            method: "POST",
                            body: file,
                            headers: { "X-Conex360-Version": business.version },
                          },
                          session.contextVersion,
                        );
                        setBusiness(b);
                        setNotice("Business logo updated.");
                        invalidateTabs();
                      })}
                    >
                      <Field label="Choose logo">
                        <input
                          name="logo"
                          type="file"
                          accept="image/png,image/jpeg"
                          required
                        />
                      </Field>
                      <button className="auth-secondary" disabled={busy}>
                        {busy ? "Uploading…" : "Upload logo"}
                      </button>
                    </form>
                  </section>
                </>
              )
            ))}
        </main>
        <footer className="private-footer">
          Conex360 <span>Built by SysConex · Your business, connected.</span>
        </footer>
      </div>
    </div>
  );
}
