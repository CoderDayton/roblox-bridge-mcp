import { EventEmitter } from "events";
import { RobloxTimeoutError, RobloxExecutionError, BridgeConnectionError } from "./errors";
import { config } from "../config";
import { logger } from "./logger";

export interface RobloxCommand {
  id: string;
  method: string;
  params: Record<string, unknown>;
}

export interface RobloxResult {
  id: string;
  success: boolean;
  data: unknown;
  error?: string;
}

class RobloxBridge extends EventEmitter {
  private commandQueue: RobloxCommand[] = [];
  private pendingResponses = new Map<string, (result: RobloxResult) => void>();
  private lastPollTime = 0;

  /** Check if bridge appears to be connected (plugin is polling) */
  isConnected(): boolean {
    return Date.now() - this.lastPollTime < 10_000; // 10 second window
  }

  /** Execute a command and wait for Roblox response with retry logic */
  async execute<T = unknown>(
    method: string,
    params: Record<string, unknown>,
    retries = 1
  ): Promise<T> {
    for (let attempt = 0; attempt <= retries; attempt++) {
      try {
        return await this.executeOnce<T>(method, params, attempt + 1);
      } catch (error) {
        const isLastAttempt = attempt === retries;
        const isTimeout = error instanceof RobloxTimeoutError;

        // Only retry on timeout errors
        if (isTimeout && !isLastAttempt) {
          logger.bridge.warn(`Timeout on attempt ${attempt + 1}/${retries + 1}, retrying...`, {
            method,
            attempt: attempt + 1,
            maxRetries: retries + 1,
          });
          await new Promise((resolve) => setTimeout(resolve, 1000)); // 1s delay between retries
          continue;
        }

        // Re-throw with context
        if (error instanceof Error) {
          logger.bridge.error("Command failed", error, { method, attempt: attempt + 1 });
        }
        throw error;
      }
    }

    // TypeScript doesn't know the loop always returns or throws
    throw new RobloxTimeoutError(`Failed after ${retries + 1} attempts`, method, retries + 1);
  }

  /** Execute a command once (internal) */
  private async executeOnce<T = unknown>(
    method: string,
    params: Record<string, unknown>,
    attempt: number
  ): Promise<T> {
    const id = crypto.randomUUID().slice(0, 8);
    const command: RobloxCommand = { id, method, params };

    this.commandQueue.push(command);
    this.emit("new_command");

    return new Promise<T>((resolve, reject) => {
      const timeout = setTimeout(() => {
        this.pendingResponses.delete(id);
        const errorMsg = this.isConnected()
          ? `Command '${method}' timed out after ${config.timeout}ms (attempt ${attempt})`
          : `Command '${method}' timed out. Roblox Studio plugin is not connected. Please ensure the plugin is installed and Studio is running.`;
        reject(new RobloxTimeoutError(errorMsg, method, attempt));
      }, config.timeout);

      this.pendingResponses.set(id, (result) => {
        clearTimeout(timeout);
        if (result.success) {
          resolve(result.data as T);
        } else {
          const errorMsg = `Roblox error in '${method}': ${result.error ?? "Unknown error"}`;
          reject(new RobloxExecutionError(errorMsg, method, params));
        }
      });
    });
  }

  /** Get pending commands (called by Roblox plugin via HTTP) */
  getPendingCommands(): RobloxCommand[] {
    this.lastPollTime = Date.now(); // Track connection
    const commands = [...this.commandQueue];
    this.commandQueue = [];
    return commands;
  }

  /** Handle result from Roblox plugin */
  handleResult(result: RobloxResult): void {
    const resolver = this.pendingResponses.get(result.id);
    if (resolver) {
      resolver(result);
      this.pendingResponses.delete(result.id);
    }
  }

  /** Get the number of pending commands */
  get pendingCount(): number {
    return this.pendingResponses.size;
  }
}

export const bridge = new RobloxBridge();

/** Start the HTTP bridge server for Roblox plugin communication */
export function startBridgeServer(): void {
  Bun.serve({
    port: config.bridgePort,
    fetch(req) {
      const url = new URL(req.url);

      // Roblox polls for commands
      if (req.method === "GET" && url.pathname === "/poll") {
        const commands = bridge.getPendingCommands();
        return Response.json(commands);
      }

      // Roblox posts results
      if (req.method === "POST" && url.pathname === "/result") {
        return req.json().then((result: RobloxResult) => {
          bridge.handleResult(result);
          return Response.json({ status: "ok" });
        });
      }

      return new Response("Not Found", { status: 404 });
    },
  });

  console.error(`[Bridge] Roblox bridge server running on port ${config.bridgePort}`);
  logger.bridge.info("Roblox bridge server started", { port: config.bridgePort });
}
