--!optimize 2
-- UI Components and Widget Creation

-- Localize globals for performance
local pairs = pairs
local ipairs = ipairs
local next = next
local tostring = tostring
local os_time = os.time
local os_date = os.date
local math_floor = math.floor
local table_insert = table.insert
local table_remove = table.remove
local tick = tick

local Services = require(script.Parent.services)

-- Cache TweenService for frequent use
local TweenService = Services.TweenService

local UI = {}

--------------------------------------------------------------------------------
-- Theme
--------------------------------------------------------------------------------

UI.COLORS = {
	bg = Color3.fromRGB(27, 27, 27),
	panelBg = Color3.fromRGB(32, 32, 32),
	titleBg = Color3.fromRGB(37, 37, 37),
	btnBg = Color3.fromRGB(50, 50, 50),
	btnHover = Color3.fromRGB(60, 60, 60),
	btnActive = Color3.fromRGB(45, 45, 45),
	primary = Color3.fromRGB(56, 139, 253),
	primaryHover = Color3.fromRGB(88, 166, 255),
	primaryActive = Color3.fromRGB(47, 129, 242),
	text = Color3.fromRGB(230, 230, 230),
	textDim = Color3.fromRGB(140, 140, 140),
	textDimmer = Color3.fromRGB(110, 110, 110),
	connected = Color3.fromRGB(63, 185, 80),
	disconnected = Color3.fromRGB(218, 54, 51),
	success = Color3.fromRGB(63, 185, 80),
	error = Color3.fromRGB(218, 54, 51),
	shadow = Color3.fromRGB(0, 0, 0),
	entryBg = Color3.fromRGB(40, 40, 40),
	entryBgHover = Color3.fromRGB(48, 48, 48),
	scrollbar = Color3.fromRGB(70, 70, 70),
}

UI.TWEENS = {
	info = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
	fast = TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
	medium = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
	slow = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
}

UI.FONTS = {
	Bold = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Bold),
	Medium = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Medium),
	Regular = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Regular),
}

--------------------------------------------------------------------------------
-- Reactive Store
--------------------------------------------------------------------------------

function UI.createStore(initialState)
	local state = {}
	local listeners = {}
	for key, value in pairs(initialState) do state[key] = value end

	local store = {}
	function store:get(key) return state[key] end
	function store:getState()
		local copy = {}
		for k, v in pairs(state) do copy[k] = v end
		return copy
	end
	function store:set(updates)
		local changed = {}
		for key, value in pairs(updates) do
			if state[key] ~= value then
				state[key] = value
				changed[key] = value
			end
		end
		if next(changed) then
			for _, listener in ipairs(listeners) do listener(changed, state) end
		end
	end
	function store:subscribe(listener)
		table_insert(listeners, listener)
		return function()
			for i, l in ipairs(listeners) do
				if l == listener then table_remove(listeners, i) break end
			end
		end
	end
	return store
end

--------------------------------------------------------------------------------
-- Button Component
--------------------------------------------------------------------------------

