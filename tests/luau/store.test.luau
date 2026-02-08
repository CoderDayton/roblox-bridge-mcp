--!strict
--------------------------------------------------------------------------------
-- Tests: ui/store.lua — Reactive state management
--------------------------------------------------------------------------------

local process = require("@lune/process")
local Framework = require("./framework")
local Loader = require("./loader")

local describe = Framework.describe
local it = Framework.it
local expect = Framework.expect

local STORE_PATH = "plugin/roblox-bridge/ui/store.lua"

-- Load the actual Store module (no Roblox deps, pure logic)
local Store = Loader.load(STORE_PATH, {
	mocks = {
		-- store.lua has no requires, but loader needs script.Parent
	},
})

local suite = Framework.runSuite("Store", function()
	describe("create", function()
		it("returns a store object with expected API", function()
			local store = Store.create({ count = 0 })
			expect(type(store.get)).to.equal("function")
			expect(type(store.getState)).to.equal("function")
			expect(type(store.set)).to.equal("function")
			expect(type(store.subscribe)).to.equal("function")
			expect(type(store.cleanup)).to.equal("function")
		end)
	end)

	describe("get", function()
		it("returns initial values", function()
			local store = Store.create({ name = "test", count = 42 })
			expect(store:get("name")).to.equal("test")
			expect(store:get("count")).to.equal(42)
		end)

		it("returns nil for unknown keys", function()
			local store = Store.create({ x = 1 })
			expect(store:get("missing")).to.be.nil_()
		end)
	end)

	describe("getState", function()
		it("returns a copy of the full state", function()
			local store = Store.create({ a = 1, b = 2 })
			local state = store:getState()
			expect(state.a).to.equal(1)
			expect(state.b).to.equal(2)
		end)

		it("returns a copy, not a reference", function()
			local store = Store.create({ x = 10 })
			local state = store:getState()
			state.x = 999
			expect(store:get("x")).to.equal(10)
		end)
	end)

	describe("set", function()
		it("updates state values", function()
			local store = Store.create({ count = 0 })
			store:set({ count = 5 })
			expect(store:get("count")).to.equal(5)
		end)

		it("can update multiple keys at once", function()
			local store = Store.create({ a = 1, b = 2 })
			store:set({ a = 10, b = 20 })
			expect(store:get("a")).to.equal(10)
			expect(store:get("b")).to.equal(20)
		end)

		it("only triggers listeners when values actually change", function()
			local store = Store.create({ x = 5 })
			local callCount = 0
			store:subscribe(function()
				callCount += 1
			end)

			store:set({ x = 5 }) -- Same value
			expect(callCount).to.equal(0)

			store:set({ x = 6 }) -- Different value
			expect(callCount).to.equal(1)
		end)

		it("passes changed keys and full state to listeners", function()
			local store = Store.create({ a = 1, b = 2 })
			local receivedChanged = nil
			local receivedState = nil

			store:subscribe(function(changed, state)
				receivedChanged = changed
				receivedState = state
			end)

			store:set({ a = 10 })
			expect(receivedChanged).to.be.ok()
			expect(receivedChanged.a).to.equal(10)
			expect(receivedChanged.b).to.be.nil_()
			expect(receivedState.a).to.equal(10)
			expect(receivedState.b).to.equal(2)
		end)
	end)

	describe("subscribe", function()
		it("returns an unsubscribe function", function()
			local store = Store.create({ x = 0 })
			local callCount = 0

			local unsub = store:subscribe(function()
				callCount += 1
			end)

			store:set({ x = 1 })
			expect(callCount).to.equal(1)

			unsub()
			store:set({ x = 2 })
			expect(callCount).to.equal(1) -- No longer called
		end)

		it("supports multiple listeners", function()
			local store = Store.create({ x = 0 })
			local calls = { 0, 0 }

			store:subscribe(function() calls[1] += 1 end)
			store:subscribe(function() calls[2] += 1 end)

			store:set({ x = 1 })
			expect(calls[1]).to.equal(1)
			expect(calls[2]).to.equal(1)
		end)

		it("fires listeners in order", function()
			local store = Store.create({ x = 0 })
			local order: { number } = {}

			store:subscribe(function() table.insert(order, 1) end)
			store:subscribe(function() table.insert(order, 2) end)
			store:subscribe(function() table.insert(order, 3) end)

			store:set({ x = 1 })
			expect(order[1]).to.equal(1)
			expect(order[2]).to.equal(2)
			expect(order[3]).to.equal(3)
		end)
	end)

	describe("cleanup", function()
		it("removes all listeners", function()
			local store = Store.create({ x = 0 })
			local callCount = 0

			store:subscribe(function() callCount += 1 end)
			store:subscribe(function() callCount += 1 end)

			store:set({ x = 1 })
			expect(callCount).to.equal(2)

			store:cleanup()
			store:set({ x = 2 })
			expect(callCount).to.equal(2) -- No new calls
		end)
	end)
end)

local allPassed = Framework.report({ suite })
if not allPassed then
	process.exit(1)
end
