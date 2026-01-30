import { describe, test, expect } from "bun:test";
import { readFileSync, readdirSync, statSync } from "fs";
import { join } from "path";

const PLUGIN_ROOT = join(process.cwd(), "plugin");

/**
 * Recursively collect all .lua files from a directory
 */
function getAllLuaFiles(dir: string): string[] {
  const files: string[] = [];
  const entries = readdirSync(dir, { withFileTypes: true });
  for (const entry of entries) {
    const fullPath = join(dir, entry.name);
    if (entry.isDirectory()) {
      files.push(...getAllLuaFiles(fullPath));
    } else if (entry.name.endsWith(".lua")) {
      files.push(fullPath);
    }
  }
  return files;
}

/**
 * Count occurrences of a pattern in a string
 */
function countPattern(content: string, pattern: RegExp): number {
  return (content.match(pattern) || []).length;
}

/**
 * Remove comments and strings from Lua content to avoid false positives
 */
function cleanLuaContent(content: string): string {
  return content
    .replace(/--\[\[[\s\S]*?\]\]/g, "") // multiline comments
    .replace(/--[^\n]*/g, "") // single line comments
    .replace(/\[\[[\s\S]*?\]\]/g, '""') // multiline strings
    .replace(/"(?:[^"\\]|\\.)*"/g, '""') // double quoted strings
    .replace(/'(?:[^'\\]|\\.)*'/g, "''"); // single quoted strings
}

/**
 * Get relative path for cleaner test names
 */
function relativePath(file: string): string {
  return file.replace(PLUGIN_ROOT, "");
}