function UI.createButton(pluginRef, props)
	local text = props.text or "Button"
	local onClick = props.onClick or function() end
	local primary = props.primary or false

	local container = Instance.new("Frame")
	container.Name = props.name or "Button"
	container.Size = props.size or UDim2.new(1, 0, 0, 32)
	container.BackgroundTransparency = 1

	local shadow = Instance.new("Frame")
	shadow.Name = "Shadow"
	shadow.Size = UDim2.new(1, 0, 1, 0)
	shadow.Position = UDim2.new(0, 0, 0, 3)
	shadow.BackgroundColor3 = UI.COLORS.shadow
	shadow.BackgroundTransparency = 0.85
	shadow.BorderSizePixel = 0
	shadow.ZIndex = 1
	shadow.Parent = container

	local shadowCorner = Instance.new("UICorner")
	shadowCorner.CornerRadius = UDim.new(0, 6)
	shadowCorner.Parent = shadow

	local btn = Instance.new("TextButton")
	btn.Name = "Btn"
	btn.Size = UDim2.new(1, 0, 1, 0)
	btn.BackgroundColor3 = primary and UI.COLORS.primary or UI.COLORS.btnBg
	btn.BorderSizePixel = 0
	btn.Text = text
	btn.TextColor3 = UI.COLORS.text
	btn.TextSize = 18
	btn.FontFace = UI.FONTS.Medium
	btn.AutoButtonColor = false
	btn.ZIndex = 2
	btn.Parent = container

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = btn

	local baseColor = primary and UI.COLORS.primary or UI.COLORS.btnBg
	local hoverColor = primary and UI.COLORS.primaryHover or UI.COLORS.btnHover
	local activeColor = primary and UI.COLORS.primaryActive or UI.COLORS.btnActive

	-- Cache tween info for reuse
	local tweenInfo = UI.TWEENS.info
	local tweenFast = UI.TWEENS.fast

	btn.MouseEnter:Connect(function()
		pluginRef:GetMouse().Icon = "rbxasset://SystemCursors/PointingHand"
		TweenService:Create(btn, tweenInfo, { BackgroundColor3 = hoverColor }):Play()
	end)

	btn.MouseLeave:Connect(function()
		pluginRef:GetMouse().Icon = ""
		TweenService:Create(btn, tweenInfo, { BackgroundColor3 = baseColor }):Play()
		TweenService:Create(btn, tweenInfo, { Position = UDim2.new(0, 0, 0, 0) }):Play()
		TweenService:Create(shadow, tweenInfo, { Position = UDim2.new(0, 0, 0, 3), BackgroundTransparency = 0.85 }):Play()
	end)

	btn.MouseButton1Down:Connect(function()
		TweenService:Create(btn, tweenFast, { BackgroundColor3 = activeColor, Position = UDim2.new(0, 0, 0, 2) }):Play()
		TweenService:Create(shadow, tweenFast, { Position = UDim2.new(0, 0, 0, 1), BackgroundTransparency = 0.92 }):Play()
	end)

	btn.MouseButton1Up:Connect(function()
		TweenService:Create(btn, tweenInfo, { BackgroundColor3 = hoverColor, Position = UDim2.new(0, 0, 0, 0) }):Play()
		TweenService:Create(shadow, tweenInfo, { Position = UDim2.new(0, 0, 0, 3), BackgroundTransparency = 0.85 }):Play()
		onClick()
	end)

	return container
end

--------------------------------------------------------------------------------
-- Main Widget
--------------------------------------------------------------------------------

