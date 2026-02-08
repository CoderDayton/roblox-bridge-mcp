--!optimize 2
--------------------------------------------------------------------------------
-- Header Component
-- Clean hierarchy: Title left, tabs right, consistent spacing
--------------------------------------------------------------------------------

local Theme = require(script.Parent.Parent.theme)
local TabButton = require(script.Parent["tab-button"])

local Header = {}

function Header.create(pluginRef, props)
	local title = props.title or "MCP Bridge"
	local tabs = props.tabs or {}
	local onTabChange = props.onTabChange or function() end

	-- Header container (40px = 5 grid units)
	local header = Instance.new("Frame")
	header.Name = "Header"
	header.Size = UDim2.new(1, 0, 0, 40)
	header.BackgroundColor3 = Theme.COLORS.bgSurface
	header.BorderSizePixel = 0

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, Theme.RADIUS.md)
	corner.Parent = header

	-- Title (left aligned with 16px padding)
	local titleLabel = Instance.new("TextLabel")
	titleLabel.Size = UDim2.new(0.5, 0, 1, 0)
	titleLabel.Position = UDim2.new(0, Theme.SPACING.md, 0, 0)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Text = title
	titleLabel.TextColor3 = Theme.COLORS.textPrimary
	titleLabel.TextSize = Theme.TYPE.title.size
	titleLabel.FontFace = Theme.FONTS.Bold
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.Parent = header

	-- Tabs container (right aligned)
	local tabsContainer = Instance.new("Frame")
	tabsContainer.Name = "Tabs"
	tabsContainer.Size = UDim2.new(0, 124, 0, 28)
	tabsContainer.Position = UDim2.new(1, -132, 0.5, 0)
	tabsContainer.AnchorPoint = Vector2.new(0, 0.5)
	tabsContainer.BackgroundTransparency = 1
	tabsContainer.Parent = header

	local tabsLayout = Instance.new("UIListLayout")
	tabsLayout.FillDirection = Enum.FillDirection.Horizontal
	tabsLayout.Padding = UDim.new(0, Theme.SPACING.xs)
	tabsLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
	tabsLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	tabsLayout.Parent = tabsContainer

	local tabButtons = {}

	for i, tabInfo in ipairs(tabs) do
		local btn = TabButton.create(pluginRef, {
			name = tabInfo.name .. "Tab",
			text = tabInfo.name,
			size = UDim2.new(0, 56, 0, 28),
			isActive = i == 1,
			onClick = function()
				onTabChange(tabInfo.name)
			end,
		})
		btn.LayoutOrder = i
		btn.Parent = tabsContainer
		tabButtons[tabInfo.name] = btn
	end

	local api = {
		frame = header,
		tabButtons = tabButtons,
	}

	function api.setActiveTab(tabName)
		for name, btn in pairs(tabButtons) do
			TabButton.setActive(btn, name == tabName)
		end
	end

	return api
end

return Header
