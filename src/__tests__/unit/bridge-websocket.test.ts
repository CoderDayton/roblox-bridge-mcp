import { describe, test, expect, mock, beforeEach } from "bun:test";
import { bridge } from "../../utils/bridge";
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
  } as unknown as ServerWebSocket<MockWSClientData>;
};

describe("RobloxBridge - WebSocket", () => {
  beforeEach(() => {
    (bridge as { resetForTesting?: () => void }).resetForTesting?.();
  });

  test("registers WebSocket client", () => {
    const ws = createMockWebSocket("client-1");
    const initialCount = bridge.getClientCount();

    bridge.addClient(ws);

    expect(bridge.getClientCount()).toBe(initialCount + 1);

    bridge.removeClient(ws);
  });

  test("removes WebSocket client", () => {
    const ws = createMockWebSocket("client-2");

    bridge.addClient(ws);
    const beforeRemove = bridge.getClientCount();

    bridge.removeClient(ws);

    expect(bridge.getClientCount()).toBe(beforeRemove - 1);
  });

  test("marks client as ready after handshake", () => {
    const ws = createMockWebSocket("client-3");

    bridge.addClient(ws);
    expect(bridge.getReadyClientCount()).toBe(0);
    expect(bridge.isConnected()).toBe(false);

    bridge.markClientReady(ws, "1.0.0");
    expect(bridge.getReadyClientCount()).toBe(1);
    expect(bridge.isConnected()).toBe(true);

    bridge.removeClient(ws);
  });

  test("sends commands only to ready clients", async () => {
    const readyWs = createMockWebSocket("ready-client");
    const notReadyWs = createMockWebSocket("not-ready-client");

    bridge.addClient(readyWs);
    bridge.addClient(notReadyWs);
    bridge.markClientReady(readyWs, "1.0.0");

    const promise = bridge.execute("CreateInstance", { className: "Part" });

    await new Promise((resolve) => setTimeout(resolve, 50));

    const readyMessages = (readyWs as unknown as { _getMessages: () => string[] })._getMessages();
    const notReadyMessages = (
      notReadyWs as unknown as { _getMessages: () => string[] }
    )._getMessages();

    // Ready client should receive commands
    const cmdMessage = readyMessages.find((m) => m.includes('"type":"commands"'));
    expect(cmdMessage).toBeDefined();

    // Not-ready client should not receive commands
    const notReadyCmdMessage = notReadyMessages.find((m) => m.includes('"type":"commands"'));
    expect(notReadyCmdMessage).toBeUndefined();

    // Clean up
    const commands = JSON.parse(cmdMessage!).data;
    bridge.handleResult({ id: commands[0].id, success: true, data: "ok" });
    bridge.removeClient(readyWs);
    bridge.removeClient(notReadyWs);
    await promise;
  });

  test("handles multiple WebSocket clients", () => {
    const ws1 = createMockWebSocket("client-4");
    const ws2 = createMockWebSocket("client-5");
    const ws3 = createMockWebSocket("client-6");

    bridge.addClient(ws1);
    bridge.addClient(ws2);
    bridge.addClient(ws3);

    expect(bridge.getClientCount()).toBe(3);

    bridge.markClientReady(ws1, "1.0.0");
    bridge.markClientReady(ws2, "1.0.0");

    expect(bridge.getReadyClientCount()).toBe(2);

    bridge.removeClient(ws1);
    bridge.removeClient(ws2);
    bridge.removeClient(ws3);

    expect(bridge.getClientCount()).toBe(0);
  });

  test("broadcasts commands to all ready clients", async () => {
    const ws1 = createMockWebSocket("client-7");
    const ws2 = createMockWebSocket("client-8");

    bridge.addClient(ws1);
    bridge.addClient(ws2);
    bridge.markClientReady(ws1, "1.0.0");
    bridge.markClientReady(ws2, "1.0.0");

    const promise = bridge.execute("GetChildren", { path: "game.Workspace" });

    await new Promise((resolve) => setTimeout(resolve, 50));

    const messages1 = (ws1 as unknown as { _getMessages: () => string[] })._getMessages();
    const messages2 = (ws2 as unknown as { _getMessages: () => string[] })._getMessages();

    // Both should receive the command
    expect(messages1.some((m) => m.includes('"type":"commands"'))).toBe(true);
    expect(messages2.some((m) => m.includes('"type":"commands"'))).toBe(true);

    // Clean up
    const cmdMessage = messages1.find((m) => m.includes('"type":"commands"'))!;
    const commands = JSON.parse(cmdMessage).data;
    bridge.handleResult({ id: commands[0].id, success: true, data: ["Part1"] });
    bridge.removeClient(ws1);
    bridge.removeClient(ws2);
    await promise;
  });
});
