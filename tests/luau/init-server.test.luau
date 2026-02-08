--!strict
--------------------------------------------------------------------------------
-- Tests: init.server.lua — Classification tables + getParamsSummary
-- Extracts testable functions from the side-effect-heavy init script
--------------------------------------------------------------------------------

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local Framework = require("./framework")

local describe = Framework.describe
local it = Framework.it
local expect = Framework.expect

local INIT_PATH = "plugin/roblox-bridge/init.server.lua"

--------------------------------------------------------------------------------
-- Extract testable code from init.server.lua
-- Strategy: Read the source, extract READONLY, NO_WAYPOINT tables and
-- getParamsSummary function, wrap in a returnable module, load with luau.load()
--------------------------------------------------------------------------------

local source = fs.readFile(INIT_PATH)

-- Extract the READONLY table
local readonlyStart = string.find(source, "local READONLY = {", 1, true)
assert(readonlyStart, "Could not find READONLY table in init.server.lua")

-- Find matching closing brace
local readonlyEnd = readonlyStart
local braceDepth = 0
for i = readonlyStart, #source do
	local c = string.sub(source, i, i)
	if c == "{" then braceDepth += 1
	elseif c == "}" then
		braceDepth -= 1
		if braceDepth == 0 then
			readonlyEnd = i
			break
		end
	end
end
local readonlyBlock = string.sub(source, readonlyStart, readonlyEnd)

-- Extract NO_WAYPOINT table
local noWpStart = string.find(source, "local NO_WAYPOINT = {", 1, true)
assert(noWpStart, "Could not find NO_WAYPOINT table in init.server.lua")

local noWpEnd = noWpStart
braceDepth = 0
for i = noWpStart, #source do
	local c = string.sub(source, i, i)
	if c == "{" then braceDepth += 1
	elseif c == "}" then
		braceDepth -= 1
		if braceDepth == 0 then
			noWpEnd = i
			break
		end
	end
end
local noWpBlock = string.sub(source, noWpStart, noWpEnd)

-- Extract getParamsSummary function
local fnStart = string.find(source, "local function getParamsSummary", 1, true)
assert(fnStart, "Could not find getParamsSummary in init.server.lua")

-- Find the "end" that closes this function (track function/end depth)
local fnEnd = fnStart
local depth = 0
local i = fnStart
while i <= #source do
	-- Look for keywords
	local line = ""
	local lineEnd = string.find(source, "\n", i, true) or #source
	line = string.sub(source, i, lineEnd)

	-- Count function openers and end closers in this line
	for _ in string.gmatch(line, "%f[%w]function%f[%W]") do depth += 1 end
	for _ in string.gmatch(line, "%f[%w]if%f[%W]") do depth += 1 end
	for _ in string.gmatch(line, "%f[%w]for%f[%W]") do depth += 1 end
	for _ in string.gmatch(line, "%f[%w]while%f[%W]") do depth += 1 end
	for _ in string.gmatch(line, "%f[%w]end%f[%W]") do depth -= 1 end

	if depth == 0 then
		fnEnd = lineEnd
		break
	end
	i = lineEnd + 1
end
local fnBlock = string.sub(source, fnStart, fnEnd)

-- Build a loadable module via concatenation (backtick interpolation breaks with braces in source)
local extractedSource = "local tostring = tostring\n\n"
	.. readonlyBlock .. "\n"
	.. noWpBlock .. "\n"
	.. fnBlock .. "\n\n"
	.. "return {\n\tREADONLY = READONLY,\n\tNO_WAYPOINT = NO_WAYPOINT,\n\tgetParamsSummary = getParamsSummary,\n}\n"

local chunk = luau.load(extractedSource, {
	debugName = "init-server-extracted",
	injectGlobals = true,
})
local M = chunk()

local READONLY = M.READONLY
local NO_WAYPOINT = M.NO_WAYPOINT
local getParamsSummary = M.getParamsSummary

--------------------------------------------------------------------------------
-- Tests
--------------------------------------------------------------------------------

