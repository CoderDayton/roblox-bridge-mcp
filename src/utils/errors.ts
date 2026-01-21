/**
 * Custom errors for Roblox Studio MCP operations
 */

/** Error thrown when Roblox Studio is not responding or plugin is not running */
export class RobloxTimeoutError extends Error {
  constructor(message = "Roblox Studio execution timed out. Is the plugin running?") {
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
  constructor(message: string) {
    super(message);
    this.name = "InvalidParameterError";
  }
}

/** Error thrown when Roblox reports an execution error */
export class RobloxExecutionError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "RobloxExecutionError";
  }
}
