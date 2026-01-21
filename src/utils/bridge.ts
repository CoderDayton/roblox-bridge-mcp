import { EventEmitter } from "events";
import { RobloxTimeoutError, RobloxExecutionError } from "./errors";

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

const TIMEOUT_MS = 30_000;
const BRIDGE_PORT = 8081;

class RobloxBridge extends EventEmitter {
  private commandQueue: RobloxCommand[] = [];
  private pendingResponses = new Map<string, (result: RobloxResult) => void>();

  /** Execute a command and wait for Roblox response */
  async execute<T = unknown>(method: string, params: Record<string, unknown>): Promise<T> {
    const id = crypto.randomUUID().slice(0, 8);
    const command: RobloxCommand = { id, method, params };

    this.commandQueue.push(command);
    this.emit("new_command");

    return new Promise<T>((resolve, reject) => {
      const timeout = setTimeout(() => {
        this.pendingResponses.delete(id);
        reject(new RobloxTimeoutError());
      }, TIMEOUT_MS);

      this.pendingResponses.set(id, (result) => {
        clearTimeout(timeout);
        if (result.success) {
          resolve(result.data as T);
        } else {
          reject(new RobloxExecutionError(result.error ?? "Unknown Roblox error"));
        }
      });
    });
  }

  /** Get pending commands (called by Roblox plugin via HTTP) */
  getPendingCommands(): RobloxCommand[] {
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
    port: BRIDGE_PORT,
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

  console.error(`[Bridge] Roblox bridge server running on port ${BRIDGE_PORT}`);
}
