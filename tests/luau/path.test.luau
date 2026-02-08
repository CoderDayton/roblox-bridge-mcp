--!strict
--------------------------------------------------------------------------------
-- Tests: utils/path.lua — Path resolution with real @lune/roblox instances
--------------------------------------------------------------------------------

local process = require("@lune/process")
local roblox = require("@lune/roblox")
local Framework = require("./framework")
local Loader = require("./loader")

local describe = Framework.describe
local it = Framework.it
local expect = Framework.expect

local Instance = roblox.Instance

local PATH_FILE = "plugin/roblox-bridge/utils/path.lua"

-- Build a real instance tree for testing
local dataModel = Instance.new("DataModel")
local workspace_ = dataModel:GetService("Workspace")
local lighting = dataModel:GetService("Lighting")

local part = Instance.new("Part")
part.Name = "TestPart"
part.Parent = workspace_

local model = Instance.new("Model")
model.Name = "TestModel"
model.Parent = workspace_

local childPart = Instance.new("Part")
childPart.Name = "ChildPart"
childPart.Parent = model

local folder = Instance.new("Folder")
folder.Name = "TestFolder"
folder.Parent = workspace_

-- Load Path module with our game instance injected
local Path = Loader.load(PATH_FILE, {
	globals = {
		game = dataModel,
	},
	mocks = {},
})

local suite = Framework.runSuite("Path", function()
	describe("resolve", function()
		it("returns game for 'game'", function()
			local result = Path.resolve("game")
			expect(result).to.equal(dataModel)
		end)

		it("resolves Workspace service via 'game.Workspace'", function()
			local result = Path.resolve("game.Workspace")
			expect(result).to.equal(workspace_)
		end)

		it("resolves Lighting service via GetService fallback", function()
			local result = Path.resolve("game.Lighting")
			expect(result).to.equal(lighting)
		end)

		it("resolves a child part", function()
			local result = Path.resolve("game.Workspace.TestPart")
			expect(result).to.equal(part)
		end)

		it("resolves nested children", function()
			local result = Path.resolve("game.Workspace.TestModel.ChildPart")
			expect(result).to.equal(childPart)
		end)

		it("resolves without 'game.' prefix", function()
			local result = Path.resolve("Workspace.TestPart")
			expect(result).to.equal(part)
		end)

		it("returns nil for non-existent path", function()
			local result = Path.resolve("game.Workspace.DoesNotExist")
			expect(result).to.be.nil_()
		end)

		it("returns nil for non-existent nested path", function()
			local result = Path.resolve("game.Workspace.TestPart.Nope.Deeper")
			expect(result).to.be.nil_()
		end)
	end)

	describe("require", function()
		it("returns instance for valid path", function()
			local result = Path.require("game.Workspace.TestPart")
			expect(result).to.equal(part)
		end)

		it("throws for non-existent path", function()
			expect(function()
				Path.require("game.Workspace.Ghost")
			end).to.throw()
		end)
	end)

	describe("requireBasePart", function()
		it("returns a BasePart instance", function()
			local result = Path.requireBasePart("game.Workspace.TestPart")
			expect(result).to.equal(part)
		end)

		it("throws for non-BasePart", function()
			expect(function()
				Path.requireBasePart("game.Workspace.TestFolder")
			end).to.throw()
		end)
	end)

	describe("getPosition", function()
		it("returns Position for a BasePart", function()
			part.Position = roblox.Vector3.new(10, 20, 30)
			local pos = Path.getPosition(part)
			expect(pos).to.be.ok()
			-- Vector3 comparison: check components
			expect(pos.X).to.equal(10)
			expect(pos.Y).to.equal(20)
			expect(pos.Z).to.equal(30)
		end)
	end)
end)

local allPassed = Framework.report({ suite })
if not allPassed then
	process.exit(1)
end
