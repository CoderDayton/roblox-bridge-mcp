# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Environment variable configuration via dotenv
- Config module for centralized settings
- `.env.example` with all available configuration options

### Changed

- Bridge port and timeout now configurable via environment variables

## [1.0.0] - 2026-01-21

### Added

- Initial release of roblox-bridge-mcp
- FastMCP server with 56 Roblox Studio tools
- HTTP bridge for Roblox plugin communication
- Roblox Studio plugin with modern Lua APIs
- Comprehensive test suite (26 tests, 54 assertions)
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

[Unreleased]: https://github.com/CoderDayton/roblox-bridge-mcp/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/CoderDayton/roblox-bridge-mcp/releases/tag/v1.0.0
