-- Players, teams, leaderstats, character, and animation tools
local Services = require(script.Parent.Parent.utils.services)
local Path = require(script.Parent.Parent.utils.path)

local Tools = {}

-- State for animation tracks
local animationTracks = {}

-- Players
function Tools.GetPlayers()
	local names = {}
	for _, player in pairs(Services.Players:GetPlayers()) do
		table.insert(names, player.Name)
	end
	return names
end

function Tools.GetPlayerInfo(p)
	local player = Services.Players:FindFirstChild(p.name)
	if not player then error("Player not found: " .. p.name) end
	return {
		UserId = player.UserId,
		DisplayName = player.DisplayName,
		Team = player.Team and player.Team.Name or nil,
		Character = player.Character and player.Character:GetFullName() or nil,
	}
end

-- Teams
function Tools.CreateTeam(p)
	local team = Instance.new("Team")
	team.Name = p.name
	if p.color then team.TeamColor = BrickColor.new(p.color) end
	team.AutoAssignable = p.autoAssignable ~= false
	team.Parent = Services.Teams
	return team:GetFullName()
end

function Tools.SetPlayerTeam(p)
	local player = Services.Players:FindFirstChild(p.playerName)
	if not player then error("Player not found: " .. p.playerName) end
	local team = Services.Teams:FindFirstChild(p.teamName)
	if not team then error("Team not found: " .. p.teamName) end
	player.Team = team
	return "Set"
end

function Tools.GetPlayerTeam(p)
	local player = Services.Players:FindFirstChild(p.playerName)
	if not player then error("Player not found: " .. p.playerName) end
	return player.Team and player.Team.Name or nil
end

-- Leaderstats
function Tools.CreateLeaderstat(p)
	local player = Services.Players:FindFirstChild(p.playerName)
	if not player then error("Player not found: " .. p.playerName) end
	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then
		leaderstats = Instance.new("Folder")
		leaderstats.Name = "leaderstats"
		leaderstats.Parent = player
	end
	local stat = Instance.new(p.valueType or "IntValue")
	stat.Name = p.statName
	stat.Value = p.initialValue or 0
	stat.Parent = leaderstats
	return stat:GetFullName()
end

function Tools.SetLeaderstatValue(p)
	local player = Services.Players:FindFirstChild(p.playerName)
	if not player then error("Player not found: " .. p.playerName) end
	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then error("No leaderstats found") end
	local stat = leaderstats:FindFirstChild(p.statName)
	if not stat then error("Stat not found: " .. p.statName) end
	stat.Value = p.value
	return "Set"
end

function Tools.GetLeaderstatValue(p)
	local player = Services.Players:FindFirstChild(p.playerName)
	if not player then error("Player not found: " .. p.playerName) end
	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then error("No leaderstats found") end
	local stat = leaderstats:FindFirstChild(p.statName)
	if not stat then error("Stat not found: " .. p.statName) end
	return stat.Value
end

-- Character
function Tools.GetCharacter(p)
	local player = Services.Players:FindFirstChild(p.playerName)
	if not player then error("Player not found: " .. p.playerName) end
	return player.Character and player.Character:GetFullName() or nil
end

function Tools.SetCharacterAppearance(p)
	local player = Services.Players:FindFirstChild(p.playerName)
	if not player then error("Player not found: " .. p.playerName) end
	local ok, desc = pcall(function()
		return Services.Players:GetHumanoidDescriptionFromUserId(p.userId or player.UserId)
	end)
	if not ok then error("Failed to get appearance: " .. tostring(desc)) end
	local character = player.Character
	if not character then error("Player has no character") end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then error("No humanoid in character") end
	humanoid:ApplyDescription(desc)
	return "Applied"
end

-- Animation
function Tools.LoadAnimation(p)
	local humanoid = Path.requireHumanoid(p.humanoidPath)
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = humanoid
	end
	local anim = Instance.new("Animation")
	anim.AnimationId = "rbxassetid://" .. tostring(p.animationId)
	local track = animator:LoadAnimation(anim)
	local trackId = tostring(p.animationId) .. "_" .. tick()
	animationTracks[trackId] = track
	return trackId
end

function Tools.PlayAnimation(p)
	local track = animationTracks[p.trackId]
	if not track then error("Animation track not found: " .. p.trackId) end
	track:Play(p.fadeTime, p.weight, p.speed)
	return "Playing"
end

function Tools.StopAnimation(p)
	local track = animationTracks[p.trackId]
	if not track then error("Animation track not found: " .. p.trackId) end
	track:Stop(p.fadeTime)
	return "Stopped"
end

-- Humanoid
function Tools.GetHumanoidState(p)
	local humanoid = Path.requireHumanoid(p.humanoidPath)
	return tostring(humanoid:GetState())
end

function Tools.ChangeHumanoidState(p)
	local humanoid = Path.requireHumanoid(p.humanoidPath)
	local state = Enum.HumanoidStateType[p.state]
	if not state then error("Invalid state: " .. p.state) end
	humanoid:ChangeState(state)
	return "Changed"
end

function Tools.TakeDamage(p)
	local humanoid = Path.requireHumanoid(p.humanoidPath)
	humanoid:TakeDamage(p.amount)
	return "Damaged"
end

function Tools.GetAccessories(p)
	local humanoid = Path.requireHumanoid(p.humanoidPath)
	local accessories = humanoid:GetAccessories()
	local paths = {}
	for _, acc in ipairs(accessories) do
		table.insert(paths, acc:GetFullName())
	end
	return paths
end

function Tools.AddAccessory(p)
	local humanoid = Path.requireHumanoid(p.humanoidPath)
	local accessory = Path.require(p.accessoryPath)
	if not accessory:IsA("Accessory") then error("Not an Accessory: " .. p.accessoryPath) end
	humanoid:AddAccessory(accessory)
	return "Added"
end

function Tools.RemoveAccessories(p)
	local humanoid = Path.requireHumanoid(p.humanoidPath)
	humanoid:RemoveAccessories()
	return "Removed"
end

function Tools.GetHumanoidDescription(p)
	local humanoid = Path.requireHumanoid(p.humanoidPath)
	local desc = humanoid:GetAppliedDescription()
	if not desc then return nil end
	return {
		HeadColor = { desc.HeadColor.R, desc.HeadColor.G, desc.HeadColor.B },
		BodyTypeScale = desc.BodyTypeScale,
		HeadScale = desc.HeadScale,
		HeightScale = desc.HeightScale,
		WidthScale = desc.WidthScale,
		DepthScale = desc.DepthScale,
	}
end

-- Player Movement
function Tools.GetPlayerPosition(p)
	local player = Services.Players:FindFirstChild(p.username)
	if not player or not player.Character then error("Player or character not found: " .. p.username) end
	local root = player.Character:FindFirstChild("HumanoidRootPart")
	if not root then error("Character root not found") end
	return { root.Position.X, root.Position.Y, root.Position.Z }
end

function Tools.TeleportPlayer(p)
	local player = Services.Players:FindFirstChild(p.username)
	if not player or not player.Character then error("Player or character not found") end
	player.Character:MoveTo(Vector3.new(p.position[1], p.position[2], p.position[3]))
	return "Teleported"
end

function Tools.KickPlayer(p)
	local player = Services.Players:FindFirstChild(p.username)
	if player then player:Kick(p.reason or "Kicked by MCP") end
	return "Kicked"
end

return Tools
