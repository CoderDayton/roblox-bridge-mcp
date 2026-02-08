--!strict
--------------------------------------------------------------------------------
-- Roblox Environment Mocks
-- Provides Roblox globals for luau.load() environments
--------------------------------------------------------------------------------

local roblox = require("@lune/roblox")

local RobloxEnv = {}

--- Build a complete Roblox-like global environment
function RobloxEnv.create(): { [string]: any }
	local dataModel = roblox.Instance.new("DataModel")

	return {
		-- Core types from @lune/roblox
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
		game = dataModel,
		workspace = dataModel:GetService("Workspace"),

		-- Plugin stub (returns no-op functions)
		plugin = setmetatable({}, {
			__index = function()
				return function() end
			end,
		}),
	}
end

return RobloxEnv
