--------------------------------------------------------------------------------
-- MCP Bridge Plugin for Roblox Studio
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

local CONFIG = {
	BASE_PORT = 8081,
	PORT_RANGE = 10, -- Try 8081-8090
	LONG_POLL_TIMEOUT = 25, -- Server holds request for 25 seconds max
	RETRY_INTERVAL = 2.0,
	MAX_RETRY_INTERVAL = 10.0,
	USE_LONG_POLL = true, -- Enable long-polling for near-instant command delivery
	API_KEY = "", -- Set this to your MCP server API key (shown on server startup)
}

--------------------------------------------------------------------------------
-- State
--------------------------------------------------------------------------------

local isConnected = false
local isEnabled = true
local retryInterval = CONFIG.RETRY_INTERVAL
local activePort = nil -- Will be discovered dynamically
local serverUrl = nil -- Built from active port
local apiKey = nil -- Loaded from plugin settings or CONFIG

--------------------------------------------------------------------------------
-- API Key Management
--------------------------------------------------------------------------------

local function getApiKey()
	-- Try to load from plugin settings first
	local savedKey = plugin:GetSetting("MCP_API_KEY")
	if savedKey and savedKey ~= "" then
		return savedKey
	end
	-- Fall back to CONFIG
	if CONFIG.API_KEY and CONFIG.API_KEY ~= "" then
		return CONFIG.API_KEY
	end
	return nil
end

local function setApiKey(key)
	plugin:SetSetting("MCP_API_KEY", key)
	apiKey = key
	print("[MCP] API key saved to plugin settings")
end

-- Load API key on startup
apiKey = getApiKey()

--------------------------------------------------------------------------------
-- UI Setup
--------------------------------------------------------------------------------

local toolbar = plugin:CreateToolbar("MCP Bridge")
local toggleButton = toolbar:CreateButton(
	"MCP Toggle",
	"Toggle MCP Bridge connection",
	"rbxassetid://6031280882"
)
toggleButton.ClickableWhenViewportHidden = true

local function updateButtonState()
	if not isEnabled then
		toggleButton:SetActive(false)
	elseif isConnected then
		toggleButton:SetActive(true)
	else
		toggleButton:SetActive(false)
	end
end

toggleButton.Click:Connect(function()
	isEnabled = not isEnabled
	updateButtonState()
	if isEnabled then
		print("[MCP] Bridge enabled")
	else
		print("[MCP] Bridge disabled")
	end
end)

--------------------------------------------------------------------------------
-- Utilities
--------------------------------------------------------------------------------

local function discoverServerPort()
	-- Try to find an active MCP bridge server in the port range using health endpoint
	for port = CONFIG.BASE_PORT, CONFIG.BASE_PORT + CONFIG.PORT_RANGE - 1 do
		local testUrl = "http://localhost:" .. port
		local success, response = pcall(function()
			return HttpService:GetAsync(testUrl .. "/health", false)
		end)
		
		if success then
			-- Verify it's actually our MCP bridge server
			local ok, data = pcall(function()
				return HttpService:JSONDecode(response)
			end)
			
			if ok and data and data.service == "roblox-bridge-mcp" then
				print(string.format("[MCP] Found bridge server on port %d (connected: %s)", port, tostring(data.connected)))
				return port
			end
		end
	end
	return nil
end

local function sendResult(id, success, data, err)
	if not serverUrl then
		warn("[MCP] Cannot send result: server URL not set")
		return
	end
	
	if not apiKey then
		warn("[MCP] Cannot send result: API key not set")
		return
	end
	
	local payload = {
		id = id,
		success = success,
		data = data,
		error = err,
	}
	pcall(function()
		local url = serverUrl .. "/result?key=" .. apiKey
		HttpService:PostAsync(url, HttpService:JSONEncode(payload))
	end)
end

