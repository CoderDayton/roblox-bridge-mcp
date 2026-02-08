import { describe, test, expect } from "bun:test";
import { readFileSync } from "fs";
import { join } from "path";

describe("Version sync", () => {
  const pkgVersion = JSON.parse(
    readFileSync(join(import.meta.dir, "../../../package.json"), "utf-8")
  ).version;

  test("package.json version is valid semver", () => {
    expect(pkgVersion).toMatch(/^\d+\.\d+\.\d+$/);
  });

  test("plugin VERSION matches package.json", () => {
    const initLua = readFileSync(
      join(import.meta.dir, "../../../plugin/roblox-bridge/init.server.lua"),
      "utf-8"
    );
    const match = initLua.match(/local VERSION = "([^"]+)"/);
    expect(match).not.toBeNull();
    expect(match![1]).toBe(pkgVersion);
  });

  test("config.ts reads version from package.json (not hardcoded)", () => {
    const configTs = readFileSync(join(import.meta.dir, "../../config.ts"), "utf-8");
    // Should import from package.json, not hardcode a version string
    expect(configTs).toContain('from "../package.json"');
    expect(configTs).toContain("pkg.version");
    // Should NOT have a hardcoded version assignment
    expect(configTs).not.toMatch(/SERVER_VERSION = "\d+\.\d+\.\d+"/);
  });
});
