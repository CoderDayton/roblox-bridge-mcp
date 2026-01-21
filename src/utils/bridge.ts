import { EventEmitter } from "events";
import { RobloxTimeoutError, RobloxExecutionError, BridgeConnectionError } from "./errors";
import { config } from "../config";
import { logger } from "./logger";
import type { ServerWebSocket } from "bun";

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

/** Metrics for a single command execution */
interface CommandMetric {
  method: string;
  timestamp: number;
  duration: number;
  success: boolean;
  error?: string;
}

/** Aggregated metrics for the bridge */
export interface BridgeMetrics {
  totalCommands: number;
  successCount: number;
  failureCount: number;
  successRate: number;
  averageDuration: number;
  recentCommands: CommandMetric[];
  methodStats: Record<string, { count: number; avgDuration: number; failures: number }>;
}

/** WebSocket client data */
interface WSClientData {
  id: string;
  connectedAt: number;
}

/** Pending long-poll request */
interface PendingPoll {
  resolve: (commands: RobloxCommand[]) => void;
  timeout: ReturnType<typeof setTimeout>;
}

class RobloxBridge extends EventEmitter {
  private commandQueue: RobloxCommand[] = [];
  private pendingResponses = new Map<string, (result: RobloxResult) => void>();
  private lastPollTime = 0;

  // Metrics tracking
  private commandHistory: CommandMetric[] = [];
  private readonly maxHistorySize = 100;
  private commandStartTimes = new Map<string, number>();

  // WebSocket clients
  private wsClients = new Set<ServerWebSocket<WSClientData>>();

  // Long-polling support
  private pendingPolls: PendingPoll[] = [];
  private readonly longPollTimeout = 25_000; // 25 seconds (less than typical 30s HTTP timeout)

  /** Check if bridge appears to be connected (plugin is polling or WebSocket connected) */
  isConnected(): boolean {
    const httpConnected = Date.now() - this.lastPollTime < 10_000;
    const wsConnected = this.wsClients.size > 0;
    return httpConnected || wsConnected;
  }

  /** Get connection info */
  getConnectionInfo(): { httpConnected: boolean; wsClients: number; lastPollTime: number } {
    return {
      httpConnected: Date.now() - this.lastPollTime < 10_000,
      wsClients: this.wsClients.size,
      lastPollTime: this.lastPollTime,
    };
  }

  /** Get metrics about command execution */
  getMetrics(): BridgeMetrics {
    const total = this.commandHistory.length;
    const successes = this.commandHistory.filter((c) => c.success).length;
    const failures = total - successes;
    const avgDuration =
      total > 0 ? this.commandHistory.reduce((sum, c) => sum + c.duration, 0) / total : 0;

    // Calculate per-method stats
    const methodStats: Record<string, { count: number; avgDuration: number; failures: number }> =
      {};
    for (const cmd of this.commandHistory) {
      if (!methodStats[cmd.method]) {
        methodStats[cmd.method] = { count: 0, avgDuration: 0, failures: 0 };
      }
      const stats = methodStats[cmd.method];
      stats.avgDuration = (stats.avgDuration * stats.count + cmd.duration) / (stats.count + 1);
      stats.count++;
      if (!cmd.success) stats.failures++;
    }

    return {
      totalCommands: total,
      successCount: successes,
      failureCount: failures,
      successRate: total > 0 ? successes / total : 0,
      averageDuration: Math.round(avgDuration),
      recentCommands: this.commandHistory.slice(-10),
      methodStats,
    };
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
    this.commandStartTimes.set(id, Date.now());

    // Notify waiting long-polls and WebSocket clients
    this.notifyNewCommand();

    return new Promise<T>((resolve, reject) => {
      const timeout = setTimeout(() => {
        this.pendingResponses.delete(id);
        this.recordMetric(id, method, false, "Timeout");
        const errorMsg = this.isConnected()
          ? `Command '${method}' timed out after ${config.timeout}ms (attempt ${attempt})`
          : `Command '${method}' timed out. Roblox Studio plugin is not connected. Please ensure the plugin is installed and Studio is running.`;
        reject(new RobloxTimeoutError(errorMsg, method, attempt));
      }, config.timeout);

      this.pendingResponses.set(id, (result) => {
        clearTimeout(timeout);
        this.recordMetric(id, method, result.success, result.error);
        if (result.success) {
          resolve(result.data as T);
        } else {
          const errorMsg = `Roblox error in '${method}': ${result.error ?? "Unknown error"}`;
          reject(new RobloxExecutionError(errorMsg, method, params));
        }
      });
    });
  }