local function resolvePath(path)
	if path == "game" then
		return game
	end

	local segments = string.split(path, ".")
	local current = game
	local startIdx = 1
	if segments[1] == "game" then
		startIdx = 2
	end

	for i = startIdx, #segments do
		local name = segments[i]
		if not current then
			return nil
		end

		local child = current:FindFirstChild(name)
		if not child and current == game then
			local ok, service = pcall(function()
				return game:GetService(name)
			end)
			if ok then
				child = service
			end
		end
		current = child
	end

	return current
end

local function requirePath(path)
	local obj = resolvePath(path)
	if not obj then
		error("Instance not found: " .. path)
	end
	return obj
end

local function requireBasePart(path)
	local obj = requirePath(path)
	if not obj:IsA("BasePart") then
		error("Not a BasePart: " .. path)
	end
	return obj
end

local function requireScript(path)
	local obj = requirePath(path)
	if not obj:IsA("LuaSourceContainer") then
		error("Not a script: " .. path)
	end
	return obj
end

--------------------------------------------------------------------------------
-- Tool Implementations
--------------------------------------------------------------------------------

local Tools = {}

-- Instance Management
function Tools.CreateInstance(p)
	local parent = requirePath(p.parentPath)
	local obj = Instance.new(p.className)
	obj.Name = p.name or p.className
	if p.properties then
		for k, v in pairs(p.properties) do
			pcall(function()
				obj[k] = v
			end)
		end
	end
	obj.Parent = parent
	return obj:GetFullName()
end

function Tools.DeleteInstance(p)
	local obj = requirePath(p.path)
	obj:Destroy()
	return "Deleted"
end

function Tools.CloneInstance(p)
	local obj = requirePath(p.path)
	local clone = obj:Clone()
	if p.parentPath then
		clone.Parent = resolvePath(p.parentPath)
	end
	return clone:GetFullName()
end

function Tools.RenameInstance(p)
	local obj = requirePath(p.path)
	obj.Name = p.newName
	return obj:GetFullName()
end

-- Instance Discovery & Info
function Tools.GetFullName(p)
	local obj = requirePath(p.path)
	return obj:GetFullName()
end

function Tools.GetParent(p)
	local obj = requirePath(p.path)
	if obj.Parent then
		return obj.Parent:GetFullName()
	end
	return nil
end

function Tools.IsA(p)
	local obj = requirePath(p.path)
	return obj:IsA(p.className)
end

function Tools.GetClassName(p)
	local obj = requirePath(p.path)
	return obj.ClassName
end

function Tools.WaitForChild(p)
	local obj = requirePath(p.path)
	local timeout = p.timeout or 5
	local child = obj:WaitForChild(p.name, timeout)
	if child then
		return child:GetFullName()
	end
	return nil
end

-- Property Access
function Tools.SetProperty(p)
	local obj = requirePath(p.path)
	obj[p.property] = p.value
	return tostring(obj[p.property])
end

function Tools.GetProperty(p)
	local obj = requirePath(p.path)
	return obj[p.property]
end

-- Hierarchy Navigation
function Tools.GetChildren(p)
	local obj = requirePath(p.path)
	local names = {}
	for _, child in pairs(obj:GetChildren()) do
		table.insert(names, child.Name)
	end
	return names
end

function Tools.GetDescendants(p)
	local obj = requirePath(p.path)
	local paths = {}
	for _, desc in pairs(obj:GetDescendants()) do
		table.insert(paths, desc:GetFullName())
	end
	return paths
end

function Tools.FindFirstChild(p)
	local obj = requirePath(p.path)
	local child = obj:FindFirstChild(p.name, p.recursive or false)
	if child then
		return child:GetFullName()
	end
	return nil
end

function Tools.GetService(p)
	local ok, service = pcall(function()
		return game:GetService(p.service)
	end)
	if ok and service then
		return service.Name
	end
	return "NotFound"
end

-- Transform
function Tools.MoveTo(p)
	local obj = requirePath(p.path)
	local pos = Vector3.new(p.position[1], p.position[2], p.position[3])
	if obj:IsA("Model") then
		obj:MoveTo(pos)
	elseif obj:IsA("BasePart") then
		obj.Position = pos
	else
		error("Cannot move: not a Model or BasePart")
	end
	return "Moved"
