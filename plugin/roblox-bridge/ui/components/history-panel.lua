--!optimize 2
--------------------------------------------------------------------------------
-- History Panel Component
-- Scannable list, clear success/error states, temporal context
-- Right-click context menu adapts to entry type (mutating/read-only/failed)
--------------------------------------------------------------------------------

local os_date = os.date
local table_insert = table.insert
local table_remove = table.remove
local tostring = tostring
local ipairs = ipairs
local pcall = pcall

local Theme = require(script.Parent.Parent.theme)
local Services = require(script.Parent.Parent.Parent.utils.services)

local HistoryPanel = {}

local MAX_ENTRIES = 100

function HistoryPanel.create(pluginRef)
	local entryCount = 0
	local waypointCount = 0
	local historyList = {} -- Stores entry Frame references, newest first
	local entryData = {} -- Maps Frame → data for quick lookup

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
	title.Size = UDim2.new(0.5, 0, 1, 0)
	title.BackgroundTransparency = 1
	title.Text = "History"
	title.TextColor3 = Theme.COLORS.textPrimary
	title.TextSize = Theme.TYPE.body.size
	title.FontFace = Theme.FONTS.SemiBold
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Parent = header

	local countLabel = Instance.new("TextLabel")
	countLabel.Name = "Count"
	countLabel.Size = UDim2.new(0.5, 0, 1, 0)
	countLabel.Position = UDim2.new(0.5, 0, 0, 0)
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
		local visible = #historyList
		local suffix = visible == 1 and " command" or " commands"
		if waypointCount > 0 then
			countLabel.Text = tostring(visible) .. suffix
				.. " · " .. tostring(waypointCount) .. " undoable"
		else
			countLabel.Text = tostring(visible) .. suffix
		end
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

	----------------------------------------------------------------------------
	-- Context Menu
	-- Adapts items based on entry type: mutating/read-only, success/failure
	----------------------------------------------------------------------------
	local function showContextMenu(entry, data)
		local menu = pluginRef:CreatePluginMenu("HistoryContextMenu", data.method)

		-- Always: copy method name
		menu:AddNewAction("CopyMethod", "Copy method name")

		-- Copy target path if summary available
		if data.summary and data.summary ~= "" then
			menu:AddNewAction("CopySummary", "Copy target path")
		end

		-- Copy error for failed commands
		if not data.success and data.error then
			menu:AddNewAction("CopyError", "Copy error message")
		end

		-- "Undo to here" only for entries that created a waypoint
		if data.hasWaypoint then
			-- Count undoable entries newer than this one
			local undoCount = 0
			for _, histEntry in ipairs(historyList) do
				local info = entryData[histEntry]
				if info and info.index > data.index and info.hasWaypoint then
					undoCount = undoCount + 1
				end
			end
			menu:AddSeparator()
			if undoCount > 0 then
				menu:AddNewAction("UndoToHere", "Undo to here (" .. tostring(undoCount + 1) .. " actions)")
			else
				menu:AddNewAction("UndoToHere", "Undo this action")
			end
		end

		menu:AddSeparator()
		menu:AddNewAction("UndoLast", "Undo last action")
		menu:AddNewAction("RedoLast", "Redo last action")
		menu:AddSeparator()
		menu:AddNewAction("ClearHistory", "Clear history")

		-- Show menu and handle selection
		local selected = menu:ShowAsync()
		menu:Destroy()

		if not selected then return end

		local actionId = selected.ActionId

		if actionId == "UndoToHere" then
			-- Count undoable entries newer than this one (inclusive of this entry)
			local targetIndex = data.index
			local undoCount = 0
			for _, histEntry in ipairs(historyList) do
				local info = entryData[histEntry]
				if info and info.index >= targetIndex and info.hasWaypoint then
					undoCount = undoCount + 1
				end
			end
			for _ = 1, undoCount do
				pcall(function()
					Services.ChangeHistoryService:Undo()
				end)
			end

		elseif actionId == "CopyMethod" then
			pcall(function()
				if pluginRef.SetClipboard then
					pluginRef:SetClipboard(data.method)
				end
			end)

		elseif actionId == "CopySummary" then
			pcall(function()
				if pluginRef.SetClipboard and data.summary then
					pluginRef:SetClipboard(data.summary)
				end
			end)

		elseif actionId == "CopyError" then
			pcall(function()
				if pluginRef.SetClipboard and data.error then
					pluginRef:SetClipboard(data.error)
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

	----------------------------------------------------------------------------
	-- Entry Creation
	----------------------------------------------------------------------------
	function api.addEntry(data)
		emptyState.Visible = false

		local method = data.method
		local success = data.success
		local summary = data.summary or ""
		local errorMsg = data.error
		local hasWaypoint = data.hasWaypoint or false
		local timestamp = os_date("%H:%M:%S")
		local currentIndex = entryCount
		local hasSummary = summary ~= ""

		-- Track waypoints
		if hasWaypoint then
			waypointCount = waypointCount + 1
		end

		-- Entry height: 36px base, 50px with summary subtitle
		local entryHeight = hasSummary and 50 or 36

		-- Entry row
		local entry = Instance.new("Frame")
		entry.Name = "Entry" .. entryCount
		entry.Size = UDim2.new(1, -4, 0, entryHeight)
		entry.BackgroundColor3 = Theme.COLORS.bgMuted
		entry.BackgroundTransparency = 1
		entry.BorderSizePixel = 0

		-- Store entry data for context menu and undo tracking
		local entryInfo = {
			method = method,
			success = success,
			summary = summary,
			error = errorMsg,
			hasWaypoint = hasWaypoint,
			index = currentIndex,
			timestamp = timestamp,
		}
		entryData[entry] = entryInfo

		local entryCorner = Instance.new("UICorner")
		entryCorner.CornerRadius = UDim.new(0, Theme.RADIUS.sm)
		entryCorner.Parent = entry

		-- Status indicator bar (left edge)
		-- Green = success+mutating, Gray = read-only, Red = error
		local barColor
		if not success then
			barColor = Theme.COLORS.error
		elseif hasWaypoint then
			barColor = Theme.COLORS.success
		else
			barColor = Theme.COLORS.bgSubtle
		end

		local statusBar = Instance.new("Frame")
		statusBar.Size = UDim2.new(0, 3, 1, -12)
		statusBar.Position = UDim2.new(0, 4, 0, 6)
		statusBar.BackgroundColor3 = barColor
		statusBar.BorderSizePixel = 0
		statusBar.Parent = entry

		local barCorner = Instance.new("UICorner")
		barCorner.CornerRadius = UDim.new(0, 2)
		barCorner.Parent = statusBar

		-- Method name (dimmed for read-only queries)
		local methodColor = hasWaypoint and Theme.COLORS.textPrimary or Theme.COLORS.textSecondary
		local methodFont = hasWaypoint and Theme.FONTS.Medium or Theme.FONTS.Regular

		local methodLabel = Instance.new("TextLabel")
		methodLabel.Size = UDim2.new(1, -80, 0, hasSummary and 20 or entryHeight)
		methodLabel.Position = UDim2.new(0, 16, 0, hasSummary and 4 or 0)
		methodLabel.BackgroundTransparency = 1
		methodLabel.Text = method
		methodLabel.TextColor3 = not success and Theme.COLORS.error or methodColor
		methodLabel.TextSize = Theme.TYPE.body.size
		methodLabel.FontFace = methodFont
		methodLabel.TextXAlignment = Enum.TextXAlignment.Left
		methodLabel.TextTruncate = Enum.TextTruncate.AtEnd
		methodLabel.Parent = entry

		-- Summary subtitle (only if available)
		if hasSummary then
			local summaryLabel = Instance.new("TextLabel")
			summaryLabel.Name = "Summary"
			summaryLabel.Size = UDim2.new(1, -80, 0, 18)
			summaryLabel.Position = UDim2.new(0, 16, 0, 26)
			summaryLabel.BackgroundTransparency = 1
			summaryLabel.Text = summary
			summaryLabel.TextColor3 = Theme.COLORS.textTertiary
			summaryLabel.TextSize = Theme.TYPE.micro.size
			summaryLabel.FontFace = Theme.FONTS.Regular
			summaryLabel.TextXAlignment = Enum.TextXAlignment.Left
			summaryLabel.TextTruncate = Enum.TextTruncate.AtEnd
			summaryLabel.Parent = entry
		end

		-- Timestamp
		local timeLabel = Instance.new("TextLabel")
		timeLabel.Size = UDim2.new(0, 60, 0, hasSummary and 20 or entryHeight)
		timeLabel.Position = UDim2.new(1, -64, 0, hasSummary and 4 or 0)
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
				showContextMenu(entry, entryInfo)
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
				local oldData = entryData[old]
				if oldData and oldData.hasWaypoint then
					waypointCount = waypointCount - 1
				end
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
		waypointCount = 0
		updateCount()
		emptyState.Visible = true
	end

	function api.getCount()
		return entryCount
	end

	return api
end

return HistoryPanel
