#!/usr/bin/env node
import { FastMCP } from "fastmcp";
import { startBridgeServer } from "./utils/bridge";
import { registerAllTools } from "./tools";

const server = new FastMCP({
  name: "roblox-bridge-mcp",
  version: "1.0.0",
});

// Register all Roblox tools
registerAllTools(server);

// Start the HTTP bridge for Roblox plugin communication
startBridgeServer();

// Start MCP server (stdio transport for Claude Desktop / local agents)
server.start({
  transportType: "stdio",
});
