--!optimize 2
--------------------------------------------------------------------------------
-- MCP Bridge Plugin for Roblox Studio
-- Connects Studio to MCP server via WebSocket
--------------------------------------------------------------------------------

-- Localize globals for performance
local pairs = pairs
local pcall = pcall
local tostring = tostring

local VERSION = "2.0.0"
local CONFIG = {
	VERSION = VERSION,
	BASE_PORT = 62847,
	PORT_RANGE = 10,
	RETRY_INTERVAL = 2,
	MAX_RETRY_INTERVAL = 30,
	MAX_RETRIES = 10,
}

--------------------------------------------------------------------------------
-- Load Modules
--------------------------------------------------------------------------------

local Parent = script.Parent
local Services = require(Parent.utils.services)
local Path = require(Parent.utils.path)
local UI = require(Parent.ui)
local WebSocket = require(Parent.utils.websocket)

-- Tool modules
local InstanceTools = require(Parent.tools.instance)
local SpatialTools = require(Parent.tools.spatial)
local VisualTools = require(Parent.tools.visual)
local ScriptingTools = require(Parent.tools.scripting)
local PlayersTools = require(Parent.tools.players)
local WorldTools = require(Parent.tools.world)
local AsyncTools = require(Parent.tools.async)

--------------------------------------------------------------------------------
-- Merge Tools
--------------------------------------------------------------------------------

local Tools = {}
local function merge(source)
	for name, fn in pairs(source) do Tools[name] = fn end
end

merge(InstanceTools)
merge(SpatialTools)
merge(VisualTools)
merge(ScriptingTools)
merge(PlayersTools)
merge(WorldTools)
merge(AsyncTools)

--------------------------------------------------------------------------------
-- Command Classification
-- Default: mutating + undoable. Tables below list exceptions.
--------------------------------------------------------------------------------

local ChangeHistoryService = Services.ChangeHistoryService

