import { test, expect } from "@playwright/test";
import { readFileSync, mkdirSync } from "node:fs";
import path from "node:path";

test("outlet setup, warehouse default and Staff outlet assignment", async ({
  page,
}) => {
  const root = path.resolve("../artifacts/auth-review");
  mkdirSync(root, { recursive: true });
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
  await page.getByRole("link", { name: "Outlets", exact: true }).click();
  await page.getByRole("button", { name: "Add outlet" }).click();
  const dialog = page.getByRole("dialog");
  const suffix = Date.now().toString().slice(-8);
  const outletName = `Demo factory ${suffix}`;
  await dialog.getByLabel("Name", { exact: true }).fill(outletName);
  await dialog.getByLabel("Code", { exact: true }).fill(`FACT-${suffix}`);
  await dialog
    .getByLabel("Reason", { exact: true })
    .fill("Browser outlet setup");
  await dialog.getByRole("button", { name: "Create", exact: true }).click();
  await expect(
    page.getByRole("cell", { name: outletName, exact: true }),
  ).toBeVisible();
  await page.getByRole("link", { name: "Warehouses", exact: true }).click();
  await expect(
    page.getByText("Main warehouse", { exact: true }).first(),
  ).toBeVisible();
  await page.getByRole("button", { name: "Add warehouse" }).click();
  await dialog
    .getByRole("combobox", { name: "Outlet", exact: true })
    .selectOption({ label: outletName });
  await dialog.getByLabel("Name", { exact: true }).fill(`Packaging ${suffix}`);
  await dialog.getByLabel("Code", { exact: true }).fill(`PACK-${suffix}`);
  await dialog
    .getByLabel("Default warehouse for this outlet", { exact: true })
    .check();
  await dialog
    .getByLabel("Reason", { exact: true })
    .fill("Browser warehouse setup");
  await dialog.getByRole("button", { name: "Create", exact: true }).click();
  await expect(
    page.getByRole("cell", { name: new RegExp(`Packaging ${suffix}`) }),
  ).toBeVisible();
  await page.getByRole("link", { name: "Users & access", exact: true }).click();
  await page.getByRole("button", { name: "Add Staff" }).click();
  await dialog
    .getByLabel("Display name", { exact: true })
    .fill(`Demo Staff ${suffix}`);
  await dialog
    .getByLabel("Email address", { exact: true })
    .fill(`staff-${suffix}@example.invalid`);
  await dialog.getByLabel(outletName, { exact: true }).check();
  await dialog
    .getByLabel("Reason", { exact: true })
    .fill("Browser Staff assignment");
  await dialog.getByRole("button", { name: "Create", exact: true }).click();
  const handoff = page.getByRole("dialog", { name: "Staff account created" });
  await expect(handoff).toBeVisible();
  await expect(
    handoff.getByLabel("Temporary password", { exact: true }),
  ).not.toBeEmpty();
  await handoff
    .getByRole("button", { name: "I have handed it over securely" })
    .click();
  const row = page.getByRole("row").filter({ hasText: `Demo Staff ${suffix}` });
  await expect(row).toContainText(outletName);
  await row.getByRole("button", { name: "Edit", exact: true }).click();
  await dialog.getByLabel(outletName, { exact: true }).uncheck();
  await dialog
    .getByLabel("Reason", { exact: true })
    .fill("Browser grant removal");
  await dialog.getByLabel(/I confirm this change/).check();
  await dialog
    .getByRole("button", { name: "Save changes", exact: true })
    .click();
  await expect(row).toContainText("No outlet access");
  await page.setViewportSize({ width: 1440, height: 950 });
  await page.screenshot({
    path: path.join(root, "p103-users-desktop.png"),
    fullPage: true,
  });
  await page.getByRole("link", { name: "Outlets", exact: true }).click();
  await page.setViewportSize({ width: 390, height: 844 });
  await expect(page.getByRole("button", { name: "Add outlet" })).toBeVisible();
  expect(
    await page.evaluate(
      () => document.documentElement.scrollWidth <= window.innerWidth,
    ),
  ).toBe(true);
  await page.screenshot({
    path: path.join(root, "p103-outlets-mobile.png"),
    fullPage: true,
  });
});
