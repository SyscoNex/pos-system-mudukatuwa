"use client";

export default function ErrorPage({ reset }: { reset: () => void }) {
  return (
    <main className="error-screen">
      <p className="eyebrow">CONEX360</p>
      <h1>Let’s get you back on track.</h1>
      <p>
        The workspace could not load. Your browser has not posted any
        transactions.
      </p>
      <button className="button button-primary" onClick={reset}>
        Try again
      </button>
    </main>
  );
}
