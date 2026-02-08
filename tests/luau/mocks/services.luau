--!strict
--------------------------------------------------------------------------------
-- Mock Services
-- Stub Roblox services for testing
--------------------------------------------------------------------------------

local roblox = require("@lune/roblox")
local serde = require("@lune/serde")

local MockServices = {}

--- Create a mock Services table matching utils/services.lua shape
function MockServices.create(): { [string]: any }
	-- Track calls for assertions
	local waypointLog: { string } = {}
	local undoCount = 0
	local redoCount = 0

	local services = {
		ChangeHistoryService = {
			SetWaypoint = function(_self: any, name: string)
				table.insert(waypointLog, name)
			end,
			Undo = function()
				undoCount += 1
			end,
			Redo = function()
				redoCount += 1
			end,
		},
		HttpService = {
			JSONEncode = function(_self: any, data: any): string
				return serde.encode("json", data)
			end,
			JSONDecode = function(_self: any, json: string): any
				return serde.decode("json", json)
			end,
		},
		TweenService = {
			Create = function(_self: any, _instance: any, _tweenInfo: any, _props: any)
				return {
					Play = function() end,
					Cancel = function() end,
					Destroy = function() end,
				}
			end,
		},
		RunService = {
			IsRunning = function() return false end,
			IsRunMode = function() return false end,
			IsStudio = function() return true end,
			IsEdit = function() return true end,
		},
		CollectionService = {},
		DataStoreService = {},
		Debris = {},
		InsertService = {},
		Lighting = roblox.Instance.new("DataModel"):GetService("Lighting"),
		MarketplaceService = {},
		PathfindingService = {},
		Players = {},
		Selection = {
			Get = function() return {} end,
			Set = function() end,
		},
		SoundService = {},
		Teams = {},
		TextChatService = {},
	}

	-- Expose test helpers
	services._test = {
		getWaypointLog = function(): { string }
			return waypointLog
		end,
		clearWaypointLog = function()
			table.clear(waypointLog)
		end,
		getUndoCount = function(): number
			return undoCount
		end,
		getRedoCount = function(): number
			return redoCount
		end,
		reset = function()
			table.clear(waypointLog)
			undoCount = 0
			redoCount = 0
		end,
	}

	return services
end

return MockServices
