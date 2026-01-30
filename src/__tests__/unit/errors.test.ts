import { describe, test, expect } from "bun:test";
import {
  RobloxTimeoutError,
  InstanceNotFoundError,
  InvalidParameterError,
  RobloxExecutionError,
  BridgeConnectionError,
} from "../../utils/errors";

describe("RobloxTimeoutError", () => {
  test("has default message when no arguments provided", () => {
    const error = new RobloxTimeoutError();
    expect(error.message).toContain("timed out");
    expect(error.message).toContain("plugin is installed");
    expect(error.name).toBe("RobloxTimeoutError");
  });

  test("accepts custom message", () => {
    const error = new RobloxTimeoutError("Custom timeout message");
    expect(error.message).toBe("Custom timeout message");
  });

  test("preserves method property", () => {
    const error = new RobloxTimeoutError("Timeout", "CreateInstance");
    expect(error.method).toBe("CreateInstance");
    expect(error.attempt).toBeUndefined();
  });

  test("preserves method and attempt properties", () => {
    const error = new RobloxTimeoutError("Timeout on retry", "SetProperty", 3);
    expect(error.method).toBe("SetProperty");
    expect(error.attempt).toBe(3);
  });

  test("is instanceof Error", () => {
    const error = new RobloxTimeoutError();
    expect(error).toBeInstanceOf(Error);
    expect(error).toBeInstanceOf(RobloxTimeoutError);
  });

  test("method and attempt are readonly", () => {
    const error = new RobloxTimeoutError("msg", "GetChildren", 2);
    // TypeScript enforces readonly, but verify values are accessible
    expect(error.method).toBe("GetChildren");
    expect(error.attempt).toBe(2);
  });
});

describe("InstanceNotFoundError", () => {
  test("formats message with path", () => {
    const error = new InstanceNotFoundError("game.Workspace.NonExistent");
    expect(error.message).toBe("Instance not found at path: game.Workspace.NonExistent");
    expect(error.name).toBe("InstanceNotFoundError");
  });

  test("handles empty path", () => {
    const error = new InstanceNotFoundError("");
    expect(error.message).toBe("Instance not found at path: ");
  });

  test("handles path with special characters", () => {
    const error = new InstanceNotFoundError("game.Workspace.Part[1]");
    expect(error.message).toContain("Part[1]");
  });

  test("is instanceof Error", () => {
    const error = new InstanceNotFoundError("any.path");
    expect(error).toBeInstanceOf(Error);
    expect(error).toBeInstanceOf(InstanceNotFoundError);
  });
});

describe("InvalidParameterError", () => {
  test("requires message argument", () => {
    const error = new InvalidParameterError("Invalid type for position");
    expect(error.message).toBe("Invalid type for position");
    expect(error.name).toBe("InvalidParameterError");
    expect(error.method).toBeUndefined();
  });

  test("preserves method property", () => {
    const error = new InvalidParameterError("Expected number, got string", "SetPosition");
    expect(error.message).toBe("Expected number, got string");
    expect(error.method).toBe("SetPosition");
  });

  test("is instanceof Error", () => {
    const error = new InvalidParameterError("error");
    expect(error).toBeInstanceOf(Error);
    expect(error).toBeInstanceOf(InvalidParameterError);
  });

  test("method is readonly", () => {
    const error = new InvalidParameterError("error", "GetProperty");
    expect(error.method).toBe("GetProperty");
  });
});

describe("RobloxExecutionError", () => {
  test("requires message argument", () => {
    const error = new RobloxExecutionError("Script execution failed");
    expect(error.message).toBe("Script execution failed");
    expect(error.name).toBe("RobloxExecutionError");
    expect(error.method).toBeUndefined();
    expect(error.params).toBeUndefined();
  });

  test("preserves method property", () => {
    const error = new RobloxExecutionError("Cannot set property", "SetProperty");
    expect(error.method).toBe("SetProperty");
    expect(error.params).toBeUndefined();
  });

  test("preserves method and params properties", () => {
    const params = { path: "game.Workspace.Part", property: "Size", value: 10 };
    const error = new RobloxExecutionError("Property is read-only", "SetProperty", params);
    expect(error.method).toBe("SetProperty");
    expect(error.params).toEqual(params);
    expect(error.params?.path).toBe("game.Workspace.Part");
  });

  test("is instanceof Error", () => {
    const error = new RobloxExecutionError("error");
    expect(error).toBeInstanceOf(Error);
    expect(error).toBeInstanceOf(RobloxExecutionError);
  });

  test("params handles complex objects", () => {
    const params = {
      nested: { deep: { value: 123 } },
      array: [1, 2, 3],
      nullValue: null,
    };
    const error = new RobloxExecutionError("Complex params", "TestMethod", params);
    expect(error.params).toEqual(params);
  });
});

describe("BridgeConnectionError", () => {
  test("has default message when no argument provided", () => {
    const error = new BridgeConnectionError();
    expect(error.message).toContain("Cannot connect");
    expect(error.message).toContain("bridge");
    expect(error.name).toBe("BridgeConnectionError");
  });

  test("accepts custom message", () => {
    const error = new BridgeConnectionError("Port 3000 refused connection");
    expect(error.message).toBe("Port 3000 refused connection");
  });

  test("is instanceof Error", () => {
    const error = new BridgeConnectionError();
    expect(error).toBeInstanceOf(Error);
    expect(error).toBeInstanceOf(BridgeConnectionError);
  });
});

describe("Error discrimination", () => {
  test("errors can be distinguished by name property", () => {
    const errors = [
      new RobloxTimeoutError(),
      new InstanceNotFoundError("path"),
      new InvalidParameterError("msg"),
      new RobloxExecutionError("msg"),
      new BridgeConnectionError(),
    ];

    const names = errors.map((e) => e.name);
    expect(names).toEqual([
      "RobloxTimeoutError",
      "InstanceNotFoundError",
      "InvalidParameterError",
      "RobloxExecutionError",
      "BridgeConnectionError",
    ]);
  });

  test("errors can be distinguished by instanceof", () => {
    const error: Error = new RobloxTimeoutError();

    expect(error instanceof RobloxTimeoutError).toBe(true);
    expect(error instanceof InstanceNotFoundError).toBe(false);
    expect(error instanceof InvalidParameterError).toBe(false);
    expect(error instanceof RobloxExecutionError).toBe(false);
    expect(error instanceof BridgeConnectionError).toBe(false);
  });

  test("all errors extend Error base class", () => {
    const errors = [
      new RobloxTimeoutError(),
      new InstanceNotFoundError("path"),
      new InvalidParameterError("msg"),
      new RobloxExecutionError("msg"),
      new BridgeConnectionError(),
    ];

    for (const error of errors) {
      expect(error instanceof Error).toBe(true);
      expect(error.stack).toBeDefined();
    }
  });
});
