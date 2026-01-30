import { describe, test, expect, mock, beforeEach } from "bun:test";
import { registerResources } from "../../resources";
import { bridge } from "../../utils/bridge";
import type { FastMCP } from "fastmcp";

interface ResourceDefinition {
  uri: string;
  name: string;
  description: string;
  mimeType: string;
  load: () => Promise<{ text: string }>;
}

describe("resources", () => {
  let mockServer: Partial<FastMCP>;
  let addedResources: ResourceDefinition[] = [];

  beforeEach(() => {
    addedResources = [];
    mockServer = {
      addResource: mock((resource: ResourceDefinition) => {
        addedResources.push(resource);
      }),
    };
    // Reset bridge for clean state
    (bridge as { resetForTesting?: () => void }).resetForTesting?.();
  });

  describe("registerResources", () => {
    test("adds exactly two resources", () => {
      registerResources(mockServer as FastMCP);

      expect(addedResources).toHaveLength(2);
    });

    test("adds bridge/status resource with correct metadata", () => {
      registerResources(mockServer as FastMCP);

      const statusResource = addedResources.find((r) => r.uri === "roblox://bridge/status");
      expect(statusResource).toBeDefined();
      expect(statusResource!.name).toBe("Bridge Status");
      expect(statusResource!.description).toContain("bridge");
      expect(statusResource!.mimeType).toBe("application/json");
    });

    test("adds capabilities resource with correct metadata", () => {
      registerResources(mockServer as FastMCP);

      const capabilitiesResource = addedResources.find((r) => r.uri === "roblox://capabilities");
      expect(capabilitiesResource).toBeDefined();
      expect(capabilitiesResource!.name).toBe("Roblox Capabilities");
      expect(capabilitiesResource!.description).toContain("methods");
      expect(capabilitiesResource!.mimeType).toBe("application/json");
    });
  });

  describe("bridge/status resource load", () => {
    test("returns valid JSON with bridge section", async () => {
      registerResources(mockServer as FastMCP);

      const statusResource = addedResources.find((r) => r.uri === "roblox://bridge/status");
      const result = await statusResource!.load();

      const parsed = JSON.parse(result.text);
      expect(parsed).toHaveProperty("bridge");
      expect(parsed.bridge).toHaveProperty("running");
      expect(parsed.bridge).toHaveProperty("port");
      expect(parsed.bridge).toHaveProperty("preferredPort");
    });

    test("returns valid JSON with connection section", async () => {
      registerResources(mockServer as FastMCP);

      const statusResource = addedResources.find((r) => r.uri === "roblox://bridge/status");
      const result = await statusResource!.load();

      const parsed = JSON.parse(result.text);
      expect(parsed).toHaveProperty("connection");
      expect(parsed.connection).toHaveProperty("connected");
      expect(parsed.connection).toHaveProperty("clients");
      expect(parsed.connection).toHaveProperty("readyClients");
      expect(parsed.connection).toHaveProperty("pendingCommands");
      expect(parsed.connection).toHaveProperty("status");
    });

    test("returns valid JSON with metrics section", async () => {
      registerResources(mockServer as FastMCP);

      const statusResource = addedResources.find((r) => r.uri === "roblox://bridge/status");
      const result = await statusResource!.load();

      const parsed = JSON.parse(result.text);
      expect(parsed).toHaveProperty("metrics");
      expect(parsed.metrics).toHaveProperty("totalCommands");
      expect(parsed.metrics).toHaveProperty("successCount");
      expect(parsed.metrics).toHaveProperty("failureCount");
      expect(parsed.metrics).toHaveProperty("successRate");
    });

    test("returns valid JSON with config section", async () => {
      registerResources(mockServer as FastMCP);

      const statusResource = addedResources.find((r) => r.uri === "roblox://bridge/status");
      const result = await statusResource!.load();

      const parsed = JSON.parse(result.text);
      expect(parsed).toHaveProperty("config");
      expect(parsed.config).toHaveProperty("timeout");
      expect(parsed.config).toHaveProperty("retries");
    });

    test("returns uptime as number", async () => {
      registerResources(mockServer as FastMCP);

      const statusResource = addedResources.find((r) => r.uri === "roblox://bridge/status");
      const result = await statusResource!.load();

      const parsed = JSON.parse(result.text);
      expect(parsed).toHaveProperty("uptime");
      expect(typeof parsed.uptime).toBe("number");
      expect(parsed.uptime).toBeGreaterThanOrEqual(0);
    });

    test("connection status reflects bridge state when not running", async () => {
      registerResources(mockServer as FastMCP);

      const statusResource = addedResources.find((r) => r.uri === "roblox://bridge/status");
      const result = await statusResource!.load();

      const parsed = JSON.parse(result.text);
      // Bridge not started in test, so should show appropriate status
      expect(parsed.connection.connected).toBe(false);
      expect(parsed.connection.clients).toBe(0);
      expect(parsed.connection.readyClients).toBe(0);
    });
  });

  describe("capabilities resource load", () => {
    test("returns valid JSON with totalMethods", async () => {
      registerResources(mockServer as FastMCP);

      const capabilitiesResource = addedResources.find((r) => r.uri === "roblox://capabilities");
      const result = await capabilitiesResource!.load();

      const parsed = JSON.parse(result.text);
      expect(parsed).toHaveProperty("totalMethods");
      expect(typeof parsed.totalMethods).toBe("number");
      expect(parsed.totalMethods).toBeGreaterThan(0);
    });

    test("returns methods object with descriptions", async () => {
      registerResources(mockServer as FastMCP);

      const capabilitiesResource = addedResources.find((r) => r.uri === "roblox://capabilities");
      const result = await capabilitiesResource!.load();

      const parsed = JSON.parse(result.text);
      expect(parsed).toHaveProperty("methods");
      expect(typeof parsed.methods).toBe("object");

      // Check some expected methods exist
      expect(parsed.methods).toHaveProperty("CreateInstance");
      expect(parsed.methods).toHaveProperty("DeleteInstance");
      expect(parsed.methods).toHaveProperty("GetProperty");
      expect(parsed.methods).toHaveProperty("SetProperty");
    });

    test("returns categories object", async () => {
      registerResources(mockServer as FastMCP);

      const capabilitiesResource = addedResources.find((r) => r.uri === "roblox://capabilities");
      const result = await capabilitiesResource!.load();

      const parsed = JSON.parse(result.text);
      expect(parsed).toHaveProperty("categories");
      expect(typeof parsed.categories).toBe("object");
    });

    test("categories contain expected groups", async () => {
      registerResources(mockServer as FastMCP);

      const capabilitiesResource = addedResources.find((r) => r.uri === "roblox://capabilities");
      const result = await capabilitiesResource!.load();

      const parsed = JSON.parse(result.text);
      const categories = parsed.categories;

      // Check expected category names
      expect(categories).toHaveProperty("Instance Management");
      expect(categories).toHaveProperty("Properties");
      expect(categories).toHaveProperty("Hierarchy");
      expect(categories).toHaveProperty("Transforms");
      expect(categories).toHaveProperty("Scripting");
      expect(categories).toHaveProperty("Physics");
    });

    test("categories contain arrays of method names", async () => {
      registerResources(mockServer as FastMCP);

      const capabilitiesResource = addedResources.find((r) => r.uri === "roblox://capabilities");
      const result = await capabilitiesResource!.load();

      const parsed = JSON.parse(result.text);

      // Instance Management should contain expected methods
      expect(parsed.categories["Instance Management"]).toContain("CreateInstance");
      expect(parsed.categories["Instance Management"]).toContain("DeleteInstance");

      // Properties should contain property methods
      expect(parsed.categories["Properties"]).toContain("SetProperty");
      expect(parsed.categories["Properties"]).toContain("GetProperty");
    });

    test("totalMethods matches actual methods count", async () => {
      registerResources(mockServer as FastMCP);

      const capabilitiesResource = addedResources.find((r) => r.uri === "roblox://capabilities");
      const result = await capabilitiesResource!.load();

      const parsed = JSON.parse(result.text);
      const methodCount = Object.keys(parsed.methods).length;

      expect(parsed.totalMethods).toBe(methodCount);
    });

    test("method descriptions are non-empty strings", async () => {
      registerResources(mockServer as FastMCP);

      const capabilitiesResource = addedResources.find((r) => r.uri === "roblox://capabilities");
      const result = await capabilitiesResource!.load();

      const parsed = JSON.parse(result.text);

      for (const [methodName, description] of Object.entries(parsed.methods)) {
        expect(typeof description).toBe("string");
        expect((description as string).length).toBeGreaterThan(0);
      }
    });
  });

  describe("edge cases", () => {
    test("calling registerResources multiple times adds duplicate resources", () => {
      registerResources(mockServer as FastMCP);
      registerResources(mockServer as FastMCP);

      // Each call adds 2 resources
      expect(addedResources).toHaveLength(4);
    });

    test("resources have unique URIs on single registration", () => {
      registerResources(mockServer as FastMCP);

      const uris = addedResources.map((r) => r.uri);
      const uniqueUris = new Set(uris);

      expect(uniqueUris.size).toBe(uris.length);
    });

    test("load functions are async", () => {
      registerResources(mockServer as FastMCP);

      for (const resource of addedResources) {
        const result = resource.load();
        expect(result).toBeInstanceOf(Promise);
      }
    });
  });
});
