-- Script creation, source manipulation, and console execution
local Services = require(script.Parent.Parent.utils.services)
local Path = require(script.Parent.Parent.utils.path)
local Sandbox = require(script.Parent.Parent.utils.sandbox)

local Tools = {}

-- Script Creation
function Tools.CreateScript(p)
	local parent = Path.require(p.parentPath or "game.ServerScriptService")
	local script = Instance.new(p.type or "Script")
	script.Name = p.name or "Script"
	if p.source then script.Source = p.source end
	script.Parent = parent
	return script:GetFullName()
end

-- Script Source
function Tools.GetScriptSource(p)
	return Path.requireScript(p.path).Source
end

function Tools.SetScriptSource(p)
	Path.requireScript(p.path).Source = p.source
	return "Set"
end

-- Console Execution
function Tools.RunConsoleCommand(p)
	return Sandbox.execute(p.code)
end

return Tools
