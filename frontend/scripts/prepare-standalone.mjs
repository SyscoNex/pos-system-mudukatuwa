import { cp } from "node:fs/promises";
import { resolve } from "node:path";

// Next standalone intentionally omits these assets. Include them for both local
// production smoke tests and the Docker runtime, without a second build.
const root = process.cwd();
await cp(resolve(root, "public"), resolve(root, ".next/standalone/public"), {
  recursive: true,
});
await cp(
  resolve(root, ".next/static"),
  resolve(root, ".next/standalone/.next/static"),
  { recursive: true },
);
