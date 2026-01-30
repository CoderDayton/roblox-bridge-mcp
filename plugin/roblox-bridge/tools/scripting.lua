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

function Tools.AppendToScript(p)
	local obj = Path.requireScript(p.path)
	obj.Source = obj.Source .. "\n" .. p.code
	return "Appended"
end

function Tools.ReplaceScriptLines(p)
	local obj = Path.requireScript(p.path)
	local lines = string.split(obj.Source, "\n")
	local newLines = {}
	local contentLines = string.split(p.content, "\n")
	for i = 1, p.startLine - 1 do if lines[i] then table.insert(newLines, lines[i]) end end
	for _, line in pairs(contentLines) do table.insert(newLines, line) end
	for i = p.endLine + 1, #lines do table.insert(newLines, lines[i]) end
	obj.Source = table.concat(newLines, "\n")
	return "Replaced"
end

function Tools.InsertScriptLines(p)
	local obj = Path.requireScript(p.path)
	local lines = string.split(obj.Source, "\n")
	local contentLines = string.split(p.content, "\n")
	local newLines = {}
	local insertAt = math.clamp(p.lineNumber, 1, #lines + 1)
	for i = 1, insertAt - 1 do table.insert(newLines, lines[i]) end
	for _, line in pairs(contentLines) do table.insert(newLines, line) end
	for i = insertAt, #lines do table.insert(newLines, lines[i]) end
	obj.Source = table.concat(newLines, "\n")
	return "Inserted"
end

-- Console Execution
function Tools.RunConsoleCommand(p)
	return Sandbox.execute(p.code)
end

return Tools
