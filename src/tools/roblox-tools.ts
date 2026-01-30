import { z } from "zod";
import type { FastMCP } from "fastmcp";
import { bridge } from "../utils/bridge";
import { config } from "../config";
import { InvalidParameterError } from "../utils/errors";

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
  "ClearAllChildren",
  "CloneInstance",
  "RenameInstance",
  // Instance discovery & info
  "GetFullName",
  "GetParent",
  "IsA",
  "GetClassName",
  "WaitForChild",
  "FindFirstAncestor",
  "FindFirstAncestorOfClass",
  "FindFirstAncestorWhichIsA",
  "FindFirstChildOfClass",
  "FindFirstChildWhichIsA",
  "FindFirstDescendant",
  "GetDebugId",
  // Properties
  "SetProperty",
  "GetProperty",
  // Hierarchy
  "GetChildren",
  "GetDescendants",
  "GetDescendantCount",
  "GetAncestors",
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
  "ApplyImpulse",
  "ApplyAngularImpulse",
  "BreakJoints",
  "GetJoints",
  "GetConnectedParts",
  "GetTouchingParts",
  "SetMassless",
  "GetVelocity",
  "SetVelocity",
  "GetAngularVelocity",
  "SetAngularVelocity",
  "GetCenterOfMass",
  "SetCollisionGroup",
  "GetCollisionGroup",
  // Assembly Physics
  "GetAssemblyMass",
  "GetAssemblyCenterOfMass",
  "GetRootPart",
  "SetRootPriority",
  "GetRootPriority",
  // Attachments
  "CreateAttachment",
  "GetAttachmentPosition",
  "SetAttachmentPosition",
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
  // Lighting & Environment
  "SetTimeOfDay",
  "SetBrightness",
  "SetAtmosphereDensity",
  "SetAtmosphereColor",
  "SetGlobalShadows",
  "SetFog",
  "CreateLight",
  "CreateClouds",
  "SetSkybox",
  "CreateBeam",
  "CreateTrail",
  "GetSunDirection",
  "GetMoonDirection",
  "GetMinutesAfterMidnight",
  "SetMinutesAfterMidnight",
  // Attributes & Tags
  "SetAttribute",
  "GetAttribute",
  "GetAttributes",
  "RemoveAttribute",
  "AddTag",
  "RemoveTag",
  "GetTags",
  "GetTagged",
  "HasTag",
  // Players
  "GetPlayers",
  "GetPlayerInfo",
  "GetPlayerPosition",
  "TeleportPlayer",
  "KickPlayer",
  // Place
  "SavePlace",
  "GetPlaceInfo",
  "GetPlaceVersion",
  "GetGameId",
  // World Settings
  "SetGravity",
  "GetGravity",
  // Pathfinding
  "ComputePath",
  // Audio
  "PlaySound",
  "StopSound",
  // Terrain
  "FillTerrain",
  "FillTerrainRegion",
  "FillBall",
  "FillBlock",
  "FillCylinder",
  "FillWedge",
  "ClearTerrain",
  "GetTerrainInfo",
  "ReplaceMaterial",
  // Camera
  "SetCameraPosition",
  "SetCameraTarget",
  "SetCameraFocus",
  "GetCameraPosition",
  "SetCameraType",
  "ZoomCamera",
  "GetCameraType",
  "ScreenPointToRay",
  "ViewportPointToRay",
  "WorldToScreenPoint",
  "WorldToViewportPoint",
  // Utilities
  "GetDistance",
  "HighlightObject",
  "Chat",
  // History
  "Undo",
  "Redo",
  "RecordUndo",
  "GetCanUndo",
  "GetCanRedo",
  // Animation & Character
  "PlayAnimation",
  "LoadAnimation",
  "StopAnimation",
  "SetCharacterAppearance",
  "GetCharacter",
  // Humanoid
  "GetHumanoidState",
  "ChangeHumanoidState",
  "TakeDamage",
  "GetAccessories",
  "AddAccessory",
  "RemoveAccessories",
  "GetHumanoidDescription",
  // GUI
  "CreateGuiElement",
  "SetGuiText",
  "SetGuiSize",
  "SetGuiPosition",
  "SetGuiVisible",
  "DestroyGuiElement",
  // Networking
  "FireRemoteEvent",
  "InvokeRemoteFunction",
  "CreateRemoteEvent",
  "CreateRemoteFunction",
  // DataStore
  "GetDataStore",
  "SetDataStoreValue",
  "GetDataStoreValue",
  "RemoveDataStoreValue",
  // Tween
  "CreateTween",
  "TweenProperty",
  // Raycasting & Spatial Queries
  "Raycast",
  "RaycastTo",
  "Spherecast",
  "Blockcast",
  "GetPartsInPart",
  "GetPartBoundsInRadius",
  "GetPartBoundsInBox",
  // Constraints
  "CreateWeld",
  "CreateMotor6D",
  // Particles
  "CreateParticleEmitter",
  "EmitParticles",
  // Materials
  "ApplyDecal",
  "ApplyTexture",
  // Marketplace
  "InsertAsset",
  "InsertMesh",
  // Teams
  "CreateTeam",
  "SetPlayerTeam",
  "GetPlayerTeam",
  // Leaderstats
  "CreateLeaderstat",
  "SetLeaderstatValue",
  "GetLeaderstatValue",
  // Model Operations
  "GetBoundingBox",
  "GetExtentsSize",
  "ScaleTo",
  "GetScale",
  "TranslateBy",
  "SetPrimaryPart",
  "GetPrimaryPart",
  // RunService State
  "IsStudio",
  "IsRunMode",
  "IsEdit",
  "IsRunning",
  // Workspace Utilities
  "GetServerTimeNow",
  "GetRealPhysicsFPS",
] as const;

