import { describe, test, expect, mock, beforeEach } from "bun:test";
import { bridge } from "../../utils/bridge";
import type { ServerWebSocket } from "bun";

// Mock WebSocket client data interface
interface MockWSClientData {
  id: string;
  connectedAt: number;
}

// Mock WebSocket client
const createMockWebSocket = (id: string): ServerWebSocket<MockWSClientData> => {
  const messages: string[] = [];
  const mockWs = {
    data: { id, connectedAt: Date.now() },
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
  };
  return mockWs as unknown as ServerWebSocket<MockWSClientData>;
};

describe("RobloxBridge - WebSocket", () => {
  beforeEach(() => {
    // Reset bridge state between tests
    (bridge as { resetForTesting?: () => void }).resetForTesting?.();
  });
  test("registers WebSocket client", () => {
    const ws = createMockWebSocket("client-1");
    const initialInfo = bridge.getConnectionInfo();

    bridge.addWebSocketClient(ws);
    const info = bridge.getConnectionInfo();

    expect(info.wsClients).toBe(initialInfo.wsClients + 1);
  });

  test("removes WebSocket client", () => {
    const ws = createMockWebSocket("client-2");

    bridge.addWebSocketClient(ws);
    const beforeRemove = bridge.getConnectionInfo();

    bridge.removeWebSocketClient(ws);
    const afterRemove = bridge.getConnectionInfo();

    expect(afterRemove.wsClients).toBe(beforeRemove.wsClients - 1);
  });

  test("notifies WebSocket clients of new commands", async () => {
    const ws = createMockWebSocket("client-3");
    bridge.addWebSocketClient(ws);

    // Clear any existing queue
    bridge.getPendingCommands();

    // Queue a command
    const promise = bridge.execute("CreateInstance", { className: "Part" });

    // Wait a bit for notification
    await new Promise((resolve) => setTimeout(resolve, 50));

    // Check that WebSocket received the command
    const messages = (ws as unknown as { _getMessages: () => string[] })._getMessages();
    expect(messages.length).toBeGreaterThan(0);

    const lastMessage = JSON.parse(messages[messages.length - 1]);
    expect(lastMessage.type).toBe("commands");
    expect(lastMessage.data).toBeArray();
    expect(lastMessage.data[0].method).toBe("CreateInstance");

    // Clean up
    const commands = lastMessage.data;
    bridge.handleResult({ id: commands[0].id, success: true, data: "ok" });
    bridge.removeWebSocketClient(ws);
    await promise;
  });

  test("handles multiple WebSocket clients", () => {
    const ws1 = createMockWebSocket("client-4");
    const ws2 = createMockWebSocket("client-5");
    const ws3 = createMockWebSocket("client-6");

    bridge.addWebSocketClient(ws1);
    bridge.addWebSocketClient(ws2);
    bridge.addWebSocketClient(ws3);

    const info = bridge.getConnectionInfo();
    expect(info.wsClients).toBeGreaterThanOrEqual(3);

    bridge.removeWebSocketClient(ws1);
    bridge.removeWebSocketClient(ws2);
    bridge.removeWebSocketClient(ws3);
  });
});
