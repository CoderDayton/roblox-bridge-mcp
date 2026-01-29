import { describe, test, expect } from "bun:test";
import { z } from "zod";
import { isVersionCompatible, config } from "../../config";

// Complete METHODS array matching src/tools/roblox-tools.ts (74 methods)
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

const RobloxMethodSchema = z.enum(METHODS);

describe("Tool Parameter Validation", () => {
  describe("method enum", () => {
    test("accepts valid methods", () => {
      expect(() => RobloxMethodSchema.parse("CreateInstance")).not.toThrow();
      expect(() => RobloxMethodSchema.parse("GetChildren")).not.toThrow();
      expect(() => RobloxMethodSchema.parse("SetColor")).not.toThrow();
    });

    test("rejects invalid methods", () => {
      expect(() => RobloxMethodSchema.parse("InvalidMethod")).toThrow();
      expect(() => RobloxMethodSchema.parse("createInstance")).toThrow(); // case sensitive
      expect(() => RobloxMethodSchema.parse("")).toThrow();
    });

    test("has all 74 methods", () => {
      expect(METHODS.length).toBe(74);
    });
  });

  describe("parameter schemas", () => {
    const PathSchema = z.string();
    const Vector3Params = z.object({ x: z.number(), y: z.number(), z: z.number() });
    const ColorParams = z.object({ r: z.number(), g: z.number(), b: z.number() });

    test("validates CreateInstance params", () => {
      const schema = z.object({
        className: z.string(),
        parentPath: PathSchema,
        name: z.string().optional(),
        properties: z.record(z.unknown()).optional(),
      });

      expect(() =>
        schema.parse({
          className: "Part",
          parentPath: "game.Workspace",
        })
      ).not.toThrow();

      expect(() =>
        schema.parse({
          className: "Part",
          parentPath: "game.Workspace",
          name: "MyPart",
          properties: { Anchored: true },
        })
      ).not.toThrow();

      expect(() =>
        schema.parse({
          className: "Part",
          // missing parentPath
        })
      ).toThrow();
    });

    test("validates SetPosition params", () => {
      const schema = z
        .object({
          path: PathSchema,
        })
        .merge(Vector3Params);

      expect(() =>
        schema.parse({
          path: "game.Workspace.Part",
          x: 10,
          y: 5,
          z: 0,
        })
      ).not.toThrow();

      expect(() =>
        schema.parse({
          path: "game.Workspace.Part",
          x: 10,
          // missing y, z
        })
      ).toThrow();
    });

    test("validates SetColor params", () => {
      const schema = z
        .object({
          path: PathSchema,
        })
        .merge(ColorParams);

      expect(() =>
        schema.parse({
          path: "game.Workspace.Part",
          r: 255,
          g: 128,
          b: 0,
        })
      ).not.toThrow();

      expect(() =>
        schema.parse({
          path: "game.Workspace.Part",
          r: 255,
          g: 128,
          // missing b
        })
      ).toThrow();
    });

    test("validates array parameters", () => {
      const positionArraySchema = z.array(z.number()).length(3);

      expect(() => positionArraySchema.parse([10, 5, 0])).not.toThrow();
      expect(() => positionArraySchema.parse([10, 5])).toThrow(); // too short
      expect(() => positionArraySchema.parse([10, 5, 0, 1])).toThrow(); // too long
    });

    test("validates optional parameters", () => {
      const schema = z.object({
        path: PathSchema,
        recursive: z.boolean().optional(),
      });

      expect(() => schema.parse({ path: "game.Workspace" })).not.toThrow();
      expect(() => schema.parse({ path: "game.Workspace", recursive: true })).not.toThrow();
    });

    test("validates enum parameters", () => {
      const scriptTypeSchema = z.enum(["Script", "LocalScript", "ModuleScript"]);

      expect(() => scriptTypeSchema.parse("Script")).not.toThrow();
      expect(() => scriptTypeSchema.parse("LocalScript")).not.toThrow();
      expect(() => scriptTypeSchema.parse("InvalidScript")).toThrow();
    });
  });

  describe("params object validation", () => {
    const ToolSchema = z.object({
      method: RobloxMethodSchema,
      params: z.record(z.unknown()).default({}),
    });

    test("accepts valid tool calls", () => {
      expect(() =>
        ToolSchema.parse({
          method: "CreateInstance",
          params: { className: "Part", parentPath: "game.Workspace" },
        })
      ).not.toThrow();
    });

    test("defaults empty params to empty object", () => {
      const result = ToolSchema.parse({
        method: "GetSelection",
      });

      expect(result.params).toEqual({});
    });

    test("rejects invalid method", () => {
      expect(() =>
        ToolSchema.parse({
          method: "InvalidMethod",
          params: {},
        })
      ).toThrow();
    });
  });
});

describe("Version Compatibility", () => {
  test("config has version defined", () => {
    expect(config.version).toBeDefined();
    expect(typeof config.version).toBe("string");
    expect(config.version).toMatch(/^\d+\.\d+\.\d+$/);
  });

  test("accepts matching major.minor versions", () => {
    // Same version should be compatible
    expect(isVersionCompatible(config.version)).toBe(true);
  });

  test("accepts different patch versions", () => {
    // Different patch versions should be compatible (1.1.0 vs 1.1.5)
    const [major, minor] = config.version.split(".");
    expect(isVersionCompatible(`${major}.${minor}.0`)).toBe(true);
    expect(isVersionCompatible(`${major}.${minor}.5`)).toBe(true);
    expect(isVersionCompatible(`${major}.${minor}.99`)).toBe(true);
  });

  test("rejects different minor versions", () => {
    const [major, minor] = config.version.split(".");
    const differentMinor = parseInt(minor) + 1;
    expect(isVersionCompatible(`${major}.${differentMinor}.0`)).toBe(false);
  });

  test("rejects different major versions", () => {
    const [major] = config.version.split(".");
    const differentMajor = parseInt(major) + 1;
    expect(isVersionCompatible(`${differentMajor}.0.0`)).toBe(false);
  });

  test("rejects malformed version strings", () => {
    expect(isVersionCompatible("")).toBe(false);
    expect(isVersionCompatible("1")).toBe(false);
    expect(isVersionCompatible("invalid")).toBe(false);
  });
});
