"use client";

import {
  Activity,
  BookOpen,
  Boxes,
  Check,
  ChevronRight,
  CircleCheck,
  Code2,
  Database,
  Factory,
  KeyRound,
  LayoutDashboard,
  Menu,
  Package,
  RefreshCw,
  Route,
  ShieldCheck,
  Sparkles,
  Store,
  Terminal,
  Wifi,
  WifiOff,
  X,
} from "lucide-react";
import { useCallback, useEffect, useRef, useState } from "react";
import { readApiHealth, type ApiHealth } from "@/lib/api/health";

type Connection = {
  state: "checking" | "connected" | "unavailable";
  health?: ApiHealth;
};
const navigation = [
  { label: "Overview", href: "#workspace", icon: LayoutDashboard },
  { label: "Build journey", href: "#journey", icon: Route },
  { label: "Connection", href: "#connection", icon: Activity },
];
const journey = [
  {
    icon: Code2,
    title: "The foundation",
    detail: "Application shell & API conventions",
    status: "Current",
    current: true,
  },
  {
    icon: KeyRound,
    title: "Your business, set up",
    detail: "Sign-in, business profile & access",
    status: "Next",
    current: false,
  },
  {
    icon: Boxes,
    title: "Stock that stays connected",
    detail: "Products, outlets, transfers & manufacturing",
    status: "Planned",
    current: false,
  },
  {
    icon: Store,
    title: "A smoother counter",
    detail: "Billing, receipts & operational reporting",
    status: "Planned",
    current: false,
  },
];

function BrandMark({ small = false }: { small?: boolean }) {
  return (
    <span
      className={`brand-mark ${small ? "brand-mark-small" : ""}`}
      aria-hidden="true"
    >
      <span />
      <i />
    </span>
  );
}

