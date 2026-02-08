--!strict
--------------------------------------------------------------------------------
-- Module Loader
-- Loads plugin Lua source files via luau.load() with require interception
-- Tests actual source files without modifying them
--------------------------------------------------------------------------------

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")
local serde = require("@lune/serde")

local Loader = {}

-- Plugin root relative to project root
local PLUGIN_ROOT = "plugin/roblox-bridge"

--- Create a proxy object that records property access chains
--- Used to intercept `script.Parent.utils.services` style paths
local function createPathProxy(segments: { string }): any
	return setmetatable({}, {
		__index = function(_, key: string)
			local newSegments = table.clone(segments)
			table.insert(newSegments, key)
			return createPathProxy(newSegments)
		end,
		__tostring = function()
			return table.concat(segments, ".")
		end,
	})
end

--- Map a require path (e.g. "script.Parent.utils.services") to a filesystem path
local function resolveRequirePath(requirePath: string, sourceDir: string): string?
	-- Strip "script." prefix
	local path = requirePath
	if string.sub(path, 1, 7) == "script." then
		path = string.sub(path, 8)
	end

	-- Resolve Parent references
	local dir = sourceDir
	while string.sub(path, 1, 7) == "Parent." do
		path = string.sub(path, 8)
		dir = string.gsub(dir, "/[^/]+$", "")
	end
	if path == "Parent" then
		dir = string.gsub(dir, "/[^/]+$", "")
		path = ""
	end

	-- Convert dot notation to path
	local relPath = string.gsub(path, "%.", "/")
	local fullPath = if relPath == "" then dir else `{dir}/{relPath}`

	-- Try .lua extension, then init.lua inside directory
	if fs.isFile(`{fullPath}.lua`) then
		return `{fullPath}.lua`
	end
	if fs.isDir(fullPath) and fs.isFile(`{fullPath}/init.lua`) then
		return `{fullPath}/init.lua`
	end
	-- Try init.server.lua for entry point
	if fs.isDir(fullPath) and fs.isFile(`{fullPath}/init.server.lua`) then
		return `{fullPath}/init.server.lua`
	end

	return nil
end

-- Cache of already-loaded modules to prevent double-loading
local moduleCache: { [string]: any } = {}

--- Build the base environment for loaded modules
local function buildBaseEnv(): { [string]: any }
	return {
		-- Roblox globals from @lune/roblox
		Instance = roblox.Instance,
		Color3 = roblox.Color3,
		Vector3 = roblox.Vector3,
		Vector2 = roblox.Vector2,
		CFrame = roblox.CFrame,
		UDim = roblox.UDim,
		UDim2 = roblox.UDim2,
		Enum = roblox.Enum,
		Font = roblox.Font,
		BrickColor = roblox.BrickColor,
		NumberRange = roblox.NumberRange,
		NumberSequence = roblox.NumberSequence,
		NumberSequenceKeypoint = roblox.NumberSequenceKeypoint,
		ColorSequence = roblox.ColorSequence,
		ColorSequenceKeypoint = roblox.ColorSequenceKeypoint,
		PhysicalProperties = roblox.PhysicalProperties,
		Ray = roblox.Ray,
		Rect = roblox.Rect,
		Region3 = roblox.Region3,

		-- Game globals
		game = roblox.Instance.new("DataModel"),
		workspace = roblox.Instance.new("DataModel"):GetService("Workspace"),
	}
end

export type LoadOptions = {
	--- Override modules by require path key (e.g. "script.Parent.utils.services")
	mocks: { [string]: any }?,
	--- Extra globals to inject into the environment
	globals: { [string]: any }?,
}

--- Load a plugin source file with require interception
--- Returns the module's exports (whatever the file returns)
function Loader.load(filePath: string, options: LoadOptions?): any
	local opts = options or {}
	local mocks = opts.mocks or {}
	local extraGlobals = opts.globals or {}

	-- Check cache
	if moduleCache[filePath] then
		return moduleCache[filePath]
	end

	local source = fs.readFile(filePath)
	local sourceDir = string.gsub(filePath, "/[^/]+$", "")

	-- Replace `= require(` and `return require(` with mock, preserving function definitions
	-- like `function Path.require(` which should NOT be replaced
	local patched = string.gsub(source, "(=%s*)require%(", "%1__MOCK_REQUIRE(")
	patched = string.gsub(patched, "(return%s+)require%(", "%1__MOCK_REQUIRE(")

	-- Build environment
	local env = buildBaseEnv()

	-- Mock script object as path proxy
	env.script = createPathProxy({ "script" })

	-- Mock require function
	env.__MOCK_REQUIRE = function(pathProxy: any): any
		local key = tostring(pathProxy)

		-- Check explicit mocks first
		if mocks[key] then
			return mocks[key]
		end

		-- Try to resolve and load the actual file
		local resolved = resolveRequirePath(key, sourceDir)
		if resolved then
			return Loader.load(resolved, { mocks = mocks })
		end

		-- Return empty table for unresolvable modules
		warn(`[loader] Could not resolve require: {key}`)
		return {}
	end

	-- Merge extra globals
	for k, v in extraGlobals do
		env[k] = v
	end

	-- Load and execute
	local chunk = luau.load(patched, {
		debugName = filePath,
		environment = env,
		injectGlobals = true,
	})

	local result = chunk()
	moduleCache[filePath] = result
	return result
end

--- Load a specific function or table from init.server.lua by extracting it
--- This handles init.server.lua specially since it has side effects (plugin, toolbar)
function Loader.loadExtracted(filePath: string, extractSource: string, options: LoadOptions?): any
	local opts = options or {}
	local mocks = opts.mocks or {}
	local extraGlobals = opts.globals or {}

	local source = fs.readFile(filePath)

	-- Build the extracted source: original file's local definitions + extract expression
	local patched = string.gsub(source, "require%(", "__MOCK_REQUIRE(")

	-- Wrap: run the original source in a controlled environment, then return what we want
	local wrapped = `do\n{extractSource}\nend`
	local patchedWrapped = string.gsub(wrapped, "require%(", "__MOCK_REQUIRE(")

	local env = buildBaseEnv()
	env.script = createPathProxy({ "script" })

	local sourceDir = string.gsub(filePath, "/[^/]+$", "")
	env.__MOCK_REQUIRE = function(pathProxy: any): any
		local key = tostring(pathProxy)
		if mocks[key] then return mocks[key] end
		local resolved = resolveRequirePath(key, sourceDir)
		if resolved then return Loader.load(resolved, { mocks = mocks }) end
		warn(`[loader] Could not resolve require: {key}`)
		return {}
	end

	for k, v in extraGlobals do
		env[k] = v
	end

	local chunk = luau.load(patchedWrapped, {
		debugName = `{filePath}[extract]`,
		environment = env,
		injectGlobals = true,
	})

	return chunk()
end

--- Clear the module cache (call between test suites if needed)
function Loader.clearCache()
	table.clear(moduleCache)
end

return Loader
