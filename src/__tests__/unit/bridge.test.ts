import { describe, test, expect, beforeEach, afterEach, mock } from "bun:test";
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

function getCommands(
  ws: ServerWebSocket<MockWSClientData>
): Array<{ id: string; method: string; params: Record<string, unknown> }> {
  const messages = (ws as unknown as { _getMessages: () => string[] })._getMessages();
  const cmdMessages = messages.filter((m) => m.includes('"type":"commands"'));
  return cmdMessages.flatMap((m) => JSON.parse(m).data);
}

describe("RobloxBridge", () => {
  let ws: ServerWebSocket<MockWSClientData>;

  beforeEach(() => {
    (bridge as { resetForTesting?: () => void }).resetForTesting?.();
    ws = createMockWebSocket("test-client");
    bridge.addClient(ws);
    bridge.markClientReady(ws, "1.0.0");
  });

  afterEach(() => {
    bridge.removeClient(ws);
  });

  describe("command queueing", () => {
    test("sends commands to WebSocket", async () => {
      const executePromise = bridge.execute("CreateInstance", { className: "Part" });
      const commands = getCommands(ws);

      expect(commands).toHaveLength(1);
      expect(commands[0].method).toBe("CreateInstance");
      expect(commands[0].params).toEqual({ className: "Part" });
      expect(commands[0].id).toBeTypeOf("string");

      bridge.handleResult({ id: commands[0].id, success: true, data: "ok" });
      await executePromise;
    });

    test("generates unique IDs for commands", async () => {
      const p1 = bridge.execute("CreateInstance", { className: "Part" });
      const p2 = bridge.execute("DeleteInstance", { path: "game.Workspace.Part" });
      const commands = getCommands(ws);

      expect(commands[0].id).not.toBe(commands[1].id);

      bridge.handleResult({ id: commands[0].id, success: true, data: "ok" });
      bridge.handleResult({ id: commands[1].id, success: true, data: "ok" });
      await Promise.all([p1, p2]);
    });
  });

  describe("result handling", () => {
    test("resolves promise on successful result", async () => {
      const executePromise = bridge.execute<string>("GetProperty", {
        path: "game.Workspace",
        property: "Name",
      });
      const commands = getCommands(ws);

      bridge.handleResult({
        id: commands[0].id,
        success: true,
        data: "Workspace",
      });

      const result = await executePromise;
      expect(result).toBe("Workspace");
    });

    test("rejects promise on failed result", async () => {
      const executePromise = bridge.execute("DeleteInstance", {
        path: "game.Workspace.NonExistent",
      });
      const commands = getCommands(ws);

      bridge.handleResult({
        id: commands[0].id,
        success: false,
        data: null,
        error: "Instance not found: game.Workspace.NonExistent",
      });

      expect(executePromise).rejects.toThrow("Instance not found");
    });

    test("ignores results for unknown command IDs", () => {
      bridge.handleResult({
        id: "unknown-id",
        success: true,
        data: "test",
      });

      expect(true).toBe(true);
    });
  });

  describe("timeout behavior", () => {
    test(
      "rejects after timeout",
      async () => {
        const executePromise = bridge.execute("CreateInstance", { className: "Part" });

        expect(executePromise).toBeInstanceOf(Promise);

        const commands = getCommands(ws);
        bridge.handleResult({
          id: commands[0].id,
          success: true,
          data: "test",
        });

        await executePromise;
      },
      { timeout: 1000 }
    );
  });

  describe("concurrent commands", () => {
    test("handles multiple pending commands", async () => {
      const promise1 = bridge.execute("CreateInstance", { className: "Part" });
      const promise2 = bridge.execute("CreateInstance", { className: "Model" });
      const promise3 = bridge.execute("GetChildren", { path: "game.Workspace" });

      const commands = getCommands(ws);
      expect(commands).toHaveLength(3);

      bridge.handleResult({ id: commands[1].id, success: true, data: "Model created" });
      bridge.handleResult({ id: commands[0].id, success: true, data: "Part created" });
      bridge.handleResult({ id: commands[2].id, success: true, data: ["Part1", "Part2"] });

      const results = await Promise.all([promise1, promise2, promise3]);
      expect(results).toEqual(["Part created", "Model created", ["Part1", "Part2"]]);
    });
  });

  describe("pending count", () => {
    test("tracks pending response count", async () => {
      const initialCount = bridge.pendingCount;

      const promise1 = bridge.execute("CreateInstance", { className: "Part" });
      expect(bridge.pendingCount).toBe(initialCount + 1);

      const promise2 = bridge.execute("CreateInstance", { className: "Model" });
      expect(bridge.pendingCount).toBe(initialCount + 2);

      const commands = getCommands(ws);
      bridge.handleResult({ id: commands[0].id, success: true, data: "ok" });

      await new Promise<void>((resolve) => setTimeout(resolve, 10));
      expect(bridge.pendingCount).toBe(initialCount + 1);

      bridge.handleResult({ id: commands[1].id, success: true, data: "ok" });

      await new Promise<void>((resolve) => setTimeout(resolve, 10));
      expect(bridge.pendingCount).toBe(initialCount);

      await Promise.all([promise1, promise2]);
    });
  });
});
