import type { NextConfig } from "next";

// Development/local-Node transport only; production Nginx routes /api to .NET.
// This is a fixed proxy, not a second business API or an authorization layer.
const apiTarget = new URL(
  process.env.API_PROXY_TARGET ?? "http://127.0.0.1:5180",
);
if (
  !["http:", "https:"].includes(apiTarget.protocol) ||
  apiTarget.username ||
  apiTarget.password ||
  apiTarget.pathname !== "/" ||
  apiTarget.search ||
  apiTarget.hash
) {
  throw new Error("API_PROXY_TARGET must be a credential-free HTTP(S) origin.");
}

const config: NextConfig = {
  output: "standalone",
  poweredByHeader: false,
  reactStrictMode: true,
  async rewrites() {
    return [
      { source: "/api/:path*", destination: `${apiTarget.origin}/api/:path*` },
    ];
  },
  async headers() {
    return [
      ...[
        "/login",
        "/app",
        "/settings/:path*",
        "/inventory/:path*",
        "/account/:path*",
        "/select-business",
      ].map((source) => ({
        source,
        headers: [
          { key: "Cache-Control", value: "private, no-store, max-age=0" },
        ],
      })),
      {
        source: "/:path*",
        headers: [
          { key: "X-Content-Type-Options", value: "nosniff" },
          { key: "X-Frame-Options", value: "DENY" },
          { key: "Referrer-Policy", value: "same-origin" },
          {
            key: "Content-Security-Policy",
            value: "frame-ancestors 'none'; base-uri 'self'; object-src 'none'",
          },
        ],
      },
    ];
  },
};
export default config;
