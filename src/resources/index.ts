import type { FastMCP } from "fastmcp";
import { bridge, getActiveBridgePort } from "../utils/bridge";
import { config } from "../config";

/** All available Roblox methods with descriptions */
const METHODS = {
  // Instance management
  CreateInstance: "Create a new Roblox instance (className, parentPath, name?, properties?)",
  DeleteInstance: "Delete an instance at the specified path",
  CloneInstance: "Clone an instance to a new parent (path, parentPath?)",
  RenameInstance: "Rename an instance (path, newName)",

  // Instance discovery & info
  GetFullName: "Get the full path of an instance (path)",
  GetParent: "Get the parent of an instance (path)",
  IsA: "Check if instance is of a class (path, className)",
  GetClassName: "Get the class name of an instance (path)",
  WaitForChild: "Wait for a child to exist (path, name, timeout?)",

  // Properties
  SetProperty: "Set a property on an instance (path, property, value)",
  GetProperty: "Get a property value from an instance (path, property)",

  // Hierarchy
  GetChildren: "Get direct children of an instance (path)",
  GetDescendants: "Get all descendants of an instance (path)",
  FindFirstChild: "Find a child by name (path, name, recursive?)",
  GetService: "Get a Roblox service (service)",

  // Transforms
  MoveTo: "Move instance to position (path, position[x,y,z])",
  SetPosition: "Set absolute position (path, x, y, z)",
  GetPosition: "Get position as [x, y, z] (path)",
  SetRotation: "Set rotation in degrees (path, x, y, z)",
  GetRotation: "Get rotation as [x, y, z] (path)",
  SetSize: "Set size (path, x, y, z)",
  GetSize: "Get size as [x, y, z] (path)",
  PivotTo: "Set CFrame via 12-element array (path, cframe[12])",
  GetPivot: "Get CFrame as 12-element array (path)",

  // Appearance
  SetColor: "Set BrickColor or Color3 (path, color)",
  SetTransparency: "Set transparency 0-1 (path, transparency)",
  SetMaterial: "Set material enum (path, material)",

  // Physics
  SetAnchored: "Set anchored state (path, anchored)",
  SetCanCollide: "Set collision state (path, canCollide)",
  CreateConstraint:
    "Create physics constraint (type, attachment0Path, attachment1Path, properties?)",
  SetPhysicalProperties: "Set custom physical properties (path, density?, friction?, elasticity?)",
  GetMass: "Get mass of a part (path)",

  // Scripting
  CreateScript: "Create a script (parentPath, source, scriptType?, name?)",
  GetScriptSource: "Get script source code (path)",
  SetScriptSource: "Replace entire script source (path, source)",
  AppendToScript: "Append code to script (path, code)",
  ReplaceScriptLines: "Replace specific lines (path, startLine, endLine, newCode)",
  InsertScriptLines: "Insert lines at position (path, atLine, code)",
  RunConsoleCommand: "Execute Lua in command bar (command)",

  // Selection
  GetSelection: "Get currently selected instances",
  SetSelection: "Set selection to specific paths (paths[])",
  ClearSelection: "Clear all selection",
  AddToSelection: "Add instance to selection (path)",
  GroupSelection: "Group selected instances into Model (name?)",
  UngroupModel: "Ungroup a model (path)",

  // Lighting
  SetTimeOfDay: "Set time of day (time string)",
  SetBrightness: "Set lighting brightness (brightness)",
  SetAtmosphereDensity: "Set atmosphere density (density)",
  CreateLight: "Create light instance (parentPath, lightType, properties?)",

  // Attributes & Tags
  SetAttribute: "Set instance attribute (path, name, value)",
  GetAttribute: "Get instance attribute (path, name)",
  GetAttributes: "Get all attributes on instance (path)",
  AddTag: "Add CollectionService tag (path, tag)",
  RemoveTag: "Remove CollectionService tag (path, tag)",
  GetTags: "Get all tags on instance (path)",
  HasTag: "Check if instance has tag (path, tag)",

  // Players
  GetPlayers: "Get list of players in game",
  GetPlayerPosition: "Get player character position (playerName)",
  TeleportPlayer: "Teleport player to position (playerName, x, y, z)",
  KickPlayer: "Kick player from game (playerName, reason?)",

  // Place
  SavePlace: "Save the current place",
  GetPlaceInfo: "Get place name, ID, and metadata",

  // Audio
  PlaySound: "Play a sound (soundId, parentPath?, properties?)",
  StopSound: "Stop a playing sound (path)",

  // Terrain
  FillTerrain: "Fill terrain region with material (material, minX, minY, minZ, maxX, maxY, maxZ)",
  ClearTerrain: "Clear all terrain",

  // Camera
  SetCameraPosition: "Move workspace camera (x, y, z)",
  SetCameraFocus: "Focus camera on instance (path)",
  GetCameraPosition: "Get current camera position as [x, y, z]",

  // Utilities
  GetDistance: "Get distance between two instances (path1, path2)",
  HighlightObject: "Add highlight effect to instance (path, color?, duration?)",
  Chat: "Send chat message (message)",

  // History
  Undo: "Undo last action in Studio",
  Redo: "Redo last undone action in Studio",

  // Animation & Character
  PlayAnimation: "Play an animation on humanoid (path, animationId)",
  LoadAnimation: "Load an animation track (path, animationId)",
  StopAnimation: "Stop playing animation (path)",
  SetCharacterAppearance: "Set character appearance asset (playerPath, assetId)",
  GetCharacter: "Get player's character instance (playerName)",

  // GUI
  CreateGuiElement: "Create a GUI element (className, parentPath, name?, properties?)",
  SetGuiText: "Set text property of GUI element (path, text)",
  SetGuiSize: "Set size of GUI element (path, size[2])",
  SetGuiPosition: "Set position of GUI element (path, position[2])",
  SetGuiVisible: "Set visible property of GUI element (path, visible)",
  DestroyGuiElement: "Destroy a GUI element (path)",

  // Networking
  FireRemoteEvent: "Fire a remote event (path, args[])",
  InvokeRemoteFunction: "Invoke a remote function (path, args[])",
  CreateRemoteEvent: "Create a remote event (name, parentPath?)",
  CreateRemoteFunction: "Create a remote function (name, parentPath?)",

  // DataStore
  GetDataStore: "Get a data store instance (name)",
  SetDataStoreValue: "Set value in data store (storeName, key, value)",
  GetDataStoreValue: "Get value from data store (storeName, key)",
  RemoveDataStoreValue: "Remove value from data store (storeName, key)",

  // Tween
  CreateTween: "Create tween animation (path, targetProperties, duration?)",
  TweenProperty: "Tween a single property (path, property, endValue, duration?)",

  // Raycasting
  Raycast: "Cast a ray from point (origin[3], direction[3], params?)",
  RaycastTo: "Raycast from one object to another (path, targetPath, params?)",

  // Constraints
  CreateWeld: "Create weld constraint (part0Path, part1Path, properties?)",
  CreateMotor6D: "Create Motor6D constraint (part0Path, part1Path, properties?)",

  // Particles
  CreateParticleEmitter: "Create particle emitter (path, properties?)",
  EmitParticles: "Emit particles from emitter (path, count?)",

  // Materials
  ApplyDecal: "Apply decal texture (path, texture, parentPath?)",
  ApplyTexture: "Apply texture (path, texture, parentPath?)",

  // Camera
  SetCameraType: "Set camera type (cameraType)",
  ZoomCamera: "Zoom camera by amount (amount)",
  GetCameraType: "Get current camera type ()",

  // Marketplace
  InsertAsset: "Insert asset from marketplace (assetId, parentPath?)",
  InsertMesh: "Insert mesh part (meshId, parentPath?)",

  // Teams
  CreateTeam: "Create a team (name, color?)",
  SetPlayerTeam: "Set player's team (playerName, teamName)",
  GetPlayerTeam: "Get player's team (playerName)",

  // Leaderstats
  CreateLeaderstat: "Create a leaderstat value (name, parentPath?)",
  SetLeaderstatValue: "Set leaderstat value (path, value)",
  GetLeaderstatValue: "Get leaderstat value (path)",
} as const;

