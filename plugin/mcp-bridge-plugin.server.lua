--------------------------------------------------------------------------------
-- MCP Bridge Plugin for Roblox Studio (Single File Distribution)
-- Connects Studio to MCP server via HTTP polling with polished UI
--------------------------------------------------------------------------------

-- Services
local ChangeHistoryService = game:GetService("ChangeHistoryService")
local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local HttpService = game:GetService("HttpService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Selection = game:GetService("Selection")
local SoundService = game:GetService("SoundService")
local StudioService = game:GetService("StudioService")
local TextChatService = game:GetService("TextChatService")
local TweenService = game:GetService("TweenService")

--------------------------------------------------------------------------------
-- Configuration
--------------------------------------------------------------------------------

local VERSION = "1.0.0"

local CONFIG = {
	BASE_PORT = 53847,
	RETRY_INTERVAL = 2,
	MAX_RETRY_INTERVAL = 10,
	USE_LONG_POLL = true,
}

--------------------------------------------------------------------------------
-- State
--------------------------------------------------------------------------------

local isConnected = false
local isEnabled = true
local retryInterval = CONFIG.RETRY_INTERVAL
local activePort = nil
local serverUrl = nil
local apiKey = nil
local ui = nil

--------------------------------------------------------------------------------
-- UI Components (Inlined)
--------------------------------------------------------------------------------

local COLORS = {
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
	inputBg = Color3.fromRGB(40, 40, 40),
	inputBgFocus = Color3.fromRGB(45, 45, 45),
	border = Color3.fromRGB(55, 55, 55),
	borderFocus = Color3.fromRGB(56, 139, 253),
	placeholder = Color3.fromRGB(90, 90, 90),
	entryBg = Color3.fromRGB(40, 40, 40),
	entryBgHover = Color3.fromRGB(48, 48, 48),
	scrollbar = Color3.fromRGB(70, 70, 70),
}

local TWEEN_INFO = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local TWEEN_FAST = TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local TWEEN_MEDIUM = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local TWEEN_SLOW = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

-- Cached fonts
local FONTS = {
	Bold = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Bold),
	Medium = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Medium),
	Regular = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Regular),
	Mono = Font.new("rbxasset://fonts/families/RobotoMono.json", Enum.FontWeight.Regular),
}

-- Cached UDim values
local UDIM_CORNER_6 = UDim.new(0, 6)
local UDIM_CORNER_4 = UDim.new(0, 4)
local UDIM_CORNER_2 = UDim.new(0, 2)
local UDIM_HALF = UDim.new(0.5, 0)

-- Button Component
local function createButton(props)
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
	shadow.BackgroundColor3 = COLORS.shadow
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
	btn.Position = UDim2.new(0, 0, 0, 0)
	btn.BackgroundColor3 = primary and COLORS.primary or COLORS.btnBg
	btn.BorderSizePixel = 0
	btn.Text = text
	btn.TextColor3 = COLORS.text
	btn.TextSize = 18
	btn.FontFace = FONTS.Medium
	btn.AutoButtonColor = false
	btn.ZIndex = 2
	btn.Parent = container

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = btn

	local baseColor = primary and COLORS.primary or COLORS.btnBg
	local hoverColor = primary and COLORS.primaryHover or COLORS.btnHover
	local activeColor = primary and COLORS.primaryActive or COLORS.btnActive

	btn.MouseEnter:Connect(function()
		plugin:GetMouse().Icon = "rbxasset://SystemCursors/PointingHand"
		TweenService:Create(btn, TWEEN_INFO, { BackgroundColor3 = hoverColor }):Play()
	end)

	btn.MouseLeave:Connect(function()
		plugin:GetMouse().Icon = ""
		TweenService:Create(btn, TWEEN_INFO, { BackgroundColor3 = baseColor }):Play()
		TweenService:Create(btn, TWEEN_INFO, { Position = UDim2.new(0, 0, 0, 0) }):Play()
		TweenService:Create(shadow, TWEEN_INFO, { Position = UDim2.new(0, 0, 0, 3), BackgroundTransparency = 0.85 }):Play()
	end)

	btn.MouseButton1Down:Connect(function()
		TweenService:Create(btn, TWEEN_FAST, { BackgroundColor3 = activeColor, Position = UDim2.new(0, 0, 0, 2) }):Play()
		TweenService:Create(shadow, TWEEN_FAST, { Position = UDim2.new(0, 0, 0, 1), BackgroundTransparency = 0.92 }):Play()
	end)

	btn.MouseButton1Up:Connect(function()
		TweenService:Create(btn, TWEEN_INFO, { BackgroundColor3 = hoverColor, Position = UDim2.new(0, 0, 0, 0) }):Play()
		TweenService:Create(shadow, TWEEN_INFO, { Position = UDim2.new(0, 0, 0, 3), BackgroundTransparency = 0.85 }):Play()
		onClick()
	end)

	return container
end

--------------------------------------------------------------------------------
-- Reactive Store (State Management)
--------------------------------------------------------------------------------

local function createStore(initialState)
	local state = {}
	local listeners = {}
	
	-- Copy initial state
	for key, value in pairs(initialState) do
		state[key] = value
	end
	
	local store = {}
	
	-- Get current state value
	function store:get(key)
		return state[key]
	end
	
	-- Get entire state
	function store:getState()
		local copy = {}
		for k, v in pairs(state) do
			copy[k] = v
		end
		return copy
	end
	
	-- Set state value(s) and notify listeners
	function store:set(updates)
		local changed = {}
		
		for key, value in pairs(updates) do
			if state[key] ~= value then
				state[key] = value
				changed[key] = value
			end
		end
		
		-- Notify all listeners of changes
		if next(changed) then
			for _, listener in pairs(listeners) do
				listener(changed, state)
			end
		end
	end
	
	-- Subscribe to state changes
	function store:subscribe(listener)
		table.insert(listeners, listener)
		
		-- Return unsubscribe function
		return function()
			for i, l in pairs(listeners) do
				if l == listener then
					table.remove(listeners, i)
					break
				end
			end
		end
	end
	
	return store
end

