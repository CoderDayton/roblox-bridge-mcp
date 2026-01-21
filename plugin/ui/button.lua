--------------------------------------------------------------------------------
-- Button Component
-- Floating button with drop shadow and smooth transitions
--------------------------------------------------------------------------------

local TweenService = game:GetService("TweenService")

local Button = {}

local COLORS = {
	bg = Color3.fromRGB(50, 50, 50),
	bgHover = Color3.fromRGB(60, 60, 60),
	bgActive = Color3.fromRGB(45, 45, 45),
	primary = Color3.fromRGB(56, 139, 253),
	primaryHover = Color3.fromRGB(88, 166, 255),
	primaryActive = Color3.fromRGB(47, 129, 242),
	text = Color3.fromRGB(230, 230, 230),
	shadow = Color3.fromRGB(0, 0, 0),
}

local TWEEN_INFO = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local TWEEN_FAST = TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

function Button.new(props)
	props = props or {}

	local text = props.text or "Button"
	local onClick = props.onClick or function() end
	local primary = props.primary or false

	-- Container for shadow effect
	local container = Instance.new("Frame")
	container.Name = props.name or "Button"
	container.Size = props.size or UDim2.new(1, 0, 0, 32)
	container.BackgroundTransparency = 1

	-- Shadow
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

	-- Button
	local btn = Instance.new("TextButton")
	btn.Name = "Btn"
	btn.Size = UDim2.new(1, 0, 1, 0)
	btn.Position = UDim2.new(0, 0, 0, 0)
	btn.BackgroundColor3 = primary and COLORS.primary or COLORS.bg
	btn.BorderSizePixel = 0
	btn.Text = text
	btn.TextColor3 = COLORS.text
	btn.TextSize = 13
	btn.FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Medium)
	btn.AutoButtonColor = false
	btn.ZIndex = 2
	btn.Parent = container

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = btn

	local baseColor = primary and COLORS.primary or COLORS.bg
	local hoverColor = primary and COLORS.primaryHover or COLORS.bgHover
	local activeColor = primary and COLORS.primaryActive or COLORS.bgActive

	btn.MouseEnter:Connect(function()
		TweenService:Create(btn, TWEEN_INFO, { BackgroundColor3 = hoverColor }):Play()
	end)

	btn.MouseLeave:Connect(function()
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

function Button.newPrimary(props)
	props = props or {}
	props.primary = true
	return Button.new(props)
end

return Button
