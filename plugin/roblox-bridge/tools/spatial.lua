--!optimize 2
--------------------------------------------------------------------------------
-- Spatial & Physics Tools
-- Provides methods for transforms, physics properties, constraints, and raycasting.
-- Handles position, rotation, size, velocity, impulses, and spatial queries.
--
-- Methods:
--   Transforms: MoveTo, SetPosition, GetPosition, SetRotation, GetRotation, SetSize, GetSize, PivotTo, GetPivot
--   Physics: SetAnchored, SetCanCollide, CreateConstraint, SetPhysicalProperties, GetMass, ApplyImpulse, ApplyAngularImpulse
--   Joints: BreakJoints, GetJoints, GetConnectedParts, GetTouchingParts, CreateWeld, CreateMotor6D
--   Velocity: SetMassless, GetVelocity, SetVelocity, GetAngularVelocity, SetAngularVelocity, GetCenterOfMass
--   Collision: SetCollisionGroup, GetCollisionGroup
--   Assembly: GetAssemblyMass, GetAssemblyCenterOfMass, GetRootPart, SetRootPriority, GetRootPriority
--   Attachments: CreateAttachment, GetAttachmentPosition, SetAttachmentPosition
--   Raycasting: Raycast, RaycastTo, Spherecast, Blockcast, GetPartsInPart, GetPartBoundsInRadius, GetPartBoundsInBox
--   Utilities: GetDistance
--------------------------------------------------------------------------------

-- Localize globals for performance
local table_insert = table.insert
local table_create = table.create
local pairs = pairs
local ipairs = ipairs
local pcall = pcall
local tostring = tostring
local Vector3_new = Vector3.new
local CFrame_new = CFrame.new

local Path = require(script.Parent.Parent.utils.path)

local Tools = {}

-- Transform
function Tools.MoveTo(p)
	local obj = Path.require(p.path)
	local position = p.position
	local pos = Vector3_new(position[1], position[2], position[3])
	if obj:IsA("Model") then obj:MoveTo(pos)
	elseif obj:IsA("BasePart") then obj.Position = pos
	else error("Cannot move: not a Model or BasePart") end
	return "Moved"
end

function Tools.SetPosition(p)
	Path.requireBasePart(p.path).Position = Vector3_new(p.x, p.y, p.z)
	return "Set"
end

function Tools.GetPosition(p)
	local pos = Path.requireBasePart(p.path).Position
	return { pos.X, pos.Y, pos.Z }
end

function Tools.SetRotation(p)
	Path.requireBasePart(p.path).Rotation = Vector3_new(p.x, p.y, p.z)
	return "Set"
end

function Tools.GetRotation(p)
	local rot = Path.requireBasePart(p.path).Rotation
	return { rot.X, rot.Y, rot.Z }
end

function Tools.SetSize(p)
	Path.requireBasePart(p.path).Size = Vector3_new(p.x, p.y, p.z)
	return "Set"
end

function Tools.GetSize(p)
	local size = Path.requireBasePart(p.path).Size
	return { size.X, size.Y, size.Z }
end

function Tools.PivotTo(p)
	local obj = Path.require(p.path)
	if not obj:IsA("PVInstance") then error("Not a PVInstance") end
	local c = p.cframe
	obj:PivotTo(CFrame_new(c[1], c[2], c[3], c[4], c[5], c[6], c[7], c[8], c[9], c[10], c[11], c[12]))
	return "Pivoted"
end

function Tools.GetPivot(p)
	local obj = Path.require(p.path)
	if not obj:IsA("PVInstance") then error("Not a PVInstance") end
	return { obj:GetPivot():GetComponents() }
end

-- Physics
function Tools.SetAnchored(p)
	Path.requireBasePart(p.path).Anchored = p.anchored
	return "Set"
end

function Tools.SetCanCollide(p)
	Path.requireBasePart(p.path).CanCollide = p.canCollide
	return "Set"
end

