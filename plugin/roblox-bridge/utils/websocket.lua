--!optimize 2
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

-- Localize globals for performance
local pairs = pairs
local ipairs = ipairs
local pcall = pcall
local tick = tick
local math_min = math.min
local task_spawn = task.spawn
local task_wait = task.wait
local task_delay = task.delay
local coroutine_wrap = coroutine.wrap

local Services = require(script.Parent.services)

-- Cache HttpService for JSON encoding/decoding
local HttpService = Services.HttpService
local JSONEncode = HttpService.JSONEncode
local JSONDecode = HttpService.JSONDecode

local WebSocket = {}

--------------------------------------------------------------------------------
-- Create Connection Manager
--------------------------------------------------------------------------------
function WebSocket.create(config)
	-- Per-instance connection state (inside closure, not module-level)
	local wsClient = nil
	local isConnecting = false
	local retryScheduled = false
	local state = {
		isConnected = false,
		isEnabled = false,
		serverVersion = nil,
		retryInterval = config.RETRY_INTERVAL,
		retryCount = 0,
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
		state.retryCount = 0
	end

	--------------------------------------------------------------------------------
	-- Connection
	--------------------------------------------------------------------------------

	--------------------------------------------------------------------------------
	-- Check if Studio is in Edit mode (not Play/Run)
	-- Protected with pcall to prevent crashes if RunService unavailable
	-- @returns boolean - true if in Edit mode, false otherwise
	-- @private
	--------------------------------------------------------------------------------
	local function isEditMode()
		local success, result = pcall(function()
			local RunService = Services.RunService
			return not RunService:IsRunning() and not RunService:IsRunMode()
		end)
		return success and result
	end

	local function connect()
		if isConnecting or wsClient then return false end

		-- Don't connect if not in Edit mode
		if not isEditMode() then
			return false
		end

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
			local ok, data = pcall(JSONDecode, HttpService, message)

			if not ok or not data then return end

			local msgType = data.type

			-- Server sends "connected" on WebSocket open
			if msgType == "connected" then
				state.serverVersion = data.serverVersion
				-- Send handshake with our version
				local handshake = JSONEncode(HttpService, {
					type = "handshake",
					version = config.VERSION
				})
				pcall(function() wsClient:Send(handshake) end)

			-- Server confirms handshake
			elseif msgType == "handshake_ok" then
				if not state.isConnected then
					state.isConnected = true
					isConnecting = false
					state.retryInterval = config.RETRY_INTERVAL
					state.retryCount = 0
					task_spawn(function()
						callbacks.onConnected(config.BASE_PORT)
					end)
				end

			-- Version mismatch error
			elseif msgType == "error" then
				if data.code == "VERSION_MISMATCH" then
					warn("[MCP] Version mismatch! Plugin:", config.VERSION, "Server:", data.serverVersion or "unknown")
				end
				task_spawn(function()
					callbacks.onError(data.code, data.message)
				end)

			-- Batch of commands
			elseif msgType == "commands" then
				local cmdData = data.data
				if cmdData then
					local onCommand = callbacks.onCommand
					for _, cmd in ipairs(cmdData) do
						task_spawn(onCommand, cmd)
					end
				end

			-- Single command
			elseif msgType == "command" then
				local cmdData = data.data
				if cmdData then
					task_spawn(callbacks.onCommand, cmdData)
				end

			-- Pong response (keepalive)
			elseif msgType == "pong" then
				state.lastPingTime = tick()
			end
		end)

		-- Connection closed
		wsClient.Closed:Connect(function()
			state.isConnected = false
			isConnecting = false
			wsClient = nil

			task_spawn(callbacks.onDisconnected)

			-- Schedule reconnect if still enabled and under retry limit
			state.retryCount = state.retryCount + 1
			if state.isEnabled and not retryScheduled and state.retryCount <= config.MAX_RETRIES then
				retryScheduled = true
				task_delay(state.retryInterval, function()
					retryScheduled = false
					-- Exponential backoff
					state.retryInterval = math_min(state.retryInterval * 1.5, config.MAX_RETRY_INTERVAL)
					if state.isEnabled and not state.isConnected and not isConnecting then
						connect()
					end
				end)
			elseif state.retryCount == config.MAX_RETRIES + 1 then
				-- Only log once when we first exceed the limit
				print("[MCP] Max retries reached, stopping reconnection attempts")
				print("[MCP] Click 'Connect' to try again")
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
		task_spawn(callbacks.onDisconnected)
	end

	--------------------------------------------------------------------------------
	-- Send Result
	--------------------------------------------------------------------------------
	function manager.sendResult(id, success, result, err)
		local client = wsClient
		if not client or not state.isConnected then
			return false
		end

		local payload = JSONEncode(HttpService, {
			type = "result",
			data = {
				id = id,
				success = success,
				data = result,
				error = err
			}
		})

		local ok = pcall(function()
			client:Send(payload)
		end)

		return ok
	end

	--------------------------------------------------------------------------------
	-- Keepalive Ping
	--------------------------------------------------------------------------------
	function manager.sendPing()
		local client = wsClient
		if not client or not state.isConnected then
			return false
		end

		local payload = JSONEncode(HttpService, {
			type = "ping",
			timestamp = tick()
		})

		pcall(function()
			client:Send(payload)
		end)

		return true
	end

	--------------------------------------------------------------------------------
	-- Connection Loop
	--------------------------------------------------------------------------------
	function manager.startLoop()
		-- Main connection loop
		coroutine_wrap(function()
			print("[MCP] Bridge starting (v" .. config.VERSION .. ")...")

			while true do
				task_wait(0.5)

				if state.isEnabled then
					-- Try to connect if not connected and haven't exceeded retries
					if not state.isConnected and not wsClient and not isConnecting then
						if state.retryCount <= config.MAX_RETRIES then
							connect()
							task_wait(state.retryInterval)
						end
						-- If max retries exceeded, just wait for manual reconnect
					end
				else
					-- Disconnect if disabled
					if state.isConnected or wsClient then
						manager.disconnect()
					end
					-- Reset retry count when disabled (allows fresh start on re-enable)
					state.retryCount = 0
				end
			end
		end)()

		-- Keepalive ping loop
		coroutine_wrap(function()
			while true do
				task_wait(30) -- Ping every 30 seconds
				if state.isConnected then
					manager.sendPing()
				end
			end
		end)()
	end

	return manager
end

return WebSocket
