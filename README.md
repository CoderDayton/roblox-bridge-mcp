<div align="center">

<img src="plugin/icon.png" alt="Roblox Bridge MCP" width="128" height="128">

# roblox-bridge-mcp

![Version](https://img.shields.io/badge/version-1.0.0-blue)
![License](https://img.shields.io/badge/license-MIT-green)
![Bun](https://img.shields.io/badge/bun-1.0+-black)
![FastMCP](https://img.shields.io/badge/FastMCP-1.20+-purple)

**AI-powered bridge connecting Model Context Protocol to Roblox Studio**

Real-time control of Roblox Studio instances through a unified MCP interface. Build, script, and manipulate 3D worlds using AI assistants like Claude.

[Getting Started](#getting-started) • [Installation](#installation) • [Usage](#usage) • [API Reference](#api-reference)

</div>

---

## Overview

roblox-bridge-mcp enables AI agents to directly interact with Roblox Studio through the Model Context Protocol. It provides 56 operations spanning instance management, scripting, physics, lighting, and more through a single unified tool.

**Architecture:**

- **MCP Server** - FastMCP + Bun server exposing the `roblox` tool
- **HTTP Bridge** - Local server (port 8081) for command/result exchange
- **Studio Plugin** - Lua plugin polling for commands and executing them in Studio

## Features

- **Single Unified Tool** - All 56 operations accessible via one `roblox` tool with method dispatch
- **Real-time Communication** - HTTP polling bridge with exponential backoff and connection status
- **Studio Integration** - Toolbar button with visual connection indicator
- **Comprehensive Coverage** - Instance CRUD, scripting, transforms, physics, lighting, selection, and more
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

Download the latest `loader.server.lua` from the [releases page](https://github.com/CoderDayton/roblox-bridge-mcp/releases) and install it:

- **Windows:** `%LOCALAPPDATA%\Roblox\Plugins`
- **macOS:** `~/Documents/Roblox/Plugins`

**3. Start Roblox Studio**

Open a place in Studio. The plugin will auto-start and the toolbar button should appear.

**4. Use from your MCP client**

The `roblox` tool will be available in your MCP client (restart the client if needed).

## Configuration

<details>
<summary>Environment Variables</summary>

You can configure the bridge server behavior using environment variables. Create a `.env` file in your project root or set these in your MCP client configuration:

| Variable             | Description                                   | Default |
| -------------------- | --------------------------------------------- | ------- |
| `ROBLOX_BRIDGE_PORT` | Port for the HTTP bridge server               | `8081`  |
| `ROBLOX_TIMEOUT_MS`  | Timeout in milliseconds for command execution | `30000` |
| `ROBLOX_RETRIES`     | Number of retry attempts for failed commands  | `2`     |
| `LOG_LEVEL`          | Logging level (DEBUG, INFO, WARN, ERROR)      | `INFO`  |

**Example `.env` file:**

```bash
ROBLOX_BRIDGE_PORT=8081
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
        "ROBLOX_BRIDGE_PORT": "8081",
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

<details>
<summary><strong>Available Methods</strong> (click to expand)</summary>

#### Instance Management

- `CreateInstance(className, parentPath, name?, properties?)` - Create a new instance
- `DeleteInstance(path)` - Destroy an instance
- `CloneInstance(path, parentPath?)` - Clone an instance
- `RenameInstance(path, newName)` - Rename an instance

#### Property Access

- `SetProperty(path, property, value)` - Set a property value
- `GetProperty(path, property)` - Get a property value

#### Hierarchy Navigation

- `GetChildren(path)` - Get child names
- `GetDescendants(path)` - Get all descendant paths
- `FindFirstChild(path, name, recursive?)` - Find a child by name
- `GetService(service)` - Get a Roblox service

#### Transform

- `MoveTo(path, position[x,y,z])` - Move a Model or BasePart
- `SetPosition(path, x, y, z)` - Set Position property
- `SetRotation(path, x, y, z)` - Set Rotation (degrees)
- `SetSize(path, x, y, z)` - Set Size property
- `PivotTo(path, cframe[12])` - Set CFrame via PivotTo
- `GetPivot(path)` - Get CFrame as 12 components

#### Appearance

- `SetColor(path, r, g, b)` - Set Color3 (0-255 RGB)
- `SetTransparency(path, value)` - Set Transparency (0-1)
- `SetMaterial(path, material)` - Set Material enum

#### Physics

- `SetAnchored(path, anchored)` - Set Anchored property
- `SetCanCollide(path, canCollide)` - Set CanCollide property

#### Scripting

- `CreateScript(name, parentPath, source, type?)` - Create a script with source code
- `GetScriptSource(path)` - Read script source
- `SetScriptSource(path, source)` - Replace script source
- `AppendToScript(path, code)` - Append to script
- `ReplaceScriptLines(path, startLine, endLine, content)` - Replace line range
- `InsertScriptLines(path, lineNumber, content)` - Insert lines at position
- `RunConsoleCommand(code)` - Execute Luau code in command bar context

#### Selection

- `GetSelection()` - Get currently selected objects
- `SetSelection(paths[])` - Set selection to specific objects
- `ClearSelection()` - Clear selection
- `AddToSelection(paths[])` - Add to current selection

#### Grouping

- `GroupSelection(name)` - Group selected objects into Model
- `UngroupModel(path)` - Ungroup a Model

#### Lighting

- `SetTimeOfDay(time)` - Set Lighting.TimeOfDay (e.g., "14:00:00")
- `SetBrightness(brightness)` - Set Lighting.Brightness
- `SetAtmosphereDensity(density)` - Set Atmosphere.Density (creates if missing)
- `CreateLight(parentPath, type, brightness?, color?)` - Create a light object

#### Attributes & Tags

- `SetAttribute(path, name, value)` - Set an attribute
- `GetAttribute(path, name)` - Get an attribute value
- `GetAttributes(path)` - Get all attributes
- `AddTag(path, tag)` - Add a CollectionService tag
- `RemoveTag(path, tag)` - Remove a tag
- `GetTags(path)` - Get all tags
- `HasTag(path, tag)` - Check if instance has tag

#### Players

- `GetPlayers()` - Get list of player names
- `GetPlayerPosition(username)` - Get player character position
- `TeleportPlayer(username, position[x,y,z])` - Teleport player
- `KickPlayer(username, reason?)` - Kick player from game

#### Place/Studio

- `SavePlace()` - Trigger save (if permissions allow)
- `GetPlaceInfo()` - Get PlaceId, Name, JobId

#### Audio

- `PlaySound(soundId, parentPath?, volume?)` - Create and play a sound
- `StopSound(path)` - Stop a playing sound

#### Utility

- `GetDistance(path1, path2)` - Calculate distance between two objects
- `HighlightObject(path, color?, duration?)` - Add visual Highlight
- `Chat(message, color?)` - Send system message to TextChatService

</details>

### Path Format

All instance paths use dot notation starting from `game`:

- `game.Workspace.Model.Part`
- `game.ReplicatedStorage.Assets`
- Service names are automatically resolved: `game.Workspace` resolves to Workspace service

## Plugin Features

The Studio plugin provides:

- **Toolbar Integration** - "MCP Bridge" toolbar with toggle button
- **Connection Status** - Visual indicator (active = connected, inactive = disconnected)
- **Enable/Disable** - Click toolbar button to toggle bridge on/off
- **Auto-Reconnect** - Exponential backoff (2s → 10s) on connection loss
- **Modern Lua** - Uses `task` library, no deprecated APIs
- **Error Handling** - Structured error messages with context

## Architecture

```
┌─────────────────┐         ┌──────────────────┐         ┌─────────────────┐
│   MCP Client    │ stdio   │   FastMCP Server │  HTTP   │  Studio Plugin  │
│  (Claude, etc)  │◄───────►│   (Bun + Node)   │◄───────►│   (Lua/Luau)    │
└─────────────────┘         └──────────────────┘         └─────────────────┘
                                     │                            │
                                     │                            │
                                  port 8081                  Roblox API
                             /poll, /result              (game.Workspace, etc)
```

**Communication Flow:**

1. MCP client calls `roblox` tool with method + params
2. Server adds command to queue
3. Plugin polls `/poll`, receives commands
4. Plugin executes command in Studio using Roblox API
5. Plugin posts result to `/result`
6. Server resolves promise, returns to MCP client

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

**Type check:**

```bash
bun run typecheck
```

**Inspect MCP server:**

```bash
bun run inspect
```

**Build for production:**

```bash
bun run build
```

## Troubleshooting

**Plugin not connecting:**

- Check that Roblox Studio is running
- Verify HttpService is enabled in Studio settings
- Ensure no firewall is blocking localhost:8081
- Check Studio output window for `[MCP]` log messages

**Tool not appearing in MCP client:**

- Verify MCP client configuration points to correct path
- Restart MCP client after configuration changes
- Check that `bun run dev` is running without errors

**Commands timing out:**

- Default timeout is 30 seconds
- Check Studio output for Lua errors
- Verify instance paths are correct (use `GetChildren` to explore)

## Contributing

Contributions welcome! Please open an issue before submitting major changes.

## License

MIT License - see LICENSE file for details

## Acknowledgments

- Built with [FastMCP](https://github.com/punkpeye/fastmcp)
- Powered by [Bun](https://bun.sh)
- Inspired by the Model Context Protocol specification