-- Create UI
local function createUI(props)
	local startTime = os.time()
	local version = props.version or "1.0.0"
	local onReconnect = props.onReconnect or function() end
	local onRestart = props.onRestart or function() end
	local entryCount = 0
	local maxEntries = 100

	-- Create the dock widget using modern Roblox API
	local widgetInfo = DockWidgetPluginGuiInfo.new(
		Enum.InitialDockState.Right,  -- Dock to right side
		false,  -- Initially disabled (hidden)
		false,  -- Don't override saved state
		320,    -- Default width
		500,    -- Default height
		280,    -- Minimum width
		400     -- Minimum height
	)
	
	local widget = plugin:CreateDockWidgetPluginGui("MCPBridgeWidget", widgetInfo)
	widget.Title = "MCP Bridge"
	widget.Name = "MCPBridgeWidget"

	-- Create reactive store for UI state
	local uiStore = createStore({
		connected = false,
		host = "localhost",
		port = "-",
		commands = 0,
		uptime = "00:00:00",
		apiKey = props.getCurrentKey(),
	})

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

	-- Title Bar
	local titleBar = Instance.new("Frame")
	titleBar.Name = "TitleBar"
	titleBar.Size = UDim2.new(1, 0, 0, 36)
	titleBar.BackgroundColor3 = COLORS.titleBg
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
	title.TextColor3 = COLORS.text
	title.TextSize = 20
	title.FontFace = FONTS.Bold
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Parent = titleBar

	local versionLabel = Instance.new("TextLabel")
	versionLabel.Size = UDim2.new(0, 50, 1, 0)
	versionLabel.Position = UDim2.new(0, 100, 0, 0)
	versionLabel.BackgroundTransparency = 1
	versionLabel.Text = "v" .. version
	versionLabel.TextColor3 = COLORS.textDim
	versionLabel.TextSize = 16
	versionLabel.FontFace = FONTS.Regular
	versionLabel.TextXAlignment = Enum.TextXAlignment.Left
	versionLabel.Parent = titleBar

	-- Status Panel
	local statusPanel = Instance.new("Frame")
	statusPanel.Name = "StatusPanel"
	statusPanel.Size = UDim2.new(1, 0, 0, 140)
	statusPanel.BackgroundColor3 = COLORS.panelBg
	statusPanel.BorderSizePixel = 0
	statusPanel.LayoutOrder = 2
	statusPanel.Parent = container

	local statusCorner = Instance.new("UICorner")
	statusCorner.CornerRadius = UDim.new(0, 6)
	statusCorner.Parent = statusPanel

	-- Status indicator (moved from title bar) - centered vertically in first row
	local indicator = Instance.new("Frame")
	indicator.Size = UDim2.new(0, 10, 0, 10)
	indicator.Position = UDim2.new(1, -22, 0, 23)
	indicator.AnchorPoint = Vector2.new(0, 0.5)
	indicator.BackgroundColor3 = COLORS.disconnected
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
		labelText.TextColor3 = COLORS.textDim
		labelText.TextSize = 16
		labelText.FontFace = FONTS.Regular
		labelText.TextXAlignment = Enum.TextXAlignment.Left
		labelText.Parent = row

		local valueText = Instance.new("TextLabel")
		valueText.Size = UDim2.new(0.5, -20, 1, 0)
		valueText.Position = UDim2.new(0.5, 0, 0, 0)
		valueText.BackgroundTransparency = 1
		valueText.Text = data[2]
		valueText.TextColor3 = COLORS.text
		valueText.TextSize = 16
		valueText.FontFace = FONTS.Medium
		valueText.TextXAlignment = Enum.TextXAlignment.Right
		valueText.Parent = row

		metrics[data[1]] = valueText
	end

	metrics["Status"].TextColor3 = COLORS.disconnected

	-- Subscribe to store changes to update UI reactively
	uiStore:subscribe(function(changed, state)
		-- Update connection status
		if changed.connected ~= nil then
			local color = state.connected and COLORS.connected or COLORS.disconnected
			TweenService:Create(indicator, TWEEN_SLOW, { BackgroundColor3 = color }):Play()
			metrics["Status"].Text = state.connected and "Connected" or "Disconnected"
			TweenService:Create(metrics["Status"], TWEEN_SLOW, { TextColor3 = color }):Play()
		end
		
		-- Update host
		if changed.host then
			metrics["Host"].Text = state.host
		end
		
		-- Update port
		if changed.port then
			metrics["Port"].Text = tostring(state.port)
		end
		
		-- Update commands count
		if changed.commands then
			metrics["Commands"].Text = tostring(state.commands)
		end
		
		-- Update uptime
		if changed.uptime then
			metrics["Uptime"].Text = state.uptime
		end
		
		-- Update API key display
		if changed.apiKey then
			statusLabel.Text = "Current: " .. (state.apiKey and string.sub(state.apiKey, 1, 8) .. "..." or "not set")
		end
	end)

	local startTime = tick()
	RunService.Heartbeat:Connect(function()
		local elapsed = tick() - startTime
		local h = math.floor(elapsed / 3600)
		local m = math.floor((elapsed % 3600) / 60)
		local s = math.floor(elapsed % 60)
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

	local undoBtn = createButton({
		name = "Undo",
		text = "Undo",
		onClick = function() ChangeHistoryService:Undo() end,
	})
	undoBtn.LayoutOrder = 1
	undoBtn.Parent = buttonsFrame

	local redoBtn = createButton({
		name = "Redo",
		text = "Redo",
		onClick = function() ChangeHistoryService:Redo() end,
	})
	redoBtn.LayoutOrder = 2
	redoBtn.Parent = buttonsFrame

	local toggleBtn
	toggleBtn = createButton({
		name = "ToggleConnection",
		text = isConnected and "Disconnect" or "Connect",
		primary = true,
		onClick = function()
			isEnabled = not isEnabled
			local btnText = isEnabled and "Disconnect" or "Connect"
			local btn = toggleBtn:FindFirstChild("Btn")
			if btn then
				btn.Text = btnText
			end
		end,
	})
	toggleBtn.LayoutOrder = 3
	toggleBtn.Parent = buttonsFrame

	-- Settings Panel
	local settingsPanel = Instance.new("Frame")
	settingsPanel.Name = "SettingsPanel"
	settingsPanel.Size = UDim2.new(1, 0, 0, 110)
	settingsPanel.BackgroundColor3 = COLORS.panelBg
	settingsPanel.BorderSizePixel = 0
	settingsPanel.LayoutOrder = 4
	settingsPanel.Parent = container

	local settingsCorner = Instance.new("UICorner")
	settingsCorner.CornerRadius = UDim.new(0, 6)
	settingsCorner.Parent = settingsPanel

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, -24, 0, 26)
	label.Position = UDim2.new(0, 12, 0, 8)
	label.BackgroundTransparency = 1
	label.Text = "API Key"
	label.Text = "API Key"
	label.TextColor3 = COLORS.textDim
	label.TextSize = 16
	label.FontFace = FONTS.Medium
	label.Parent = settingsPanel

	local inputContainer = Instance.new("Frame")
	inputContainer.Size = UDim2.new(1, -24, 0, 36)
	inputContainer.Position = UDim2.new(0, 12, 0, 36)
	inputContainer.BackgroundColor3 = COLORS.inputBg
	inputContainer.BorderSizePixel = 0
	inputContainer.Parent = settingsPanel

	local inputCorner = Instance.new("UICorner")
	inputCorner.CornerRadius = UDim.new(0, 4)
	inputCorner.Parent = inputContainer

	local inputStroke = Instance.new("UIStroke")
	inputStroke.Color = COLORS.border
	inputStroke.Thickness = 1
	inputStroke.Parent = inputContainer

	local inputBox = Instance.new("TextBox")
	inputBox.Size = UDim2.new(1, -90, 1, 0)
	inputBox.Position = UDim2.new(0, 10, 0, 0)
	inputBox.BackgroundTransparency = 1
	inputBox.Text = ""
	inputBox.PlaceholderText = "Paste key here..."
	inputBox.PlaceholderColor3 = COLORS.placeholder
	inputBox.TextColor3 = COLORS.text
	inputBox.TextSize = 15
	inputBox.FontFace = FONTS.Mono
	inputBox.TextXAlignment = Enum.TextXAlignment.Left
	inputBox.ClearTextOnFocus = false
	inputBox.Parent = inputContainer

	local saveBtn = Instance.new("TextButton")
	saveBtn.Size = UDim2.new(0, 64, 0, 28)
	saveBtn.Position = UDim2.new(1, -72, 0.5, -14)
	saveBtn.BackgroundColor3 = COLORS.primary
	saveBtn.BorderSizePixel = 0
	saveBtn.Text = "Save"
	saveBtn.TextColor3 = COLORS.text
	saveBtn.TextSize = 16
	saveBtn.FontFace = FONTS.Medium
	saveBtn.AutoButtonColor = false
	saveBtn.Parent = inputContainer

	local saveBtnCorner = Instance.new("UICorner")
	saveBtnCorner.CornerRadius = UDim.new(0, 4)
	saveBtnCorner.Parent = saveBtn

	local statusLabel = Instance.new("TextLabel")
	statusLabel.Size = UDim2.new(1, -24, 0, 22)
	statusLabel.Position = UDim2.new(0, 12, 0, 78)
	statusLabel.BackgroundTransparency = 1
				statusLabel.Text = "Current: " .. props.getCurrentKey()
	statusLabel.TextColor3 = COLORS.textDim
	statusLabel.TextSize = 14
	statusLabel.FontFace = FONTS.Regular
	statusLabel.TextXAlignment = Enum.TextXAlignment.Left
	statusLabel.TextTruncate = Enum.TextTruncate.AtEnd
	statusLabel.Parent = settingsPanel

	inputBox.Focused:Connect(function()
		TweenService:Create(inputStroke, TWEEN_INFO, { Color = COLORS.borderFocus }):Play()
		TweenService:Create(inputContainer, TWEEN_INFO, { BackgroundColor3 = COLORS.inputBgFocus }):Play()
	end)

	inputBox.FocusLost:Connect(function()
		TweenService:Create(inputStroke, TWEEN_INFO, { Color = COLORS.border }):Play()
		TweenService:Create(inputContainer, TWEEN_INFO, { BackgroundColor3 = COLORS.inputBg }):Play()
	end)

	saveBtn.MouseEnter:Connect(function()
		TweenService:Create(saveBtn, TWEEN_INFO, { BackgroundColor3 = COLORS.primaryHover }):Play()
	end)

	saveBtn.MouseLeave:Connect(function()
		TweenService:Create(saveBtn, TWEEN_INFO, { BackgroundColor3 = COLORS.primary }):Play()
	end)

	saveBtn.MouseButton1Down:Connect(function()
		TweenService:Create(saveBtn, TWEEN_INFO, { BackgroundColor3 = COLORS.primaryActive }):Play()
	end)

	saveBtn.MouseButton1Click:Connect(function()
		TweenService:Create(saveBtn, TWEEN_INFO, { BackgroundColor3 = COLORS.primaryHover }):Play()
		local key = inputBox.Text
		if key and key ~= "" then
			onSaveKey(key)
			statusLabel.Text = "Saved"
			TweenService:Create(statusLabel, TWEEN_INFO, { TextColor3 = COLORS.success }):Play()
			inputBox.Text = ""
			task.delay(2, function()
	statusLabel.Text = "Current: " .. props.getCurrentKey()
				TweenService:Create(statusLabel, TWEEN_INFO, { TextColor3 = COLORS.textDim }):Play()
			end)
		end
	end)

	-- History Panel
	local historyPanel = Instance.new("Frame")
	historyPanel.Name = "HistoryPanel"
	historyPanel.Size = UDim2.new(1, 0, 1, -402)
	historyPanel.BackgroundColor3 = COLORS.panelBg
	historyPanel.BorderSizePixel = 0
	historyPanel.LayoutOrder = 5
	historyPanel.Parent = container

	local historyCorner = Instance.new("UICorner")
	historyCorner.CornerRadius = UDim.new(0, 6)
	historyCorner.Parent = historyPanel

	local header = Instance.new("TextLabel")
	header.Size = UDim2.new(1, -24, 0, 30)
	header.Position = UDim2.new(0, 12, 0, 0)
	header.BackgroundTransparency = 1
	header.Text = "History"
	header.TextColor3 = COLORS.textDim
	header.TextSize = 16
	header.FontFace = FONTS.Medium
	header.TextXAlignment = Enum.TextXAlignment.Left
	header.Parent = historyPanel

	local scrollFrame = Instance.new("ScrollingFrame")
	scrollFrame.Size = UDim2.new(1, -16, 1, -40)
	scrollFrame.Position = UDim2.new(0, 8, 0, 36)
	scrollFrame.BackgroundTransparency = 1
	scrollFrame.BorderSizePixel = 0
	scrollFrame.ScrollBarThickness = 4
	scrollFrame.ScrollBarImageColor3 = COLORS.scrollbar
	scrollFrame.ScrollingDirection = Enum.ScrollingDirection.Y
	scrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
	scrollFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scrollFrame.Parent = historyPanel

	local historyLayout = Instance.new("UIListLayout")
	historyLayout.Padding = UDim.new(0, 4)
	historyLayout.Parent = scrollFrame

	local historyList = {}
	local entryCount = 0

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
		uiStore:set({
			connected = connected,
			host = host or "localhost",
			port = port or "-",
		})
	end

	function api.addCommand(method, success)
		local timestamp = os.date("%H:%M:%S")
		
		local entry = Instance.new("Frame")
		entry.Name = "Entry" .. entryCount
		entry.Size = UDim2.new(1, -4, 0, 32)
		entry.BackgroundColor3 = COLORS.entryBg
		entry.BackgroundTransparency = 1
		entry.BorderSizePixel = 0

		local entryCorner = Instance.new("UICorner")
		entryCorner.CornerRadius = UDim.new(0, 4)
		entryCorner.Parent = entry

		local statusBar = Instance.new("Frame")
		statusBar.Size = UDim2.new(0, 3, 1, -8)
		statusBar.Position = UDim2.new(0, 0, 0, 4)
		statusBar.BackgroundColor3 = success and COLORS.success or COLORS.error
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
		methodLabel.TextColor3 = COLORS.text
		methodLabel.TextSize = 16
		methodLabel.FontFace = FONTS.Medium
		methodLabel.TextXAlignment = Enum.TextXAlignment.Left
		methodLabel.TextTruncate = Enum.TextTruncate.AtEnd
		methodLabel.Parent = entry

		local timeLabel = Instance.new("TextLabel")
		timeLabel.Size = UDim2.new(0, 55, 1, 0)
		timeLabel.Position = UDim2.new(1, -60, 0, 0)
		timeLabel.BackgroundTransparency = 1
		timeLabel.Text = timestamp
		timeLabel.TextColor3 = COLORS.textDimmer
		timeLabel.TextSize = 14
		timeLabel.FontFace = FONTS.Regular
		timeLabel.TextXAlignment = Enum.TextXAlignment.Right
		timeLabel.Parent = entry

		entry.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseMovement then
				TweenService:Create(entry, TWEEN_MEDIUM, { BackgroundColor3 = COLORS.entryBgHover, BackgroundTransparency = 0 }):Play()
			end
		end)

		entry.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseMovement then
				TweenService:Create(entry, TWEEN_MEDIUM, { BackgroundTransparency = 1 }):Play()
			end
		end)

		table.insert(historyList, 1, entry)
		entry.LayoutOrder = -entryCount
		entry.Parent = scrollFrame
		entryCount = entryCount + 1

		while #historyList > 100 do
			local old = table.remove(historyList)
			if old then
				old:Destroy()
			end
		end

		uiStore:set({ commands = entryCount })
	end

	function api.clearHistory()
		for _, entry in ipairs(historyList) do
			entry:Destroy()
		end
		historyList = {}
		entryCount = 0
	end

	-- Uptime updater (runs in background)
	task.spawn(function()
		while true do
			local elapsed = os.time() - startTime
			local h = math.floor(elapsed / 3600)
			local m = math.floor((elapsed % 3600) / 60)
			local s = elapsed % 60
			uiStore:set({ uptime = string.format("%02d:%02d:%02d", h, m, s) })
			task.wait(1)
		end
	end)

	return api