-- Read-only methods (queries that don't change state)
local READONLY = {
	-- Instance discovery
	GetFullName=1, GetParent=1, IsA=1, GetClassName=1, WaitForChild=1,
	FindFirstAncestor=1, FindFirstAncestorOfClass=1, FindFirstAncestorWhichIsA=1,
	FindFirstChildOfClass=1, FindFirstChildWhichIsA=1, FindFirstDescendant=1,
	GetDebugId=1, GetProperty=1, GetChildren=1, GetDescendants=1,
	GetDescendantCount=1, FindFirstChild=1, GetService=1, GetAncestors=1,
	GetSelection=1, GetBoundingBox=1, GetExtentsSize=1, GetScale=1, GetPrimaryPart=1,
	-- Spatial queries
	GetPosition=1, GetRotation=1, GetSize=1, GetPivot=1, GetMass=1,
	GetJoints=1, GetAttachmentPosition=1, GetCollisionGroup=1,
	GetVelocity=1, GetAngularVelocity=1, GetCenterOfMass=1,
	GetAssemblyMass=1, GetAssemblyCenterOfMass=1, GetRootPart=1, GetRootPriority=1,
	Raycast=1, RaycastTo=1, Spherecast=1, Blockcast=1,
	GetPartsInPart=1, GetPartBoundsInRadius=1, GetPartBoundsInBox=1,
	GetTouchingParts=1, GetConnectedParts=1, GetDistance=1,
	-- World queries
	GetTerrainInfo=1, GetCameraType=1, GetCameraPosition=1,
	ScreenPointToRay=1, ViewportPointToRay=1, WorldToScreenPoint=1, WorldToViewportPoint=1,
	GetSunDirection=1, GetMoonDirection=1, GetMinutesAfterMidnight=1,
	GetCanUndo=1, GetCanRedo=1, ComputePath=1,
	GetPlaceVersion=1, GetGameId=1, GetPlaceInfo=1, GetGravity=1,
	GetAttribute=1, GetAttributes=1, GetTags=1, GetTagged=1, HasTag=1,
	IsStudio=1, IsRunMode=1, IsEdit=1, IsRunning=1,
	GetServerTimeNow=1, GetRealPhysicsFPS=1,
	-- Scripting queries
	GetScriptSource=1,
	-- Player queries
	GetPlayers=1, GetPlayerInfo=1, GetPlayerTeam=1, GetLeaderstatValue=1,
	GetCharacter=1, GetHumanoidState=1, GetAccessories=1,
	GetHumanoidDescription=1, GetPlayerPosition=1,
	-- Async queries
	GetDataStore=1, GetDataStoreValue=1,
}

-- Mutations that should NOT set ChangeHistory waypoints
-- (camera, runtime, datastore, meta-operations, ephemeral actions, physics)
local NO_WAYPOINT = {
	-- Camera (viewport-only, not persisted)
	SetCameraPosition=1, SetCameraTarget=1, SetCameraFocus=1, SetCameraType=1, ZoomCamera=1,
	-- History meta-operations
	Undo=1, Redo=1, RecordUndo=1,
	-- Runtime/ephemeral (not part of place state)
	PlaySound=1, StopSound=1, PlayAnimation=1, StopAnimation=1, LoadAnimation=1,
	Chat=1, EmitParticles=1,
	-- Player runtime actions (Player/Character are runtime-only objects)
	TeleportPlayer=1, KickPlayer=1, ChangeHumanoidState=1, TakeDamage=1,
	SetPlayerTeam=1, SetCharacterAppearance=1, AddAccessory=1, RemoveAccessories=1,
	CreateLeaderstat=1, SetLeaderstatValue=1,
	-- Physics runtime state (impulses and velocities are not persisted)
	ApplyImpulse=1, ApplyAngularImpulse=1, SetVelocity=1, SetAngularVelocity=1,
	-- Script source (ChangeHistoryService does not track .Source property changes)
	SetScriptSource=1, AppendToScript=1, ReplaceScriptLines=1, InsertScriptLines=1,
	-- Arbitrary code execution (unknown mutation scope)
	RunConsoleCommand=1,
	-- DataStore (external, not ChangeHistory-tracked)
	SetDataStoreValue=1, RemoveDataStoreValue=1,
	-- Networking (remote events/functions)
	FireRemoteEvent=1, InvokeRemoteFunction=1,
	-- Selection (UI state, not place state)
	SetSelection=1, ClearSelection=1, AddToSelection=1,
	-- Tweens (runtime animation)
	CreateTween=1, TweenProperty=1,
	-- Save (triggers async save, not undoable)
	SavePlace=1,
}

--- Extract a short summary from command params for display in history
local function getParamsSummary(method, params)
	-- SetProperty: show "path.property" (must check before generic path)
	if params.property and params.path then
		return params.path .. "." .. params.property
	end

	-- SetAttribute/RemoveAttribute: show "path: attrName"
	-- AddTag/RemoveTag: show "path: tag"
	if params.path and (params.name or params.tag) then
		return params.path .. ": " .. (params.tag or params.name)
	end

	local path = params.path
	if path then return path end

	local parentPath = params.parentPath
	if parentPath then
		local className = params.className
		if className then
			return parentPath .. " → " .. className
		end
		return parentPath
	end

	local className = params.className
	if className then return className end

	local name = params.name
	if name then return name end

	-- Constraint/weld paths
	if params.attachment0Path then return params.attachment0Path end
	if params.part0Path then return params.part0Path end

	-- Scalar value params (SetTimeOfDay, SetBrightness, SetGravity, etc.)
	if params.time then return tostring(params.time) end
	if params.material then return tostring(params.material) end
	if params.gravity then return tostring(params.gravity) end
	if params.brightness then return tostring(params.brightness) end
	if params.assetId then return tostring(params.assetId) end

	return nil
end

--------------------------------------------------------------------------------
-- State
--------------------------------------------------------------------------------

local ui = nil
local wsManager = nil

--------------------------------------------------------------------------------
-- UI Setup
--------------------------------------------------------------------------------

local toolbar = plugin:CreateToolbar("MCP Bridge")
local toggleButton = toolbar:CreateButton("MCP Toggle", "Toggle MCP Bridge UI", "rbxassetid://87958811949866")
toggleButton.ClickableWhenViewportHidden = true

local function updateButtonState()
	local state = wsManager and wsManager.getState() or {}
	toggleButton:SetActive(state.isEnabled and state.isConnected)
end

ui = UI.createWidget(plugin, {
	version = VERSION,
	onToggleConnection = function()
		if not wsManager then return end
		local state = wsManager.getState()
		local newEnabled = not state.isEnabled
		wsManager.setEnabled(newEnabled)
		if newEnabled then
			-- Starting connection attempt
			ui.setConnecting(true)
			wsManager.resetRetry()
		else
			-- Disconnecting
			ui.setConnectionState(false, "localhost", nil)
		end
	end,
})

toggleButton.Click:Connect(function()
	ui.toggle()
	updateButtonState()
end)

--------------------------------------------------------------------------------
-- Command Handler
--------------------------------------------------------------------------------

local function handleCommand(cmd)
	-- Validate command structure
	if type(cmd) ~= "table" or type(cmd.id) ~= "string" or type(cmd.method) ~= "string" then
		if wsManager and type(cmd) == "table" and cmd.id then
			wsManager.sendResult(cmd.id, false, nil, "Malformed command: missing id or method")
		end
		return
	end

	local method = cmd.method
	local handler = Tools[method]
	if not handler then
		wsManager.sendResult(cmd.id, false, nil, "Unknown method: " .. method)
		ui.addCommand({ method = method, success = false, error = "Unknown method" })
		return
	end

	local params = cmd.params or {}
	local summary = getParamsSummary(method, params)
	local isReadOnly = READONLY[method] ~= nil

	local success, result = pcall(handler, params)
	local hasWaypoint = false

	if success then
		-- Set undo waypoint for undoable mutations
		if not isReadOnly and not NO_WAYPOINT[method] then
			ChangeHistoryService:SetWaypoint("MCP " .. method)
			hasWaypoint = true
		end
		wsManager.sendResult(cmd.id, true, result, nil)
	else
		wsManager.sendResult(cmd.id, false, nil, tostring(result))
	end

	ui.addCommand({
		method = method,
		success = success,
		summary = summary,
		error = not success and tostring(result) or nil,
		hasWaypoint = hasWaypoint,
	})
end

--------------------------------------------------------------------------------
-- WebSocket Setup
--------------------------------------------------------------------------------

wsManager = WebSocket.create(CONFIG)

wsManager.setCallbacks({
	onConnected = function(port)
		ui.setConnectionState(true, "localhost", port)
		task.spawn(updateButtonState)
	end,
	onDisconnected = function()
		ui.setConnectionState(false, nil, nil)
		task.spawn(updateButtonState)
	end,
	onCommand = handleCommand,
	onError = function(code, message)
		if code == "VERSION_MISMATCH" then
			warn("[MCP] Version mismatch - please update plugin or server")
		end
	end,
})

wsManager.startLoop()
updateButtonState()

--------------------------------------------------------------------------------
-- Cleanup on Unload
--------------------------------------------------------------------------------

plugin.Unloading:Connect(function()
	if wsManager then
		wsManager.setEnabled(false)
		wsManager.disconnect()
	end
	if ui then
		ui.cleanup()
	end
end)

--------------------------------------------------------------------------------
-- Global
--------------------------------------------------------------------------------

_G.MCP_Version = VERSION
print("[MCP] Plugin loaded (v" .. VERSION .. ") - Click toolbar button to connect")
