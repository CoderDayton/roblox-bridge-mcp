import { describe, test, expect, beforeEach } from "bun:test";
import { bridge } from "../../utils/bridge";

describe("RobloxBridge - Long Polling", () => {
  beforeEach(() => {
    // Clear any pending commands and reset state between tests
    (bridge as { resetForTesting?: () => void }).resetForTesting?.();
    bridge.getPendingCommands();
  });

  test("longPoll returns empty array on timeout", async () => {
    // Clear queue first
    bridge.getPendingCommands();

    // This should timeout after 25 seconds and return empty array
    // We use a shorter wait for testing (25s is production timeout)
    const startTime = Date.now();
    const commands = await bridge.longPoll();
    const duration = Date.now() - startTime;

    expect(commands).toEqual([]);
    expect(duration).toBeGreaterThanOrEqual(24000); // ~25s with tolerance
  }, 30000);

  test("longPoll returns immediately if commands are queued", async () => {
    // Clear queue first
    bridge.getPendingCommands();

    // Queue a command first
    const promise = bridge.execute("CreateInstance", { className: "Part" });

    // Long poll should return immediately with the queued command
    const startTime = Date.now();
    const commands = await bridge.longPoll();
    const duration = Date.now() - startTime;

    expect(commands).toHaveLength(1);
    expect(commands[0].method).toBe("CreateInstance");
    expect(duration).toBeLessThan(100); // Should be immediate

    // Clean up
    bridge.handleResult({ id: commands[0].id, success: true, data: "ok" });
    await promise;
  }, 3000);

  test("longPoll resolves when command arrives during wait", async () => {
    // Clear queue first
    bridge.getPendingCommands();

    // Start long poll with no commands
    const longPollPromise = bridge.longPoll();

    // Add command after 100ms
    await new Promise((resolve) => setTimeout(resolve, 100));
    const executePromise = bridge.execute("GetProperty", {
      path: "game.Workspace",
      property: "Name",
    });

    // Long poll should resolve with the new command
    const commands = await longPollPromise;
    expect(commands).toHaveLength(1);
    expect(commands[0].method).toBe("GetProperty");

    // Clean up
    bridge.handleResult({ id: commands[0].id, success: true, data: "Workspace" });
    await executePromise;
  }, 3000);

  test("multiple longPolls can wait concurrently", async () => {
    // Clear queue first
    bridge.getPendingCommands();

    const poll1 = bridge.longPoll();
    const poll2 = bridge.longPoll();

    // Add command after 50ms
    await new Promise((resolve) => setTimeout(resolve, 50));
    const promise = bridge.execute("CreateInstance", { className: "Part" });

    // Both polls should resolve with the same commands
    const [commands1, commands2] = await Promise.all([poll1, poll2]);

    expect(commands1).toHaveLength(1);
    expect(commands2).toHaveLength(1);
    expect(commands1[0].id).toBe(commands2[0].id);

    // Clean up
    bridge.handleResult({ id: commands1[0].id, success: true, data: "ok" });
    await promise;
  }, 3000);
});
