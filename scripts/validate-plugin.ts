#!/usr/bin/env bun
/**
 * Lua Plugin Validator
 * Checks for common issues in Roblox Lua plugins without needing Lua installed
 */

import { readFileSync } from "fs";

const PLUGIN_PATH = "plugin/mcp-bridge-plugin.server.lua";

interface Issue {
  line: number;
  type: "error" | "warning";
  message: string;
}

function validatePlugin(content: string): Issue[] {
  const lines = content.split("\n");
  const issues: Issue[] = [];

  // Track defined locals and functions
  const definedLocals = new Set<string>();
  const definedFunctions = new Set<string>();
  const usedBeforeDefined: Map<string, number> = new Map();

  // Track scope depth for proper analysis
  let scopeDepth = 0;
  let inFunction = false;
  let currentFunction = "";

  // Patterns
  const localVarPattern = /^[\t ]*local\s+(\w+)\s*=/;
  const localFuncPattern = /^[\t ]*local\s+function\s+(\w+)/;
  const funcPattern = /^[\t ]*function\s+(\w+)/;
  const funcCallPattern = /(\w+)\s*\(/g;
  const methodCallPattern = /(\w+):(\w+)\s*\(/g;
  const nilIndexPattern = /(\w+)\.(\w+)/g;
  const requirePattern = /require\s*\(\s*(\w+)/;

  for (let i = 0; i < lines.length; i++) {
    const line = lines[i];
    const lineNum = i + 1;

    // Track local variable definitions
    const localMatch = line.match(localVarPattern);
    if (localMatch) {
      definedLocals.add(localMatch[1]);
    }

    // Track local function definitions
    const localFuncMatch = line.match(localFuncPattern);
    if (localFuncMatch) {
      definedFunctions.add(localFuncMatch[1]);
      definedLocals.add(localFuncMatch[1]);
    }

    // Track function definitions
    const funcMatch = line.match(funcPattern);
    if (funcMatch && !localFuncMatch) {
      definedFunctions.add(funcMatch[1]);
    }

    // Check for common issues

    // 1. Using '...' outside vararg function
    if (line.includes("...") && !line.includes("function") && !line.includes("--")) {
      // Check if we're in a vararg context
      if (!line.includes("ipairs") && !line.includes("pairs") && !line.includes("string")) {
        // Look back to see if current function is vararg
        let isVararg = false;
        for (let j = i - 1; j >= 0 && j > i - 50; j--) {
          if (lines[j].includes("function") && lines[j].includes("...")) {
            isVararg = true;
            break;
          }
          if (lines[j].match(/^[\t ]*function\s/) && !lines[j].includes("...")) {
            break;
          }
        }
        if (!isVararg && line.includes("select") && line.includes("...")) {
          issues.push({
            line: lineNum,
            type: "error",
            message: "Using '...' (vararg) potentially outside vararg function",
          });
        }
      }
    }

    // 2. Calling undefined function
    let match;
    funcCallPattern.lastIndex = 0;
    while ((match = funcCallPattern.exec(line)) !== null) {
      const funcName = match[1];
      // Skip common globals and methods
      const globals = [
        "print",
        "warn",
        "error",
        "pcall",
        "xpcall",
        "require",
        "type",
        "typeof",
        "tostring",
        "tonumber",
        "pairs",
        "ipairs",
        "next",
        "select",
        "setmetatable",
        "getmetatable",
        "rawget",
        "rawset",
        "table",
        "string",
        "math",
        "os",
        "task",
        "game",
        "workspace",
        "script",
        "plugin",
        "Instance",
        "Vector3",
        "Vector2",
        "CFrame",
        "Color3",
        "UDim",
        "UDim2",
        "Enum",
        "TweenInfo",
        "Font",
        "DockWidgetPluginGuiInfo",
        "PhysicalProperties",
        "Region3",
        "loadstring",
        "setfenv",
        "getfenv",
      ];
      if (
        !globals.includes(funcName) &&
        !definedFunctions.has(funcName) &&
        !definedLocals.has(funcName) &&
        !funcName.startsWith("_") &&
        funcName[0] === funcName[0].toLowerCase()
      ) {
        // Check if it's defined later
        usedBeforeDefined.set(funcName, lineNum);
      }
    }

    // 3. Indexing potentially nil value
    if (line.includes(":FindFirstChild") && line.includes(".")) {
      const afterFind = line.split(":FindFirstChild")[1];
      if (afterFind && (afterFind.includes(".") || afterFind.includes(":"))) {
        if (!line.includes("if ") && !line.includes("and ")) {
          issues.push({
            line: lineNum,
            type: "warning",
            message: "Indexing result of FindFirstChild without nil check",
          });
        }
      }
    }

    // 4. Missing task.wait in while true loop
    if (line.includes("while true do") || line.includes("while true do")) {
      // Look ahead for task.wait
      let hasWait = false;
      let depth = 1;
      for (let j = i + 1; j < lines.length && depth > 0; j++) {
        if (lines[j].includes("do") || lines[j].includes("then") || lines[j].includes("function")) {
          depth++;
        }
        if (lines[j].includes("end")) {
          depth--;
        }
        if (lines[j].includes("task.wait") || lines[j].includes("wait(")) {
          hasWait = true;
          break;
        }
        if (depth === 0) break;
      }
      if (!hasWait) {
        issues.push({
          line: lineNum,
          type: "error",
          message: "while true loop without task.wait() - will cause script timeout",
        });
      }
    }

    // 5. Check for continue without being in a loop
    if (line.trim() === "continue") {
      // Look back for loop
      let inLoop = false;
      let depth = 0;
      for (let j = i - 1; j >= 0; j--) {
        if (lines[j].includes("end")) depth++;
        if (lines[j].includes("do")) depth--;
        if (depth < 0 && (lines[j].includes("while") || lines[j].includes("for"))) {
          inLoop = true;
          break;
        }
      }
      if (!inLoop) {
        issues.push({
          line: lineNum,
          type: "error",
          message: "'continue' used outside of loop",
        });
      }
    }

    // 6. Using undefined variable in callback before it's assigned
    if (line.includes("onClick = function()") || line.includes("onClick=function()")) {
      // Check for self-reference in upcoming lines
      const varMatch = lines
        .slice(Math.max(0, i - 5), i)
        .join("\n")
        .match(/local\s+(\w+)\s*\n.*\1\s*=\s*create/);
      if (!varMatch) {
        // Check if using a variable that's being defined in this block
        for (let j = i + 1; j < Math.min(i + 20, lines.length); j++) {
          if (lines[j].includes("end,") || lines[j].includes("end)")) break;
          const selfRefMatch = lines[j].match(/(\w+):FindFirstChild|(\w+)\.(\w+)/);
          if (selfRefMatch) {
            const refVar = selfRefMatch[1] || selfRefMatch[2];
            // Check if this var is being defined in surrounding context
            for (let k = i - 3; k < i; k++) {
              if (k >= 0 && lines[k].includes(`local ${refVar}`) && !lines[k].includes("=")) {
                // Forward declaration found, OK
                break;
              }
              if (k >= 0 && lines[k].includes(`${refVar} = create`)) {
                issues.push({
                  line: j + 1,
                  type: "error",
                  message: `Variable '${refVar}' used in callback before assignment completes`,
                });
              }
            }
          }
        }
      }
    }

    // 7. props.X vs X - using unpassed props
    if (line.includes("props.") && inFunction) {
      const propsMatch = line.match(/props\.(\w+)/g);
      if (propsMatch) {
        // This is fine, just informational
      }
    }

    // 8. Calling method on potentially nil
    if (line.match(/\)\s*:/)) {
      issues.push({
        line: lineNum,
        type: "warning",
        message: "Calling method on function result without nil check",
      });
    }
  }

  // Check for functions used before defined
  for (const [funcName, lineNum] of usedBeforeDefined) {
    if (!definedFunctions.has(funcName) && !definedLocals.has(funcName)) {
      issues.push({
        line: lineNum,
        type: "warning",
        message: `Function '${funcName}' may not be defined`,
      });
    }
  }

  return issues;
}

function checkBracketBalance(content: string): Issue[] {
  const issues: Issue[] = [];
  const lines = content.split("\n");

  let doCount = 0;
  let endCount = 0;
  let funcCount = 0;
  let ifCount = 0;

  for (let i = 0; i < lines.length; i++) {
    const line = lines[i].replace(/--.*$/, ""); // Remove comments

    // Count keywords (rough, doesn't handle strings perfectly)
    const dos = (line.match(/\bdo\b/g) || []).length;
    const ends = (line.match(/\bend\b/g) || []).length;
    const funcs = (line.match(/\bfunction\b/g) || []).length;
    const ifs = (line.match(/\bthen\b/g) || []).length;

    doCount += dos;
    endCount += ends;
    funcCount += funcs;
    ifCount += ifs;
  }

  const expectedEnds = doCount + funcCount + ifCount;
  if (endCount !== expectedEnds) {
    issues.push({
      line: 0,
      type: "error",
      message: `Bracket imbalance: ${expectedEnds} 'end' expected (do:${doCount} + function:${funcCount} + if/then:${ifCount}), found ${endCount}`,
    });
  }

  return issues;
}

// Main
console.log("Validating Roblox plugin...\n");

const content = readFileSync(PLUGIN_PATH, "utf-8");
const issues = [...validatePlugin(content), ...checkBracketBalance(content)];

// Sort by line number
issues.sort((a, b) => a.line - b.line);

// Print results
const errors = issues.filter((i) => i.type === "error");
const warnings = issues.filter((i) => i.type === "warning");

if (errors.length > 0) {
  console.log("ERRORS:");
  for (const issue of errors) {
    console.log(`  Line ${issue.line}: ${issue.message}`);
  }
  console.log();
}

if (warnings.length > 0) {
  console.log("WARNINGS:");
  for (const issue of warnings) {
    console.log(`  Line ${issue.line}: ${issue.message}`);
  }
  console.log();
}

console.log(`\nSummary: ${errors.length} errors, ${warnings.length} warnings`);

if (errors.length > 0) {
  process.exit(1);
}