end

--------------------------------------------------------------------------------
-- API Key Management
--------------------------------------------------------------------------------

local function getApiKey()
	local savedKey = plugin:GetSetting("MCP_API_KEY")
	if savedKey and savedKey ~= "" then
		return savedKey
	end
	if CONFIG.API_KEY and CONFIG.API_KEY ~= "" then
		return CONFIG.API_KEY
	end
	return nil
end

local function setApiKey(key)
	plugin:SetSetting("MCP_API_KEY", key)
	apiKey = key
	print("[MCP] API key saved")
end

apiKey = getApiKey()

--------------------------------------------------------------------------------
-- UI Creation
--------------------------------------------------------------------------------

local toolbar = plugin:CreateToolbar("MCP Bridge")
local toggleButton = toolbar:CreateButton(
	"MCP Toggle",
	"Toggle MCP Bridge UI",
	""
)
toggleButton.ClickableWhenViewportHidden = true

local function updateButtonState()
	if not isEnabled then
		toggleButton:SetActive(false)
	elseif isConnected then
		toggleButton:SetActive(true)
	else
		toggleButton:SetActive(false)
	end
end

local function reconnect()
	isConnected = false
	activePort = nil
	serverUrl = nil
	retryInterval = CONFIG.RETRY_INTERVAL
	print("[MCP] Manual reconnect triggered")
