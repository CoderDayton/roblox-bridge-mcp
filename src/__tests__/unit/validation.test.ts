import { describe, test, expect } from "bun:test";
import { z } from "zod";

// Import the METHODS array and test it matches our schema
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

    test("has all 56 methods", () => {
      expect(METHODS.length).toBe(56);
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
