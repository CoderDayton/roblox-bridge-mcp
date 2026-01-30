-- Terrain, camera, history, place, attributes, and tags tools
local Services = require(script.Parent.Parent.utils.services)
local Path = require(script.Parent.Parent.utils.path)

local Tools = {}

-- Terrain
function Tools.GetTerrainInfo()
	local terrain = workspace.Terrain
	return {
		maxExtents = { terrain.MaxExtents.Min.X, terrain.MaxExtents.Min.Y, terrain.MaxExtents.Min.Z,
			terrain.MaxExtents.Max.X, terrain.MaxExtents.Max.Y, terrain.MaxExtents.Max.Z },
		waterWaveSize = terrain.WaterWaveSize,
		waterWaveSpeed = terrain.WaterWaveSpeed,
	}
end

function Tools.FillTerrainRegion(p)
	local min = Vector3.new(p.min[1], p.min[2], p.min[3])
	local max = Vector3.new(p.max[1], p.max[2], p.max[3])
	local material = Enum.Material[p.material]
	if not material then error("Invalid material: " .. p.material) end
	workspace.Terrain:FillRegion(Region3.new(min, max):ExpandToGrid(4), 4, material)
	return "Filled"
end

function Tools.ClearTerrain()
	workspace.Terrain:Clear()
	return "Cleared"
end

function Tools.FillBall(p)
	local center = Vector3.new(p.center[1], p.center[2], p.center[3])
	local material = Enum.Material[p.material]
	if not material then error("Invalid material: " .. p.material) end
	workspace.Terrain:FillBall(center, p.radius, material)
	return "Filled"
end

function Tools.FillBlock(p)
	local cframe = CFrame.new(p.position[1], p.position[2], p.position[3])
	local size = Vector3.new(p.size[1], p.size[2], p.size[3])
	local material = Enum.Material[p.material]
	if not material then error("Invalid material: " .. p.material) end
	workspace.Terrain:FillBlock(cframe, size, material)
	return "Filled"
end

function Tools.FillCylinder(p)
	local cframe = CFrame.new(p.position[1], p.position[2], p.position[3])
	local material = Enum.Material[p.material]
	if not material then error("Invalid material: " .. p.material) end
	workspace.Terrain:FillCylinder(cframe, p.height, p.radius, material)
	return "Filled"
end

function Tools.FillWedge(p)
	local cframe = CFrame.new(p.position[1], p.position[2], p.position[3])
	local size = Vector3.new(p.size[1], p.size[2], p.size[3])
	local material = Enum.Material[p.material]
	if not material then error("Invalid material: " .. p.material) end
	workspace.Terrain:FillWedge(cframe, size, material)
	return "Filled"
end

function Tools.ReplaceMaterial(p)
	local min = Vector3.new(p.min[1], p.min[2], p.min[3])
	local max = Vector3.new(p.max[1], p.max[2], p.max[3])
	local region = Region3.new(min, max):ExpandToGrid(4)
	local sourceMaterial = Enum.Material[p.sourceMaterial]
	local targetMaterial = Enum.Material[p.targetMaterial]
	if not sourceMaterial then error("Invalid source material: " .. p.sourceMaterial) end
	if not targetMaterial then error("Invalid target material: " .. p.targetMaterial) end
	workspace.Terrain:ReplaceMaterial(region, 4, sourceMaterial, targetMaterial)
	return "Replaced"
end

-- Camera
function Tools.SetCameraPosition(p)
	local camera = workspace.CurrentCamera
	camera.CFrame = CFrame.new(p.x, p.y, p.z) * camera.CFrame.Rotation
	return "Set"
end

function Tools.SetCameraTarget(p)
	local camera = workspace.CurrentCamera
	local pos = camera.CFrame.Position
	local target = Vector3.new(p.x, p.y, p.z)
	camera.CFrame = CFrame.lookAt(pos, target)
	return "Set"
end

function Tools.SetCameraFocus(p)
	local target = Path.require(p.path)
	local pos = Path.getPosition(target)
	local camera = workspace.CurrentCamera
	camera.CFrame = CFrame.lookAt(camera.CFrame.Position, pos)
	return "Set"
end

function Tools.SetCameraType(p)
	local camType = Enum.CameraType[p.cameraType]
	if not camType then error("Invalid camera type: " .. p.cameraType) end
	workspace.CurrentCamera.CameraType = camType
	return "Set"
end

function Tools.GetCameraType()
	return tostring(workspace.CurrentCamera.CameraType)
end

function Tools.ZoomCamera(p)
	local camera = workspace.CurrentCamera
	local direction = camera.CFrame.LookVector
	camera.CFrame = camera.CFrame + direction * p.distance
	return "Zoomed"
end

-- Change History
function Tools.RecordUndo(p)
	Services.ChangeHistoryService:SetWaypoint(p.name)
	return "Recorded"
end

function Tools.Undo()
	Services.ChangeHistoryService:Undo()
	return "Undone"
end

function Tools.Redo()
	Services.ChangeHistoryService:Redo()
	return "Redone"
end

-- Place Info
function Tools.GetPlaceInfo()
	return {
		PlaceId = game.PlaceId,
		PlaceVersion = game.PlaceVersion,
		GameId = game.GameId,
		CreatorId = game.CreatorId,
		CreatorType = tostring(game.CreatorType),
	}
end

-- Attributes
function Tools.SetAttribute(p)
	Path.require(p.path):SetAttribute(p.name, p.value)
	return "Set"
end

function Tools.GetAttribute(p)
	return Path.require(p.path):GetAttribute(p.name)
end

function Tools.GetAttributes(p)
	return Path.require(p.path):GetAttributes()
end

function Tools.RemoveAttribute(p)
	Path.require(p.path):SetAttribute(p.name, nil)
	return "Removed"
end

-- Tags
function Tools.AddTag(p)
	Services.CollectionService:AddTag(Path.require(p.path), p.tag)
	return "Added"
end

function Tools.RemoveTag(p)
	Services.CollectionService:RemoveTag(Path.require(p.path), p.tag)
	return "Removed"
end

function Tools.GetTags(p)
	return Services.CollectionService:GetTags(Path.require(p.path))
end

function Tools.GetTagged(p)
	local paths = {}
	for _, obj in pairs(Services.CollectionService:GetTagged(p.tag)) do
		table.insert(paths, obj:GetFullName())
	end
	return paths
end

return Tools