end

local function restart()
	reconnect()
	if ui then
		ui.clearHistory()
	end
	print("[MCP] Bridge restart triggered")
end

ui = createUI({
	plugin = plugin,
	version = VERSION,
	onReconnect = reconnect,
	onRestart = restart,
	onSaveKey = setApiKey,
	getCurrentKey = function()
		return apiKey and string.sub(apiKey, 1, 8) .. "..." or "not set"
	end,
})

toggleButton.Click:Connect(function()
	ui.toggle()
	updateButtonState()
end)

--------------------------------------------------------------------------------
-- Utilities
--------------------------------------------------------------------------------

local function discoverServerPort()
	local port = CONFIG.BASE_PORT
	local testUrl = "http://localhost:" .. port .. "/health"
	
	local success, response = pcall(function()
		return HttpService:GetAsync(testUrl, false)
	end)
	
	if success then
		local ok, data = pcall(function()
			return HttpService:JSONDecode(response)
		end)
		
		if ok and data and data.service == "roblox-bridge-mcp" then
			return port
		end
	end
	
	return nil
end

local function sendResult(id, success, data, err)
	if not serverUrl or not apiKey then
		return
	end
	
	local payload = {
		id = id,
		success = success,
		data = data,
		error = err,
	}
	pcall(function()
		local url = serverUrl .. "/result?key=" .. apiKey
		HttpService:PostAsync(url, HttpService:JSONEncode(payload))
	end)
