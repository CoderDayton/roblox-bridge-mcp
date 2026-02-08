import { config as loadEnv } from "dotenv";

// Load .env file silently (debug output breaks MCP JSON protocol)
loadEnv({ debug: false });

// Single source of truth: read version from package.json
import pkg from "../package.json";

export interface Config {
  /** Server version for protocol compatibility checks */
  version: string;
  /** Port for the Roblox WebSocket bridge server (default: 62847) */
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
 * Version from package.json — single source of truth.
 * Pre-compute parts at module load for fast comparison.
 */
const SERVER_VERSION = pkg.version;
const firstDot = SERVER_VERSION.indexOf(".");
const secondDot = SERVER_VERSION.indexOf(".", firstDot + 1);
const SERVER_MAJOR = SERVER_VERSION.substring(0, firstDot);
const SERVER_MINOR = SERVER_VERSION.substring(firstDot + 1, secondDot);

/**
 * Check if a plugin version is compatible with the server version.
 * Versions are compatible if major.minor match (patch can differ).
 *
 * Optimized to avoid string splits by using indexOf/substring.
 *
 * @param pluginVersion - Version string from the plugin (e.g., "2.0.0")
 * @returns true if compatible, false otherwise
 */
export function isVersionCompatible(pluginVersion: string): boolean {
  // Find version separators
  const firstDotIdx = pluginVersion.indexOf(".");
  if (firstDotIdx === -1) return false;

  const secondDotIdx = pluginVersion.indexOf(".", firstDotIdx + 1);
  if (secondDotIdx === -1) return false;

  // Extract major and minor (patch is ignored)
  const major = pluginVersion.substring(0, firstDotIdx);
  const minor = pluginVersion.substring(firstDotIdx + 1, secondDotIdx);

  // Compare with cached server version parts
  return major === SERVER_MAJOR && minor === SERVER_MINOR;
}

export const config: Config = {
  version: SERVER_VERSION,
  bridgePort: parseNumber(process.env.ROBLOX_BRIDGE_PORT, 62847),
  timeout: parseNumber(process.env.ROBLOX_TIMEOUT_MS, 30_000),
  retries: parseNumber(process.env.ROBLOX_RETRIES, 2),
};
