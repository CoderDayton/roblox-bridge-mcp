import { describe, test, expect, beforeAll, afterAll } from "bun:test";
import type { Server } from "bun";

// Helper to find an available port in test range
async function findAvailablePort(startPort: number, maxAttempts: number = 10): Promise<number> {
  for (let i = 0; i < maxAttempts; i++) {
    const port = startPort + i;
    try {
      const testServer = Bun.serve({
        port,
        fetch() {
          return new Response("test");
        },
      });
      void testServer.stop();
      return port;
    } catch {
      continue;
    }
  }
  throw new Error(`No available ports found in range ${startPort}-${startPort + maxAttempts - 1}`);
}

describe("HTTP Bridge Integration", () => {
  let mockServer: Server<unknown> | undefined;
  let TEST_PORT: number;

  beforeAll(async () => {
    // Find available port in test range (30000+)
    TEST_PORT = await findAvailablePort(30000);

    // Start a mock HTTP bridge server
    mockServer = Bun.serve({
      port: TEST_PORT,
      fetch(req) {
        const url = new URL(req.url);

        if (req.method === "GET" && url.pathname === "/poll") {
          return Response.json([
            {
              id: "test-cmd-1",
              method: "CreateInstance",
              params: { className: "Part", parentPath: "game.Workspace" },
            },
          ]);
        }

        if (req.method === "POST" && url.pathname === "/result") {
          return req.json().then((result) => {
            return Response.json({ status: "ok", received: result });
          });
        }

        return new Response("Not Found", { status: 404 });
      },
    });
  });

  afterAll(() => {
    if (mockServer) {
      void mockServer.stop();
    }
  });

  test("GET /poll returns commands", async () => {
    const response = await fetch(`http://localhost:${TEST_PORT}/poll`);
    expect(response.status).toBe(200);

    const commands = await response.json();
    expect(Array.isArray(commands)).toBe(true);
    expect(commands[0]).toHaveProperty("id");
    expect(commands[0]).toHaveProperty("method");
    expect(commands[0]).toHaveProperty("params");
  });

  test("POST /result accepts results", async () => {
    const result = {
      id: "test-cmd-1",
      success: true,
      data: "game.Workspace.Part",
    };

    const response = await fetch(`http://localhost:${TEST_PORT}/result`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(result),
    });

    expect(response.status).toBe(200);
    const json = await response.json();
    expect(json.status).toBe("ok");
    expect(json.received).toEqual(result);
  });

  test("returns 404 for unknown routes", async () => {
    const response = await fetch(`http://localhost:${TEST_PORT}/unknown`);
    expect(response.status).toBe(404);
  });

  test("command and result roundtrip", async () => {
    // Simulate plugin polling
    const pollResponse = await fetch(`http://localhost:${TEST_PORT}/poll`);
    const commands = await pollResponse.json();
    const command = commands[0];

    // Simulate plugin executing and sending result
    const result = {
      id: command.id,
      success: true,
      data: `${command.params.parentPath}.${command.params.className}`,
    };

    const resultResponse = await fetch(`http://localhost:${TEST_PORT}/result`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(result),
    });

    expect(resultResponse.status).toBe(200);

    const resultJson = await resultResponse.json();
    expect(resultJson.received.id).toBe(command.id);
    expect(resultJson.received.success).toBe(true);
  });
});

describe("Error Handling", () => {
  test("handles malformed JSON in result", async () => {
    // Find available port for this isolated test
    const errorTestPort = await findAvailablePort(30100);

    const mockServer = Bun.serve({
      port: errorTestPort,
      fetch(req) {
        if (req.method === "POST" && new URL(req.url).pathname === "/result") {
          return req
            .text()
            .then(() => {
              return Response.json({ status: "error", message: "Invalid JSON" }, { status: 400 });
            })
            .catch(() => {
              return Response.json({ status: "error", message: "Parse failed" }, { status: 400 });
            });
        }
        return new Response("Not Found", { status: 404 });
      },
    });

    const response = await fetch(`http://localhost:${errorTestPort}/result`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: "invalid json{",
    });

    expect(response.status).toBe(400);
    await new Promise((resolve) => setTimeout(resolve, 10));
    void mockServer.stop();
  });
});
