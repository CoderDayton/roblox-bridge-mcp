/**
 * Custom errors for Roblox Studio MCP operations
 */

/** Error thrown when Roblox Studio is not responding or plugin is not running */
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

/** Error thrown when a requested instance path cannot be resolved */
export class InstanceNotFoundError extends Error {
  constructor(path: string) {
    super(`Instance not found at path: ${path}`);
    this.name = "InstanceNotFoundError";
  }
}

/** Error thrown when a tool receives invalid parameters */
export class InvalidParameterError extends Error {
  constructor(
    message: string,
    public readonly method?: string
  ) {
    super(message);
    this.name = "InvalidParameterError";
  }
}

/** Error thrown when Roblox reports an execution error */
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

/** Error thrown when the bridge server cannot be reached */
export class BridgeConnectionError extends Error {
  constructor(message = "Cannot connect to Roblox bridge. Is the server running?") {
    super(message);
    this.name = "BridgeConnectionError";
  }
}
