--!optimize 2
--------------------------------------------------------------------------------
-- Scripting Tools
-- Provides methods for script creation, source code manipulation, and execution.
-- Supports Script, LocalScript, and ModuleScript types.
--
-- Methods:
--   Creation: CreateScript (creates Script/LocalScript/ModuleScript)
--   Source: GetScriptSource, SetScriptSource, AppendToScript, ReplaceScriptLines, InsertScriptLines
--   Execution: RunConsoleCommand (sandboxed Lua execution)
--
-- Note: RunConsoleCommand executes in a sandboxed environment with limited API access.
--------------------------------------------------------------------------------

-- Localize globals for performance
local table_insert = table.insert
local table_concat = table.concat
local table_create = table.create
local string_split = string.split
local math_clamp = math.clamp
local ipairs = ipairs

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
	local lines = string_split(obj.Source, "\n")
	local contentLines = string_split(p.content, "\n")
	local startLine = p.startLine
	local endLine = p.endLine
	local numLines = #lines

	-- Estimate new size: (startLine-1) + contentLines + (numLines - endLine)
	local estimatedSize = (startLine - 1) + #contentLines + (numLines - endLine)
	local newLines = table_create(estimatedSize > 0 and estimatedSize or 1)
	local idx = 0

	for i = 1, startLine - 1 do
		if lines[i] then
			idx = idx + 1
			newLines[idx] = lines[i]
		end
	end
	for _, line in ipairs(contentLines) do
		idx = idx + 1
		newLines[idx] = line
	end
	for i = endLine + 1, numLines do
		idx = idx + 1
		newLines[idx] = lines[i]
	end
	obj.Source = table_concat(newLines, "\n")
	return "Replaced"
end

function Tools.InsertScriptLines(p)
	local obj = Path.requireScript(p.path)
	local lines = string_split(obj.Source, "\n")
	local contentLines = string_split(p.content, "\n")
	local numLines = #lines
	local insertAt = math_clamp(p.lineNumber, 1, numLines + 1)

	local newLines = table_create(numLines + #contentLines)
	local idx = 0

	for i = 1, insertAt - 1 do
		idx = idx + 1
		newLines[idx] = lines[i]
	end
	for _, line in ipairs(contentLines) do
		idx = idx + 1
		newLines[idx] = line
	end
	for i = insertAt, numLines do
		idx = idx + 1
		newLines[idx] = lines[i]
	end
	obj.Source = table_concat(newLines, "\n")
	return "Inserted"
end

-- Console Execution
function Tools.RunConsoleCommand(p)
	return Sandbox.execute(p.code)
end

return Tools
