import { EventEmitter } from "events";
import { z } from "zod";
import { RobloxTimeoutError, RobloxExecutionError } from "./errors";
import { config } from "../config";
import { logger } from "./logger";
import type { ServerWebSocket } from "bun";

/**
 * Command sent from MCP server to Roblox Studio plugin
 */
export interface RobloxCommand {
  id: string;
  method: string;
  params: Record<string, unknown>;
}

/**
 * Result returned from Roblox Studio plugin to MCP server
 */
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

/**
 * Aggregated metrics for the bridge
 * Includes success rates, average duration, and per-method statistics
 */
export interface BridgeMetrics {
  totalCommands: number;
  successCount: number;
  failureCount: number;
  successRate: number;
  averageDuration: number;
  recentCommands: CommandMetric[];
  methodStats: Record<string, { count: number; avgDuration: number; failures: number }>;
}

/** Validation schemas for bridge methods */
const executeSchema = z.object({
  method: z.string().min(1, "Method name cannot be empty"),
  params: z.record(z.unknown()),
  retries: z.number().int().min(0).max(10).optional(),
});

const resultSchema = z.object({
  id: z.string().min(1, "Result ID cannot be empty"),
  success: z.boolean(),
  data: z.unknown(),
  error: z.string().optional(),
});

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

  /**
   * Check if the bridge appears to be connected to the Roblox Studio plugin
   * @returns True if HTTP polling is active or WebSocket clients are connected
   */
  isConnected(): boolean {
    return this.isHttpConnected() || this.wsClients.size > 0;
  }

  /**
   * Check if HTTP polling connection is active (polled within last 10 seconds)
   * @private
   */
  private isHttpConnected(): boolean {
    return Date.now() - this.lastPollTime < 10_000;
  }

  /**
   * Get detailed connection information
   * @returns Object with HTTP and WebSocket connection states
   */
  getConnectionInfo(): { httpConnected: boolean; wsClients: number; lastPollTime: number } {
    return {
      httpConnected: this.isHttpConnected(),
      wsClients: this.wsClients.size,
      lastPollTime: this.lastPollTime,
    };
  }

  /**
   * Get aggregated metrics about command execution
   * Includes success rates, average duration, recent commands, and per-method statistics
   * @returns BridgeMetrics object with comprehensive statistics
   */
  getMetrics(): BridgeMetrics {
    const total = this.commandHistory.length;
    const successes = this.commandHistory.filter((c) => c.success).length;
    const avgDuration =
      total > 0 ? this.commandHistory.reduce((sum, c) => sum + c.duration, 0) / total : 0;

    return {
      totalCommands: total,
      successCount: successes,
      failureCount: total - successes,
      successRate: total > 0 ? successes / total : 0,
      averageDuration: Math.round(avgDuration),
      recentCommands: this.commandHistory.slice(-10),
      methodStats: this.calculateMethodStats(),
    };
  }

  /**
   * Calculate per-method statistics from command history
   * @private
   * @returns Record mapping method names to their statistics
   */
  private calculateMethodStats(): Record<
    string,
    { count: number; avgDuration: number; failures: number }
  > {
    const methodStats: Record<string, { count: number; avgDuration: number; failures: number }> =
      {};
    for (const cmd of this.commandHistory) {
      if (!methodStats[cmd.method]) {
        methodStats[cmd.method] = { count: 0, avgDuration: 0, failures: 0 };
      }
      const stats = methodStats[cmd.method];
      if (stats) {
        stats.avgDuration = (stats.avgDuration * stats.count + cmd.duration) / (stats.count + 1);
        stats.count++;
        if (!cmd.success) stats.failures++;
      }
    }
    return methodStats;
  }

  /**
   * Execute a Roblox command with automatic retry logic
   * @param method - Roblox API method name (e.g., 'CreateInstance', 'SetProperty')
   * @param params - Method parameters as key-value pairs
   * @param retries - Number of retry attempts on timeout (default: 1)
   * @returns Promise resolving to the command result
   * @throws {RobloxTimeoutError} If command times out after all retries
   * @throws {RobloxExecutionError} If Roblox returns an error
   * @throws {z.ZodError} If parameters fail validation
   */
  async execute<T = unknown>(
    method: string,
    params: Record<string, unknown>,
    retries = 1
  ): Promise<T> {
    // Validate input parameters
    const validated = executeSchema.parse({ method, params, retries });
    method = validated.method;
    params = validated.params;
    retries = validated.retries ?? 1;
    for (let attempt = 0; attempt <= retries; attempt++) {
      try {
        return await this.executeOnce<T>(method, params, attempt + 1);
      } catch (error) {
        const isTimeout = error instanceof RobloxTimeoutError;
        const shouldRetry = isTimeout && attempt < retries;

        if (shouldRetry) {
          logger.bridge.warn(`Timeout on attempt ${attempt + 1}/${retries + 1}, retrying...`, {
            method,
            attempt: attempt + 1,
            maxRetries: retries + 1,
          });
          await new Promise((resolve) => setTimeout(resolve, 1000));
          continue;
        }

        if (error instanceof Error) {
          logger.bridge.error("Command failed", error, { method, attempt: attempt + 1 });
        }
        throw error;
      }
    }

    throw new RobloxTimeoutError(`Failed after ${retries + 1} attempts`, method, retries + 1);
  }

  /**
   * Execute a command once without retry logic (internal helper)
   * @private
   * @param method - Roblox API method name
   * @param params - Method parameters
   * @param attempt - Current attempt number (for logging)
   * @returns Promise resolving to the command result
   */
  private async executeOnce<T = unknown>(
    method: string,
    params: Record<string, unknown>,
    attempt: number
  ): Promise<T> {
    const id = crypto.randomUUID().slice(0, 8);
    const command: RobloxCommand = { id, method, params };

    this.commandQueue.push(command);
    this.commandStartTimes.set(id, Date.now());
    this.notifyNewCommand();

    return new Promise<T>((resolve, reject) => {
      const timeout = setTimeout(() => {
        this.handleTimeout(id, method, attempt, reject);
      }, config.timeout);

      this.pendingResponses.set(id, (result) => {
        this.handleResponse(id, method, params, timeout, result, resolve, reject);
      });
    });
  }

  /**
   * Handle command timeout by cleaning up and rejecting the promise
   * @private
   */
  private handleTimeout(
    id: string,
    method: string,
    attempt: number,
    reject: (error: Error) => void
  ): void {
    this.pendingResponses.delete(id);
    this.recordMetric(id, method, false, "Timeout");
    const errorMsg = this.isConnected()
      ? `Command '${method}' timed out after ${config.timeout}ms (attempt ${attempt})`
      : `Command '${method}' timed out. Roblox Studio plugin is not connected. Please ensure the plugin is installed and Studio is running.`;
    reject(new RobloxTimeoutError(errorMsg, method, attempt));
  }

  /**
   * Handle command response from Roblox plugin
   * @private
   */
  private handleResponse<T>(
    id: string,
    method: string,
    params: Record<string, unknown>,
    timeout: ReturnType<typeof setTimeout>,
    result: RobloxResult,
    resolve: (value: T) => void,
    reject: (error: Error) => void
  ): void {
    clearTimeout(timeout);
    this.recordMetric(id, method, result.success, result.error);
    if (result.success) {
      resolve(result.data as T);
    } else {
      const errorMsg = `Roblox error in '${method}': ${result.error ?? "Unknown error"}`;
      reject(new RobloxExecutionError(errorMsg, method, params));
    }
  }

  /**
   * Notify all waiting clients (long-polls and WebSockets) about new commands
   * @private
   */
  private notifyNewCommand(): void {
    if (this.pendingPolls.length > 0) {
      this.notifyLongPolls();
      return;
    }

    if (this.wsClients.size > 0 && this.commandQueue.length > 0) {
      this.notifyWebSocketClients();
    }
  }

  /**
   * Notify all pending long-poll requests with queued commands
   * @private
   */
  private notifyLongPolls(): void {
    const commands = this.drainCommandQueue();
    for (const poll of this.pendingPolls) {
      clearTimeout(poll.timeout);
      poll.resolve(commands);
    }
    this.pendingPolls = [];
  }

  /**
   * Notify all WebSocket clients with queued commands
   * @private
   */
  private notifyWebSocketClients(): void {
    const commands = this.drainCommandQueue();
    const message = JSON.stringify({ type: "commands", data: commands });
    for (const client of this.wsClients) {
      client.send(message);
    }
  }

  /**
   * Drain and return all commands from the queue
   * @private
   * @returns Array of pending commands (queue is cleared)
   */
  private drainCommandQueue(): RobloxCommand[] {
    const commands = [...this.commandQueue];
    this.commandQueue = [];
    return commands;
  }

  /**
   * Record metrics for a completed command execution
   * @private
   * @param id - Command ID
   * @param method - Roblox API method name
   * @param success - Whether the command succeeded
   * @param error - Optional error message
   */
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

    if (this.commandHistory.length > this.maxHistorySize) {
      this.commandHistory.shift();
    }
  }

  /**
   * Get pending commands immediately without blocking (legacy polling)
   * @returns Array of pending commands (queue is drained)
   * @deprecated Use longPoll() for better efficiency
   */
  getPendingCommands(): RobloxCommand[] {
    this.lastPollTime = Date.now();
    return this.drainCommandQueue();
  }

  /**
   * Long-poll for commands (blocks until commands arrive or timeout)
   * More efficient than getPendingCommands() as it eliminates unnecessary polling
   * @returns Promise resolving to array of commands (empty if timeout)
   */
  async longPoll(): Promise<RobloxCommand[]> {
    this.lastPollTime = Date.now();

    if (this.commandQueue.length > 0) {
      return this.drainCommandQueue();
    }

    return new Promise<RobloxCommand[]>((resolve) => {
      const timeout = setTimeout(() => {
        this.removePendingPoll(resolve);
        resolve([]);
      }, this.longPollTimeout);

      this.pendingPolls.push({ resolve, timeout });
    });
  }

  /**
   * Remove a specific long-poll request from pending list
   * @private
   */
  private removePendingPoll(resolve: (commands: RobloxCommand[]) => void): void {
    const idx = this.pendingPolls.findIndex((p) => p.resolve === resolve);
    if (idx !== -1) {
      this.pendingPolls.splice(idx, 1);
    }
  }

  /**
   * Handle result received from Roblox plugin
   * Resolves the corresponding pending promise
   * @param result - Command execution result from plugin
   * @throws {z.ZodError} If result fails validation
   */
  handleResult(result: RobloxResult): void {
    // Validate result structure
    resultSchema.parse(result);
    const resolver = this.pendingResponses.get(result.id);
    if (resolver) {
      resolver(result);
      this.pendingResponses.delete(result.id);
    }
  }

  /**
   * Register a new WebSocket client connection
   * @param ws - WebSocket connection to register
   * @throws {Error} If ws is null or undefined
   */
  addWebSocketClient(ws: ServerWebSocket<WSClientData> | null | undefined): void {
    if (!ws) {
      throw new Error("WebSocket client cannot be null or undefined");
    }
    this.wsClients.add(ws);
    logger.bridge.info("WebSocket client connected", { clientId: ws.data.id });
  }

  /**
   * Unregister a WebSocket client connection
   * @param ws - WebSocket connection to remove
   * @throws {Error} If ws is null or undefined
   */
  removeWebSocketClient(ws: ServerWebSocket<WSClientData> | null | undefined): void {
    if (!ws) {
      throw new Error("WebSocket client cannot be null or undefined");
    }
    this.wsClients.delete(ws);
    logger.bridge.info("WebSocket client disconnected", { clientId: ws.data.id });
  }

  /**
   * Get the number of commands awaiting responses from Roblox
   * @returns Count of pending responses
   */
  get pendingCount(): number {
    return this.pendingResponses.size;
  }

  /**
   * Reset bridge state for testing (clears all queues and connections)
   * @private
   */
  resetForTesting(): void {
    this.commandQueue = [];
    this.pendingResponses.clear();
    this.wsClients.clear();
    this.pendingPolls = [];
    this.commandHistory = [];
    this.commandStartTimes.clear();
  }
}

