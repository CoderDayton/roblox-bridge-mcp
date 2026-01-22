#!/usr/bin/env node
import { FastMCP } from "fastmcp";
import { startBridgeServer } from "./utils/bridge";
import { registerAllTools, registerResources } from "./tools";
import { logger } from "./utils/logger";

const server = new FastMCP({
  name: "roblox-bridge-mcp",
  version: "1.0.0",
});

// Register all Roblox tools and resources
registerAllTools(server);
registerResources(server);
logger.server.info("Registered all Roblox tools and resources");

// Start the HTTP bridge for Roblox plugin communication (non-blocking)
// The MCP server will start regardless of bridge success
startBridgeServer();

// Start MCP server (stdio transport for Claude Desktop / local agents)
logger.server.info("Starting MCP server", { transport: "stdio" });
void server.start({
  transportType: "stdio",
});
