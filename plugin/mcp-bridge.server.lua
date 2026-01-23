--------------------------------------------------------------------------------
-- MCP Bridge Plugin for Roblox Studio (Single File - No UI)
-- Connects Studio to MCP server via HTTP polling
--------------------------------------------------------------------------------

-- Services (alphabetical per Roblox style guide)
local ChangeHistoryService = game:GetService("ChangeHistoryService")
local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local HttpService = game:GetService("HttpService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local Selection = game:GetService("Selection")
local SoundService = game:GetService("SoundService")
local TextChatService = game:GetService("TextChatService")

--------------------------------------------------------------------------------
-- Configuration
--------------------------------------------------------------------------------

local VERSION = "1.0.0"

local CONFIG = {
	BASE_PORT = 62847,
	PORT_RANGE = 10, -- Try 62847-62856
	RETRY_INTERVAL = 2.0,
	RECONNECT_INTERVAL = 5.0,
	API_KEY = "7273eb6205c492baa2e88c4ec5858015f7563150442d9198",
	USE_WEBSOCKET = true, -- Prefer WebSocket over long-polling
}

local state = {
	connected = false,
	currentPort = CONFIG.BASE_PORT,
	isPolling = false,
	commandCount = 0,
	lastError = nil,
	websocket = nil,
	useWebSocket = CONFIG.USE_WEBSOCKET,
}

--------------------------------------------------------------------------------
-- Helper Functions
--------------------------------------------------------------------------------

local function isValidMCPServer(response)
	return response and response.service == "roblox-bridge-mcp"
end

local function resolveChild(parent, childName)
	if not parent then
		return nil
	end
	return parent:FindFirstChild(childName)
end

local function createSandboxEnv()
	return {
		game = game,
		workspace = workspace,
		Workspace = workspace,
		script = script,
		Instance = Instance,
		Vector3 = Vector3,
		Color3 = Color3,
		CFrame = CFrame,
		UDim2 = UDim2,
		Enum = Enum,
		print = print,
		warn = warn,
		error = error,
		assert = assert,
		select = select,
		type = type,
		typeof = typeof,
		tonumber = tonumber,
		tostring = tostring,
		pairs = pairs,
		ipairs = ipairs,
		next = next,
		pcall = pcall,
		xpcall = xpcall,
		math = math,
		string = string,
		table = table,
		coroutine = coroutine,
		debug = debug,
		os = { time = os.time, clock = os.clock },
	}
end

local function formatCommandOutput(result)
	if type(result) == "string" then
		return result
	elseif type(result) == "table" then
		return HttpService:JSONEncode(result)
	else
		return tostring(result)
	end
end

local function getObjectPosition(obj)
	if obj:IsA("Model") then
		return obj:GetPivot().Position
	elseif obj:IsA("BasePart") then
		return obj.Position
	elseif obj:IsA("Attachment") then
		return obj.WorldPosition
	end
	return Vector3.new(0, 0, 0)
end

--------------------------------------------------------------------------------
-- Path Resolution
--------------------------------------------------------------------------------

local function requirePath(pathStr)
	if not pathStr or pathStr == "" then
		error("Path cannot be empty")
	end

	local parts = string.split(pathStr, ".")
	local current = game

	for i, part in ipairs(parts) do
		if i == 1 and part == "game" then
			current = game
		elseif current then
			local child = resolveChild(current, part)
			if not child then
				error(string.format("Instance not found: %s (stopped at %s)", pathStr, current:GetFullName()))
			end
			current = child
		else
			error(string.format("Invalid path: %s", pathStr))
		end
	end

	return current
end

local function requireParam(params, key, expectedType)
	local value = params[key]
	if value == nil then
		error(string.format("Missing required parameter: %s", key))
	end
	if expectedType and typeof(value) ~= expectedType then
		error(string.format("Parameter %s must be %s, got %s", key, expectedType, typeof(value)))
	end
	return value
end

--------------------------------------------------------------------------------
-- Command Executor
--------------------------------------------------------------------------------

local METHODS = {}

-- Instance Management
function METHODS:CreateInstance(params)
	local className = requireParam(params, "className", "string")
	local parentPath = params.parentPath or "game.Workspace"
	local name = params.name
	local properties = params.properties or {}

	local parent = requirePath(parentPath)
	local instance = Instance.new(className)
	
	if name then
		instance.Name = name
	end

	for propName, propValue in pairs(properties) do
		pcall(function()
			instance[propName] = propValue
		end)
	end

	instance.Parent = parent
	ChangeHistoryService:SetWaypoint("Create " .. className)
	
	return instance:GetFullName()
end

function METHODS:DeleteInstance(params)
	local path = requireParam(params, "path", "string")
	local obj = requirePath(path)
	local fullName = obj:GetFullName()
	
	obj:Destroy()
	ChangeHistoryService:SetWaypoint("Delete " .. obj.Name)
	
	return string.format("Deleted %s", fullName)
end

function METHODS:GetInstance(params)
	local path = requireParam(params, "path", "string")
	local obj = requirePath(path)
	
	local info = {
		Name = obj.Name,
		ClassName = obj.ClassName,
		FullName = obj:GetFullName(),
		ChildCount = #obj:GetChildren(),
	}
	
	if obj:IsA("BasePart") then
		info.Position = { obj.Position.X, obj.Position.Y, obj.Position.Z }
		info.Size = { obj.Size.X, obj.Size.Y, obj.Size.Z }
		info.Anchored = obj.Anchored
		info.CanCollide = obj.CanCollide
	end
	
	return info
end

function METHODS:SetProperty(params)
	local path = requireParam(params, "path", "string")
	local propertyName = requireParam(params, "property", "string")
	local value = params.value
	
	local obj = requirePath(path)
	local oldValue = obj[propertyName]
	obj[propertyName] = value
	
	ChangeHistoryService:SetWaypoint(string.format("Set %s.%s", obj.Name, propertyName))
	
	return string.format("Set %s = %s (was %s)", propertyName, tostring(value), tostring(oldValue))
end

function METHODS:GetProperty(params)
	local path = requireParam(params, "path", "string")
	local propertyName = requireParam(params, "property", "string")
	
	local obj = requirePath(path)
	return obj[propertyName]
end

function METHODS:ListChildren(params)
	local path = requireParam(params, "path", "string")
	local obj = requirePath(path)
	
	local children = {}
	for _, child in ipairs(obj:GetChildren()) do
		table.insert(children, {
			Name = child.Name,
			ClassName = child.ClassName,
			FullName = child:GetFullName(),
		})
	end
	
	return children
end

-- Selection
function METHODS:GetSelection(params)
	local selection = Selection:Get()
	local result = {}
	
	for _, obj in ipairs(selection) do
		table.insert(result, {
			Name = obj.Name,
			ClassName = obj.ClassName,
			FullName = obj:GetFullName(),
		})
	end
	
	return result
end

function METHODS:SetSelection(params)
	local paths = requireParam(params, "paths", "table")
	local objects = {}
	
	for _, path in ipairs(paths) do
		local obj = requirePath(path)
		table.insert(objects, obj)
	end
	
	Selection:Set(objects)
	return string.format("Selected %d objects", #objects)
end

-- Part Operations
function METHODS:MovePart(params)
	local path = requireParam(params, "path", "string")
	local offset = params.offset or { 0, 0, 0 }
	
	local obj = requirePath(path)
	if not obj:IsA("BasePart") then
		error("Object must be a BasePart")
	end
	
	local offsetVector = Vector3.new(offset[1], offset[2], offset[3])
	obj.Position = obj.Position + offsetVector
	
	ChangeHistoryService:SetWaypoint("Move " .. obj.Name)
	
	return string.format("Moved %s by %s", obj.Name, tostring(offsetVector))
end

function METHODS:RotatePart(params)
	local path = requireParam(params, "path", "string")
	local rotation = params.rotation or { 0, 0, 0 }
	
	local obj = requirePath(path)
	if not obj:IsA("BasePart") then
		error("Object must be a BasePart")
	end
	
	local rotationCFrame = CFrame.Angles(
		math.rad(rotation[1]),
		math.rad(rotation[2]),
		math.rad(rotation[3])
	)
	obj.CFrame = obj.CFrame * rotationCFrame
	
	ChangeHistoryService:SetWaypoint("Rotate " .. obj.Name)
	
	return string.format("Rotated %s", obj.Name)
end

function METHODS:ScalePart(params)
	local path = requireParam(params, "path", "string")
	local scale = requireParam(params, "scale", "table")
	
	local obj = requirePath(path)
	if not obj:IsA("BasePart") then
		error("Object must be a BasePart")
	end
	
	obj.Size = Vector3.new(scale[1], scale[2], scale[3])
	
	ChangeHistoryService:SetWaypoint("Scale " .. obj.Name)
	
	return string.format("Scaled %s to %s", obj.Name, tostring(obj.Size))
end

-- Execute Lua Code
function METHODS:ExecuteLua(params)
	local code = requireParam(params, "code", "string")
	
	local env = createSandboxEnv()
	local func, compileErr = loadstring(code)
	
	if not func then
		error("Compilation error: " .. tostring(compileErr))
	end
	
	setfenv(func, env)
	local results = { pcall(func) }
	local success = table.remove(results, 1)
	
	if not success then
		error("Runtime error: " .. tostring(results[1]))
	end
	
	ChangeHistoryService:SetWaypoint("Execute Lua")
	
	return formatCommandOutput(results[1] or "Success")
end

-- Add more methods as needed...

--------------------------------------------------------------------------------
-- HTTP Communication
--------------------------------------------------------------------------------

local function makeURL(endpoint)
	return string.format("http://localhost:%d%s", state.currentPort, endpoint)
end

local function makeRequest(method, endpoint, body)
	local url = makeURL(endpoint)
	
	local headers = {
		["Content-Type"] = "application/json",
		["Authorization"] = "Bearer " .. CONFIG.API_KEY,
	}
	
	local options = {
		Url = url,
		Method = method,
		Headers = headers,
	}
	
	if body then
		options.Body = HttpService:JSONEncode(body)
	end
	
	return HttpService:RequestAsync(options)
end

local function sendResult(command, success, data, errorMsg)
	local result = {
		id = command.id,
		success = success,
		data = data,
		error = errorMsg,
	}
	
	local ok, response = pcall(function()
		return makeRequest("POST", "/result", result)
	end)
	
	if not ok then
		warn("Failed to send result:", response)
	end
end

local function executeCommand(command)
	local method = METHODS[command.method]
	
	if not method then
		sendResult(command, false, nil, "Unknown method: " .. command.method)
		return
	end
	
	local success, result = pcall(method, METHODS, command.params or {})
	
	if success then
		print(string.format("[MCP] ✓ %s", command.method))
		sendResult(command, true, result, nil)
		state.commandCount = state.commandCount + 1
	else
		warn(string.format("[MCP] ✗ %s: %s", command.method, result))
		sendResult(command, false, nil, tostring(result))
	end
end

local function pollCommands()
	if state.isPolling then
		return
	end
	
	state.isPolling = true
	
	local success, response = pcall(function()
		return makeRequest("GET", "/poll?long=1", nil)
	end)
	
	state.isPolling = false
	
	if not success then
		if state.connected then
			state.connected = false
			state.lastError = response
		end
		-- Silent retry when disconnected
		return
	end
	
	if not state.connected then
		state.connected = true
		state.lastError = nil
		print("[MCP] Connected via HTTP polling at port", state.currentPort)
	end
	
	local commands = HttpService:JSONDecode(response.Body)
	
	if type(commands) == "table" and #commands > 0 then
		for _, command in ipairs(commands) do
			executeCommand(command)
		end
	end
end

--------------------------------------------------------------------------------
-- WebSocket Communication
--------------------------------------------------------------------------------

local function handleWebSocketMessage(message)
	local parseSuccess, data = pcall(function()
		return HttpService:JSONDecode(message)
	end)
	
	if not parseSuccess then
		warn("[MCP] Failed to parse WebSocket message:", data)
		return
	end
	
	-- Handle different message types
	if data.type == "commands" and data.data then
		-- Server sends array of commands
		local commands = data.data
		if type(commands) == "table" and #commands > 0 then
			for _, command in ipairs(commands) do
				executeCommand(command)
			end
		end
	elseif data.type == "command" and data.data then
		-- Single command
		executeCommand(data.data)
	elseif data.type == "ping" then
		-- Respond to ping if needed
		if state.websocket then
			pcall(function()
				state.websocket:Send(HttpService:JSONEncode({ type = "pong" }))
			end)
		end
	end
end

local function handleWebSocketError(errorMessage)
	-- Silent reconnection on error
	state.websocket = nil
	state.connected = false
end

local function handleWebSocketClose()
	print("[MCP] WebSocket closed by server")
	state.websocket = nil
	state.connected = false
end

local function connectWebSocket()
	if state.websocket then
		pcall(function() state.websocket:Close() end)
		state.websocket = nil
	end
	
	local wsUrl = string.format("ws://localhost:%d/ws?key=%s", state.currentPort, CONFIG.API_KEY)
	
	local success, ws = pcall(function()
		return HttpService:CreateWebStreamClient(Enum.WebStreamClientType.WebSocket, {
			Url = wsUrl
		})
	end)
	
	if not success then
		-- Silently fall back to HTTP polling
		state.useWebSocket = false
		return false
	end
	
	state.websocket = ws
	state.connected = true
	print("[MCP] WebSocket connected at port", state.currentPort)
	
	-- Connect event handlers
	ws.MessageReceived:Connect(handleWebSocketMessage)
	ws.Error:Connect(handleWebSocketError)
	ws.Closed:Connect(handleWebSocketClose)
	
	return true
end

local function tryConnectToPort(port)
	local ok, response = pcall(function()
		return makeRequest("GET", "/health", nil)
	end)
	
	if ok and response.StatusCode == 200 then
		local body = HttpService:JSONDecode(response.Body)
		if isValidMCPServer(body) then
			return true
		end
	end
	
	return false
end

local function findMCPServer()
	for offset = 0, CONFIG.PORT_RANGE - 1 do
		local port = CONFIG.BASE_PORT + offset
		state.currentPort = port
		
		if tryConnectToPort(port) then
			print(string.format("[MCP] Found bridge server at port %d", port))
			return true
		end
	end
	
	-- Silently retry connection scan
	return false
end

--------------------------------------------------------------------------------
-- Main Loop
--------------------------------------------------------------------------------

local function mainLoop()
	-- Try to find the MCP server
	if not state.connected then
		if not findMCPServer() then
			wait(CONFIG.RETRY_INTERVAL)
			return
		end
		
		-- Try WebSocket first
		if state.useWebSocket then
			local wsConnected = connectWebSocket()
			if wsConnected then
				-- WebSocket handles messages asynchronously
				wait(1.0) -- Keep alive
				return
			else
				-- Fall back to HTTP polling
				print("[MCP] Falling back to HTTP polling")
				state.useWebSocket = false
			end
		end
	end
	
	-- Use HTTP polling if WebSocket is not available or disconnected
	if not state.useWebSocket or not state.websocket then
		pollCommands()
		wait(0.1)
	else
		-- WebSocket is active, just keep alive
		wait(1.0)
	end
end

--------------------------------------------------------------------------------
-- Startup
--------------------------------------------------------------------------------

print(string.format("[MCP Bridge Plugin v%s] Starting...", VERSION))
print("[MCP] Searching for bridge server...")

-- Main loop
while true do
	local ok, err = pcall(mainLoop)
	if not ok then
		warn("[MCP] Error in main loop:", err)
		wait(CONFIG.RETRY_INTERVAL)
	end
end
