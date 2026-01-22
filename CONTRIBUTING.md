# Contributing to roblox-bridge-mcp

Thank you for your interest in contributing! This document provides guidelines for contributing to the project.

## Getting Started

### Prerequisites

- [Bun](https://bun.sh/) (latest version)
- [Roblox Studio](https://www.roblox.com/create)
- Node.js 18+ (for compatibility testing)
- Git

### Setup

1. Fork and clone the repository
2. Install dependencies: `bun install`
3. Copy `.env.example` to `.env` and configure if needed
4. Install the Roblox plugin: Copy `plugin/loader.server.lua` to `%LOCALAPPDATA%\Roblox\Plugins\`

## Development Workflow

### Making Changes

1. Create a feature branch: `git checkout -b feature/your-feature`
2. Make your changes
3. Run tests: `bun test`
4. Run typecheck: `bun run typecheck`
5. Format code: `bun run format`

### Pre-commit Hooks

Lefthook automatically runs before each commit:

- Prettier formatting check
- TypeScript type checking
- Full test suite

If checks fail, the commit will be blocked. Fix issues before committing.

## Code Standards

### TypeScript

- Strict mode enabled - no `any` without justification
- Explicit return types for public functions
- Use type inference for local variables
- All exported functions MUST have JSDoc comments
- Document complex types with JSDoc comments

### JSDoc Standards

All exported functions, classes, and interfaces must include:

```typescript
/**
 * Brief one-line description
 * Optional extended description with usage context
 * @param paramName - Description of parameter
 * @returns Description of return value
 * @throws {ErrorType} When this error occurs
 * @example
 * const result = myFunction("input");
 */
```

Required JSDoc elements:

- Summary line (what the function does)
- `@param` for all parameters with types and descriptions
- `@returns` describing the return value
- `@throws` for all error types that can be thrown
- `@private` for private methods (helps IDE autocomplete)
- `@deprecated` for deprecated APIs with migration guidance

### Code Style

- Prettier for formatting (auto-configured)
- 2-space indentation
- No trailing semicolons (Prettier removes them)
- Use modern ES6+ syntax
- Extract magic numbers to named constants
- Prefer early returns over nested conditionals
- Extract helper functions when methods exceed 30 lines
- Max function complexity: McCabe score ≤ 10

### Error Handling

- Use custom error classes from `src/utils/errors.ts`
- Include context in error messages (method, params, attempt)
- Retry on transient failures (timeouts)
- Log errors with structured logger

### Logging

- Use structured logger from `src/utils/logger.ts`
- Include context objects for debugging: `logger.bridge.info("message", { key: value })`
- Levels: DEBUG (verbose), INFO (normal), WARN (issues), ERROR (failures)
- No `console.log` in production code

## Testing

### Writing Tests

- Unit tests: Test individual functions/classes in isolation
- Integration tests: Test HTTP endpoints and bridge communication
- Place tests in `src/__tests__/` matching source structure
- Use descriptive test names: `describe("Feature")` → `test("should behave correctly when X")`

### Running Tests

```bash
bun test              # Run all tests
bun test --watch      # Watch mode
bun test --coverage   # Coverage report
```

### Test Requirements

- All new features must include tests
- Target coverage: 85%+ for critical paths (bridge.ts, tools)
- Maintain or improve code coverage (never decrease)
- Tests must pass before merging
- Mock external dependencies (HTTP, file system)
- Test edge cases: empty strings, null, undefined, boundary values
- Integration tests for new endpoints or protocols

## Project Structure

```
src/
├── index.ts              # MCP server entry point
├── config.ts             # Environment configuration
├── utils/
│   ├── bridge.ts         # HTTP bridge for Roblox
│   ├── errors.ts         # Custom error types
│   └── logger.ts         # Structured logging
├── tools/
│   ├── index.ts          # Tool registration
│   └── roblox-tools.ts   # Roblox Studio tools
└── __tests__/            # Test suite
plugin/
└── loader.server.lua     # Roblox Studio plugin
```

## Pull Request Process

### Before Submitting

1. Update CHANGELOG.md under `[Unreleased]` section
2. Update documentation if adding/changing features
3. Ensure all tests pass: `bun test`
4. Ensure typecheck passes: `bun run typecheck`
5. Format code: `bun run format`

### PR Guidelines

- Clear title describing the change
- Description with:
  - What changed
  - Why it changed
  - How to test it
- Link related issues
- Keep PRs focused - one feature/fix per PR
- Update tests for changed functionality

### Review Process

- Maintainers will review within 3-5 days
- Address feedback and push updates
- Squash commits if requested
- PRs merged via "Squash and merge"

## Adding New Roblox Tools

### Tool Structure

Tools follow the consolidated pattern in `src/tools/roblox-tools.ts`:

1. Add method to `METHODS` array enum
2. Document in `DESCRIPTION` string with signature: `MethodName(param1,param2?)`
3. Optional params marked with `?`, arrays with `[]`, CFrames with `[x,y,z,...]`

### Steps to Add a Tool

1. Add method name to `METHODS` array in `src/tools/roblox-tools.ts`
2. Add method signature to `DESCRIPTION` string
3. Update tool count in README (currently 99 methods)
4. Implement in `plugin/loader.server.lua`:
   - Add to appropriate Tools table function
   - Handle all params with validation
   - Return `{ success = true, data = result }` or throw error
5. Add tests for validation and execution
6. Document in CHANGELOG.md under `[Unreleased]`
7. Update capability categorization in `src/resources/index.ts` if adding new category

### Lua Implementation

```lua
function Tools.YourMethod(p)
	-- Validate required params
	local param1 = requireParam(p.param1, "param1")

	-- Optional params with defaults
	local param2 = p.param2 or "default"

	-- Implementation
	local result = doSomething(param1, param2)

	-- Return success or throw error
	return result
end
```

### Lua Best Practices

- Extract helper functions to reduce complexity
- Use `requirePath()` for instance lookups
- Use `requireParam()` for required parameters
- Document all public functions with Lua comments
- Prefer explicit error messages over generic failures
- Test with Roblox Studio before submitting

## Environment Variables

Configure via `.env` file:

- `ROBLOX_BRIDGE_PORT` - Bridge server port (default: 8081)
- `ROBLOX_TIMEOUT_MS` - Command timeout (default: 30000)
- `ROBLOX_RETRIES` - Retry attempts (default: 2)
- `LOG_LEVEL` - Logging level: DEBUG, INFO, WARN, ERROR (default: INFO)

## Release Process

Maintainers only:

1. Update version in `package.json` (semver)
2. Update `CHANGELOG.md` - move `[Unreleased]` to versioned section
3. Commit: `git commit -m "Release v1.0.0"`
4. Tag: `git tag v1.0.0`
5. Push: `git push origin main --tags`
6. GitHub Actions handles npm publish + release

## Getting Help

- **Issues:** [GitHub Issues](https://github.com/CoderDayton/roblox-bridge-mcp/issues)
- **Discussions:** [GitHub Discussions](https://github.com/CoderDayton/roblox-bridge-mcp/discussions)
- **Documentation:** [README.md](README.md)

## Code of Conduct

- Be respectful and inclusive
- Provide constructive feedback
- Focus on the code, not the person
- Help others learn and grow

## License

By contributing, you agree that your contributions will be licensed under the MIT License.