/**
 * Singleton bridge instance for communication with Roblox Studio plugin
 */
export const bridge = new RobloxBridge();

/** Track the actual port the bridge server is running on */
let activeBridgePort: number | null = null;

/**
 * Get the active bridge server port
 * @returns Port number if server is running, null if startup failed
 */
export function getActiveBridgePort(): number | null {
  return activeBridgePort;
}

/**
 * Generate health status response for /health endpoint
 * @param port - Bridge server port
 * @returns Health status object
 */
function getHealthStatus(port: number): {
  status: string;
  service: string;
  port: number;
  connected: boolean;
  connections: { http: boolean; websocket: number };
  uptime: number;
} {
  const connInfo = bridge.getConnectionInfo();
  return {
    status: "ok",
    service: "roblox-bridge-mcp",
    port,
    connected: bridge.isConnected(),
    connections: {
      http: connInfo.httpConnected,
      websocket: connInfo.wsClients,
    },
    uptime: process.uptime(),
  };
}

/**
 * Extract API key from request headers or query parameters
 * @param req - HTTP request
 * @param url - Parsed URL
 * @returns API key if present, null otherwise
 */
function getApiKey(req: Request, url: URL): string | null {
  const authHeader = req.headers.get("Authorization");
  const apiKeyParam = url.searchParams.get("key");
  return authHeader?.replace("Bearer ", "") ?? apiKeyParam;
}

