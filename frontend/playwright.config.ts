import { defineConfig, devices } from "@playwright/test";
const port = process.env.CONEX360_E2E_PORT ?? "3600";

export default defineConfig({
  testDir: "./tests/e2e",
  fullyParallel: true,
  forbidOnly: Boolean(process.env.CI),
  retries: 0,
  workers: 2,
  reporter: "list",
  use: {
    baseURL: `http://127.0.0.1:${port}`,
    trace: "retain-on-failure",
    ...devices["Desktop Chrome"],
  },
  webServer: [
    {
      command:
        "dotnet run --no-build -c Release --no-launch-profile --project ../backend/src/Conex360.Api --urls http://127.0.0.1:5180",
      url: "http://127.0.0.1:5180/health/ready",
      reuseExistingServer: false,
      timeout: 60_000,
      env: { ASPNETCORE_ENVIRONMENT: "Development" },
    },
    {
      command: "npm run start",
      url: `http://127.0.0.1:${port}`,
      env: { PORT: port },
      reuseExistingServer: false,
      timeout: 60_000,
    },
  ],
});