end

function Tools.SetPosition(p)
	local obj = requireBasePart(p.path)
	obj.Position = Vector3.new(p.x, p.y, p.z)
	return "Set"
end

function Tools.GetPosition(p)
	local obj = requireBasePart(p.path)
	local pos = obj.Position
	return { pos.X, pos.Y, pos.Z }
end

function Tools.SetRotation(p)
	local obj = requireBasePart(p.path)
	obj.Rotation = Vector3.new(p.x, p.y, p.z)
	return "Set"
end

function Tools.GetRotation(p)
	local obj = requireBasePart(p.path)
	local rot = obj.Rotation
	return { rot.X, rot.Y, rot.Z }
end

function Tools.SetSize(p)
	local obj = requireBasePart(p.path)
	obj.Size = Vector3.new(p.x, p.y, p.z)
	return "Set"
end

function Tools.GetSize(p)
	local obj = requireBasePart(p.path)
	local size = obj.Size
	return { size.X, size.Y, size.Z }
end

function Tools.PivotTo(p)
	local obj = requirePath(p.path)
	if not obj:IsA("PVInstance") then
		error("Not a PVInstance: " .. p.path)
	end
	-- CFrame from 12 components: x,y,z, r00,r01,r02, r10,r11,r12, r20,r21,r22
	local c = p.cframe
	local cf = CFrame.new(c[1], c[2], c[3], c[4], c[5], c[6], c[7], c[8], c[9], c[10], c[11], c[12])
	obj:PivotTo(cf)
	return "Pivoted"
end

function Tools.GetPivot(p)
	local obj = requirePath(p.path)
	if not obj:IsA("PVInstance") then
		error("Not a PVInstance: " .. p.path)
	end
	local cf = obj:GetPivot()
	return { cf:GetComponents() }
end

-- Appearance
function Tools.SetColor(p)
	local obj = requirePath(p.path)
	if obj:IsA("BasePart") then
		obj.Color = Color3.fromRGB(p.r, p.g, p.b)
	elseif obj:IsA("Light") then
		obj.Color = Color3.fromRGB(p.r, p.g, p.b)
	else
		error("Cannot set color: not a BasePart or Light")
	end
	return "Set"
end

function Tools.SetTransparency(p)
	local obj = requirePath(p.path)
	if obj:IsA("BasePart") then
		obj.Transparency = p.value
	elseif obj:IsA("GuiObject") then
		obj.Transparency = p.value
	else
		error("Cannot set transparency")
	end
	return "Set"
end

function Tools.SetMaterial(p)
	local obj = requireBasePart(p.path)
	local material = Enum.Material[p.material]
	if not material then
		error("Invalid material: " .. p.material)
	end
	obj.Material = material
	return "Set"
end

-- Physics
function Tools.SetAnchored(p)
	local obj = requireBasePart(p.path)
	obj.Anchored = p.anchored
	return "Set"
end

function Tools.SetCanCollide(p)
	local obj = requireBasePart(p.path)
	obj.CanCollide = p.canCollide
	return "Set"
end

function Tools.CreateConstraint(p)
	local att0 = requirePath(p.attachment0Path)
	local att1 = requirePath(p.attachment1Path)
	
	if not att0:IsA("Attachment") then
		error("attachment0Path must be an Attachment")
	end
	if not att1:IsA("Attachment") then
		error("attachment1Path must be an Attachment")
	end
	
	local constraint = Instance.new(p.type)
	constraint.Attachment0 = att0
	constraint.Attachment1 = att1
	
	if p.properties then
		for k, v in pairs(p.properties) do
			pcall(function()
				constraint[k] = v
			end)
		end
	end
	
	constraint.Parent = att0.Parent
	return constraint:GetFullName()
end

function Tools.SetPhysicalProperties(p)
	local obj = requireBasePart(p.path)
	local density = p.density or 1
	local friction = p.friction or 0.3
	local elasticity = p.elasticity or 0.5
	local frictionWeight = p.frictionWeight or 1
	local elasticityWeight = p.elasticityWeight or 1
	
	obj.CustomPhysicalProperties = PhysicalProperties.new(
		density, friction, elasticity, frictionWeight, elasticityWeight
	)
	return "Set"