export function FoundationWorkspace() {
  const [navigationOpen, setNavigationOpen] = useState(false);
  const [activeSection, setActiveSection] = useState("Overview");
  const [connection, setConnection] = useState<Connection>({
    state: "checking",
  });
  const request = useRef<AbortController | null>(null);
  const guide = useRef<HTMLDialogElement>(null);

  const checkConnection = useCallback(() => {
    request.current?.abort();
    const controller = new AbortController();
    request.current = controller;
    const timeout = window.setTimeout(() => controller.abort(), 5_000);
    void readApiHealth(fetch, controller.signal)
      .then(
        (health) => {
          if (request.current === controller)
            setConnection({ state: "connected", health });
        },
        () => {
          if (request.current === controller)
            setConnection({ state: "unavailable" });
        },
      )
      .finally(() => window.clearTimeout(timeout));
  }, []);

  useEffect(() => {
    void checkConnection();
    return () => {
      request.current?.abort();
      request.current = null;
    };
  }, [checkConnection]);

  const connected = connection.state === "connected";
  const checking = connection.state === "checking";

  return (
    <div className="workspace" id="workspace" tabIndex={-1}>
      <a className="skip-link" href="#main-content">
        Skip to content
      </a>
      {navigationOpen && (
        <button
          className="navigation-backdrop"
          aria-label="Close navigation"
          onClick={() => setNavigationOpen(false)}
        />
      )}
      <aside className={`sidebar ${navigationOpen ? "sidebar-open" : ""}`}>
        <button
          className="icon-button sidebar-close"
          aria-label="Close navigation menu"
          onClick={() => setNavigationOpen(false)}
        >
          <X size={19} />
        </button>
        <a className="brand" href="#workspace" aria-label="Conex360 home">
          <BrandMark />
          <span>
            Conex<span className="brand-360">360</span>
          </span>
        </a>
        <div className="workspace-label">
          <span className="workspace-monogram">C</span>
          <span>
            Conex360 workspace<small>Development preview</small>
          </span>
          <span className="preview-square" />
        </div>
        <p className="nav-label">YOUR WORKSPACE</p>
        <nav aria-label="Main navigation">
          {navigation.map(({ label, href, icon: Icon }) => (
            <a
              key={label}
              href={href}
              className={`nav-link ${activeSection === label ? "nav-link-active" : ""}`}
              aria-current={activeSection === label ? "location" : undefined}
              onClick={() => {
                setActiveSection(label);
                setNavigationOpen(false);
                window.requestAnimationFrame(() => {
                  document
                    .getElementById(href.slice(1))
                    ?.focus({ preventScroll: true });
                });
              }}
            >
              <Icon size={19} />
              <span>{label}</span>
              {activeSection === label && (
                <span className="nav-active-marker" />
              )}
            </a>
          ))}
        </nav>
        <div className="sidebar-note">
          <div className="sidebar-note-icon">
            <Package size={24} strokeWidth={1.5} />
          </div>
          <h2>
            Small team.
            <br />
            Connected business.
          </h2>
          <p>
            A little less complexity.
            <br />A lot more possibility.
          </p>
          <span className="sidebar-phase">PHASE 1</span>
        </div>
        <div className="sidebar-footer">
          <span className="sysconex-symbol">S</span>
          <span>
            Built by SysConex<small>Thoughtfully connected.</small>
          </span>
        </div>
      </aside>

      <div className="main-shell">
        <header className="topbar">
          <div className="breadcrumb">
            <button
              className="icon-button menu-button"
              aria-label="Open navigation"
              aria-expanded={navigationOpen}
              onClick={() => setNavigationOpen(true)}
            >
              <Menu size={21} />
            </button>
            <LayoutDashboard size={17} />
            <span>Workspace</span>
            <ChevronRight size={14} />
            <strong>Overview</strong>
          </div>
          <div className="topbar-actions">
            <span className="environment-label">Development</span>
            <button
              className="guide-button"
              onClick={() => guide.current?.showModal()}
            >
              <BookOpen size={17} />
              <span>Quick guide</span>
            </button>
            <span className="topbar-brand" aria-label="SysConex">
              SC
            </span>
          </div>
        </header>

        <main id="main-content" className="main-content" tabIndex={-1}>
          <div className="page-heading">
            <div>
              <p className="eyebrow">YOUR BUSINESS, CONNECTED</p>
              <h1>
                A fresh workspace.
                <br className="mobile-break" /> A solid start.
              </h1>
              <p>Welcome to Conex360. Let’s build a better working day.</p>
            </div>
            <span className="milestone-pill">
              <span />
              Foundation milestone
            </span>
          </div>

          <section className="hero" aria-labelledby="hero-title">
            <div className="hero-copy">
              <span className="hero-kicker">
                <Sparkles size={15} />
                Built around the way you work
              </span>
              <h2 id="hero-title">
                From the factory floor
                <br />
                to the shop counter.
              </h2>
              <p>
                One clear home for your stock, production and sales.
                <br className="desktop-break" /> Simple for your team. Ready to
                grow with your business.
              </p>
              <a className="button button-primary" href="#journey">
                Explore the build journey
              </a>
              <span className="hero-footnote">
                <ShieldCheck size={15} />A careful start. Built to last.
              </span>
            </div>
            <div className="hero-art" aria-hidden="true">
              <div className="art-orbit orbit-one" />
              <div className="art-orbit orbit-two" />
              <div className="art-dots" />
              <div className="floating-tag tag-stock">
                <Boxes size={18} />
                <span>Stock</span>
              </div>
              <div className="floating-tag tag-production">
                <Factory size={18} />
                <span>Production</span>
              </div>
              <div className="receipt-illustration">
                <BrandMark small />
                <strong>Conex360</strong>
                <span className="receipt-caption">BUSINESS ESSENTIALS</span>
                <div className="receipt-divider" />
                <div className="receipt-line">
                  <span />
                  <i />
                </div>
                <div className="receipt-line">
                  <span />
                  <i />
                </div>
                <div className="receipt-line short">
                  <span />
                  <i />
                </div>
                <div className="receipt-divider" />
                <div className="receipt-barcode" />
                <span className="receipt-bottom">
                  Everything. A little more connected.
                </span>
              </div>
              <div className="art-check">
                <Check size={22} />
              </div>
              <div className="floating-tag tag-counter">
                <Store size={18} />
                <span>Your counter</span>
              </div>
            </div>
          </section>

          <section
            id="connection"
            tabIndex={-1}
            className="connection-section"
            aria-labelledby="connection-heading"
          >
            <div className="section-heading">
              <div>
                <h2 id="connection-heading">The essentials, in place</h2>
                <p>A live look at this development workspace.</p>
              </div>
              <button
                className="text-button"
                disabled={checking}
                onClick={() => {
                  setConnection({ state: "checking" });
                  void checkConnection();
                }}
              >
                <RefreshCw size={15} className={checking ? "spinning" : ""} />
                {checking ? "Checking…" : "Check connection"}
              </button>
            </div>
            <div className="status-grid">
              <article className="status-card">
                <div className="status-top">
                  <span className="card-icon icon-blue">
                    <LayoutDashboard size={20} />
                  </span>
                  <span className="small-status">
                    <span className="status-dot" />
                    Ready
                  </span>
                </div>
                <h3>Your workspace</h3>
                <p className="status-value">A clear starting point</p>
                <p className="status-description">
                  The Conex360 application shell is ready to explore.
                </p>
                <div className="card-meta">
                  Next.js <span>·</span> App Router
                </div>
              </article>
              <article className="status-card" aria-busy={checking}>
                <div className="status-top">
                  <span
                    className={`card-icon ${connection.state === "unavailable" ? "icon-amber" : "icon-green"}`}
                  >
                    {connection.state === "unavailable" ? (
                      <WifiOff size={20} />
                    ) : (
                      <Wifi size={20} />
                    )}
                  </span>
                  <span
                    className={`small-status ${connection.state === "unavailable" ? "status-unavailable" : ""}`}
                  >
                    <span
                      className={`status-dot ${checking ? "status-dot-checking" : ""}`}
                    />
                    {checking
                      ? "Checking"
                      : connected
                        ? "Connected"
                        : "Unavailable"}
                  </span>
                </div>
                <h3>Backend connection</h3>
                <div role="status" aria-live="polite">
                  <p className="status-value">
                    {checking
                      ? "Making the connection"
                      : connected
                        ? "Connected to Conex360"
                        : "Let’s reconnect"}
                  </p>
                  <p className="status-description">
                    {checking
                      ? "Checking the API process. This takes a moment."
                      : connected
                        ? "The API is responding. Process health only; no database check."
                        : "The API could not be reached. Start it, then check again."}
                  </p>
                </div>
                <div className="card-meta">
                  ASP.NET Core <span>·</span> .NET 10
                </div>
              </article>
              <article className="status-card">
                <div className="status-top">
                  <span className="card-icon icon-slate">
                    <Database size={20} />
                  </span>
                  <span className="small-status status-planned">
                    Not configured
                  </span>
                </div>
                <h3>Business data</h3>
                <p className="status-value">A clean slate</p>
                <p className="status-description">
                  No database has been initialized. Business setup comes next.
                </p>
                <div className="card-meta">
                  MySQL 8.4 <span>·</span> Future milestone
                </div>
              </article>
            </div>
          </section>

          <div className="bottom-grid">
            <section
              id="journey"
              tabIndex={-1}
              className="journey-panel"
              aria-labelledby="journey-heading"
            >
              <div className="panel-heading">
                <div>
                  <span className="eyebrow">ONE STEP AT A TIME</span>
                  <h2 id="journey-heading">The build journey</h2>
                </div>
                <span className="outline-badge">Phase 1</span>
              </div>
              <div className="journey-list">
                {journey.map(
                  ({ icon: Icon, title, detail, status, current }) => (
                    <div
                      className={`journey-row ${current ? "journey-current" : ""}`}
                      key={title}
                    >
                      <span className="journey-icon">
                        <Icon size={19} />
                      </span>
                      <div className="journey-copy">
                        <h3>{title}</h3>
                        <p>{detail}</p>
                      </div>
                      <span
                        className={`journey-status ${current ? "journey-status-current" : ""}`}
                      >
                        {status}
                      </span>
                    </div>
                  ),
                )}
              </div>
              <div className="journey-footer">
                <CircleCheck size={16} />
                <span>
                  Working features, added carefully. No shortcuts on accuracy.
                </span>
              </div>
            </section>
            <aside className="principles-panel">
              <div className="principles-illustration" aria-hidden="true">
                <span />
                <span />
                <span />
                <ShieldCheck size={26} />
              </div>
              <p className="eyebrow">THE PHASE 1 APPROACH</p>
              <h2>
                Less complexity.
                <br />
                More clarity.
              </h2>
              <p>
                Built for a small team, with care for the details that matter.
              </p>
              <ul>
                <li>
                  <Check size={16} />
                  Exact quantities and amounts
                </li>
                <li>
                  <Check size={16} />
                  Separate stock for each outlet
                </li>
                <li>
                  <Check size={16} />A simple, online workflow
                </li>
              </ul>
              <span className="principles-note">
                Approved direction · delivered in stages
              </span>
            </aside>
          </div>
          <footer className="page-footer">
            <span>
              Conex360 <span className="footer-dot">·</span> Made by SysConex
            </span>
            <span>
              Foundation preview <span className="footer-dot">·</span> v0.1.0
            </span>
          </footer>
        </main>
      </div>

      <dialog
        ref={guide}
        className="guide-dialog"
        aria-labelledby="guide-title"
      >
        <button
          className="icon-button dialog-close"
          aria-label="Close quick guide"
          onClick={() => guide.current?.close()}
        >
          <X size={20} />
        </button>
        <span className="card-icon icon-blue">
          <Terminal size={23} />
        </span>
        <h2 id="guide-title">Your foundation, locally.</h2>
        <p>
          This preview connects the application shell to the .NET health
          endpoint. Authentication and business data come in the next milestone.
        </p>
        <h3>Start the API</h3>
        <code>dotnet run --project backend/src/Conex360.Api</code>
        <h3>Start the workspace</h3>
        <code>
          cd frontend
          <br />
          npm run dev
        </code>
        <p className="dialog-note">
          Use the pinned Node runtime. See the repository README for setup and
          checks.
        </p>
        <button
          className="button button-primary"
          onClick={() => guide.current?.close()}
        >
          Got it
        </button>
      </dialog>
    </div>
  );
}
