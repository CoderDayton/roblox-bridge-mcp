#!/usr/bin/env bun
/**
 * Lua Syntax Checker - Validates bracket/end balance with precise tracking
 */

import { readFileSync } from "fs";

const PLUGIN_PATH = "plugin/mcp-bridge-plugin.server.lua";

interface Block {
  type: "function" | "if" | "while" | "for" | "do";
  line: number;
  indent: number;
}

function checkSyntax(content: string): { valid: boolean; errors: string[] } {
  const lines = content.split("\n");
  const errors: string[] = [];
  const stack: Block[] = [];

  for (let i = 0; i < lines.length; i++) {
    const line = lines[i];
    const lineNum = i + 1;

    // Remove comments and strings (simplified)
    const cleanLine = line
      .replace(/--.*$/, "")
      .replace(/"[^"]*"/g, '""')
      .replace(/'[^']*'/g, "''");

    const indent = line.search(/\S/);

    // Count all function occurrences (including inline function())
    const functionMatches = cleanLine.match(/\bfunction\b/g);
    if (functionMatches) {
      for (let j = 0; j < functionMatches.length; j++) {
        stack.push({ type: "function", line: lineNum, indent });
      }
    }

    // Count if...then
    const ifMatches = cleanLine.match(/\bif\b[^\n]*?\bthen\b/g);
    if (ifMatches) {
      for (let j = 0; j < ifMatches.length; j++) {
        stack.push({ type: "if", line: lineNum, indent });
      }
    }

    // Count while...do
    const whileMatches = cleanLine.match(/\bwhile\b[^\n]*?\bdo\b/g);
    if (whileMatches) {
      for (let j = 0; j < whileMatches.length; j++) {
        stack.push({ type: "while", line: lineNum, indent });
      }
    }

    // Count for...do
    const forMatches = cleanLine.match(/\bfor\b[^\n]*?\bdo\b/g);
    if (forMatches) {
      for (let j = 0; j < forMatches.length; j++) {
        stack.push({ type: "for", line: lineNum, indent });
      }
    }

    // Explicit do blocks (standalone)
    if (/^\s*do\s*$/.test(cleanLine)) {
      stack.push({ type: "do", line: lineNum, indent });
    }

    // Count closes
    const endMatches = cleanLine.match(/\bend\b/g);
    if (endMatches) {
      for (let j = 0; j < endMatches.length; j++) {
        if (stack.length === 0) {
          errors.push(`Line ${lineNum}: 'end' without matching block opener`);
        } else {
          const block = stack.pop()!;
        }
      }
    }
  }

  // Check for unclosed blocks
  for (const block of stack) {
    errors.push(`Line ${block.line}: Unclosed '${block.type}' block`);
  }

  return { valid: errors.length === 0, errors };
}

// Main
console.log("Checking Lua syntax...\n");

const content = readFileSync(PLUGIN_PATH, "utf-8");
const { valid, errors } = checkSyntax(content);

if (valid) {
  console.log("✓ Syntax valid: All blocks properly closed");
  process.exit(0);
} else {
  console.log("✗ Syntax errors found:\n");
  for (const error of errors) {
    console.log(`  ${error}`);
  }
  console.log(`\n${errors.length} error(s) total`);
  process.exit(1);
}