/**
 * Comprehensive description of all 205 Roblox Studio API methods
 * Format: MethodName(param1,param2?,param3?)
 * Optional params marked with ?, arrays marked with [], numeric ranges shown as min-max
 */
const DESCRIPTION = `Roblox Studio ops. method + params{}.
CreateInstance(className,parentPath,name?,properties?) DeleteInstance(path) ClearAllChildren(path) CloneInstance(path,parentPath?) RenameInstance(path,newName)
GetFullName(path) GetParent(path) IsA(path,className) GetClassName(path) WaitForChild(path,name,timeout?)
FindFirstAncestor(path,name) FindFirstAncestorOfClass(path,className) FindFirstAncestorWhichIsA(path,className)
FindFirstChildOfClass(path,className) FindFirstChildWhichIsA(path,className,recursive?) FindFirstDescendant(path,name) GetDebugId(path)
SetProperty(path,property,value) GetProperty(path,property)
GetChildren(path) GetDescendants(path) GetDescendantCount(path) GetAncestors(path) FindFirstChild(path,name,recursive?) GetService(service)
MoveTo(path,position[3]) SetPosition(path,x,y,z) GetPosition(path) SetRotation(path,x,y,z) GetRotation(path)
SetSize(path,x,y,z) GetSize(path) PivotTo(path,cframe[12]) GetPivot(path)
SetColor(path,r,g,b) SetTransparency(path,value:0-1) SetMaterial(path,material)
SetAnchored(path,anchored) SetCanCollide(path,canCollide) CreateConstraint(type,attachment0Path,attachment1Path,properties?)
SetPhysicalProperties(path,density?,friction?,elasticity?) GetMass(path) ApplyImpulse(path,impulse[3]) ApplyAngularImpulse(path,impulse[3])
BreakJoints(path) GetJoints(path) GetConnectedParts(path,recursive?) GetTouchingParts(path)
SetMassless(path,massless) GetVelocity(path) SetVelocity(path,x,y,z) GetAngularVelocity(path) SetAngularVelocity(path,x,y,z) GetCenterOfMass(path)
SetCollisionGroup(path,group) GetCollisionGroup(path)
GetAssemblyMass(path) GetAssemblyCenterOfMass(path) GetRootPart(path) SetRootPriority(path,priority) GetRootPriority(path)
CreateAttachment(parentPath,name?,position?,orientation?) GetAttachmentPosition(path) SetAttachmentPosition(path,x,y,z)
CreateScript(name,parentPath,source,type?) GetScriptSource(path) SetScriptSource(path,source)
AppendToScript(path,code) ReplaceScriptLines(path,startLine,endLine,content) InsertScriptLines(path,lineNumber,content) RunConsoleCommand(code)
GetSelection() SetSelection(paths[]) ClearSelection() AddToSelection(paths[]) GroupSelection(name) UngroupModel(path)
SetTimeOfDay(time) SetBrightness(brightness) SetAtmosphereDensity(density) SetAtmosphereColor(r,g,b,haze?) SetGlobalShadows(enabled)
SetFog(start?,fogEnd?,color?) CreateLight(parentPath,type,brightness?,color?) CreateClouds(cover?,density?,color?)
SetSkybox(skyboxBk?,skyboxDn?,skyboxFt?,skyboxLf?,skyboxRt?,skyboxUp?,sunTextureId?,moonTextureId?)
CreateBeam(attachment0Path,attachment1Path,color?,width0?,width1?,segments?) CreateTrail(attachment0Path,attachment1Path,lifetime?,color?,widthScale?)
GetSunDirection() GetMoonDirection() GetMinutesAfterMidnight() SetMinutesAfterMidnight(minutes)
SetAttribute(path,name,value) GetAttribute(path,name) GetAttributes(path) RemoveAttribute(path,name) AddTag(path,tag) RemoveTag(path,tag) GetTags(path) GetTagged(tag) HasTag(path,tag)
GetPlayers() GetPlayerInfo(name) GetPlayerPosition(username) TeleportPlayer(username,position[3]) KickPlayer(username,reason?)
SavePlace() GetPlaceInfo() GetPlaceVersion() GetGameId() SetGravity(gravity) GetGravity()
ComputePath(start[3],endPos[3],agentRadius?,agentHeight?,canJump?,canClimb?)
PlaySound(soundId,parentPath?,volume?) StopSound(path)
FillTerrain(material,minX,minY,minZ,maxX,maxY,maxZ) FillTerrainRegion(min[3],max[3],material) FillBall(center[3],radius,material) FillBlock(position[3],size[3],material)
FillCylinder(position[3],height,radius,material) FillWedge(position[3],size[3],material) ClearTerrain() GetTerrainInfo() ReplaceMaterial(min[3],max[3],sourceMaterial,targetMaterial)
SetCameraPosition(x,y,z) SetCameraTarget(x,y,z) SetCameraFocus(path) GetCameraPosition() SetCameraType(cameraType) ZoomCamera(distance) GetCameraType()
ScreenPointToRay(x,y,depth?) ViewportPointToRay(x,y,depth?) WorldToScreenPoint(x,y,z) WorldToViewportPoint(x,y,z)
GetDistance(path1,path2) HighlightObject(path,color?,duration?) Chat(message) Undo() Redo() RecordUndo(name) GetCanUndo() GetCanRedo()
PlayAnimation(trackId,fadeTime?,weight?,speed?) LoadAnimation(humanoidPath,animationId) StopAnimation(trackId,fadeTime?)
SetCharacterAppearance(playerName,userId?) GetCharacter(playerName)
GetHumanoidState(humanoidPath) ChangeHumanoidState(humanoidPath,state) TakeDamage(humanoidPath,amount)
GetAccessories(humanoidPath) AddAccessory(humanoidPath,accessoryPath) RemoveAccessories(humanoidPath) GetHumanoidDescription(humanoidPath)
CreateGuiElement(className,parentPath,name?,properties?) SetGuiText(path,text) SetGuiSize(path,scaleX,scaleY,offsetX?,offsetY?)
SetGuiPosition(path,scaleX,scaleY,offsetX?,offsetY?) SetGuiVisible(path,visible) DestroyGuiElement(path)
FireRemoteEvent(path,playerName?,args[]?) InvokeRemoteFunction(path,playerName,args[]?) CreateRemoteEvent(name,parentPath?) CreateRemoteFunction(name,parentPath?)
GetDataStore(name,scope?) SetDataStoreValue(storeName,key,value) GetDataStoreValue(storeName,key) RemoveDataStoreValue(storeName,key)
CreateTween(path,goals,duration?,easingStyle?,easingDirection?,repeatCount?,reverses?,delayTime?,autoPlay?) TweenProperty(path,property,value,duration?)
Raycast(origin[3],direction[3],filterDescendants[]?,filterType?) RaycastTo(originPath,targetPath,filterDescendants[]?,filterType?)
Spherecast(position[3],radius,direction[3],filterDescendants[]?,filterType?) Blockcast(position[3],size[3],direction[3],filterDescendants[]?,filterType?)
GetPartsInPart(path,filterDescendants[]?,filterType?) GetPartBoundsInRadius(position[3],radius,filterDescendants[]?) GetPartBoundsInBox(position[3],size[3],filterDescendants[]?)
CreateWeld(part0Path,part1Path) CreateMotor6D(part0Path,part1Path,name?)
CreateParticleEmitter(parentPath,properties?) EmitParticles(path,count?)
ApplyDecal(parentPath,textureId,face?) ApplyTexture(parentPath,textureId,face?)
InsertAsset(assetId,parentPath?) InsertMesh(parentPath,meshId,textureId?,name?)
CreateTeam(name,color?,autoAssignable?) SetPlayerTeam(playerName,teamName) GetPlayerTeam(playerName)
CreateLeaderstat(playerName,statName,valueType?,initialValue?) SetLeaderstatValue(playerName,statName,value) GetLeaderstatValue(playerName,statName)
GetBoundingBox(path) GetExtentsSize(path) ScaleTo(path,scale) GetScale(path) TranslateBy(path,offset[3]) SetPrimaryPart(path,primaryPartPath) GetPrimaryPart(path)
IsStudio() IsRunMode() IsEdit() IsRunning() GetServerTimeNow() GetRealPhysicsFPS()`;

/**
 * Register all Roblox Studio tools with the FastMCP server
 * Registers a single 'roblox' tool that dispatches to 205 different methods
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
      // Validate RunConsoleCommand has required 'code' parameter
      if (method === "RunConsoleCommand") {
        if (typeof params.code !== "string" || params.code.trim().length === 0) {
          throw new InvalidParameterError(
            "RunConsoleCommand requires a non-empty 'code' parameter",
            method
          );
        }
        // Limit code length to prevent abuse (64KB max)
        if (params.code.length > 65536) {
          throw new InvalidParameterError(
            `RunConsoleCommand code exceeds maximum length of 65536 characters (got ${params.code.length})`,
            method
          );
        }
      }

      const result = await bridge.execute(method, params, config.retries);
      return typeof result === "string" ? result : JSON.stringify(result, null, 2);
    },
  });
}
