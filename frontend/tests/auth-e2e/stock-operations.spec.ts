import { test, expect } from "@playwright/test";
import { readFileSync } from "node:fs";
import path from "node:path";

test("transfer request, dispatch, partial receipt and count freeze smoke", async ({
  page,
}) => {
  test.skip(
    process.env.CONEX360_STOCK_OPERATIONS_MYSQL_APPROVED !== "1",
    "Requires the approved P1-06 synthetic database.",
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
  await page.getByRole("link", { name: "Inventory", exact: true }).click();
  await page.getByRole("link", { name: "Transfers", exact: true }).click();
  await page
    .getByRole("combobox", { name: "Source warehouse", exact: true })
    .selectOption({ label: "Transfer Source · Main warehouse" });
  const [destinationId] = await page
    .getByRole("combobox", { name: "Destination warehouse", exact: true })
    .selectOption({ label: "Transfer Destination · Main warehouse" });
  if (!destinationId) throw new Error("Transfer destination was not selected.");
  await page
    .getByRole("combobox", { name: "Product 1", exact: true })
    .selectOption({ label: "P106-ITEM · Transfer Fixture" });
  await page
    .getByRole("combobox", { name: "Unit 1", exact: true })
    .selectOption({ label: "Piece" });
  await page.getByLabel("Quantity 1", { exact: true }).fill("3");
  await page
    .getByLabel("Reference", { exact: true })
    .fill("Synthetic browser transfer");
  const post = () =>
    page.getByRole("button", { name: "Confirm and post", exact: true }).click();
  await page
    .getByRole("button", { name: "Review request", exact: true })
    .click();
  await post();
  const detail = page.getByRole("region", { name: "Transfer detail" });
  await expect(detail.getByRole("heading", { name: /XREQ-/ })).toBeVisible();
  await detail
    .getByRole("button", { name: "Review reservation", exact: true })
    .click();
  await post();
  await detail.getByLabel("Dispatch quantity", { exact: true }).fill("3");
  await detail
    .getByRole("button", { name: "Review dispatch", exact: true })
    .click();
  await post();
  await detail
    .getByLabel("Transfer action", { exact: true })
    .selectOption("receive");
  await detail.getByLabel("Allocation quantity", { exact: true }).fill("1");
  await detail
    .getByRole("button", { name: "Review receive", exact: true })
    .click();
  await post();
  await expect(detail.getByText(/2 base units remaining/)).toBeVisible();
  await detail.getByLabel("Allocation quantity", { exact: true }).fill("2");
  await detail
    .getByRole("button", { name: "Review receive", exact: true })
    .click();
  await post();
  await expect(
    detail.getByText("No accessible allocations for this action."),
  ).toBeVisible();
  await page.screenshot({
    path: path.join(evidence, "p106-transfer.png"),
    fullPage: true,
  });
  await page.getByRole("link", { name: "Stock takes", exact: true }).click();
  const warehouse = page.getByRole("combobox", {
    name: "Count warehouse",
    exact: true,
  });
  await warehouse.selectOption({ value: destinationId });
  await page
    .getByRole("button", { name: "Review stock take", exact: true })
    .click();
  await post();
  const count = page.getByRole("region", { name: "Count detail" });
  await expect(count.getByText(/COUNTING/)).toBeVisible();
  await count
    .getByLabel("Cancellation reason", { exact: true })
    .fill("Browser smoke complete");
  await count
    .getByRole("button", { name: "Review cancellation", exact: true })
    .click();
  await post();
  await expect(count.getByText(/CANCELLED/)).toBeVisible();
});
