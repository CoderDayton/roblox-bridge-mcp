/**
 * Custom error classes for Roblox Studio MCP operations
 *
 * Error Hierarchy:
 * - Error (base)
 *   ├── RobloxTimeoutError: Plugin unresponsive or Studio not running
 *   ├── InstanceNotFoundError: Invalid instance path
 *   ├── InvalidParameterError: Invalid method parameters
 *   ├── RobloxExecutionError: Roblox reported execution failure
 *   └── BridgeConnectionError: Bridge server unreachable
 *
 * All custom errors preserve method context for debugging and include
 * specific information relevant to the failure mode.
 */

/**
 * Error thrown when Roblox Studio times out on command execution
 * Indicates the plugin is not polling, Studio crashed, or network issues
 * @property method - Roblox API method that timed out
 * @property attempt - Retry attempt number when timeout occurred
 */
export class RobloxTimeoutError extends Error {
  constructor(
    message = "Roblox Studio execution timed out. Ensure the plugin is installed and Studio is running.",
    public readonly method?: string,
    public readonly attempt?: number
  ) {
    super(message);
    this.name = "RobloxTimeoutError";
  }
}

/**
 * Error thrown when a requested instance path cannot be resolved in the Roblox DataModel
 * Common causes: typo in path, instance was deleted, parent doesn't exist
 * @example throw new InstanceNotFoundError("game.Workspace.NonExistent")
 */
export class InstanceNotFoundError extends Error {
  constructor(path: string) {
    super(`Instance not found at path: ${path}`);
    this.name = "InstanceNotFoundError";
  }
}

/**
 * Error thrown when a tool receives invalid parameters
 * Indicates client-side validation failure or type mismatch
 * @property method - Roblox API method that received invalid parameters
 */
export class InvalidParameterError extends Error {
  constructor(
    message: string,
    public readonly method?: string
  ) {
    super(message);
    this.name = "InvalidParameterError";
  }
}

/**
 * Error thrown when Roblox reports an execution error
 * The command reached Roblox successfully but failed during execution
 * @property method - Roblox API method that failed
 * @property params - Parameters passed to the method (for debugging)
 */
export class RobloxExecutionError extends Error {
  constructor(
    message: string,
    public readonly method?: string,
    public readonly params?: Record<string, unknown>
  ) {
    super(message);
    this.name = "RobloxExecutionError";
  }
}

/** Error thrown when the WebSocket bridge server cannot be reached */
export class BridgeConnectionError extends Error {
  constructor(message = "Cannot connect to Roblox bridge. Is the server running?") {
    super(message);
    this.name = "BridgeConnectionError";
  }
}