end

local function resolvePath(path)
	if path == "game" then
		return game
	end

	local segments = string.split(path, ".")
	local current = game
	local startIdx = 1
	if segments[1] == "game" then
		startIdx = 2
	end

	for i = startIdx, #segments do
		local name = segments[i]
		if not current then
			return nil
		end

		local child = current:FindFirstChild(name)
		if not child and current == game then
			local ok, service = pcall(function()
				return game:GetService(name)
			end)
			if ok then
				child = service
			end
		end
		current = child
	end

	return current
end

local function requirePath(path)
	local obj = resolvePath(path)
	if not obj then
		error("Instance not found: " .. path)
	end
	return obj
end

local function requireBasePart(path)
	local obj = requirePath(path)
	if not obj:IsA("BasePart") then
		error("Not a BasePart: " .. path)
	end
	return obj
end

local function requireScript(path)
	local obj = requirePath(path)
	if not obj:IsA("LuaSourceContainer") then
		error("Not a script: " .. path)
	end
	return obj
end

--------------------------------------------------------------------------------
-- Tool Implementations
--------------------------------------------------------------------------------

local Tools = {}

-- Instance Management
function Tools.CreateInstance(p)
	local parent = requirePath(p.parentPath)
	local obj = Instance.new(p.className)
	obj.Name = p.name or p.className
	if p.properties then
		for k, v in pairs(p.properties) do
			pcall(function()
				obj[k] = v
			end)
		end
	end
	obj.Parent = parent
	return obj:GetFullName()
end

function Tools.DeleteInstance(p)
	local obj = requirePath(p.path)
	obj:Destroy()
	return "Deleted"
end

function Tools.CloneInstance(p)
	local obj = requirePath(p.path)
	local clone = obj:Clone()
	if p.parentPath then
		clone.Parent = resolvePath(p.parentPath)
	end
	return clone:GetFullName()
end

function Tools.RenameInstance(p)
	local obj = requirePath(p.path)
	obj.Name = p.newName
	return obj:GetFullName()
end

-- Instance Discovery & Info
function Tools.GetFullName(p)
	local obj = requirePath(p.path)
	return obj:GetFullName()
end

function Tools.GetParent(p)
	local obj = requirePath(p.path)
	if obj.Parent then
		return obj.Parent:GetFullName()
	end
	return nil
end

function Tools.IsA(p)
	local obj = requirePath(p.path)
	return obj:IsA(p.className)
end

function Tools.GetClassName(p)
	local obj = requirePath(p.path)
	return obj.ClassName
end

function Tools.WaitForChild(p)
	local obj = requirePath(p.path)
	local timeout = p.timeout or 5
	local child = obj:WaitForChild(p.name, timeout)
	if child then
		return child:GetFullName()
	end
	return nil
end

-- Property Access
function Tools.SetProperty(p)
	local obj = requirePath(p.path)
	obj[p.property] = p.value
	return tostring(obj[p.property])
end

function Tools.GetProperty(p)
	local obj = requirePath(p.path)
	return obj[p.property]
end

-- Hierarchy Navigation
function Tools.GetChildren(p)
	local obj = requirePath(p.path)
	local names = {}
	for _, child in pairs(obj:GetChildren()) do
		table.insert(names, child.Name)
	end
	return names
end

function Tools.GetDescendants(p)
	local obj = requirePath(p.path)
	local paths = {}
	for _, desc in pairs(obj:GetDescendants()) do
		table.insert(paths, desc:GetFullName())
	end
	return paths
end

function Tools.FindFirstChild(p)
	local obj = requirePath(p.path)
	local child = obj:FindFirstChild(p.name, p.recursive or false)
	if child then
		return child:GetFullName()
	end
	return nil
end

function Tools.GetService(p)
	local ok, service = pcall(function()
		return game:GetService(p.service)
	end)
	if ok and service then
		return service.Name
	end
	return "NotFound"
end

-- Transform
function Tools.MoveTo(p)
	local obj = requirePath(p.path)
	local pos = Vector3.new(p.position[1], p.position[2], p.position[3])
	if obj:IsA("Model") then
		obj:MoveTo(pos)
	elseif obj:IsA("BasePart") then
		obj.Position = pos
	else
		error("Cannot move: not a Model or BasePart")
	end
	return "Moved"
end

function Tools.SetPosition(p)
	local obj = requireBasePart(p.path)
	obj.Position = Vector3.new(p.x, p.y, p.z)
	return "Set"
end

function Tools.GetPosition(p)
	local obj = requireBasePart(p.path)
	local pos = obj.Position
	return { pos.X, pos.Y, pos.Z }
end

function Tools.SetRotation(p)
	local obj = requireBasePart(p.path)
	obj.Rotation = Vector3.new(p.x, p.y, p.z)
	return "Set"
end

function Tools.GetRotation(p)
	local obj = requireBasePart(p.path)
	local rot = obj.Rotation
	return { rot.X, rot.Y, rot.Z }
end

function Tools.SetSize(p)
	local obj = requireBasePart(p.path)
	obj.Size = Vector3.new(p.x, p.y, p.z)
	return "Set"
end

function Tools.GetSize(p)
	local obj = requireBasePart(p.path)
	local size = obj.Size
	return { size.X, size.Y, size.Z }
end

function Tools.PivotTo(p)
	local obj = requirePath(p.path)
	if not obj:IsA("PVInstance") then
		error("Not a PVInstance: " .. p.path)
	end
	local c = p.cframe
	local cf = CFrame.new(c[1], c[2], c[3], c[4], c[5], c[6], c[7], c[8], c[9], c[10], c[11], c[12])
	obj:PivotTo(cf)
	return "Pivoted"