function Tools.CreateConstraint(p)
	local att0, att1 = Path.require(p.attachment0Path), Path.require(p.attachment1Path)
	if not att0:IsA("Attachment") or not att1:IsA("Attachment") then
		error("Paths must be Attachments")
	end
	local constraint = Instance.new(p.type)
	constraint.Attachment0, constraint.Attachment1 = att0, att1
	if p.properties then
		for k, v in pairs(p.properties) do pcall(function() constraint[k] = v end) end
	end
	constraint.Parent = att0.Parent
	return constraint:GetFullName()
end

function Tools.SetPhysicalProperties(p)
	Path.requireBasePart(p.path).CustomPhysicalProperties = PhysicalProperties.new(
		p.density or 1, p.friction or 0.3, p.elasticity or 0.5,
		p.frictionWeight or 1, p.elasticityWeight or 1
	)
	return "Set"
end

function Tools.GetMass(p) return Path.requireBasePart(p.path):GetMass() end

function Tools.ApplyImpulse(p)
	local part = Path.requireBasePart(p.path)
	local impulse = p.impulse
	part:ApplyImpulse(Vector3_new(impulse[1], impulse[2], impulse[3]))
	return "Applied"
end

function Tools.ApplyAngularImpulse(p)
	local part = Path.requireBasePart(p.path)
	local impulse = p.impulse
	part:ApplyAngularImpulse(Vector3_new(impulse[1], impulse[2], impulse[3]))
	return "Applied"
end

function Tools.BreakJoints(p)
	local part = Path.requireBasePart(p.path)
	part:BreakJoints()
	return "Broken"
end

