--------------------------------------------------------------------------------
-- MCP Bridge Plugin for Roblox Studio
-- Connects Studio to MCP server via HTTP polling/WebSocket
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
local TweenService = game:GetService("TweenService")
local Teams = game:GetService("Teams")
local DataStoreService = game:GetService("DataStoreService")
local MarketplaceService = game:GetService("MarketplaceService")

--------------------------------------------------------------------------------
-- Configuration
--------------------------------------------------------------------------------

local VERSION = "1.0.0"

local CONFIG = {
	BASE_PORT = 62847,
	PORT_RANGE = 10,
	RETRY_INTERVAL = 2.0,
	RECONNECT_INTERVAL = 5.0,
	API_KEY = "7273eb6205c492baa2e88c4ec5858015f7563150442d9198",
	USE_WEBSOCKET = true,
}

local state = {
	connected = false,
	currentPort = CONFIG.BASE_PORT,
	isPolling = false,
	commandCount = 0,
	lastError = nil,
	websocket = nil,
	useWebSocket = CONFIG.USE_WEBSOCKET,
	-- Animation tracking
	animationTracks = {},
	-- Tween tracking
	activeTweens = {},
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

local function createRaycastParams(params)
	if not params then
		return nil
	end
	
	local raycastParams = RaycastParams.new()
	if params.filterDescendantsInstances then
		local filterInstances = {}
		for _, path in ipairs(params.filterDescendantsInstances) do
			table.insert(filterInstances, requirePath(path))
		end
		raycastParams.FilterDescendantsInstances = filterInstances
	end
	if params.filterType then
		raycastParams.FilterType = params.filterType
	end
	if params.ignoreWater then
		raycastParams.IgnoreWater = params.ignoreWater
	end
	if params.respectCanCollide then
		raycastParams.RespectCanCollide = params.respectCanCollide
	end
	
	return raycastParams
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

function METHODS:CloneInstance(params)
	local path = requireParam(params, "path", "string")
	local parentPath = params.parentPath or "game.Workspace"
	
	local obj = requirePath(path)
	local clone = obj:Clone()
	clone.Parent = requirePath(parentPath)
	ChangeHistoryService:SetWaypoint("Clone " .. obj.Name)
	
	return clone:GetFullName()
end

function METHODS:RenameInstance(params)
	local path = requireParam(params, "path", "string")
	local newName = requireParam(params, "newName", "string")
	
	local obj = requirePath(path)
	local oldName = obj.Name
	obj.Name = newName
	ChangeHistoryService:SetWaypoint("Rename " .. oldName .. " to " .. newName)
	
	return string.format("Renamed %s to %s", oldName, newName)
end

-- Instance Discovery & Info
function METHODS:GetFullName(params)
	local path = requireParam(params, "path", "string")
	local obj = requirePath(path)
	return obj:GetFullName()
end

function METHODS:GetParent(params)
	local path = requireParam(params, "path", "string")
	local obj = requirePath(path)
	return obj.Parent and obj.Parent:GetFullName() or nil
end

function METHODS:IsA(params)
	local path = requireParam(params, "path", "string")
	local className = requireParam(params, "className", "string")
	local obj = requirePath(path)
	return obj:IsA(className)
end

function METHODS:GetClassName(params)
	local path = requireParam(params, "path", "string")
	local obj = requirePath(path)
	return obj.ClassName
end

function METHODS:WaitForChild(params)
	local path = requireParam(params, "path", "string")
	local name = requireParam(params, "name", "string")
	local timeout = params.timeout
	
	local obj = requirePath(path)
	if timeout then
		obj = obj:WaitForChild(name, timeout)
	else
		obj = obj:WaitForChild(name)
	end
	
	return obj:GetFullName()
end

-- Properties
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

-- Hierarchy
function METHODS:GetChildren(params)
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

function METHODS:GetDescendants(params)
	local path = requireParam(params, "path", "string")
	local obj = requirePath(path)
	
	local descendants = {}
	for _, descendant in ipairs(obj:GetDescendants()) do
		table.insert(descendants, {
			Name = descendant.Name,
			ClassName = descendant.ClassName,
			FullName = descendant:GetFullName(),
		})
	end
	
	return descendants
end

function METHODS:FindFirstChild(params)
	local path = requireParam(params, "path", "string")
	local name = requireParam(params, "name", "string")
	local recursive = params.recursive
	
	local obj = requirePath(path)
	local child
	
	if recursive then
		for _, descendant in ipairs(obj:GetDescendants()) do
			if descendant.Name == name then
				child = descendant
				break
			end
		end
	else
		child = obj:FindFirstChild(name)
	end
	
	if child then
		return {
			Name = child.Name,
			ClassName = child.ClassName,
			FullName = child:GetFullName(),
		}
	end
	
	return nil
end

function METHODS:GetService(params)
	local serviceName = requireParam(params, "service", "string")
	return game:GetService(serviceName)
end

-- Transforms
function METHODS:MoveTo(params)
	local path = requireParam(params, "path", "string")
	local position = requireParam(params, "position", "table")
	
	local obj = requirePath(path)
	if obj:IsA("Model") then
		obj:MoveTo(Vector3.new(position[1], position[2], position[3]))
	elseif obj:IsA("BasePart") then
		obj.Position = Vector3.new(position[1], position[2], position[3])
	else
		error("Object must be a Model or BasePart")
	end
	
	ChangeHistoryService:SetWaypoint("Move " .. obj.Name)
	
	return string.format("Moved %s", obj.Name)
end

function METHODS:SetPosition(params)
	local path = requireParam(params, "path", "string")
	local x = requireParam(params, "x", "number")
	local y = requireParam(params, "y", "number")
	local z = requireParam(params, "z", "number")
	
	local obj = requirePath(path)
	if not obj:IsA("BasePart") then
		error("Object must be a BasePart")
	end
	
	obj.Position = Vector3.new(x, y, z)
	ChangeHistoryService:SetWaypoint("Set Position " .. obj.Name)
	
	return { obj.Position.X, obj.Position.Y, obj.Position.Z }
end

function METHODS:GetPosition(params)
	local path = requireParam(params, "path", "string")
	local obj = requirePath(path)
	local pos = getObjectPosition(obj)
	return { pos.X, pos.Y, pos.Z }
end

function METHODS:SetRotation(params)
	local path = requireParam(params, "path", "string")
	local x = requireParam(params, "x", "number")
	local y = requireParam(params, "y", "number")
	local z = requireParam(params, "z", "number")
	
	local obj = requirePath(path)
	if not obj:IsA("BasePart") then
		error("Object must be a BasePart")
	end
	
	obj.CFrame = CFrame.Angles(math.rad(x), math.rad(y), math.rad(z)) * obj.CFrame.Position
	ChangeHistoryService:SetWaypoint("Set Rotation " .. obj.Name)
	
	return { x, y, z }
end

function METHODS:GetRotation(params)
	local path = requireParam(params, "path", "string")
	local obj = requirePath(path)
	
	if not obj:IsA("BasePart") then
		error("Object must be a BasePart")
	end
	
	local _, _, _, rx, ry, rz = obj.CFrame:GetComponents()
	return { math.deg(rx), math.deg(ry), math.deg(rz) }
end

function METHODS:SetSize(params)
	local path = requireParam(params, "path", "string")
	local x = requireParam(params, "x", "number")
	local y = requireParam(params, "y", "number")
	local z = requireParam(params, "z", "number")
	
	local obj = requirePath(path)
	if not obj:IsA("BasePart") then
		error("Object must be a BasePart")
	end
	
	obj.Size = Vector3.new(x, y, z)
	ChangeHistoryService:SetWaypoint("Set Size " .. obj.Name)
	
	return { obj.Size.X, obj.Size.Y, obj.Size.Z }
end

function METHODS:GetSize(params)
	local path = requireParam(params, "path", "string")
	local obj = requirePath(path)
	
	if not obj:IsA("BasePart") then
		error("Object must be a BasePart")
	end
	
	return { obj.Size.X, obj.Size.Y, obj.Size.Z }
end

function METHODS:PivotTo(params)
	local path = requireParam(params, "path", "string")
	local cframe = requireParam(params, "cframe", "table")
	
	local obj = requirePath(path)
	if not obj:IsA("Model") and not obj:IsA("BasePart") then
		error("Object must be a Model or BasePart")
	end
	
	local cf = CFrame.new(unpack(cframe))
	obj:PivotTo(cf)
	ChangeHistoryService:SetWaypoint("PivotTo " .. obj.Name)
	
	return { obj:GetPivotOffset().Position.X, obj:GetPivotOffset().Position.Y, obj:GetPivotOffset().Position.Z }
end

function METHODS:GetPivot(params)
	local path = requireParam(params, "path", "string")
	local obj = requirePath(path)
	
	if not obj:IsA("Model") and not obj:IsA("BasePart") then
		error("Object must be a Model or BasePart")
	end
	
	local cf = obj:GetPivot()
	local components = { cf:GetComponents() }
	return components
end

-- Appearance
function METHODS:SetColor(params)
	local path = requireParam(params, "path", "string")
	local color = requireParam(params, "color", "table")
	
	local obj = requirePath(path)
	local color3 = Color3.new(color[1]/255, color[2]/255, color[3]/255)
	
	if obj:IsA("BasePart") then
		obj.Color = color3
	elseif obj:IsA("GuiObject") then
		obj.BackgroundColor3 = color3
	elseif obj:IsA("GuiBase2d") then
		obj.BackgroundColor3 = color3
	elseif obj:IsA("TextLabel") or obj:IsA("TextBox") or obj:IsA("TextButton") then
		obj.TextColor3 = color3
	else
		error("Object does not support color property")
	end
	
	ChangeHistoryService:SetWaypoint("Set Color " .. obj.Name)
	
	return string.format("Set color to RGB(%d, %d, %d)", color[1], color[2], color[3])
end

function METHODS:SetTransparency(params)
	local path = requireParam(params, "path", "string")
	local transparency = requireParam(params, "transparency", "number")
	
	local obj = requirePath(path)
	
	if obj:IsA("BasePart") then
		obj.Transparency = math.clamp(transparency, 0, 1)
	elseif obj:IsA("GuiObject") then
		obj.BackgroundTransparency = math.clamp(transparency, 0, 1)
	elseif obj:IsA("GuiBase2d") then
		obj.BackgroundTransparency = math.clamp(transparency, 0, 1)
	else
		error("Object does not support transparency property")
	end
	
	ChangeHistoryService:SetWaypoint("Set Transparency " .. obj.Name)
	
	return string.format("Set transparency to %.2f", transparency)
end

function METHODS:SetMaterial(params)
	local path = requireParam(params, "path", "string")
	local material = requireParam(params, "material", "string")
	
	local obj = requirePath(path)
	if not obj:IsA("BasePart") then
		error("Object must be a BasePart")
	end
	
	obj.Material = Enum.Material[material] or Enum.Material.Plastic
	ChangeHistoryService:SetWaypoint("Set Material " .. obj.Name)
	
	return material
end

-- Physics
function METHODS:SetAnchored(params)
	local path = requireParam(params, "path", "string")
	local anchored = requireParam(params, "anchored", "boolean")
	
	local obj = requirePath(path)
	if not obj:IsA("BasePart") then
		error("Object must be a BasePart")
	end
	
	obj.Anchored = anchored
	ChangeHistoryService:SetWaypoint(string.format("%s Anchored", tostring(anchored)))
	
	return string.format("Set Anchored to %s", tostring(anchored))
end

function METHODS:SetCanCollide(params)
	local path = requireParam(params, "path", "string")
	local canCollide = requireParam(params, "canCollide", "boolean")
	
	local obj = requirePath(path)
	if not obj:IsA("BasePart") then
		error("Object must be a BasePart")
	end
	
	obj.CanCollide = canCollide
	ChangeHistoryService:SetWaypoint(string.format("%s CanCollide", tostring(canCollide)))
	
	return string.format("Set CanCollide to %s", tostring(canCollide))
end

function METHODS:CreateConstraint(params)
	local constraintType = requireParam(params, "type", "string")
	local attachment0Path = requireParam(params, "attachment0Path", "string")
	local attachment1Path = requireParam(params, "attachment1Path", "string")
	local properties = params.properties or {}
	
	local attachment0 = requirePath(attachment0Path)
	local attachment1 = requirePath(attachment1Path)
	
	local constraintName = "Constraint"
	if constraintType == "Weld" then
		constraintName = "WeldConstraint"
	elseif constraintType == "Motor6D" then
		constraintName = "Motor6D"
	elseif constraintType == "AlignPosition" then
		constraintName = "AlignPosition"
	elseif constraintType == "AlignOrientation" then
		constraintName = "AlignOrientation"
	elseif constraintType == "Spring" then
		constraintName = "SpringConstraint"
	elseif constraintType == "BallSocket" then
		constraintName = "BallSocketConstraint"
	else
		error("Unknown constraint type: " .. constraintType)
	end
	
	local constraint = Instance.new(constraintName)
	constraint.Attachment0 = attachment0
	constraint.Attachment1 = attachment1
	
	for propName, propValue in pairs(properties) do
		pcall(function()
			constraint[propName] = propValue
		end)
	end
	
	constraint.Parent = workspace
	ChangeHistoryService:SetWaypoint("Create " .. constraintName)
	
	return constraint:GetFullName()
end

function METHODS:SetPhysicalProperties(params)
	local path = requireParam(params, "path", "string")
	local density = params.density
	local friction = params.friction
	local elasticity = params.elasticity
	
	local obj = requirePath(path)
	if not obj:IsA("BasePart") then
		error("Object must be a BasePart")
	end
	
	local customPhysicalProps = CustomPhysicalProperties.new()
	if density then customPhysicalProps.Density = density end
	if friction then customPhysicalProps.Friction = friction end
	if elasticity then customPhysicalProps.Elasticity = elasticity end
	
	obj.CustomPhysicalProperties = customPhysicalProps
	ChangeHistoryService:SetWaypoint("Set Physical Properties " .. obj.Name)
	
	return { density = density, friction = friction, elasticity = elasticity }
end

function METHODS:GetMass(params)
	local path = requireParam(params, "path", "string")
	local obj = requirePath(path)
	if not obj:IsA("BasePart") then
		error("Object must be a BasePart")
	end
	
	return obj:GetMass()
end

-- Scripting
function METHODS:CreateScript(params)
	local name = requireParam(params, "name", "string")
	local parentPath = params.parentPath or "game.Workspace"
	local source = params.source or ""
	local scriptType = params.type or "Script"
	
	local parent = requirePath(parentPath)
	local scriptInstance
	
	if scriptType == "Script" then
		scriptInstance = Instance.new("Script")
	elseif scriptType == "LocalScript" then
		scriptInstance = Instance.new("LocalScript")
	elseif scriptType == "ModuleScript" then
		scriptInstance = Instance.new("ModuleScript")
	else
		error("Invalid script type. Use: Script, LocalScript, or ModuleScript")
	end
	
	scriptInstance.Name = name
	scriptInstance.Source = source
	scriptInstance.Parent = parent
	ChangeHistoryService:SetWaypoint("Create " .. scriptType)
	
	return scriptInstance:GetFullName()
end

function METHODS:GetScriptSource(params)
	local path = requireParam(params, "path", "string")
	local obj = requirePath(path)
	
	if not (obj:IsA("Script") or obj:IsA("LocalScript") or obj:IsA("ModuleScript")) then
		error("Object must be a Script, LocalScript, or ModuleScript")
	end
	
	return obj.Source
end

function METHODS:SetScriptSource(params)
	local path = requireParam(params, "path", "string")
	local source = requireParam(params, "source", "string")
	
	local obj = requirePath(path)
	if not (obj:IsA("Script") or obj:IsA("LocalScript") or obj:IsA("ModuleScript")) then
		error("Object must be a Script, LocalScript, or ModuleScript")
	end
	
	obj.Source = source
	ChangeHistoryService:SetWaypoint("Set Script Source " .. obj.Name)
	
	return string.format("Set source for %s", obj.Name)
end

function METHODS:AppendToScript(params)
	local path = requireParam(params, "path", "string")
	local code = requireParam(params, "code", "string")
	
	local obj = requirePath(path)
	if not (obj:IsA("Script") or obj:IsA("LocalScript") or obj:IsA("ModuleScript")) then
		error("Object must be a Script, LocalScript, or ModuleScript")
	end
	
	obj.Source = obj.Source .. code
	ChangeHistoryService:SetWaypoint("Append to Script " .. obj.Name)
	
	return string.format("Appended %d characters to %s", #code, obj.Name)
end

function METHODS:ReplaceScriptLines(params)
	local path = requireParam(params, "path", "string")
	local startLine = requireParam(params, "startLine", "number")
	local endLine = requireParam(params, "endLine", "number")
	local content = requireParam(params, "content", "string")
	
	local obj = requirePath(path)
	if not (obj:IsA("Script") or obj:IsA("LocalScript") or obj:IsA("ModuleScript")) then
		error("Object must be a Script, LocalScript, or ModuleScript")
	end
	
	local lines = string.split(obj.Source, "\n")
	for i = startLine, endLine do
		lines[i] = ""
	end
	obj.Source = table.concat(lines, "\n")
	ChangeHistoryService:SetWaypoint("Replace Script Lines " .. obj.Name)
	
	return string.format("Replaced lines %d-%d in %s", startLine, endLine, obj.Name)
end

function METHODS:InsertScriptLines(params)
	local path = requireParam(params, "path", "string")
	local lineNumber = requireParam(params, "lineNumber", "number")
	local content = requireParam(params, "content", "string")
	
	local obj = requirePath(path)
	if not (obj:IsA("Script") or obj:IsA("LocalScript") or obj:IsA("ModuleScript")) then
		error("Object must be a Script, LocalScript, or ModuleScript")
	end
	
	local lines = string.split(obj.Source, "\n")
	table.insert(lines, lineNumber, content)
	obj.Source = table.concat(lines, "\n")
	ChangeHistoryService:SetWaypoint("Insert Script Lines " .. obj.Name)
	
	return string.format("Inserted lines at position %d in %s", lineNumber, obj.Name)
end

function METHODS:RunConsoleCommand(params)
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
	
	ChangeHistoryService:SetWaypoint("Execute Console Command")
	
	return formatCommandOutput(results[1] or "Success")
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

function METHODS:ClearSelection(params)
	Selection:Set({})
	return "Cleared selection"
end

function METHODS:AddToSelection(params)
	local paths = requireParam(params, "paths", "table")
	local currentSelection = Selection:Get()
	local newSelection = {}
	
	-- Copy current selection
	for _, obj in ipairs(currentSelection) do
		table.insert(newSelection, obj)
	end
	
	-- Add new objects
	for _, path in ipairs(paths) do
		local obj = requirePath(path)
		table.insert(newSelection, obj)
	end
	
	Selection:Set(newSelection)
	return string.format("Added %d objects to selection", #paths)
end

function METHODS:GroupSelection(params)
	local name = params.name or "Model"
	local selection = Selection:Get()
	
	if #selection == 0 then
		error("No objects selected")
	end
	
	local model = Instance.new("Model")
	model.Name = name
	
	for _, obj in ipairs(selection) do
		obj.Parent = model
	end
	
	model.Parent = workspace
	Selection:Set({ model })
	ChangeHistoryService:SetWaypoint("Group Selection")
	
	return model:GetFullName()
end

function METHODS:UngroupModel(params)
	local path = requireParam(params, "path", "string")
	local model = requirePath(path)
	
	if not model:IsA("Model") then
		error("Object must be a Model")
	end
	
	local children = model:GetChildren()
	for _, child in ipairs(children) do
		child.Parent = model.Parent
	end
	
	model:Destroy()
	ChangeHistoryService:SetWaypoint("Ungroup Model")
	
	return string.format("Ungrouped model, moved %d children", #children)
end

-- Lighting
function METHODS:SetTimeOfDay(params)
	local time = requireParam(params, "time", "string")
	Lighting.ClockTime = time
	ChangeHistoryService:SetWaypoint("Set Time of Day")
	return time
end

function METHODS:SetBrightness(params)
	local brightness = requireParam(params, "brightness", "number")
	Lighting.Brightness = math.clamp(brightness, 0, 3)
	ChangeHistoryService:SetWaypoint("Set Brightness")
	return Lighting.Brightness
end

function METHODS:SetAtmosphereDensity(params)
	local density = requireParam(params, "density", "number")
	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
	
	if not atmosphere then
		atmosphere = Instance.new("Atmosphere")
		atmosphere.Parent = Lighting
	end
	
	atmosphere.Density = math.clamp(density, 0, 1)
	ChangeHistoryService:SetWaypoint("Set Atmosphere Density")
	return atmosphere.Density
end

function METHODS:CreateLight(params)
	local parentPath = params.parentPath or "game.Workspace"
	local lightType = requireParam(params, "type", "string")
	local properties = params.properties or {}
	
	local parent = requirePath(parentPath)
	local light
	
	if lightType == "PointLight" then
		light = Instance.new("PointLight")
	elseif lightType == "SpotLight" then
		light = Instance.new("SpotLight")
	elseif lightType == "SurfaceLight" then
		light = Instance.new("SurfaceLight")
	elseif lightType == "DirectionalLight" then
		light = Instance.new("DirectionalLight")
	else
		error("Unknown light type. Use: PointLight, SpotLight, SurfaceLight, or DirectionalLight")
	end
	
	for propName, propValue in pairs(properties) do
		pcall(function()
			light[propName] = propValue
		end)
	end
	
	light.Parent = parent
	ChangeHistoryService:SetWaypoint("Create " .. lightType)
	
	return light:GetFullName()
end

-- Attributes & Tags
function METHODS:SetAttribute(params)
	local path = requireParam(params, "path", "string")
	local name = requireParam(params, "name", "string")
	local value = params.value
	
	local obj = requirePath(path)
	obj:SetAttribute(name, value)
	ChangeHistoryService:SetWaypoint("Set Attribute " .. name)
	
	return string.format("Set attribute %s = %s", name, tostring(value))
end

function METHODS:GetAttribute(params)
	local path = requireParam(params, "path", "string")
	local name = requireParam(params, "name", "string")
	
	local obj = requirePath(path)
	return obj:GetAttribute(name)
end

function METHODS:GetAttributes(params)
	local path = requireParam(params, "path", "string")
	local obj = requirePath(path)
	return obj:GetAttributes()
end

function METHODS:AddTag(params)
	local path = requireParam(params, "path", "string")
	local tag = requireParam(params, "tag", "string")
	
	local obj = requirePath(path)
	CollectionService:AddTag(obj, tag)
	ChangeHistoryService:SetWaypoint("Add Tag " .. tag)
	
	return string.format("Added tag %s to %s", tag, obj.Name)
end

function METHODS:RemoveTag(params)
	local path = requireParam(params, "path", "string")
	local tag = requireParam(params, "tag", "string")
	
	local obj = requirePath(path)
	CollectionService:RemoveTag(obj, tag)
	ChangeHistoryService:SetWaypoint("Remove Tag " .. tag)
	
	return string.format("Removed tag %s from %s", tag, obj.Name)
end

function METHODS:GetTags(params)
	local path = requireParam(params, "path", "string")
	local obj = requirePath(path)
	return CollectionService:GetTags(obj)
end

function METHODS:HasTag(params)
	local path = requireParam(params, "path", "string")
	local tag = requireParam(params, "tag", "string")
	
	local obj = requirePath(path)
	return CollectionService:HasTag(obj, tag)
end

-- Players
function METHODS:GetPlayers(params)
	local players = Players:GetPlayers()
	local result = {}
	
	for _, player in ipairs(players) do
		table.insert(result, {
			Name = player.Name,
			UserId = player.UserId,
			DisplayName = player.DisplayName,
		})
	end
	
	return result
end

function METHODS:GetPlayerPosition(params)
	local playerName = requireParam(params, "playerName", "string")
	local player = Players:FindFirstChild(playerName)
	
	if not player then
		error("Player not found: " .. playerName)
	end
	
	if not player.Character then
		error("Player character not loaded")
	end
	
	local pos = player.Character:GetPivot().Position
	return { pos.X, pos.Y, pos.Z }
end

function METHODS:TeleportPlayer(params)
	local playerName = requireParam(params, "playerName", "string")
	local position = requireParam(params, "position", "table")
	
	local player = Players:FindFirstChild(playerName)
	if not player then
		error("Player not found: " .. playerName)
	end
	
	if not player.Character then
		error("Player character not loaded")
	end
	
	local pos = Vector3.new(position[1], position[2], position[3])
	player.Character:PivotTo(CFrame.new(pos))
	ChangeHistoryService:SetWaypoint("Teleport Player " .. playerName)
	
	return string.format("Teleported %s to (%.2f, %.2f, %.2f)", playerName, pos.X, pos.Y, pos.Z)
end

function METHODS:KickPlayer(params)
	local playerName = requireParam(params, "playerName", "string")
	local reason = params.reason or "No reason provided"
	
	local player = Players:FindFirstChild(playerName)
	if not player then
		error("Player not found: " .. playerName)
	end
	
	player:Kick(reason)
	return string.format("Kicked %s: %s", playerName, reason)
end

-- Place
function METHODS:SavePlace(params)
	game:SavePlace()
	return "Place saved"
end

function METHODS:GetPlaceInfo(params)
	return {
		PlaceId = game.PlaceId,
		Name = game:GetService("MarketplaceService"):GetProductInfo(game.PlaceId).Name,
		JobId = game.JobId,
	}
end

-- Audio
function METHODS:PlaySound(params)
	local soundId = requireParam(params, "soundId", "string")
	local parentPath = params.parentPath or "game.Workspace"
	local properties = params.properties or {}
	
	local parent = requirePath(parentPath)
	local sound = Instance.new("Sound")
	sound.SoundId = "rbxassetid://" .. soundId
	
	for propName, propValue in pairs(properties) do
		pcall(function()
			sound[propName] = propValue
		end)
	end
	
	sound.Parent = parent
	sound:Play()
	ChangeHistoryService:SetWaypoint("Play Sound")
	
	return sound:GetFullName()
end

function METHODS:StopSound(params)
	local path = requireParam(params, "path", "string")
	local obj = requirePath(path)
	
	if not obj:IsA("Sound") then
		error("Object must be a Sound")
	end
	
	obj:Stop()
	ChangeHistoryService:SetWaypoint("Stop Sound")
	
	return string.format("Stopped sound %s", obj.Name)
end

-- Terrain
function METHODS:FillTerrain(params)
	local material = requireParam(params, "material", "string")
	local minX = requireParam(params, "minX", "number")
	local minY = requireParam(params, "minY", "number")
	local minZ = requireParam(params, "minZ", "number")
	local maxX = requireParam(params, "maxX", "number")
	local maxY = requireParam(params, "maxY", "number")
	local maxZ = requireParam(params, "maxZ", "number")
	
	local region = Region3int16.new(
		Vector3int16.new(minX, minY, minZ),
		Vector3int16.new(maxX, maxY, maxZ)
	)
	
	local enumMaterial = Enum.Material[material] or Enum.Material.Grass
	workspace:FillRegion(region, 4, enumMaterial)
	ChangeHistoryService:SetWaypoint("Fill Terrain")
	
	return string.format("Filled terrain region with %s", material)
end

function METHODS:ClearTerrain(params)
	workspace:ClearAllTerrain()
	ChangeHistoryService:SetWaypoint("Clear Terrain")
	return "Cleared all terrain"
end

-- Camera
function METHODS:SetCameraPosition(params)
	local x = requireParam(params, "x", "number")
	local y = requireParam(params, "y", "number")
	local z = requireParam(params, "z", "number")
	
	local camera = workspace.CurrentCamera
	if not camera then
		error("No active camera")
	end
	
	camera.CFrame = CFrame.new(x, y, z)
	ChangeHistoryService:SetWaypoint("Set Camera Position")
	
	return { x, y, z }
end

function METHODS:SetCameraFocus(params)
	local path = requireParam(params, "path", "string")
	local obj = requirePath(path)
	
	local camera = workspace.CurrentCamera
	if not camera then
		error("No active camera")
	end
	
	camera.Focus = obj
	ChangeHistoryService:SetWaypoint("Set Camera Focus")
	
	return obj:GetFullName()
end

function METHODS:GetCameraPosition(params)
	local camera = workspace.CurrentCamera
	if not camera then
		error("No active camera")
	end
	
	local pos = camera.CFrame.Position
	return { pos.X, pos.Y, pos.Z }
end

function METHODS:SetCameraType(params)
	local cameraType = requireParam(params, "cameraType", "string")
	
	local camera = workspace.CurrentCamera
	if not camera then
		error("No active camera")
	end
	
	camera.CameraType = Enum.CameraType[cameraType] or Enum.CameraType.Fixed
	ChangeHistoryService:SetWaypoint("Set Camera Type")
	
	return cameraType
end

function METHODS:ZoomCamera(params)
	local amount = requireParam(params, "amount", "number")
	
	local camera = workspace.CurrentCamera
	if not camera then
		error("No active camera")
	end
	
	camera.FieldOfView = camera.FieldOfView - amount
	ChangeHistoryService:SetWaypoint("Zoom Camera")
	
	return camera.FieldOfView
end

function METHODS:GetCameraType(params)
	local camera = workspace.CurrentCamera
	if not camera then
		error("No active camera")
	end
	
	return tostring(camera.CameraType)
end

-- Utilities
function METHODS:GetDistance(params)
	local path1 = requireParam(params, "path1", "string")
	local path2 = requireParam(params, "path2", "string")
	
	local obj1 = requirePath(path1)
	local obj2 = requirePath(path2)
	
	local pos1 = getObjectPosition(obj1)
	local pos2 = getObjectPosition(obj2)
	
	return (pos1 - pos2).Magnitude
end

function METHODS:HighlightObject(params)
	local path = requireParam(params, "path", "string")
	local color = params.color or { 255, 255, 0 }
	local duration = params.duration
	
	local obj = requirePath(path)
	local highlight = Instance.new("Highlight")
	highlight.Name = "MCP_Highlight_" .. obj.Name
	highlight.FillColor = Color3.new(color[1]/255, color[2]/255, color[3]/255)
	highlight.OutlineColor = Color3.new(color[1]/255, color[2]/255, color[3]/255)
	highlight.FillTransparency = 0.5
	highlight.OutlineTransparency = 0
	highlight.Adornee = obj
	highlight.Parent = obj
	
	if duration then
		Debris:AddItem(highlight, duration)
	end
	
	return string.format("Highlighted %s", obj.Name)
end

function METHODS:Chat(params)
	local message = requireParam(params, "message", "string")
	local color = params.color
	
	if color then
		TextChatService:SendTextMessageToUser("System", message, { Color = Color3.new(color[1]/255, color[2]/255, color[3]/255) })
	else
		TextChatService:SendTextMessageToUser("System", message)
	end
	
	return string.format("Sent chat: %s", message)
end

-- History
function METHODS:Undo(params)
	ChangeHistoryService:Undo()
	return "Undone last action"
end

function METHODS:Redo(params)
	ChangeHistoryService:Redo()
	return "Redone last action"
end

-- ==================== NEW METHODS (158 total) ====================

-- Animation & Character
function METHODS:PlayAnimation(params)
	local path = requireParam(params, "path", "string")
	local animationId = requireParam(params, "animationId", "string")
	
	local obj = requirePath(path)
	if not obj:IsA("Humanoid") then
		error("Object must be a Humanoid")
	end
	
	local animation = Instance.new("Animation")
	animation.AnimationId = "rbxassetid://" .. animationId
	local track = obj:LoadAnimation(animation)
	
	state.animationTracks[obj.Parent.Name] = track
	track:Play()
	
	return string.format("Playing animation on %s", obj.Parent.Name)
end

function METHODS:LoadAnimation(params)
	local path = requireParam(params, "path", "string")
	local animationId = requireParam(params, "animationId", "string")
	
	local obj = requirePath(path)
	if not obj:IsA("Humanoid") then
		error("Object must be a Humanoid")
	end
	
	local animation = Instance.new("Animation")
	animation.AnimationId = "rbxassetid://" .. animationId
	local track = obj:LoadAnimation(animation)
	
	return {
		AnimationId = animation.AnimationId,
		Length = track.Length,
		Priority = track.Priority,
	}
end

function METHODS:StopAnimation(params)
	local path = requireParam(params, "path", "string")
	
	local obj = requirePath(path)
	if not obj:IsA("Humanoid") then
		error("Object must be a Humanoid")
	end
	
	if not obj.Parent then
		error("Humanoid has no parent")
	end
	
	local track = state.animationTracks[obj.Parent.Name]
	if track then
		track:Stop()
		state.animationTracks[obj.Parent.Name] = nil
	end
	
	return string.format("Stopped animation on %s", obj.Parent.Name)
end

function METHODS:SetCharacterAppearance(params)
	local playerPath = requireParam(params, "playerPath", "string")
	local assetId = requireParam(params, "assetId", "string")
	
	local obj = requirePath(playerPath)
	if not obj:IsA("Player") then
		error("Object must be a Player")
	end
	
	if obj.Character then
		local humanoidDescription = obj.Character:FindFirstChildOfClass("HumanoidDescription")
		if humanoidDescription then
			local shirtId = humanoidDescription.Shirt
			local pantsId = humanoidDescription.Pants
			humanoidDescription.Shirt = assetId
			humanoidDescription.Pants = assetId
			obj.CharacterAppearanceLoaded:Wait()
		end
	end
	
	return string.format("Set character appearance for %s", obj.Name)
end

function METHODS:GetCharacter(params)
	local playerName = requireParam(params, "playerName", "string")
	
	local player = Players:FindFirstChild(playerName)
	if not player then
		error("Player not found: " .. playerName)
	end
	
	if not player.Character then
		return nil
	end
	
	return {
		Name = player.Character.Name,
		ClassName = player.Character.ClassName,
		FullName = player.Character:GetFullName(),
		Humanoid = player.Character:FindFirstChildOfClass("Humanoid") ~= nil,
	}
end

-- GUI
function METHODS:CreateGuiElement(params)
	local className = requireParam(params, "className", "string")
	local parentPath = params.parentPath or "game.Players.LocalPlayer.PlayerGui"
	local name = params.name
	local properties = params.properties or {}
	
	local parent = requirePath(parentPath)
	local gui
	
	if className == "ScreenGui" then
		gui = Instance.new("ScreenGui")
	elseif className == "Frame" then
		gui = Instance.new("Frame")
	elseif className == "TextLabel" then
		gui = Instance.new("TextLabel")
	elseif className == "TextButton" then
		gui = Instance.new("TextButton")
	elseif className == "TextBox" then
		gui = Instance.new("TextBox")
	elseif className == "ImageLabel" then
		gui = Instance.new("ImageLabel")
	elseif className == "ImageButton" then
		gui = Instance.new("ImageButton")
	elseif className == "ScrollingFrame" then
		gui = Instance.new("ScrollingFrame")
	elseif className == "UIGridLayout" then
		gui = Instance.new("UIGridLayout")
	elseif className == "UIListLayout" then
		gui = Instance.new("UIListLayout")
	elseif className == "UIPadding" then
		gui = Instance.new("UIPadding")
	elseif className == "UISizeConstraint" then
		gui = Instance.new("UISizeConstraint")
	else
		error("Unknown GUI class: " .. className)
	end
	
	if name then gui.Name = name end
	for propName, propValue in pairs(properties) do
		pcall(function() gui[propName] = propValue end)
	end
	
	gui.Parent = parent
	ChangeHistoryService:SetWaypoint("Create GUI " .. className)
	
	return gui:GetFullName()
end

function METHODS:SetGuiText(params)
	local path = requireParam(params, "path", "string")
	local text = requireParam(params, "text", "string")
	
	local obj = requirePath(path)
	
	if obj:IsA("TextLabel") or obj:IsA("TextButton") or obj:IsA("TextBox") then
		obj.Text = text
	else
		error("Object must be a TextLabel, TextButton, or TextBox")
	end
	
	ChangeHistoryService:SetWaypoint("Set GUI Text")
	return text
end

function METHODS:SetGuiSize(params)
	local path = requireParam(params, "path", "string")
	local size = requireParam(params, "size", "table")
	
	local obj = requirePath(path)
	if not obj:IsA("GuiObject") then
		error("Object must be a GuiObject")
	end
	
	obj.Size = UDim2.new(size[1], size[2])
	ChangeHistoryService:SetWaypoint("Set GUI Size")
	return { obj.Size.X.Scale, obj.Size.Y.Scale }
end

function METHODS:SetGuiPosition(params)
	local path = requireParam(params, "path", "string")
	local position = requireParam(params, "position", "table")
	
	local obj = requirePath(path)
	if not obj:IsA("GuiObject") then
		error("Object must be a GuiObject")
	end
	
	obj.Position = UDim2.new(position[1], position[2])
	ChangeHistoryService:SetWaypoint("Set GUI Position")
	return { obj.Position.X.Scale, obj.Position.Y.Scale }
end

function METHODS:SetGuiVisible(params)
	local path = requireParam(params, "path", "string")
	local visible = requireParam(params, "visible", "boolean")
	
	local obj = requirePath(path)
	if not obj:IsA("GuiObject") then
		error("Object must be a GuiObject")
	end
	
	obj.Visible = visible
	ChangeHistoryService:SetWaypoint(string.format("Set GUI Visible to %s", tostring(visible)))
	return tostring(visible)
end

function METHODS:DestroyGuiElement(params)
	local path = requireParam(params, "path", "string")
	local obj = requirePath(path)
	obj:Destroy()
	ChangeHistoryService:SetWaypoint("Destroy GUI Element")
	return string.format("Destroyed %s", obj.Name)
end

-- Networking
function METHODS:FireRemoteEvent(params)
	local path = requireParam(params, "path", "string")
	local args = params.args or {}
	
	local obj = requirePath(path)
	if not obj:IsA("RemoteEvent") then
		error("Object must be a RemoteEvent")
	end
	
	obj:FireServer(unpack(args))
	return string.format("Fired remote event %s", obj.Name)
end

function METHODS:InvokeRemoteFunction(params)
	local path = requireParam(params, "path", "string")
	local args = params.args or {}
	
	local obj = requirePath(path)
	if not obj:IsA("RemoteFunction") then
		error("Object must be a RemoteFunction")
	end
	
	local result = obj:InvokeServer(unpack(args))
	return result
end

function METHODS:CreateRemoteEvent(params)
	local name = requireParam(params, "name", "string")
	local parentPath = params.parentPath or "game.ReplicatedStorage"
	
	local parent = requirePath(parentPath)
	local remote = Instance.new("RemoteEvent")
	remote.Name = name
	remote.Parent = parent
	ChangeHistoryService:SetWaypoint("Create RemoteEvent")
	
	return remote:GetFullName()
end

function METHODS:CreateRemoteFunction(params)
	local name = requireParam(params, "name", "string")
	local parentPath = params.parentPath or "game.ReplicatedStorage"
	
	local parent = requirePath(parentPath)
	local remote = Instance.new("RemoteFunction")
	remote.Name = name
	remote.Parent = parent
	ChangeHistoryService:SetWaypoint("Create RemoteFunction")
	
	return remote:GetFullName()
end

-- DataStore
function METHODS:GetDataStore(params)
	local name = requireParam(params, "name", "string")
	local success, dataStore = pcall(function()
		return DataStoreService:GetDataStore(name)
	end)
	
	if not success then
		error("Failed to get data store: " .. tostring(dataStore))
	end
	
	return {
		Name = name,
		Exists = true,
	}
end

function METHODS:SetDataStoreValue(params)
	local storeName = requireParam(params, "storeName", "string")
	local key = requireParam(params, "key", "string")
	local value = requireParam(params, "value")
	
	local success, dataStore = pcall(function()
		return DataStoreService:GetDataStore(storeName)
	end)
	
	if not success then
		error("Failed to get data store: " .. tostring(dataStore))
	end
	
	local setSuccess, setResult = pcall(function()
		return dataStore:SetAsync(key, value)
	end)
	
	if not setSuccess then
		error("Failed to set data store value: " .. tostring(setResult))
	end
	
	ChangeHistoryService:SetWaypoint("Set DataStore Value")
	return string.format("Set %s = %s in %s", key, tostring(value), storeName)
end

function METHODS:GetDataStoreValue(params)
	local storeName = requireParam(params, "storeName", "string")
	local key = requireParam(params, "key", "string")
	
	local success, dataStore = pcall(function()
		return DataStoreService:GetDataStore(storeName)
	end)
	
	if not success then
		error("Failed to get data store: " .. tostring(dataStore))
	end
	
	local getSuccess, value = pcall(function()
		return dataStore:GetAsync(key)
	end)
	
	if not getSuccess then
		error("Failed to get data store value: " .. tostring(value))
	end
	
	return value
end

function METHODS:RemoveDataStoreValue(params)
	local storeName = requireParam(params, "storeName", "string")
	local key = requireParam(params, "key", "string")
	
	local success, dataStore = pcall(function()
		return DataStoreService:GetDataStore(storeName)
	end)
	
	if not success then
		error("Failed to get data store: " .. tostring(dataStore))
	end
	
	local removeSuccess = pcall(function()
		return dataStore:RemoveAsync(key)
	end)
	
	if not removeSuccess then
		error("Failed to remove data store value")
	end
	
	ChangeHistoryService:SetWaypoint("Remove DataStore Value")
	return string.format("Removed %s from %s", key, storeName)
end

-- Tween
function METHODS:CreateTween(params)
	local path = requireParam(params, "path", "string")
	local targetProperties = requireParam(params, "targetProperties", "table")
	local duration = params.duration or 0.5
	
	local obj = requirePath(path)
	
	local tweenInfo = TweenInfo.new(duration)
	local tween = TweenService:Create(obj, targetProperties, tweenInfo)
	
	tween:Play()
	
	local tweenId = tostring(tween)
	state.activeTweens[tweenId] = tween
	
	return string.format("Created tween on %s", obj.Name)
end

function METHODS:TweenProperty(params)
	local path = requireParam(params, "path", "string")
	local property = requireParam(params, "property", "string")
	local endValue = requireParam(params, "endValue")
	local duration = params.duration or 0.5
	
	local obj = requirePath(path)
	local targetProps = {}
	targetProps[property] = endValue
	
	local tweenInfo = TweenInfo.new(duration)
	local tween = TweenService:Create(obj, targetProps, tweenInfo)
	
	tween:Play()
	return string.format("Tweening %s on %s", property, obj.Name)
end

-- Raycasting
function METHODS:Raycast(params)
	local origin = requireParam(params, "origin", "table")
	local direction = requireParam(params, "direction", "table")
	local raycastParams = createRaycastParams(params.params)
	
	local originVector = Vector3.new(origin[1], origin[2], origin[3])
	local directionVector = Vector3.new(direction[1], direction[2], direction[3])
	
	local result = workspace:Raycast(originVector, directionVector, raycastParams)
	
	if result then
		return {
			Instance = result.Instance and result.Instance:GetFullName(),
			Position = { result.Position.X, result.Position.Y, result.Position.Z },
			Material = tostring(result.Material),
			Distance = result.Distance,
		}
	end
	
	return nil
end

function METHODS:RaycastTo(params)
	local path = requireParam(params, "path", "string")
	local targetPath = requireParam(params, "targetPath", "string")
	local raycastParams = createRaycastParams(params.params)
	
	local obj = requirePath(path)
	local target = requirePath(targetPath)
	
	local startPos = getObjectPosition(obj)
	local endPos = getObjectPosition(target)
	local direction = (endPos - startPos).Unit
	
	local result = workspace:Raycast(startPos, direction, raycastParams)
	
	if result then
		return {
			Instance = result.Instance and result.Instance:GetFullName(),
			Position = { result.Position.X, result.Position.Y, result.Position.Z },
			Material = tostring(result.Material),
			Distance = result.Distance,
		}
	end
	
	return nil
end

-- Constraints
function METHODS:CreateWeld(params)
	local part0Path = requireParam(params, "part0Path", "string")
	local part1Path = requireParam(params, "part1Path", "string")
	local properties = params.properties or {}
	
	local part0 = requirePath(part0Path)
	local part1 = requirePath(part1Path)
	
	local weld = Instance.new("WeldConstraint")
	
	local attachment0 = Instance.new("Attachment")
	attachment0.Name = "WeldAttach0"
	attachment0.Parent = part0
	
	local attachment1 = Instance.new("Attachment")
	attachment1.Name = "WeldAttach1"
	attachment1.Parent = part1
	
	weld.Part0 = part0
	weld.Part1 = part1
	weld.C0 = attachment0
	weld.C1 = attachment1
	
	for propName, propValue in pairs(properties) do
		pcall(function() weld[propName] = propValue end)
	end
	
	weld.Parent = part0
	ChangeHistoryService:SetWaypoint("Create Weld")
	
	return weld:GetFullName()
end

function METHODS:CreateMotor6D(params)
	local part0Path = requireParam(params, "part0Path", "string")
	local part1Path = requireParam(params, "part1Path", "string")
	local properties = params.properties or {}
	
	local part0 = requirePath(part0Path)
	local part1 = requirePath(part1Path)
	
	local motor = Instance.new("Motor6D")
	
	local attachment0 = Instance.new("Attachment")
	attachment0.Name = "MotorAttach0"
	attachment0.Parent = part0
	
	local attachment1 = Instance.new("Attachment")
	attachment1.Name = "MotorAttach1"
	attachment1.Parent = part1
	
	motor.Part0 = part0
	motor.Part1 = part1
	motor.C0 = attachment0
	motor.C1 = attachment1
	
	for propName, propValue in pairs(properties) do
		pcall(function() motor[propName] = propValue end)
	end
	
	motor.Parent = part0
	ChangeHistoryService:SetWaypoint("Create Motor6D")
	
	return motor:GetFullName()
end

-- Particles
function METHODS:CreateParticleEmitter(params)
	local path = requireParam(params, "path", "string")
	local properties = params.properties or {}
	
	local obj = requirePath(path)
	if not obj:IsA("BasePart") then
		error("Object must be a BasePart")
	end
	
	local emitter = Instance.new("ParticleEmitter")
	
	for propName, propValue in pairs(properties) do
		pcall(function() emitter[propName] = propValue end)
	end
	
	emitter.Parent = obj
	ChangeHistoryService:SetWaypoint("Create ParticleEmitter")
	
	return emitter:GetFullName()
end

function METHODS:EmitParticles(params)
	local path = requireParam(params, "path", "string")
	local count = params.count or 10
	
	local obj = requirePath(path)
	local emitter = obj:FindFirstChildOfClass("ParticleEmitter")
	
	if not emitter then
		error("No ParticleEmitter found on object")
	end
	
	emitter:Emit(count)
	return string.format("Emitted %d particles", count)
end

-- Materials
function METHODS:ApplyDecal(params)
	local path = requireParam(params, "path", "string")
	local texture = requireParam(params, "texture", "string")
	local parentPath = params.parentPath or "game.Workspace"
	
	local parent = requirePath(parentPath)
	local decal = Instance.new("Decal")
	decal.Texture = "rbxassetid://" .. texture
	decal.Parent = parent
	
	ChangeHistoryService:SetWaypoint("Apply Decal")
	return decal:GetFullName()
end

function METHODS:ApplyTexture(params)
	local path = requireParam(params, "path", "string")
	local texture = requireParam(params, "texture", "string")
	local parentPath = params.parentPath or "game.Workspace"
	
	local parent = requirePath(parentPath)
	local textureObj = Instance.new("Texture")
	textureObj.Texture = "rbxassetid://" .. texture
	textureObj.Parent = parent
	
	ChangeHistoryService:SetWaypoint("Apply Texture")
	return textureObj:GetFullName()
end

-- Marketplace
function METHODS:InsertAsset(params)
	local assetId = requireParam(params, "assetId", "string")
	local parentPath = params.parentPath or "game.Workspace"
	
	local parent = requirePath(parentPath)
	local success, asset = pcall(function()
		return MarketplaceService:InsertAsset(tonumber(assetId), parent)
	end)
	
	if not success then
		error("Failed to insert asset: " .. tostring(asset))
	end
	
	ChangeHistoryService:SetWaypoint("Insert Asset")
	return asset and asset:GetFullName() or "Asset inserted"
end

function METHODS:InsertMesh(params)
	local meshId = requireParam(params, "meshId", "string")
	local parentPath = params.parentPath or "game.Workspace"
	
	local parent = requirePath(parentPath)
	local mesh = Instance.new("Part")
	mesh.Shape = Enum.PartType.Ball
	mesh.Size = Vector3.new(1, 1, 1)
	
	local meshObj = Instance.new("SpecialMesh")
	meshObj.MeshId = "rbxassetid://" .. meshId
	meshObj.Parent = mesh
	
	mesh.Parent = parent
	ChangeHistoryService:SetWaypoint("Insert Mesh")
	
	return mesh:GetFullName()
end

-- Teams
function METHODS:CreateTeam(params)
	local name = requireParam(params, "name", "string")
	local color = params.color
	
	local team = Instance.new("Team")
	team.Name = name
	
	if color then
		team.TeamColor = BrickColor.new(color[1], color[2], color[3])
	end
	
	team.Parent = Teams
	ChangeHistoryService:SetWaypoint("Create Team")
	
	return team:GetFullName()
end

function METHODS:SetPlayerTeam(params)
	local playerName = requireParam(params, "playerName", "string")
	local teamName = requireParam(params, "teamName", "string")
	
	local player = Players:FindFirstChild(playerName)
	if not player then
		error("Player not found: " .. playerName)
	end
	
	local team = Teams:FindFirstChild(teamName)
	if not team then
		error("Team not found: " .. teamName)
	end
	
	player.Team = team
	ChangeHistoryService:SetWaypoint("Set Player Team")
	
	return string.format("Set %s to team %s", playerName, teamName)
end

function METHODS:GetPlayerTeam(params)
	local playerName = requireParam(params, "playerName", "string")
	
	local player = Players:FindFirstChild(playerName)
	if not player then
		error("Player not found: " .. playerName)
	end
	
	return player.Team and player.Team.Name or nil
end

-- Leaderstats
function METHODS:CreateLeaderstat(params)
	local name = requireParam(params, "name", "string")
	local parentPath = params.parentPath or "game.Players"
	
	local parent = requirePath(parentPath)
	local leaderstats = parent:FindFirstChild("leaderstats")
	
	if not leaderstats then
		leaderstats = Instance.new("Folder")
		leaderstats.Name = "leaderstats"
		leaderstats.Parent = parent
	end
	
	local valueObj = Instance.new("IntValue")
	valueObj.Name = name
	valueObj.Value = 0
	valueObj.Parent = leaderstats
	
	ChangeHistoryService:SetWaypoint("Create Leaderstat")
	return valueObj:GetFullName()
end

function METHODS:SetLeaderstatValue(params)
	local path = requireParam(params, "path", "string")
	local value = requireParam(params, "value")
	
	local obj = requirePath(path)
	if not (obj:IsA("IntValue") or obj:IsA("NumberValue") or obj:IsA("StringValue")) then
		error("Object must be a Value object")
	end
	
	obj.Value = value
	ChangeHistoryService:SetWaypoint("Set Leaderstat Value")
	
	return string.format("Set %s = %s", obj.Name, tostring(value))
end

function METHODS:GetLeaderstatValue(params)
	local path = requireParam(params, "path", "string")
	local obj = requirePath(path)
	if not (obj:IsA("IntValue") or obj:IsA("NumberValue") or obj:IsA("StringValue")) then
		error("Object must be a Value object")
	end
	
	return obj.Value
end

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
	
	if data.type == "commands" and data.data then
		local commands = data.data
		if type(commands) == "table" and #commands > 0 then
			for _, command in ipairs(commands) do
				executeCommand(command)
			end
		end
	elseif data.type == "command" and data.data then
		executeCommand(data.data)
	elseif data.type == "ping" then
		if state.websocket then
			pcall(function()
				state.websocket:Send(HttpService:JSONEncode({ type = "pong" }))
			end)
		end
	end
end

local function handleWebSocketError(errorMessage)
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
		state.useWebSocket = false
		return false
	end
	
	state.websocket = ws
	state.connected = true
	print("[MCP] WebSocket connected at port", state.currentPort)
	
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
	
	return false
end

--------------------------------------------------------------------------------
-- Main Loop
--------------------------------------------------------------------------------

local function mainLoop()
	if not state.connected then
		if not findMCPServer() then
			wait(CONFIG.RETRY_INTERVAL)
			return
		end
		
		if state.useWebSocket then
			local wsConnected = connectWebSocket()
			if wsConnected then
				wait(1.0)
				return
			else
				print("[MCP] Falling back to HTTP polling")
				state.useWebSocket = false
			end
		end
	end
	
	if not state.useWebSocket or not state.websocket then
		pollCommands()
		wait(0.1)
	else
		wait(1.0)
	end
end

--------------------------------------------------------------------------------
-- Startup
--------------------------------------------------------------------------------

print(string.format("[MCP Bridge Plugin v%s] Starting...", VERSION))
print("[MCP] Searching for bridge server...")

while true do
	local ok, err = pcall(mainLoop)
	if not ok then
		warn("[MCP] Error in main loop:", err)
		wait(CONFIG.RETRY_INTERVAL)
	end
end
