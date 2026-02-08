--!optimize 2
--------------------------------------------------------------------------------
-- Action Buttons Component
-- Secondary actions, consistent sizing, grouped proximity
--------------------------------------------------------------------------------

local Theme = require(script.Parent.Parent.theme)
local Services = require(script.Parent.Parent.Parent.utils.services)
local Button = require(script.Parent.button)

local ActionButtons = {}

function ActionButtons.create(pluginRef)
	-- Container for button row (40px = 5 grid units)
	local frame = Instance.new("Frame")
	frame.Name = "ActionButtons"
	frame.Size = UDim2.new(1, 0, 0, 40)
	frame.BackgroundTransparency = 1

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.Padding = UDim.new(0, Theme.SPACING.sm)
	layout.Parent = frame

	local function createHistoryButton(name, method, order)
		local btn = Button.create(pluginRef, {
			name = name,
			text = name,
			variant = "secondary",
			size = "md",
			size_override = UDim2.new(0.5, -4, 0, 40),
			onClick = function()
				pcall(method, Services.ChangeHistoryService)
			end,
		})
		btn.LayoutOrder = order
		btn.Parent = frame
	end

	createHistoryButton("Undo", Services.ChangeHistoryService.Undo, 1)
	createHistoryButton("Redo", Services.ChangeHistoryService.Redo, 2)

	return {
		frame = frame,
	}
end

return ActionButtons