/**
 * Handle WebSocket upgrade request
 * @param req - HTTP upgrade request
 * @param server - ReturnType<typeof Bun.serve> - Bun server instance with upgrade capability
 * @returns Undefined if upgrade successful, error response otherwise
 */
function handleWebSocketUpgrade(
  req: Request,
  server: ReturnType<typeof Bun.serve<WSClientData>>
): Response | undefined {
  const clientId = crypto.randomUUID().slice(0, 8);
  const upgraded = server.upgrade(req, {
    data: { id: clientId, connectedAt: Date.now() },
  });
  return upgraded ? undefined : new Response("WebSocket upgrade failed", { status: 400 });
}

/**
 * Handle command polling request (both long-poll and immediate)
 * @param url - Request URL with query parameters
 * @returns Response promise with pending commands
 */
function handlePollRequest(url: URL): Promise<Response> | Response {
  const useLongPoll = url.searchParams.get("long") === "1";

  if (useLongPoll) {
    return bridge.longPoll().then((commands) => Response.json(commands));
  }

  const commands = bridge.getPendingCommands();
  return Response.json(commands);
}

/**
 * Handle command result submission from plugin
 * @param req - HTTP request with result in body
 * @returns Success response promise
 */
function handleResultPost(req: Request): Promise<Response> {
  return req.json().then((result: RobloxResult) => {
    bridge.handleResult(result);
    return Response.json({ status: "ok" });
  });
}

