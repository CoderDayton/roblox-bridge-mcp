--!optimize 2
-- Reactive Store for UI State Management

local pairs = pairs
local ipairs = ipairs
local next = next
local table_insert = table.insert
local table_remove = table.remove

local Store = {}

function Store.create(initialState)
	local state = {}
	local listeners = {}

	for key, value in pairs(initialState) do
		state[key] = value
	end

	local store = {}

	function store:get(key)
		return state[key]
	end

	function store:getState()
		local copy = {}
		for k, v in pairs(state) do copy[k] = v end
		return copy
	end

	function store:set(updates)
		local changed = {}
		for key, value in pairs(updates) do
			if state[key] ~= value then
				state[key] = value
				changed[key] = value
			end
		end
		if next(changed) then
			for _, listener in ipairs(listeners) do
				listener(changed, state)
			end
		end
	end

	function store:subscribe(listener)
		table_insert(listeners, listener)
		return function()
			for i, l in ipairs(listeners) do
				if l == listener then
					table_remove(listeners, i)
					break
				end
			end
		end
	end

	--------------------------------------------------------------------------------
	-- Cleanup all listeners to prevent memory leaks
	-- Call when the store is no longer needed
	--------------------------------------------------------------------------------
	function store:cleanup()
		listeners = {}
	end

	return store
end

return Store
