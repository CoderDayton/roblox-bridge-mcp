#!/usr/bin/env bun
/**
 * Generates install-plugin.lua by bundling all plugin source files
 * Run: bun scripts/generate-installer.ts
 */

import { readFileSync, writeFileSync, readdirSync, statSync } from "fs";
import { join, relative, basename, dirname } from "path";

const PLUGIN_ROOT = join(import.meta.dir, "..", "plugin", "roblox-bridge");
const OUTPUT_PATH = join(import.meta.dir, "install-plugin.lua");

interface FileEntry {
  path: string;
  name: string;
  content: string;
  isScript: boolean;
}

function escapeForLua(content: string): string {
  // Use long string brackets with unique level to avoid conflicts
  // Find a level that doesn't appear in the content
  let level = 0;
  while (content.includes(`]${"=".repeat(level)}]`)) {
    level++;
  }
  const eq = "=".repeat(level);
  return `[${eq}[${content}]${eq}]`;
}

function collectFiles(dir: string, files: FileEntry[] = []): FileEntry[] {
  const entries = readdirSync(dir);

  for (const entry of entries) {
    const fullPath = join(dir, entry);
    const stat = statSync(fullPath);

    if (stat.isDirectory()) {
      collectFiles(fullPath, files);
    } else if (entry.endsWith(".lua")) {
      const content = readFileSync(fullPath, "utf-8");
      const relativePath = relative(PLUGIN_ROOT, fullPath);
      const name = basename(entry, ".lua");
      const isScript = entry.endsWith(".server.lua") || entry.endsWith(".client.lua");

      files.push({
        path: relativePath,
        name: isScript ? name.replace(/\.(server|client)$/, "") : name,
        content,
        isScript,
      });
    }
  }

  return files;
}

function generateInstaller(): string {
  const files = collectFiles(PLUGIN_ROOT);

  // Sort files by path depth (create parent folders first)
  files.sort((a, b) => {
    const depthA = a.path.split("/").length;
    const depthB = b.path.split("/").length;
    return depthA - depthB;
  });

  // Build the installer script
  let output = `--[[
MCP Bridge Plugin Installer
Paste this entire script into Roblox Studio's Command Bar and press Enter.
The plugin will be created in ServerStorage, then you can move it to your Plugins folder.

After running:
1. Find "roblox-bridge" in ServerStorage
2. Right-click -> Save to File -> Save as .rbxm
3. Move the .rbxm file to your Roblox Plugins folder:
   - Windows: %LOCALAPPDATA%\\Roblox\\Plugins
   - Mac: ~/Documents/Roblox/Plugins
4. Restart Studio
]]

local ServerStorage = game:GetService("ServerStorage")

-- Remove existing if present
local existing = ServerStorage:FindFirstChild("roblox-bridge")
if existing then existing:Destroy() end

-- Create root folder
local root = Instance.new("Folder")
root.Name = "roblox-bridge"

-- Helper to create ModuleScript
local function createModule(name, parent, source)
	local mod = Instance.new("ModuleScript")
	mod.Name = name
	mod.Source = source
	mod.Parent = parent
	return mod
end

-- Helper to create Script (server script)
local function createScript(name, parent, source)
	local scr = Instance.new("Script")
	scr.Name = name
	scr.Source = source
	scr.Parent = parent
	return scr
end

-- Helper to get or create folder
local folders = { [""] = root }
local function getFolder(path)
	if folders[path] then return folders[path] end

	local parentPath = path:match("(.+)/[^/]+$") or ""
	local folderName = path:match("([^/]+)$")
	local parent = getFolder(parentPath)

	local folder = Instance.new("Folder")
	folder.Name = folderName
	folder.Parent = parent
	folders[path] = folder
	return folder
end

`;

  // Group files by directory
  const dirs = new Set<string>();
  for (const file of files) {
    const dir = dirname(file.path);
    if (dir !== ".") {
      dirs.add(dir);
    }
  }

  // Create folders
  const sortedDirs = Array.from(dirs).sort();
  if (sortedDirs.length > 0) {
    output += `-- Create folder structure\n`;
    for (const dir of sortedDirs) {
      output += `getFolder("${dir}")\n`;
    }
    output += `\n`;
  }

  output += `--------------------------------------------------------------------------------\n`;
  output += `-- FILES\n`;
  output += `--------------------------------------------------------------------------------\n\n`;

  // Create files
  for (const file of files) {
    const dir = dirname(file.path);
    const parent = dir === "." ? "root" : `folders["${dir}"]`;
    const createFn = file.isScript ? "createScript" : "createModule";
    const escapedContent = escapeForLua(file.content);

    output += `${createFn}("${file.name}", ${parent}, ${escapedContent})\n\n`;
  }

  // Final setup
  output += `--------------------------------------------------------------------------------
-- FINALIZE
--------------------------------------------------------------------------------

root.Parent = ServerStorage
print("✅ MCP Bridge plugin installed to ServerStorage.roblox-bridge")
print("→ Right-click it and 'Save to File' as .rbxm")
print("→ Move to your Plugins folder and restart Studio")
`;

  return output;
}

// Generate and write
const installer = generateInstaller();
writeFileSync(OUTPUT_PATH, installer);

const stats = {
  files: collectFiles(PLUGIN_ROOT).length,
  size: (installer.length / 1024).toFixed(1),
};

console.log(`✅ Generated ${OUTPUT_PATH}`);
console.log(`   ${stats.files} files, ${stats.size} KB`);