describe("Lua Syntax Validation", () => {
  let luaFiles: string[];

  try {
    luaFiles = getAllLuaFiles(PLUGIN_ROOT);
  } catch {
    luaFiles = [];
  }

  if (luaFiles.length === 0) {
    test.skip("No Lua files found in plugin directory", () => {});
    return;
  }

  describe("Balanced Blocks", () => {
    for (const file of luaFiles) {
      test(`${relativePath(file)} has balanced blocks`, () => {
        const content = readFileSync(file, "utf-8");
        const cleaned = cleanLuaContent(content);

        const functionCount = countPattern(cleaned, /\bfunction\b/g);
        const ifCount = countPattern(cleaned, /\bif\b/g);
        const forCount = countPattern(cleaned, /\bfor\b/g);
        const whileCount = countPattern(cleaned, /\bwhile\b/g);
        const repeatCount = countPattern(cleaned, /\brepeat\b/g);

        const endCount = countPattern(cleaned, /\bend\b/g);
        const untilCount = countPattern(cleaned, /\buntil\b/g);

        const blockStarters = functionCount + ifCount + forCount + whileCount;
        const blockEnders = endCount;

        // repeat-until uses until instead of end
        expect(repeatCount).toBe(untilCount);

        // endCount should be >= blockStarters
        expect(blockEnders).toBeGreaterThanOrEqual(blockStarters);
      });
    }
  });

  describe("Balanced Braces", () => {
    for (const file of luaFiles) {
      test(`${relativePath(file)} has balanced curly braces`, () => {
        const content = readFileSync(file, "utf-8");
        const cleaned = cleanLuaContent(content);

        const openBraces = countPattern(cleaned, /\{/g);
        const closeBraces = countPattern(cleaned, /\}/g);

        expect(openBraces).toBe(closeBraces);
      });

      test(`${relativePath(file)} has balanced parentheses`, () => {
        const content = readFileSync(file, "utf-8");
        const cleaned = cleanLuaContent(content);

        const openParens = countPattern(cleaned, /\(/g);
        const closeParens = countPattern(cleaned, /\)/g);

        expect(openParens).toBe(closeParens);
      });

      test(`${relativePath(file)} has balanced square brackets`, () => {
        const content = readFileSync(file, "utf-8");
        const cleaned = cleanLuaContent(content);

        const openBrackets = countPattern(cleaned, /\[/g);
        const closeBrackets = countPattern(cleaned, /\]/g);

        expect(openBrackets).toBe(closeBrackets);
      });
    }
  });

  describe("Module Exports", () => {
    for (const file of luaFiles) {
      if (file.includes("init.server.lua")) continue;

      test(`${relativePath(file)} has return statement`, () => {
        const content = readFileSync(file, "utf-8");
        const cleanedForReturn = cleanLuaContent(content);
        expect(cleanedForReturn).toMatch(/\breturn\b/);
      });
    }
  });

  describe("Module Structure", () => {
    for (const file of luaFiles) {
      if (!file.includes("/tools/")) continue;

      test(`${relativePath(file)} exports a Tools table`, () => {
        const content = readFileSync(file, "utf-8");

        expect(content).toMatch(/local\s+Tools\s*=\s*\{\}/);
        expect(content).toMatch(/return\s+Tools/);
      });
    }
  });

  describe("Security Patterns", () => {
    for (const file of luaFiles) {
      test(`${relativePath(file)} has no dangerous os functions`, () => {
        const content = readFileSync(file, "utf-8");

        expect(content).not.toMatch(/os\.execute/);
        expect(content).not.toMatch(/io\.popen/);
        expect(content).not.toMatch(/loadfile\s*\([^"']/);
        expect(content).not.toMatch(/\bdofile\b/);
      });

      test(`${relativePath(file)} has no hardcoded external URLs`, () => {
        const content = readFileSync(file, "utf-8");

        const urlMatches = content.match(/https?:\/\/[^\s"']+/g) || [];

        for (const url of urlMatches) {
          const isLocalhost = url.includes("localhost") || url.includes("127.0.0.1");
          expect(isLocalhost).toBe(true);
        }
      });

      test(`${relativePath(file)} has no hardcoded secrets`, () => {
        const content = readFileSync(file, "utf-8");
        const cleaned = cleanLuaContent(content);

        expect(cleaned).not.toMatch(/api[_-]?key\s*=\s*["'][a-zA-Z0-9]{20,}["']/i);
        expect(cleaned).not.toMatch(/password\s*=\s*["'][^"']+["']/i);
        expect(cleaned).not.toMatch(/bearer\s+[a-zA-Z0-9._-]{20,}/i);
      });
    }
  });

  describe("Common Syntax Errors", () => {
    for (const file of luaFiles) {
      test(`${relativePath(file)} has no function()end without space`, () => {
        const content = readFileSync(file, "utf-8");
        const cleaned = cleanLuaContent(content);

        expect(cleaned).not.toMatch(/function\s*\([^)]*\)end/);
      });

      test(`${relativePath(file)} has no double operators`, () => {
        const content = readFileSync(file, "utf-8");
        const cleaned = cleanLuaContent(content);

        expect(cleaned).not.toMatch(/\+\+(?!])/);
        expect(cleaned).not.toMatch(/\*\*/);
      });
    }
  });

  describe("String Closure", () => {
    for (const file of luaFiles) {
      test(`${relativePath(file)} has properly closed strings`, () => {
        const content = readFileSync(file, "utf-8");

        const noComments = content.replace(/--\[\[[\s\S]*?\]\]/g, "").replace(/--[^\n]*/g, "");

        const lines = noComments.split("\n");
        for (const line of lines) {
          if (line.includes("[[") || line.includes("]]")) continue;

          const doubleQuotes =
            (line.match(/(?<!\\)"/g) || []).length - (line.match(/\\"/g) || []).length;
          const singleQuotes =
            (line.match(/(?<!\\)'/g) || []).length - (line.match(/\\'/g) || []).length;

          expect(doubleQuotes % 2).toBe(0);
          expect(singleQuotes % 2).toBe(0);
        }
      });
    }
  });

  describe("File Statistics", () => {
    test("plugin directory contains Lua files", () => {
      expect(luaFiles.length).toBeGreaterThan(0);
    });

    test("all Lua files are non-empty", () => {
      for (const file of luaFiles) {
        const stats = statSync(file);
        expect(stats.size).toBeGreaterThan(0);
      }
    });
  });
});
