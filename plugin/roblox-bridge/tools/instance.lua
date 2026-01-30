-- Instance management, properties, hierarchy, and selection tools
local Services = require(script.Parent.Parent.utils.services)
local Path = require(script.Parent.Parent.utils.path)

local Tools = {}

-- Instance Management
function Tools.CreateInstance(p)
	local parent = Path.require(p.parentPath or "game.Workspace")
	local obj = Instance.new(p.className)
	obj.Name = p.name or p.className
	if p.properties then
		for k, v in pairs(p.properties) do pcall(function() obj[k] = v end) end
	end
	obj.Parent = parent
	return obj:GetFullName()
end

function Tools.DeleteInstance(p)
	Path.require(p.path):Destroy()
	return "Deleted"
end

function Tools.ClearAllChildren(p)
	Path.require(p.path):ClearAllChildren()
	return "Cleared"
end

function Tools.CloneInstance(p)
	local clone = Path.require(p.path):Clone()
	clone.Parent = p.parentPath and Path.resolve(p.parentPath) or nil
	return clone:GetFullName()
end

function Tools.RenameInstance(p)
	local obj = Path.require(p.path)
	obj.Name = p.newName
	return obj:GetFullName()
end

-- Discovery & Info
function Tools.GetFullName(p) return Path.require(p.path):GetFullName() end
function Tools.GetParent(p)
	local parent = Path.require(p.path).Parent
	return parent and parent:GetFullName() or nil
end
function Tools.IsA(p) return Path.require(p.path):IsA(p.className) end
function Tools.GetClassName(p) return Path.require(p.path).ClassName end

function Tools.WaitForChild(p)
	local child = Path.require(p.path):WaitForChild(p.name, p.timeout or 5)
	return child and child:GetFullName() or nil
end

function Tools.FindFirstAncestor(p)
	local obj = Path.require(p.path)
	local ancestor = obj:FindFirstAncestor(p.name)
	return ancestor and ancestor:GetFullName() or nil
end

function Tools.FindFirstAncestorOfClass(p)
	local obj = Path.require(p.path)
	local ancestor = obj:FindFirstAncestorOfClass(p.className)
	return ancestor and ancestor:GetFullName() or nil
end

function Tools.FindFirstAncestorWhichIsA(p)
	local obj = Path.require(p.path)
	local ancestor = obj:FindFirstAncestorWhichIsA(p.className)
	return ancestor and ancestor:GetFullName() or nil
end

function Tools.FindFirstChildOfClass(p)
	local obj = Path.require(p.path)
	local child = obj:FindFirstChildOfClass(p.className)
	return child and child:GetFullName() or nil
end

function Tools.FindFirstChildWhichIsA(p)
	local obj = Path.require(p.path)
	local child = obj:FindFirstChildWhichIsA(p.className, p.recursive or false)
	return child and child:GetFullName() or nil
end

function Tools.FindFirstDescendant(p)
	local obj = Path.require(p.path)
	local desc = obj:FindFirstDescendant(p.name)
	return desc and desc:GetFullName() or nil
end

function Tools.GetDebugId(p)
	local obj = Path.require(p.path)
	return obj:GetDebugId()
end

-- Properties
function Tools.SetProperty(p)
	local obj = Path.require(p.path)
	obj[p.property] = p.value
	return tostring(obj[p.property])
end

function Tools.GetProperty(p) return Path.require(p.path)[p.property] end

-- Hierarchy
function Tools.GetChildren(p)
	local names = {}
	for _, child in pairs(Path.require(p.path):GetChildren()) do
		table.insert(names, child.Name)
	end
	return names
end

function Tools.GetDescendants(p)
	local paths = {}
	for _, desc in pairs(Path.require(p.path):GetDescendants()) do
		table.insert(paths, desc:GetFullName())
	end
	return paths
end

function Tools.GetDescendantCount(p)
	return #Path.require(p.path):GetDescendants()
