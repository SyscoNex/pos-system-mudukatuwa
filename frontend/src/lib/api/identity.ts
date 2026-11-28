export type Session = {
  user: { publicId: string; displayName: string; mustChangePassword: boolean };
  memberships: {
    id: string;
    businessName: string;
    role: "ADMINISTRATOR" | "STAFF";
  }[];
  selectedMembershipId: string | null;
  contextVersion: string;
  absoluteExpiresAt: string;
  idleExpiresAt: string;
};
export type Business = {
  id: string;
  tenantId: string;
  businessName: string;
  displayName: string;
  phone: string | null;
  email: string | null;
  address: string | null;
  timezone: string;
  currencyCode: string;
  currencyMinorUnits: number;
  logoKey: string | null;
  version: string;
};
export class ApiError extends Error {
  public status: number;
  public code: string;
  constructor(status: number, code: string, message: string) {
    super(message);
    this.status = status;
    this.code = code;
  }
}
export async function api<T>(
  path: string,
  init: RequestInit = {},
  context?: string,
): Promise<T> {
  const headers = new Headers(init.headers);
  if (context) headers.set("X-Conex360-Context", context);
  if (init.method && init.method !== "GET") {
    const csrf = await fetch("/api/v1/auth/csrf", {
      cache: "no-store",
      credentials: "same-origin",
    });
    if (!csrf.ok)
      throw new ApiError(
        csrf.status,
        "CONNECTION",
        "Unable to verify the request. Try again.",
      );
    headers.set(
      "X-CSRF-TOKEN",
      ((await csrf.json()) as { token: string }).token,
    );
    if (typeof init.body === "string")
      headers.set("Content-Type", "application/json");
  }
  const response = await fetch(`/api/v1${path}`, {
    ...init,
    headers,
    cache: "no-store",
    credentials: "same-origin",
  });
  if (!response.ok) {
    const problem = (await response.json().catch(() => ({}))) as {
      code?: string;
      title?: string;
    };
    throw new ApiError(
      response.status,
      problem.code ?? "REQUEST_FAILED",
      response.status === 429
        ? "Too many attempts. Wait a minute before trying again."
        : (problem.title ??
            (response.status === 401
              ? "Your session has ended. Sign in again."
              : "Unable to complete the request. Try again.")),
    );
  }
  return (response.status === 204 ? undefined : await response.json()) as T;
}
export function safeReturnPath(value: string | null): string {
  return [
    "/app",
    "/settings/business",
    "/settings/outlets",
    "/settings/warehouses",
    "/settings/users",
    "/settings/products",
    "/settings/categories",
    "/settings/units",
    "/settings/suppliers",
    "/account/password",
    "/select-business",
  ].includes(value ?? "")
    ? value!
    : "/app";
}
// Invalidation only; no credentials, IDs or business data cross tabs or enter browser storage.
let invalidationChannel: BroadcastChannel | undefined;
export function sessionInvalidations(): BroadcastChannel | null {
  if (typeof window === "undefined" || typeof BroadcastChannel === "undefined")
    return null;
  // Use one object per window: BroadcastChannel excludes its own sending object.
  invalidationChannel ??= new BroadcastChannel(
    "conex360-session-invalidation-v1",
  );
  return invalidationChannel;
}
export function invalidateTabs() {
  sessionInvalidations()?.postMessage("invalidate");
}
