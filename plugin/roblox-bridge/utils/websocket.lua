--------------------------------------------------------------------------------
-- WebSocket Connection Manager
-- Pure WebSocket communication with MCP server. No HTTP fallback.
--
-- Features:
--   - Direct WebSocket connection (no health check)
--   - Version handshake with compatibility check
--   - Automatic reconnection with exponential backoff
--   - Ping/pong keepalive
--   - Clean disconnect handling
--------------------------------------------------------------------------------
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
		lastPingTime = 0,
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

	--------------------------------------------------------------------------------
	-- Connection
	--------------------------------------------------------------------------------
	local function connect()
		if isConnecting or wsClient then return false end

		isConnecting = true
		local wsUrl = "ws://localhost:" .. config.BASE_PORT .. "/ws"

		local success, client = pcall(function()
			return Services.HttpService:CreateWebStreamClient(Enum.WebStreamClientType.WebSocket, {
				Url = wsUrl,
				Headers = { ["X-Plugin-Version"] = config.VERSION },
			})
		end)

		if not success or not client then
			isConnecting = false
			return false
		end

		wsClient = client

		-- Message handler
		wsClient.MessageReceived:Connect(function(message)
			local ok, data = pcall(function()
				return Services.HttpService:JSONDecode(message)
			end)

			if not ok or not data then return end

			-- Server sends "connected" on WebSocket open
			if data.type == "connected" then
				state.serverVersion = data.serverVersion
				-- Send handshake with our version
				local handshake = Services.HttpService:JSONEncode({
					type = "handshake",
					version = config.VERSION
				})
				pcall(function() wsClient:Send(handshake) end)

			-- Server confirms handshake
			elseif data.type == "handshake_ok" then
				if not state.isConnected then
					state.isConnected = true
					isConnecting = false
					state.retryInterval = config.RETRY_INTERVAL
					task.spawn(function()
						callbacks.onConnected(config.BASE_PORT)
					end)
				end

			-- Version mismatch error
			elseif data.type == "error" then
				if data.code == "VERSION_MISMATCH" then
					warn("[MCP] Version mismatch! Plugin:", config.VERSION, "Server:", data.serverVersion or "unknown")
				end
				task.spawn(function()
					callbacks.onError(data.code, data.message)
				end)

			-- Batch of commands
			elseif data.type == "commands" and data.data then
				for _, cmd in ipairs(data.data) do
					task.spawn(function()
						callbacks.onCommand(cmd)
					end)
				end

			-- Single command
			elseif data.type == "command" and data.data then
				task.spawn(function()
					callbacks.onCommand(data.data)
				end)

			-- Pong response (keepalive)
			elseif data.type == "pong" then
				state.lastPingTime = tick()
			end
		end)

		-- Connection closed
		wsClient.Closed:Connect(function()
			local wasConnected = state.isConnected
			state.isConnected = false
			isConnecting = false
			wsClient = nil

			task.spawn(function()
				callbacks.onDisconnected()
			end)

			-- Schedule reconnect if still enabled
			if state.isEnabled and not retryScheduled then
				retryScheduled = true
				task.delay(state.retryInterval, function()
					retryScheduled = false
					-- Exponential backoff
					state.retryInterval = math.min(state.retryInterval * 1.5, config.MAX_RETRY_INTERVAL)
					if state.isEnabled and not state.isConnected and not isConnecting then
						connect()
					end
				end)
			end
		end)

		-- Error handler
		wsClient.Error:Connect(function(statusCode, errorMessage)
			-- Only log unexpected errors, not connection refused
			if statusCode ~= 0 then
				print("[MCP] WebSocket error:", statusCode, "-", errorMessage)
			end
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
		isConnecting = false
		task.spawn(function()
			callbacks.onDisconnected()
		end)
	end

	--------------------------------------------------------------------------------
	-- Send Result
	--------------------------------------------------------------------------------
	function manager.sendResult(id, success, result, err)
		if not wsClient or not state.isConnected then
			return false
		end

		local payload = Services.HttpService:JSONEncode({
			type = "result",
			data = {
				id = id,
				success = success,
				result = result,
				error = err
			}
		})

		local ok = pcall(function()
			wsClient:Send(payload)
		end)

		return ok
	end

	--------------------------------------------------------------------------------
	-- Keepalive Ping
	--------------------------------------------------------------------------------
	function manager.sendPing()
		if not wsClient or not state.isConnected then
			return false
		end

		local payload = Services.HttpService:JSONEncode({
			type = "ping",
			timestamp = tick()
		})

		pcall(function()
			wsClient:Send(payload)
		end)

		return true
	end

	--------------------------------------------------------------------------------
	-- Connection Loop
	--------------------------------------------------------------------------------
	function manager.startLoop()
		-- Main connection loop
		coroutine.wrap(function()
			print("[MCP] Bridge starting (v" .. config.VERSION .. ")...")

			while true do
				task.wait(0.5)

				if state.isEnabled then
					-- Try to connect if not connected
					if not state.isConnected and not wsClient and not isConnecting then
						connect()
						task.wait(state.retryInterval)
					end
				else
					-- Disconnect if disabled
					if state.isConnected or wsClient then
						manager.disconnect()
					end
				end
			end
		end)()

		-- Keepalive ping loop
		coroutine.wrap(function()
			while true do
				task.wait(30) -- Ping every 30 seconds
				if state.isConnected then
					manager.sendPing()
				end
			end
		end)()
	end

	return manager
end

return WebSocket
