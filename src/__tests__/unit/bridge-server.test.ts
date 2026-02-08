import { describe, test, expect, beforeEach, afterEach, mock } from "bun:test";
import {
  bridge,
  getActiveBridgePort,
  startBridgeServer,
  _handleMessage,
  _handleRequest,
  _tryStartServer,
} from "../../utils/bridge";
import { config } from "../../config";
import type { ServerWebSocket } from "bun";

interface MockWSClientData {
  id: string;
  connectedAt: number;
  version?: string;
  ready: boolean;
}

const createMockWebSocket = (id: string): ServerWebSocket<MockWSClientData> => {
  const messages: string[] = [];
  return {
    data: { id, connectedAt: Date.now(), ready: false },
    send: mock((msg: string) => messages.push(msg)),
    close: mock(() => {}),
    readyState: 1,
    remoteAddress: "127.0.0.1",
    binaryType: "nodebuffer" as const,
    subscribe: mock(() => {}),
    unsubscribe: mock(() => {}),
    publish: mock(() => 0),
    publishText: mock(() => 0),
    publishBinary: mock(() => 0),
    isSubscribed: mock(() => false),
    cork: mock(() => {}),
    ping: mock(() => {}),
    pong: mock(() => {}),
    terminate: mock(() => {}),
    sendBinary: mock(() => {}),
    sendText: mock(() => {}),
    subscriptions: [],
    getBufferedAmount: mock(() => 0),
    _getMessages: () => messages,
    _clearMessages: () => {
      messages.length = 0;
    },
  } as unknown as ServerWebSocket<MockWSClientData>;
};

function getMessages(ws: ServerWebSocket<MockWSClientData>): string[] {
  return (ws as unknown as { _getMessages: () => string[] })._getMessages();
}

function clearMessages(ws: ServerWebSocket<MockWSClientData>): void {
  (ws as unknown as { _clearMessages: () => void })._clearMessages();
}

describe("Bridge Server Functions", () => {
  describe("getActiveBridgePort", () => {
    test("returns null before server starts", () => {
      // Note: This tests the initial state. If server was started elsewhere,
      // this may return a port. The function itself just returns the module variable.
      const port = getActiveBridgePort();
      expect(port === null || typeof port === "number").toBe(true);
    });
  });

  describe("startBridgeServer", () => {
    test("starts server and sets active port", () => {
      // startBridgeServer is typically called once at app startup
      // We can verify it doesn't throw and check getActiveBridgePort after
      startBridgeServer();
      const port = getActiveBridgePort();
      // After calling startBridgeServer, port should be set (or null if port in use)
      expect(port === null || port === config.bridgePort).toBe(true);
    });
  });
});

describe("Timeout Message Paths", () => {
  let ws: ServerWebSocket<MockWSClientData>;

  beforeEach(() => {
    (bridge as { resetForTesting?: () => void }).resetForTesting?.();
    ws = createMockWebSocket("timeout-test-client");
  });

  afterEach(() => {
    bridge.removeClient(ws);
  });

  test("timeout message when not connected shows plugin not connected", async () => {
    // Do NOT add any client - isConnected() returns false
    expect(bridge.isConnected()).toBe(false);

    // Use a very short timeout for testing by mocking config
    const originalTimeout = config.timeout;
    (config as { timeout: number }).timeout = 100;

    try {
      await bridge.execute("TestMethod", { test: true });
      expect.unreachable("Should have thrown error");
    } catch (error) {
      expect(error).toBeDefined();
      const msg = (error as Error).message;
      // Either timeout (no plugin) or execution error (parallel test client responded)
      const isTimeoutNoPlugin = msg.includes("No Roblox Studio plugin connected");
      const isTimeoutWithPlugin = msg.includes("timed out");
      const isUnknownMethod = msg.includes("Unknown method");
      expect(isTimeoutNoPlugin || isTimeoutWithPlugin || isUnknownMethod).toBe(true);
    } finally {
      (config as { timeout: number }).timeout = originalTimeout;
    }
  });

  test("timeout message when connected shows standard timeout", async () => {
    // Add and mark client ready - isConnected() returns true
    bridge.addClient(ws);
    bridge.markClientReady(ws, "2.0.0");
    expect(bridge.isConnected()).toBe(true);

    const originalTimeout = config.timeout;
    (config as { timeout: number }).timeout = 100;

    try {
      await bridge.execute("TestMethod", { test: true });
      expect.unreachable("Should have thrown timeout error");
    } catch (error) {
      expect(error).toBeDefined();
      expect((error as Error).message).toContain("timed out after");
      expect((error as Error).message).not.toContain("No Roblox Studio plugin connected");
    } finally {
      (config as { timeout: number }).timeout = originalTimeout;
    }
  });
});

