import { config as loadEnv } from "dotenv";

// Load .env file if it exists
loadEnv();

export interface Config {
  /** Port for the Roblox HTTP bridge server (default: 8081) */
  bridgePort: number;
  /** Timeout in milliseconds for Roblox command execution (default: 30000) */
  timeout: number;
}

function parseNumber(value: string | undefined, defaultValue: number): number {
  if (!value) return defaultValue;
  const parsed = Number(value);
  return isNaN(parsed) ? defaultValue : parsed;
}

export const config: Config = {
  bridgePort: parseNumber(process.env.ROBLOX_BRIDGE_PORT, 8081),
  timeout: parseNumber(process.env.ROBLOX_TIMEOUT_MS, 30_000),
};
