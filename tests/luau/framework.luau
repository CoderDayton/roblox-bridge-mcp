--!strict
--------------------------------------------------------------------------------
-- Minimal BDD Test Framework for Lune
-- describe/it/expect with matchers, structured results
--------------------------------------------------------------------------------

local process = require("@lune/process")

export type TestResult = {
	name: string,
	passed: boolean,
	error: string?,
}

export type SuiteResult = {
	name: string,
	tests: { TestResult },
	children: { SuiteResult },
	passed: number,
	failed: number,
}

local Framework = {}

local suiteStack: { SuiteResult } = {}
local currentSuite: SuiteResult? = nil

local function pushSuite(name: string): SuiteResult
	local suite: SuiteResult = {
		name = name,
		tests = {},
		children = {},
		passed = 0,
		failed = 0,
	}
	if currentSuite then
		table.insert(currentSuite.children, suite)
	end
	table.insert(suiteStack, suite)
	currentSuite = suite
	return suite
end

local function popSuite()
	table.remove(suiteStack)
	currentSuite = suiteStack[#suiteStack]
end

function Framework.describe(name: string, fn: () -> ())
	local suite = pushSuite(name)
	local ok, err = pcall(fn)
	if not ok then
		table.insert(suite.tests, {
			name = "[describe setup error]",
			passed = false,
			error = tostring(err),
		})
		suite.failed += 1
	end
	popSuite()
end

function Framework.it(name: string, fn: () -> ())
	assert(currentSuite, "it() must be called inside describe()")
	local ok, err = pcall(fn)
	local result: TestResult = {
		name = name,
		passed = ok,
		error = if ok then nil else tostring(err),
	}
	table.insert(currentSuite.tests, result)
	if ok then
		currentSuite.passed += 1
	else
		currentSuite.failed += 1
	end
end

-- Expect chain builder
type ExpectChain = {
	to: ExpectTo,
	never: { to: ExpectTo },
}

type ExpectTo = {
	equal: (self: ExpectTo, expected: any) -> (),
	be: {
		ok: (self: any) -> (),
		a: (self: any, typeName: string) -> (),
		truthy: (self: any) -> (),
		falsy: (self: any) -> (),
		greaterThan: (self: any, n: number) -> (),
		lessThan: (self: any, n: number) -> (),
		nil_: (self: any) -> (),
	},
	throw: (self: ExpectTo) -> (),
	contain: (self: ExpectTo, item: any) -> (),
}

function Framework.expect(value: any): any
	local function makeChain(negate: boolean)
		local chain = {}

		local function check(condition: boolean, msg: string)
			if negate then condition = not condition end
			if not condition then
				error(msg, 3)
			end
		end

		chain.equal = function(expected: any)
			check(value == expected,
				`Expected {tostring(value)} {if negate then "not " else ""}to equal {tostring(expected)}`)
		end

		chain.be = setmetatable({}, {
			__index = function(_, key)
				if key == "ok" or key == "truthy" then
					return function()
						check(value ~= nil and value ~= false,
							`Expected {tostring(value)} {if negate then "not " else ""}to be truthy`)
					end
				elseif key == "falsy" then
					return function()
						check(not value,
							`Expected {tostring(value)} {if negate then "not " else ""}to be falsy`)
					end
				elseif key == "a" then
					return function(typeName: string)
						check(type(value) == typeName,
							`Expected type '{type(value)}' {if negate then "not " else ""}to be '{typeName}'`)
					end
				elseif key == "greaterThan" then
					return function(n: number)
						check(value > n,
							`Expected {tostring(value)} {if negate then "not " else ""}to be > {tostring(n)}`)
					end
				elseif key == "lessThan" then
					return function(n: number)
						check(value < n,
							`Expected {tostring(value)} {if negate then "not " else ""}to be < {tostring(n)}`)
					end
				elseif key == "nil_" then
					return function()
						check(value == nil,
							`Expected {tostring(value)} {if negate then "not " else ""}to be nil`)
					end
				end
				return nil
			end,
		})

		chain.throw = function()
			assert(type(value) == "function", "expect().to.throw() requires a function")
			local ok, _ = pcall(value)
			check(not ok,
				`Expected function {if negate then "not " else ""}to throw`)
		end

		chain.contain = function(item: any)
			if type(value) == "string" then
				check(string.find(value, item, 1, true) ~= nil,
					`Expected string {if negate then "not " else ""}to contain '{item}'`)
			elseif type(value) == "table" then
				local found = false
				for _, v in value do
					if v == item then found = true; break end
				end
				check(found,
					`Expected table {if negate then "not " else ""}to contain {tostring(item)}`)
			else
				error("contain() requires a string or table")
			end
		end

		return chain
	end

	return {
		to = makeChain(false),
		never = { to = makeChain(true) },
	}
end

--------------------------------------------------------------------------------
-- Result Reporting
--------------------------------------------------------------------------------

local function countResults(suite: SuiteResult): (number, number)
	local passed = suite.passed
	local failed = suite.failed
	for _, child in suite.children do
		local cp, cf = countResults(child)
		passed += cp
		failed += cf
	end
	return passed, failed
end

local function printResults(suite: SuiteResult, indent: number)
	local pad = string.rep("  ", indent)
	print(`{pad}{suite.name}`)

	for _, test in suite.tests do
		local icon = if test.passed then "✓" else "✗"
		local color = if test.passed then "\27[32m" else "\27[31m"
		print(`{pad}  {color}{icon}\27[0m {test.name}`)
		if test.error then
			print(`{pad}    \27[31m{test.error}\27[0m`)
		end
	end

	for _, child in suite.children do
		printResults(child, indent + 1)
	end
end

function Framework.runSuite(name: string, fn: () -> ()): SuiteResult
	local suite = pushSuite(name)
	local ok, err = pcall(fn)
	if not ok then
		table.insert(suite.tests, {
			name = "[suite error]",
			passed = false,
			error = tostring(err),
		})
		suite.failed += 1
	end
	popSuite()
	return suite
end

function Framework.report(suites: { SuiteResult }): boolean
	local totalPassed = 0
	local totalFailed = 0

	print("")
	for _, suite in suites do
		printResults(suite, 0)
		local p, f = countResults(suite)
		totalPassed += p
		totalFailed += f
	end

	print("")
	local color = if totalFailed > 0 then "\27[31m" else "\27[32m"
	print(`{color}{totalPassed} passed, {totalFailed} failed\27[0m`)
	print("")

	return totalFailed == 0
end

return Framework
