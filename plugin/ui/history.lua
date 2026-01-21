--------------------------------------------------------------------------------
-- Command History Component
-- Scrollable list with animated entry additions
--------------------------------------------------------------------------------

local TweenService = game:GetService("TweenService")

local COLORS = {
	bg = Color3.fromRGB(32, 32, 32),
	entryBg = Color3.fromRGB(40, 40, 40),
	entryBgHover = Color3.fromRGB(48, 48, 48),
	text = Color3.fromRGB(230, 230, 230),
	textDim = Color3.fromRGB(110, 110, 110),
	success = Color3.fromRGB(63, 185, 80),
	error = Color3.fromRGB(218, 54, 51),
	scrollbar = Color3.fromRGB(70, 70, 70),
}

local TWEEN_INFO = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local History = {}
local MAX_HISTORY = 100

function History.new(props)
	props = props or {}

	local frame = Instance.new("Frame")
	frame.Name = "HistoryPanel"
	frame.Size = UDim2.new(1, 0, 1, 0)
	frame.BackgroundColor3 = COLORS.bg
	frame.BorderSizePixel = 0

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = frame

	local header = Instance.new("TextLabel")
	header.Name = "Header"
	header.Size = UDim2.new(1, -24, 0, 28)
	header.Position = UDim2.new(0, 12, 0, 0)
	header.BackgroundTransparency = 1
	header.Text = "History"
	header.TextColor3 = COLORS.textDim
	header.TextSize = 12
	header.FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Medium)
	header.TextXAlignment = Enum.TextXAlignment.Left
	header.Parent = frame

	local scrollFrame = Instance.new("ScrollingFrame")
	scrollFrame.Name = "Scroll"
	scrollFrame.Size = UDim2.new(1, -16, 1, -36)
	scrollFrame.Position = UDim2.new(0, 8, 0, 32)
	scrollFrame.BackgroundTransparency = 1
	scrollFrame.BorderSizePixel = 0
	scrollFrame.ScrollBarThickness = 4
	scrollFrame.ScrollBarImageColor3 = COLORS.scrollbar
	scrollFrame.ScrollingDirection = Enum.ScrollingDirection.Y
	scrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
	scrollFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scrollFrame.Parent = frame

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 4)
	layout.Parent = scrollFrame

	local historyList = {}
	local entryCount = 0

	local function createEntry(method, status, timestamp)
		local entry = Instance.new("Frame")
		entry.Name = "Entry" .. entryCount
		entry.Size = UDim2.new(1, -4, 0, 28)
		entry.BackgroundColor3 = COLORS.entryBg
		entry.BackgroundTransparency = 1
		entry.BorderSizePixel = 0

		local entryCorner = Instance.new("UICorner")
		entryCorner.CornerRadius = UDim.new(0, 4)
		entryCorner.Parent = entry

		local statusBar = Instance.new("Frame")
		statusBar.Name = "StatusBar"
		statusBar.Size = UDim2.new(0, 3, 1, -8)
		statusBar.Position = UDim2.new(0, 0, 0, 4)
		statusBar.BackgroundColor3 = status == "success" and COLORS.success or COLORS.error
		statusBar.BorderSizePixel = 0
		statusBar.Parent = entry

		local barCorner = Instance.new("UICorner")
		barCorner.CornerRadius = UDim.new(0, 2)
		barCorner.Parent = statusBar

		local methodLabel = Instance.new("TextLabel")
		methodLabel.Name = "Method"
		methodLabel.Size = UDim2.new(1, -70, 1, 0)
		methodLabel.Position = UDim2.new(0, 10, 0, 0)
		methodLabel.BackgroundTransparency = 1
		methodLabel.Text = method
		methodLabel.TextColor3 = COLORS.text
		methodLabel.TextSize = 12
		methodLabel.FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Medium)
		methodLabel.TextXAlignment = Enum.TextXAlignment.Left
		methodLabel.TextTruncate = Enum.TextTruncate.AtEnd
		methodLabel.Parent = entry

		local timeLabel = Instance.new("TextLabel")
		timeLabel.Name = "Time"
		timeLabel.Size = UDim2.new(0, 50, 1, 0)
		timeLabel.Position = UDim2.new(1, -55, 0, 0)
		timeLabel.BackgroundTransparency = 1
		timeLabel.Text = timestamp
		timeLabel.TextColor3 = COLORS.textDim
		timeLabel.TextSize = 10
		timeLabel.FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Regular)
		timeLabel.TextXAlignment = Enum.TextXAlignment.Right
		timeLabel.Parent = entry

		-- Hover effect
		entry.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseMovement then
				TweenService:Create(entry, TWEEN_INFO, { BackgroundColor3 = COLORS.entryBgHover, BackgroundTransparency = 0 }):Play()
			end
		end)

		entry.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseMovement then
				TweenService:Create(entry, TWEEN_INFO, { BackgroundTransparency = 1 }):Play()
			end
		end)

		return entry
	end

	function frame.AddEntry(method, status)
		local timestamp = os.date("%H:%M:%S")
		local entry = createEntry(method, status, timestamp)

		table.insert(historyList, 1, entry)
		entry.LayoutOrder = -entryCount
		entry.Parent = scrollFrame
		entryCount = entryCount + 1

		-- Fade in animation
		entry.BackgroundTransparency = 1
		TweenService:Create(entry, TWEEN_INFO, { BackgroundTransparency = 1 }):Play()

		while #historyList > MAX_HISTORY do
			local old = table.remove(historyList)
			if old then
				old:Destroy()
			end
		end
	end

	function frame.Clear()
		for _, entry in ipairs(historyList) do
			entry:Destroy()
		end
		historyList = {}
		entryCount = 0
	end

	function frame.GetCount()
		return #historyList
	end

	if props.parent then
		frame.Parent = props.parent
	end

	return frame
end

return History