end

function Tools.FindFirstChild(p)
	local child = Path.require(p.path):FindFirstChild(p.name, p.recursive or false)
	return child and child:GetFullName() or nil
end

function Tools.GetService(p)
	local ok, service = pcall(game.GetService, game, p.service)
	return ok and service and service.Name or "NotFound"
end

function Tools.GetAncestors(p)
	local obj = Path.require(p.path)
	local ancestors = {}
	local current = obj.Parent
	while current do
		table.insert(ancestors, current:GetFullName())
		current = current.Parent
	end
	return ancestors
end

-- Selection
function Tools.GetSelection()
	local paths = {}
	for _, obj in pairs(Services.Selection:Get()) do
		table.insert(paths, obj:GetFullName())
	end
	return paths
end

function Tools.SetSelection(p)
	local objs = {}
	for _, path in pairs(p.paths) do
		local obj = Path.resolve(path)
		if obj then table.insert(objs, obj) end
	end
	Services.Selection:Set(objs)
	return "Set"
end

function Tools.ClearSelection()
	Services.Selection:Set({})
	return "Cleared"
end

function Tools.AddToSelection(p)
	local current = Services.Selection:Get()
	for _, path in pairs(p.paths) do
		local obj = Path.resolve(path)
		if obj then table.insert(current, obj) end
	end
	Services.Selection:Set(current)
	return "Added"
end

function Tools.GroupSelection(p)
	local sel = Services.Selection:Get()
	if #sel == 0 then error("Nothing selected") end
	local model = Instance.new("Model")
	model.Name = p.name
	model.Parent = sel[1].Parent
	for _, obj in pairs(sel) do obj.Parent = model end
	Services.Selection:Set({ model })
	return model:GetFullName()
end

function Tools.UngroupModel(p)
	local model = Path.require(p.path)
	if not model:IsA("Model") then error("Not a Model: " .. p.path) end
	local parent = model.Parent
	for _, child in pairs(model:GetChildren()) do child.Parent = parent end
	model:Destroy()
	return "Ungrouped"
end

-- Model Methods
function Tools.GetBoundingBox(p)
	local obj = Path.require(p.path)
	if not obj:IsA("Model") then error("Not a Model: " .. p.path) end
	local cf, size = obj:GetBoundingBox()
	return {
		cframe = { cf:GetComponents() },
		size = { size.X, size.Y, size.Z },
	}
end

function Tools.GetExtentsSize(p)
	local obj = Path.require(p.path)
	if not obj:IsA("Model") then error("Not a Model: " .. p.path) end
	local size = obj:GetExtentsSize()
	return { size.X, size.Y, size.Z }
end

function Tools.ScaleTo(p)
	local obj = Path.require(p.path)
	if not obj:IsA("Model") then error("Not a Model: " .. p.path) end
	obj:ScaleTo(p.scale)
	return "Scaled"
end

function Tools.GetScale(p)
	local obj = Path.require(p.path)
	if not obj:IsA("Model") then error("Not a Model: " .. p.path) end
	return obj:GetScale()
end

function Tools.TranslateBy(p)
	local obj = Path.require(p.path)
	if not obj:IsA("Model") then error("Not a Model: " .. p.path) end
	obj:TranslateBy(Vector3.new(p.offset[1], p.offset[2], p.offset[3]))
	return "Translated"
end

-- Model Primary Part
function Tools.SetPrimaryPart(p)
	local model = Path.require(p.path)
	if not model:IsA("Model") then error("Not a Model: " .. p.path) end
	local primaryPart = Path.requireBasePart(p.primaryPartPath)
	model.PrimaryPart = primaryPart
	return "Set"
end

function Tools.GetPrimaryPart(p)
	local model = Path.require(p.path)
	if not model:IsA("Model") then error("Not a Model: " .. p.path) end
	return model.PrimaryPart and model.PrimaryPart:GetFullName() or nil
end

return Tools