  /** Notify all waiting clients about new commands */
  private notifyNewCommand(): void {
    // Resolve all pending long-polls immediately
    if (this.pendingPolls.length > 0) {
      const commands = this.drainCommandQueue();
      for (const poll of this.pendingPolls) {
        clearTimeout(poll.timeout);
        poll.resolve(commands);
      }
      this.pendingPolls = [];
      return; // Commands already drained
    }

    // Notify WebSocket clients
    if (this.wsClients.size > 0 && this.commandQueue.length > 0) {
      const commands = this.drainCommandQueue();
      const message = JSON.stringify({ type: "commands", data: commands });
      for (const client of this.wsClients) {
        client.send(message);
      }
    }
  }

  /** Drain and return all commands from queue */
  private drainCommandQueue(): RobloxCommand[] {
    const commands = [...this.commandQueue];
    this.commandQueue = [];
    return commands;
  }

  /** Record a command metric */
  private recordMetric(id: string, method: string, success: boolean, error?: string): void {
    const startTime = this.commandStartTimes.get(id);
    const duration = startTime ? Date.now() - startTime : 0;
    this.commandStartTimes.delete(id);

    this.commandHistory.push({
      method,
      timestamp: Date.now(),
      duration,
      success,
      error,
    });

    // Trim history to max size
    if (this.commandHistory.length > this.maxHistorySize) {
      this.commandHistory.shift();
    }
  }

  /** Get pending commands immediately (legacy polling) */
  getPendingCommands(): RobloxCommand[] {
    this.lastPollTime = Date.now();
    return this.drainCommandQueue();
  }

  /** Long-poll for commands (blocks until commands arrive or timeout) */
  async longPoll(): Promise<RobloxCommand[]> {
    this.lastPollTime = Date.now();

    // If commands already queued, return immediately
    if (this.commandQueue.length > 0) {
      return this.drainCommandQueue();
    }

    // Wait for new commands or timeout
    return new Promise<RobloxCommand[]>((resolve) => {
      const timeout = setTimeout(() => {
        // Remove this poll from pending list
        const idx = this.pendingPolls.findIndex((p) => p.resolve === resolve);
        if (idx !== -1) {
          this.pendingPolls.splice(idx, 1);
        }
        // Return empty array on timeout (client will re-poll)
        resolve([]);
      }, this.longPollTimeout);

      this.pendingPolls.push({ resolve, timeout });
    });
  }

  /** Handle result from Roblox plugin */
  handleResult(result: RobloxResult): void {
    const resolver = this.pendingResponses.get(result.id);
    if (resolver) {
      resolver(result);
      this.pendingResponses.delete(result.id);
    }
  }

  /** Register a WebSocket client */
  addWebSocketClient(ws: ServerWebSocket<WSClientData>): void {
    this.wsClients.add(ws);
    logger.bridge.info("WebSocket client connected", { clientId: ws.data.id });
  }

  /** Remove a WebSocket client */
  removeWebSocketClient(ws: ServerWebSocket<WSClientData>): void {
    this.wsClients.delete(ws);
    logger.bridge.info("WebSocket client disconnected", { clientId: ws.data.id });
  }

  /** Get the number of pending commands */
  get pendingCount(): number {
    return this.pendingResponses.size;
  }
}

export const bridge = new RobloxBridge();

/** Track the actual port the bridge server is running on */
let activeBridgePort: number | null = null;

/** Get the active bridge port (null if server failed to start) */
export function getActiveBridgePort(): number | null {
  return activeBridgePort;
}

/**
 * Try to start server on a specific port with WebSocket support
 * @returns Server instance if successful, null if port is in use
 */
