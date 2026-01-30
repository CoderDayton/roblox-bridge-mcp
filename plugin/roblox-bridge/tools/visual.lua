-- Appearance, lighting, particles, materials, and GUI tools
local Services = require(script.Parent.Parent.utils.services)
local Path = require(script.Parent.Parent.utils.path)

local Tools = {}

-- Appearance
function Tools.SetColor(p)
	local obj = Path.require(p.path)
	local color = Color3.fromRGB(p.r, p.g, p.b)
	if obj:IsA("BasePart") or obj:IsA("Light") then obj.Color = color
	else error("Cannot set color: unsupported type") end
	return "Set"
end

function Tools.SetTransparency(p)
	local obj = Path.require(p.path)
	if obj:IsA("BasePart") or obj:IsA("GuiObject") then obj.Transparency = p.value
	else error("Cannot set transparency") end
	return "Set"
end

function Tools.SetMaterial(p)
	local material = Enum.Material[p.material]
	if not material then error("Invalid material: " .. p.material) end
	Path.requireBasePart(p.path).Material = material
	return "Set"
end

-- Lighting
function Tools.SetTimeOfDay(p)
	Services.Lighting.TimeOfDay = p.time
	return "Set"
end

function Tools.SetBrightness(p)
	Services.Lighting.Brightness = p.brightness
	return "Set"
end

function Tools.SetAtmosphereDensity(p)
	local atmo = Services.Lighting:FindFirstChildOfClass("Atmosphere")
	if not atmo then
		atmo = Instance.new("Atmosphere")
		atmo.Parent = Services.Lighting
	end
	atmo.Density = p.density
	return "Set"
end

function Tools.CreateLight(p)
	local parent = Path.require(p.parentPath)
	local light = Instance.new(p.type)
	if p.brightness then light.Brightness = p.brightness end
	if p.color then light.Color = Color3.fromRGB(p.color[1], p.color[2], p.color[3]) end
	light.Parent = parent
	return light:GetFullName()
end

-- Environment
function Tools.SetAtmosphereColor(p)
	local atmo = Services.Lighting:FindFirstChildOfClass("Atmosphere")
	if not atmo then
		atmo = Instance.new("Atmosphere")
		atmo.Parent = Services.Lighting
	end
	atmo.Color = Color3.fromRGB(p.r, p.g, p.b)
	if p.haze then atmo.Haze = p.haze end
	return "Set"
end

function Tools.SetGlobalShadows(p)
	Services.Lighting.GlobalShadows = p.enabled
	return "Set"
end

function Tools.SetFog(p)
	Services.Lighting.FogStart = p.start or 0
	Services.Lighting.FogEnd = p.fogEnd or 100000
	if p.color then
		Services.Lighting.FogColor = Color3.fromRGB(p.color[1], p.color[2], p.color[3])
	end
	return "Set"
end

function Tools.CreateClouds(p)
	local existing = workspace:FindFirstChildOfClass("Clouds")
	if existing then existing:Destroy() end
	local clouds = Instance.new("Clouds")
	if p.cover then clouds.Cover = p.cover end
	if p.density then clouds.Density = p.density end
	if p.color then clouds.Color = Color3.fromRGB(p.color[1], p.color[2], p.color[3]) end
	clouds.Parent = workspace.Terrain
	return clouds:GetFullName()
end

function Tools.SetSkybox(p)
	local sky = Services.Lighting:FindFirstChildOfClass("Sky")
	if not sky then
		sky = Instance.new("Sky")
		sky.Parent = Services.Lighting
	end
	if p.skyboxBk then sky.SkyboxBk = "rbxassetid://" .. tostring(p.skyboxBk) end
	if p.skyboxDn then sky.SkyboxDn = "rbxassetid://" .. tostring(p.skyboxDn) end
	if p.skyboxFt then sky.SkyboxFt = "rbxassetid://" .. tostring(p.skyboxFt) end
	if p.skyboxLf then sky.SkyboxLf = "rbxassetid://" .. tostring(p.skyboxLf) end
	if p.skyboxRt then sky.SkyboxRt = "rbxassetid://" .. tostring(p.skyboxRt) end
	if p.skyboxUp then sky.SkyboxUp = "rbxassetid://" .. tostring(p.skyboxUp) end
	if p.sunTextureId then sky.SunTextureId = "rbxassetid://" .. tostring(p.sunTextureId) end
	if p.moonTextureId then sky.MoonTextureId = "rbxassetid://" .. tostring(p.moonTextureId) end
	return sky:GetFullName()
end

