import { z } from "zod";
import type { FastMCP } from "fastmcp";
import { bridge } from "../utils/bridge";
import { config } from "../config";
import { InvalidParameterError } from "../utils/errors";

/**
 * All supported Roblox Studio API methods (205 total)
 *
 * Methods are organized into the following categories:
 * - Instance: Create, delete, clone, rename instances
 * - Discovery: Find and query instance hierarchy
 * - Properties: Get/set arbitrary properties
 * - Hierarchy: Navigate parent/child relationships
 * - Transforms: Position, rotation, size manipulation
 * - Appearance: Colors, materials, transparency
 * - Physics: Anchoring, collision, impulses, velocity
 * - Attachments: Create and manipulate attachments
 * - Scripting: Script creation and source manipulation
 * - Selection: Studio selection management
 * - Environment: Lighting, atmosphere, skybox, effects
 * - Attributes/Tags: Custom attributes and CollectionService tags
 * - Players: Player info, position, teams, leaderstats
 * - Place: Place info and save operations
 * - Pathfinding: AI navigation path computation
 * - Audio: Sound playback control
 * - Terrain: Voxel terrain manipulation
 * - Camera: Camera position, rotation, coordinate conversion
 * - History: Undo/redo operations
 * - Character: Animation and humanoid control
 * - GUI: UI element creation and manipulation
 * - Networking: RemoteEvent/RemoteFunction management
 * - DataStore: Persistent data storage
 * - Tween: Property animation
 * - Raycasting: Ray and shape casting queries
 * - Constraints: Weld and Motor6D creation
 * - Particles: Particle emitter control
 * - Materials: Decal and texture application
 * - Marketplace: Asset insertion
 * - Model: Bounding box, scale, primary part
 * - RunService: Runtime state queries
 */
