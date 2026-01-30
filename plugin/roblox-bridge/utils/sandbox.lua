--!optimize 2
-- Sandboxed execution environment

-- Localize globals for performance
local table_insert = table.insert
local table_concat = table.concat
local table_remove = table.remove
local tostring = tostring
local select = select
local pcall = pcall
local setfenv = setfenv
local loadstring = loadstring

local Sandbox = {}

function Sandbox.createEnv(logs)
	return {
		game = game, workspace = workspace, Workspace = workspace, script = script,
		Instance = Instance, Vector3 = Vector3, Vector2 = Vector2, Color3 = Color3,
		CFrame = CFrame, UDim2 = UDim2, UDim = UDim, Enum = Enum, Ray = Ray,
		Region3 = Region3, BrickColor = BrickColor, NumberRange = NumberRange,
		NumberSequence = NumberSequence, ColorSequence = ColorSequence,
		print = function(...)
			local count = select("#", ...)
			local parts = table.create(count)
			for i = 1, count do parts[i] = tostring(select(i, ...)) end
			table_insert(logs, table_concat(parts, " "))
			print(...)
		end,
		warn = function(...)
			local count = select("#", ...)
			local parts = table.create(count)
			for i = 1, count do parts[i] = tostring(select(i, ...)) end
			table_insert(logs, "WARN: " .. table_concat(parts, " "))
			warn(...)
		end,
		error = error, assert = assert, type = type, typeof = typeof,
		tonumber = tonumber, tostring = tostring, pairs = pairs, ipairs = ipairs,
		next = next, select = select, unpack = unpack, pcall = pcall, xpcall = xpcall,
		math = math, string = string, table = table, coroutine = coroutine,
		os = { time = os.time, clock = os.clock, date = os.date, difftime = os.difftime },
		task = task, wait = task.wait, delay = task.delay, spawn = task.spawn,
	}
end

function Sandbox.execute(code)
	local func, compileErr = loadstring(code)
	if not func then error("Compile error: " .. tostring(compileErr)) end

	local logs = {}
	setfenv(func, Sandbox.createEnv(logs))

	local results = { pcall(func) }
	local success = table_remove(results, 1)
	local output = table_concat(logs, "\n")

	if not success then
		error(output .. "\nRuntime error: " .. tostring(results[1]))
	end

	local returnStr = ""
	local numResults = #results
	if numResults > 0 then
		local strResults = table.create(numResults)
		for i, v in ipairs(results) do strResults[i] = tostring(v) end
		returnStr = "Returned: " .. table_concat(strResults, ", ")
	end

	if output == "" and returnStr == "" then return "Executed (no output)" end
	return output .. (output ~= "" and returnStr ~= "" and "\n" or "") .. returnStr
end

return Sandbox
