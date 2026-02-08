--!optimize 2
--------------------------------------------------------------------------------
-- Tab Button Component
-- Minimal, clear active state, smooth transitions
--------------------------------------------------------------------------------

local Theme = require(script.Parent.Parent.theme)

local TabButton = {}

function TabButton.create(pluginRef, props)
	local text = props.text or "Tab"
	local onClick = props.onClick or function() end
	local isActive = props.isActive or false

	local btn = Instance.new("TextButton")
	btn.Name = props.name or "TabButton"
	btn.Size = props.size or UDim2.new(0, 56, 0, 28)
	btn.BackgroundColor3 = isActive and Theme.COLORS.interactive or Theme.COLORS.bgSubtle
	btn.BackgroundTransparency = isActive and 0 or 0.4
	btn.BorderSizePixel = 0
	btn.Text = text
	btn.TextColor3 = isActive and Theme.COLORS.textPrimary or Theme.COLORS.textTertiary
	btn.TextSize = Theme.TYPE.caption.size
	btn.FontFace = isActive and Theme.FONTS.SemiBold or Theme.FONTS.Medium
	btn.AutoButtonColor = false

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, Theme.RADIUS.sm)
	corner.Parent = btn

	-- Hover state (only when not active)
	btn.MouseEnter:Connect(function()
		pluginRef:GetMouse().Icon = "rbxasset://SystemCursors/PointingHand"
		if not btn:GetAttribute("Active") then
			Theme.tween(btn, "instant", {
				BackgroundTransparency = 0.2,
				TextColor3 = Theme.COLORS.textSecondary,
			})
		end
	end)

	btn.MouseLeave:Connect(function()
		pluginRef:GetMouse().Icon = ""
		if not btn:GetAttribute("Active") then
			Theme.tween(btn, "instant", {
				BackgroundTransparency = 0.4,
				TextColor3 = Theme.COLORS.textTertiary,
			})
		end
	end)

	btn.MouseButton1Click:Connect(onClick)
	btn:SetAttribute("Active", isActive)

	return btn
end

function TabButton.setActive(btn, isActive)
	btn:SetAttribute("Active", isActive)
	Theme.tween(btn, "fast", {
		BackgroundColor3 = isActive and Theme.COLORS.interactive or Theme.COLORS.bgSubtle,
		BackgroundTransparency = isActive and 0 or 0.4,
		TextColor3 = isActive and Theme.COLORS.textPrimary or Theme.COLORS.textTertiary,
	})
	btn.FontFace = isActive and Theme.FONTS.SemiBold or Theme.FONTS.Medium
end

return TabButton