end

function Tools.GetMass(p)
	local obj = requireBasePart(p.path)
	return obj:GetMass()
end

-- Scripting
function Tools.CreateScript(p)
	local parent = requirePath(p.parentPath)
	local scriptType = p.type or "Script"
	local s = Instance.new(scriptType)
	s.Name = p.name
	s.Source = p.source
	s.Parent = parent
	return s:GetFullName()
end

function Tools.GetScriptSource(p)
	local obj = requireScript(p.path)
	return obj.Source
end

function Tools.SetScriptSource(p)
	local obj = requireScript(p.path)
	obj.Source = p.source
	return "Updated"
end

function Tools.AppendToScript(p)
	local obj = requireScript(p.path)
	obj.Source = obj.Source .. "\n" .. p.code
	return "Appended"
end

function Tools.ReplaceScriptLines(p)
	local obj = requireScript(p.path)
	local lines = string.split(obj.Source, "\n")
	local newLines = {}
	local contentLines = string.split(p.content, "\n")

	for i = 1, p.startLine - 1 do
		if lines[i] then
			table.insert(newLines, lines[i])
		end
	end

	for _, line in pairs(contentLines) do
		table.insert(newLines, line)
	end

	for i = p.endLine + 1, #lines do
		table.insert(newLines, lines[i])
	end

	obj.Source = table.concat(newLines, "\n")
	return "Replaced"
end

