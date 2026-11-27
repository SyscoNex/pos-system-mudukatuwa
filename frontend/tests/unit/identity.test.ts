import test from "node:test";
import assert from "node:assert/strict";
import { safeReturnPath } from "../../src/lib/api/identity.ts";
test("return paths allow only supported internal destinations", () => {
  for (const path of [
    "https://attacker.invalid",
    "//attacker.invalid",
    "/\\attacker.invalid",
    "javascript:alert(1)",
    null,
    "/pos",
  ])
    assert.equal(safeReturnPath(path), "/app");
  assert.equal(safeReturnPath("/settings/business"), "/settings/business");
});
