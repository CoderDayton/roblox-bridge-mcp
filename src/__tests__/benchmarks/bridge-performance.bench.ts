/* eslint-disable @typescript-eslint/no-explicit-any, @typescript-eslint/no-unused-vars, no-console, @typescript-eslint/explicit-function-return-type, @typescript-eslint/no-unnecessary-condition */
/**
 * Performance benchmarks for bridge.ts optimizations
 * Run with: bun run src/__tests__/benchmarks/bridge-performance.bench.ts
 */

import { bridge } from "../../utils/bridge";
import type { ServerWebSocket } from "bun";

interface MockWSClientData {
  id: string;
  connectedAt: number;
  version?: string;
  ready: boolean;
}

// Create a mock WebSocket
const createMockWebSocket = (id: string): ServerWebSocket<MockWSClientData> => {
  const messages: string[] = [];
  return {
    data: { id, connectedAt: Date.now(), ready: false },
    send: (msg: string) => messages.push(msg),
    close: () => {},
    readyState: 1,
    remoteAddress: "127.0.0.1",
    binaryType: "nodebuffer" as const,
    subscribe: () => {},
    unsubscribe: () => {},
    publish: () => 0,
    publishText: () => 0,
    publishBinary: () => 0,
    isSubscribed: () => false,
    cork: () => {},
    ping: () => {},
    pong: () => {},
    terminate: () => {},
    sendBinary: () => {},
    sendText: () => {},
    subscriptions: [],
    getBufferedAmount: () => 0,
  } as unknown as ServerWebSocket<MockWSClientData>;
};

// Setup: populate command history with 100 entries
function setupBridgeWithHistory() {
  (bridge as any).resetForTesting?.();
  const ws = createMockWebSocket("bench-client");
  bridge.addClient(ws);
  bridge.markClientReady(ws, "1.0.0");

  // Populate command history
  const history: any[] = [];
  for (let i = 0; i < 100; i++) {
    history.push({
      method: i % 5 === 0 ? "CreateInstance" : i % 3 === 0 ? "GetProperty" : "SetProperty",
      timestamp: Date.now() - i * 1000,
      duration: 10 + Math.random() * 50,
      success: i % 10 !== 0, // 10% failure rate
      error: i % 10 === 0 ? "Test error" : undefined,
    });
  }
  (bridge as any).commandHistory = history;

  return ws;
}

function benchmark(name: string, fn: () => void, iterations = 10000): number {
  // Warmup
  for (let i = 0; i < 100; i++) fn();

  const start = performance.now();
  for (let i = 0; i < iterations; i++) {
    fn();
  }
  const end = performance.now();
  const totalMs = end - start;
  const avgUs = (totalMs / iterations) * 1000;

  console.log(`${name}: ${totalMs.toFixed(2)}ms total, ${avgUs.toFixed(3)}μs avg`);
  return totalMs;
}

console.log("=== Bridge Performance Benchmarks ===\n");

console.log("--- getMetrics() with 100 history entries ---");
{
  const ws = setupBridgeWithHistory();
  benchmark("getMetrics - baseline", () => bridge.getMetrics(), 10000);
  bridge.removeClient(ws);
}

console.log("\n--- ID generation (1000 iterations) ---");
{
  benchmark(
    "crypto.randomUUID().slice(0, 8)",
    () => {
      crypto.randomUUID().slice(0, 8);
    },
    1000
  );

  benchmark(
    "crypto.randomUUID().substring(0, 8)",
    () => {
      crypto.randomUUID().substring(0, 8);
    },
    1000
  );

  benchmark(
    "performance.now() + random",
    () => {
      Math.floor(performance.now() * 1000 + Math.random() * 1000000).toString(36);
    },
    1000
  );
}

console.log("\n--- Command array handling ---");
{
  benchmark(
    "Array spread copy",
    () => {
      const queue = Array(10)
        .fill(null)
        .map((_, i) => ({ id: `${i}`, method: "test", params: {} }));
      const copy = [...queue];
    },
    10000
  );

  benchmark(
    "Array reference swap",
    () => {
      const queue = Array(10)
        .fill(null)
        .map((_, i) => ({ id: `${i}`, method: "test", params: {} }));
      const ref = queue;
    },
    10000
  );
}

console.log("\n--- JSON message creation (1000 iterations) ---");
{
  benchmark(
    "JSON.stringify for common messages",
    () => {
      JSON.stringify({ type: "pong", timestamp: Date.now() });
      JSON.stringify({ type: "ack", id: "test-id-123" });
      JSON.stringify({ type: "error", message: "Invalid JSON" });
    },
    1000
  );

  benchmark(
    "Template literals (static parts)",
    () => {
      const timestamp = Date.now();
      `{"type":"pong","timestamp":${timestamp}}`;
      const id = "test-id-123";
      `{"type":"ack","id":"${id}"}`;
      ('{"type":"error","message":"Invalid JSON"}');
    },
    1000
  );
}

console.log("\n--- calculateMethodStats() approaches ---");
{
  const ws = setupBridgeWithHistory();
  const history = (bridge as any).commandHistory;

  benchmark(
    "Map + Object.fromEntries",
    () => {
      const stats = new Map<string, { count: number; avgDuration: number; failures: number }>();
      for (const cmd of history) {
        const existing = stats.get(cmd.method) ?? { count: 0, avgDuration: 0, failures: 0 };
        existing.avgDuration =
          (existing.avgDuration * existing.count + cmd.duration) / (existing.count + 1);
        existing.count++;
        if (!cmd.success) existing.failures++;
        stats.set(cmd.method, existing);
      }
      Object.fromEntries(stats);
    },
    1000
  );

  benchmark(
    "Direct object building",
    () => {
      const stats: Record<string, { count: number; avgDuration: number; failures: number }> = {};
      for (const cmd of history) {
        const existing = stats[cmd.method] ?? { count: 0, avgDuration: 0, failures: 0 };
        existing.avgDuration =
          (existing.avgDuration * existing.count + cmd.duration) / (existing.count + 1);
        existing.count++;
        if (!cmd.success) existing.failures++;
        stats[cmd.method] = existing;
      }
    },
    1000
  );

  bridge.removeClient(ws);
}

console.log("\n--- getMetrics filter+reduce vs single loop ---");
{
  const ws = setupBridgeWithHistory();
  const history = (bridge as any).commandHistory;

  benchmark(
    "filter + reduce (current)",
    () => {
      const total = history.length;
      const successes = history.filter((c: any) => c.success).length;
      const avgDuration =
        total > 0 ? history.reduce((sum: number, c: any) => sum + c.duration, 0) / total : 0;
    },
    10000
  );

  benchmark(
    "single for-loop (optimized)",
    () => {
      const total = history.length;
      let successes = 0;
      let totalDuration = 0;

      for (const cmd of history) {
        if (cmd.success) successes++;
        totalDuration += cmd.duration;
      }

      const avgDuration = total > 0 ? totalDuration / total : 0;
    },
    10000
  );

  bridge.removeClient(ws);
}

console.log("\n=== Benchmarks Complete ===");
