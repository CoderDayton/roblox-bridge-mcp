import { EventEmitter } from "events";
import { z } from "zod";
import { RobloxTimeoutError, RobloxExecutionError } from "./errors";
import { config, isVersionCompatible } from "../config";
import { logger } from "./logger";
import type { ServerWebSocket } from "bun";

/** Message type constants */
const MessageTypes = {
  HANDSHAKE: "handshake",
  HANDSHAKE_OK: "handshake_ok",
  RESULT: "result",
  COMMANDS: "commands",
  ACK: "ack",
  PING: "ping",
  PONG: "pong",
  ERROR: "error",
  CONNECTED: "connected",
} as const;

/** Type guards for message handling */
interface HandshakeMessage {
  type: typeof MessageTypes.HANDSHAKE;
  version: string;
}

interface ResultMessage {
  type: typeof MessageTypes.RESULT;
  data: RobloxResult;
}

interface PingMessage {
  type: typeof MessageTypes.PING;
}

function isHandshakeMessage(data: unknown): data is HandshakeMessage {
  return (
    typeof data === "object" &&
    data !== null &&
    "type" in data &&
    data.type === MessageTypes.HANDSHAKE &&
    "version" in data &&
    typeof data.version === "string"
  );
}

function isResultMessage(data: unknown): data is ResultMessage {
  return (
    typeof data === "object" &&
    data !== null &&
    "type" in data &&
    data.type === MessageTypes.RESULT &&
    "data" in data &&
    data.data !== null &&
    data.data !== undefined
  );
}

function isPingMessage(data: unknown): data is PingMessage {
  return (
    typeof data === "object" && data !== null && "type" in data && data.type === MessageTypes.PING
  );
}

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

/** Validation schemas */
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
  version?: string;
  ready: boolean;
}

/**
 * WebSocket-only bridge for Roblox Studio communication
 */
class RobloxBridge extends EventEmitter {
  private commandQueue: RobloxCommand[] = [];
  private pendingResponses = new Map<string, (result: RobloxResult) => void>();

  // Metrics
  private commandHistory: CommandMetric[] = [];
  private readonly maxHistorySize = 100;
  private commandStartTimes = new Map<string, number>();

  // WebSocket clients
  private wsClients = new Set<ServerWebSocket<WSClientData>>();

  /**
   * Check if any WebSocket clients are connected and ready
   */
  isConnected(): boolean {
    for (const client of this.wsClients) {
      if (client.data.ready) return true;
    }
    return false;
  }

  /**
   * Get number of connected WebSocket clients
   */
  getClientCount(): number {
    return this.wsClients.size;
  }

  /**
   * Get number of ready (handshake complete) clients
   */
  getReadyClientCount(): number {
    let count = 0;
    for (const client of this.wsClients) {
      if (client.data.ready) count++;
    }
    return count;
  }

