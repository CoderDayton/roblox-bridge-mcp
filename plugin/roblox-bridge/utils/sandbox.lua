-- Sandboxed execution environment
local Sandbox = {}

function Sandbox.createEnv(logs)
	return {
		game = game, workspace = workspace, Workspace = workspace, script = script,
		Instance = Instance, Vector3 = Vector3, Vector2 = Vector2, Color3 = Color3,
		CFrame = CFrame, UDim2 = UDim2, UDim = UDim, Enum = Enum, Ray = Ray,
		Region3 = Region3, BrickColor = BrickColor, NumberRange = NumberRange,
		NumberSequence = NumberSequence, ColorSequence = ColorSequence,
		print = function(...)
			local parts = {}
			for i = 1, select("#", ...) do parts[i] = tostring(select(i, ...)) end
			table.insert(logs, table.concat(parts, " "))
			print(...)
		end,
		warn = function(...)
			local parts = {}
			for i = 1, select("#", ...) do parts[i] = tostring(select(i, ...)) end
			table.insert(logs, "WARN: " .. table.concat(parts, " "))
			warn(...)
		end,
		error = error, assert = assert, type = type, typeof = typeof,
		tonumber = tonumber, tostring = tostring, pairs = pairs, ipairs = ipairs,
		next = next, select = select, unpack = unpack, pcall = pcall, xpcall = xpcall,
		math = math, string = string, table = table, coroutine = coroutine,
		os = { time = os.time, clock = os.clock, date = os.date, difftime = os.difftime },
		task = task, wait = wait, delay = delay, spawn = spawn,
	}
end

function Sandbox.execute(code)
	local func, compileErr = loadstring(code)
	if not func then error("Compile error: " .. tostring(compileErr)) end

	local logs = {}
	setfenv(func, Sandbox.createEnv(logs))

	local results = { pcall(func) }
	local success = table.remove(results, 1)
	local output = table.concat(logs, "\n")

	if not success then
		error(output .. "\nRuntime error: " .. tostring(results[1]))
	end

	local returnStr = ""
	if #results > 0 then
		local strResults = {}
		for _, v in pairs(results) do table.insert(strResults, tostring(v)) end
		returnStr = "Returned: " .. table.concat(strResults, ", ")
	end

	if output == "" and returnStr == "" then return "Executed (no output)" end
	return output .. (output ~= "" and returnStr ~= "" and "\n" or "") .. returnStr
end

return Sandbox
