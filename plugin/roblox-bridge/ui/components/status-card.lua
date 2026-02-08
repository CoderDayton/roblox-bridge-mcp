--!optimize 2
--------------------------------------------------------------------------------
-- Status Card Component
-- Clear visual hierarchy, status-first design, breathing room
--------------------------------------------------------------------------------

local Theme = require(script.Parent.Parent.theme)

local StatusCard = {}

function StatusCard.create(props)
	local version = props.version or "1.0.0"

	-- Card container (88px = 11 grid units)
	local card = Instance.new("Frame")
	card.Name = "StatusCard"
	card.Size = UDim2.new(1, 0, 0, 88)
	card.BackgroundColor3 = Theme.COLORS.bgSurface
	card.BorderSizePixel = 0

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, Theme.RADIUS.md)
	corner.Parent = card

	-- Content padding
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, Theme.SPACING.md)
	padding.PaddingRight = UDim.new(0, Theme.SPACING.md)
	padding.PaddingTop = UDim.new(0, Theme.SPACING.md)
	padding.PaddingBottom = UDim.new(0, Theme.SPACING.md)
	padding.Parent = card

	-- Status row (indicator + text)
	local statusRow = Instance.new("Frame")
	statusRow.Name = "StatusRow"
	statusRow.Size = UDim2.new(1, 0, 0, 24)
	statusRow.BackgroundTransparency = 1
	statusRow.Parent = card

	-- Pulsing status indicator
	local indicator = Instance.new("Frame")
	indicator.Name = "Indicator"
	indicator.Size = UDim2.new(0, 10, 0, 10)
	indicator.Position = UDim2.new(0, 0, 0.5, 0)
	indicator.AnchorPoint = Vector2.new(0, 0.5)
	indicator.BackgroundColor3 = Theme.COLORS.error
	indicator.BorderSizePixel = 0
	indicator.Parent = statusRow

	local indicatorCorner = Instance.new("UICorner")
	indicatorCorner.CornerRadius = UDim.new(0.5, 0)
	indicatorCorner.Parent = indicator

	-- Glow ring for indicator
	local glow = Instance.new("Frame")
	glow.Name = "Glow"
	glow.Size = UDim2.new(0, 18, 0, 18)
	glow.Position = UDim2.new(0.5, 0, 0.5, 0)
	glow.AnchorPoint = Vector2.new(0.5, 0.5)
	glow.BackgroundColor3 = Theme.COLORS.error
	glow.BackgroundTransparency = 0.85
	glow.BorderSizePixel = 0
	glow.ZIndex = 0
	glow.Parent = indicator

	local glowCorner = Instance.new("UICorner")
	glowCorner.CornerRadius = UDim.new(0.5, 0)
	glowCorner.Parent = glow

	-- Status text
	local statusText = Instance.new("TextLabel")
	statusText.Name = "StatusText"
	statusText.Size = UDim2.new(1, -80, 1, 0)
	statusText.Position = UDim2.new(0, 20, 0, 0)
	statusText.BackgroundTransparency = 1
	statusText.Text = "Disconnected"
	statusText.TextColor3 = Theme.COLORS.error
	statusText.TextSize = Theme.TYPE.title.size
	statusText.FontFace = Theme.FONTS.SemiBold
	statusText.TextXAlignment = Enum.TextXAlignment.Left
	statusText.Parent = statusRow

	-- Version badge (right aligned)
	local versionBadge = Instance.new("Frame")
	versionBadge.Name = "VersionBadge"
	versionBadge.Size = UDim2.new(0, 48, 0, 20)
	versionBadge.Position = UDim2.new(1, 0, 0.5, 0)
	versionBadge.AnchorPoint = Vector2.new(1, 0.5)
	versionBadge.BackgroundColor3 = Theme.COLORS.bgMuted
	versionBadge.BorderSizePixel = 0
	versionBadge.Parent = statusRow

	local badgeCorner = Instance.new("UICorner")
	badgeCorner.CornerRadius = UDim.new(0, Theme.RADIUS.sm)
	badgeCorner.Parent = versionBadge

	local versionLabel = Instance.new("TextLabel")
	versionLabel.Size = UDim2.new(1, 0, 1, 0)
	versionLabel.BackgroundTransparency = 1
	versionLabel.Text = "v" .. version
	versionLabel.TextColor3 = Theme.COLORS.textTertiary
	versionLabel.TextSize = Theme.TYPE.micro.size
	versionLabel.FontFace = Theme.FONTS.Medium
	versionLabel.Parent = versionBadge

	-- Connection info (secondary text)
	local connectionInfo = Instance.new("TextLabel")
	connectionInfo.Name = "ConnectionInfo"
	connectionInfo.Size = UDim2.new(1, 0, 0, 20)
	connectionInfo.Position = UDim2.new(0, 0, 0, 36)
	connectionInfo.BackgroundTransparency = 1
	connectionInfo.Text = "Ready to connect"
	connectionInfo.TextColor3 = Theme.COLORS.textSecondary
	connectionInfo.TextSize = Theme.TYPE.body.size
	connectionInfo.FontFace = Theme.FONTS.Regular
	connectionInfo.TextXAlignment = Enum.TextXAlignment.Left
	connectionInfo.Parent = card

	local api = {
		frame = card,
	}

	function api.update(state)
		local color, text, info, glowAlpha

		if state.isConnecting then
			color = Theme.COLORS.warning
			text = "Connecting"
			info = "Establishing connection..."
			glowAlpha = 0.7
		elseif state.connected then
			color = Theme.COLORS.success
			text = "Connected"
			info = (state.host or "localhost") .. ":" .. tostring(state.port or "-")
			glowAlpha = 0.8
		else
			color = Theme.COLORS.error
			text = "Disconnected"
			info = "Ready to connect"
			glowAlpha = 0.85
		end

		Theme.tween(indicator, "medium", { BackgroundColor3 = color })
		Theme.tween(glow, "medium", { BackgroundColor3 = color, BackgroundTransparency = glowAlpha })
		statusText.Text = text
		Theme.tween(statusText, "medium", { TextColor3 = color })
		connectionInfo.Text = info
	end

	return api
end

return StatusCard
