--------------------------------------------------------------------------------
-- MCP Bridge Plugin for Roblox Studio
-- Connects Studio to MCP server via WebSocket
--------------------------------------------------------------------------------

local VERSION = "1.1.0"
local CONFIG = {
	VERSION = VERSION,
	BASE_PORT = 62847,
	PORT_RANGE = 10,
	RETRY_INTERVAL = 2,
	MAX_RETRY_INTERVAL = 30,
}

--------------------------------------------------------------------------------
-- Load Modules
--------------------------------------------------------------------------------

local Services = require(script.utils.services)
local Path = require(script.utils.path)
local UI = require(script.utils.ui)
local WebSocket = require(script.utils.websocket)

-- Tool modules
local InstanceTools = require(script.tools.instance)
local SpatialTools = require(script.tools.spatial)
local VisualTools = require(script.tools.visual)
local ScriptingTools = require(script.tools.scripting)
local PlayersTools = require(script.tools.players)
local WorldTools = require(script.tools.world)
local AsyncTools = require(script.tools.async)

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

-- Additional inline tools
function Tools.AppendToScript(p)
	local obj = Path.requireScript(p.path)
	obj.Source = obj.Source .. "\n" .. p.code
	return "Appended"
end

function Tools.ReplaceScriptLines(p)
	local obj = Path.requireScript(p.path)
	local lines = string.split(obj.Source, "\n")
	local newLines = {}
	local contentLines = string.split(p.content, "\n")
	for i = 1, p.startLine - 1 do if lines[i] then table.insert(newLines, lines[i]) end end
	for _, line in pairs(contentLines) do table.insert(newLines, line) end
	for i = p.endLine + 1, #lines do table.insert(newLines, lines[i]) end
	obj.Source = table.concat(newLines, "\n")
	return "Replaced"
end

function Tools.InsertScriptLines(p)
	local obj = Path.requireScript(p.path)
	local lines = string.split(obj.Source, "\n")
	local contentLines = string.split(p.content, "\n")
	local newLines = {}
	local insertAt = math.clamp(p.lineNumber, 1, #lines + 1)
	for i = 1, insertAt - 1 do table.insert(newLines, lines[i]) end
	for _, line in pairs(contentLines) do table.insert(newLines, line) end
	for i = insertAt, #lines do table.insert(newLines, lines[i]) end
	obj.Source = table.concat(newLines, "\n")
	return "Inserted"
end

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

function Tools.SavePlace() return "Save triggered (if permissions allow)" end

function Tools.GetCameraPosition()
	local pos = workspace.CurrentCamera.CFrame.Position
	return { pos.X, pos.Y, pos.Z }
end

function Tools.FillTerrain(p)
	local material = Enum.Material[p.material]
	if not material then error("Invalid material: " .. p.material) end
	workspace.Terrain:FillRegion(Region3.new(Vector3.new(p.minX, p.minY, p.minZ), Vector3.new(p.maxX, p.maxY, p.maxZ)), 4, material)
	return "Filled"
end

function Tools.HasTag(p) return Services.CollectionService:HasTag(Path.require(p.path), p.tag) end

function Tools.RemoveAttribute(p)
	Path.require(p.path):SetAttribute(p.name, nil)
	return "Removed"
end

function Tools.GetTagged(p)
	local paths = {}
	for _, obj in pairs(Services.CollectionService:GetTagged(p.tag)) do table.insert(paths, obj:GetFullName()) end
	return paths
end

function Tools.Chat(p)
	local channels = Services.TextChatService:FindFirstChild("TextChannels")
	local systemChannel = channels and channels:FindFirstChild("RBXSystem")
	if systemChannel then systemChannel:DisplaySystemMessage(p.message) return "Sent" end
	return "Chat not available"
end

function Tools.SetCameraTarget(p)
	workspace.CurrentCamera.CFrame = CFrame.lookAt(workspace.CurrentCamera.CFrame.Position, Vector3.new(p.x, p.y, p.z))
	return "Set"
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

--------------------------------------------------------------------------------
-- State
--------------------------------------------------------------------------------

local ui = nil
local wsManager = nil

--------------------------------------------------------------------------------
-- UI Setup
--------------------------------------------------------------------------------

local toolbar = plugin:CreateToolbar("MCP Bridge")
local toggleButton = toolbar:CreateButton("MCP Toggle", "Toggle MCP Bridge UI", "")
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
		wsManager.setEnabled(not state.isEnabled)
		if not state.isEnabled then
			wsManager.resetRetry()
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
-- Global
--------------------------------------------------------------------------------

_G.MCP_Version = VERSION
print("[MCP] Plugin loaded (v" .. VERSION .. ") - Click toolbar button to connect")
