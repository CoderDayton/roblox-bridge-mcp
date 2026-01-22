import { describe, test, expect } from "bun:test";
import { bridge } from "../../utils/bridge";

describe("RobloxBridge - Connection State", () => {
  test("isConnected returns false when no recent polls or WebSocket clients", async () => {
    // Wait for any previous polls to expire (10+ seconds)
    await new Promise((resolve) => setTimeout(resolve, 11000));

    const connected = bridge.isConnected();
    expect(connected).toBe(false);
  }, 15000);

  test("isConnected returns true after recent HTTP poll", () => {
    // Simulate HTTP poll
    bridge.getPendingCommands();

    const connected = bridge.isConnected();
    expect(connected).toBe(true);
  });

  test("getConnectionInfo returns accurate state", () => {
    bridge.getPendingCommands(); // Update last poll time

    const info = bridge.getConnectionInfo();

    expect(info).toHaveProperty("httpConnected");
    expect(info).toHaveProperty("wsClients");
    expect(info).toHaveProperty("lastPollTime");

    expect(info.httpConnected).toBeBoolean();
    expect(info.wsClients).toBeNumber();
    expect(info.lastPollTime).toBeNumber();
  });

  test("HTTP connection expires after 10 seconds", async () => {
    bridge.getPendingCommands(); // Update last poll time

    expect(bridge.isConnected()).toBe(true);

    // Wait 11 seconds for connection to expire
    await new Promise((resolve) => setTimeout(resolve, 11000));

    const info = bridge.getConnectionInfo();
    expect(info.httpConnected).toBe(false);
  }, 15000);

  test("pendingCount reflects active commands", async () => {
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
