#!/usr/bin/env bun
/**
 * Test script to verify bridge connection and run tools
 * Usage: bun scripts/test-bridge.ts [method] [params]
 * Example: bun scripts/test-bridge.ts GetChildren '{"path":"game.Workspace"}'
 */

const WS_URL = "ws://localhost:62847";

async function testBridge(method: string, params: Record<string, unknown> = {}) {
  const ws = new WebSocket(WS_URL);

  return new Promise((resolve, reject) => {
    const timeout = setTimeout(() => {
      ws.close();
      reject(new Error("Timeout waiting for response"));
    }, 10000);

    ws.onopen = () => {
      console.log("Connected to bridge");

      // Send handshake
      ws.send(
        JSON.stringify({
          type: "handshake",
          version: "2.0.0",
        })
      );
    };

    ws.onmessage = (event) => {
      const data = JSON.parse(event.data as string);

      if (data.type === "handshake_ok") {
        console.log("Handshake complete, sending command...\n");

        // Send the actual command
        ws.send(
          JSON.stringify({
            id: "test-1",
            method,
            params,
          })
        );
      } else if (data.id === "test-1") {
        clearTimeout(timeout);
        ws.close();

        if (data.success) {
          console.log("Success:", JSON.stringify(data.result, null, 2));
          resolve(data.result);
        } else {
          console.error("Error:", data.error);
          reject(new Error(data.error));
        }
      }
    };

    ws.onerror = (error) => {
      clearTimeout(timeout);
      reject(error);
    };

    ws.onclose = () => {
      clearTimeout(timeout);
    };
  });
}

// Parse CLI args
const method = process.argv[2] || "GetChildren";
const paramsArg = process.argv[3] || '{"path":"game.Workspace"}';

let params: Record<string, unknown>;
try {
  params = JSON.parse(paramsArg);
} catch {
  console.error("Invalid JSON params:", paramsArg);
  process.exit(1);
}

console.log(`Testing: ${method}(${JSON.stringify(params)})\n`);

testBridge(method, params)
  .then(() => process.exit(0))
  .catch((err) => {
    console.error("\nFailed:", err.message);
    process.exit(1);
  });
