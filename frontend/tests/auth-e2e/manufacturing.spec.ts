import { test, expect } from "@playwright/test";
import { readFileSync } from "node:fs";
import path from "node:path";

test("complete a production run and verify material detail and output stock", async ({
  page,
}) => {
  test.skip(
    process.env.CONEX360_MANUFACTURING_MYSQL_APPROVED !== "1",
    "Requires the approved P1-07 synthetic database.",
  );
  const evidence = path.resolve("../artifacts/auth-review");
  const fixture = JSON.parse(
    readFileSync(path.join(evidence, "browser-fixture.json"), "utf8"),
  ) as {
    email: string;
    password: string;
    businessName: string;
  };
  await page.goto("/login");
  await page.getByLabel("Email address").fill(fixture.email);
  await page.getByLabel("Password", { exact: true }).fill(fixture.password);
  await page.getByRole("button", { name: "Sign in", exact: true }).click();
  await expect(page).toHaveURL(/select-business/);
  await page
    .getByRole("button", { name: new RegExp(fixture.businessName) })
    .first()
    .click();
  await expect(page).toHaveURL(/\/app$/);
  await page.getByRole("link", { name: "Manufacturing", exact: true }).click();
  await page
    .getByRole("combobox", { name: "Production warehouse", exact: true })
    .selectOption({ label: "Production Plant · Main warehouse" });
  await page
    .getByRole("combobox", { name: "Material 1", exact: true })
    .selectOption({ label: "P107-RAW · Synthetic raw oil" });
  await page
    .getByRole("combobox", { name: "Material unit 1", exact: true })
    .selectOption({ label: "Litre" });
  await page.getByLabel("Material quantity 1", { exact: true }).fill("2");
  await page.getByRole("button", { name: "Add material", exact: true }).click();
  await page
    .getByRole("combobox", { name: "Material 2", exact: true })
    .selectOption({ label: "P107-BOTTLE · Synthetic bottle" });
  await page
    .getByRole("combobox", { name: "Material unit 2", exact: true })
    .selectOption({ label: "Piece" });
  await page.getByLabel("Material quantity 2", { exact: true }).fill("2");
  await page
    .getByRole("combobox", { name: "Output product", exact: true })
    .selectOption({ label: "P107-FINISHED · Synthetic bottled oil" });
  await page
    .getByRole("combobox", { name: "Output unit", exact: true })
    .selectOption({ label: "Piece" });
  await page.getByLabel("Actual output quantity", { exact: true }).fill("2");
  const lot = "P107-BROWSER-" + Date.now();
  await page.getByLabel("New production lot", { exact: true }).fill(lot);
  const date = await page
    .getByLabel("Production date", { exact: true })
    .inputValue();
  await page.getByLabel("Output expiry", { exact: true }).fill(date);
  await page
    .getByRole("button", { name: "Preview production", exact: true })
    .click();
  await expect(
    page.getByText("Production cost LKR 1120 · 560 per base unit"),
  ).toBeVisible();
  await page
    .getByRole("button", { name: "Confirm and post production", exact: true })
    .click();
  const details = page.getByRole("region", { name: "Production details" });
  await expect(details.getByRole("heading", { name: /PROD-/ })).toBeVisible();
  await expect(details.getByText(/P107-LATER/)).toBeVisible();
  await expect(
    details.getByText(/Total operational cost LKR 1120/),
  ).toBeVisible();
  await page.screenshot({
    path: path.join(evidence, "p107-manufacturing.png"),
    fullPage: true,
  });
  await page.getByRole("link", { name: "Inventory", exact: true }).click();
  await page.getByLabel("Exact batch", { exact: true }).fill(lot);
  const row = page.getByRole("row").filter({ hasText: lot });
  await expect(row).toContainText("2 EA on hand");
  await expect(row).toContainText("2 available");
  await page.setViewportSize({ width: 390, height: 844 });
  expect(
    await page.evaluate(
      () => document.documentElement.scrollWidth <= window.innerWidth,
    ),
  ).toBe(true);
});
