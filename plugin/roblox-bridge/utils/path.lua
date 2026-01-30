--!optimize 2
-- Path resolution utilities

-- Localize globals for performance
local string_split = string.split
local pcall = pcall

local Path = {}

function Path.resolve(path)
	if path == "game" then return game end

	local segments = string_split(path, ".")
	local current = game
	local startIdx = segments[1] == "game" and 2 or 1
	local numSegments = #segments

	for i = startIdx, numSegments do
		if not current then return nil end
		local segment = segments[i]
		local child = current:FindFirstChild(segment)
		if not child and current == game then
			local ok, service = pcall(game.GetService, game, segment)
			if ok then child = service end
		end
		current = child
	end
	return current
end

function Path.require(path)
	local obj = Path.resolve(path)
	if not obj then error("Instance not found: " .. path) end
	return obj
end

function Path.requireBasePart(path)
	local obj = Path.require(path)
	if not obj:IsA("BasePart") then error("Not a BasePart: " .. path) end
	return obj
end

function Path.requireScript(path)
	local obj = Path.require(path)
	if not obj:IsA("LuaSourceContainer") then error("Not a script: " .. path) end
	return obj
end

function Path.requireHumanoid(path)
	local obj = Path.require(path)
	if not obj:IsA("Humanoid") then error("Not a Humanoid: " .. path) end
	return obj
end

function Path.requireGuiObject(path)
	local obj = Path.require(path)
	if not obj:IsA("GuiObject") then error("Not a GuiObject: " .. path) end
	return obj
end

function Path.getPosition(obj)
	if obj:IsA("BasePart") then return obj.Position
	elseif obj:IsA("Model") then return obj:GetPivot().Position
	elseif obj:IsA("Attachment") then return obj.WorldPosition
	end
	return Vector3.zero
end

return Path
