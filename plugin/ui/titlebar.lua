--------------------------------------------------------------------------------
-- Title Bar Component
-- Header with animated connection indicator and status text
--------------------------------------------------------------------------------

local TweenService = game:GetService("TweenService")

local COLORS = {
	bg = Color3.fromRGB(37, 37, 37),
	text = Color3.fromRGB(230, 230, 230),
	textDim = Color3.fromRGB(140, 140, 140),
	connected = Color3.fromRGB(63, 185, 80),
	disconnected = Color3.fromRGB(218, 54, 51),
}

local TWEEN_INFO = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local TitleBar = {}

function TitleBar.new(props)
	props = props or {}

	local version = props.version or "1.0.0"

	local frame = Instance.new("Frame")
	frame.Name = "TitleBar"
	frame.Size = UDim2.new(1, 0, 0, 36)
	frame.BackgroundColor3 = COLORS.bg
	frame.BorderSizePixel = 0

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = frame

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(0, 80, 1, 0)
	title.Position = UDim2.new(0, 12, 0, 0)
	title.BackgroundTransparency = 1
	title.Text = "MCP Bridge"
	title.TextColor3 = COLORS.text
	title.TextSize = 14
	title.FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold)
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Parent = frame

	local versionLabel = Instance.new("TextLabel")
	versionLabel.Name = "Version"
	versionLabel.Size = UDim2.new(0, 40, 1, 0)
	versionLabel.Position = UDim2.new(0, 90, 0, 0)
	versionLabel.BackgroundTransparency = 1
	versionLabel.Text = "v" .. version
	versionLabel.TextColor3 = COLORS.textDim
	versionLabel.TextSize = 11
	versionLabel.FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Regular)
	versionLabel.TextXAlignment = Enum.TextXAlignment.Left
	versionLabel.Parent = frame

	-- Status container (right side)
	local statusContainer = Instance.new("Frame")
	statusContainer.Name = "StatusContainer"
	statusContainer.Size = UDim2.new(0, 100, 1, 0)
	statusContainer.Position = UDim2.new(1, -108, 0, 0)
	statusContainer.BackgroundTransparency = 1
	statusContainer.Parent = frame

	local statusText = Instance.new("TextLabel")
	statusText.Name = "StatusText"
	statusText.Size = UDim2.new(1, -20, 1, 0)
	statusText.Position = UDim2.new(0, 0, 0, 0)
	statusText.BackgroundTransparency = 1
	statusText.Text = "Disconnected"
	statusText.TextColor3 = COLORS.disconnected
	statusText.TextSize = 11
	statusText.FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Medium)
	statusText.TextXAlignment = Enum.TextXAlignment.Right
	statusText.Parent = statusContainer

	local indicator = Instance.new("Frame")
	indicator.Name = "Indicator"
	indicator.Size = UDim2.new(0, 8, 0, 8)
	indicator.Position = UDim2.new(1, -8, 0.5, -4)
	indicator.BackgroundColor3 = COLORS.disconnected
	indicator.BorderSizePixel = 0
	indicator.Parent = statusContainer

	local indicatorCorner = Instance.new("UICorner")
	indicatorCorner.CornerRadius = UDim.new(0.5, 0)
	indicatorCorner.Parent = indicator

	function frame:SetConnectionState(state)
		local isConnected = state == "connected"
		local color = isConnected and COLORS.connected or COLORS.disconnected
		local text = isConnected and "Connected" or "Disconnected"

		TweenService:Create(indicator, TWEEN_INFO, { BackgroundColor3 = color }):Play()
		TweenService:Create(statusText, TWEEN_INFO, { TextColor3 = color }):Play()
		statusText.Text = text
	end

	if props.parent then
		frame.Parent = props.parent
	end

	return frame
end

return TitleBar
