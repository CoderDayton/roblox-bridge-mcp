--!optimize 2
--------------------------------------------------------------------------------
-- Connect Button Component
-- Primary action, prominent placement, clear state feedback
--------------------------------------------------------------------------------

local tick = tick
local Theme = require(script.Parent.Parent.theme)
local Button = require(script.Parent.button)

local ConnectButton = {}

local DEBOUNCE_TIME = 0.5

function ConnectButton.create(pluginRef, props)
	local onClick = props.onClick or function() end
	local lastClickTime = 0

	-- Container (48px = 6 grid units for prominent action)
	local container = Instance.new("Frame")
	container.Name = "ConnectButton"
	container.Size = UDim2.new(1, 0, 0, 48)
	container.BackgroundTransparency = 1

	local btn = Button.create(pluginRef, {
		name = "ToggleConnection",
		text = "Connect",
		variant = "primary",
		size = "lg",
		size_override = UDim2.new(1, 0, 0, 48),
		onClick = function()
			local now = tick()
			if now - lastClickTime < DEBOUNCE_TIME then return end
			lastClickTime = now
			onClick()
		end,
	})
	btn.Parent = container

	local api = {
		frame = container,
	}

	function api.update(state)
		local surface = btn:FindFirstChild("Surface")
		if surface then
			if state.isConnecting then
				surface.Text = "Connecting..."
			elseif state.connected then
				surface.Text = "Disconnect"
			else
				surface.Text = "Connect"
			end
		end
	end

	return api
end

return ConnectButton