local suite = Framework.runSuite("init.server.lua", function()
	describe("READONLY table", function()
		it("has expected entry count", function()
			local count = 0
			for _ in READONLY do count += 1 end
			expect(count).to.be.greaterThan(60)
		end)

		it("contains known read-only methods", function()
			local known = {
				"GetFullName", "GetParent", "IsA", "GetClassName",
				"GetChildren", "GetDescendants", "FindFirstChild",
				"GetProperty", "GetPosition", "GetSize", "GetRotation",
				"GetMass", "Raycast", "GetCameraPosition",
				"GetPlayers", "GetPlayerInfo", "GetScriptSource",
				"IsStudio", "IsRunMode", "IsEdit", "IsRunning",
				"GetAttribute", "GetTags", "GetGravity",
			}
			for _, method in known do
				expect(READONLY[method]).to.be.ok()
			end
		end)

		it("does NOT contain mutating methods", function()
			local mutating = {
				"CreateInstance", "DeleteInstance", "SetProperty",
				"SetPosition", "SetColor", "SetAnchored",
				"CreateScript", "SetTimeOfDay",
			}
			for _, method in mutating do
				expect(READONLY[method]).to.be.nil_()
			end
		end)
	end)

	describe("NO_WAYPOINT table", function()
		it("has expected entry count", function()
			local count = 0
			for _ in NO_WAYPOINT do count += 1 end
			expect(count).to.be.greaterThan(30)
		end)

		it("contains camera methods", function()
			local camera = { "SetCameraPosition", "SetCameraTarget", "SetCameraFocus", "SetCameraType", "ZoomCamera" }
			for _, method in camera do
				expect(NO_WAYPOINT[method]).to.be.ok()
			end
		end)

		it("contains history meta-operations", function()
			expect(NO_WAYPOINT["Undo"]).to.be.ok()
			expect(NO_WAYPOINT["Redo"]).to.be.ok()
			expect(NO_WAYPOINT["RecordUndo"]).to.be.ok()
		end)

		it("contains runtime/ephemeral methods", function()
			local ephemeral = { "PlaySound", "StopSound", "PlayAnimation", "StopAnimation", "Chat", "EmitParticles" }
			for _, method in ephemeral do
				expect(NO_WAYPOINT[method]).to.be.ok()
			end
		end)

		it("contains player runtime methods", function()
			local player = { "TeleportPlayer", "KickPlayer", "ChangeHumanoidState", "TakeDamage" }
			for _, method in player do
				expect(NO_WAYPOINT[method]).to.be.ok()
			end
		end)

		it("contains script source methods", function()
			local scriptMethods = { "SetScriptSource", "AppendToScript", "ReplaceScriptLines", "InsertScriptLines" }
			for _, method in scriptMethods do
				expect(NO_WAYPOINT[method]).to.be.ok()
			end
		end)

		it("contains physics runtime methods", function()
			local physics = { "ApplyImpulse", "ApplyAngularImpulse", "SetVelocity", "SetAngularVelocity" }
			for _, method in physics do
				expect(NO_WAYPOINT[method]).to.be.ok()
			end
		end)

		it("does NOT contain methods that should get waypoints", function()
			local undoable = {
				"CreateInstance", "DeleteInstance", "SetProperty",
				"SetPosition", "SetColor", "SetAnchored",
				"CreateLight", "FillTerrain",
			}
			for _, method in undoable do
				expect(NO_WAYPOINT[method]).to.be.nil_()
			end
		end)
	end)

	describe("READONLY and NO_WAYPOINT overlap", function()
		it("have zero overlap (a method cannot be in both tables)", function()
			local overlap: { string } = {}
			for method in READONLY do
				if NO_WAYPOINT[method] then
					table.insert(overlap, method)
				end
			end
			expect(#overlap).to.equal(0)
		end)
	end)

	describe("getParamsSummary", function()
		it("returns path.property for SetProperty-style params", function()
			local result = getParamsSummary("SetProperty", { path = "Workspace.Part", property = "Anchored" })
			expect(result).to.equal("Workspace.Part.Anchored")
		end)

		it("returns path: tag for AddTag-style params", function()
			local result = getParamsSummary("AddTag", { path = "Workspace.Part", tag = "Enemy" })
			expect(result).to.equal("Workspace.Part: Enemy")
		end)

		it("returns path: name for SetAttribute-style params", function()
			local result = getParamsSummary("SetAttribute", { path = "Workspace.Part", name = "Health" })
			expect(result).to.equal("Workspace.Part: Health")
		end)

		it("returns plain path when only path is provided", function()
			local result = getParamsSummary("DeleteInstance", { path = "Workspace.Part" })
			expect(result).to.equal("Workspace.Part")
		end)

		it("returns parentPath → className for CreateInstance-style params", function()
			local result = getParamsSummary("CreateInstance", { parentPath = "Workspace", className = "Part" })
			expect(result).to.equal("Workspace → Part")
		end)

		it("returns parentPath alone when no className", function()
			local result = getParamsSummary("CreateLight", { parentPath = "Workspace.Part" })
			expect(result).to.equal("Workspace.Part")
		end)

		it("returns className when only className is provided", function()
			local result = getParamsSummary("FindFirstChildOfClass", { className = "Part" })
			expect(result).to.equal("Part")
		end)

		it("returns name when only name is provided", function()
			local result = getParamsSummary("RecordUndo", { name = "MyWaypoint" })
			expect(result).to.equal("MyWaypoint")
		end)

		it("returns attachment0Path for constraint params", function()
			local result = getParamsSummary("CreateConstraint", { attachment0Path = "Part.Att0" })
			expect(result).to.equal("Part.Att0")
		end)

		it("returns part0Path for weld params", function()
			local result = getParamsSummary("CreateWeld", { part0Path = "Workspace.Part1" })
			expect(result).to.equal("Workspace.Part1")
		end)

		it("returns scalar time value", function()
			local result = getParamsSummary("SetTimeOfDay", { time = "14:30:00" })
			expect(result).to.equal("14:30:00")
		end)

		it("returns scalar material value", function()
			local result = getParamsSummary("SetMaterial", { material = "Neon" })
			expect(result).to.equal("Neon")
		end)

		it("returns scalar gravity value", function()
			local result = getParamsSummary("SetGravity", { gravity = 196.2 })
			expect(result).to.equal("196.2")
		end)

		it("returns scalar brightness value", function()
			local result = getParamsSummary("SetBrightness", { brightness = 2 })
			expect(result).to.equal("2")
		end)

		it("returns scalar assetId value", function()
			local result = getParamsSummary("InsertAsset", { assetId = 12345 })
			expect(result).to.equal("12345")
		end)

		it("returns nil for empty params", function()
			local result = getParamsSummary("Undo", {})
			expect(result).to.be.nil_()
		end)

		it("prioritizes property+path over plain path", function()
			local result = getParamsSummary("SetProperty", { path = "Workspace.Part", property = "Name", name = "Foo" })
			expect(result).to.equal("Workspace.Part.Name")
		end)

		it("prioritizes tag over name when path present", function()
			local result = getParamsSummary("AddTag", { path = "Workspace.Part", tag = "Enemy", name = "X" })
			expect(result).to.equal("Workspace.Part: Enemy")
		end)
	end)
end)

local allPassed = Framework.report({ suite })
if not allPassed then
	process.exit(1)
end