const METHODS = [
  // ─────────────────────────────────────────────────────────────────────────────
  // INSTANCE MANAGEMENT - Create, destroy, and manipulate instances
  // ─────────────────────────────────────────────────────────────────────────────
  "CreateInstance",
  "DeleteInstance",
  "ClearAllChildren",
  "CloneInstance",
  "RenameInstance",

  // ─────────────────────────────────────────────────────────────────────────────
  // INSTANCE DISCOVERY - Find instances by name, class, or ancestry
  // ─────────────────────────────────────────────────────────────────────────────
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

  // ─────────────────────────────────────────────────────────────────────────────
  // PROPERTIES - Get and set arbitrary instance properties
  // ─────────────────────────────────────────────────────────────────────────────
  "SetProperty",
  "GetProperty",

  // ─────────────────────────────────────────────────────────────────────────────
  // HIERARCHY - Navigate and query instance trees
  // ─────────────────────────────────────────────────────────────────────────────
  "GetChildren",
  "GetDescendants",
  "GetDescendantCount",
  "GetAncestors",
  "FindFirstChild",
  "GetService",

  // ─────────────────────────────────────────────────────────────────────────────
  // TRANSFORMS - Position, rotation, and size manipulation
  // ─────────────────────────────────────────────────────────────────────────────
  "MoveTo",
  "SetPosition",
  "GetPosition",
  "SetRotation",
  "GetRotation",
  "SetSize",
  "GetSize",
  "PivotTo",
  "GetPivot",

  // ─────────────────────────────────────────────────────────────────────────────
  // APPEARANCE - Visual properties like color, material, transparency
  // ─────────────────────────────────────────────────────────────────────────────
  "SetColor",
  "SetTransparency",
  "SetMaterial",

  // ─────────────────────────────────────────────────────────────────────────────
  // PHYSICS - Anchoring, collision, forces, and velocity
  // ─────────────────────────────────────────────────────────────────────────────
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

  // ─────────────────────────────────────────────────────────────────────────────
  // ASSEMBLY PHYSICS - Multi-part assembly properties
  // ─────────────────────────────────────────────────────────────────────────────
  "GetAssemblyMass",
  "GetAssemblyCenterOfMass",
  "GetRootPart",
  "SetRootPriority",
  "GetRootPriority",

  // ─────────────────────────────────────────────────────────────────────────────
  // ATTACHMENTS - Create and manipulate attachment points
  // ─────────────────────────────────────────────────────────────────────────────
  "CreateAttachment",
  "GetAttachmentPosition",
  "SetAttachmentPosition",

  // ─────────────────────────────────────────────────────────────────────────────
  // SCRIPTING - Script creation and source code manipulation
  // ─────────────────────────────────────────────────────────────────────────────
  "CreateScript",
  "GetScriptSource",
  "SetScriptSource",
  "AppendToScript",
  "ReplaceScriptLines",
  "InsertScriptLines",
  "RunConsoleCommand",

  // ─────────────────────────────────────────────────────────────────────────────
  // SELECTION - Studio selection management
  // ─────────────────────────────────────────────────────────────────────────────
  "GetSelection",
  "SetSelection",
  "ClearSelection",
  "AddToSelection",
  "GroupSelection",
  "UngroupModel",

  // ─────────────────────────────────────────────────────────────────────────────
  // ENVIRONMENT - Lighting, atmosphere, skybox, and visual effects
  // ─────────────────────────────────────────────────────────────────────────────
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

  // ─────────────────────────────────────────────────────────────────────────────
  // ATTRIBUTES & TAGS - Custom attributes and CollectionService tags
  // ─────────────────────────────────────────────────────────────────────────────
  "SetAttribute",
  "GetAttribute",
  "GetAttributes",
  "RemoveAttribute",
  "AddTag",
  "RemoveTag",
  "GetTags",
  "GetTagged",
  "HasTag",

  // ─────────────────────────────────────────────────────────────────────────────
  // PLAYERS - Player info, position, and management
  // ─────────────────────────────────────────────────────────────────────────────
  "GetPlayers",
  "GetPlayerInfo",
  "GetPlayerPosition",
  "TeleportPlayer",
  "KickPlayer",

  // ─────────────────────────────────────────────────────────────────────────────
  // PLACE - Place metadata and save operations
  // ─────────────────────────────────────────────────────────────────────────────
  "SavePlace",
  "GetPlaceInfo",
  "GetPlaceVersion",
  "GetGameId",

  // ─────────────────────────────────────────────────────────────────────────────
  // WORLD SETTINGS - Global workspace properties
  // ─────────────────────────────────────────────────────────────────────────────
  "SetGravity",
  "GetGravity",

  // ─────────────────────────────────────────────────────────────────────────────
  // PATHFINDING - AI navigation path computation
  // ─────────────────────────────────────────────────────────────────────────────
  "ComputePath",

  // ─────────────────────────────────────────────────────────────────────────────
  // AUDIO - Sound playback control
  // ─────────────────────────────────────────────────────────────────────────────
  "PlaySound",
  "StopSound",

  // ─────────────────────────────────────────────────────────────────────────────
  // TERRAIN - Voxel terrain manipulation and queries
  // ─────────────────────────────────────────────────────────────────────────────
  "FillTerrain",
  "FillTerrainRegion",
  "FillBall",
  "FillBlock",
  "FillCylinder",
  "FillWedge",
  "ClearTerrain",
  "GetTerrainInfo",
  "ReplaceMaterial",

  // ─────────────────────────────────────────────────────────────────────────────
  // CAMERA - Position, focus, and coordinate conversion
  // ─────────────────────────────────────────────────────────────────────────────
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

  // ─────────────────────────────────────────────────────────────────────────────
  // UTILITIES - Distance calculation, highlights, chat
  // ─────────────────────────────────────────────────────────────────────────────
  "GetDistance",
  "HighlightObject",
  "Chat",

  // ─────────────────────────────────────────────────────────────────────────────
  // HISTORY - Undo/redo and change recording
  // ─────────────────────────────────────────────────────────────────────────────
  "Undo",
  "Redo",
  "RecordUndo",
  "GetCanUndo",
  "GetCanRedo",

  // ─────────────────────────────────────────────────────────────────────────────
  // ANIMATION - Animation track loading and playback
  // ─────────────────────────────────────────────────────────────────────────────
  "PlayAnimation",
  "LoadAnimation",
  "StopAnimation",
  "SetCharacterAppearance",
  "GetCharacter",

  // ─────────────────────────────────────────────────────────────────────────────
  // HUMANOID - State, damage, and accessory management
  // ─────────────────────────────────────────────────────────────────────────────
  "GetHumanoidState",
  "ChangeHumanoidState",
  "TakeDamage",
  "GetAccessories",
  "AddAccessory",
  "RemoveAccessories",
  "GetHumanoidDescription",

  // ─────────────────────────────────────────────────────────────────────────────
  // GUI - UI element creation and manipulation
  // ─────────────────────────────────────────────────────────────────────────────
  "CreateGuiElement",
  "SetGuiText",
  "SetGuiSize",
  "SetGuiPosition",
  "SetGuiVisible",
  "DestroyGuiElement",

  // ─────────────────────────────────────────────────────────────────────────────
  // NETWORKING - RemoteEvent and RemoteFunction management
  // ─────────────────────────────────────────────────────────────────────────────
  "FireRemoteEvent",
  "InvokeRemoteFunction",
  "CreateRemoteEvent",
  "CreateRemoteFunction",

  // ─────────────────────────────────────────────────────────────────────────────
  // DATASTORE - Persistent data storage (requires API access)
  // ─────────────────────────────────────────────────────────────────────────────
  "GetDataStore",
  "SetDataStoreValue",
  "GetDataStoreValue",
  "RemoveDataStoreValue",

  // ─────────────────────────────────────────────────────────────────────────────
  // TWEEN - Property animation with easing
  // ─────────────────────────────────────────────────────────────────────────────
  "CreateTween",
  "TweenProperty",

  // ─────────────────────────────────────────────────────────────────────────────
  // RAYCASTING - Ray and shape casting spatial queries
  // ─────────────────────────────────────────────────────────────────────────────
  "Raycast",
  "RaycastTo",
  "Spherecast",
  "Blockcast",
  "GetPartsInPart",
  "GetPartBoundsInRadius",
  "GetPartBoundsInBox",

  // ─────────────────────────────────────────────────────────────────────────────
  // CONSTRAINTS - Weld and motor creation
  // ─────────────────────────────────────────────────────────────────────────────
  "CreateWeld",
  "CreateMotor6D",

  // ─────────────────────────────────────────────────────────────────────────────
  // PARTICLES - Particle emitter creation and control
  // ─────────────────────────────────────────────────────────────────────────────
  "CreateParticleEmitter",
  "EmitParticles",

  // ─────────────────────────────────────────────────────────────────────────────
  // MATERIALS - Decal and texture application
  // ─────────────────────────────────────────────────────────────────────────────
  "ApplyDecal",
  "ApplyTexture",

  // ─────────────────────────────────────────────────────────────────────────────
  // MARKETPLACE - Asset insertion from library
  // ─────────────────────────────────────────────────────────────────────────────
  "InsertAsset",
  "InsertMesh",

  // ─────────────────────────────────────────────────────────────────────────────
  // TEAMS - Team creation and player assignment
  // ─────────────────────────────────────────────────────────────────────────────
  "CreateTeam",
  "SetPlayerTeam",
  "GetPlayerTeam",

  // ─────────────────────────────────────────────────────────────────────────────
  // LEADERSTATS - Player leaderboard statistics
  // ─────────────────────────────────────────────────────────────────────────────
  "CreateLeaderstat",
  "SetLeaderstatValue",
  "GetLeaderstatValue",

  // ─────────────────────────────────────────────────────────────────────────────
  // MODEL OPERATIONS - Bounding box, scale, and primary part
  // ─────────────────────────────────────────────────────────────────────────────
  "GetBoundingBox",
  "GetExtentsSize",
  "ScaleTo",
  "GetScale",
  "TranslateBy",
  "SetPrimaryPart",
  "GetPrimaryPart",

  // ─────────────────────────────────────────────────────────────────────────────
  // RUNSERVICE - Runtime state queries
  // ─────────────────────────────────────────────────────────────────────────────
  "IsStudio",
  "IsRunMode",
  "IsEdit",
  "IsRunning",

  // ─────────────────────────────────────────────────────────────────────────────
  // WORKSPACE UTILITIES - Server time and physics metrics
  // ─────────────────────────────────────────────────────────────────────────────
  "GetServerTimeNow",
  "GetRealPhysicsFPS",
] as const;

