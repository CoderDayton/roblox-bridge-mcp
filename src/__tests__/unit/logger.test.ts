import { describe, test, expect, mock, beforeEach, afterEach } from "bun:test";
import { LogLevel, createLogger, _Logger } from "../../utils/logger";

describe("Logger", () => {
  let originalError: typeof console.error;
  let originalWarn: typeof console.warn;
  let errorLogs: string[];
  let warnLogs: string[];

  beforeEach(() => {
    errorLogs = [];
    warnLogs = [];
    originalError = console.error;
    originalWarn = console.warn;
    console.error = mock((...args: unknown[]) => {
      errorLogs.push(args.join(" "));
    });
    console.warn = mock((...args: unknown[]) => {
      warnLogs.push(args.join(" "));
    });
  });

  afterEach(() => {
    console.error = originalError;
    console.warn = originalWarn;
  });

  describe("createLogger", () => {
    test("creates logger with prefix", () => {
      const logger = createLogger("TestPrefix");
      logger.info("test message");

      expect(errorLogs.length).toBe(1);
      expect(errorLogs[0]).toContain("[TestPrefix]");
      expect(errorLogs[0]).toContain("test message");
    });
  });

  describe("debug level", () => {
    test("debug logs when level is DEBUG", () => {
      // Create a logger directly with DEBUG level to test the debug method
      const logger = new _Logger("Debug", LogLevel.DEBUG);
      logger.debug("debug message");

      expect(errorLogs.length).toBe(1);
      expect(errorLogs[0]).toContain("[DEBUG]");
      expect(errorLogs[0]).toContain("[Debug]");
      expect(errorLogs[0]).toContain("debug message");
    });

    test("debug logs with context when level is DEBUG", () => {
      const logger = new _Logger("DebugCtx", LogLevel.DEBUG);
      logger.debug("context debug", { data: "test" });

      expect(errorLogs.length).toBe(1);
      expect(errorLogs[0]).toContain('{"data":"test"}');
    });

    test("debug is filtered when level is INFO", () => {
      const logger = new _Logger("InfoLevel", LogLevel.INFO);
      logger.debug("should not appear");

      expect(errorLogs.length).toBe(0);
    });

    test("info logs message with timestamp and prefix", () => {
      const logger = createLogger("Info");
      logger.info("test info");

      expect(errorLogs.length).toBe(1);
      expect(errorLogs[0]).toMatch(/\[\d{4}-\d{2}-\d{2}T/);
      expect(errorLogs[0]).toContain("[INFO]");
      expect(errorLogs[0]).toContain("[Info]");
      expect(errorLogs[0]).toContain("test info");
    });

    test("info logs with context", () => {
      const logger = createLogger("InfoCtx");
      logger.info("test", { key: "value" });

      expect(errorLogs[0]).toContain('{"key":"value"}');
    });
  });

  describe("warn level", () => {
    test("warn logs to console.warn", () => {
      const logger = createLogger("Warn");
      logger.warn("warning message");

      expect(warnLogs.length).toBe(1);
      expect(warnLogs[0]).toContain("[WARN]");
      expect(warnLogs[0]).toContain("warning message");
    });

    test("warn logs with context", () => {
      const logger = createLogger("WarnCtx");
      logger.warn("warning", { count: 42 });

      expect(warnLogs[0]).toContain('{"count":42}');
    });
  });

  describe("error level", () => {
    test("error logs message", () => {
      const logger = createLogger("Error");
      logger.error("error occurred");

      expect(errorLogs.length).toBe(1);
      expect(errorLogs[0]).toContain("[ERROR]");
      expect(errorLogs[0]).toContain("error occurred");
    });

    test("error logs with Error object", () => {
      const logger = createLogger("ErrorObj");
      const err = new Error("test error");
      logger.error("failed", err);

      expect(errorLogs[0]).toContain("test error");
      expect(errorLogs[0]).toContain("stack");
    });

    test("error logs with Error and context", () => {
      const logger = createLogger("ErrorCtx");
      const err = new Error("ctx error");
      logger.error("failed", err, { operation: "test" });

      expect(errorLogs[0]).toContain('"operation":"test"');
      expect(errorLogs[0]).toContain("ctx error");
    });
  });

  describe("LogLevel enum", () => {
    test("LogLevel values are ordered", () => {
      expect(LogLevel.DEBUG).toBeLessThan(LogLevel.INFO);
      expect(LogLevel.INFO).toBeLessThan(LogLevel.WARN);
      expect(LogLevel.WARN).toBeLessThan(LogLevel.ERROR);
    });
  });
});
