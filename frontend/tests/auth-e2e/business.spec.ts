import { test, expect, type Page } from "@playwright/test";
import { readFileSync, mkdirSync } from "node:fs";
import path from "node:path";
import { randomBytes } from "node:crypto";

test("controlled onboarding forces password replacement before business access", async ({
  page,
}) => {
  const forced = JSON.parse(
    readFileSync(
      path.resolve("../artifacts/auth-review/browser-forced-fixture.json"),
      "utf8",
    ),
  ) as { email: string; password: string };
  await page.goto("/login");
  await page.getByLabel("Email address").fill(forced.email);
  await page.getByLabel("Password", { exact: true }).fill(forced.password);
  await page.getByRole("button", { name: "Sign in", exact: true }).click();
  await expect(page).toHaveURL(/account\/password/);
  await expect(
    page.getByRole("heading", { name: "Set your own password" }),
  ).toBeVisible();
  const replacement = randomBytes(32).toString("base64url");
  await page.getByLabel("Current or temporary password").fill(forced.password);
  await page.getByLabel("New password", { exact: true }).fill(replacement);
  await page.getByLabel("Confirm new password").fill(replacement);
  await page.getByRole("button", { name: "Update password" }).click();
  await expect(page).toHaveURL(/\/app$/);
  await expect(
    page.getByRole("heading", { name: "Your business is connected." }),
  ).toBeVisible();
});
const evidence = path.resolve("../artifacts/auth-review");
const fixture = JSON.parse(
  readFileSync(path.join(evidence, "browser-fixture.json"), "utf8"),
) as { email: string; password: string; businessName: string };
async function login(page: Page) {
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
  await expect(page.getByRole("heading", { name: /Welcome,/ })).toBeVisible();
}
test("branded login, selected business and private cache headers", async ({
  page,
  request,
}) => {
  mkdirSync(evidence, { recursive: true });
  const response = await page.goto("/login");
  expect(response?.headers()["cache-control"]).toContain("no-store");
  await page.screenshot({
    path: path.join(evidence, "login-desktop.png"),
    fullPage: true,
  });
  await login(page);
  const cookie = (await page.context().cookies()).find(
    (c) => c.name === "Conex360.Dev.Session",
  );
  expect(cookie?.httpOnly).toBe(true);
  expect(cookie?.sameSite).toBe("Lax");
  await expect(
    page.getByRole("heading", { name: "Your business is connected." }),
  ).toBeVisible();
  await page.screenshot({
    path: path.join(evidence, "workspace-desktop.png"),
    fullPage: true,
  });
  expect((await request.get("/api/v1/business/")).status()).toBe(401);
  const html = await page.request.get("/app?_rsc=synthetic", {
    headers: { RSC: "1" },
  });
  expect(html.headers()["cache-control"]).toContain("no-store");
  expect(await html.text()).not.toContain(fixture.email);
});
test("business profile, validation, sanitized logo and mobile layout", async ({
  page,
}) => {
  await login(page);
  await page
    .getByRole("link", { name: "Business settings", exact: true })
    .click();
  await expect(page.getByLabel("Business name", { exact: true })).toBeVisible();
  await page.getByLabel("Contact number").fill("+94 11 000 0000");
  await page.getByRole("button", { name: "Save changes" }).click();
  await expect(page.getByRole("status")).toContainText(
    "Business profile saved.",
  );
  await page.getByLabel("Choose logo").setInputFiles({
    name: "unsafe.svg",
    mimeType: "image/svg+xml",
    buffer: Buffer.from("<svg onload='alert(1)'/>"),
  });
  await page.getByRole("button", { name: "Upload logo" }).click();
  await expect(page.locator(".auth-error")).toContainText("PNG or JPEG");
  const png = Buffer.from(
    "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=",
    "base64",
  );
  await page.getByLabel("Choose logo").setInputFiles({
    name: "synthetic.png",
    mimeType: "image/png",
    buffer: png,
  });
  await page.getByRole("button", { name: "Upload logo" }).click();
  await expect(page.getByRole("status")).toContainText(
    "Business logo updated.",
  );
  await expect(page.getByAltText("Business logo")).toBeVisible();
  await page
    .context()
    .storageState({ path: path.join(evidence, "persistence-session.json") });
  const s = (await (await page.request.get("/api/v1/auth/session")).json()) as {
    contextVersion: string;
  };
  const logo = await page.request.get(
    `/api/v1/business/logo?context=${s.contextVersion}`,
  );
  expect(logo.status()).toBe(200);
  expect(logo.headers()["cache-control"]).toContain("no-store");
  await page.screenshot({
    path: path.join(evidence, "business-desktop.png"),
    fullPage: true,
  });
  await page.setViewportSize({ width: 390, height: 844 });
  await page.screenshot({
    path: path.join(evidence, "business-mobile.png"),
    fullPage: true,
  });
  expect(
    await page.evaluate(
      () => document.documentElement.scrollWidth <= window.innerWidth,
    ),
  ).toBe(true);
});
test("password mismatch is accessible and logout invalidates another window", async ({
  page,
  context,
}) => {
  await login(page);
  const other = await context.newPage();
  await other.goto("/app");
  await expect(other.getByRole("heading", { name: /Welcome,/ })).toBeVisible();
  await page.getByRole("link", { name: "Password & security" }).click();
  await page.getByLabel("Current or temporary password").fill(fixture.password);
  await page
    .getByLabel("New password", { exact: true })
    .fill("Synthetic mismatch phrase one");
  await page
    .getByLabel("Confirm new password")
    .fill("Synthetic mismatch phrase two");
  await page.getByRole("button", { name: "Update password" }).click();
  await expect(page.locator(".auth-error")).toContainText("do not match");
  await page.getByLabel("Account menu").click();
  await page.getByRole("button", { name: "Sign out" }).click();
  await expect(page).toHaveURL(/login/);
  await expect(other).toHaveURL(/login/);
  await expect(
    other.getByRole("heading", { name: "Welcome back" }),
  ).toBeVisible();
});
test("invalid credentials and unsafe return URL stay on the approved application", async ({
  page,
}) => {
  await page.goto("/login?returnTo=https://attacker.invalid");
  await page.getByLabel("Email address").fill(fixture.email);
  await page
    .getByLabel("Password", { exact: true })
    .fill("incorrect synthetic password");
  await page.getByRole("button", { name: "Sign in", exact: true }).click();
  await expect(page.locator(".auth-error")).toContainText(
    "Sign-in was unsuccessful",
  );
  await page.getByLabel("Password", { exact: true }).fill(fixture.password);
  await page.getByRole("button", { name: "Sign in", exact: true }).click();
  await expect(page).toHaveURL(/select-business/);
  expect(new URL(page.url()).hostname).toBe("127.0.0.1");
});
