import { defineConfig, devices } from "@playwright/test";
export default defineConfig({
  testDir: "./tests/auth-e2e",
  outputDir: "./test-results/auth",
  fullyParallel: false,
  workers: 1,
  retries: 0,
  reporter: "list",
  timeout: 45_000,
  use: {
    baseURL: "http://127.0.0.1:3602",
    trace: "retain-on-failure",
    ...devices["Desktop Chrome"],
  },
});
