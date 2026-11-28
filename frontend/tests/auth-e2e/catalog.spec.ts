import { test, expect } from "@playwright/test";
import { readFileSync } from "node:fs";
import path from "node:path";

test("product alternative unit, exact price/barcode and supplier setup", async ({
  page,
}) => {
  const root = path.resolve("../artifacts/auth-review");
  const fixture = JSON.parse(
    readFileSync(path.join(root, "browser-fixture.json"), "utf8"),
  ) as { email: string; password: string; businessName: string };
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
  await page.getByRole("link", { name: "Units", exact: true }).click();
  await page.getByRole("button", { name: "Set up standard units" }).click();
  await expect(
    page.getByRole("cell", { name: "Carton", exact: true }),
  ).toBeVisible();
  const suffix = Date.now().toString().slice(-8);
  const dialog = page.getByRole("dialog");
  await page.getByRole("link", { name: "Categories", exact: true }).click();
  await page.getByRole("button", { name: "Add category" }).click();
  await dialog.getByLabel("Name", { exact: true }).fill(`Packaging ${suffix}`);
  await dialog.getByLabel("Code", { exact: true }).fill(`PACK-${suffix}`);
  await dialog
    .getByLabel("Reason", { exact: true })
    .fill("Synthetic browser category");
  await dialog.getByRole("button", { name: "Create", exact: true }).click();
  await expect(
    page.getByRole("cell", { name: `Packaging ${suffix}`, exact: true }),
  ).toBeVisible();
  await page.getByRole("link", { name: "Products", exact: true }).click();
  await page.getByRole("button", { name: "Add product" }).click();
  await dialog
    .getByLabel("Name", { exact: true })
    .fill(`Empty bottle ${suffix}`);
  await dialog.getByLabel("SKU", { exact: true }).fill(`BOTTLE-${suffix}`);
  await dialog
    .getByRole("combobox", { name: "Category", exact: true })
    .selectOption({ label: `Packaging ${suffix}` });
  await dialog
    .getByRole("combobox", { name: "Base unit", exact: true })
    .selectOption({ label: "Piece (EA)" });
  await dialog
    .getByRole("combobox", { name: "Product type", exact: true })
    .selectOption("PACKAGING");
  await dialog.getByText("Units, prices & barcodes", { exact: true }).click();
  await dialog
    .getByLabel("Purchase price 1", { exact: true })
    .fill("12.123456");
  await dialog.getByLabel("Selling price 1", { exact: true }).fill("20.000001");
  await dialog.getByRole("button", { name: "Add alternative unit" }).click();
  await dialog
    .getByRole("combobox", { name: "Unit 2", exact: true })
    .selectOption({ label: "Carton (CARTON)" });
  await dialog.getByLabel("Conversion factor 2", { exact: true }).fill("24");
  await dialog.getByLabel("Selling price 2", { exact: true }).fill("480");
  await dialog
    .getByRole("button", { name: "Add barcode to unit 2", exact: true })
    .click();
  const barcode = `000${suffix}`;
  await dialog.getByLabel("Barcode 2.1", { exact: true }).fill(barcode);
  await dialog
    .getByLabel("Reason", { exact: true })
    .fill("Synthetic product packaging setup");
  await dialog.getByRole("button", { name: "Create", exact: true }).click();
  const row = page.getByRole("row").filter({ hasText: `BOTTLE-${suffix}` });
  await expect(row).toBeVisible();
  await row.getByRole("button", { name: "Edit", exact: true }).click();
  await expect(dialog.getByLabel("Barcode 2.1", { exact: true })).toHaveValue(
    barcode,
  );
  await expect(
    dialog.getByLabel("Selling price 1", { exact: true }),
  ).toHaveValue("20.000001");
  await page.setViewportSize({ width: 1440, height: 1050 });
  await page.screenshot({
    path: path.join(root, "p104-product-desktop.png"),
    fullPage: true,
  });
  await page.setViewportSize({ width: 390, height: 844 });
  expect(
    await page.evaluate(
      () => document.documentElement.scrollWidth <= window.innerWidth,
    ),
  ).toBe(true);
  await page.screenshot({
    path: path.join(root, "p104-product-mobile.png"),
    fullPage: true,
  });
  await dialog.getByRole("button", { name: "Close dialog" }).click();
  await page.getByRole("link", { name: "Suppliers", exact: true }).click();
  await page.getByRole("button", { name: "Add supplier" }).click();
  await dialog.getByLabel("Name", { exact: true }).fill(`Supplier ${suffix}`);
  await dialog.getByLabel("Code", { exact: true }).fill(`SUP-${suffix}`);
  await dialog
    .getByLabel("Email", { exact: true })
    .fill("synthetic@example.invalid");
  await dialog
    .getByLabel("Reason", { exact: true })
    .fill("Synthetic supplier setup");
  await dialog.getByRole("button", { name: "Create", exact: true }).click();
  await expect(
    page.getByRole("cell", { name: `Supplier ${suffix}`, exact: true }),
  ).toBeVisible();
});
