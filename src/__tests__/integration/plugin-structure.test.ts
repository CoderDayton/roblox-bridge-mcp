import { describe, test, expect } from "bun:test";
import { readFileSync, existsSync } from "fs";
import { join } from "path";

const PLUGIN_ROOT = join(process.cwd(), "plugin/roblox-bridge");
const PROJECT_ROOT = process.cwd();

/**
 * Expected 205 methods from TypeScript METHODS array in src/tools/roblox-tools.ts
 */
const EXPECTED_METHODS = [
  // Instance Management
  "CreateInstance",
  "DeleteInstance",
  "ClearAllChildren",
  "CloneInstance",
  "RenameInstance",
  // Discovery
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
  // Assembly
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
  // Environment
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
  // Animation
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
  // Raycasting
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
  // Model
  "GetBoundingBox",
  "GetExtentsSize",
  "ScaleTo",
  "GetScale",
  "TranslateBy",
  "SetPrimaryPart",
  "GetPrimaryPart",
  // RunService
  "IsStudio",
  "IsRunMode",
  "IsEdit",
  "IsRunning",
  // Workspace
  "GetServerTimeNow",
  "GetRealPhysicsFPS",
] as const;

describe("Plugin Structure", () => {
  describe("Required Files", () => {
    const requiredFiles = [
      "init.server.lua",
      "utils/path.lua",
      "utils/sandbox.lua",
      "utils/websocket.lua",
      "utils/services.lua",
      "utils/ui.lua",
      "tools/instance.lua",
      "tools/spatial.lua",
      "tools/visual.lua",
      "tools/scripting.lua",
      "tools/players.lua",
      "tools/world.lua",
      "tools/async.lua",
    ];

    for (const file of requiredFiles) {
      test(`${file} exists`, () => {
        expect(existsSync(join(PLUGIN_ROOT, file))).toBe(true);
      });
    }
  });

  describe("Tool Methods", () => {
    test("expected 205 methods defined", () => {
      expect(EXPECTED_METHODS.length).toBe(205);
    });

    test("all methods implemented in Lua", () => {
      const toolFiles = ["instance", "spatial", "visual", "scripting", "players", "world", "async"];
      const implementedMethods = new Set<string>();

      for (const toolFile of toolFiles) {
        const filePath = join(PLUGIN_ROOT, `tools/${toolFile}.lua`);
        const content = readFileSync(filePath, "utf-8");
        const matches = content.matchAll(/function\s+Tools\.(\w+)/g);
        for (const match of matches) {
          implementedMethods.add(match[1]);
        }
      }

      const missing = EXPECTED_METHODS.filter((m) => !implementedMethods.has(m));

      expect(missing).toEqual([]);
      expect(implementedMethods.size).toBeGreaterThanOrEqual(200);
    });
  });

  describe("Lua Syntax Validation", () => {
    const luaFiles = [
      "init.server.lua",
      "utils/path.lua",
      "utils/sandbox.lua",
      "utils/websocket.lua",
      "utils/services.lua",
      "utils/ui.lua",
      "tools/instance.lua",
      "tools/spatial.lua",
      "tools/visual.lua",
      "tools/scripting.lua",
      "tools/players.lua",
      "tools/world.lua",
      "tools/async.lua",
    ];

    for (const file of luaFiles) {
      test(`${file} has balanced parentheses`, () => {
        const content = readFileSync(join(PLUGIN_ROOT, file), "utf-8");
        const openParens = (content.match(/\(/g) || []).length;
        const closeParens = (content.match(/\)/g) || []).length;
        expect(openParens).toBe(closeParens);
      });

      test(`${file} has balanced brackets`, () => {
        const content = readFileSync(join(PLUGIN_ROOT, file), "utf-8");
        const openBrackets = (content.match(/\[/g) || []).length;
        const closeBrackets = (content.match(/\]/g) || []).length;
        expect(openBrackets).toBe(closeBrackets);
      });

      test(`${file} has balanced braces`, () => {
        const content = readFileSync(join(PLUGIN_ROOT, file), "utf-8");
        const openBraces = (content.match(/\{/g) || []).length;
        const closeBraces = (content.match(/\}/g) || []).length;
        expect(openBraces).toBe(closeBraces);
      });

      test(`${file} has valid Lua content`, () => {
        const content = readFileSync(join(PLUGIN_ROOT, file), "utf-8");
        // Every file should have a return statement or function definitions
        const hasReturn = /\breturn\b/.test(content);
        const hasFunction = /\bfunction\b/.test(content);
        expect(hasReturn || hasFunction).toBe(true);
      });
    }
  });

  describe("Version Consistency", () => {
    test("plugin version matches package.json", () => {
      const pkg = JSON.parse(readFileSync(join(PROJECT_ROOT, "package.json"), "utf-8"));
      const initLua = readFileSync(join(PLUGIN_ROOT, "init.server.lua"), "utf-8");

      const versionMatch = initLua.match(/VERSION\s*=\s*["']([^"']+)["']/);
      expect(versionMatch).not.toBeNull();
      expect(versionMatch![1]).toBe(pkg.version);
    });

    test("CONFIG.VERSION matches VERSION constant", () => {
      const initLua = readFileSync(join(PLUGIN_ROOT, "init.server.lua"), "utf-8");

      const versionMatch = initLua.match(/local VERSION\s*=\s*["']([^"']+)["']/);
      const configVersionMatch = initLua.match(/CONFIG\s*=\s*\{[^}]*VERSION\s*=\s*VERSION/);

      expect(versionMatch).not.toBeNull();
      expect(configVersionMatch).not.toBeNull();
    });
  });

  describe("Module Structure", () => {
    test("init.server.lua requires all tool modules", () => {
      const initLua = readFileSync(join(PLUGIN_ROOT, "init.server.lua"), "utf-8");
      const toolModules = [
        "instance",
        "spatial",
        "visual",
        "scripting",
        "players",
        "world",
        "async",
      ];

      for (const mod of toolModules) {
        expect(initLua).toContain(`script.tools.${mod}`);
      }
    });

    test("init.server.lua requires all utility modules", () => {
      const initLua = readFileSync(join(PLUGIN_ROOT, "init.server.lua"), "utf-8");
      const utilModules = ["services", "path", "ui", "websocket"];

      for (const mod of utilModules) {
        expect(initLua).toContain(`script.utils.${mod}`);
      }
    });

    test("all tool files return Tools table", () => {
      const toolFiles = ["instance", "spatial", "visual", "scripting", "players", "world", "async"];

      for (const toolFile of toolFiles) {
        const content = readFileSync(join(PLUGIN_ROOT, `tools/${toolFile}.lua`), "utf-8");
        expect(content).toMatch(/local\s+Tools\s*=\s*\{\}/);
        expect(content).toMatch(/return\s+Tools\s*$/m);
      }
    });
  });
});
