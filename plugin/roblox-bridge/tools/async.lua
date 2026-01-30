--------------------------------------------------------------------------------
-- Async & Service Tools
-- Provides methods for audio, tweening, networking, data storage, and marketplace.
-- Handles operations that may involve async calls or external services.
--
-- Methods:
--   Audio: PlaySound, StopSound
--   Tweening: CreateTween, TweenProperty
--   Networking: CreateRemoteEvent, CreateRemoteFunction, FireRemoteEvent, InvokeRemoteFunction
--   DataStore: GetDataStore, SetDataStoreValue, GetDataStoreValue, RemoveDataStoreValue
--   Marketplace: InsertAsset, InsertMesh
--
-- Note: DataStore operations require API access to be enabled in Studio settings.
-- Note: Tweens are stored in memory and referenced by tweenId.
--------------------------------------------------------------------------------
local Services = require(script.Parent.Parent.utils.services)
local Path = require(script.Parent.Parent.utils.path)

local Tools = {}

-- State for active tweens (tweenId -> Tween)
local activeTweens = {}

-- Audio
function Tools.PlaySound(p)
	local sound
	if p.path then
		sound = Path.require(p.path)
		if not sound:IsA("Sound") then error("Not a Sound: " .. p.path) end
	else
		sound = Instance.new("Sound")
		sound.SoundId = "rbxassetid://" .. tostring(p.soundId)
		sound.Parent = workspace
		Services.Debris:AddItem(sound, (p.duration or 10) + 1)
	end
	if p.volume then sound.Volume = p.volume end
	sound:Play()
	return sound:GetFullName()
end

function Tools.StopSound(p)
	local sound = Path.require(p.path)
	if not sound:IsA("Sound") then error("Not a Sound: " .. p.path) end
	sound:Stop()
	return "Stopped"
end

-- Tweening
function Tools.CreateTween(p)
	local obj = Path.require(p.path)
	local tweenInfo = TweenInfo.new(
		p.duration or 1,
		Enum.EasingStyle[p.easingStyle or "Linear"] or Enum.EasingStyle.Linear,
		Enum.EasingDirection[p.easingDirection or "Out"] or Enum.EasingDirection.Out,
		p.repeatCount or 0,
		p.reverses or false,
		p.delayTime or 0
	)
	local goals = {}
	for prop, value in pairs(p.goals) do
		goals[prop] = value
	end
	local tween = Services.TweenService:Create(obj, tweenInfo, goals)
	local tweenId = tostring(tick())
	activeTweens[tweenId] = tween
	if p.autoPlay ~= false then tween:Play() end
	return tweenId
end

function Tools.TweenProperty(p)
	local obj = Path.require(p.path)
	local tweenInfo = TweenInfo.new(p.duration or 1)
	local goals = { [p.property] = p.value }
	local tween = Services.TweenService:Create(obj, tweenInfo, goals)
	tween:Play()
	return "Tweening"
end

-- Networking (Remote Events/Functions)
function Tools.CreateRemoteEvent(p)
	local parent = Path.require(p.parentPath or "game.ReplicatedStorage")
	local remote = Instance.new("RemoteEvent")
	remote.Name = p.name
	remote.Parent = parent
	return remote:GetFullName()
end

function Tools.CreateRemoteFunction(p)
	local parent = Path.require(p.parentPath or "game.ReplicatedStorage")
	local remote = Instance.new("RemoteFunction")
	remote.Name = p.name
	remote.Parent = parent
	return remote:GetFullName()
end

function Tools.FireRemoteEvent(p)
	local remote = Path.require(p.path)
	if not remote:IsA("RemoteEvent") then error("Not a RemoteEvent: " .. p.path) end
	if p.playerName then
		local player = Services.Players:FindFirstChild(p.playerName)
		if not player then error("Player not found: " .. p.playerName) end
		remote:FireClient(player, unpack(p.args or {}))
	else
		remote:FireAllClients(unpack(p.args or {}))
	end
	return "Fired"
end

function Tools.InvokeRemoteFunction(p)
	local remote = Path.require(p.path)
	if not remote:IsA("RemoteFunction") then error("Not a RemoteFunction: " .. p.path) end
	local player = Services.Players:FindFirstChild(p.playerName)
	if not player then error("Player not found: " .. p.playerName) end
	local ok, result = pcall(function()
		return remote:InvokeClient(player, unpack(p.args or {}))
	end)
	if not ok then error("Invoke failed: " .. tostring(result)) end
	return result
end

-- DataStore (Studio requires API access enabled)
function Tools.GetDataStore(p)
	local ok, store = pcall(function()
		return Services.DataStoreService:GetDataStore(p.name, p.scope)
	end)
	if not ok then error("Failed to get DataStore: " .. tostring(store)) end
	return "DataStore:" .. p.name
end

function Tools.SetDataStoreValue(p)
	local ok, store = pcall(function()
		return Services.DataStoreService:GetDataStore(p.storeName)
	end)
	if not ok then error("Failed to get DataStore: " .. tostring(store)) end
	local setOk, setErr = pcall(function()
		store:SetAsync(p.key, p.value)
	end)
	if not setOk then error("Failed to set value: " .. tostring(setErr)) end
	return "Set"
end

function Tools.GetDataStoreValue(p)
	local ok, store = pcall(function()
		return Services.DataStoreService:GetDataStore(p.storeName)
	end)
	if not ok then error("Failed to get DataStore: " .. tostring(store)) end
	local getOk, value = pcall(function()
		return store:GetAsync(p.key)
	end)
	if not getOk then error("Failed to get value: " .. tostring(value)) end
	return value
end

function Tools.RemoveDataStoreValue(p)
	local ok, store = pcall(function()
		return Services.DataStoreService:GetDataStore(p.storeName)
	end)
	if not ok then error("Failed to get DataStore: " .. tostring(store)) end
	local removeOk, removeErr = pcall(function()
		store:RemoveAsync(p.key)
	end)
	if not removeOk then error("Failed to remove value: " .. tostring(removeErr)) end
	return "Removed"
end

-- Marketplace (Asset Insertion)
function Tools.InsertAsset(p)
	local ok, model = pcall(function()
		return Services.InsertService:LoadAsset(p.assetId)
	end)
	if not ok then error("Failed to insert asset: " .. tostring(model)) end
	local parent = p.parentPath and Path.require(p.parentPath) or workspace
	for _, child in pairs(model:GetChildren()) do
		child.Parent = parent
	end
	model:Destroy()
	return "Inserted"
end

function Tools.InsertMesh(p)
	local parent = Path.require(p.parentPath or "game.Workspace")
	local meshPart = Instance.new("MeshPart")
	meshPart.MeshId = "rbxassetid://" .. tostring(p.meshId)
	if p.textureId then meshPart.TextureID = "rbxassetid://" .. tostring(p.textureId) end
	meshPart.Name = p.name or "MeshPart"
	meshPart.Parent = parent
	return meshPart:GetFullName()
end

return Tools
