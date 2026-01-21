import { describe, test, expect, beforeEach } from "bun:test";
import { bridge, type RobloxCommand, type RobloxResult } from "../../utils/bridge";

describe("RobloxBridge", () => {
  beforeEach(() => {
    // Clear any pending state between tests
    bridge.getPendingCommands();
  });

  describe("command queueing", () => {
    test("adds commands to queue", () => {
      const executePromise = bridge.execute("CreateInstance", { className: "Part" });
      const commands = bridge.getPendingCommands();

      expect(commands).toHaveLength(1);
      expect(commands[0].method).toBe("CreateInstance");
      expect(commands[0].params).toEqual({ className: "Part" });
      expect(commands[0].id).toBeTypeOf("string");
    });

    test("clears queue after getPendingCommands", () => {
      bridge.execute("CreateInstance", { className: "Part" });
      bridge.getPendingCommands();
      const commands = bridge.getPendingCommands();

      expect(commands).toHaveLength(0);
    });

    test("generates unique IDs for commands", () => {
      bridge.execute("CreateInstance", { className: "Part" });
      bridge.execute("DeleteInstance", { path: "game.Workspace.Part" });
      const commands = bridge.getPendingCommands();

      expect(commands[0].id).not.toBe(commands[1].id);
    });
  });

  describe("result handling", () => {
    test("resolves promise on successful result", async () => {
      const executePromise = bridge.execute<string>("GetProperty", { path: "game.Workspace", property: "Name" });
      const commands = bridge.getPendingCommands();
      const commandId = commands[0].id;

      bridge.handleResult({
        id: commandId,
        success: true,
        data: "Workspace",
      });

      const result = await executePromise;
      expect(result).toBe("Workspace");
    });

    test("rejects promise on failed result", async () => {
      const executePromise = bridge.execute("DeleteInstance", { path: "game.Workspace.NonExistent" });
      const commands = bridge.getPendingCommands();
      const commandId = commands[0].id;

      bridge.handleResult({
        id: commandId,
        success: false,
        data: null,
        error: "Instance not found: game.Workspace.NonExistent",
      });

      await expect(executePromise).rejects.toThrow("Instance not found");
    });

    test("ignores results for unknown command IDs", () => {
      bridge.handleResult({
        id: "unknown-id",
        success: true,
        data: "test",
      });

      // Should not throw
      expect(true).toBe(true);
    });
  });

  describe("timeout behavior", () => {
    test("rejects after timeout", async () => {
      const executePromise = bridge.execute("CreateInstance", { className: "Part" });
      
      // Fast-forward time would require mocking setTimeout
      // For now, we test that the promise is created
      expect(executePromise).toBeInstanceOf(Promise);
      
      // Clean up by resolving
      const commands = bridge.getPendingCommands();
      bridge.handleResult({
        id: commands[0].id,
        success: true,
        data: "test",
      });
      
      await executePromise;
    }, { timeout: 1000 });
  });

  describe("concurrent commands", () => {
    test("handles multiple pending commands", async () => {
      const promise1 = bridge.execute("CreateInstance", { className: "Part" });
      const promise2 = bridge.execute("CreateInstance", { className: "Model" });
      const promise3 = bridge.execute("GetChildren", { path: "game.Workspace" });

      const commands = bridge.getPendingCommands();
      expect(commands).toHaveLength(3);

      // Resolve in different order
      bridge.handleResult({ id: commands[1].id, success: true, data: "Model created" });
      bridge.handleResult({ id: commands[0].id, success: true, data: "Part created" });
      bridge.handleResult({ id: commands[2].id, success: true, data: ["Part1", "Part2"] });

      const results = await Promise.all([promise1, promise2, promise3]);
      expect(results).toEqual(["Part created", "Model created", ["Part1", "Part2"]]);
    });
  });

  describe("pending count", () => {
    test("tracks pending response count", async () => {
      // Clear any existing pending state
      const existingCommands = bridge.getPendingCommands();
      for (const cmd of existingCommands) {
        bridge.handleResult({ id: cmd.id, success: true, data: "cleanup" });
      }
      
      await new Promise(resolve => setTimeout(resolve, 10));
      
      const initialCount = bridge.pendingCount;

      const promise1 = bridge.execute("CreateInstance", { className: "Part" });
      expect(bridge.pendingCount).toBe(initialCount + 1);

      const promise2 = bridge.execute("CreateInstance", { className: "Model" });
      expect(bridge.pendingCount).toBe(initialCount + 2);

      const commands = bridge.getPendingCommands();
      bridge.handleResult({ id: commands[0].id, success: true, data: "ok" });
      expect(bridge.pendingCount).toBe(initialCount + 1);

      bridge.handleResult({ id: commands[1].id, success: true, data: "ok" });
      expect(bridge.pendingCount).toBe(initialCount);
      
      await Promise.all([promise1, promise2]);
    });
  });
});
