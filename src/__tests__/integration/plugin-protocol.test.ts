import { describe, test, expect, beforeAll, afterAll } from "bun:test";
import { _tryStartServer } from "../../utils/bridge";
import { config } from "../../config";

// Helper to find an available port
async function findAvailablePort(startPort: number, maxAttempts = 10): Promise<number> {
  for (let i = 0; i < maxAttempts; i++) {
    const port = startPort + i;
    try {
      const testServer = Bun.serve({
        port,
        fetch() {
          return new Response("test");
        },
      });
      void testServer.stop(true);
      return port;
    } catch {
      continue;
    }
  }
  throw new Error(`No available ports in range ${startPort}-${startPort + maxAttempts - 1}`);
}

// Helper to wait for WebSocket message
function waitForMessage(ws: WebSocket, timeout = 5000): Promise<MessageEvent> {
  return new Promise((resolve, reject) => {
    const timer = setTimeout(() => reject(new Error("Timeout waiting for message")), timeout);
    ws.addEventListener(
      "message",
      (event) => {
        clearTimeout(timer);
        resolve(event);
      },
      { once: true }
    );
  });
}

// Helper to connect and complete handshake
async function connectAndHandshake(port: number, version = config.version): Promise<WebSocket> {
  const ws = new WebSocket(`ws://localhost:${port}/ws`);

  await new Promise<void>((resolve, reject) => {
    ws.addEventListener("open", () => resolve());
    ws.addEventListener("error", reject);
  });

  // Wait for connected message
  const connectedMsg = await waitForMessage(ws);
  const connected = JSON.parse(connectedMsg.data);
  if (connected.type !== "connected") {
    throw new Error(`Expected 'connected', got '${connected.type}'`);
  }

  // Send handshake
  ws.send(JSON.stringify({ type: "handshake", version }));

  // Wait for handshake response
  const handshakeMsg = await waitForMessage(ws);
  const handshake = JSON.parse(handshakeMsg.data);
  if (handshake.type !== "handshake_ok") {
    throw new Error(`Handshake failed: ${JSON.stringify(handshake)}`);
  }

  return ws;
}

