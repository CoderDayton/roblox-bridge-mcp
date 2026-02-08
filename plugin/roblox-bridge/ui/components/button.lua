--!optimize 2
--------------------------------------------------------------------------------
-- Button Component
-- 8-point grid aligned, proper touch targets, visual feedback
--------------------------------------------------------------------------------

local Theme = require(script.Parent.Parent.theme)

local Button = {}

function Button.create(pluginRef, props)
	local text = props.text or "Button"
	local onClick = props.onClick or function() end
	local variant = props.variant or "secondary" -- primary, secondary, ghost
	local size = props.size or "md" -- sm, md, lg

	-- Size presets (8-point grid)
	local heights = { sm = 32, md = 40, lg = 48 }
	local paddings = { sm = 12, md = 16, lg = 20 }
	local textSizes = { sm = 13, md = 14, lg = 15 }

	local height = heights[size] or heights.md
	local hPadding = paddings[size] or paddings.md
	local textSize = textSizes[size] or textSizes.md

	-- Color schemes
	local schemes = {
		primary = {
			bg = Theme.COLORS.interactive,
			bgHover = Theme.COLORS.interactiveHover,
			bgActive = Theme.COLORS.interactiveActive,
			text = Theme.COLORS.textPrimary,
		},
		secondary = {
			bg = Theme.COLORS.bgSubtle,
			bgHover = Theme.COLORS.bgMuted,
			bgActive = Theme.COLORS.bgSurface,
			text = Theme.COLORS.textPrimary,
		},
		ghost = {
			bg = Theme.COLORS.bgSurface,
			bgHover = Theme.COLORS.bgMuted,
			bgActive = Theme.COLORS.bgSubtle,
			text = Theme.COLORS.textSecondary,
		},
	}

	local scheme = schemes[variant] or schemes.secondary

	-- Container (for shadow positioning)
	local container = Instance.new("Frame")
	container.Name = props.name or "Button"
	container.Size = props.size_override or UDim2.new(1, 0, 0, height)
	container.BackgroundTransparency = 1

	-- Shadow layer (elevation)
	local shadow = Instance.new("Frame")
	shadow.Name = "Shadow"
	shadow.Size = UDim2.new(1, 0, 1, 0)
	shadow.Position = UDim2.new(0, 0, 0, 2)
	shadow.BackgroundColor3 = Theme.COLORS.shadow
	shadow.BackgroundTransparency = 0.88
	shadow.BorderSizePixel = 0
	shadow.ZIndex = 1
	shadow.Parent = container

	local shadowCorner = Instance.new("UICorner")
	shadowCorner.CornerRadius = UDim.new(0, Theme.RADIUS.md)
	shadowCorner.Parent = shadow

	-- Button surface
	local btn = Instance.new("TextButton")
	btn.Name = "Surface"
	btn.Size = UDim2.new(1, 0, 1, 0)
	btn.BackgroundColor3 = scheme.bg
	btn.BorderSizePixel = 0
	btn.Text = text
	btn.TextColor3 = scheme.text
	btn.TextSize = textSize
	btn.FontFace = Theme.FONTS.Medium
	btn.AutoButtonColor = false
	btn.ZIndex = 2
	btn.Parent = container

	local btnCorner = Instance.new("UICorner")
	btnCorner.CornerRadius = UDim.new(0, Theme.RADIUS.md)
	btnCorner.Parent = btn

	local btnPadding = Instance.new("UIPadding")
	btnPadding.PaddingLeft = UDim.new(0, hPadding)
	btnPadding.PaddingRight = UDim.new(0, hPadding)
	btnPadding.Parent = btn

	-- State tracking
	local isHovered = false
	local isPressed = false

	local function updateVisual()
		local targetBg = scheme.bg
		local shadowOffset = 2
		local shadowAlpha = 0.88

		if isPressed then
			targetBg = scheme.bgActive
			shadowOffset = 1
			shadowAlpha = 0.92
		elseif isHovered then
			targetBg = scheme.bgHover
			shadowOffset = 3
			shadowAlpha = 0.85
		end

		Theme.tween(btn, "instant", { BackgroundColor3 = targetBg })
		Theme.tween(shadow, "instant", {
			Position = UDim2.new(0, 0, 0, shadowOffset),
			BackgroundTransparency = shadowAlpha,
		})
	end

	-- Interactions
	btn.MouseEnter:Connect(function()
		isHovered = true
		pluginRef:GetMouse().Icon = "rbxasset://SystemCursors/PointingHand"
		updateVisual()
	end)

	btn.MouseLeave:Connect(function()
		isHovered = false
		isPressed = false
		pluginRef:GetMouse().Icon = ""
		updateVisual()
	end)

	btn.MouseButton1Down:Connect(function()
		isPressed = true
		updateVisual()
	end)

	btn.MouseButton1Up:Connect(function()
		isPressed = false
		updateVisual()
		if isHovered then
			onClick()
		end
	end)

	return container
end

return Button