  /**
   * Get aggregated metrics about command execution
   */
  getMetrics(): BridgeMetrics {
    const total = this.commandHistory.length;

    // Single-pass loop to count successes and sum durations
    let successes = 0;
    let totalDuration = 0;
    for (const cmd of this.commandHistory) {
      if (cmd.success) successes++;
      totalDuration += cmd.duration;
    }

    const avgDuration = total > 0 ? totalDuration / total : 0;

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

  private calculateMethodStats(): Record<
    string,
    { count: number; avgDuration: number; failures: number }
  > {
    // Build object directly instead of Map + Object.fromEntries
    const stats: Record<string, { count: number; avgDuration: number; failures: number }> = {};
    for (const cmd of this.commandHistory) {
      const existing = stats[cmd.method] ?? { count: 0, avgDuration: 0, failures: 0 };
      existing.avgDuration =
        (existing.avgDuration * existing.count + cmd.duration) / (existing.count + 1);
      existing.count++;
      if (!cmd.success) existing.failures++;
      stats[cmd.method] = existing;
    }
    return stats;
  }

  /**
   * Execute a Roblox command with retry logic
   */
  async execute<T = unknown>(
    method: string,
    params: Record<string, unknown>,
    retries = 1
  ): Promise<T> {
    const validated = executeSchema.parse({ method, params, retries });
    method = validated.method;
    params = validated.params;
    retries = validated.retries ?? 1;

    let lastError: Error | undefined;

    for (let attempt = 0; attempt <= retries; attempt++) {
      try {
        return await this.executeOnce<T>(method, params, attempt + 1);
      } catch (error) {
        const isTimeout = error instanceof RobloxTimeoutError;
        const shouldRetry = isTimeout && attempt < retries;
        lastError = error instanceof Error ? error : new Error(String(error));

        if (shouldRetry) {
          logger.bridge.warn(`Timeout on attempt ${attempt + 1}/${retries + 1}, retrying...`, {
            method,
            attempt: attempt + 1,
          });
          await new Promise((resolve) => setTimeout(resolve, 1000));
          continue;
        }

        logger.bridge.error("Command failed", lastError, { method, attempt: attempt + 1 });
        throw error;
      }
    }

    throw (
      lastError ??
      new RobloxTimeoutError(`Failed after ${retries + 1} attempts`, method, retries + 1)
    );
  }

  private async executeOnce<T = unknown>(
    method: string,
    params: Record<string, unknown>,
    attempt: number
  ): Promise<T> {
    // Use substring instead of slice for slightly better performance
    const id = crypto.randomUUID().substring(0, 8);
    const command: RobloxCommand = { id, method, params };

    this.commandQueue.push(command);
    this.commandStartTimes.set(id, Date.now());
    this.sendCommands();

    return new Promise<T>((resolve, reject) => {
      const timeout = setTimeout(() => {
        this.pendingResponses.delete(id);
        this.recordMetric(id, method, false, "Timeout");
        const msg = this.isConnected()
          ? `Command '${method}' timed out after ${config.timeout}ms (attempt ${attempt})`
          : `Command '${method}' timed out. No Roblox Studio plugin connected.`;
        reject(new RobloxTimeoutError(msg, method, attempt));
      }, config.timeout);

      this.pendingResponses.set(id, (result) => {
        clearTimeout(timeout);
        this.recordMetric(id, method, result.success, result.error);
        if (result.success) {
          resolve(result.data as T);
        } else {
          reject(
            new RobloxExecutionError(
              `Roblox error in '${method}': ${result.error ?? "Unknown error"}`,
              method,
              params
            )
          );
        }
      });
    });
  }

  /**
   * Send queued commands to all ready WebSocket clients
   */
  private sendCommands(): void {
    if (this.commandQueue.length === 0) return;

    // Swap references instead of copying array
    const commands = this.commandQueue;
    this.commandQueue = [];

    const message = JSON.stringify({ type: MessageTypes.COMMANDS, data: commands });
    for (const client of this.wsClients) {
      if (client.data.ready) {
        client.send(message);
      }
    }
  }

  private recordMetric(id: string, method: string, success: boolean, error?: string): void {
    const startTime = this.commandStartTimes.get(id);
    const duration = startTime ? Date.now() - startTime : 0;
    this.commandStartTimes.delete(id);

    this.commandHistory.push({ method, timestamp: Date.now(), duration, success, error });
    if (this.commandHistory.length > this.maxHistorySize) {
      this.commandHistory.shift();
    }
  }

  /**
   * Handle result from plugin
   */
  handleResult(result: RobloxResult): void {
    resultSchema.parse(result);
    const resolver = this.pendingResponses.get(result.id);
    if (resolver) {
      resolver(result);
      this.pendingResponses.delete(result.id);
    }
  }

  /**
   * Register WebSocket client
   */
  addClient(ws: ServerWebSocket<WSClientData>): void {
    this.wsClients.add(ws);
    logger.bridge.info("WebSocket client connected", { clientId: ws.data.id });
  }

  /**
   * Mark client as ready after successful handshake
   */
  markClientReady(ws: ServerWebSocket<WSClientData>, version: string): void {
    ws.data.ready = true;
    ws.data.version = version;
    logger.bridge.info("WebSocket client ready", { clientId: ws.data.id, version });

    // Send any queued commands immediately
    if (this.commandQueue.length > 0) {
      this.sendCommands();
    }
  }

  /**
   * Remove WebSocket client
   */
  removeClient(ws: ServerWebSocket<WSClientData>): void {
    this.wsClients.delete(ws);
    logger.bridge.info("WebSocket client disconnected", { clientId: ws.data.id });
  }

  get pendingCount(): number {
    return this.pendingResponses.size;
  }

  resetForTesting(): void {
    this.commandQueue = [];
    this.pendingResponses.clear();
    this.wsClients.clear();
    this.commandHistory = [];
    this.commandStartTimes.clear();
  }
}

export const bridge = new RobloxBridge();

let activeBridgePort: number | null = null;

export function getActiveBridgePort(): number | null {
  return activeBridgePort;
}

/**
 * Handle WebSocket message from plugin
 */
function handleMessage(ws: ServerWebSocket<WSClientData>, message: string | Buffer): void {
  try {
    const data = JSON.parse(message.toString());

    // Handshake - version check
    if (isHandshakeMessage(data)) {
      if (!isVersionCompatible(data.version)) {
        ws.send(
          JSON.stringify({
            type: MessageTypes.ERROR,
            code: "VERSION_MISMATCH",
            message: `Plugin version ${data.version} incompatible with server ${config.version}`,
            serverVersion: config.version,
          })
        );
        ws.close(1008, "Version mismatch");
        return;
      }

      bridge.markClientReady(ws, data.version);
      ws.send(
        JSON.stringify({
          type: MessageTypes.HANDSHAKE_OK,
          serverVersion: config.version,
          pluginVersion: data.version,
        })
      );
      return;
    }

    // Result from command execution
    if (isResultMessage(data)) {
      bridge.handleResult(data.data);
      // Use template literal for simple message
      ws.send(`{"type":"${MessageTypes.ACK}","id":"${data.data.id}"}`);
      return;
    }

    // Ping/pong for keepalive
    if (isPingMessage(data)) {
      // Use template literal for pong response
      ws.send(`{"type":"${MessageTypes.PONG}","timestamp":${Date.now()}}`);
      return;
    }
  } catch {
    // Pre-serialize static error message
    ws.send(`{"type":"${MessageTypes.ERROR}","message":"Invalid JSON"}`);
  }
}

/**
 * Handle incoming request - WebSocket upgrade only
 */
function handleRequest(
  req: Request,
  server: ReturnType<typeof Bun.serve<WSClientData>>,
  port: number
): Response | undefined {
  const url = new URL(req.url);

  // WebSocket upgrade
  if (url.pathname === "/ws" || url.pathname === "/") {
    const clientId = crypto.randomUUID().substring(0, 8);
    const upgraded = server.upgrade(req, {
      data: { id: clientId, connectedAt: Date.now(), ready: false },
    });
    if (!upgraded) {
      return new Response("WebSocket upgrade failed", { status: 400 });
    }
    return undefined;
  }

  // Status endpoint for debugging (optional, lightweight)
  if (req.method === "GET" && url.pathname === "/status") {
    return Response.json({
      service: "roblox-bridge-mcp",
      version: config.version,
      port,
      clients: bridge.getClientCount(),
      ready: bridge.getReadyClientCount(),
      connected: bridge.isConnected(),
      uptime: process.uptime(),
    });
  }

  return new Response("Use WebSocket connection", { status: 426 });
}

/**
 * Start WebSocket-only bridge server
 */
function tryStartServer(port: number): ReturnType<typeof Bun.serve> | null {
  try {
    return Bun.serve<WSClientData>({
      port,
      fetch(req, server) {
        return handleRequest(req, server, port);
      },
      websocket: {
        open(ws) {
          bridge.addClient(ws);
          ws.send(
            JSON.stringify({
              type: MessageTypes.CONNECTED,
              clientId: ws.data.id,
              serverVersion: config.version,
            })
          );
        },
        message(ws, message) {
          handleMessage(ws, message);
        },
        close(ws) {
          bridge.removeClient(ws);
        },
        idleTimeout: 120, // 2 minutes
      },
    });
  } catch (error) {
    if (error instanceof Error && "code" in error && error.code === "EADDRINUSE") {
      return null;
    }
    throw error;
  }
}

/**
 * Start the WebSocket bridge server
 */
/** @internal Exported for testing */
export {
  handleMessage as _handleMessage,
  handleRequest as _handleRequest,
  tryStartServer as _tryStartServer,
};

export function startBridgeServer(): void {
  const port = config.bridgePort;

  try {
    const server = tryStartServer(port);
    if (!server) {
      console.error(`[Bridge] Port ${port} in use. Set ROBLOX_BRIDGE_PORT to a different port.`);
      logger.bridge.warn("Bridge port in use", { port });
      return;
    }

    activeBridgePort = port;
    console.error(`[Bridge] WebSocket server on ws://localhost:${port} (v${config.version})`);
    logger.bridge.info("Bridge server started", { port, version: config.version });
  } catch (error) {
    activeBridgePort = null;
    const msg = error instanceof Error ? error.message : String(error);
    console.error(`[Bridge] Failed to start: ${msg}`);
    logger.bridge.error("Bridge startup failed", error instanceof Error ? error : undefined, {
      port,
    });
  }
}
