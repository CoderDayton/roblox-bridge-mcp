import { z } from "zod";
import type { FastMCP } from "fastmcp";
import { bridge } from "../utils/bridge";
import { config } from "../config";

/**
 * All supported Roblox Studio API methods
 * Methods are organized by category: Instance Management, Discovery, Properties,
 * Hierarchy, Transforms, Appearance, Physics, Scripting, Selection, Lighting,
 * Attributes/Tags, Players, Place, Audio, Terrain, Camera, Utilities, History
 */
const METHODS = [
  // Instance management
  "CreateInstance",
  "DeleteInstance",
  "CloneInstance",
  "RenameInstance",
  // Instance discovery & info
  "GetFullName",
  "GetParent",
  "IsA",
  "GetClassName",
  "WaitForChild",
  // Properties
  "SetProperty",
  "GetProperty",
  // Hierarchy
  "GetChildren",
  "GetDescendants",
  "FindFirstChild",
  "GetService",
  // Transforms
  "MoveTo",
  "SetPosition",
  "GetPosition",
  "SetRotation",
  "GetRotation",
  "SetSize",
  "GetSize",
  "PivotTo",
  "GetPivot",
  // Appearance
  "SetColor",
  "SetTransparency",
  "SetMaterial",
  // Physics
  "SetAnchored",
  "SetCanCollide",
  "CreateConstraint",
  "SetPhysicalProperties",
  "GetMass",
  // Scripting
  "CreateScript",
  "GetScriptSource",
  "SetScriptSource",
  "AppendToScript",
  "ReplaceScriptLines",
  "InsertScriptLines",
  "RunConsoleCommand",
  // Selection
  "GetSelection",
  "SetSelection",
  "ClearSelection",
  "AddToSelection",
  "GroupSelection",
  "UngroupModel",
  // Lighting
  "SetTimeOfDay",
  "SetBrightness",
  "SetAtmosphereDensity",
  "CreateLight",
  // Attributes & Tags
  "SetAttribute",
  "GetAttribute",
  "GetAttributes",
  "AddTag",
  "RemoveTag",
  "GetTags",
  "HasTag",
  // Players
  "GetPlayers",
  "GetPlayerPosition",
  "TeleportPlayer",
  "KickPlayer",
  // Place
  "SavePlace",
  "GetPlaceInfo",
  // Audio
  "PlaySound",
  "StopSound",
  // Terrain
  "FillTerrain",
  "ClearTerrain",
  // Camera
  "SetCameraPosition",
  "SetCameraFocus",
  "GetCameraPosition",
  // Utilities
  "GetDistance",
  "HighlightObject",
  "Chat",
  // History
  "Undo",
  "Redo",
] as const;

/**
 * Comprehensive description of all 99 Roblox Studio API methods
 * Format: MethodName(param1,param2?,param3?)
 * Optional params marked with ?, arrays marked with [], numeric ranges shown as min-max
 */
const DESCRIPTION = `Roblox Studio ops. method + params{}.
CreateInstance(className,parentPath,name?,properties?)
DeleteInstance(path)
CloneInstance(path,parentPath?)
RenameInstance(path,newName)
GetFullName(path)
GetParent(path)
IsA(path,className)
GetClassName(path)
WaitForChild(path,name,timeout?)
SetProperty(path,property,value)
GetProperty(path,property)
GetChildren(path)
GetDescendants(path)
FindFirstChild(path,name,recursive?)
GetService(service)
MoveTo(path,position[x,y,z])
SetPosition(path,x,y,z)
GetPosition(path)
SetRotation(path,x,y,z)
GetRotation(path)
SetSize(path,x,y,z)
GetSize(path)
PivotTo(path,cframe[12])
GetPivot(path)
SetColor(path,r,g,b)
SetTransparency(path,value:0-1)
SetMaterial(path,material)
SetAnchored(path,anchored)
SetCanCollide(path,canCollide)
CreateConstraint(type,attachment0Path,attachment1Path,properties?)
SetPhysicalProperties(path,density?,friction?,elasticity?)
GetMass(path)
CreateScript(name,parentPath,source,type?)
GetScriptSource(path)
SetScriptSource(path,source)
AppendToScript(path,code)
ReplaceScriptLines(path,startLine,endLine,content)
InsertScriptLines(path,lineNumber,content)
RunConsoleCommand(code)
GetSelection()
SetSelection(paths[])
ClearSelection()
AddToSelection(paths[])
GroupSelection(name)
UngroupModel(path)
SetTimeOfDay(time)
SetBrightness(brightness)
SetAtmosphereDensity(density)
CreateLight(parentPath,type,brightness?,color?)
SetAttribute(path,name,value)
GetAttribute(path,name)
GetAttributes(path)
AddTag(path,tag)
RemoveTag(path,tag)
GetTags(path)
HasTag(path,tag)
GetPlayers()
GetPlayerPosition(username)
TeleportPlayer(username,position[x,y,z])
KickPlayer(username,reason?)
SavePlace()
GetPlaceInfo()
PlaySound(soundId,parentPath?,volume?)
StopSound(path)
FillTerrain(material,minX,minY,minZ,maxX,maxY,maxZ)
ClearTerrain()
SetCameraPosition(x,y,z)
SetCameraFocus(path)
GetCameraPosition()
GetDistance(path1,path2)
HighlightObject(path,color?,duration?)
Chat(message,color?)
Undo()
Redo()`;

/**
 * Register all Roblox Studio tools with the FastMCP server
 * Registers a single 'roblox' tool that dispatches to 99 different methods
 * @param server - FastMCP server instance to register tools with
 */
export function registerAllTools(server: FastMCP): void {
  server.addTool({
    name: "roblox",
    description: DESCRIPTION,
    parameters: z.object({
      method: z.enum(METHODS),
      params: z.record(z.unknown()).default({}),
    }),
    /**
     * Execute a Roblox Studio command via the bridge
     * @param method - Roblox API method to invoke
     * @param params - Method parameters as key-value pairs
     * @returns Stringified JSON result from Roblox Studio
     */
    execute: async ({ method, params }) => {
      const result = await bridge.execute(method, params, config.retries);
      return typeof result === "string" ? result : JSON.stringify(result, null, 2);
    },
  });
}
