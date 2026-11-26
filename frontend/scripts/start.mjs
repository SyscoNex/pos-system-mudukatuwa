import { resolve } from "node:path";
import { pathToFileURL } from "node:url";

process.env.PORT ??= "3600";
process.env.HOSTNAME = "127.0.0.1";
await import(pathToFileURL(resolve(".next/standalone/server.js")).href);