/** Register all MCP resources */
export function registerResources(server: FastMCP): void {
  // Bridge status resource - shows connection state and diagnostics
  server.addResource({
    uri: "roblox://bridge/status",
    name: "Bridge Status",
    description: "Current bridge server status, connection state, and diagnostics",
    mimeType: "application/json",
    async load() {
      const port = getActiveBridgePort();
      const connected = bridge.isConnected();
      const connInfo = bridge.getConnectionInfo();

      const status = {
        bridge: {
          running: port !== null,
          port,
          preferredPort: config.bridgePort,
          usingFallback: port !== null && port !== config.bridgePort,
        },
        connection: {
          pluginConnected: connected,
          httpPolling: connInfo.httpConnected,
          websocketClients: connInfo.wsClients,
          pendingCommands: bridge.pendingCount,
          status: !port ? "bridge_not_running" : connected ? "connected" : "waiting_for_plugin",
        },
        metrics: bridge.getMetrics(),
        config: {
          timeout: config.timeout,
          retries: config.retries,
        },
        uptime: process.uptime(),
      };

      return {
        text: JSON.stringify(status, null, 2),
      };
    },
  });

  // Capabilities resource - lists all available methods
  server.addResource({
    uri: "roblox://capabilities",
    name: "Roblox Capabilities",
    description: "List of all available Roblox methods and their parameters",
    mimeType: "application/json",
    async load() {
      const capabilities = {
        totalMethods: Object.keys(METHODS).length,
        methods: METHODS,
        categories: {
          "Instance Management": [
            "CreateInstance",
            "DeleteInstance",
            "CloneInstance",
            "RenameInstance",
          ],
          "Instance Discovery": ["GetFullName", "GetParent", "IsA", "GetClassName", "WaitForChild"],
          Properties: ["SetProperty", "GetProperty"],
          Hierarchy: ["GetChildren", "GetDescendants", "FindFirstChild", "GetService"],
          Transforms: [
            "MoveTo",
            "SetPosition",
            "GetPosition",
            "SetRotation",
            "GetRotation",
            "SetSize",
            "GetSize",
            "PivotTo",
            "GetPivot",
          ],
          Appearance: ["SetColor", "SetTransparency", "SetMaterial"],
          Physics: [
            "SetAnchored",
            "SetCanCollide",
            "CreateConstraint",
            "SetPhysicalProperties",
            "GetMass",
          ],
          Scripting: [
            "CreateScript",
            "GetScriptSource",
            "SetScriptSource",
            "AppendToScript",
            "ReplaceScriptLines",
            "InsertScriptLines",
            "RunConsoleCommand",
          ],
          Selection: [
            "GetSelection",
            "SetSelection",
            "ClearSelection",
            "AddToSelection",
            "GroupSelection",
            "UngroupModel",
          ],
          Lighting: ["SetTimeOfDay", "SetBrightness", "SetAtmosphereDensity", "CreateLight"],
          "Attributes & Tags": [
            "SetAttribute",
            "GetAttribute",
            "GetAttributes",
            "AddTag",
            "RemoveTag",
            "GetTags",
            "HasTag",
          ],
          Players: ["GetPlayers", "GetPlayerPosition", "TeleportPlayer", "KickPlayer"],
          Place: ["SavePlace", "GetPlaceInfo"],
          Audio: ["PlaySound", "StopSound"],
          Terrain: ["FillTerrain", "ClearTerrain"],
          Camera: [
            "SetCameraPosition",
            "SetCameraFocus",
            "GetCameraPosition",
            "SetCameraType",
            "ZoomCamera",
            "GetCameraType",
          ],
          Utilities: ["GetDistance", "HighlightObject", "Chat"],
          History: ["Undo", "Redo"],
          "Animation & Character": [
            "PlayAnimation",
            "LoadAnimation",
            "StopAnimation",
            "SetCharacterAppearance",
            "GetCharacter",
          ],
          GUI: [
            "CreateGuiElement",
            "SetGuiText",
            "SetGuiSize",
            "SetGuiPosition",
            "SetGuiVisible",
            "DestroyGuiElement",
          ],
          Networking: [
            "FireRemoteEvent",
            "InvokeRemoteFunction",
            "CreateRemoteEvent",
            "CreateRemoteFunction",
          ],
          DataStore: [
            "GetDataStore",
            "SetDataStoreValue",
            "GetDataStoreValue",
            "RemoveDataStoreValue",
          ],
          Tween: ["CreateTween", "TweenProperty"],
          Raycasting: ["Raycast", "RaycastTo"],
          Constraints: ["CreateWeld", "CreateMotor6D"],
          Particles: ["CreateParticleEmitter", "EmitParticles"],
          Materials: ["ApplyDecal", "ApplyTexture"],
          Marketplace: ["InsertAsset", "InsertMesh"],
          Teams: ["CreateTeam", "SetPlayerTeam", "GetPlayerTeam"],
          Leaderstats: ["CreateLeaderstat", "SetLeaderstatValue", "GetLeaderstatValue"],
        },
      };

      return {
        text: JSON.stringify(capabilities, null, 2),
      };
    },
  });
}