function tryStartServer(port: number): ReturnType<typeof Bun.serve> | null {
  try {
    const server = Bun.serve<WSClientData>({
      port,
      fetch(req, server) {
        const url = new URL(req.url);

        // Health check endpoint - no auth required for discovery
        if (req.method === "GET" && url.pathname === "/health") {
          const connInfo = bridge.getConnectionInfo();
          return Response.json({
            status: "ok",
            service: "roblox-bridge-mcp",
            port,
            connected: bridge.isConnected(),
            connections: {
              http: connInfo.httpConnected,
              websocket: connInfo.wsClients,
            },
            uptime: process.uptime(),
          });
        }

        // All other endpoints require API key authentication
        const authHeader = req.headers.get("Authorization");
        const apiKeyParam = url.searchParams.get("key");
        const providedKey = authHeader?.replace("Bearer ", "") || apiKeyParam;

        if (providedKey !== config.apiKey) {
          return Response.json(
            { error: "Unauthorized", message: "Invalid or missing API key" },
            { status: 401 }
          );
        }

        // WebSocket upgrade (auth via query param since headers not supported in WS)
        if (url.pathname === "/ws") {
          const clientId = crypto.randomUUID().slice(0, 8);
          const upgraded = server.upgrade(req, {
            data: { id: clientId, connectedAt: Date.now() },
          });
          if (upgraded) {
            return undefined; // Upgrade successful
          }
          return new Response("WebSocket upgrade failed", { status: 400 });
        }

        // Long-poll for commands (blocks until commands arrive)
        if (req.method === "GET" && url.pathname === "/poll") {
          const useLongPoll = url.searchParams.get("long") === "1";

          if (useLongPoll) {
            return bridge.longPoll().then((commands) => Response.json(commands));
          }

          // Legacy immediate poll
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
      websocket: {
        open(ws) {
          bridge.addWebSocketClient(ws);
          ws.send(JSON.stringify({ type: "connected", clientId: ws.data.id }));
        },
        message(ws, message) {
          try {
            const data = JSON.parse(message.toString());

            // Handle results sent via WebSocket
            if (data.type === "result" && data.data) {
              bridge.handleResult(data.data as RobloxResult);
              ws.send(JSON.stringify({ type: "ack", id: data.data.id }));
            }
          } catch (error) {
            ws.send(JSON.stringify({ type: "error", message: "Invalid JSON" }));
          }
        },
        close(ws) {
          bridge.removeWebSocketClient(ws);
        },
      },
    });
    return server;
  } catch (error) {
    if (error instanceof Error && "code" in error && error.code === "EADDRINUSE") {
      return null; // Port in use, caller will try next
    }
    // Re-throw non-port-conflict errors
    throw error;
  }
}

/** Start the HTTP bridge server for Roblox plugin communication with automatic port fallback */
export function startBridgeServer(): void {
  const preferredPort = config.bridgePort;
  const maxPort = preferredPort + 9; // Try up to 10 ports (e.g., 8081-8090)

  try {
    // Try preferred port first, then fallback ports
    for (let port = preferredPort; port <= maxPort; port++) {
      const server = tryStartServer(port);
      if (server) {
        activeBridgePort = port;
        const portInfo =
          port === preferredPort
            ? `port ${port}`
            : `port ${port} (preferred ${preferredPort} was in use)`;

        // Write port to file for fast plugin discovery
        const portFile =
          process.platform === "win32"
            ? `${process.env.LOCALAPPDATA}\\Temp\\roblox-mcp-port.txt`
            : `/tmp/roblox-mcp-port.txt`;

        try {
          require("fs").writeFileSync(portFile, String(port), "utf8");
          logger.bridge.debug("Wrote port file", { path: portFile, port });
        } catch (err) {
          logger.bridge.warn("Failed to write port file", { error: String(err) });
        }

        console.error(`[Bridge] Roblox bridge server running on ${portInfo}`);
        console.error(`[Bridge] API Key: ${config.apiKey}`);
        console.error(`[Bridge] Set this key in your Roblox plugin to connect`);
        logger.bridge.info("Roblox bridge server started", {
          port,
          preferredPort,
          wasFallback: port !== preferredPort,
        });
        return; // Success
      }
    }

    // All ports exhausted
    throw new Error(
      `All ports ${preferredPort}-${maxPort} are in use. Could not start bridge server.`
    );
  } catch (error) {
    activeBridgePort = null;
    const errorMsg =
      error instanceof Error ? error.message : `Failed to start bridge server: ${String(error)}`;

    console.error(`[Bridge] WARNING: ${errorMsg}`);
    logger.bridge.error(
      "Bridge server startup failed - MCP server will still start",
      error instanceof Error ? error : undefined,
      {
        preferredPort,
        recoverable: true,
      }
    );
  }
}
