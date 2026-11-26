import Link from "next/link";

export default function NotFound() {
  return (
    <main className="error-screen">
      <p className="eyebrow">CONEX360</p>
      <h1>This page isn’t here.</h1>
      <p>Return to your workspace to continue.</p>
      <Link className="button button-primary" href="/">
        Back to workspace
      </Link>
    </main>
  );
}
