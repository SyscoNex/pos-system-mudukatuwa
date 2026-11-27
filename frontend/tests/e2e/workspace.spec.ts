import { expect, test } from "@playwright/test";

test("the built workspace connects to the real .NET API", async ({
  page,
  request,
}) => {
  const errors: string[] = [];
  page.on("pageerror", (error) => errors.push(error.message));
  await page.setViewportSize({ width: 1440, height: 1080 });
  await page.goto("/");
  await expect(
    page.getByRole("heading", { name: "A fresh workspace. A solid start." }),
  ).toBeVisible();
  await expect(
    page.getByText("Connected to Conex360", { exact: true }),
  ).toBeVisible();
  await expect(
    page.getByText(
      "Process health is available. Sign in for your business workspace.",
    ),
  ).toBeVisible();
  const health = await request.get("/api/v1/health");
  expect((await health.json()).scope).toBe("process");
  expect(health.headers()["cache-control"]).toContain("no-store");
  const html = await request.get("/");
  expect(html.headers()["cache-control"]).toContain("no-store");
  expect(errors).toEqual([]);
  await page.screenshot({
    path: "../artifacts/frontend-desktop.png",
    fullPage: true,
  });
});

test("failed health checks can be retried without inventing a connection", async ({
  page,
}) => {
  await page.route("**/api/v1/health", (route) =>
    route.fulfill({ status: 503, json: { status: "unavailable" } }),
  );
  await page.goto("/");
  await expect(
    page.getByText("Let’s reconnect", { exact: true }),
  ).toBeVisible();
  await page.unroute("**/api/v1/health");
  await page
    .getByRole("button", { name: "Check connection", exact: true })
    .click();
  await expect(
    page.getByText("Connected to Conex360", { exact: true }),
  ).toBeVisible();
});

test("quick guide supports keyboard dismissal and returns focus", async ({
  page,
}) => {
  await page.goto("/");
  const button = page.getByRole("button", { name: "Quick guide" });
  await button.click();
  await expect(page.getByRole("dialog")).toBeVisible();
  await page.keyboard.press("Escape");
  await expect(page.getByRole("dialog")).not.toBeVisible();
  await expect(button).toBeFocused();
});

test("mobile navigation and layout remain usable without overflow", async ({
  page,
}) => {
  await page.setViewportSize({ width: 390, height: 844 });
  await page.goto("/");
  await expect(
    page.getByText("Connected to Conex360", { exact: true }),
  ).toBeVisible();
  await page.getByRole("button", { name: "Open navigation" }).click();
  await expect(
    page.getByRole("navigation", { name: "Main navigation" }),
  ).toBeVisible();
  await page.getByRole("link", { name: "Build journey", exact: true }).click();
  await expect(
    page.getByRole("heading", { name: "The build journey" }),
  ).toBeInViewport();
  await expect(page.locator("#journey")).toBeFocused();
  await expect(
    page.getByRole("button", { name: "Open navigation" }),
  ).toHaveAttribute("aria-expanded", "false");
  expect(
    await page.evaluate(
      () => document.documentElement.scrollWidth <= window.innerWidth,
    ),
  ).toBe(true);
  await page.screenshot({
    path: "../artifacts/frontend-mobile.png",
    fullPage: true,
  });
});