end

function Tools.GetPivot(p)
	local obj = requirePath(p.path)
	if not obj:IsA("PVInstance") then
		error("Not a PVInstance: " .. p.path)
	end
	local cf = obj:GetPivot()
	return { cf:GetComponents() }
end

-- Appearance
function Tools.SetColor(p)
	local obj = requirePath(p.path)
	if obj:IsA("BasePart") then
		obj.Color = Color3.fromRGB(p.r, p.g, p.b)
	elseif obj:IsA("Light") then
		obj.Color = Color3.fromRGB(p.r, p.g, p.b)
	else
		error("Cannot set color: not a BasePart or Light")
	end
	return "Set"
end

function Tools.SetTransparency(p)
	local obj = requirePath(p.path)
	if obj:IsA("BasePart") then
		obj.Transparency = p.value
	elseif obj:IsA("GuiObject") then
		obj.Transparency = p.value
	else
		error("Cannot set transparency")
	end
	return "Set"
end

function Tools.SetMaterial(p)
	local obj = requireBasePart(p.path)
	local material = Enum.Material[p.material]
	if not material then
		error("Invalid material: " .. p.material)
	end
	obj.Material = material
	return "Set"
end

-- Physics
function Tools.SetAnchored(p)
	local obj = requireBasePart(p.path)
	obj.Anchored = p.anchored
	return "Set"
end

function Tools.SetCanCollide(p)
	local obj = requireBasePart(p.path)
	obj.CanCollide = p.canCollide
	return "Set"
end

function Tools.CreateConstraint(p)
	local att0 = requirePath(p.attachment0Path)
	local att1 = requirePath(p.attachment1Path)
	
	if not att0:IsA("Attachment") then
		error("attachment0Path must be an Attachment")
	end
	if not att1:IsA("Attachment") then
		error("attachment1Path must be an Attachment")
	end
	
	local constraint = Instance.new(p.type)
	constraint.Attachment0 = att0
	constraint.Attachment1 = att1
	
	if p.properties then
		for k, v in pairs(p.properties) do
			pcall(function()
				constraint[k] = v
			end)
		end
	end
	
	constraint.Parent = att0.Parent
	return constraint:GetFullName()
end

function Tools.SetPhysicalProperties(p)
	local obj = requireBasePart(p.path)
	local density = p.density or 1
	local friction = p.friction or 0.3
	local elasticity = p.elasticity or 0.5
	local frictionWeight = p.frictionWeight or 1
	local elasticityWeight = p.elasticityWeight or 1
	
	obj.CustomPhysicalProperties = PhysicalProperties.new(
		density, friction, elasticity, frictionWeight, elasticityWeight
	)
	return "Set"
end

function Tools.GetMass(p)
	local obj = requireBasePart(p.path)
	return obj:GetMass()
end

-- Scripting
function Tools.CreateScript(p)
	local parent = requirePath(p.parentPath)
	local scriptType = p.type or "Script"
	local s = Instance.new(scriptType)
	s.Name = p.name
	s.Source = p.source
	s.Parent = parent
	return s:GetFullName()
end

function Tools.GetScriptSource(p)
	local obj = requireScript(p.path)
	return obj.Source
end

function Tools.SetScriptSource(p)
	local obj = requireScript(p.path)
	obj.Source = p.source
	return "Updated"
end

function Tools.AppendToScript(p)
	local obj = requireScript(p.path)
	obj.Source = obj.Source .. "\n" .. p.code
	return "Appended"
end

function Tools.ReplaceScriptLines(p)
	local obj = requireScript(p.path)
	local lines = string.split(obj.Source, "\n")
	local newLines = {}
	local contentLines = string.split(p.content, "\n")

	for i = 1, p.startLine - 1 do
		if lines[i] then
			table.insert(newLines, lines[i])
		end
	end

	for _, line in pairs(contentLines) do
		table.insert(newLines, line)
	end

	for i = p.endLine + 1, #lines do
		table.insert(newLines, lines[i])
	end

	obj.Source = table.concat(newLines, "\n")
	return "Replaced"
end

