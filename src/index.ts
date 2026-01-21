#!/usr/bin/env node
import { FastMCP } from "fastmcp";
import { startBridgeServer } from "./utils/bridge";
import { registerAllTools } from "./tools";
import { logger } from "./utils/logger";

const server = new FastMCP({
  name: "roblox-bridge-mcp",
  version: "1.0.0",
});

// Register all Roblox tools
registerAllTools(server);
logger.server.info("Registered all Roblox tools");

// Start the HTTP bridge for Roblox plugin communication (non-blocking)
// The MCP server will start regardless of bridge success
startBridgeServer();

// Start MCP server (stdio transport for Claude Desktop / local agents)
logger.server.info("Starting MCP server", { transport: "stdio" });
server.start({
  transportType: "stdio",
});
