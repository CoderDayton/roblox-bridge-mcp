import { describe, test, expect, beforeEach, mock } from "bun:test";
import { bridge } from "../../utils/bridge";
import type { ServerWebSocket } from "bun";

interface MockWSClientData {
  id: string;
  connectedAt: number;
  version?: string;
  ready: boolean;
}

const createMockWebSocket = (id: string, ready = false): ServerWebSocket<MockWSClientData> => {
  const messages: string[] = [];
  return {
    data: { id, connectedAt: Date.now(), ready },
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
  } as unknown as ServerWebSocket<MockWSClientData>;
};

describe("RobloxBridge - Connection State", () => {
  beforeEach(() => {
    (bridge as { resetForTesting?: () => void }).resetForTesting?.();
  });

  test("isConnected returns false when no clients", () => {
    expect(bridge.isConnected()).toBe(false);
  });

  test("isConnected returns false when clients not ready", () => {
    const ws = createMockWebSocket("client-1", false);
    bridge.addClient(ws);

    expect(bridge.isConnected()).toBe(false);

    bridge.removeClient(ws);
  });

  test("isConnected returns true when client is ready", () => {
    const ws = createMockWebSocket("client-1", false);
    bridge.addClient(ws);
    bridge.markClientReady(ws, "1.0.0");

    expect(bridge.isConnected()).toBe(true);

    bridge.removeClient(ws);
  });

  test("getClientCount tracks connected clients", () => {
    expect(bridge.getClientCount()).toBe(0);

    const ws1 = createMockWebSocket("client-1");
    const ws2 = createMockWebSocket("client-2");

    bridge.addClient(ws1);
    expect(bridge.getClientCount()).toBe(1);

    bridge.addClient(ws2);
    expect(bridge.getClientCount()).toBe(2);

    bridge.removeClient(ws1);
    expect(bridge.getClientCount()).toBe(1);

    bridge.removeClient(ws2);
    expect(bridge.getClientCount()).toBe(0);
  });

  test("getReadyClientCount tracks ready clients", () => {
    const ws1 = createMockWebSocket("client-1");
    const ws2 = createMockWebSocket("client-2");

    bridge.addClient(ws1);
    bridge.addClient(ws2);

    expect(bridge.getReadyClientCount()).toBe(0);

    bridge.markClientReady(ws1, "1.0.0");
    expect(bridge.getReadyClientCount()).toBe(1);

    bridge.markClientReady(ws2, "1.0.0");
    expect(bridge.getReadyClientCount()).toBe(2);

    bridge.removeClient(ws1);
    bridge.removeClient(ws2);
  });

  test("pendingCount reflects active commands", async () => {
    const ws = createMockWebSocket("client-1");
    bridge.addClient(ws);
    bridge.markClientReady(ws, "1.0.0");

    const initialCount = bridge.pendingCount;

    const promise1 = bridge.execute("CreateInstance", { className: "Part" });
    expect(bridge.pendingCount).toBe(initialCount + 1);

    const promise2 = bridge.execute("CreateInstance", { className: "Model" });
    expect(bridge.pendingCount).toBe(initialCount + 2);

    // Get command IDs from sent messages
    const messages = (ws as unknown as { _getMessages: () => string[] })._getMessages();
    const cmdMessages = messages.filter((m) => m.includes('"type":"commands"'));
    const allCommands = cmdMessages.flatMap((m) => JSON.parse(m).data);

    bridge.handleResult({ id: allCommands[0].id, success: true, data: "ok" });
    expect(bridge.pendingCount).toBe(initialCount + 1);

    bridge.handleResult({ id: allCommands[1].id, success: true, data: "ok" });
    expect(bridge.pendingCount).toBe(initialCount);

    await Promise.all([promise1, promise2]);
    bridge.removeClient(ws);
  });
});
