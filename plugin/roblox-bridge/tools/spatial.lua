-- Transform, physics, constraints, and raycast tools
local Path = require(script.Parent.Parent.utils.path)

local Tools = {}

-- Transform
function Tools.MoveTo(p)
	local obj = Path.require(p.path)
	local pos = Vector3.new(p.position[1], p.position[2], p.position[3])
	if obj:IsA("Model") then obj:MoveTo(pos)
	elseif obj:IsA("BasePart") then obj.Position = pos
	else error("Cannot move: not a Model or BasePart") end
	return "Moved"
end

function Tools.SetPosition(p)
	Path.requireBasePart(p.path).Position = Vector3.new(p.x, p.y, p.z)
	return "Set"
end

function Tools.GetPosition(p)
	local pos = Path.requireBasePart(p.path).Position
	return { pos.X, pos.Y, pos.Z }
end

function Tools.SetRotation(p)
	Path.requireBasePart(p.path).Rotation = Vector3.new(p.x, p.y, p.z)
	return "Set"
end

function Tools.GetRotation(p)
	local rot = Path.requireBasePart(p.path).Rotation
	return { rot.X, rot.Y, rot.Z }
end

function Tools.SetSize(p)
	Path.requireBasePart(p.path).Size = Vector3.new(p.x, p.y, p.z)
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
	obj:PivotTo(CFrame.new(c[1], c[2], c[3], c[4], c[5], c[6], c[7], c[8], c[9], c[10], c[11], c[12]))
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
	if p.filterDescendants then
		local instances = {}
		for _, path in ipairs(p.filterDescendants) do
			local obj = Path.resolve(path)
			if obj then table.insert(instances, obj) end
		end
		params.FilterDescendantsInstances = instances
	end
	if p.filterType then
		params.FilterType = Enum.RaycastFilterType[p.filterType] or Enum.RaycastFilterType.Exclude
	end
	return params
end

function Tools.Raycast(p)
	local origin = Vector3.new(p.origin[1], p.origin[2], p.origin[3])
	local direction = Vector3.new(p.direction[1], p.direction[2], p.direction[3])
	local result = workspace:Raycast(origin, direction, createRaycastParams(p))
	if not result then return nil end
	return {
		instance = result.Instance:GetFullName(),
		position = { result.Position.X, result.Position.Y, result.Position.Z },
		normal = { result.Normal.X, result.Normal.Y, result.Normal.Z },
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

return Tools