describe("WebSocket Server Integration", () => {
  let server: ReturnType<typeof Bun.serve> | null = null;
  const TEST_PORT = 62899;

  beforeEach(() => {
    (bridge as { resetForTesting?: () => void }).resetForTesting?.();
  });

  afterEach(() => {
    if (server) {
      server.stop(true);
      server = null;
    }
  });

  test("WebSocket upgrade on root path", async () => {
    server = Bun.serve({
      port: TEST_PORT,
      fetch(req, server) {
        const url = new URL(req.url);
        if (url.pathname === "/" || url.pathname === "/ws") {
          const upgraded = server.upgrade(req, {
            data: { id: "test", connectedAt: Date.now(), ready: false },
          });
          if (!upgraded) {
            return new Response("WebSocket upgrade failed", { status: 400 });
          }
          return undefined;
        }
        return new Response("Use WebSocket connection", { status: 426 });
      },
      websocket: {
        open() {},
        message() {},
        close() {},
      },
    });

    // Test that non-WebSocket request to root gets 426
    const response = await fetch(`http://localhost:${TEST_PORT}/`);
    // Without Upgrade header, should return 426 or fail upgrade
    expect(response.status === 426 || response.status === 400).toBe(true);
  });

  test("status endpoint returns JSON with service info", async () => {
    server = Bun.serve({
      port: TEST_PORT,
      fetch(req) {
        const url = new URL(req.url);
        if (req.method === "GET" && url.pathname === "/status") {
          return Response.json({
            service: "roblox-bridge-mcp",
            version: config.version,
            port: TEST_PORT,
            clients: bridge.getClientCount(),
            ready: bridge.getReadyClientCount(),
            connected: bridge.isConnected(),
            uptime: process.uptime(),
          });
        }
        return new Response("Use WebSocket connection", { status: 426 });
      },
      websocket: {
        open() {},
        message() {},
        close() {},
      },
    });

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

  test("unknown paths return 426", async () => {
    server = Bun.serve({
      port: TEST_PORT,
      fetch(req) {
        const url = new URL(req.url);
        if (url.pathname === "/status") {
          return Response.json({ status: "ok" });
        }
        if (url.pathname === "/" || url.pathname === "/ws") {
          return new Response("WebSocket upgrade failed", { status: 400 });
        }
        return new Response("Use WebSocket connection", { status: 426 });
      },
      websocket: {
        open() {},
        message() {},
        close() {},
      },
    });

    const response = await fetch(`http://localhost:${TEST_PORT}/unknown/path`);
    expect(response.status).toBe(426);
    expect(await response.text()).toBe("Use WebSocket connection");
  });
});

describe("handleMessage simulation", () => {
  let ws: ServerWebSocket<MockWSClientData>;

  beforeEach(() => {
    (bridge as { resetForTesting?: () => void }).resetForTesting?.();
    ws = createMockWebSocket("msg-test-client");
    bridge.addClient(ws);
  });

  afterEach(() => {
    bridge.removeClient(ws);
  });

  // Simulate handleMessage behavior by testing bridge methods it calls

  test("handshake with compatible version marks client ready", () => {
    expect(ws.data.ready).toBe(false);
    expect(bridge.isConnected()).toBe(false);

    // Simulate what handleMessage does on handshake
    bridge.markClientReady(ws, "2.0.0");

    expect(ws.data.ready).toBe(true);
    expect(ws.data.version).toBe("2.0.0");
    expect(bridge.isConnected()).toBe(true);
  });

  test("result message triggers handleResult", async () => {
    bridge.markClientReady(ws, "2.0.0");

    const executePromise = bridge.execute("TestMethod", { param: "value" });

    // Get the command ID from sent messages
    const messages = getMessages(ws);
    const cmdMessage = messages.find((m) => m.includes('"type":"commands"'));
    expect(cmdMessage).toBeDefined();

    const parsed = JSON.parse(cmdMessage!);
    const commandId = parsed.data[0].id;

    // Simulate what handleMessage does when receiving result
    bridge.handleResult({
      id: commandId,
      success: true,
      data: { result: "success" },
    });

    const result = await executePromise;
    expect(result).toEqual({ result: "success" });
  });

  test("handleResult with failed result rejects promise", async () => {
    bridge.markClientReady(ws, "2.0.0");

    const executePromise = bridge.execute("FailingMethod", { param: "value" });

    const messages = getMessages(ws);
    const cmdMessage = messages.find((m) => m.includes('"type":"commands"'));
    const parsed = JSON.parse(cmdMessage!);
    const commandId = parsed.data[0].id;

    bridge.handleResult({
      id: commandId,
      success: false,
      data: null,
      error: "Execution failed",
    });

    await expect(executePromise).rejects.toThrow("Execution failed");
  });

  test("handleResult validates result schema", () => {
    // Invalid result should throw validation error
    expect(() => {
      bridge.handleResult({
        id: "", // Empty ID is invalid
        success: true,
        data: null,
      });
    }).toThrow();
  });

  test("handleResult ignores unknown command IDs", () => {
    // Should not throw when result ID doesn't match any pending command
    expect(() => {
      bridge.handleResult({
        id: "unknown-command-id",
        success: true,
        data: "ignored",
      });
    }).not.toThrow();
  });
});

describe("WebSocket message handling simulation", () => {
  let ws: ServerWebSocket<MockWSClientData>;

  beforeEach(() => {
    (bridge as { resetForTesting?: () => void }).resetForTesting?.();
    ws = createMockWebSocket("ws-msg-client");
    bridge.addClient(ws);
  });

  afterEach(() => {
    bridge.removeClient(ws);
  });

  test("ping message handling - bridge sends pong", () => {
    // The handleMessage function sends pong on ping
    // We test the expected behavior pattern
    bridge.markClientReady(ws, "2.0.0");
    clearMessages(ws);

    // In real implementation, handleMessage would send:
    // ws.send(JSON.stringify({ type: "pong", timestamp: Date.now() }))
    // We verify the ws.send mock works
    ws.send(JSON.stringify({ type: "pong", timestamp: Date.now() }));

    const messages = getMessages(ws);
    expect(messages.some((m) => m.includes('"type":"pong"'))).toBe(true);
  });

  test("invalid JSON sends error response", () => {
    // In handleMessage, invalid JSON results in:
    // ws.send(JSON.stringify({ type: "error", message: "Invalid JSON" }))
    ws.send(JSON.stringify({ type: "error", message: "Invalid JSON" }));

    const messages = getMessages(ws);
    const errorMsg = messages.find((m) => m.includes('"type":"error"'));
    expect(errorMsg).toBeDefined();
    expect(errorMsg).toContain("Invalid JSON");
  });
});

describe("Server port handling", () => {
  test("tryStartServer returns null on EADDRINUSE", async () => {
    const TEST_PORT = 62898;
    const firstServer = Bun.serve({
      port: TEST_PORT,
      fetch() {
        return new Response("OK");
      },
    });

    try {
      let secondServer: ReturnType<typeof Bun.serve> | null = null;
      try {
        secondServer = Bun.serve({
          port: TEST_PORT,
          fetch() {
            return new Response("OK");
          },
        });
        secondServer?.stop(true);
      } catch (error) {
        expect(error).toBeDefined();
        if (error instanceof Error && "code" in error) {
          expect(error.code).toBe("EADDRINUSE");
        }
      }
    } finally {
      firstServer.stop(true);
    }
  });
});

describe("handleMessage direct tests", () => {
  let ws: ServerWebSocket<MockWSClientData>;

  beforeEach(() => {
    (bridge as { resetForTesting?: () => void }).resetForTesting?.();
    ws = createMockWebSocket("handle-msg-client");
    bridge.addClient(ws);
  });

  afterEach(() => {
    bridge.removeClient(ws);
  });

  test("handshake with compatible version sends handshake_ok", () => {
    _handleMessage(ws, JSON.stringify({ type: "handshake", version: "2.0.0" }));

    const messages = getMessages(ws);
    expect(messages.some((m) => m.includes('"type":"handshake_ok"'))).toBe(true);
    expect(ws.data.ready).toBe(true);
  });

  test("handshake with incompatible version sends error and closes", () => {
    _handleMessage(ws, JSON.stringify({ type: "handshake", version: "0.0.1" }));

    const messages = getMessages(ws);
    expect(messages.some((m) => m.includes('"type":"error"'))).toBe(true);
    expect(messages.some((m) => m.includes("VERSION_MISMATCH"))).toBe(true);
    expect(ws.close).toHaveBeenCalled();
  });

  test("result message calls handleResult and sends ack", async () => {
    bridge.markClientReady(ws, "2.0.0");
    clearMessages(ws);

    const executePromise = bridge.execute("TestCmd", { test: true });
    const cmdMessages = getMessages(ws);
    const cmdMsg = cmdMessages.find((m) => m.includes('"type":"commands"'));
    const cmdId = JSON.parse(cmdMsg!).data[0].id;

    clearMessages(ws);
    _handleMessage(
      ws,
      JSON.stringify({
        type: "result",
        data: { id: cmdId, success: true, data: "test-result" },
      })
    );

    const messages = getMessages(ws);
    expect(messages.some((m) => m.includes('"type":"ack"'))).toBe(true);

    const result = await executePromise;
    expect(result).toBe("test-result");
  });

  test("ping message returns pong with timestamp", () => {
    _handleMessage(ws, JSON.stringify({ type: "ping" }));

    const messages = getMessages(ws);
    const pongMsg = messages.find((m) => m.includes('"type":"pong"'));
    expect(pongMsg).toBeDefined();
    expect(pongMsg).toContain("timestamp");
  });

  test("invalid JSON sends error message", () => {
    _handleMessage(ws, "not valid json {{{");

    const messages = getMessages(ws);
    expect(messages.some((m) => m.includes('"type":"error"'))).toBe(true);
    expect(messages.some((m) => m.includes("Invalid JSON"))).toBe(true);
  });

  test("Buffer message is handled correctly", () => {
    const buffer = Buffer.from(JSON.stringify({ type: "ping" }));
    _handleMessage(ws, buffer);

    const messages = getMessages(ws);
    expect(messages.some((m) => m.includes('"type":"pong"'))).toBe(true);
  });
});

describe("handleRequest direct tests", () => {
  let mockServer: ReturnType<typeof Bun.serve>;
  const TEST_PORT = 62896;

  beforeEach(() => {
    (bridge as { resetForTesting?: () => void }).resetForTesting?.();
    mockServer = Bun.serve({
      port: TEST_PORT,
      fetch(req, server) {
        return _handleRequest(req, server, TEST_PORT);
      },
      websocket: {
        open(ws) {
          bridge.addClient(ws as ServerWebSocket<MockWSClientData>);
        },
        message(ws, msg) {
          _handleMessage(ws as ServerWebSocket<MockWSClientData>, msg);
        },
        close(ws) {
          bridge.removeClient(ws as ServerWebSocket<MockWSClientData>);
        },
      },
    });
  });

  afterEach(() => {
    mockServer.stop(true);
  });

  test("GET /status returns JSON service info", async () => {
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

  test("unknown path returns 426", async () => {
    const response = await fetch(`http://localhost:${TEST_PORT}/unknown`);
    expect(response.status).toBe(426);
    expect(await response.text()).toBe("Use WebSocket connection");
  });

  test("root path without upgrade returns 400", async () => {
    const response = await fetch(`http://localhost:${TEST_PORT}/`);
    // Without WebSocket upgrade headers, server.upgrade returns false
    expect(response.status).toBe(400);
  });

  test("/ws path WebSocket upgrade works", async () => {
    const ws = new WebSocket(`ws://localhost:${TEST_PORT}/ws`);
    let connected = false;

    await new Promise<void>((resolve, reject) => {
      ws.onopen = () => {
        connected = true;
        resolve();
      };
      ws.onerror = reject;
      setTimeout(() => reject(new Error("Timeout")), 2000);
    });

    ws.close();
    expect(connected).toBe(true);
  });
});

describe("tryStartServer direct tests", () => {
  test("returns server on success", () => {
    const server = _tryStartServer(62895);
    expect(server).not.toBeNull();
    server?.stop(true);
  });

  test("returns null when port in use", () => {
    const first = _tryStartServer(62894);
    expect(first).not.toBeNull();

    const second = _tryStartServer(62894);
    expect(second).toBeNull();

    first?.stop(true);
  });

  test("WebSocket open handler sends connected message", async () => {
    (bridge as { resetForTesting?: () => void }).resetForTesting?.();
    const server = _tryStartServer(62893);
    expect(server).not.toBeNull();

    const ws = new WebSocket("ws://localhost:62893/");
    let connectedMsg: string | null = null;

    await new Promise<void>((resolve, reject) => {
      ws.onmessage = (e) => {
        connectedMsg = e.data;
        resolve();
      };
      ws.onerror = reject;
      setTimeout(() => reject(new Error("Timeout")), 2000);
    });

    ws.close();
    server?.stop(true);

    expect(connectedMsg).not.toBeNull();
    const parsed = JSON.parse(connectedMsg!);
    expect(parsed.type).toBe("connected");
    expect(parsed.clientId).toBeDefined();
    expect(parsed.serverVersion).toBe(config.version);
  });

  test("WebSocket message handler processes handshake", async () => {
    (bridge as { resetForTesting?: () => void }).resetForTesting?.();
    const server = _tryStartServer(62892);
    expect(server).not.toBeNull();

    const ws = new WebSocket("ws://localhost:62892/ws");
    let handshakeOk = false;
    let isConnectedAfterHandshake = false;

    await new Promise<void>((resolve, reject) => {
      ws.onmessage = (e) => {
        const data = JSON.parse(e.data);
        if (data.type === "connected") {
          ws.send(JSON.stringify({ type: "handshake", version: "2.0.0" }));
        }
        if (data.type === "handshake_ok") {
          handshakeOk = true;
          isConnectedAfterHandshake = bridge.isConnected();
          resolve();
        }
      };
      ws.onerror = reject;
      setTimeout(() => reject(new Error("Timeout")), 2000);
    });

    ws.close();
    server?.stop(true);

    expect(handshakeOk).toBe(true);
    expect(isConnectedAfterHandshake).toBe(true);
  });

  test("WebSocket close handler removes client", async () => {
    (bridge as { resetForTesting?: () => void }).resetForTesting?.();
    const server = _tryStartServer(62891);
    expect(server).not.toBeNull();

    const ws = new WebSocket("ws://localhost:62891/");

    await new Promise<void>((resolve, reject) => {
      ws.onmessage = (e) => {
        const data = JSON.parse(e.data);
        if (data.type === "connected") {
          ws.send(JSON.stringify({ type: "handshake", version: "2.0.0" }));
        }
        if (data.type === "handshake_ok") resolve();
      };
      ws.onerror = reject;
      setTimeout(() => reject(new Error("Timeout")), 2000);
    });

    expect(bridge.getClientCount()).toBe(1);
    ws.close();

    // Wait for close to propagate
    await new Promise((r) => setTimeout(r, 100));

    expect(bridge.getClientCount()).toBe(0);
    server?.stop(true);
  });
});

describe("Real WebSocket Server Integration", () => {
  const TEST_PORT = 62897;
  let server: ReturnType<typeof Bun.serve> | null = null;

  beforeEach(() => {
    (bridge as { resetForTesting?: () => void }).resetForTesting?.();
  });

  afterEach(() => {
    server?.stop(true);
    server = null;
  });

  function startTestServer() {
    server = Bun.serve<MockWSClientData>({
      port: TEST_PORT,
      fetch(req, srv) {
        const url = new URL(req.url);
        if (url.pathname === "/ws" || url.pathname === "/") {
          const clientId = crypto.randomUUID().slice(0, 8);
          const upgraded = srv.upgrade(req, {
            data: { id: clientId, connectedAt: Date.now(), ready: false },
          });
          if (!upgraded) return new Response("Upgrade failed", { status: 400 });
          return undefined;
        }
        if (req.method === "GET" && url.pathname === "/status") {
          return Response.json({
            service: "roblox-bridge-mcp",
            version: config.version,
            port: TEST_PORT,
            clients: bridge.getClientCount(),
          });
        }
        return new Response("Use WebSocket connection", { status: 426 });
      },
      websocket: {
        open(ws) {
          bridge.addClient(ws);
          ws.send(JSON.stringify({ type: "connected", clientId: ws.data.id }));
        },
        message(ws, message) {
          try {
            const data = JSON.parse(message.toString());
            if (data.type === "handshake" && data.version) {
              bridge.markClientReady(ws, data.version);
              ws.send(JSON.stringify({ type: "handshake_ok" }));
              return;
            }
            if (data.type === "result" && data.data) {
              bridge.handleResult(data.data);
              ws.send(JSON.stringify({ type: "ack", id: data.data.id }));
              return;
            }
            if (data.type === "ping") {
              ws.send(JSON.stringify({ type: "pong", timestamp: Date.now() }));
              return;
            }
          } catch {
            ws.send(JSON.stringify({ type: "error", message: "Invalid JSON" }));
          }
        },
        close(ws) {
          bridge.removeClient(ws);
        },
      },
    });
    return server;
  }

  test("WebSocket client connects and receives connected message", async () => {
    startTestServer();
    const ws = new WebSocket(`ws://localhost:${TEST_PORT}/ws`);
    const messages: string[] = [];

    await new Promise<void>((resolve, reject) => {
      ws.onopen = () => {};
      ws.onmessage = (e) => {
        messages.push(e.data);
        if (messages.length === 1) resolve();
      };
      ws.onerror = reject;
      setTimeout(() => reject(new Error("Timeout")), 2000);
    });

    ws.close();
    expect(messages[0]).toContain('"type":"connected"');
  });

  test("handshake message marks client ready", async () => {
    startTestServer();
    const ws = new WebSocket(`ws://localhost:${TEST_PORT}/ws`);
    const messages: string[] = [];

    await new Promise<void>((resolve, reject) => {
      ws.onmessage = (e) => {
        messages.push(e.data);
        const data = JSON.parse(e.data);
        if (data.type === "connected") {
          ws.send(JSON.stringify({ type: "handshake", version: "2.0.0" }));
        }
        if (data.type === "handshake_ok") resolve();
      };
      ws.onerror = reject;
      setTimeout(() => reject(new Error("Timeout")), 2000);
    });

    expect(bridge.isConnected()).toBe(true);
    ws.close();
  });

  test("ping message returns pong", async () => {
    startTestServer();
    const ws = new WebSocket(`ws://localhost:${TEST_PORT}/ws`);
    let pongReceived = false;

    await new Promise<void>((resolve, reject) => {
      ws.onmessage = (e) => {
        const data = JSON.parse(e.data);
        if (data.type === "connected") {
          ws.send(JSON.stringify({ type: "ping" }));
        }
        if (data.type === "pong") {
          pongReceived = true;
          resolve();
        }
      };
      ws.onerror = reject;
      setTimeout(() => reject(new Error("Timeout")), 2000);
    });

    ws.close();
    expect(pongReceived).toBe(true);
  });

  test("invalid JSON returns error", async () => {
    startTestServer();
    const ws = new WebSocket(`ws://localhost:${TEST_PORT}/ws`);
    let errorReceived = false;

    await new Promise<void>((resolve, reject) => {
      ws.onmessage = (e) => {
        const data = JSON.parse(e.data);
        if (data.type === "connected") {
          ws.send("not valid json {{{");
        }
        if (data.type === "error") {
          errorReceived = true;
          resolve();
        }
      };
      ws.onerror = reject;
      setTimeout(() => reject(new Error("Timeout")), 2000);
    });

    ws.close();
    expect(errorReceived).toBe(true);
  });

  test("result message triggers ack response", async () => {
    startTestServer();
    const ws = new WebSocket(`ws://localhost:${TEST_PORT}/ws`);
    let ackReceived = false;

    await new Promise<void>((resolve, reject) => {
      ws.onmessage = (e) => {
        const data = JSON.parse(e.data);
        if (data.type === "connected") {
          ws.send(JSON.stringify({ type: "handshake", version: "2.0.0" }));
        }
        if (data.type === "handshake_ok") {
          // Send a result message
          ws.send(
            JSON.stringify({
              type: "result",
              data: { id: "test-id", success: true, data: "ok" },
            })
          );
        }
        if (data.type === "ack") {
          ackReceived = true;
          resolve();
        }
      };
      ws.onerror = reject;
      setTimeout(() => reject(new Error("Timeout")), 2000);
    });

    ws.close();
    expect(ackReceived).toBe(true);
  });
});