describe("Plugin Protocol Integration", () => {
  let server: ReturnType<typeof Bun.serve> | null = null;
  let TEST_PORT: number;

  beforeAll(async () => {
    TEST_PORT = await findAvailablePort(31000);
    server = _tryStartServer(TEST_PORT);
    if (!server) {
      throw new Error(`Failed to start server on port ${TEST_PORT}`);
    }
  });

  afterAll(() => {
    server?.stop(true);
  });

  describe("Handshake Protocol", () => {
    test("server sends connected message on WebSocket open", async () => {
      const ws = new WebSocket(`ws://localhost:${TEST_PORT}/ws`);

      await new Promise<void>((resolve) => ws.addEventListener("open", () => resolve()));

      const msg = await waitForMessage(ws);
      const data = JSON.parse(msg.data);

      expect(data.type).toBe("connected");
      expect(data.clientId).toBeDefined();
      expect(data.serverVersion).toBe(config.version);

      ws.close();
    });

    test("accepts valid version handshake", async () => {
      const ws = new WebSocket(`ws://localhost:${TEST_PORT}/ws`);

      await new Promise<void>((resolve) => ws.addEventListener("open", () => resolve()));

      // Wait for connected
      await waitForMessage(ws);

      // Send handshake with matching major.minor version
      ws.send(JSON.stringify({ type: "handshake", version: config.version }));

      const response = await waitForMessage(ws);
      const data = JSON.parse(response.data);

      expect(data.type).toBe("handshake_ok");
      expect(data.serverVersion).toBe(config.version);
      expect(data.pluginVersion).toBe(config.version);

      ws.close();
    });

    test("accepts compatible patch version", async () => {
      const ws = new WebSocket(`ws://localhost:${TEST_PORT}/ws`);

      await new Promise<void>((resolve) => ws.addEventListener("open", () => resolve()));
      await waitForMessage(ws);

      // Same major.minor, different patch
      const [major, minor] = config.version.split(".");
      const compatibleVersion = `${major}.${minor}.99`;

      ws.send(JSON.stringify({ type: "handshake", version: compatibleVersion }));

      const response = await waitForMessage(ws);
      const data = JSON.parse(response.data);

      expect(data.type).toBe("handshake_ok");

      ws.close();
    });

    test("rejects incompatible version", async () => {
      const ws = new WebSocket(`ws://localhost:${TEST_PORT}/ws`);

      await new Promise<void>((resolve) => ws.addEventListener("open", () => resolve()));
      await waitForMessage(ws);

      // Incompatible major version
      ws.send(JSON.stringify({ type: "handshake", version: "99.99.99" }));

      const response = await waitForMessage(ws);
      const data = JSON.parse(response.data);

      expect(data.type).toBe("error");
      expect(data.code).toBe("VERSION_MISMATCH");
      expect(data.message).toContain("incompatible");
      expect(data.serverVersion).toBe(config.version);

      // Connection should be closed
      await new Promise<void>((resolve) => {
        ws.addEventListener("close", () => resolve());
        setTimeout(resolve, 1000); // Fallback timeout
      });
    });
  });

  describe("Ping/Pong Keepalive", () => {
    test("responds to ping with pong and timestamp", async () => {
      const ws = await connectAndHandshake(TEST_PORT);

      const beforePing = Date.now();
      ws.send(JSON.stringify({ type: "ping" }));

      const response = await waitForMessage(ws);
      const afterPing = Date.now();
      const data = JSON.parse(response.data);

      expect(data.type).toBe("pong");
      expect(data.timestamp).toBeGreaterThanOrEqual(beforePing);
      expect(data.timestamp).toBeLessThanOrEqual(afterPing);

      ws.close();
    });

    test("handles multiple pings", async () => {
      const ws = await connectAndHandshake(TEST_PORT);

      for (let i = 0; i < 3; i++) {
        ws.send(JSON.stringify({ type: "ping" }));
        const response = await waitForMessage(ws);
        const data = JSON.parse(response.data);
        expect(data.type).toBe("pong");
      }

      ws.close();
    });
  });

  describe("Command Protocol", () => {
    test("client receives commands and sends result", async () => {
      const ws = await connectAndHandshake(TEST_PORT);

      // Import bridge to queue a command
      const { bridge } = await import("../../utils/bridge");

      // Execute command (will timeout, but we intercept)
      const executePromise = bridge.execute("TestMethod", { arg: "value" }).catch(() => "timeout");

      // Wait for command message
      const cmdMsg = await waitForMessage(ws, 1000);
      const cmdData = JSON.parse(cmdMsg.data);

      expect(cmdData.type).toBe("commands");
      expect(Array.isArray(cmdData.data)).toBe(true);
      expect(cmdData.data.length).toBeGreaterThan(0);

      const command = cmdData.data[0];
      expect(command.id).toBeDefined();
      expect(command.method).toBe("TestMethod");
      expect(command.params).toEqual({ arg: "value" });

      // Send result back
      ws.send(
        JSON.stringify({
          type: "result",
          data: {
            id: command.id,
            success: true,
            data: { result: "test-output" },
          },
        })
      );

      // Wait for ack
      const ackMsg = await waitForMessage(ws);
      const ackData = JSON.parse(ackMsg.data);

      expect(ackData.type).toBe("ack");
      expect(ackData.id).toBe(command.id);

      // Verify command resolved
      const result = await executePromise;
      expect(result).toEqual({ result: "test-output" });

      ws.close();
    });

    test("handles command failure result", async () => {
      const ws = await connectAndHandshake(TEST_PORT);
      const { bridge } = await import("../../utils/bridge");

      const executePromise = bridge.execute("FailingMethod", {}).catch((e) => e.message);

      const cmdMsg = await waitForMessage(ws, 1000);
      const cmdData = JSON.parse(cmdMsg.data);
      const command = cmdData.data[0];

      // Send failure result
      ws.send(
        JSON.stringify({
          type: "result",
          data: {
            id: command.id,
            success: false,
            data: null,
            error: "Test error message",
          },
        })
      );

      await waitForMessage(ws); // ack

      const errorMsg = await executePromise;
      expect(errorMsg).toContain("FailingMethod");
      expect(errorMsg).toContain("Test error message");

      ws.close();
    });
  });

  describe("Error Handling", () => {
    test("handles invalid JSON gracefully", async () => {
      const ws = await connectAndHandshake(TEST_PORT);

      ws.send("not valid json {{{");

      const response = await waitForMessage(ws);
      const data = JSON.parse(response.data);

      expect(data.type).toBe("error");
      expect(data.message).toBe("Invalid JSON");

      ws.close();
    });

    test("handles unknown message types", async () => {
      const ws = await connectAndHandshake(TEST_PORT);

      ws.send(JSON.stringify({ type: "unknown_type", data: {} }));

      // Should not crash - connection stays open
      ws.send(JSON.stringify({ type: "ping" }));

      const response = await waitForMessage(ws);
      const data = JSON.parse(response.data);

      expect(data.type).toBe("pong");

      ws.close();
    });

    test("handles empty message", async () => {
      const ws = await connectAndHandshake(TEST_PORT);

      ws.send("");

      const response = await waitForMessage(ws);
      const data = JSON.parse(response.data);

      expect(data.type).toBe("error");

      ws.close();
    });
  });

  describe("Status Endpoint", () => {
    test("GET /status returns server info", async () => {
      const response = await fetch(`http://localhost:${TEST_PORT}/status`);
      expect(response.status).toBe(200);

      const data = await response.json();
      expect(data.service).toBe("roblox-bridge-mcp");
      expect(data.version).toBe(config.version);
      expect(data.port).toBe(TEST_PORT);
      expect(typeof data.clients).toBe("number");
      expect(typeof data.ready).toBe("number");
      expect(typeof data.connected).toBe("boolean");
      expect(typeof data.uptime).toBe("number");
    });

    test("non-WebSocket request to / returns 400 (upgrade failed)", async () => {
      const response = await fetch(`http://localhost:${TEST_PORT}/`);
      // Returns 400 because WebSocket upgrade fails for non-WS requests
      expect(response.status).toBe(400);
    });
  });
});
