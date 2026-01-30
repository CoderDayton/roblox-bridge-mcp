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

describe("RobloxBridge - Metrics", () => {
  let ws: ServerWebSocket<MockWSClientData>;

  beforeEach(async () => {
    (bridge as { resetForTesting?: () => void }).resetForTesting?.();
    ws = createMockWebSocket("test-client");
    bridge.addClient(ws);
    bridge.markClientReady(ws, "1.0.0");
    await new Promise((resolve) => setTimeout(resolve, 50));
  });

  afterEach(() => {
    bridge.removeClient(ws);
  });

  test("tracks successful command execution", async () => {
    const metricsBefore = bridge.getMetrics();

    const promise = bridge.execute("CreateInstance", { className: "Part" });
    const commands = getCommands(ws);

    bridge.handleResult({ id: commands[0].id, success: true, data: "Part created" });
    await promise;

    const metricsAfter = bridge.getMetrics();

    expect(metricsAfter.totalCommands).toBeGreaterThan(metricsBefore.totalCommands);
    expect(metricsAfter.successCount).toBeGreaterThan(metricsBefore.successCount);
  });

  test("tracks failed command execution", async () => {
    const metricsBefore = bridge.getMetrics();

    const promise = bridge.execute("DeleteInstance", { path: "game.Workspace.NonExistent" });
    const commands = getCommands(ws);

    bridge.handleResult({
      id: commands[0].id,
      success: false,
      data: null,
      error: "Instance not found",
    });

    await promise.catch(() => {});

    const metricsAfter = bridge.getMetrics();

    expect(metricsAfter.totalCommands).toBeGreaterThan(metricsBefore.totalCommands);
    expect(metricsAfter.failureCount).toBeGreaterThan(metricsBefore.failureCount);
  });

  test("calculates success rate correctly", async () => {
    const promises: Promise<unknown>[] = [];

    for (let i = 0; i < 3; i++) {
      const p = bridge.execute("CreateInstance", { className: "Part" });
      promises.push(p);
    }

    const failPromise = bridge.execute("DeleteInstance", { path: "NonExistent" });
    promises.push(failPromise.catch(() => {}));

    const commands = getCommands(ws);

    for (let i = 0; i < 3; i++) {
      bridge.handleResult({ id: commands[i].id, success: true, data: "ok" });
    }

    bridge.handleResult({ id: commands[3].id, success: false, data: null, error: "Not found" });

    await Promise.all(promises);

    const metrics = bridge.getMetrics();

    expect(metrics.successRate).toBeGreaterThan(0);
    expect(metrics.successRate).toBeLessThan(1);
  });

  test("tracks per-method statistics", async () => {
    const promise1 = bridge.execute("CreateInstance", { className: "Part" });
    const promise2 = bridge.execute("GetProperty", { path: "game.Workspace", property: "Name" });
    const promise3 = bridge.execute("CreateInstance", { className: "Model" });

    const commands = getCommands(ws);

    for (const cmd of commands) {
      bridge.handleResult({ id: cmd.id, success: true, data: "ok" });
    }

    await Promise.all([promise1, promise2, promise3]);

    const metrics = bridge.getMetrics();

    expect(metrics.methodStats).toBeDefined();
    expect(metrics.methodStats.CreateInstance).toBeDefined();
    expect(metrics.methodStats.GetProperty).toBeDefined();

    expect(metrics.methodStats.CreateInstance.count).toBeGreaterThanOrEqual(2);
    expect(metrics.methodStats.GetProperty.count).toBeGreaterThanOrEqual(1);
  });

  test("includes recent commands in metrics", async () => {
    const promise = bridge.execute("SetProperty", {
      path: "game.Workspace.Part",
      property: "Transparency",
      value: 0.5,
    });

    const commands = getCommands(ws);
    bridge.handleResult({ id: commands[0].id, success: true, data: null });

    await promise;

    const metrics = bridge.getMetrics();

    expect(metrics.recentCommands).toBeArray();
    expect(metrics.recentCommands.length).toBeGreaterThan(0);

    const recentCommand = metrics.recentCommands.find((c) => c.method === "SetProperty");
    expect(recentCommand).toBeDefined();
    expect(recentCommand?.success).toBe(true);
  });

  test("calculates average duration", async () => {
    const promise = bridge.execute("CreateInstance", { className: "Part" });
    const commands = getCommands(ws);

    await new Promise((resolve) => setTimeout(resolve, 10));

    bridge.handleResult({ id: commands[0].id, success: true, data: "ok" });
    await promise;

    const metrics = bridge.getMetrics();

    expect(metrics.averageDuration).toBeGreaterThan(0);
    expect(metrics.averageDuration).toBeTypeOf("number");
  });
});