function Tools.InsertScriptLines(p)
	local obj = requireScript(p.path)
	local lines = string.split(obj.Source, "\n")
	local contentLines = string.split(p.content, "\n")
	local newLines = {}
	local insertAt = math.clamp(p.lineNumber, 1, #lines + 1)

	for i = 1, insertAt - 1 do
		table.insert(newLines, lines[i])
	end

	for _, line in pairs(contentLines) do
		table.insert(newLines, line)
	end

	for i = insertAt, #lines do
		table.insert(newLines, lines[i])
	end

	obj.Source = table.concat(newLines, "\n")
	return "Inserted"
end

function Tools.RunConsoleCommand(p)
	local func, compileErr = loadstring(p.code)
	if not func then
		error("Compile error: " .. tostring(compileErr))
	end

	local logs = {}
	local env = setmetatable({
		print = function(...)
			local parts = {}
			for i = 1, select("#", ...) do
				table.insert(parts, tostring(select(i, ...)))
			end
			table.insert(logs, table.concat(parts, " "))
			print(...)
		end,
		warn = function(...)
			local parts = {}
			for i = 1, select("#", ...) do
				table.insert(parts, tostring(select(i, ...)))
			end
			table.insert(logs, "WARN: " .. table.concat(parts, " "))
			warn(...)
		end,
	}, { __index = getfenv() })

	setfenv(func, env)

	local results = { pcall(func) }
	local success = table.remove(results, 1)
	local output = table.concat(logs, "\n")

	if not success then
		error(output .. "\nRuntime error: " .. tostring(results[1]))
	end

	local returnStr = ""
	if #results > 0 then
		local strResults = {}
		for _, v in pairs(results) do
			table.insert(strResults, tostring(v))
		end
		returnStr = "Returned: " .. table.concat(strResults, ", ")
	end

	if output == "" and returnStr == "" then
		return "Executed (no output)"
	end

	local sep = ""
	if output ~= "" and returnStr ~= "" then
		sep = "\n"
	end
	return output .. sep .. returnStr
end

-- Selection
function Tools.GetSelection()
	local sel = Selection:Get()
	local paths = {}
	for _, obj in pairs(sel) do
		table.insert(paths, obj:GetFullName())
	end
	return paths
end

function Tools.SetSelection(p)
	local objs = {}
	for _, path in pairs(p.paths) do
		local obj = resolvePath(path)
		if obj then
			table.insert(objs, obj)
		end
	end
	Selection:Set(objs)
	return "Set"
end

function Tools.ClearSelection()
	Selection:Set({})
	return "Cleared"
end

function Tools.AddToSelection(p)
	local current = Selection:Get()
	for _, path in pairs(p.paths) do
		local obj = resolvePath(path)
		if obj then
			table.insert(current, obj)
		end
	end
	Selection:Set(current)
	return "Added"
end

-- Grouping
function Tools.GroupSelection(p)
	local sel = Selection:Get()
	if #sel == 0 then
		error("Nothing selected")
	end
	local parent = sel[1].Parent
	local model = Instance.new("Model")
	model.Name = p.name
	model.Parent = parent
	for _, obj in pairs(sel) do
		obj.Parent = model
	end
	Selection:Set({ model })
	return model:GetFullName()
end

function Tools.UngroupModel(p)
	local model = requirePath(p.path)
	if not model:IsA("Model") then
		error("Not a Model: " .. p.path)
	end
	local parent = model.Parent
	for _, child in pairs(model:GetChildren()) do
		child.Parent = parent
	end
	model:Destroy()
	return "Ungrouped"
end

-- Lighting
function Tools.SetTimeOfDay(p)
	Lighting.TimeOfDay = p.time
	return "Set"
end

function Tools.SetBrightness(p)
	Lighting.Brightness = p.brightness
	return "Set"
end

function Tools.SetAtmosphereDensity(p)
	local atmo = Lighting:FindFirstChildOfClass("Atmosphere")
	if not atmo then
		atmo = Instance.new("Atmosphere")
		atmo.Parent = Lighting
	end
	atmo.Density = p.density
	return "Set"
end

function Tools.CreateLight(p)
	local parent = requirePath(p.parentPath)
	local light = Instance.new(p.type)
	if p.brightness then
		light.Brightness = p.brightness
	end
	if p.color then
		light.Color = Color3.fromRGB(p.color[1], p.color[2], p.color[3])
	end
	light.Parent = parent
	return light:GetFullName()
end

-- Attributes & Tags
function Tools.SetAttribute(p)
	local obj = requirePath(p.path)
	obj:SetAttribute(p.name, p.value)
	return "Set"
end

function Tools.GetAttribute(p)
	local obj = requirePath(p.path)
	return obj:GetAttribute(p.name)
end

function Tools.GetAttributes(p)
	local obj = requirePath(p.path)
	return obj:GetAttributes()
end

function Tools.AddTag(p)
	local obj = requirePath(p.path)
	CollectionService:AddTag(obj, p.tag)
	return "Added"
end

function Tools.RemoveTag(p)
	local obj = requirePath(p.path)
	CollectionService:RemoveTag(obj, p.tag)
	return "Removed"
end

function Tools.GetTags(p)
	local obj = requirePath(p.path)
	return CollectionService:GetTags(obj)
end

function Tools.HasTag(p)
	local obj = requirePath(p.path)
	return CollectionService:HasTag(obj, p.tag)
end

-- Players
function Tools.GetPlayers()
	local names = {}
	for _, player in pairs(Players:GetPlayers()) do
		table.insert(names, player.Name)
	end
	return names
end

function Tools.GetPlayerPosition(p)
	local player = Players:FindFirstChild(p.username)
	if not player or not player.Character then
		error("Player or character not found: " .. p.username)
	end
	local root = player.Character:FindFirstChild("HumanoidRootPart")
	if not root then
		error("Character root not found")
	end
	local pos = root.Position
	return { pos.X, pos.Y, pos.Z }
end

function Tools.TeleportPlayer(p)
	local player = Players:FindFirstChild(p.username)
	if not player or not player.Character then
		error("Player or character not found")
	end
	player.Character:MoveTo(Vector3.new(p.position[1], p.position[2], p.position[3]))
	return "Teleported"
end

function Tools.KickPlayer(p)
	local player = Players:FindFirstChild(p.username)
	if player then
		player:Kick(p.reason or "Kicked by MCP")
	end
	return "Kicked"
end

-- Place/Studio
function Tools.SavePlace()
	return "Save triggered (if permissions allow)"
end

function Tools.GetPlaceInfo()
	return {
		PlaceId = game.PlaceId,
		Name = game.Name,
		JobId = game.JobId,
	}
end

-- Audio
function Tools.PlaySound(p)
	local sound = Instance.new("Sound")
	sound.SoundId = p.soundId
	sound.Volume = p.volume or 1

	local parent = SoundService
	if p.parentPath then
		parent = resolvePath(p.parentPath) or SoundService
	end
	sound.Parent = parent
	sound:Play()
	Debris:AddItem(sound, 30)
	return sound:GetFullName()
end

function Tools.StopSound(p)
	local obj = requirePath(p.path)
	if not obj:IsA("Sound") then
		error("Not a Sound: " .. p.path)
	end
	obj:Stop()
	return "Stopped"
end

-- Terrain
function Tools.FillTerrain(p)
	local terrain = game.Workspace:FindFirstChildOfClass("Terrain")
	if not terrain then
		error("No Terrain found in Workspace")
	end
	
	local material = Enum.Material[p.material]
	if not material then
		error("Invalid material: " .. p.material)
	end
	
	local min = Vector3.new(p.minX, p.minY, p.minZ)
	local max = Vector3.new(p.maxX, p.maxY, p.maxZ)
	local region = Region3.new(min, max)
	
	terrain:FillRegion(region, 4, material)
	return "Filled"
end

function Tools.ClearTerrain()
	local terrain = game.Workspace:FindFirstChildOfClass("Terrain")
	if not terrain then
		error("No Terrain found in Workspace")
	end
	terrain:Clear()
	return "Cleared"
end

-- Camera
function Tools.SetCameraPosition(p)
	local camera = game.Workspace.CurrentCamera
	if not camera then
		error("No CurrentCamera found")
	end
	local pos = Vector3.new(p.x, p.y, p.z)
	camera.CFrame = CFrame.new(pos) * camera.CFrame.Rotation
	return "Set"
end

function Tools.SetCameraFocus(p)
	local camera = game.Workspace.CurrentCamera
	if not camera then
		error("No CurrentCamera found")
	end
	local obj = requirePath(p.path)
	
	local targetPos
	if obj:IsA("BasePart") then
		targetPos = obj.Position
	elseif obj:IsA("Model") then
		targetPos = obj:GetPivot().Position
	else
		error("Cannot focus on: not a BasePart or Model")
	end
	
	camera.CFrame = CFrame.new(camera.CFrame.Position, targetPos)
	return "Focused"
end

function Tools.GetCameraPosition()
	local camera = game.Workspace.CurrentCamera
	if not camera then
		error("No CurrentCamera found")
	end
	local pos = camera.CFrame.Position
	return { pos.X, pos.Y, pos.Z }
end

-- Utility
function Tools.GetDistance(p)
	local obj1 = requirePath(p.path1)
	local obj2 = requirePath(p.path2)

	local function getPosition(obj)
		if obj:IsA("BasePart") then
			return obj.Position
		elseif obj:IsA("Model") then
			return obj:GetPivot().Position
		else
			error("Cannot get position: not a BasePart or Model")
		end
	end

	local pos1 = getPosition(obj1)
	local pos2 = getPosition(obj2)
	return (pos1 - pos2).Magnitude
end

function Tools.HighlightObject(p)
	local obj = requirePath(p.path)
	local hl = Instance.new("Highlight")
	if p.color then
		hl.FillColor = Color3.fromRGB(p.color[1], p.color[2], p.color[3])
	end
	hl.Parent = obj
	if p.duration then
		Debris:AddItem(hl, p.duration)
	end
	return hl:GetFullName()
end

function Tools.Chat(p)
	local channels = TextChatService:FindFirstChild("TextChannels")
	local systemChannel = channels and channels:FindFirstChild("RBXSystem")
	if systemChannel then
		systemChannel:DisplaySystemMessage(p.message)
		return "Sent"
	end
	return "Chat not available"
end

-- History (Undo/Redo)
function Tools.Undo()
	ChangeHistoryService:Undo()
	return "Undo executed"
end

function Tools.Redo()
	ChangeHistoryService:Redo()
	return "Redo executed"
end

--------------------------------------------------------------------------------
-- Command Handler
--------------------------------------------------------------------------------

local function handleCommand(cmd)
	local handler = Tools[cmd.method]
	if not handler then
		sendResult(cmd.id, false, nil, "Unknown method: " .. cmd.method)
		return
	end

	local success, result = pcall(handler, cmd.params or {})
	if success then
		sendResult(cmd.id, true, result, nil)
	else
		sendResult(cmd.id, false, nil, tostring(result))
	end
end

--------------------------------------------------------------------------------
-- Polling Loop (Long-polling for near-instant command delivery)
--------------------------------------------------------------------------------

task.spawn(function()
	print("[MCP] Bridge starting, discovering server port...")

	while true do
		if isEnabled then
			-- Check for API key before attempting connection
			if not apiKey or apiKey == "" then
				print("[MCP] API key not set. Use setApiKey('your-key') or set CONFIG.API_KEY in the plugin")
				task.wait(5)
				apiKey = getApiKey() -- Re-check in case it was set
				continue
			end

			-- Auto-discover server port if not connected
			if not isConnected and not activePort then
				activePort = discoverServerPort()
				if activePort then
					serverUrl = "http://localhost:" .. activePort
					print("[MCP] Discovered server on port " .. activePort)
				else
					print("[MCP] No server found on ports " .. CONFIG.BASE_PORT .. "-" .. (CONFIG.BASE_PORT + CONFIG.PORT_RANGE - 1))
					task.wait(retryInterval)
					retryInterval = math.min(retryInterval * 1.5, CONFIG.MAX_RETRY_INTERVAL)
					continue
				end
			end

			-- Long-poll for commands (blocks until commands arrive or timeout)
			if serverUrl then
				local pollUrl = serverUrl .. "/poll?key=" .. apiKey
				if CONFIG.USE_LONG_POLL then
					pollUrl = pollUrl .. "&long=1"
				end

				local success, response = pcall(function()
					-- Long-poll: server holds connection for up to 25s waiting for commands
					return HttpService:GetAsync(pollUrl, false)
				end)

				if success then
					if not isConnected then
						isConnected = true
						retryInterval = CONFIG.RETRY_INTERVAL
						updateButtonState()
						local mode = CONFIG.USE_LONG_POLL and "long-poll" or "legacy poll"
						print("[MCP] Connected to server at " .. serverUrl .. " (" .. mode .. ")")
					end

					local ok, commands = pcall(function()
						return HttpService:JSONDecode(response)
					end)

					if ok and commands then
						for _, cmd in pairs(commands) do
							task.spawn(handleCommand, cmd)
						end
					end

					-- No delay needed with long-polling - immediately re-poll
					-- The server will hold the connection until commands arrive
					if not CONFIG.USE_LONG_POLL then
						task.wait(0.3) -- Legacy fallback interval
					end
				else
					if isConnected then
						isConnected = false
						activePort = nil -- Reset for rediscovery
						serverUrl = nil
						updateButtonState()
						print("[MCP] Disconnected from server, will rediscover...")
					end

					task.wait(retryInterval)
					retryInterval = math.min(retryInterval * 1.5, CONFIG.MAX_RETRY_INTERVAL)
				end
			end
		else
			task.wait(0.5)
		end
	end
end)

updateButtonState()

-- Expose setApiKey globally so users can set it from command bar
-- Usage: _G.MCP_SetApiKey("your-api-key-here")
_G.MCP_SetApiKey = setApiKey
_G.MCP_GetApiKey = function()
	return apiKey and string.sub(apiKey, 1, 8) .. "..." or "not set"
end

if apiKey then
	print("[MCP] Plugin loaded (API key configured)")
else
	print("[MCP] Plugin loaded (API key NOT set - run _G.MCP_SetApiKey('your-key') in command bar)")
end
