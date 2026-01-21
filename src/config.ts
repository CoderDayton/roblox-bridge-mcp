import { config as loadEnv } from "dotenv";

// Load .env file silently (debug output breaks MCP JSON protocol)
loadEnv({ debug: false });

export interface Config {
  /** Port for the Roblox HTTP bridge server (default: 53847) */
  bridgePort: number;
  /** Timeout in milliseconds for Roblox command execution (default: 30000) */
  timeout: number;
  /** Number of retry attempts for failed commands (default: 2) */
  retries: number;
  /** API key for bridge server authentication (optional, generates random if not set) */
  apiKey: string;
}

function parseNumber(value: string | undefined, defaultValue: number): number {
  if (!value) return defaultValue;
  const parsed = Number(value);
  return isNaN(parsed) ? defaultValue : parsed;
}

/** Generate a random API key */
function generateApiKey(): string {
  return crypto.randomUUID().replace(/-/g, "");
}

export const config: Config = {
  bridgePort: parseNumber(process.env.ROBLOX_BRIDGE_PORT, 53847),
  timeout: parseNumber(process.env.ROBLOX_TIMEOUT_MS, 30_000),
  retries: parseNumber(process.env.ROBLOX_RETRIES, 2),
  apiKey: process.env.ROBLOX_API_KEY || generateApiKey(),
};
