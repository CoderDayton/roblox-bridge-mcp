--!optimize 2
--------------------------------------------------------------------------------
-- Main Widget
-- Composes all UI components with 8-point grid alignment
--------------------------------------------------------------------------------

local os_clock = os.clock
local math_floor = math.floor

local Theme = require(script.Parent.theme)
local Store = require(script.Parent.store)
local Header = require(script.Parent.components.header)
local StatusCard = require(script.Parent.components["status-card"])
local StatsPanel = require(script.Parent.components["stats-panel"])
local ConnectButton = require(script.Parent.components["connect-button"])
local ActionButtons = require(script.Parent.components["action-buttons"])
local HistoryPanel = require(script.Parent.components["history-panel"])

local Widget = {}

function Widget.create(pluginRef, props)
	local version = props.version or "1.0.0"

	-- Create dock widget (min 280px width for usability)
	local widgetInfo = DockWidgetPluginGuiInfo.new(
		Enum.InitialDockState.Right, false, false, 300, 480, 280, 400
	)
	local widget = pluginRef:CreateDockWidgetPluginGui("MCPBridgeWidget", widgetInfo)
	widget.Title = "MCP Bridge"
	widget.Name = "MCPBridgeWidget"

	-- State store
	local store = Store.create({
		activeTab = "Home",
		connected = false,
		isConnecting = false,
		host = "localhost",
		port = "-",
	})

	----------------------------------------------------------------------------
	-- Main Container
	----------------------------------------------------------------------------
	local container = Instance.new("Frame")
	container.Name = "Container"
	container.Size = UDim2.new(1, 0, 1, 0)
	container.BackgroundColor3 = Theme.COLORS.bgBase
	container.BorderSizePixel = 0
	container.Parent = widget

	-- Container padding (8px = 1 grid unit)
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, Theme.SPACING.sm)
	padding.PaddingRight = UDim.new(0, Theme.SPACING.sm)
	padding.PaddingTop = UDim.new(0, Theme.SPACING.sm)
	padding.PaddingBottom = UDim.new(0, Theme.SPACING.sm)
	padding.Parent = container

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, Theme.SPACING.sm)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = container

	----------------------------------------------------------------------------
	-- Header (40px)
	----------------------------------------------------------------------------
	local header = Header.create(pluginRef, {
		title = "MCP Bridge",
		tabs = {
			{ name = "Home" },
			{ name = "History" },
		},
		onTabChange = function(tabName)
			store:set({ activeTab = tabName })
		end,
	})
	header.frame.LayoutOrder = 1
	header.frame.Parent = container

	----------------------------------------------------------------------------
	-- Home Tab Content
	----------------------------------------------------------------------------
	local homeContent = Instance.new("Frame")
	homeContent.Name = "HomeContent"
	homeContent.Size = UDim2.new(1, 0, 1, -56) -- Full height minus header + spacing
	homeContent.BackgroundTransparency = 1
	homeContent.LayoutOrder = 2
	homeContent.Parent = container

	local homeLayout = Instance.new("UIListLayout")
	homeLayout.Padding = UDim.new(0, Theme.SPACING.sm)
	homeLayout.SortOrder = Enum.SortOrder.LayoutOrder
	homeLayout.Parent = homeContent

	-- Status Card (88px)
	local statusCard = StatusCard.create({ version = version })
	statusCard.frame.LayoutOrder = 1
	statusCard.frame.Parent = homeContent

	-- Stats Panel (64px)
	local statsPanel = StatsPanel.create()
	statsPanel.frame.LayoutOrder = 2
	statsPanel.frame.Parent = homeContent

	-- Connect Button (48px)
	local connectButton = ConnectButton.create(pluginRef, {
		onClick = function()
			if props.onToggleConnection then
				props.onToggleConnection()
			end
		end,
	})
	connectButton.frame.LayoutOrder = 3
	connectButton.frame.Parent = homeContent

	-- Action Buttons (40px)
	local actionButtons = ActionButtons.create(pluginRef)
	actionButtons.frame.LayoutOrder = 4
	actionButtons.frame.Parent = homeContent

	----------------------------------------------------------------------------
	-- History Tab Content
	----------------------------------------------------------------------------
	local historyPanel = HistoryPanel.create(pluginRef)
	historyPanel.frame.LayoutOrder = 3
	historyPanel.frame.Visible = false
	historyPanel.frame.Parent = container

	----------------------------------------------------------------------------
	-- State Subscriptions
	----------------------------------------------------------------------------

	-- Tab visibility
	store:subscribe(function(changed, state)
		if changed.activeTab then
			local isHome = state.activeTab == "Home"
			homeContent.Visible = isHome
			historyPanel.frame.Visible = not isHome
			header.setActiveTab(state.activeTab)
		end
	end)

	-- Connection state updates
	store:subscribe(function(changed, state)
		if changed.connected ~= nil or changed.isConnecting ~= nil or changed.host or changed.port then
			statusCard.update(state)
			connectButton.update(state)
		end
	end)

	-- Uptime ticker (tracks connection duration, not plugin lifetime)
	local connectedAt = nil -- os_clock() timestamp when connection established

	store:subscribe(function(changed, state)
		if changed.connected ~= nil then
			if state.connected then
				connectedAt = os_clock()
			else
				connectedAt = nil
				statsPanel.setUptime("00:00:00")
			end
		end
	end)

	task.spawn(function()
		while true do
			local start = connectedAt
			if start then
				local elapsed = math_floor(os_clock() - start)
				local h = math_floor(elapsed / 3600)
				local m = math_floor((elapsed % 3600) / 60)
				local s = elapsed % 60
				statsPanel.setUptime(string.format("%02d:%02d:%02d", h, m, s))
			end
			task.wait(1)
		end
	end)

	----------------------------------------------------------------------------
	-- Public API
	----------------------------------------------------------------------------
	local api = {
		widget = widget,
	}

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
		store:set({
			connected = connected,
			isConnecting = false,
			host = host or "localhost",
			port = port or "-",
		})
	end

	function api.setConnecting(isConnecting)
		store:set({ isConnecting = isConnecting })
	end

	function api.addCommand(data)
		local count = historyPanel.addEntry(data)
		statsPanel.setCommands(count)
	end

	function api.clearHistory()
		historyPanel.clear()
		statsPanel.setCommands(0)
	end

	function api.cleanup()
		store:cleanup()
		widget:Destroy()
	end

	return api
end

return Widget
