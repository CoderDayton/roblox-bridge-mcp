/**
 * Structured logging system for roblox-bridge-mcp
 */

export enum LogLevel {
  DEBUG = 0,
  INFO = 1,
  WARN = 2,
  ERROR = 3,
}

interface LogContext {
  [key: string]: unknown;
}

class Logger {
  private level: LogLevel;
  private prefix: string;

  constructor(prefix: string, level: LogLevel = LogLevel.INFO) {
    this.prefix = prefix;
    this.level = level;
  }

  private shouldLog(level: LogLevel): boolean {
    return level >= this.level;
  }

  private formatMessage(level: string, message: string, context?: LogContext): string {
    const timestamp = new Date().toISOString();
    const contextStr = context ? ` ${JSON.stringify(context)}` : "";
    return `[${timestamp}] [${level}] [${this.prefix}] ${message}${contextStr}`;
  }

  debug(message: string, context?: LogContext): void {
    if (!this.shouldLog(LogLevel.DEBUG)) return;
    // Use stderr for all logs to avoid interfering with MCP JSON protocol on stdout
    console.error(this.formatMessage("DEBUG", message, context));
  }

  info(message: string, context?: LogContext): void {
    if (!this.shouldLog(LogLevel.INFO)) return;
    // Use stderr for all logs to avoid interfering with MCP JSON protocol on stdout
    console.error(this.formatMessage("INFO", message, context));
  }

  warn(message: string, context?: LogContext): void {
    if (!this.shouldLog(LogLevel.WARN)) return;
    console.warn(this.formatMessage("WARN", message, context));
  }

  error(message: string, error?: Error, context?: LogContext): void {
    if (!this.shouldLog(LogLevel.ERROR)) return;

    const errorContext = error ? { ...context, error: error.message, stack: error.stack } : context;
    console.error(this.formatMessage("ERROR", message, errorContext));
  }
}

// Parse log level from environment variable
function parseLogLevel(value: string | undefined): LogLevel {
  if (!value) return LogLevel.INFO;

  const normalized = value.toUpperCase();
  switch (normalized) {
    case "DEBUG":
      return LogLevel.DEBUG;
    case "INFO":
      return LogLevel.INFO;
    case "WARN":
      return LogLevel.WARN;
    case "ERROR":
      return LogLevel.ERROR;
    default:
      return LogLevel.INFO;
  }
}

// Global log level configuration
const globalLogLevel = parseLogLevel(process.env.LOG_LEVEL);

// Factory function to create loggers
export function createLogger(prefix: string): Logger {
  return new Logger(prefix, globalLogLevel);
}

// Pre-configured loggers
export const logger = {
  bridge: createLogger("Bridge"),
  tools: createLogger("Tools"),
  server: createLogger("Server"),
};
