import { describe, test, expect, mock, beforeEach } from "bun:test";
import { registerAllTools } from "../../tools/roblox-tools";
import { bridge } from "../../utils/bridge";
import { InvalidParameterError } from "../../utils/errors";
import type { FastMCP } from "fastmcp";
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

describe("roblox-tools", () => {
  let mockServer: Partial<FastMCP>;
  let addedTool: {
    name: string;
    description: string;
    parameters: unknown;
    execute: (args: { method: string; params: Record<string, unknown> }) => Promise<string>;
  } | null;
  let ws: ServerWebSocket<MockWSClientData>;

  beforeEach(() => {
    addedTool = null;
    mockServer = {
      // eslint-disable-next-line @typescript-eslint/no-explicit-any
      addTool: mock((tool: any) => {
        addedTool = tool;
      }),
    };
    (bridge as { resetForTesting?: () => void }).resetForTesting?.();
    ws = createMockWebSocket("test-client");
    bridge.addClient(ws);
    bridge.markClientReady(ws, "1.0.0");
  });

  describe("registerAllTools", () => {
    test("adds roblox tool to server", () => {
      registerAllTools(mockServer as FastMCP);

      expect(addedTool).not.toBeNull();
      expect(addedTool!.name).toBe("roblox");
    });

    test("tool description mentions 205 methods", () => {
      registerAllTools(mockServer as FastMCP);

      expect(addedTool!.description).toContain("205 methods");
    });

    test("tool has zod parameters schema", () => {
      registerAllTools(mockServer as FastMCP);

      expect(addedTool!.parameters).toBeDefined();
    });

    test("calls addTool exactly once", () => {
      registerAllTools(mockServer as FastMCP);

      expect(mockServer.addTool).toHaveBeenCalledTimes(1);
    });
  });

  describe("RunConsoleCommand validation", () => {
    test("rejects empty code parameter", async () => {
      registerAllTools(mockServer as FastMCP);

      await expect(addedTool!.execute({ method: "RunConsoleCommand", params: {} })).rejects.toThrow(
        "requires a non-empty 'code' parameter"
      );
    });

    test("rejects missing code parameter", async () => {
      registerAllTools(mockServer as FastMCP);

      await expect(
        addedTool!.execute({ method: "RunConsoleCommand", params: { other: "value" } })
      ).rejects.toThrow("requires a non-empty 'code' parameter");
    });

    test("rejects whitespace-only code", async () => {
      registerAllTools(mockServer as FastMCP);

      await expect(
        addedTool!.execute({ method: "RunConsoleCommand", params: { code: "   " } })
      ).rejects.toThrow("requires a non-empty 'code' parameter");
    });

    test("rejects code exceeding 65536 characters", async () => {
      registerAllTools(mockServer as FastMCP);

      const longCode = "x".repeat(70000);
      await expect(
        addedTool!.execute({ method: "RunConsoleCommand", params: { code: longCode } })
      ).rejects.toThrow("exceeds maximum length");
    });

    test("accepts valid code at max length boundary", async () => {
      registerAllTools(mockServer as FastMCP);

      const maxCode = "x".repeat(65536);
      const executePromise = addedTool!.execute({
        method: "RunConsoleCommand",
        params: { code: maxCode },
      });

      const commands = getCommands(ws);
      expect(commands).toHaveLength(1);
      expect(commands[0].method).toBe("RunConsoleCommand");

      bridge.handleResult({ id: commands[0].id, success: true, data: "executed" });
      const result = await executePromise;
      expect(result).toBe("executed");
    });

    test("throws InvalidParameterError for validation failures", async () => {
      registerAllTools(mockServer as FastMCP);

      try {
        await addedTool!.execute({ method: "RunConsoleCommand", params: {} });
        expect.unreachable("Should have thrown");
      } catch (error) {
        expect(error).toBeInstanceOf(InvalidParameterError);
        expect((error as InvalidParameterError).method).toBe("RunConsoleCommand");
      }
    });
  });

  describe("execute", () => {
    test("sends command to bridge", async () => {
      registerAllTools(mockServer as FastMCP);

      const executePromise = addedTool!.execute({
        method: "CreateInstance",
        params: { className: "Part" },
      });

      const commands = getCommands(ws);
      expect(commands).toHaveLength(1);
      expect(commands[0].method).toBe("CreateInstance");
      expect(commands[0].params).toEqual({ className: "Part" });

      bridge.handleResult({ id: commands[0].id, success: true, data: "game.Workspace.Part" });
      await executePromise;
    });

    test("returns string result directly", async () => {
      registerAllTools(mockServer as FastMCP);

      const executePromise = addedTool!.execute({
        method: "GetProperty",
        params: { path: "game.Workspace", property: "Name" },
      });

      const commands = getCommands(ws);
      bridge.handleResult({ id: commands[0].id, success: true, data: "Workspace" });

      const result = await executePromise;
      expect(result).toBe("Workspace");
    });

    test("stringifies object results", async () => {
      registerAllTools(mockServer as FastMCP);

      const executePromise = addedTool!.execute({
        method: "GetPosition",
        params: { path: "game.Workspace.Part" },
      });

      const commands = getCommands(ws);
      bridge.handleResult({
        id: commands[0].id,
        success: true,
        data: { x: 0, y: 5, z: 10 },
      });

      const result = await executePromise;
      expect(result).toBe(JSON.stringify({ x: 0, y: 5, z: 10 }, null, 2));
    });

    test("stringifies array results", async () => {
      registerAllTools(mockServer as FastMCP);

      const executePromise = addedTool!.execute({
        method: "GetChildren",
        params: { path: "game.Workspace" },
      });

      const commands = getCommands(ws);
      bridge.handleResult({
        id: commands[0].id,
        success: true,
        data: ["Part1", "Part2", "Model1"],
      });

      const result = await executePromise;
      expect(result).toBe(JSON.stringify(["Part1", "Part2", "Model1"], null, 2));
    });

    test("handles numeric results", async () => {
      registerAllTools(mockServer as FastMCP);

      const executePromise = addedTool!.execute({
        method: "GetMass",
        params: { path: "game.Workspace.Part" },
      });

      const commands = getCommands(ws);
      bridge.handleResult({ id: commands[0].id, success: true, data: 42.5 });

      const result = await executePromise;
      expect(result).toBe("42.5");
    });

    test("handles boolean results", async () => {
      registerAllTools(mockServer as FastMCP);

      const executePromise = addedTool!.execute({
        method: "IsStudio",
        params: {},
      });

      const commands = getCommands(ws);
      bridge.handleResult({ id: commands[0].id, success: true, data: true });

      const result = await executePromise;
      expect(result).toBe("true");
    });

    test("propagates bridge execution errors", async () => {
      registerAllTools(mockServer as FastMCP);

      const executePromise = addedTool!.execute({
        method: "DeleteInstance",
        params: { path: "game.Workspace.NonExistent" },
      });

      const commands = getCommands(ws);
      bridge.handleResult({
        id: commands[0].id,
        success: false,
        data: null,
        error: "Instance not found",
      });

      await expect(executePromise).rejects.toThrow("Instance not found");
    });

    test("uses default empty params object", async () => {
      registerAllTools(mockServer as FastMCP);

      const executePromise = addedTool!.execute({
        method: "GetSelection",
        params: {},
      });

      const commands = getCommands(ws);
      expect(commands[0].params).toEqual({});

      bridge.handleResult({ id: commands[0].id, success: true, data: [] });
      await executePromise;
    });
  });

  describe("method coverage", () => {
    const methodsToTest = [
      { method: "CreateInstance", params: { className: "Part" } },
      { method: "DeleteInstance", params: { path: "game.Workspace.Part" } },
      { method: "GetProperty", params: { path: "game.Workspace", property: "Name" } },
      {
        method: "SetProperty",
        params: { path: "game.Workspace.Part", property: "Name", value: "Test" },
      },
      { method: "GetChildren", params: { path: "game.Workspace" } },
      { method: "FindFirstChild", params: { path: "game.Workspace", name: "Part" } },
      { method: "MoveTo", params: { path: "game.Workspace.Part", position: [0, 10, 0] } },
      { method: "SetColor", params: { path: "game.Workspace.Part", r: 1, g: 0, b: 0 } },
      { method: "Raycast", params: { origin: [0, 50, 0], direction: [0, -100, 0] } },
      { method: "IsStudio", params: {} },
    ];

    test.each(methodsToTest)("accepts valid $method call", async ({ method, params }) => {
      registerAllTools(mockServer as FastMCP);

      const executePromise = addedTool!.execute({ method, params });
      const commands = getCommands(ws);

      expect(commands.length).toBeGreaterThanOrEqual(1);
      const lastCommand = commands[commands.length - 1];
      expect(lastCommand.method).toBe(method);

      bridge.handleResult({ id: lastCommand.id, success: true, data: "ok" });
      await executePromise;
    });
  });
});