function UI.createWidget(pluginRef, props)
	local startTime = os_time()
	local version = props.version or "1.0.0"
	local entryCount = 0

	-- Cache tween info for reuse throughout widget
	local tweenSlow = UI.TWEENS.slow
	local tweenMedium = UI.TWEENS.medium

	local widgetInfo = DockWidgetPluginGuiInfo.new(
		Enum.InitialDockState.Right, false, false, 320, 500, 280, 400
	)
	local widget = pluginRef:CreateDockWidgetPluginGui("MCPBridgeWidget", widgetInfo)
	widget.Title = "MCP Bridge"
	widget.Name = "MCPBridgeWidget"

	local uiStore = UI.createStore({
		connected = false,
		host = "localhost",
		port = "-",
		commands = 0,
		uptime = "00:00:00",
	})

	local container = Instance.new("Frame")
	container.Name = "Container"
	container.Size = UDim2.new(1, 0, 1, 0)
	container.BackgroundColor3 = UI.COLORS.bg
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

	-- Title Bar
	local titleBar = Instance.new("Frame")
	titleBar.Name = "TitleBar"
	titleBar.Size = UDim2.new(1, 0, 0, 36)
	titleBar.BackgroundColor3 = UI.COLORS.titleBg
	titleBar.BorderSizePixel = 0
	titleBar.LayoutOrder = 1
	titleBar.Parent = container

	local titleCorner = Instance.new("UICorner")
	titleCorner.CornerRadius = UDim.new(0, 6)
	titleCorner.Parent = titleBar

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(0, 90, 1, 0)
	title.Position = UDim2.new(0, 12, 0, 0)
	title.BackgroundTransparency = 1
	title.Text = "MCP Bridge"
	title.TextColor3 = UI.COLORS.text
	title.TextSize = 20
	title.FontFace = UI.FONTS.Bold
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Parent = titleBar

	local versionLabel = Instance.new("TextLabel")
	versionLabel.Size = UDim2.new(0, 50, 1, 0)
	versionLabel.Position = UDim2.new(0, 100, 0, 0)
	versionLabel.BackgroundTransparency = 1
	versionLabel.Text = "v" .. version
	versionLabel.TextColor3 = UI.COLORS.textDim
	versionLabel.TextSize = 16
	versionLabel.FontFace = UI.FONTS.Regular
	versionLabel.TextXAlignment = Enum.TextXAlignment.Left
	versionLabel.Parent = titleBar

	-- Status Panel
	local statusPanel = Instance.new("Frame")
	statusPanel.Name = "StatusPanel"
	statusPanel.Size = UDim2.new(1, 0, 0, 140)
	statusPanel.BackgroundColor3 = UI.COLORS.panelBg
	statusPanel.BorderSizePixel = 0
	statusPanel.LayoutOrder = 2
	statusPanel.Parent = container

	local statusCorner = Instance.new("UICorner")
	statusCorner.CornerRadius = UDim.new(0, 6)
	statusCorner.Parent = statusPanel

	local indicator = Instance.new("Frame")
	indicator.Size = UDim2.new(0, 10, 0, 10)
	indicator.Position = UDim2.new(1, -22, 0, 23)
	indicator.AnchorPoint = Vector2.new(0, 0.5)
	indicator.BackgroundColor3 = UI.COLORS.disconnected
	indicator.BorderSizePixel = 0
	indicator.Parent = statusPanel

	local indicatorCorner = Instance.new("UICorner")
	indicatorCorner.CornerRadius = UDim.new(0.5, 0)
	indicatorCorner.Parent = indicator

	local metrics = {}
	local labels = {
		{ "Status", "Disconnected", 12 },
		{ "Host", "localhost", 36 },
		{ "Port", "-", 60 },
		{ "Commands", "0", 84 },
		{ "Uptime", "00:00:00", 108 },
	}

	for _, data in ipairs(labels) do
		local row = Instance.new("Frame")
		row.Size = UDim2.new(1, -24, 0, 24)
		row.Position = UDim2.new(0, 12, 0, data[3])
		row.BackgroundTransparency = 1
		row.Parent = statusPanel

		local labelText = Instance.new("TextLabel")
		labelText.Size = UDim2.new(0.5, 0, 1, 0)
		labelText.BackgroundTransparency = 1
		labelText.Text = data[1]
		labelText.TextColor3 = UI.COLORS.textDim
		labelText.TextSize = 16
		labelText.FontFace = UI.FONTS.Regular
		labelText.TextXAlignment = Enum.TextXAlignment.Left
		labelText.Parent = row

		local valueText = Instance.new("TextLabel")
		valueText.Size = UDim2.new(0.5, -20, 1, 0)
		valueText.Position = UDim2.new(0.5, 0, 0, 0)
		valueText.BackgroundTransparency = 1
		valueText.Text = data[2]
		valueText.TextColor3 = UI.COLORS.text
		valueText.TextSize = 16
		valueText.FontFace = UI.FONTS.Medium
		valueText.TextXAlignment = Enum.TextXAlignment.Right
		valueText.Parent = row

		metrics[data[1]] = valueText
	end

	metrics["Status"].TextColor3 = UI.COLORS.disconnected

	uiStore:subscribe(function(changed, state)
		if changed.connected ~= nil then
			local color = state.connected and UI.COLORS.connected or UI.COLORS.disconnected
			TweenService:Create(indicator, tweenSlow, { BackgroundColor3 = color }):Play()
			metrics["Status"].Text = state.connected and "Connected" or "Disconnected"
			TweenService:Create(metrics["Status"], tweenSlow, { TextColor3 = color }):Play()
		end
		if changed.host then metrics["Host"].Text = state.host end
		if changed.port then metrics["Port"].Text = tostring(state.port) end
		if changed.commands then metrics["Commands"].Text = tostring(state.commands) end
		if changed.uptime then metrics["Uptime"].Text = state.uptime end
	end)

	Services.RunService.Heartbeat:Connect(function()
		local elapsed = tick() - startTime
		local h = math_floor(elapsed / 3600)
		local m = math_floor((elapsed % 3600) / 60)
		local s = math_floor(elapsed % 60)
		metrics["Uptime"].Text = string.format("%02d:%02d:%02d", h, m, s)
	end)

	-- Buttons
	local buttonsFrame = Instance.new("Frame")
	buttonsFrame.Name = "Buttons"
	buttonsFrame.Size = UDim2.new(1, 0, 0, 84)
	buttonsFrame.BackgroundTransparency = 1
	buttonsFrame.LayoutOrder = 3
	buttonsFrame.Parent = container

	local btnLayout = Instance.new("UIGridLayout")
	btnLayout.CellSize = UDim2.new(0.48, 0, 0, 36)
	btnLayout.CellPadding = UDim2.new(0.04, 0, 0, 8)
	btnLayout.SortOrder = Enum.SortOrder.LayoutOrder
	btnLayout.Parent = buttonsFrame

	local undoBtn = UI.createButton(pluginRef, {
		name = "Undo", text = "Undo",
		onClick = function() pcall(function() Services.ChangeHistoryService:Undo() end) end,
	})
	undoBtn.LayoutOrder = 1
	undoBtn.Parent = buttonsFrame

	local redoBtn = UI.createButton(pluginRef, {
		name = "Redo", text = "Redo",
		onClick = function() pcall(function() Services.ChangeHistoryService:Redo() end) end,
	})
	redoBtn.LayoutOrder = 2
	redoBtn.Parent = buttonsFrame

	local toggleBtn
	local lastClickTime = 0
	local DEBOUNCE_TIME = 0.5

	toggleBtn = UI.createButton(pluginRef, {
		name = "ToggleConnection", text = "Connect", primary = true,
		onClick = function()
			local now = tick()
			if now - lastClickTime < DEBOUNCE_TIME then return end
			lastClickTime = now
			if props.onToggleConnection then props.onToggleConnection() end
		end,
	})
	toggleBtn.LayoutOrder = 3
	toggleBtn.Parent = buttonsFrame

	uiStore:subscribe(function(changed, state)
		if changed.connected ~= nil then
			local btn = toggleBtn:FindFirstChild("Btn")
			if btn then btn.Text = state.connected and "Disconnect" or "Connect" end
		end
	end)

	-- History Panel
	local historyPanel = Instance.new("Frame")
	historyPanel.Name = "HistoryPanel"
	historyPanel.Size = UDim2.new(1, 0, 1, -286)
	historyPanel.BackgroundColor3 = UI.COLORS.panelBg
	historyPanel.BorderSizePixel = 0
	historyPanel.LayoutOrder = 4
	historyPanel.Parent = container

	local historyCorner = Instance.new("UICorner")
	historyCorner.CornerRadius = UDim.new(0, 6)
	historyCorner.Parent = historyPanel

	local header = Instance.new("TextLabel")
	header.Size = UDim2.new(1, -24, 0, 30)
	header.Position = UDim2.new(0, 12, 0, 0)
	header.BackgroundTransparency = 1
	header.Text = "History"
	header.TextColor3 = UI.COLORS.textDim
	header.TextSize = 16
	header.FontFace = UI.FONTS.Medium
	header.TextXAlignment = Enum.TextXAlignment.Left
	header.Parent = historyPanel

	local scrollFrame = Instance.new("ScrollingFrame")
	scrollFrame.Size = UDim2.new(1, -16, 1, -40)
	scrollFrame.Position = UDim2.new(0, 8, 0, 36)
	scrollFrame.BackgroundTransparency = 1
	scrollFrame.BorderSizePixel = 0
	scrollFrame.ScrollBarThickness = 4
	scrollFrame.ScrollBarImageColor3 = UI.COLORS.scrollbar
	scrollFrame.ScrollingDirection = Enum.ScrollingDirection.Y
	scrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
	scrollFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scrollFrame.Parent = historyPanel

	local historyLayout = Instance.new("UIListLayout")
	historyLayout.Padding = UDim.new(0, 4)
	historyLayout.Parent = scrollFrame

	local historyList = {}

	-- API
	local api = {}
	api.widget = widget

	function api.show() widget.Enabled = true end
	function api.hide() widget.Enabled = false end
	function api.toggle() widget.Enabled = not widget.Enabled end

	function api.setConnectionState(connected, host, port)
		uiStore:set({ connected = connected, host = host or "localhost", port = port or "-" })
	end

	function api.addCommand(method, success)
		local timestamp = os_date("%H:%M:%S")

		local entry = Instance.new("Frame")
		entry.Name = "Entry" .. entryCount
		entry.Size = UDim2.new(1, -4, 0, 32)
		entry.BackgroundColor3 = UI.COLORS.entryBg
		entry.BackgroundTransparency = 1
		entry.BorderSizePixel = 0

		local entryCorner = Instance.new("UICorner")
		entryCorner.CornerRadius = UDim.new(0, 4)
		entryCorner.Parent = entry

		local statusBar = Instance.new("Frame")
		statusBar.Size = UDim2.new(0, 3, 1, -8)
		statusBar.Position = UDim2.new(0, 0, 0, 4)
		statusBar.BackgroundColor3 = success and UI.COLORS.success or UI.COLORS.error
		statusBar.BorderSizePixel = 0
		statusBar.Parent = entry

		local barCorner = Instance.new("UICorner")
		barCorner.CornerRadius = UDim.new(0, 2)
		barCorner.Parent = statusBar

		local methodLabel = Instance.new("TextLabel")
		methodLabel.Size = UDim2.new(1, -70, 1, 0)
		methodLabel.Position = UDim2.new(0, 10, 0, 0)
		methodLabel.BackgroundTransparency = 1
		methodLabel.Text = method
		methodLabel.TextColor3 = UI.COLORS.text
		methodLabel.TextSize = 16
		methodLabel.FontFace = UI.FONTS.Medium
		methodLabel.TextXAlignment = Enum.TextXAlignment.Left
		methodLabel.TextTruncate = Enum.TextTruncate.AtEnd
		methodLabel.Parent = entry

		local timeLabel = Instance.new("TextLabel")
		timeLabel.Size = UDim2.new(0, 55, 1, 0)
		timeLabel.Position = UDim2.new(1, -60, 0, 0)
		timeLabel.BackgroundTransparency = 1
		timeLabel.Text = timestamp
		timeLabel.TextColor3 = UI.COLORS.textDimmer
		timeLabel.TextSize = 14
		timeLabel.FontFace = UI.FONTS.Regular
		timeLabel.TextXAlignment = Enum.TextXAlignment.Right
		timeLabel.Parent = entry

		entry.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseMovement then
				TweenService:Create(entry, tweenMedium, { BackgroundColor3 = UI.COLORS.entryBgHover, BackgroundTransparency = 0 }):Play()
			end
		end)

		entry.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseMovement then
				TweenService:Create(entry, tweenMedium, { BackgroundTransparency = 1 }):Play()
			end
		end)

		table_insert(historyList, 1, entry)
		entry.LayoutOrder = -entryCount
		entry.Parent = scrollFrame
		entryCount = entryCount + 1

		while #historyList > 100 do
			local old = table_remove(historyList)
			if old then old:Destroy() end
		end

		uiStore:set({ commands = entryCount })
	end

	function api.clearHistory()
		for _, entry in ipairs(historyList) do entry:Destroy() end
		historyList = {}
		entryCount = 0
	end

	task.spawn(function()
		while true do
			local elapsed = os_time() - startTime
			local h = math_floor(elapsed / 3600)
			local m = math_floor((elapsed % 3600) / 60)
			local s = elapsed % 60
			uiStore:set({ uptime = string.format("%02d:%02d:%02d", h, m, s) })
			task.wait(1)
		end
	end)

	return api
end

return UI
