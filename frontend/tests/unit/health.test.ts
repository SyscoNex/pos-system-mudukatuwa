import assert from "node:assert/strict";
import { test } from "node:test";
import { readApiHealth, HealthCheckError } from "../../src/lib/api/health.ts";

const healthy = {
  status: "healthy",
  service: "conex360-api",
  version: "0.1.0",
  scope: "process",
  timestamp: "2026-11-25T10:00:00Z",
};

test("reads the same-origin health contract without caching", async () => {
  const fakeFetch: typeof fetch = async (input, init) => {
    assert.equal(input, "/api/v1/health");
    assert.equal(init?.cache, "no-store");
    assert.equal(init?.credentials, "same-origin");
    return Response.json(healthy);
  };
  assert.deepEqual(await readApiHealth(fakeFetch), healthy);
});

for (const payload of [
  null,
  {},
  { ...healthy, service: "another-service" },
  { ...healthy, timestamp: "invalid" },
  { ...healthy, scope: "database" },
]) {
  test(`rejects a malformed or misleading health contract: ${JSON.stringify(payload)}`, async () => {
    await assert.rejects(
      readApiHealth(async () => Response.json(payload)),
      HealthCheckError,
    );
  });
}

test("does not treat an HTTP failure as a successful connection", async () => {
  await assert.rejects(
    readApiHealth(async () => Response.json(healthy, { status: 503 })),
    HealthCheckError,
  );
});

test("handles invalid JSON without exposing the raw response", async () => {
  await assert.rejects(
    readApiHealth(
      async () =>
        new Response("private server details", {
          headers: { "content-type": "application/json" },
        }),
    ),
    HealthCheckError,
  );
});

test("forwards cancellation to the request", async () => {
  const controller = new AbortController();
  const fakeFetch: typeof fetch = async (_input, init) => {
    assert.equal(init?.signal, controller.signal);
    throw new DOMException("The operation was aborted", "AbortError");
  };
  controller.abort();
  await assert.rejects(readApiHealth(fakeFetch, controller.signal), {
    name: "AbortError",
  });
});