function Tools.InsertScriptLines(p)
	local obj = requireScript(p.path)
	local lines = string.split(obj.Source, "\n")
	local contentLines = string.split(p.content, "\n")
	local newLines = {}
	local insertAt = math.clamp(p.lineNumber, 1, #lines + 1)

	for i = 1, insertAt - 1 do
		table.insert(newLines, lines[i])
	end

	for _, line in pairs(contentLines) do
		table.insert(newLines, line)
	end

	for i = insertAt, #lines do
		table.insert(newLines, lines[i])
	end

	obj.Source = table.concat(newLines, "\n")
	return "Inserted"
end

function Tools.RunConsoleCommand(p)
	local func, compileErr = loadstring(p.code)
	if not func then
		error("Compile error: " .. tostring(compileErr))
	end

	local logs = {}
	local env = setmetatable({
		print = function(...)
			local parts = {}
			for i = 1, select("#", ...) do
				table.insert(parts, tostring(select(i, ...)))
			end
			table.insert(logs, table.concat(parts, " "))
			print(...)
		end,
		warn = function(...)
			local parts = {}
			for i = 1, select("#", ...) do
				table.insert(parts, tostring(select(i, ...)))
			end
			table.insert(logs, "WARN: " .. table.concat(parts, " "))
			warn(...)
		end,
	}, { __index = getfenv() })

	setfenv(func, env)

	local results = { pcall(func) }
	local success = table.remove(results, 1)
	local output = table.concat(logs, "\n")

	if not success then
		error(output .. "\nRuntime error: " .. tostring(results[1]))
	end

	local returnStr = ""
	if #results > 0 then
		local strResults = {}
		for _, v in pairs(results) do
			table.insert(strResults, tostring(v))
		end
		returnStr = "Returned: " .. table.concat(strResults, ", ")
	end

	if output == "" and returnStr == "" then
		return "Executed (no output)"
	end

	local sep = ""
	if output ~= "" and returnStr ~= "" then
		sep = "\n"
	end
	return output .. sep .. returnStr
end

-- Selection
function Tools.GetSelection()
	local sel = Selection:Get()
	local paths = {}
	for _, obj in pairs(sel) do
		table.insert(paths, obj:GetFullName())
	end
	return paths
end

function Tools.SetSelection(p)
	local objs = {}
	for _, path in pairs(p.paths) do
		local obj = resolvePath(path)
		if obj then
			table.insert(objs, obj)
		end
	end
	Selection:Set(objs)
	return "Set"
end

function Tools.ClearSelection()
	Selection:Set({})
	return "Cleared"
end

function Tools.AddToSelection(p)
	local current = Selection:Get()
	for _, path in pairs(p.paths) do
		local obj = resolvePath(path)
		if obj then
			table.insert(current, obj)
		end
	end
	Selection:Set(current)
	return "Added"
end

-- Grouping
function Tools.GroupSelection(p)
	local sel = Selection:Get()
	if #sel == 0 then
		error("Nothing selected")
	end
	local parent = sel[1].Parent
	local model = Instance.new("Model")
	model.Name = p.name
	model.Parent = parent
	for _, obj in pairs(sel) do
		obj.Parent = model
	end
	Selection:Set({ model })
	return model:GetFullName()
end

function Tools.UngroupModel(p)
	local model = requirePath(p.path)
	if not model:IsA("Model") then
		error("Not a Model: " .. p.path)
	end
	local parent = model.Parent
	for _, child in pairs(model:GetChildren()) do
		child.Parent = parent
	end
	model:Destroy()
	return "Ungrouped"
end

-- Lighting
function Tools.SetTimeOfDay(p)
	Lighting.TimeOfDay = p.time
	return "Set"
end

function Tools.SetBrightness(p)
	Lighting.Brightness = p.brightness
	return "Set"
end

function Tools.SetAtmosphereDensity(p)
	local atmo = Lighting:FindFirstChildOfClass("Atmosphere")
	if not atmo then
		atmo = Instance.new("Atmosphere")
		atmo.Parent = Lighting
	end
	atmo.Density = p.density
	return "Set"
end

function Tools.CreateLight(p)
	local parent = requirePath(p.parentPath)
	local light = Instance.new(p.type)
	if p.brightness then
		light.Brightness = p.brightness
	end
	if p.color then
		light.Color = Color3.fromRGB(p.color[1], p.color[2], p.color[3])
	end
	light.Parent = parent
	return light:GetFullName()
end

-- Attributes & Tags
function Tools.SetAttribute(p)
	local obj = requirePath(p.path)
	obj:SetAttribute(p.name, p.value)
	return "Set"
end

function Tools.GetAttribute(p)
	local obj = requirePath(p.path)
	return obj:GetAttribute(p.name)
end

function Tools.GetAttributes(p)
	local obj = requirePath(p.path)
	return obj:GetAttributes()
end

function Tools.AddTag(p)
	local obj = requirePath(p.path)
	CollectionService:AddTag(obj, p.tag)
	return "Added"
end

function Tools.RemoveTag(p)
	local obj = requirePath(p.path)
	CollectionService:RemoveTag(obj, p.tag)
	return "Removed"
end

function Tools.GetTags(p)
	local obj = requirePath(p.path)
	return CollectionService:GetTags(obj)
end

function Tools.HasTag(p)
	local obj = requirePath(p.path)
	return CollectionService:HasTag(obj, p.tag)
end

-- Players
function Tools.GetPlayers()
	local names = {}
	for _, player in pairs(Players:GetPlayers()) do
		table.insert(names, player.Name)
	end
	return names
end

function Tools.GetPlayerPosition(p)
	local player = Players:FindFirstChild(p.username)
	if not player or not player.Character then
		error("Player or character not found: " .. p.username)
	end
	local root = player.Character:FindFirstChild("HumanoidRootPart")
	if not root then
		error("Character root not found")
	end
	local pos = root.Position
	return { pos.X, pos.Y, pos.Z }
end

function Tools.TeleportPlayer(p)
	local player = Players:FindFirstChild(p.username)
	if not player or not player.Character then
		error("Player or character not found")
	end
	player.Character:MoveTo(Vector3.new(p.position[1], p.position[2], p.position[3]))
	return "Teleported"
end

function Tools.KickPlayer(p)
	local player = Players:FindFirstChild(p.username)
	if player then
		player:Kick(p.reason or "Kicked by MCP")
	end
	return "Kicked"
end

-- Place/Studio
function Tools.SavePlace()
	return "Save triggered (if permissions allow)"
end

function Tools.GetPlaceInfo()
	return {
		PlaceId = game.PlaceId,
		Name = game.Name,
		JobId = game.JobId,
	}
end

-- Audio
function Tools.PlaySound(p)
	local sound = Instance.new("Sound")
	sound.SoundId = p.soundId
	sound.Volume = p.volume or 1

	local parent = SoundService
	if p.parentPath then
		parent = resolvePath(p.parentPath) or SoundService
	end
	sound.Parent = parent
	sound:Play()
	Debris:AddItem(sound, 30)
	return sound:GetFullName()
end

function Tools.StopSound(p)
	local obj = requirePath(p.path)
	if not obj:IsA("Sound") then
		error("Not a Sound: " .. p.path)
	end
	obj:Stop()
	return "Stopped"
end

-- Terrain
function Tools.FillTerrain(p)
	local terrain = game.Workspace:FindFirstChildOfClass("Terrain")
	if not terrain then
		error("No Terrain found in Workspace")
	end
	
	local material = Enum.Material[p.material]
	if not material then
		error("Invalid material: " .. p.material)
	end
	
	local min = Vector3.new(p.minX, p.minY, p.minZ)
	local max = Vector3.new(p.maxX, p.maxY, p.maxZ)
	local region = Region3.new(min, max)
	
	terrain:FillRegion(region, 4, material)
	return "Filled"
end

function Tools.ClearTerrain()
	local terrain = game.Workspace:FindFirstChildOfClass("Terrain")
	if not terrain then
		error("No Terrain found in Workspace")
	end
	terrain:Clear()
	return "Cleared"
end

-- Camera
function Tools.SetCameraPosition(p)
	local camera = game.Workspace.CurrentCamera
	if not camera then
		error("No CurrentCamera found")
	end
	local pos = Vector3.new(p.x, p.y, p.z)
	camera.CFrame = CFrame.new(pos) * camera.CFrame.Rotation
	return "Set"
end

function Tools.SetCameraFocus(p)
	local camera = game.Workspace.CurrentCamera
	if not camera then
		error("No CurrentCamera found")
	end
	local obj = requirePath(p.path)
	
	local targetPos
	if obj:IsA("BasePart") then
		targetPos = obj.Position
	elseif obj:IsA("Model") then
		targetPos = obj:GetPivot().Position
	else
		error("Cannot focus on: not a BasePart or Model")
	end
	
	camera.CFrame = CFrame.new(camera.CFrame.Position, targetPos)
	return "Focused"
end

function Tools.GetCameraPosition()
	local camera = game.Workspace.CurrentCamera
	if not camera then
		error("No CurrentCamera found")
	end
	local pos = camera.CFrame.Position
	return { pos.X, pos.Y, pos.Z }
end

-- Utility
function Tools.GetDistance(p)
	local obj1 = requirePath(p.path1)
	local obj2 = requirePath(p.path2)

	local function getPosition(obj)
		if obj:IsA("BasePart") then
			return obj.Position
		elseif obj:IsA("Model") then
			return obj:GetPivot().Position
		else
			error("Cannot get position: not a BasePart or Model")
		end
	end

	local pos1 = getPosition(obj1)
	local pos2 = getPosition(obj2)
	return (pos1 - pos2).Magnitude
end

function Tools.HighlightObject(p)
	local obj = requirePath(p.path)
	local hl = Instance.new("Highlight")
	if p.color then
		hl.FillColor = Color3.fromRGB(p.color[1], p.color[2], p.color[3])
	end
	hl.Parent = obj
	if p.duration then
		Debris:AddItem(hl, p.duration)
	end
	return hl:GetFullName()
end

function Tools.Chat(p)
	local channels = TextChatService:FindFirstChild("TextChannels")
	local systemChannel = channels and channels:FindFirstChild("RBXSystem")
	if systemChannel then
		systemChannel:DisplaySystemMessage(p.message)
		return "Sent"
	end
	return "Chat not available"
end

-- History (Undo/Redo)
function Tools.Undo()
	ChangeHistoryService:Undo()
	return "Undo executed"
end

function Tools.Redo()
	ChangeHistoryService:Redo()
	return "Redo executed"
end

--------------------------------------------------------------------------------
-- Command Handler
--------------------------------------------------------------------------------

local function handleCommand(cmd)
	local handler = Tools[cmd.method]
	if not handler then
		sendResult(cmd.id, false, nil, "Unknown method: " .. cmd.method)
		if ui then
			ui.addCommand(cmd.method, false)
		end
		return
	end

	local success, result = pcall(handler, cmd.params or {})
	if success then
		sendResult(cmd.id, true, result, nil)
		if ui then
			ui.addCommand(cmd.method, true)
		end
	else
		sendResult(cmd.id, false, nil, tostring(result))
		if ui then
			ui.addCommand(cmd.method, false)
		end
	end
end

--------------------------------------------------------------------------------
-- Polling Loop (Long-polling for near-instant command delivery)
--------------------------------------------------------------------------------

task.spawn(function()
	print("[MCP] Bridge starting, discovering server port...")

	while true do
		if isEnabled then
			-- Check for API key before attempting connection
			if not apiKey or apiKey == "" then
				print("[MCP] API key not set. Use _G.MCP_SetApiKey('your-key') or enter in Settings panel")
				task.wait(5)
				apiKey = getApiKey()
				continue
			end

			-- Auto-discover server port if not connected
			if not isConnected and not activePort then
				activePort = discoverServerPort()
				if activePort then
					serverUrl = "http://localhost:" .. activePort
					print("[MCP] Found server on port " .. activePort)
				else
					print("[MCP] No server found on port " .. CONFIG.BASE_PORT)
					task.wait(retryInterval)
					retryInterval = math.min(retryInterval * 1.5, CONFIG.MAX_RETRY_INTERVAL)
					continue
				end
			end

			-- Long-poll for commands (blocks until commands arrive or timeout)
			if serverUrl then
				local pollUrl = serverUrl .. "/poll?key=" .. apiKey
				if CONFIG.USE_LONG_POLL then
					pollUrl = pollUrl .. "&long=1"
				end

				local success, response = pcall(function()
					return HttpService:GetAsync(pollUrl, false)
				end)

				if success then
					if not isConnected then
						isConnected = true
						retryInterval = CONFIG.RETRY_INTERVAL
						updateButtonState()
						local mode = CONFIG.USE_LONG_POLL and "long-poll" or "legacy poll"
						print("[MCP] Connected to server at " .. serverUrl .. " (" .. mode .. ")")
						if ui then
							ui.setConnectionState(true, "localhost", activePort)
						end
					end

					local ok, commands = pcall(function()
						return HttpService:JSONDecode(response)
					end)

					if ok and commands then
						for _, cmd in pairs(commands) do
							task.spawn(handleCommand, cmd)
						end
					end

					-- No delay needed with long-polling - immediately re-poll
					if not CONFIG.USE_LONG_POLL then
						task.wait(0.3)
					end
				else
					if isConnected then
						isConnected = false
						activePort = nil
						serverUrl = nil
						updateButtonState()
						print("[MCP] Disconnected from server, will rediscover...")
						if ui then
							ui.setConnectionState(false, nil, nil)
						end
					end

					task.wait(retryInterval)
					retryInterval = math.min(retryInterval * 1.5, CONFIG.MAX_RETRY_INTERVAL)
				end
			end
		else
			task.wait(0.5)
		end
	end
end)

updateButtonState()

-- Expose setApiKey globally so users can set it from command bar
_G.MCP_SetApiKey = setApiKey
_G.MCP_GetApiKey = function()
	return apiKey and string.sub(apiKey, 1, 8) .. "..." or "not set"
end

if apiKey then
	print("[MCP] Plugin loaded (API key configured)")
else
	print("[MCP] Plugin loaded (API key NOT set - run _G.MCP_SetApiKey('your-key') in command bar)")
end