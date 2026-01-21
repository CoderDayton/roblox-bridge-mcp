--------------------------------------------------------------------------------
-- Status Panel Component
-- Connection info and metrics with smooth transitions
--------------------------------------------------------------------------------

local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local COLORS = {
	bg = Color3.fromRGB(32, 32, 32),
	text = Color3.fromRGB(230, 230, 230),
	textDim = Color3.fromRGB(140, 140, 140),
	connected = Color3.fromRGB(63, 185, 80),
	disconnected = Color3.fromRGB(218, 54, 51),
}

local TWEEN_INFO = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local StatusPanel = {}

local function createRow(label, value, parent, yPos)
	local row = Instance.new("Frame")
	row.Name = label .. "Row"
	row.Size = UDim2.new(1, -24, 0, 22)
	row.Position = UDim2.new(0, 12, 0, yPos)
	row.BackgroundTransparency = 1
	row.Parent = parent

	local labelText = Instance.new("TextLabel")
	labelText.Name = "Label"
	labelText.Size = UDim2.new(0.5, 0, 1, 0)
	labelText.BackgroundTransparency = 1
	labelText.Text = label
	labelText.TextColor3 = COLORS.textDim
	labelText.TextSize = 12
	labelText.FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Regular)
	labelText.TextXAlignment = Enum.TextXAlignment.Left
	labelText.Parent = row

	local valueText = Instance.new("TextLabel")
	valueText.Name = "Value"
	valueText.Size = UDim2.new(0.5, 0, 1, 0)
	valueText.Position = UDim2.new(0.5, 0, 0, 0)
	valueText.BackgroundTransparency = 1
	valueText.Text = value
	valueText.TextColor3 = COLORS.text
	valueText.TextSize = 12
	valueText.FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Medium)
	valueText.TextXAlignment = Enum.TextXAlignment.Right
	valueText.Parent = row

	return valueText
end

function StatusPanel.new(props)
	props = props or {}

	local frame = Instance.new("Frame")
	frame.Name = "StatusPanel"
	frame.Size = UDim2.new(1, 0, 0, 130)
	frame.BackgroundColor3 = COLORS.bg
	frame.BorderSizePixel = 0

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = frame

	local metrics = {}
	local labels = {
		{ "Status", "Disconnected", 10 },
		{ "Host", "localhost", 32 },
		{ "Port", "-", 54 },
		{ "Commands", "0", 76 },
		{ "Uptime", "00:00:00", 98 },
	}

	for _, data in ipairs(labels) do
		metrics[data[1]] = createRow(data[1], data[2], frame, data[3])
	end

	metrics["Status"].TextColor3 = COLORS.disconnected

	local startTime = tick()

	local function updateUptime()
		local elapsed = tick() - startTime
		local h = math.floor(elapsed / 3600)
		local m = math.floor((elapsed % 3600) / 60)
		local s = math.floor(elapsed % 60)
		metrics["Uptime"].Text = string.format("%02d:%02d:%02d", h, m, s)
	end

	RunService.Heartbeat:Connect(updateUptime)

	function frame.SetConnection(connected, host, port)
		if connected then
			metrics["Status"].Text = "Connected"
			TweenService:Create(metrics["Status"], TWEEN_INFO, { TextColor3 = COLORS.connected }):Play()
			metrics["Host"].Text = host or "localhost"
			metrics["Port"].Text = tostring(port or "-")
		else
			metrics["Status"].Text = "Disconnected"
			TweenService:Create(metrics["Status"], TWEEN_INFO, { TextColor3 = COLORS.disconnected }):Play()
		end
	end

	function frame.SetCommandCount(count)
		metrics["Commands"].Text = tostring(count)
	end

	function frame.GetCommandCount()
		return tonumber(metrics["Commands"].Text) or 0
	end

	if props.parent then
		frame.Parent = props.parent
	end

	return frame
end

return StatusPanel
