--!optimize 2
--------------------------------------------------------------------------------
-- History Panel Component
-- Scannable list, clear success/error states, temporal context
-- Right-click context menu for undo, copy, and more
--------------------------------------------------------------------------------

local os_date = os.date
local table_insert = table.insert
local table_remove = table.remove
local ipairs = ipairs
local pcall = pcall

local Theme = require(script.Parent.Parent.theme)
local Services = require(script.Parent.Parent.Parent.utils.services)

local HistoryPanel = {}

local MAX_ENTRIES = 100

function HistoryPanel.create(pluginRef)
	local entryCount = 0
	local historyList = {}  -- Stores {frame, method, success, index, timestamp}
	local entryData = {}    -- Maps frame to data for quick lookup

	-- Panel fills remaining space
	local panel = Instance.new("Frame")
	panel.Name = "HistoryPanel"
	panel.Size = UDim2.new(1, 0, 1, -52)
	panel.BackgroundColor3 = Theme.COLORS.bgSurface
	panel.BorderSizePixel = 0

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, Theme.RADIUS.md)
	corner.Parent = panel

	-- Header row (40px)
	local header = Instance.new("Frame")
	header.Name = "Header"
	header.Size = UDim2.new(1, 0, 0, 40)
	header.BackgroundTransparency = 1
	header.Parent = panel

	local headerPadding = Instance.new("UIPadding")
	headerPadding.PaddingLeft = UDim.new(0, Theme.SPACING.md)
	headerPadding.PaddingRight = UDim.new(0, Theme.SPACING.md)
	headerPadding.Parent = header

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(0.6, 0, 1, 0)
	title.BackgroundTransparency = 1
	title.Text = "History"
	title.TextColor3 = Theme.COLORS.textPrimary
	title.TextSize = Theme.TYPE.body.size
	title.FontFace = Theme.FONTS.SemiBold
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Parent = header

	local countLabel = Instance.new("TextLabel")
	countLabel.Name = "Count"
	countLabel.Size = UDim2.new(0.4, 0, 1, 0)
	countLabel.Position = UDim2.new(0.6, 0, 0, 0)
	countLabel.BackgroundTransparency = 1
	countLabel.Text = "0 commands"
	countLabel.TextColor3 = Theme.COLORS.textTertiary
	countLabel.TextSize = Theme.TYPE.caption.size
	countLabel.FontFace = Theme.FONTS.Regular
	countLabel.TextXAlignment = Enum.TextXAlignment.Right
	countLabel.Parent = header

	-- Divider line
	local divider = Instance.new("Frame")
	divider.Size = UDim2.new(1, -32, 0, 1)
	divider.Position = UDim2.new(0, 16, 0, 40)
	divider.BackgroundColor3 = Theme.COLORS.borderSubtle
	divider.BorderSizePixel = 0
	divider.Parent = panel

	-- Scroll frame
	local scrollFrame = Instance.new("ScrollingFrame")
	scrollFrame.Size = UDim2.new(1, -16, 1, -48)
	scrollFrame.Position = UDim2.new(0, 8, 0, 44)
	scrollFrame.BackgroundTransparency = 1
	scrollFrame.BorderSizePixel = 0
	scrollFrame.ScrollBarThickness = 3
	scrollFrame.ScrollBarImageColor3 = Theme.COLORS.bgSubtle
	scrollFrame.ScrollBarImageTransparency = 0.3
	scrollFrame.ScrollingDirection = Enum.ScrollingDirection.Y
	scrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
	scrollFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scrollFrame.Parent = panel

	local listLayout = Instance.new("UIListLayout")
	listLayout.Padding = UDim.new(0, 2)
	listLayout.Parent = scrollFrame

	local function updateCount()
		local suffix = entryCount == 1 and " command" or " commands"
		countLabel.Text = tostring(entryCount) .. suffix
	end

	-- Empty state
	local emptyState = Instance.new("TextLabel")
	emptyState.Name = "EmptyState"
	emptyState.Size = UDim2.new(1, 0, 0, 80)
	emptyState.BackgroundTransparency = 1
	emptyState.Text = "No commands yet"
	emptyState.TextColor3 = Theme.COLORS.textDisabled
	emptyState.TextSize = Theme.TYPE.body.size
	emptyState.FontFace = Theme.FONTS.Regular
	emptyState.Visible = true
	emptyState.Parent = scrollFrame

	local api = {
		frame = panel,
	}

	--------------------------------------------------------------------------------
	-- Show right-click context menu for a history entry
	-- Provides undo, copy, and history management actions
	-- @param entry Frame - The history entry frame that was right-clicked
	-- @param data table - Entry metadata {method: string, success: boolean, index: number, timestamp: string}
	-- @private
	--------------------------------------------------------------------------------
	local function showContextMenu(entry, data)
		local menu = pluginRef:CreatePluginMenu("HistoryContextMenu", "Command Options")

		-- Add menu items
		local undoToHere = menu:AddNewAction("UndoToHere", "Undo to here", "rbxasset://textures/StudioToolbox/AssetPreview/undo_button.png")
		local copyMethod = menu:AddNewAction("CopyMethod", "Copy method name")
		menu:AddSeparator()
		local undoLast = menu:AddNewAction("UndoLast", "Undo last action")
		local redoLast = menu:AddNewAction("RedoLast", "Redo last action")
		menu:AddSeparator()
		local clearHistory = menu:AddNewAction("ClearHistory", "Clear history")

		-- Show menu and handle selection
		local selected = menu:ShowAsync()
		menu:Destroy()

		if not selected then return end

		local actionId = selected.ActionId

		if actionId == "UndoToHere" then
			-- Undo all commands after this one (newer commands)
			local targetIndex = data.index
			local undoCount = 0
			for i, histEntry in ipairs(historyList) do
				local entryInfo = entryData[histEntry]
				if entryInfo and entryInfo.index > targetIndex then
					undoCount = undoCount + 1
				end
			end
			-- Perform undos
			for _ = 1, undoCount do
				pcall(function()
					Services.ChangeHistoryService:Undo()
				end)
			end

		elseif actionId == "CopyMethod" then
			pcall(function()
				Services.Selection:Set({}) -- Clear selection to unfocus
				-- Use SetClipboard if available (plugin context)
				if pluginRef.SetClipboard then
					pluginRef:SetClipboard(data.method)
				end
			end)

		elseif actionId == "UndoLast" then
			pcall(function()
				Services.ChangeHistoryService:Undo()
			end)

		elseif actionId == "RedoLast" then
			pcall(function()
				Services.ChangeHistoryService:Redo()
			end)

		elseif actionId == "ClearHistory" then
			api.clear()
		end
	end

	function api.addEntry(method, success)
		emptyState.Visible = false

		local timestamp = os_date("%H:%M:%S")
		local currentIndex = entryCount

		-- Entry row (36px = consistent touch target)
		local entry = Instance.new("Frame")
		entry.Name = "Entry" .. entryCount
		entry.Size = UDim2.new(1, -4, 0, 36)
		entry.BackgroundColor3 = Theme.COLORS.bgMuted
		entry.BackgroundTransparency = 1
		entry.BorderSizePixel = 0

		-- Store entry data
		local data = {
			method = method,
			success = success,
			index = currentIndex,
			timestamp = timestamp,
		}
		entryData[entry] = data

		local entryCorner = Instance.new("UICorner")
		entryCorner.CornerRadius = UDim.new(0, Theme.RADIUS.sm)
		entryCorner.Parent = entry

		-- Status indicator bar (left edge)
		local statusBar = Instance.new("Frame")
		statusBar.Size = UDim2.new(0, 3, 1, -12)
		statusBar.Position = UDim2.new(0, 4, 0, 6)
		statusBar.BackgroundColor3 = success and Theme.COLORS.success or Theme.COLORS.error
		statusBar.BorderSizePixel = 0
		statusBar.Parent = entry

		local barCorner = Instance.new("UICorner")
		barCorner.CornerRadius = UDim.new(0, 2)
		barCorner.Parent = statusBar

		-- Method name
		local methodLabel = Instance.new("TextLabel")
		methodLabel.Size = UDim2.new(1, -80, 1, 0)
		methodLabel.Position = UDim2.new(0, 16, 0, 0)
		methodLabel.BackgroundTransparency = 1
		methodLabel.Text = method
		methodLabel.TextColor3 = Theme.COLORS.textPrimary
		methodLabel.TextSize = Theme.TYPE.body.size
		methodLabel.FontFace = Theme.FONTS.Medium
		methodLabel.TextXAlignment = Enum.TextXAlignment.Left
		methodLabel.TextTruncate = Enum.TextTruncate.AtEnd
		methodLabel.Parent = entry

		-- Timestamp
		local timeLabel = Instance.new("TextLabel")
		timeLabel.Size = UDim2.new(0, 60, 1, 0)
		timeLabel.Position = UDim2.new(1, -64, 0, 0)
		timeLabel.BackgroundTransparency = 1
		timeLabel.Text = timestamp
		timeLabel.TextColor3 = Theme.COLORS.textDisabled
		timeLabel.TextSize = Theme.TYPE.micro.size
		timeLabel.FontFace = Theme.FONTS.Regular
		timeLabel.TextXAlignment = Enum.TextXAlignment.Right
		timeLabel.Parent = entry

		-- Hover effect
		entry.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseMovement then
				Theme.tween(entry, "instant", { BackgroundTransparency = 0 })
			end
		end)

		entry.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseMovement then
				Theme.tween(entry, "instant", { BackgroundTransparency = 1 })
			end
		end)

		-- Right-click context menu
		entry.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton2 then
				showContextMenu(entry, data)
			end
		end)

		table_insert(historyList, 1, entry)
		entry.LayoutOrder = -entryCount
		entry.Parent = scrollFrame
		entryCount = entryCount + 1

		-- Cleanup old entries
		while #historyList > MAX_ENTRIES do
			local old = table_remove(historyList)
			if old then
				entryData[old] = nil
				old:Destroy()
			end
		end

		updateCount()
		return entryCount
	end

	function api.clear()
		for _, entry in ipairs(historyList) do
			entryData[entry] = nil
			entry:Destroy()
		end
		historyList = {}
		entryData = {}
		entryCount = 0
		updateCount()
		emptyState.Visible = true
	end

	function api.getCount()
		return entryCount
	end

	return api
end

return HistoryPanel
