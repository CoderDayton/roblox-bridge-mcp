import { config as loadEnv } from "dotenv";

// Load .env file silently (debug output breaks MCP JSON protocol)
loadEnv({ debug: false });

export interface Config {
  /** Server version for protocol compatibility checks */
  version: string;
  /** Port for the Roblox HTTP bridge server (default: 62847) */
  bridgePort: number;
  /** Timeout in milliseconds for Roblox command execution (default: 30000) */
  timeout: number;
  /** Number of retry attempts for failed commands (default: 2) */
  retries: number;
}

function parseNumber(value: string | undefined, defaultValue: number): number {
  const parsed = Number(value);
  return isNaN(parsed) || !value ? defaultValue : parsed;
}

/**
 * Check if a plugin version is compatible with the server version.
 * Versions are compatible if major.minor match (patch can differ).
 * @param pluginVersion - Version string from the plugin (e.g., "1.1.0")
 * @returns true if compatible, false otherwise
 */
export function isVersionCompatible(pluginVersion: string): boolean {
  const serverParts = config.version.split(".");
  const pluginParts = pluginVersion.split(".");

  // Must have at least major.minor
  if (serverParts.length < 2 || pluginParts.length < 2) {
    return false;
  }

  // Major and minor must match
  return serverParts[0] === pluginParts[0] && serverParts[1] === pluginParts[1];
}

export const config: Config = {
  version: "1.1.0",
  bridgePort: parseNumber(process.env.ROBLOX_BRIDGE_PORT, 62847),
  timeout: parseNumber(process.env.ROBLOX_TIMEOUT_MS, 30_000),
  retries: parseNumber(process.env.ROBLOX_RETRIES, 2),
};
