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

	local handler = Tools[cmd.method]
	if not handler then
		wsManager.sendResult(cmd.id, false, nil, "Unknown method: " .. cmd.method)
		ui.addCommand(cmd.method, false)
		return
	end

	local success, result = pcall(handler, cmd.params or {})
	if success then
		wsManager.sendResult(cmd.id, true, result, nil)
		ui.addCommand(cmd.method, true)
	else
		wsManager.sendResult(cmd.id, false, nil, tostring(result))
		ui.addCommand(cmd.method, false)
	end
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
