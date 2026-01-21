--------------------------------------------------------------------------------
-- Settings Component
-- API key input with smooth transitions
--------------------------------------------------------------------------------

local TweenService = game:GetService("TweenService")

local COLORS = {
	bg = Color3.fromRGB(32, 32, 32),
	inputBg = Color3.fromRGB(40, 40, 40),
	inputBgFocus = Color3.fromRGB(45, 45, 45),
	text = Color3.fromRGB(230, 230, 230),
	textDim = Color3.fromRGB(110, 110, 110),
	placeholder = Color3.fromRGB(90, 90, 90),
	primary = Color3.fromRGB(56, 139, 253),
	primaryHover = Color3.fromRGB(88, 166, 255),
	primaryActive = Color3.fromRGB(47, 129, 242),
	success = Color3.fromRGB(63, 185, 80),
	error = Color3.fromRGB(218, 54, 51),
	border = Color3.fromRGB(55, 55, 55),
	borderFocus = Color3.fromRGB(56, 139, 253),
}

local TWEEN_INFO = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local Settings = {}

function Settings.new(props)
	props = props or {}

	local onSaveKey = props.onSaveKey or function() end
	local getCurrentKey = props.getCurrentKey or function() return "not set" end

	local frame = Instance.new("Frame")
	frame.Name = "SettingsPanel"
	frame.Size = UDim2.new(1, 0, 0, 100)
	frame.BackgroundColor3 = COLORS.bg
	frame.BorderSizePixel = 0

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = frame

	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.Size = UDim2.new(1, -24, 0, 24)
	label.Position = UDim2.new(0, 12, 0, 8)
	label.BackgroundTransparency = 1
	label.Text = "API Key"
	label.TextColor3 = COLORS.textDim
	label.TextSize = 12
	label.FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Medium)
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Parent = frame

	local inputContainer = Instance.new("Frame")
	inputContainer.Name = "InputContainer"
	inputContainer.Size = UDim2.new(1, -24, 0, 32)
	inputContainer.Position = UDim2.new(0, 12, 0, 32)
	inputContainer.BackgroundColor3 = COLORS.inputBg
	inputContainer.BorderSizePixel = 0
	inputContainer.Parent = frame

	local inputCorner = Instance.new("UICorner")
	inputCorner.CornerRadius = UDim.new(0, 4)
	inputCorner.Parent = inputContainer

	local inputStroke = Instance.new("UIStroke")
	inputStroke.Color = COLORS.border
	inputStroke.Thickness = 1
	inputStroke.Parent = inputContainer

	local inputBox = Instance.new("TextBox")
	inputBox.Name = "Input"
	inputBox.Size = UDim2.new(1, -90, 1, 0)
	inputBox.Position = UDim2.new(0, 10, 0, 0)
	inputBox.BackgroundTransparency = 1
	inputBox.Text = ""
	inputBox.PlaceholderText = "Paste key here..."
	inputBox.PlaceholderColor3 = COLORS.placeholder
	inputBox.TextColor3 = COLORS.text
	inputBox.TextSize = 12
	inputBox.FontFace = Font.new("rbxasset://fonts/families/RobotoMono.json", Enum.FontWeight.Regular)
	inputBox.TextXAlignment = Enum.TextXAlignment.Left
	inputBox.ClearTextOnFocus = false
	inputBox.Parent = inputContainer

	local saveBtn = Instance.new("TextButton")
	saveBtn.Name = "SaveBtn"
	saveBtn.Size = UDim2.new(0, 60, 0, 24)
	saveBtn.Position = UDim2.new(1, -68, 0.5, -12)
	saveBtn.BackgroundColor3 = COLORS.primary
	saveBtn.BorderSizePixel = 0
	saveBtn.Text = "Save"
	saveBtn.TextColor3 = COLORS.text
	saveBtn.TextSize = 12
	saveBtn.FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Medium)
	saveBtn.AutoButtonColor = false
	saveBtn.Parent = inputContainer

	local saveBtnCorner = Instance.new("UICorner")
	saveBtnCorner.CornerRadius = UDim.new(0, 4)
	saveBtnCorner.Parent = saveBtn

	local statusLabel = Instance.new("TextLabel")
	statusLabel.Name = "Status"
	statusLabel.Size = UDim2.new(1, -24, 0, 20)
	statusLabel.Position = UDim2.new(0, 12, 0, 70)
	statusLabel.BackgroundTransparency = 1
	statusLabel.Text = "Current: " .. getCurrentKey()
	statusLabel.TextColor3 = COLORS.textDim
	statusLabel.TextSize = 10
	statusLabel.FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Regular)
	statusLabel.TextXAlignment = Enum.TextXAlignment.Left
	statusLabel.TextTruncate = Enum.TextTruncate.AtEnd
	statusLabel.Parent = frame

	inputBox.Focused:Connect(function()
		TweenService:Create(inputStroke, TWEEN_INFO, { Color = COLORS.borderFocus }):Play()
		TweenService:Create(inputContainer, TWEEN_INFO, { BackgroundColor3 = COLORS.inputBgFocus }):Play()
	end)

	inputBox.FocusLost:Connect(function()
		TweenService:Create(inputStroke, TWEEN_INFO, { Color = COLORS.border }):Play()
		TweenService:Create(inputContainer, TWEEN_INFO, { BackgroundColor3 = COLORS.inputBg }):Play()
	end)

	saveBtn.MouseEnter:Connect(function()
		TweenService:Create(saveBtn, TWEEN_INFO, { BackgroundColor3 = COLORS.primaryHover }):Play()
	end)

	saveBtn.MouseLeave:Connect(function()
		TweenService:Create(saveBtn, TWEEN_INFO, { BackgroundColor3 = COLORS.primary }):Play()
	end)

	saveBtn.MouseButton1Down:Connect(function()
		TweenService:Create(saveBtn, TWEEN_INFO, { BackgroundColor3 = COLORS.primaryActive }):Play()
	end)

	saveBtn.MouseButton1Click:Connect(function()
		TweenService:Create(saveBtn, TWEEN_INFO, { BackgroundColor3 = COLORS.primaryHover }):Play()
		local key = inputBox.Text
		if key and key ~= "" then
			onSaveKey(key)
			statusLabel.Text = "Saved"
			TweenService:Create(statusLabel, TWEEN_INFO, { TextColor3 = COLORS.success }):Play()
			inputBox.Text = ""
			task.delay(2, function()
				statusLabel.Text = "Current: " .. getCurrentKey()
				TweenService:Create(statusLabel, TWEEN_INFO, { TextColor3 = COLORS.textDim }):Play()
			end)
		end
	end)

	if props.parent then
		frame.Parent = props.parent
	end

	return frame
end

return Settings
