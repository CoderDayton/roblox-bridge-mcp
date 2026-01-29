-- Path resolution utilities
local Path = {}

function Path.resolve(path)
	if path == "game" then return game end

	local segments = string.split(path, ".")
	local current = game
	local startIdx = segments[1] == "game" and 2 or 1

	for i = startIdx, #segments do
		if not current then return nil end
		local child = current:FindFirstChild(segments[i])
		if not child and current == game then
			local ok, service = pcall(game.GetService, game, segments[i])
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
