export type ApiHealth = {
  status: "healthy";
  service: "conex360-api";
  version: string;
  scope: "process";
  timestamp: string;
};

export class HealthCheckError extends Error {
  constructor(message = "Conex360 could not be reached. Please try again.") {
    super(message);
    this.name = "HealthCheckError";
  }
}

function isApiHealth(value: unknown): value is ApiHealth {
  if (!value || typeof value !== "object") return false;
  const data = value as Record<string, unknown>;
  return (
    data.status === "healthy" &&
    data.service === "conex360-api" &&
    data.scope === "process" &&
    typeof data.version === "string" &&
    data.version.length > 0 &&
    typeof data.timestamp === "string" &&
    Number.isFinite(Date.parse(data.timestamp))
  );
}

export async function readApiHealth(
  fetcher: typeof fetch = fetch,
  signal?: AbortSignal,
): Promise<ApiHealth> {
  const response = await fetcher("/api/v1/health", {
    cache: "no-store",
    credentials: "same-origin",
    signal,
    headers: { Accept: "application/json" },
  });
  if (
    !response.ok ||
    !response.headers.get("content-type")?.includes("application/json")
  ) {
    throw new HealthCheckError();
  }
  let data: unknown;
  try {
    data = await response.json();
  } catch {
    throw new HealthCheckError(
      "The connection returned an unreadable response. Please try again.",
    );
  }
  if (!isApiHealth(data))
    throw new HealthCheckError(
      "The connection response was not recognised. Please try again.",
    );
  return data;
}
