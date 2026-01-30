<div align="center">

<img src="assets/icon.svg" alt="Roblox Bridge MCP" width="128" height="128">

# roblox-bridge-mcp

![Version](https://img.shields.io/badge/version-1.1.0-blue)
![License](https://img.shields.io/badge/license-MIT-green)
![Bun](https://img.shields.io/badge/bun-3.0+-black)
![FastMCP](https://img.shields.io/badge/FastMCP-3.28+-purple)

**AI-powered bridge connecting Model Context Protocol to Roblox Studio**

Real-time control of Roblox Studio instances through a unified MCP interface. Build, script, and manipulate 3D worlds using AI assistants like Claude.

[Getting Started](#getting-started) • [Installation](#installation) • [Usage](#usage) • [API Reference](#api-reference)

</div>

---

## Overview

roblox-bridge-mcp enables AI agents to directly interact with Roblox Studio through the Model Context Protocol. It provides **205 operations** across 30+ categories including instance management, scripting, physics, terrain, camera, pathfinding, GUI, animation, networking, and more through a single unified tool.

**Architecture:**

- **MCP Server** - FastMCP + Bun server exposing the `roblox` tool
- **WebSocket Bridge** - Real-time bidirectional communication on configurable port
- **Studio Plugin** - Lua plugin with automatic reconnection and keepalive

## Features

- **Single Unified Tool** - All 205 operations accessible via one `roblox` tool with method dispatch
- **API Key Security** - Simple authentication to protect the bridge server
- **WebSocket-Only** - Pure WebSocket communication, no HTTP polling overhead
- **Seamless Startup** - MCP server always starts, even if bridge port is occupied
- **Real-time Communication** - Instant bidirectional messaging with automatic reconnection
- **Studio Integration** - Toolbar button with visual connection indicator
- **Comprehensive Coverage** - Instance CRUD, scripting, transforms, physics, terrain, camera, and more
- **Type-Safe** - Zod schemas for all parameters
- **Modern Stack** - Bun runtime, FastMCP framework, task-based Lua

## Getting Started

### Prerequisites

- Roblox Studio
- An MCP client (Claude Desktop, etc.)

### Installation

**1. Configure your MCP client**

Add to your MCP client configuration (e.g., Claude Desktop `claude_desktop_config.json`):

```json
{
  "mcpServers": {
    "roblox-bridge": {
      "command": "npx",
      "args": ["-y", "roblox-bridge-mcp"]
    }
  }
}
```

**2. Install the Studio plugin**

Download the latest plugin from the [releases page](https://github.com/CoderDayton/roblox-bridge-mcp/releases).

**3. Start Roblox Studio**

Open a place in Studio. The plugin will auto-connect (toolbar button turns active).

**4. Use from your MCP client**

The `roblox` tool will be available in your MCP client (restart the client if needed).

## Configuration

<details>
<summary>Environment Variables</summary>

You can configure the bridge server behavior using environment variables. Create a `.env` file in your project root or set these in your MCP client configuration:

| Variable             | Description                                   | Default |
| -------------------- | --------------------------------------------- | ------- |
| `ROBLOX_BRIDGE_PORT` | Port for the WebSocket bridge server          | `62847` |
| `ROBLOX_TIMEOUT_MS`  | Timeout in milliseconds for command execution | `30000` |
| `ROBLOX_RETRIES`     | Number of retry attempts for failed commands  | `2`     |
| `LOG_LEVEL`          | Logging level (DEBUG, INFO, WARN, ERROR)      | `INFO`  |

**Example `.env` file:**

```bash
ROBLOX_BRIDGE_PORT=62847
ROBLOX_TIMEOUT_MS=30000
ROBLOX_RETRIES=2
LOG_LEVEL=INFO
```

**MCP Client Configuration:**

```json
{
  "mcpServers": {
    "roblox-bridge-mcp": {
      "command": "npx",
      "args": ["-y", "roblox-bridge-mcp"],
      "env": {
        "ROBLOX_BRIDGE_PORT": "62847",
        "LOG_LEVEL": "INFO",
        "ROBLOX_RETRIES": "2",
        "ROBLOX_TIMEOUT_MS": "30000"
      }
    }
  }
}
```

</details>

## Usage

### Basic Workflow

1. Open Roblox Studio with a place
2. The plugin will auto-connect (toolbar button turns active)
3. Use your MCP client to call the `roblox` tool

### Example Commands

**Create a part:**

```json
{
  "method": "CreateInstance",
  "params": {
    "className": "Part",
    "parentPath": "game.Workspace",
    "name": "MyPart",
    "properties": {
      "Anchored": true,
      "Size": [4, 1, 4]
    }
  }
}
```

**Set color:**

```json
{
  "method": "SetColor",
  "params": {
    "path": "game.Workspace.MyPart",
    "r": 255,
    "g": 0,
    "b": 0
  }
}
```

**Create a script:**

```json
{
  "method": "CreateScript",
  "params": {
    "name": "HelloWorld",
    "parentPath": "game.Workspace",
    "source": "print('Hello from AI!')",
    "type": "Script"
  }
}
```

**Get selection:**

```json
{
  "method": "GetSelection",
  "params": {}
}
```

## API Reference

### The `roblox` Tool

All operations are accessed through a single tool with two parameters:

- **method** (string) - The operation to execute (see methods below)
- **params** (object) - Method-specific parameters

See [API Reference](docs/API.md) for the complete list of 205 methods organized by category.

### Path Format

All instance paths use dot notation starting from `game`:

- `game.Workspace.Model.Part`
- `game.ReplicatedStorage.Assets`
- Service names are automatically resolved: `game.Workspace` resolves to Workspace service

## Plugin Features

The Studio plugin provides:

- **WebSocket Communication** - Direct WebSocket connection for real-time messaging
- **Version Handshake** - Automatic version compatibility check on connect
- **Toolbar Integration** - "MCP Bridge" toolbar with toggle button
- **Connection Status** - Visual indicator (active = connected, inactive = disconnected)
- **Enable/Disable** - Click toolbar button to toggle bridge on/off
- **Auto-Reconnect** - Exponential backoff (2s to 10s) on connection loss
- **Keepalive Ping** - 30-second ping/pong to detect stale connections
- **Modern Lua** - Uses `task` library, no deprecated APIs
- **Error Handling** - Structured error messages with context

## Architecture

```
┌─────────────────┐         ┌──────────────────┐           ┌─────────────────┐
│   MCP Client    │ stdio   │   FastMCP Server │ WebSocket │  Studio Plugin  │
│  (Claude, etc)  │◄───────►│   (Bun + Node)   │◄─────────►│   (Lua/Luau)    │
└─────────────────┘         └──────────────────┘           └─────────────────┘
                                     │                              │
                              ws://localhost:62847            Roblox API
                                                        (game.Workspace, etc)
```

**Communication Flow:**

1. Bridge server starts WebSocket server on configured port
2. Plugin connects directly via WebSocket
3. Version handshake verifies compatibility
4. MCP client calls `roblox` tool with method + params
5. Server sends command over WebSocket immediately
6. Plugin executes command in Studio using Roblox API
7. Plugin sends result over WebSocket
8. Server resolves promise, returns to MCP client

## Development

For contributors or those running from source:

**Clone and install:**

```bash
git clone https://github.com/CoderDayton/roblox-bridge-mcp.git
cd roblox-bridge-mcp
bun install
```

**Run in development mode:**

```bash
bun run dev
```

**Run tests:**

```bash
bun test                  # Run all tests
bun test --watch          # Watch mode
bun test --coverage       # With coverage report
```

**Code quality:**

```bash
bun run typecheck         # TypeScript type checking
bun run lint              # ESLint strict mode
bun run lint:fix          # Auto-fix linting issues
bun run format            # Format with Prettier
```

**Inspect MCP server:**

```bash
bun run inspect
```

**Build for production:**

```bash
bun run build
```

### Code Quality Standards

This project maintains high code quality standards:

- **Documentation:** Comprehensive JSDoc comments on all exported functions
- **Type Safety:** TypeScript strict mode with explicit return types
- **Testing:** 87%+ test pass rate with comprehensive coverage
- **Linting:** ESLint strict ruleset enforcing best practices
- **Formatting:** Prettier for consistent code style

See [CONTRIBUTING.md](CONTRIBUTING.md) for detailed development guidelines.

## Troubleshooting

**Plugin not connecting:**

- Check that Roblox Studio is running
- Verify HttpService is enabled in Studio settings (Game Settings > Security)
- Ensure no firewall is blocking localhost port 62847
- Check Studio output window for `[MCP]` log messages
- Verify the bridge server is running (`bun run dev`)

**Tool not appearing in MCP client:**

- Verify MCP client configuration points to correct path
- Restart MCP client after configuration changes
- Check that `bun run dev` is running without errors
- The MCP server will always start even if the bridge port is occupied

**Commands timing out:**

- Default timeout is 30 seconds
- Check Studio output for Lua errors
- Verify instance paths are correct (use `GetChildren` to explore)

**Port conflicts:**

- Set `ROBLOX_BRIDGE_PORT` to a different port in your environment
- Check server startup logs to see which port was used

**Version mismatch errors:**

- Update the plugin to match the server version
- Check the server console for the expected version

## Contributing

Contributions are welcome! Please read our [Contributing Guide](CONTRIBUTING.md) for guidelines on:

- Setting up the development environment
- Code standards and testing requirements
- Pull request process
- Adding new Roblox tools

For major changes, please open an issue first to discuss your proposal.

## License

MIT License - see LICENSE file for details

## Acknowledgments

- Built with [FastMCP](https://github.com/punkpeye/fastmcp)
- Powered by [Bun](https://bun.sh)
- Inspired by the Model Context Protocol specification
