# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Changed

- **WebSocket-only communication** - Removed HTTP long-polling, now pure WebSocket
- Plugin connects directly via WebSocket without health check
- Added ping/pong keepalive (30 second interval)
- Simplified bridge API: `addClient`, `removeClient`, `markClientReady`
- Cleaner connection state: `isConnected`, `getClientCount`, `getReadyClientCount`

### Removed

- HTTP `/poll` endpoint (replaced by WebSocket)
- HTTP `/result` endpoint (replaced by WebSocket)
- HTTP `/health` endpoint (WebSocket handles discovery)
- `getPendingCommands()` method (commands sent immediately via WebSocket)
- `longPoll()` method (no longer needed)
- `getConnectionInfo()` method (replaced by simpler API)

## [1.1.0] - 2026-01-29

### Added

- **149 new methods** (56 → 205 total), organized into 30+ categories
- API documentation at `docs/API.md`
- Modular Lua plugin architecture with 7 tool modules:
  - `instance.lua` - Instance management, hierarchy, selection
  - `spatial.lua` - Transforms, physics, raycasting, joints
  - `visual.lua` - Appearance, lighting, effects, GUI
  - `world.lua` - Terrain, camera, pathfinding, attributes
  - `players.lua` - Players, teams, animation, humanoid
  - `scripting.lua` - Script creation and manipulation
  - `async.lua` - Audio, tweening, networking, DataStore
- Utility modules for shared functionality:
  - `services.lua` - Cached service references
  - `path.lua` - Path resolution and type validation
  - `sandbox.lua` - Safe code execution environment
- New method categories:
  - Raycasting & spatial queries (Raycast, Shapecast, Blockcast, Spherecast)
  - Physics (velocity, impulse, assembly, collision groups)
  - Pathfinding (ComputePath with agent configuration)
  - Animation (LoadAnimation, PlayAnimation, StopAnimation)
  - Humanoid (state, damage, accessories, description)
  - GUI (CreateGuiElement, SetGuiText, SetGuiSize, etc.)
  - Networking (RemoteEvents, RemoteFunctions)
  - DataStore (Get, Set, Remove values)
  - Tweening (CreateTween, TweenProperty)
  - Teams & Leaderstats
  - Terrain operations (FillBall, FillBlock, FillCylinder, etc.)
  - Camera coordinates (ScreenPointToRay, WorldToScreenPoint, etc.)
  - History (Undo, Redo, waypoints)
  - Runtime state (IsStudio, IsRunMode, IsEdit, IsRunning)
- JSDoc category comments in TypeScript METHODS array
- Lua module headers documenting method categories
- Return type annotations in DESCRIPTION

### Changed

- Refactored plugin from monolithic to modular architecture
- Reduced `init.server.lua` from 245 to 142 lines (orchestration only)
- Environment variable configuration via dotenv
- Config module for centralized settings
- Bridge port and timeout now configurable via environment variables

### Fixed

- Removed duplicate function definitions between init and modules
- Added missing InsertService to services cache

## [1.0.0] - 2026-01-21

### Added

- Initial release of roblox-bridge-mcp
- FastMCP server with 56 Roblox Studio tools
- HTTP bridge for Roblox plugin communication
- Roblox Studio plugin with modern Lua APIs
- Test suite with full coverage
- CI/CD workflows (testing, releases, dependency updates)
- Pre-commit hooks with Lefthook (typecheck, format, test)
- npm publishing support with npx execution
- Documentation with API reference and installation guide
- MIT License

### Tools Included

- Instance management (create, delete, clone, parent)
- Property manipulation (set, get, multi-set)
- Positioning and transforms (move, rotate, scale, resize)
- Visual effects (color, material, transparency, reflectance)
- Lighting controls (time of day, ambient, brightness, fog)
- Terrain operations (generate, clear, smooth, paint)
- Script management (ModuleScript, LocalScript, Script)
- Audio (create, play, stop, volume, pitch)
- Animation and tweening (play, create, stop)
- Camera controls (set type, position, field of view, focus)
- Selection tools (get, set, add, remove, clear, highlight)
- Workspace utilities (raycast, find parts in region/radius, get descendants)
- Datastore operations (read, write, delete)
- Team management (create, rename, color, auto-assign)
- UI creation and manipulation (ScreenGui, TextLabel, TextButton, ImageLabel, Frame)
- Debug tools (breakpoint, log, measure performance, memory snapshot)

[Unreleased]: https://github.com/CoderDayton/roblox-bridge-mcp/compare/v1.1.0...HEAD
[1.1.0]: https://github.com/CoderDayton/roblox-bridge-mcp/compare/v1.0.0...v1.1.0
[1.0.0]: https://github.com/CoderDayton/roblox-bridge-mcp/releases/tag/v1.0.0
