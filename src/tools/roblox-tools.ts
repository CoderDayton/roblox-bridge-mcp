import { z } from "zod";
import type { FastMCP } from "fastmcp";
import { bridge } from "../utils/bridge";

const METHODS = [
  "CreateInstance",
  "DeleteInstance",
  "CloneInstance",
  "RenameInstance",
  "SetProperty",
  "GetProperty",
  "GetChildren",
  "GetDescendants",
  "FindFirstChild",
  "GetService",
  "MoveTo",
  "SetPosition",
  "SetRotation",
  "SetSize",
  "PivotTo",
  "GetPivot",
  "SetColor",
  "SetTransparency",
  "SetMaterial",
  "SetAnchored",
  "SetCanCollide",
  "CreateScript",
  "GetScriptSource",
  "SetScriptSource",
  "AppendToScript",
  "ReplaceScriptLines",
  "InsertScriptLines",
  "RunConsoleCommand",
  "GetSelection",
  "SetSelection",
  "ClearSelection",
  "AddToSelection",
  "GroupSelection",
  "UngroupModel",
  "SetTimeOfDay",
  "SetBrightness",
  "SetAtmosphereDensity",
  "CreateLight",
  "SetAttribute",
  "GetAttribute",
  "GetAttributes",
  "AddTag",
  "RemoveTag",
  "GetTags",
  "HasTag",
  "GetPlayers",
  "GetPlayerPosition",
  "TeleportPlayer",
  "KickPlayer",
  "SavePlace",
  "GetPlaceInfo",
  "PlaySound",
  "StopSound",
  "GetDistance",
  "HighlightObject",
  "Chat",
] as const;

const DESCRIPTION = `Roblox Studio ops. method + params{}.
CreateInstance(className,parentPath,name?,properties?)
DeleteInstance(path)
CloneInstance(path,parentPath?)
RenameInstance(path,newName)
SetProperty(path,property,value)
GetProperty(path,property)
GetChildren(path)
GetDescendants(path)
FindFirstChild(path,name,recursive?)
GetService(service)
MoveTo(path,position[x,y,z])
SetPosition(path,x,y,z)
SetRotation(path,x,y,z)
SetSize(path,x,y,z)
PivotTo(path,cframe[12])
GetPivot(path)
SetColor(path,r,g,b)
SetTransparency(path,value:0-1)
SetMaterial(path,material)
SetAnchored(path,anchored)
SetCanCollide(path,canCollide)
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
GetDistance(path1,path2)
HighlightObject(path,color?,duration?)
Chat(message,color?)`;

export function registerAllTools(server: FastMCP): void {
  server.addTool({
    name: "roblox",
    description: DESCRIPTION,
    parameters: z.object({
      method: z.enum(METHODS),
      params: z.record(z.unknown()).default({}),
    }),
    execute: async ({ method, params }) => {
      const result = await bridge.execute(method, params);
      return typeof result === "string" ? result : JSON.stringify(result, null, 2);
    },
  });
}
