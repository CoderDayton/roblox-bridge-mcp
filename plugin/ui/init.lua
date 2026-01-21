--------------------------------------------------------------------------------
-- UI Module
-- Main UI coordinator
--------------------------------------------------------------------------------

local Button = require(script.button)
local TitleBar = require(script.titlebar)
local StatusPanel = require(script.statuspanel)
local History = require(script.history)
local Settings = require(script.settings)

local ChangeHistoryService = game:GetService("ChangeHistoryService")

local COLORS = {
	bg = Color3.fromRGB(27, 27, 27),
}

local UI = {}

function UI.new(props)
	props = props or {}

	local plugin = props.plugin or error("plugin is required")
	local version = props.version or "1.0.0"
	local onReconnect = props.onReconnect or function() end
	local onRestart = props.onRestart or function() end
	local onSaveKey = props.onSaveKey or function() end
	local getCurrentKey = props.getCurrentKey or function() return "not set" end

	local widgetInfo = DockWidgetPluginGuiInfo.new(
		Enum.InitialDockState.Right,
		false,
		false,
		320,
		500,
		280,
		400
	)

	local widget = plugin:CreateDockWidgetPluginGui("MCPBridgeWidget", widgetInfo)
	widget.Title = "MCP Bridge"
	widget.Name = "MCPBridgeWidget"

	local container = Instance.new("Frame")
	container.Name = "Container"
	container.Size = UDim2.new(1, 0, 1, 0)
	container.BackgroundColor3 = COLORS.bg
	container.BorderSizePixel = 0
	container.Parent = widget

	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 8)
	padding.PaddingRight = UDim.new(0, 8)
	padding.PaddingTop = UDim.new(0, 8)
	padding.PaddingBottom = UDim.new(0, 8)
	padding.Parent = container

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 8)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = container

	-- Title
	local titleBar = TitleBar.new({ version = version })
	titleBar.LayoutOrder = 1
	titleBar.Parent = container

	-- Status
	local statusPanel = StatusPanel.new({})
	statusPanel.LayoutOrder = 2
	statusPanel.Parent = container

	-- Buttons (extra height for shadow)
	local buttonsFrame = Instance.new("Frame")
	buttonsFrame.Name = "Buttons"
	buttonsFrame.Size = UDim2.new(1, 0, 0, 76)
	buttonsFrame.BackgroundTransparency = 1
	buttonsFrame.LayoutOrder = 3
	buttonsFrame.Parent = container

	local btnLayout = Instance.new("UIGridLayout")
	btnLayout.CellSize = UDim2.new(0.48, 0, 0, 32)
	btnLayout.CellPadding = UDim2.new(0.04, 0, 0, 8)
	btnLayout.SortOrder = Enum.SortOrder.LayoutOrder
	btnLayout.Parent = buttonsFrame

	local undoBtn = Button.new({
		name = "Undo",
		text = "Undo",
		onClick = function()
			ChangeHistoryService:Undo()
		end,
	})
	undoBtn.LayoutOrder = 1
	undoBtn.Parent = buttonsFrame

	local redoBtn = Button.new({
		name = "Redo",
		text = "Redo",
		onClick = function()
			ChangeHistoryService:Redo()
		end,
	})
	redoBtn.LayoutOrder = 2
	redoBtn.Parent = buttonsFrame

	local reconnectBtn = Button.newPrimary({
		name = "Reconnect",
		text = "Reconnect",
		onClick = onReconnect,
	})
	reconnectBtn.LayoutOrder = 3
	reconnectBtn.Parent = buttonsFrame

	local restartBtn = Button.new({
		name = "Restart",
		text = "Restart",
		onClick = onRestart,
	})
	restartBtn.LayoutOrder = 4
	restartBtn.Parent = buttonsFrame

	-- Settings
	local settingsPanel = Settings.new({
		onSaveKey = onSaveKey,
		getCurrentKey = getCurrentKey,
	})
	settingsPanel.LayoutOrder = 4
	settingsPanel.Parent = container

	-- History
	local historyPanel = History.new({})
	historyPanel.LayoutOrder = 5
	historyPanel.Size = UDim2.new(1, 0, 1, -382)
	historyPanel.Parent = container

	-- API
	local api = {}
	api.widget = widget

	function api.show()
		widget.Enabled = true
	end

	function api.hide()
		widget.Enabled = false
	end

	function api.toggle()
		widget.Enabled = not widget.Enabled
	end

	function api.setConnectionState(connected, host, port)
		titleBar:SetConnectionState(connected and "connected" or "disconnected")
		statusPanel.SetConnection(connected, host, port)
	end

	function api.addCommand(method, success)
		historyPanel.AddEntry(method, success and "success" or "error")
		statusPanel.SetCommandCount(statusPanel.GetCommandCount() + 1)
	end

	function api.clearHistory()
		historyPanel.Clear()
	end

	return api
end

return UI
