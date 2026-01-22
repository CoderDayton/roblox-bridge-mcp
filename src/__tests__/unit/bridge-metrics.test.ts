import { describe, test, expect, beforeEach } from "bun:test";
import { bridge } from "../../utils/bridge";

describe("RobloxBridge - Metrics", () => {
  beforeEach(async () => {
    // Reset bridge state
    (bridge as { resetForTesting?: () => void }).resetForTesting?.();

    // Clear pending commands
    bridge.getPendingCommands();

    // Give time for any async operations to settle
    await new Promise((resolve) => setTimeout(resolve, 50));
  });

  test("tracks successful command execution", async () => {
    const metricsBefore = bridge.getMetrics();

    const promise = bridge.execute("CreateInstance", { className: "Part" });
    const commands = bridge.getPendingCommands();

    bridge.handleResult({ id: commands[0].id, success: true, data: "Part created" });
    await promise;

    const metricsAfter = bridge.getMetrics();

    expect(metricsAfter.totalCommands).toBeGreaterThan(metricsBefore.totalCommands);
    expect(metricsAfter.successCount).toBeGreaterThan(metricsBefore.successCount);
  });

  test("tracks failed command execution", async () => {
    const metricsBefore = bridge.getMetrics();

    const promise = bridge.execute("DeleteInstance", { path: "game.Workspace.NonExistent" });
    const commands = bridge.getPendingCommands();

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
    // Execute 3 successful and 1 failed command
    const promises: Promise<unknown>[] = [];

    for (let i = 0; i < 3; i++) {
      const p = bridge.execute("CreateInstance", { className: "Part" });
      promises.push(p);
    }

    const failPromise = bridge.execute("DeleteInstance", { path: "NonExistent" });
    promises.push(failPromise.catch(() => {}));

    const commands = bridge.getPendingCommands();

    // Resolve first 3 as success
    for (let i = 0; i < 3; i++) {
      bridge.handleResult({ id: commands[i].id, success: true, data: "ok" });
    }

    // Resolve last as failure
    bridge.handleResult({ id: commands[3].id, success: false, data: null, error: "Not found" });

    await Promise.all(promises);

    const metrics = bridge.getMetrics();

    // Success rate should account for recent commands
    expect(metrics.successRate).toBeGreaterThan(0);
    expect(metrics.successRate).toBeLessThan(1);
  });

  test("tracks per-method statistics", async () => {
    const promise1 = bridge.execute("CreateInstance", { className: "Part" });
    const promise2 = bridge.execute("GetProperty", { path: "game.Workspace", property: "Name" });
    const promise3 = bridge.execute("CreateInstance", { className: "Model" });

    const commands = bridge.getPendingCommands();

    for (const cmd of commands) {
      bridge.handleResult({ id: cmd.id, success: true, data: "ok" });
    }

    await Promise.all([promise1, promise2, promise3]);

    const metrics = bridge.getMetrics();

    // Check method stats exist
    expect(metrics.methodStats).toBeDefined();
    expect(metrics.methodStats.CreateInstance).toBeDefined();
    expect(metrics.methodStats.GetProperty).toBeDefined();

    // CreateInstance should have count of at least 2
    expect(metrics.methodStats.CreateInstance.count).toBeGreaterThanOrEqual(2);
    expect(metrics.methodStats.GetProperty.count).toBeGreaterThanOrEqual(1);
  });

  test("includes recent commands in metrics", async () => {
    const promise = bridge.execute("SetProperty", {
      path: "game.Workspace.Part",
      property: "Transparency",
      value: 0.5,
    });

    const commands = bridge.getPendingCommands();
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
    const commands = bridge.getPendingCommands();

    // Wait a bit before resolving
    await new Promise((resolve) => setTimeout(resolve, 10));

    bridge.handleResult({ id: commands[0].id, success: true, data: "ok" });
    await promise;

    const metrics = bridge.getMetrics();

    expect(metrics.averageDuration).toBeGreaterThan(0);
    expect(metrics.averageDuration).toBeTypeOf("number");
  });
});