/**
 * All 205 Roblox Studio API methods
 *
 * Format: MethodName(params) -> ReturnType
 * - Optional params marked with ?
 * - Arrays marked with []
 * - Actions return "string" status, queries return data
 *
 * Return Type Legend:
 * - path: Instance full name string (e.g., "game.Workspace.Part")
 * - path|nil: Path or nil if not found
 * - paths[]: Array of instance paths
 * - vec3: Array [x, y, z]
 * - cframe: Array [12 components]
 * - {}: Object with named properties
 */
const DESCRIPTION = `Roblox Studio API (205 methods). Call with method + params{}.

INSTANCE: CreateInstance(className,parentPath,name?,properties?)->path DeleteInstance(path)->"Deleted" ClearAllChildren(path)->"Cleared" CloneInstance(path,parentPath?)->path RenameInstance(path,newName)->path

DISCOVERY: GetFullName(path)->path GetParent(path)->path|nil IsA(path,className)->bool GetClassName(path)->string WaitForChild(path,name,timeout?)->path|nil
FindFirstAncestor(path,name)->path|nil FindFirstAncestorOfClass(path,className)->path|nil FindFirstAncestorWhichIsA(path,className)->path|nil
FindFirstChildOfClass(path,className)->path|nil FindFirstChildWhichIsA(path,className,recursive?)->path|nil FindFirstDescendant(path,name)->path|nil GetDebugId(path)->string

PROPERTIES: SetProperty(path,property,value)->string GetProperty(path,property)->any

HIERARCHY: GetChildren(path)->names[] GetDescendants(path)->paths[] GetDescendantCount(path)->number GetAncestors(path)->paths[] FindFirstChild(path,name,recursive?)->path|nil GetService(service)->string

TRANSFORMS: MoveTo(path,position[3])->"Moved" SetPosition(path,x,y,z)->"Set" GetPosition(path)->vec3 SetRotation(path,x,y,z)->"Set" GetRotation(path)->vec3
SetSize(path,x,y,z)->"Set" GetSize(path)->vec3 PivotTo(path,cframe[12])->"Pivoted" GetPivot(path)->cframe

APPEARANCE: SetColor(path,r,g,b)->"Set" SetTransparency(path,value:0-1)->"Set" SetMaterial(path,material)->"Set"

PHYSICS: SetAnchored(path,anchored)->"Set" SetCanCollide(path,canCollide)->"Set" CreateConstraint(type,attachment0Path,attachment1Path,properties?)->path
SetPhysicalProperties(path,density?,friction?,elasticity?)->"Set" GetMass(path)->number ApplyImpulse(path,impulse[3])->"Applied" ApplyAngularImpulse(path,impulse[3])->"Applied"
BreakJoints(path)->"Broken" GetJoints(path)->paths[] GetConnectedParts(path,recursive?)->paths[] GetTouchingParts(path)->paths[]
SetMassless(path,massless)->"Set" GetVelocity(path)->vec3 SetVelocity(path,x,y,z)->"Set" GetAngularVelocity(path)->vec3 SetAngularVelocity(path,x,y,z)->"Set" GetCenterOfMass(path)->vec3
SetCollisionGroup(path,group)->"Set" GetCollisionGroup(path)->string

ASSEMBLY: GetAssemblyMass(path)->number GetAssemblyCenterOfMass(path)->vec3 GetRootPart(path)->path|nil SetRootPriority(path,priority)->"Set" GetRootPriority(path)->number

ATTACHMENTS: CreateAttachment(parentPath,name?,position?,orientation?)->path GetAttachmentPosition(path)->vec3 SetAttachmentPosition(path,x,y,z)->"Set"

SCRIPTING: CreateScript(name,parentPath,source,type?)->path GetScriptSource(path)->string SetScriptSource(path,source)->"Set"
AppendToScript(path,code)->"Appended" ReplaceScriptLines(path,startLine,endLine,content)->"Replaced" InsertScriptLines(path,lineNumber,content)->"Inserted" RunConsoleCommand(code)->any

SELECTION: GetSelection()->paths[] SetSelection(paths[])->"Set" ClearSelection()->"Cleared" AddToSelection(paths[])->"Added" GroupSelection(name)->path UngroupModel(path)->"Ungrouped"

ENVIRONMENT: SetTimeOfDay(time)->"Set" SetBrightness(brightness)->"Set" SetAtmosphereDensity(density)->"Set" SetAtmosphereColor(r,g,b,haze?)->"Set" SetGlobalShadows(enabled)->"Set"
SetFog(start?,fogEnd?,color?)->"Set" CreateLight(parentPath,type,brightness?,color?)->path CreateClouds(cover?,density?,color?)->path
SetSkybox(skyboxBk?,skyboxDn?,skyboxFt?,skyboxLf?,skyboxRt?,skyboxUp?,sunTextureId?,moonTextureId?)->path
CreateBeam(attachment0Path,attachment1Path,color?,width0?,width1?,segments?)->path CreateTrail(attachment0Path,attachment1Path,lifetime?,color?,widthScale?)->path
GetSunDirection()->vec3 GetMoonDirection()->vec3 GetMinutesAfterMidnight()->number SetMinutesAfterMidnight(minutes)->"Set"

ATTRIBUTES: SetAttribute(path,name,value)->"Set" GetAttribute(path,name)->any GetAttributes(path)->{} RemoveAttribute(path,name)->"Removed"
AddTag(path,tag)->"Added" RemoveTag(path,tag)->"Removed" GetTags(path)->string[] GetTagged(tag)->paths[] HasTag(path,tag)->bool

PLAYERS: GetPlayers()->names[] GetPlayerInfo(name)->{UserId,DisplayName,Team,Character} GetPlayerPosition(username)->vec3 TeleportPlayer(username,position[3])->"Teleported" KickPlayer(username,reason?)->"Kicked"

PLACE: SavePlace()->"Save triggered" GetPlaceInfo()->{PlaceId,PlaceVersion,GameId,CreatorId} GetPlaceVersion()->number GetGameId()->number SetGravity(gravity)->"Set" GetGravity()->number

PATHFINDING: ComputePath(start[3],endPos[3],agentRadius?,agentHeight?,canJump?,canClimb?)->{status,waypoints[{position,action}]}

AUDIO: PlaySound(soundId,parentPath?,volume?)->path StopSound(path)->"Stopped"

TERRAIN: FillTerrain(material,minX,minY,minZ,maxX,maxY,maxZ)->"Filled" FillTerrainRegion(min[3],max[3],material)->"Filled" FillBall(center[3],radius,material)->"Filled" FillBlock(position[3],size[3],material)->"Filled"
FillCylinder(position[3],height,radius,material)->"Filled" FillWedge(position[3],size[3],material)->"Filled" ClearTerrain()->"Cleared" GetTerrainInfo()->{maxExtents,waterWaveSize,waterWaveSpeed} ReplaceMaterial(min[3],max[3],sourceMaterial,targetMaterial)->"Replaced"

CAMERA: SetCameraPosition(x,y,z)->"Set" SetCameraTarget(x,y,z)->"Set" SetCameraFocus(path)->"Set" GetCameraPosition()->vec3 SetCameraType(cameraType)->"Set" ZoomCamera(distance)->"Zoomed" GetCameraType()->string
ScreenPointToRay(x,y,depth?)->{origin,direction} ViewportPointToRay(x,y,depth?)->{origin,direction} WorldToScreenPoint(x,y,z)->{position,onScreen} WorldToViewportPoint(x,y,z)->{position,onScreen}

UTILITIES: GetDistance(path1,path2)->number HighlightObject(path,color?,duration?)->path Chat(message)->"Sent"|"Chat not available"

HISTORY: Undo()->"Undone" Redo()->"Redone" RecordUndo(name)->"Recorded" GetCanUndo()->bool GetCanRedo()->bool

ANIMATION: PlayAnimation(trackId,fadeTime?,weight?,speed?)->"Playing" LoadAnimation(humanoidPath,animationId)->trackId StopAnimation(trackId,fadeTime?)->"Stopped"
SetCharacterAppearance(playerName,userId?)->"Applied" GetCharacter(playerName)->path|nil

HUMANOID: GetHumanoidState(humanoidPath)->HumanoidStateType ChangeHumanoidState(humanoidPath,state)->"Changed" TakeDamage(humanoidPath,amount)->"Damaged"
GetAccessories(humanoidPath)->paths[] AddAccessory(humanoidPath,accessoryPath)->"Added" RemoveAccessories(humanoidPath)->"Removed"
GetHumanoidDescription(humanoidPath)->{HeadColor,BodyTypeScale,HeadScale,HeightScale,WidthScale,DepthScale}|nil

GUI: CreateGuiElement(className,parentPath,name?,properties?)->path SetGuiText(path,text)->"Set" SetGuiSize(path,scaleX,scaleY,offsetX?,offsetY?)->"Set"
SetGuiPosition(path,scaleX,scaleY,offsetX?,offsetY?)->"Set" SetGuiVisible(path,visible)->"Set" DestroyGuiElement(path)->"Destroyed"

NETWORKING: FireRemoteEvent(path,playerName?,args[]?)->"Fired" InvokeRemoteFunction(path,playerName,args[]?)->any CreateRemoteEvent(name,parentPath?)->path CreateRemoteFunction(name,parentPath?)->path

DATASTORE: GetDataStore(name,scope?)->"DataStore:name" SetDataStoreValue(storeName,key,value)->"Set" GetDataStoreValue(storeName,key)->any RemoveDataStoreValue(storeName,key)->"Removed"

TWEEN: CreateTween(path,goals,duration?,easingStyle?,easingDirection?,repeatCount?,reverses?,delayTime?,autoPlay?)->tweenId TweenProperty(path,property,value,duration?)->"Tweening"

RAYCASTING: Raycast(origin[3],direction[3],filterDescendants[]?,filterType?)->{instance,position,normal,material,distance}|nil RaycastTo(originPath,targetPath,filterDescendants[]?,filterType?)->{instance,position,distance}|nil
Spherecast(position[3],radius,direction[3],filterDescendants[]?,filterType?)->{instance,position,normal,distance}|nil Blockcast(position[3],size[3],direction[3],filterDescendants[]?,filterType?)->{instance,position,normal,distance}|nil
GetPartsInPart(path,filterDescendants[]?,filterType?)->paths[] GetPartBoundsInRadius(position[3],radius,filterDescendants[]?)->paths[] GetPartBoundsInBox(position[3],size[3],filterDescendants[]?)->paths[]

CONSTRAINTS: CreateWeld(part0Path,part1Path)->path CreateMotor6D(part0Path,part1Path,name?)->path

PARTICLES: CreateParticleEmitter(parentPath,properties?)->path EmitParticles(path,count?)->"Emitted"

MATERIALS: ApplyDecal(parentPath,textureId,face?)->path ApplyTexture(parentPath,textureId,face?)->path

MARKETPLACE: InsertAsset(assetId,parentPath?)->"Inserted" InsertMesh(parentPath,meshId,textureId?,name?)->path

TEAMS: CreateTeam(name,color?,autoAssignable?)->path SetPlayerTeam(playerName,teamName)->"Set" GetPlayerTeam(playerName)->string|nil

LEADERSTATS: CreateLeaderstat(playerName,statName,valueType?,initialValue?)->path SetLeaderstatValue(playerName,statName,value)->"Set" GetLeaderstatValue(playerName,statName)->any

MODEL: GetBoundingBox(path)->{cframe,size} GetExtentsSize(path)->vec3 ScaleTo(path,scale)->"Scaled" GetScale(path)->number TranslateBy(path,offset[3])->"Translated" SetPrimaryPart(path,primaryPartPath)->"Set" GetPrimaryPart(path)->path|nil

RUNSERVICE: IsStudio()->bool IsRunMode()->bool IsEdit()->bool IsRunning()->bool GetServerTimeNow()->number GetRealPhysicsFPS()->number`;

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
      return typeof result === "string" ? result : JSON.stringify(result);
    },
  });
}
