import { request } from "@playwright/test";
import assert from "node:assert/strict";
import path from "node:path";
import console from "node:console";
import process from "node:process";
import { createHash } from "node:crypto";
import { readFileSync, writeFileSync } from "node:fs";
const baseURL = "http://127.0.0.1:3602";
const context = await request.newContext({
  baseURL,
  storageState: path.resolve(
    "../artifacts/auth-review/persistence-session.json",
  ),
});
const session = await context.get("/api/v1/auth/session");
if (process.argv.includes("--database-unavailable")) {
  assert.equal(
    session.status(),
    503,
    "Database failure returns controlled 503",
  );
  const problem = await session.json();
  assert.equal(problem.code, "DATABASE_UNAVAILABLE");
  assert.ok(!JSON.stringify(problem).includes("Server="));
  await context.dispose();
  console.log(
    "Unavailable database denied authenticated access with safe 503.",
  );
  process.exit(0);
}
assert.equal(session.status(), 200, "Persisted session remains authenticated");
const data = await session.json();
const logo = await context.get(
  `/api/v1/business/logo?context=${data.contextVersion}`,
);
assert.equal(logo.status(), 200, "Private logo persists");
assert.equal(logo.headers()["content-type"], "image/png");
const hash = createHash("sha256")
  .update(await logo.body())
  .digest("hex");
const hashFile = path.resolve(
  "../artifacts/auth-review/persistence-logo-sha256",
);
if (process.argv.includes("--record")) writeFileSync(hashFile, hash);
else
  assert.equal(
    hash,
    readFileSync(hashFile, "utf8"),
    "Logo bytes survive restart",
  );
console.log("Persisted cookie session and authorized PNG logo verified.");
await context.dispose();
