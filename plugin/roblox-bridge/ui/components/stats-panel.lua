--!optimize 2
--------------------------------------------------------------------------------
-- Stats Panel Component
-- Clean data presentation, visual hierarchy, scannable
--------------------------------------------------------------------------------

local Theme = require(script.Parent.Parent.theme)

local StatsPanel = {}

function StatsPanel.create()
	-- Panel container (64px = 8 grid units)
	local panel = Instance.new("Frame")
	panel.Name = "StatsPanel"
	panel.Size = UDim2.new(1, 0, 0, 64)
	panel.BackgroundColor3 = Theme.COLORS.bgSurface
	panel.BorderSizePixel = 0

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, Theme.RADIUS.md)
	corner.Parent = panel

	-- Grid for stats (2 columns)
	local grid = Instance.new("Frame")
	grid.Size = UDim2.new(1, -32, 1, -24)
	grid.Position = UDim2.new(0, 16, 0, 12)
	grid.BackgroundTransparency = 1
	grid.Parent = panel

	local gridLayout = Instance.new("UIGridLayout")
	gridLayout.CellSize = UDim2.new(0.5, -8, 1, 0)
	gridLayout.CellPadding = UDim2.new(0, 16, 0, 0)
	gridLayout.Parent = grid

	-- Helper to create stat item
	local function createStat(name, defaultValue, layoutOrder)
		local stat = Instance.new("Frame")
		stat.Name = name .. "Stat"
		stat.BackgroundTransparency = 1
		stat.LayoutOrder = layoutOrder
		stat.Parent = grid

		local value = Instance.new("TextLabel")
		value.Name = "Value"
		value.Size = UDim2.new(1, 0, 0, 24)
		value.BackgroundTransparency = 1
		value.Text = defaultValue
		value.TextColor3 = Theme.COLORS.textPrimary
		value.TextSize = Theme.TYPE.display.size
		value.FontFace = Theme.FONTS.Bold
		value.TextXAlignment = Enum.TextXAlignment.Left
		value.Parent = stat

		local label = Instance.new("TextLabel")
		label.Name = "Label"
		label.Size = UDim2.new(1, 0, 0, 16)
		label.Position = UDim2.new(0, 0, 0, 24)
		label.BackgroundTransparency = 1
		label.Text = name
		label.TextColor3 = Theme.COLORS.textTertiary
		label.TextSize = Theme.TYPE.caption.size
		label.FontFace = Theme.FONTS.Regular
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.Parent = stat

		return value
	end

	local commandsValue = createStat("Commands", "0", 1)
	local uptimeValue = createStat("Uptime", "00:00:00", 2)

	local api = {
		frame = panel,
	}

	function api.setCommands(count)
		commandsValue.Text = tostring(count)
	end

	function api.setUptime(time)
		uptimeValue.Text = time
	end

	return api
end

return StatsPanel