function Tools.CreateBeam(p)
	local att0 = Path.require(p.attachment0Path)
	local att1 = Path.require(p.attachment1Path)
	if not att0:IsA("Attachment") or not att1:IsA("Attachment") then
		error("Both paths must be Attachments")
	end
	local beam = Instance.new("Beam")
	beam.Attachment0, beam.Attachment1 = att0, att1
	if p.color then beam.Color = ColorSequence.new(Color3.fromRGB(p.color[1], p.color[2], p.color[3])) end
	if p.width0 then beam.Width0 = p.width0 end
	if p.width1 then beam.Width1 = p.width1 end
	if p.segments then beam.Segments = p.segments end
	beam.Parent = att0.Parent
	return beam:GetFullName()
end

function Tools.CreateTrail(p)
	local att0 = Path.require(p.attachment0Path)
	local att1 = Path.require(p.attachment1Path)
	if not att0:IsA("Attachment") or not att1:IsA("Attachment") then
		error("Both paths must be Attachments")
	end
	local trail = Instance.new("Trail")
	trail.Attachment0, trail.Attachment1 = att0, att1
	if p.lifetime then trail.Lifetime = p.lifetime end
	if p.color then trail.Color = ColorSequence.new(Color3.fromRGB(p.color[1], p.color[2], p.color[3])) end
	if p.widthScale then trail.WidthScale = NumberSequence.new(p.widthScale) end
	trail.Parent = att0.Parent
	return trail:GetFullName()
end

function Tools.HighlightObject(p)
	local obj = Path.require(p.path)
	local hl = Instance.new("Highlight")
	if p.color then
		hl.FillColor = Color3.fromRGB(p.color[1], p.color[2], p.color[3])
	end
	hl.Parent = obj
	if p.duration then Services.Debris:AddItem(hl, p.duration) end
	return hl:GetFullName()
end

-- Particles
function Tools.CreateParticleEmitter(p)
	local parent = Path.requireBasePart(p.parentPath)
	local emitter = Instance.new("ParticleEmitter")
	if p.properties then
		for k, v in pairs(p.properties) do pcall(function() emitter[k] = v end) end
	end
	emitter.Parent = parent
	return emitter:GetFullName()
end

function Tools.EmitParticles(p)
	local obj = Path.require(p.path)
	local emitter = obj:IsA("ParticleEmitter") and obj or obj:FindFirstChildOfClass("ParticleEmitter")
	if not emitter then error("No ParticleEmitter found") end
	emitter:Emit(p.count or 10)
	return "Emitted"
end

-- Materials (Decals & Textures)
function Tools.ApplyDecal(p)
	local parent = Path.requireBasePart(p.parentPath)
	local decal = Instance.new("Decal")
	decal.Texture = "rbxassetid://" .. tostring(p.textureId)
	if p.face then decal.Face = Enum.NormalId[p.face] or Enum.NormalId.Front end
	decal.Parent = parent
	return decal:GetFullName()
end

function Tools.ApplyTexture(p)
	local parent = Path.requireBasePart(p.parentPath)
	local texture = Instance.new("Texture")
	texture.Texture = "rbxassetid://" .. tostring(p.textureId)
	if p.face then texture.Face = Enum.NormalId[p.face] or Enum.NormalId.Front end
	texture.Parent = parent
	return texture:GetFullName()
end

-- GUI
function Tools.CreateGuiElement(p)
	local parent = Path.require(p.parentPath or "game.StarterGui")
	local gui = Instance.new(p.className)
	if p.name then gui.Name = p.name end
	if p.properties then
		for k, v in pairs(p.properties) do pcall(function() gui[k] = v end) end
	end
	gui.Parent = parent
	return gui:GetFullName()
end

function Tools.SetGuiText(p)
	local obj = Path.require(p.path)
	if obj:IsA("TextLabel") or obj:IsA("TextButton") or obj:IsA("TextBox") then
		obj.Text = p.text
	else error("Not a text GUI element") end
	return "Set"
end

function Tools.SetGuiSize(p)
	Path.requireGuiObject(p.path).Size = UDim2.new(
		p.scaleX or 0, p.offsetX or 0,
		p.scaleY or 0, p.offsetY or 0
	)
	return "Set"
end

function Tools.SetGuiPosition(p)
	Path.requireGuiObject(p.path).Position = UDim2.new(
		p.scaleX or 0, p.offsetX or 0,
		p.scaleY or 0, p.offsetY or 0
	)
	return "Set"
end

function Tools.SetGuiVisible(p)
	Path.requireGuiObject(p.path).Visible = p.visible
	return "Set"
end

function Tools.DestroyGuiElement(p)
	Path.require(p.path):Destroy()
	return "Destroyed"
end

return Tools
