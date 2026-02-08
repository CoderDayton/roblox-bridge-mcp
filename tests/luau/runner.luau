--!strict
--------------------------------------------------------------------------------
-- Test Runner
-- Discovers and runs *.test.luau files, reports results, exits with code
--------------------------------------------------------------------------------

local fs = require("@lune/fs")
local process = require("@lune/process")

local TEST_DIR = "tests/luau"
local TEST_SUFFIX = ".test.luau"

-- Collect test files
local testFiles: { string } = {}
for _, entry in fs.readDir(TEST_DIR) do
	if string.sub(entry, -#TEST_SUFFIX) == TEST_SUFFIX then
		table.insert(testFiles, `{TEST_DIR}/{entry}`)
	end
end

table.sort(testFiles)

if #testFiles == 0 then
	print("No test files found in " .. TEST_DIR)
	process.exit(1)
end

print(`\27[1mRunning {#testFiles} Luau test file(s)\27[0m\n`)

-- Run each test file as a subprocess
local totalPassed = 0
local totalFailed = 0
local failedFiles: { string } = {}

for _, file in testFiles do
	local result = process.exec("lune", { "run", file })

	-- Print the output
	if result.stdout ~= "" then
		print(result.stdout)
	end
	if result.stderr ~= "" then
		print(result.stderr)
	end

	if result.ok then
		-- Parse pass/fail counts from output
		local passCount = string.match(result.stdout, "(%d+) passed")
		local failCount = string.match(result.stdout, "(%d+) failed")
		totalPassed += tonumber(passCount) or 0
		totalFailed += tonumber(failCount) or 0
	else
		table.insert(failedFiles, file)
		totalFailed += 1
	end
end

-- Summary
print(string.rep("─", 50))
if totalFailed > 0 then
	print(`\27[31m✗ {totalPassed} passed, {totalFailed} failed\27[0m`)
	if #failedFiles > 0 then
		print("\nFailed files:")
		for _, f in failedFiles do
			print(`  \27[31m{f}\27[0m`)
		end
	end
	process.exit(1)
else
	print(`\27[32m✓ {totalPassed} passed, 0 failed across {#testFiles} files\27[0m`)
end
