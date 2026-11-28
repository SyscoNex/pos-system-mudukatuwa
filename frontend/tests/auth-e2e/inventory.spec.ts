import { test, expect } from "@playwright/test";
import { readFileSync } from "node:fs";
import path from "node:path";

test("receive an identified lot and verify stock on desktop and mobile", async ({
  page,
}) => {
  test.skip(
    process.env.CONEX360_INVENTORY_MYSQL_APPROVED !== "1",
    "Requires the separately approved inventory database and synthetic fixture.",
  );
  const root = path.resolve("../artifacts/auth-review");
  const fixture = JSON.parse(
    readFileSync(path.join(root, "browser-fixture.json"), "utf8"),
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
  const outlet = page.getByLabel("Working outlet", { exact: true });
  await outlet.selectOption({ label: "Inventory Test" });
  await expect(outlet.locator("option:checked")).toHaveText("Inventory Test");
  await page.getByRole("link", { name: "Inventory", exact: true }).click();
  await page.getByRole("link", { name: "Goods receipts", exact: true }).click();
  await page
    .getByRole("combobox", { name: "Warehouse", exact: true })
    .selectOption({ label: "Main warehouse" });
  await page
    .getByRole("combobox", { name: "Supplier", exact: true })
    .selectOption({ label: "Inventory Test Supplier" });
  await page
    .getByRole("combobox", { name: "Product 1", exact: true })
    .selectOption({ label: "INV-LOT · Inventory Test Product" });
  await page
    .getByRole("combobox", { name: "Unit 1", exact: true })
    .selectOption({ label: "Carton" });
  await page.getByLabel("Received quantity", { exact: true }).fill("2");
  await page
    .getByLabel("Actual cost per selected unit", { exact: true })
    .fill("12.345678");
  const lot = "BROWSER-" + Date.now();
  await page.getByLabel("Lot code", { exact: true }).fill(lot);
  const businessDate = await page
    .getByLabel("Business date", { exact: true })
    .inputValue();
  await page.getByLabel("Expiry date", { exact: true }).fill(businessDate);
  await page
    .getByRole("button", { name: "Preview posting", exact: true })
    .click();
  await expect(
    page.getByText("INV-LOT: 48 base units", { exact: false }),
  ).toBeVisible();
  await page
    .getByRole("button", { name: "Confirm and post", exact: true })
    .click();
  await expect(page.getByText(/Posted GRN-/)).toBeVisible();
  await page.getByRole("link", { name: "View document", exact: true }).click();
  await expect(
    page.getByRole("button", { name: "Print", exact: true }),
  ).toBeVisible();
  await expect(
    page.getByText("Total: LKR 24.69", { exact: true }),
  ).toBeVisible();
  await page.setViewportSize({ width: 1440, height: 1000 });
  await page.screenshot({
    path: path.join(root, "p105-receipt-desktop.png"),
    fullPage: true,
  });
  await page.getByRole("link", { name: "Stock", exact: true }).click();
  await page.getByLabel("Exact batch", { exact: true }).fill(lot);
  const row = page.getByRole("row").filter({ hasText: lot });
  await expect(row).toContainText("48 EA on hand");
  await expect(row).toContainText("48 available");
  await page.setViewportSize({ width: 390, height: 844 });
  expect(
    await page.evaluate(
      () => document.documentElement.scrollWidth <= window.innerWidth,
    ),
  ).toBe(true);
  await page.screenshot({
    path: path.join(root, "p105-stock-mobile.png"),
    fullPage: true,
  });
});
