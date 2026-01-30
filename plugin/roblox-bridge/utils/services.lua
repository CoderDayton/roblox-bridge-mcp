--!optimize 2
-- Cached service references (pre-loaded at module init for performance)
local game_GetService = game.GetService
return {
	ChangeHistoryService = game:GetService("ChangeHistoryService"),
	CollectionService = game:GetService("CollectionService"),
	DataStoreService = game:GetService("DataStoreService"),
	Debris = game:GetService("Debris"),
	HttpService = game:GetService("HttpService"),
	InsertService = game:GetService("InsertService"),
	Lighting = game:GetService("Lighting"),
	MarketplaceService = game:GetService("MarketplaceService"),
	PathfindingService = game:GetService("PathfindingService"),
	Players = game:GetService("Players"),
	RunService = game:GetService("RunService"),
	Selection = game:GetService("Selection"),
	SoundService = game:GetService("SoundService"),
	Teams = game:GetService("Teams"),
	TextChatService = game:GetService("TextChatService"),
	TweenService = game:GetService("TweenService"),
}