function Tools.GetJoints(p)
	local part = Path.requireBasePart(p.path)
	local joints = part:GetJoints()
	local paths = table_create(#joints)
	for i, j in ipairs(joints) do paths[i] = j:GetFullName() end
	return paths
end

-- Welds & Motor6D
function Tools.CreateWeld(p)
	local part0, part1 = Path.requireBasePart(p.part0Path), Path.requireBasePart(p.part1Path)
	local weld = Instance.new("WeldConstraint")
	weld.Part0, weld.Part1 = part0, part1
	weld.Parent = part0
	return weld:GetFullName()
end

function Tools.CreateMotor6D(p)
	local part0, part1 = Path.requireBasePart(p.part0Path), Path.requireBasePart(p.part1Path)
	local motor = Instance.new("Motor6D")
	motor.Name = p.name or "Motor6D"
	motor.Part0, motor.Part1 = part0, part1
	motor.Parent = part0
	return motor:GetFullName()
end

-- Raycasting
local function createRaycastParams(p)
	local params = RaycastParams.new()
	local filterDescendants = p.filterDescendants
	if filterDescendants then
		local numFilters = #filterDescendants
		local instances = table_create(numFilters)
		local idx = 0
		for _, path in ipairs(filterDescendants) do
			local obj = Path.resolve(path)
			if obj then
				idx = idx + 1
				instances[idx] = obj
			end
		end
		params.FilterDescendantsInstances = instances
	end
	local filterType = p.filterType
	if filterType then
		params.FilterType = Enum.RaycastFilterType[filterType] or Enum.RaycastFilterType.Exclude
	end
	return params
end

function Tools.Raycast(p)
	local originData = p.origin
	local directionData = p.direction
	local origin = Vector3_new(originData[1], originData[2], originData[3])
	local direction = Vector3_new(directionData[1], directionData[2], directionData[3])
	local result = workspace:Raycast(origin, direction, createRaycastParams(p))
	if not result then return nil end
	local resultPos = result.Position
	local resultNormal = result.Normal
	return {
		instance = result.Instance:GetFullName(),
		position = { resultPos.X, resultPos.Y, resultPos.Z },
		normal = { resultNormal.X, resultNormal.Y, resultNormal.Z },
		material = tostring(result.Material),
		distance = result.Distance,
	}
end

function Tools.RaycastTo(p)
	local origin = Path.getPosition(Path.require(p.originPath))
	local target = Path.getPosition(Path.require(p.targetPath))
	local direction = (target - origin)
	local result = workspace:Raycast(origin, direction, createRaycastParams(p))
	if not result then return nil end
	return {
		instance = result.Instance:GetFullName(),
		position = { result.Position.X, result.Position.Y, result.Position.Z },
		distance = result.Distance,
	}
end

-- Utilities
function Tools.GetDistance(p)
	local pos1 = Path.getPosition(Path.require(p.path1))
	local pos2 = Path.getPosition(Path.require(p.path2))
	return (pos1 - pos2).Magnitude
end

-- Advanced Spatial Queries
function Tools.Spherecast(p)
	local posData = p.position
	local dirData = p.direction
	local pos = Vector3_new(posData[1], posData[2], posData[3])
	local direction = Vector3_new(dirData[1], dirData[2], dirData[3])
	local result = workspace:Spherecast(pos, p.radius, direction, createRaycastParams(p))
	if not result then return nil end
	local resultPos = result.Position
	local resultNormal = result.Normal
	return {
		instance = result.Instance:GetFullName(),
		position = { resultPos.X, resultPos.Y, resultPos.Z },
		normal = { resultNormal.X, resultNormal.Y, resultNormal.Z },
		distance = result.Distance,
	}
end

function Tools.Blockcast(p)
	local posData = p.position
	local sizeData = p.size
	local dirData = p.direction
	local cframe = CFrame_new(posData[1], posData[2], posData[3])
	local size = Vector3_new(sizeData[1], sizeData[2], sizeData[3])
	local direction = Vector3_new(dirData[1], dirData[2], dirData[3])
	local result = workspace:Blockcast(cframe, size, direction, createRaycastParams(p))
	if not result then return nil end
	local resultPos = result.Position
	local resultNormal = result.Normal
	return {
		instance = result.Instance:GetFullName(),
		position = { resultPos.X, resultPos.Y, resultPos.Z },
		normal = { resultNormal.X, resultNormal.Y, resultNormal.Z },
		distance = result.Distance,
	}
end

-- Helper for overlap params (avoids repeated code)
local function createOverlapParams(filterDescendants, filterType)
	local params = OverlapParams.new()
	if filterDescendants then
		local numFilters = #filterDescendants
		local instances = table_create(numFilters)
		local idx = 0
		for _, path in ipairs(filterDescendants) do
			local obj = Path.resolve(path)
			if obj then
				idx = idx + 1
				instances[idx] = obj
			end
		end
		params.FilterDescendantsInstances = instances
	end
	if filterType then
		params.FilterType = Enum.RaycastFilterType[filterType] or Enum.RaycastFilterType.Exclude
	end
	return params
end

function Tools.GetPartsInPart(p)
	local part = Path.requireBasePart(p.path)
	local params = createOverlapParams(p.filterDescendants, p.filterType)
	local parts = workspace:GetPartsInPart(part, params)
	local paths = table_create(#parts)
	for i, partObj in ipairs(parts) do paths[i] = partObj:GetFullName() end
	return paths
end

function Tools.GetPartBoundsInRadius(p)
	local position = p.position
	local pos = Vector3_new(position[1], position[2], position[3])
	local params = createOverlapParams(p.filterDescendants, nil)
	local parts = workspace:GetPartBoundsInRadius(pos, p.radius, params)
	local paths = table_create(#parts)
	for i, part in ipairs(parts) do paths[i] = part:GetFullName() end
	return paths
end

function Tools.GetPartBoundsInBox(p)
	local position = p.position
	local sizeData = p.size
	local cframe = CFrame_new(position[1], position[2], position[3])
	local size = Vector3_new(sizeData[1], sizeData[2], sizeData[3])
	local params = createOverlapParams(p.filterDescendants, nil)
	local parts = workspace:GetPartBoundsInBox(cframe, size, params)
	local paths = table_create(#parts)
	for i, part in ipairs(parts) do paths[i] = part:GetFullName() end
	return paths
end

function Tools.GetTouchingParts(p)
	local part = Path.requireBasePart(p.path)
	local touching = part:GetTouchingParts()
	local paths = table_create(#touching)
	for i, t in ipairs(touching) do paths[i] = t:GetFullName() end
	return paths
end

function Tools.GetConnectedParts(p)
	local part = Path.requireBasePart(p.path)
	local connected = part:GetConnectedParts(p.recursive or false)
	local paths = table_create(#connected)
	for i, c in ipairs(connected) do paths[i] = c:GetFullName() end
	return paths
end

-- Attachments
function Tools.CreateAttachment(p)
	local parent = Path.requireBasePart(p.parentPath)
	local attachment = Instance.new("Attachment")
	attachment.Name = p.name or "Attachment"
	local position = p.position
	if position then
		attachment.Position = Vector3_new(position[1], position[2], position[3])
	end
	local orientation = p.orientation
	if orientation then
		attachment.Orientation = Vector3_new(orientation[1], orientation[2], orientation[3])
	end
	attachment.Parent = parent
	return attachment:GetFullName()
end

function Tools.GetAttachmentPosition(p)
	local att = Path.require(p.path)
	if not att:IsA("Attachment") then error("Not an Attachment: " .. p.path) end
	return { att.WorldPosition.X, att.WorldPosition.Y, att.WorldPosition.Z }
end

function Tools.SetAttachmentPosition(p)
	local att = Path.require(p.path)
	if not att:IsA("Attachment") then error("Not an Attachment: " .. p.path) end
	att.Position = Vector3_new(p.x, p.y, p.z)
	return "Set"
end

-- Collision Groups
function Tools.SetCollisionGroup(p)
	local part = Path.requireBasePart(p.path)
	part.CollisionGroup = p.group
	return "Set"
end

function Tools.GetCollisionGroup(p)
	return Path.requireBasePart(p.path).CollisionGroup
end

-- Additional Part Properties
function Tools.SetMassless(p)
	Path.requireBasePart(p.path).Massless = p.massless
	return "Set"
end

function Tools.GetVelocity(p)
	local part = Path.requireBasePart(p.path)
	local vel = part.AssemblyLinearVelocity
	return { vel.X, vel.Y, vel.Z }
end

function Tools.SetVelocity(p)
	local part = Path.requireBasePart(p.path)
	part.AssemblyLinearVelocity = Vector3_new(p.x, p.y, p.z)
	return "Set"
end

function Tools.GetAngularVelocity(p)
	local part = Path.requireBasePart(p.path)
	local vel = part.AssemblyAngularVelocity
	return { vel.X, vel.Y, vel.Z }
end

function Tools.SetAngularVelocity(p)
	local part = Path.requireBasePart(p.path)
	part.AssemblyAngularVelocity = Vector3_new(p.x, p.y, p.z)
	return "Set"
end

-- Center of Mass
function Tools.GetCenterOfMass(p)
	local part = Path.requireBasePart(p.path)
	local com = part.CenterOfMass
	return { com.X, com.Y, com.Z }
end

-- Assembly Physics
function Tools.GetAssemblyMass(p)
	return Path.requireBasePart(p.path):GetMass()
end

function Tools.GetAssemblyCenterOfMass(p)
	local part = Path.requireBasePart(p.path)
	local com = part.AssemblyCenterOfMass
	return { com.X, com.Y, com.Z }
end

function Tools.GetRootPart(p)
	local part = Path.requireBasePart(p.path)
	local root = part.AssemblyRootPart
	return root and root:GetFullName() or nil
end

function Tools.SetRootPriority(p)
	Path.requireBasePart(p.path).RootPriority = p.priority
	return "Set"
end

function Tools.GetRootPriority(p)
	return Path.requireBasePart(p.path).RootPriority
end

return Tools
