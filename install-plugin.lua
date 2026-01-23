--------------------------------------------------------------------------------
-- Plugin Installer Script
-- Run this in Roblox Studio Command Bar to install the MCP Bridge plugin
--------------------------------------------------------------------------------

local function installPlugin()
	local pluginFolder = game:GetService("StudioService"):GetPluginsFolder()
	
	-- Remove old plugin if exists
	local oldPlugin = pluginFolder:FindFirstChild("Roblox Bridge MCP")
	if oldPlugin then
		oldPlugin:Destroy()
		print("Removed old plugin")
	end
	
	-- Create plugin folder
	local plugin = Instance.new("Script")
	plugin.Name = "Roblox Bridge MCP"
	plugin.Parent = pluginFolder
	
	-- Read main plugin file
	local HttpService = game:GetService("HttpService")
	local mainCode = HttpService:GetAsync("file:///C:/Users/Dayto/.projects/roblox-studio-mcp/plugin/loader.server.lua")
	plugin.Source = mainCode
	
	-- Create UI module folder
	local ui = Instance.new("ModuleScript")
	ui.Name = "ui"
	ui.Parent = plugin
	
	-- Load UI files
	local uiFiles = {
		"init",
		"button",
		"titlebar", 
		"statuspanel",
		"history",
		"settings"
	}
	
	for _, fileName in ipairs(uiFiles) do
		local filePath = string.format("file:///C:/Users/Dayto/.projects/roblox-studio-mcp/plugin/ui/%s.lua", fileName)
		local code = HttpService:GetAsync(filePath)
		
		local module = Instance.new("ModuleScript")
		module.Name = fileName
		module.Source = code
		module.Parent = ui
	end
	
	print("Plugin installed successfully!")
	print("Location:", plugin:GetFullName())
	print("Reload plugins to activate")
end

-- Run installer
local success, err = pcall(installPlugin)
if not success then
	warn("Installation failed:", err)
end