/**
 * Handle incoming WebSocket message from plugin
 * @param ws - WebSocket connection
 * @param message - Message data (JSON string or buffer)
 */
function handleWebSocketMessage(ws: ServerWebSocket<WSClientData>, message: string | Buffer): void {
  try {
    const data = JSON.parse(message.toString());

    if (data.type === "result" && data.data) {
      bridge.handleResult(data.data as RobloxResult);
      ws.send(JSON.stringify({ type: "ack", id: data.data.id }));
    }
  } catch {
    ws.send(JSON.stringify({ type: "error", message: "Invalid JSON" }));
  }
}

/**
 * Route incoming HTTP requests to appropriate handlers
 * @param req - HTTP request
 * @param server - Bun server instance
 * @param port - Bridge server port
 * @returns HTTP response or undefined for WebSocket upgrades
 */
function handleRequest(
  req: Request,
  server: ReturnType<typeof Bun.serve<WSClientData>>,
  port: number
): Response | Promise<Response> | undefined {
  const url = new URL(req.url);

  if (req.method === "GET" && url.pathname === "/health") {
    return Response.json(getHealthStatus(port));
  }

  const providedKey = getApiKey(req, url);
  if (providedKey !== config.apiKey) {
    return Response.json(
      { error: "Unauthorized", message: "Invalid or missing API key" },
      { status: 401 }
    );
  }

  if (url.pathname === "/ws") {
    return handleWebSocketUpgrade(req, server);
  }

  if (req.method === "GET" && url.pathname === "/poll") {
    return handlePollRequest(url);
  }

  if (req.method === "POST" && url.pathname === "/result") {
    return handleResultPost(req);
  }

  return new Response("Not Found", { status: 404 });
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
        return handleRequest(req, server, port);
      },
      websocket: {
        open(ws) {
          bridge.addWebSocketClient(ws);
          ws.send(JSON.stringify({ type: "connected", clientId: ws.data.id }));
        },
        message(ws, message) {
          handleWebSocketMessage(ws, message);
        },
        close(ws) {
          bridge.removeWebSocketClient(ws);
        },
      },
    });
    return server;
  } catch (error) {
    if (error instanceof Error && "code" in error && error.code === "EADDRINUSE") {
      return null;
    }
    throw error;
  }
}

/**
 * Start the HTTP/WebSocket bridge server for Roblox plugin communication
 * Attempts to bind to configured port with graceful error handling
 * Server startup failure is non-fatal - MCP server continues without bridge
 */
export function startBridgeServer(): void {
  const port = config.bridgePort;

  try {
    const server = tryStartServer(port);
    if (!server) {
      // Port in use - log warning but don't throw (allows MCP to continue)
      console.error(`[Bridge] WARNING: Port ${port} is in use. Please set ROBLOX_BRIDGE_PORT to a different port.`);
      console.error(`[Bridge] MCP server will start without Roblox bridge functionality.`);
      logger.bridge.warn("Bridge server port in use - continuing without bridge", { port });
      return;
    }

    activeBridgePort = port;
    console.error(`[Bridge] Roblox bridge server running on port ${port}`);
    console.error(`[Bridge] API Key: ${config.apiKey}`);
    console.error(`[Bridge] Set this key in your Roblox plugin to connect`);
    logger.bridge.info("Roblox bridge server started", { port });
  } catch (error) {
    activeBridgePort = null;
    const errorMsg =
      error instanceof Error ? error.message : `Failed to start bridge server: ${String(error)}`;

    console.error(`[Bridge] ERROR: ${errorMsg}`);
    console.error(`[Bridge] MCP server will start without Roblox bridge functionality.`);
    logger.bridge.error(
      "Bridge server startup failed - MCP server will still start",
      error instanceof Error ? error : undefined,
      { port, recoverable: true }
    );
  }
}
