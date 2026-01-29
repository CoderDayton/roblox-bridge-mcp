-- WebSocket connection management
local Services = require(script.Parent.services)

local WebSocket = {}

--------------------------------------------------------------------------------
-- State
--------------------------------------------------------------------------------

local wsClient = nil
local isConnecting = false
local retryScheduled = false

--------------------------------------------------------------------------------
-- Create Connection Manager
--------------------------------------------------------------------------------

function WebSocket.create(config)
	local state = {
		isConnected = false,
		isEnabled = false,
		serverVersion = nil,
		retryInterval = config.RETRY_INTERVAL,
	}

	local callbacks = {
		onConnected = function() end,
		onDisconnected = function() end,
		onCommand = function() end,
		onError = function() end,
	}

	local manager = {}

	function manager.setCallbacks(cbs)
		for k, v in pairs(cbs) do
			if callbacks[k] then callbacks[k] = v end
		end
	end

	function manager.getState()
		return {
			isConnected = state.isConnected,
			isEnabled = state.isEnabled,
			serverVersion = state.serverVersion,
		}
	end

	function manager.setEnabled(enabled)
		state.isEnabled = enabled
		if not enabled then
			manager.disconnect()
		end
	end

	function manager.resetRetry()
		state.retryInterval = config.RETRY_INTERVAL
	end

	local function connect()
		if isConnecting then return false end
		if wsClient then
			pcall(function() wsClient:Close() end)
			wsClient = nil
			task.wait(0.5)
		end

		isConnecting = true
		local wsUrl = "ws://localhost:" .. config.BASE_PORT .. "/ws"

		local success, client = pcall(function()
			return Services.HttpService:CreateWebStreamClient(Enum.WebStreamClientType.WebSocket, {
				Url = wsUrl,
				Headers = { ["X-Plugin-Version"] = config.VERSION },
			})
		end)

		if not success then
			isConnecting = false
			return false
		end

		wsClient = client

		wsClient.MessageReceived:Connect(function(message)
			local ok, data = pcall(function() return Services.HttpService:JSONDecode(message) end)
			if ok and data then
				if data.type == "connected" then
					state.serverVersion = data.serverVersion
					local handshake = Services.HttpService:JSONEncode({ type = "handshake", version = config.VERSION })
					pcall(function() wsClient:Send(handshake) end)
				elseif data.type == "handshake_ok" then
					if not state.isConnected then
						state.isConnected = true
						isConnecting = false
						state.retryInterval = config.RETRY_INTERVAL
						task.spawn(function() callbacks.onConnected(config.BASE_PORT) end)
					end
				elseif data.type == "error" then
					if data.code == "VERSION_MISMATCH" then
						warn("[MCP] Version mismatch! Plugin:", config.VERSION, "Server:", data.serverVersion or "unknown")
					end
					task.spawn(function() callbacks.onError(data.code, data.message) end)
				elseif data.type == "commands" and data.data then
					for _, cmd in ipairs(data.data) do
						task.spawn(function() callbacks.onCommand(cmd) end)
					end
				elseif data.type == "command" and data.data then
					task.spawn(function() callbacks.onCommand(data.data) end)
				end
			end
		end)

		wsClient.Closed:Connect(function()
			state.isConnected = false
			isConnecting = false
			wsClient = nil
			task.spawn(function() callbacks.onDisconnected() end)

			if state.isEnabled and not retryScheduled then
				retryScheduled = true
				task.delay(state.retryInterval, function()
					retryScheduled = false
					state.retryInterval = math.min(state.retryInterval * 1.5, config.MAX_RETRY_INTERVAL)
					if state.isEnabled and not state.isConnected and not isConnecting then
						connect()
					end
				end)
			end
		end)

		wsClient.Error:Connect(function(statusCode, errorMessage)
			print("[MCP] WebSocket error:", statusCode, "-", errorMessage)
		end)

		return true
	end

	function manager.connect()
		return connect()
	end

	function manager.disconnect()
		if wsClient then
			pcall(function() wsClient:Close() end)
			wsClient = nil
		end
		state.isConnected = false
		state.serverVersion = nil
		task.spawn(function() callbacks.onDisconnected() end)
	end

	function manager.sendResult(id, success, result, err)
		if wsClient and state.isConnected then
			local payload = Services.HttpService:JSONEncode({
				type = "result",
				data = { id = id, success = success, result = result, error = err }
			})
			pcall(function() wsClient:Send(payload) end)
			return true
		end
		return false
	end

	function manager.checkServerHealth()
		local healthUrl = "http://localhost:" .. config.BASE_PORT .. "/health"
		local ok = pcall(function() return Services.HttpService:GetAsync(healthUrl, false) end)
		return ok
	end

	-- Connection manager loop
	function manager.startLoop()
		coroutine.wrap(function()
			print("[MCP] Bridge starting (v" .. config.VERSION .. ")...")
			while true do
				task.wait(0.5)
				if state.isEnabled then
					if not state.isConnected and not wsClient then
						if manager.checkServerHealth() then
							connect()
							task.wait(2)
						else
							task.wait(state.retryInterval)
							state.retryInterval = math.min(state.retryInterval * 1.5, config.MAX_RETRY_INTERVAL)
						end
					end
				else
					if state.isConnected or wsClient then
						manager.disconnect()
					end
				end
			end
		end)()
	end

	return manager
end

return WebSocket
