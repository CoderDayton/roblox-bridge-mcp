import { describe, test, expect } from "bun:test";
import { readFileSync, existsSync } from "fs";
import { join } from "path";

const PLUGIN_ROOT = join(process.cwd(), "plugin/roblox-bridge");
const UI_ROOT = join(PLUGIN_ROOT, "ui");
const COMPONENTS_ROOT = join(UI_ROOT, "components");

/**
 * Read a Lua file and return its content
 */
function readLua(path: string): string {
  return readFileSync(path, "utf-8");
}

/**
 * Check if a file exports a module table
 */
function hasModuleExport(content: string, moduleName: string): boolean {
  return content.includes(`local ${moduleName} = {}`) && content.includes(`return ${moduleName}`);
}

/**
 * Check if content has a create function
 */
function hasCreateFunction(content: string, moduleName: string): boolean {
  return content.includes(`function ${moduleName}.create(`);
}

describe("Plugin UI Structure", () => {
  describe("UI Directory Structure", () => {
    test("ui directory exists", () => {
      expect(existsSync(UI_ROOT)).toBe(true);
    });

    test("components directory exists", () => {
      expect(existsSync(COMPONENTS_ROOT)).toBe(true);
    });

    const requiredFiles = ["init.lua", "theme.lua", "store.lua", "widget.lua"];

    for (const file of requiredFiles) {
      test(`ui/${file} exists`, () => {
        expect(existsSync(join(UI_ROOT, file))).toBe(true);
      });
    }

    const requiredComponents = [
      "button.lua",
      "tab-button.lua",
      "header.lua",
      "status-card.lua",
      "stats-panel.lua",
      "connect-button.lua",
      "action-buttons.lua",
      "history-panel.lua",
    ];

    for (const component of requiredComponents) {
      test(`ui/components/${component} exists`, () => {
        expect(existsSync(join(COMPONENTS_ROOT, component))).toBe(true);
      });
    }
  });

  describe("UI Entry Point (init.lua)", () => {
    const initPath = join(UI_ROOT, "init.lua");

    test("exports UI module", () => {
      const content = readLua(initPath);
      expect(content).toMatch(/local UI = \{\}/);
      expect(content).toMatch(/return UI/);
    });

    test("requires widget module", () => {
      const content = readLua(initPath);
      expect(content).toMatch(/require\(script\.widget\)/);
    });

    test("exports createWidget function", () => {
      const content = readLua(initPath);
      expect(content).toMatch(/UI\.createWidget\s*=/);
    });
  });

  describe("Theme Module", () => {
    const themePath = join(UI_ROOT, "theme.lua");

    test("exports Theme module", () => {
      const content = readLua(themePath);
      expect(hasModuleExport(content, "Theme")).toBe(true);
    });

    test("defines COLORS table", () => {
      const content = readLua(themePath);
      expect(content).toMatch(/Theme\.COLORS\s*=\s*\{/);
    });

    test("defines FONTS table", () => {
      const content = readLua(themePath);
      expect(content).toMatch(/Theme\.FONTS\s*=\s*\{/);
    });

    test("defines TWEENS table", () => {
      const content = readLua(themePath);
      // TWEENS can be defined directly or aliased from MOTION
      expect(content).toMatch(/Theme\.TWEENS\s*=\s*(Theme\.MOTION|\{)/);
    });

    test("has tween helper function", () => {
      const content = readLua(themePath);
      expect(content).toMatch(/function Theme\.tween\(/);
    });

    const requiredColors = [
      "bgBase",
      "bgSurface",
      "textPrimary",
      "textSecondary",
      "interactive",
      "success",
      "warning",
      "error",
    ];

    test("has all required colors", () => {
      const content = readLua(themePath);
      for (const color of requiredColors) {
        expect(content).toContain(`${color} = `);
      }
    });
  });

  describe("Store Module", () => {
    const storePath = join(UI_ROOT, "store.lua");

    test("exports Store module", () => {
      const content = readLua(storePath);
      expect(hasModuleExport(content, "Store")).toBe(true);
    });

    test("has create function", () => {
      const content = readLua(storePath);
      expect(hasCreateFunction(content, "Store")).toBe(true);
    });

    test("store has get method", () => {
      const content = readLua(storePath);
      expect(content).toMatch(/function store:get\(/);
    });

    test("store has set method", () => {
      const content = readLua(storePath);
      expect(content).toMatch(/function store:set\(/);
    });

    test("store has subscribe method", () => {
      const content = readLua(storePath);
      expect(content).toMatch(/function store:subscribe\(/);
    });

    test("store has getState method", () => {
      const content = readLua(storePath);
      expect(content).toMatch(/function store:getState\(/);
    });
  });

  describe("Widget Module", () => {
    const widgetPath = join(UI_ROOT, "widget.lua");

    test("exports Widget module", () => {
      const content = readLua(widgetPath);
      expect(hasModuleExport(content, "Widget")).toBe(true);
    });

    test("has create function", () => {
      const content = readLua(widgetPath);
      expect(hasCreateFunction(content, "Widget")).toBe(true);
    });

    test("requires all components", () => {
      const content = readLua(widgetPath);
      expect(content).toMatch(/require\(script\.Parent\.theme\)/);
      expect(content).toMatch(/require\(script\.Parent\.store\)/);
      expect(content).toMatch(/require\(script\.Parent\.components\.header\)/);
      expect(content).toMatch(/require\(script\.Parent\.components\["status-card"\]\)/);
      expect(content).toMatch(/require\(script\.Parent\.components\["stats-panel"\]\)/);
      expect(content).toMatch(/require\(script\.Parent\.components\["connect-button"\]\)/);
      expect(content).toMatch(/require\(script\.Parent\.components\["action-buttons"\]\)/);
      expect(content).toMatch(/require\(script\.Parent\.components\["history-panel"\]\)/);
    });

    test("creates DockWidgetPluginGui", () => {
      const content = readLua(widgetPath);
      expect(content).toMatch(/CreateDockWidgetPluginGui/);
    });

    test("API has show/hide/toggle methods", () => {
      const content = readLua(widgetPath);
      expect(content).toMatch(/function api\.show\(\)/);
      expect(content).toMatch(/function api\.hide\(\)/);
      expect(content).toMatch(/function api\.toggle\(\)/);
    });

    test("API has setConnectionState method", () => {
      const content = readLua(widgetPath);
      expect(content).toMatch(/function api\.setConnectionState\(/);
    });

    test("API has setConnecting method", () => {
      const content = readLua(widgetPath);
      expect(content).toMatch(/function api\.setConnecting\(/);
    });

    test("API has addCommand method", () => {
      const content = readLua(widgetPath);
      expect(content).toMatch(/function api\.addCommand\(/);
    });

    test("API has clearHistory method", () => {
      const content = readLua(widgetPath);
      expect(content).toMatch(/function api\.clearHistory\(/);
    });
  });
});

describe("UI Components", () => {
  describe("Button Component", () => {
    const buttonPath = join(COMPONENTS_ROOT, "button.lua");

    test("exports Button module", () => {
      const content = readLua(buttonPath);
      expect(hasModuleExport(content, "Button")).toBe(true);
    });

    test("has create function", () => {
      const content = readLua(buttonPath);
      expect(hasCreateFunction(content, "Button")).toBe(true);
    });

    test("requires Theme", () => {
      const content = readLua(buttonPath);
      expect(content).toMatch(/require\(script\.Parent\.Parent\.theme\)/);
    });

    test("creates TextButton instance", () => {
      const content = readLua(buttonPath);
      expect(content).toMatch(/Instance\.new\("TextButton"\)/);
    });

    test("has hover effects", () => {
      const content = readLua(buttonPath);
      expect(content).toMatch(/MouseEnter:Connect/);
      expect(content).toMatch(/MouseLeave:Connect/);
    });

    test("has click effects", () => {
      const content = readLua(buttonPath);
      expect(content).toMatch(/MouseButton1Down:Connect/);
      expect(content).toMatch(/MouseButton1Up:Connect/);
    });

    test("supports primary variant", () => {
      const content = readLua(buttonPath);
      // Uses variant system with schemes table
      expect(content).toMatch(/variant.*primary.*secondary.*ghost/);
      expect(content).toMatch(/schemes\s*=\s*\{/);
      expect(content).toMatch(/primary\s*=\s*\{/);
    });
  });

  describe("Tab Button Component", () => {
    const tabButtonPath = join(COMPONENTS_ROOT, "tab-button.lua");

    test("exports TabButton module", () => {
      const content = readLua(tabButtonPath);
      expect(hasModuleExport(content, "TabButton")).toBe(true);
    });

    test("has create function", () => {
      const content = readLua(tabButtonPath);
      expect(hasCreateFunction(content, "TabButton")).toBe(true);
    });

    test("has setActive function", () => {
      const content = readLua(tabButtonPath);
      expect(content).toMatch(/function TabButton\.setActive\(/);
    });

    test("uses Active attribute", () => {
      const content = readLua(tabButtonPath);
      expect(content).toMatch(/SetAttribute\("Active"/);
      expect(content).toMatch(/GetAttribute\("Active"\)/);
    });
  });

  describe("Header Component", () => {
    const headerPath = join(COMPONENTS_ROOT, "header.lua");

    test("exports Header module", () => {
      const content = readLua(headerPath);
      expect(hasModuleExport(content, "Header")).toBe(true);
    });

    test("has create function", () => {
      const content = readLua(headerPath);
      expect(hasCreateFunction(content, "Header")).toBe(true);
    });

    test("requires TabButton component", () => {
      const content = readLua(headerPath);
      expect(content).toMatch(/require\(script\.Parent\["tab-button"\]\)/);
    });

    test("has setActiveTab method", () => {
      const content = readLua(headerPath);
      expect(content).toMatch(/function api\.setActiveTab\(/);
    });

    test("creates tabs from config", () => {
      const content = readLua(headerPath);
      expect(content).toMatch(/for.*tabInfo.*in.*tabs/);
    });
  });

  describe("Status Card Component", () => {
    const statusCardPath = join(COMPONENTS_ROOT, "status-card.lua");

    test("exports StatusCard module", () => {
      const content = readLua(statusCardPath);
      expect(hasModuleExport(content, "StatusCard")).toBe(true);
    });

    test("has create function", () => {
      const content = readLua(statusCardPath);
      expect(hasCreateFunction(content, "StatusCard")).toBe(true);
    });

    test("has update method", () => {
      const content = readLua(statusCardPath);
      expect(content).toMatch(/function api\.update\(/);
    });

    test("handles connecting state", () => {
      const content = readLua(statusCardPath);
      expect(content).toMatch(/state\.isConnecting/);
      // Uses warning color for connecting state
      expect(content).toMatch(/Theme\.COLORS\.warning/);
    });

    test("handles connected state", () => {
      const content = readLua(statusCardPath);
      expect(content).toMatch(/state\.connected/);
      // Uses success color for connected state
      expect(content).toMatch(/Theme\.COLORS\.success/);
    });

    test("handles disconnected state", () => {
      const content = readLua(statusCardPath);
      // Uses error color for disconnected state
      expect(content).toMatch(/Theme\.COLORS\.error/);
    });

    test("shows version badge", () => {
      const content = readLua(statusCardPath);
      expect(content).toMatch(/version/);
    });
  });

  describe("Stats Panel Component", () => {
    const statsPanelPath = join(COMPONENTS_ROOT, "stats-panel.lua");

    test("exports StatsPanel module", () => {
      const content = readLua(statsPanelPath);
      expect(hasModuleExport(content, "StatsPanel")).toBe(true);
    });

    test("has create function", () => {
      const content = readLua(statsPanelPath);
      expect(hasCreateFunction(content, "StatsPanel")).toBe(true);
    });

    test("has setCommands method", () => {
      const content = readLua(statsPanelPath);
      expect(content).toMatch(/function api\.setCommands\(/);
    });

    test("has setUptime method", () => {
      const content = readLua(statsPanelPath);
      expect(content).toMatch(/function api\.setUptime\(/);
    });

    test("displays commands stat", () => {
      const content = readLua(statsPanelPath);
      // Uses createStat helper with name concatenation
      expect(content).toMatch(/createStat\("Commands"/);
      expect(content).toMatch(/name \.\. "Stat"/);
    });

    test("displays uptime stat", () => {
      const content = readLua(statsPanelPath);
      // Uses createStat helper with name concatenation
      expect(content).toMatch(/createStat\("Uptime"/);
    });
  });

  describe("Connect Button Component", () => {
    const connectButtonPath = join(COMPONENTS_ROOT, "connect-button.lua");

    test("exports ConnectButton module", () => {
      const content = readLua(connectButtonPath);
      expect(hasModuleExport(content, "ConnectButton")).toBe(true);
    });

    test("has create function", () => {
      const content = readLua(connectButtonPath);
      expect(hasCreateFunction(content, "ConnectButton")).toBe(true);
    });

    test("requires Button component", () => {
      const content = readLua(connectButtonPath);
      expect(content).toMatch(/require\(script\.Parent\.button\)/);
    });

    test("has update method", () => {
      const content = readLua(connectButtonPath);
      expect(content).toMatch(/function api\.update\(/);
    });

    test("shows different text for states", () => {
      const content = readLua(connectButtonPath);
      expect(content).toMatch(/Connecting\.\.\./);
      expect(content).toMatch(/Disconnect/);
      expect(content).toMatch(/Connect/);
    });

    test("has debounce protection", () => {
      const content = readLua(connectButtonPath);
      expect(content).toMatch(/DEBOUNCE_TIME/);
      expect(content).toMatch(/lastClickTime/);
    });
  });

  describe("Action Buttons Component", () => {
    const actionButtonsPath = join(COMPONENTS_ROOT, "action-buttons.lua");

    test("exports ActionButtons module", () => {
      const content = readLua(actionButtonsPath);
      expect(hasModuleExport(content, "ActionButtons")).toBe(true);
    });

    test("has create function", () => {
      const content = readLua(actionButtonsPath);
      expect(hasCreateFunction(content, "ActionButtons")).toBe(true);
    });

    test("requires Button component", () => {
      const content = readLua(actionButtonsPath);
      expect(content).toMatch(/require\(script\.Parent\.button\)/);
    });

    test("creates Undo button", () => {
      const content = readLua(actionButtonsPath);
      expect(content).toMatch(/["']Undo["']/);
      expect(content).toMatch(/ChangeHistoryService\.Undo/);
    });

    test("creates Redo button", () => {
      const content = readLua(actionButtonsPath);
      expect(content).toMatch(/["']Redo["']/);
      expect(content).toMatch(/ChangeHistoryService\.Redo/);
    });
  });

  describe("History Panel Component", () => {
    const historyPanelPath = join(COMPONENTS_ROOT, "history-panel.lua");

    test("exports HistoryPanel module", () => {
      const content = readLua(historyPanelPath);
      expect(hasModuleExport(content, "HistoryPanel")).toBe(true);
    });

    test("has create function", () => {
      const content = readLua(historyPanelPath);
      expect(hasCreateFunction(content, "HistoryPanel")).toBe(true);
    });

    test("has addEntry method", () => {
      const content = readLua(historyPanelPath);
      expect(content).toMatch(/function api\.addEntry\(/);
    });

    test("has clear method", () => {
      const content = readLua(historyPanelPath);
      expect(content).toMatch(/function api\.clear\(/);
    });

    test("has getCount method", () => {
      const content = readLua(historyPanelPath);
      expect(content).toMatch(/function api\.getCount\(/);
    });

    test("has MAX_ENTRIES limit", () => {
      const content = readLua(historyPanelPath);
      expect(content).toMatch(/MAX_ENTRIES/);
    });

    test("uses ScrollingFrame", () => {
      const content = readLua(historyPanelPath);
      expect(content).toMatch(/Instance\.new\("ScrollingFrame"\)/);
    });

    test("shows timestamp on entries", () => {
      const content = readLua(historyPanelPath);
      expect(content).toMatch(/os_date\("%H:%M:%S"\)/);
    });

    test("shows success/error indicator", () => {
      const content = readLua(historyPanelPath);
      expect(content).toMatch(/Theme\.COLORS\.success/);
      expect(content).toMatch(/Theme\.COLORS\.error/);
    });
  });
});

describe("UI Integration", () => {
  test("init.server.lua requires UI module correctly", () => {
    const initServerPath = join(PLUGIN_ROOT, "init.server.lua");
    const content = readLua(initServerPath);
    expect(content).toMatch(/require\(Parent\.ui\)/);
  });

  test("init.server.lua calls UI.createWidget", () => {
    const initServerPath = join(PLUGIN_ROOT, "init.server.lua");
    const content = readLua(initServerPath);
    expect(content).toMatch(/UI\.createWidget\(plugin,/);
  });

  test("init.server.lua uses setConnecting API", () => {
    const initServerPath = join(PLUGIN_ROOT, "init.server.lua");
    const content = readLua(initServerPath);
    expect(content).toMatch(/ui\.setConnecting\(/);
  });

  test("init.server.lua uses setConnectionState API", () => {
    const initServerPath = join(PLUGIN_ROOT, "init.server.lua");
    const content = readLua(initServerPath);
    expect(content).toMatch(/ui\.setConnectionState\(/);
  });

  test("init.server.lua uses addCommand API", () => {
    const initServerPath = join(PLUGIN_ROOT, "init.server.lua");
    const content = readLua(initServerPath);
    expect(content).toMatch(/ui\.addCommand\(/);
  });
});

describe("UI Theme Consistency", () => {
  test("all components use Theme module for colors", () => {
    const components = [
      "button.lua",
      "tab-button.lua",
      "header.lua",
      "status-card.lua",
      "stats-panel.lua",
      "history-panel.lua",
    ];

    for (const component of components) {
      const content = readLua(join(COMPONENTS_ROOT, component));
      // Should not have hardcoded Color3 values (except in Theme itself)
      const hardcodedColors = content.match(/Color3\.fromRGB\(\d+/g) || [];
      expect(hardcodedColors.length).toBe(0);
    }
  });

  test("all components use Theme module for fonts", () => {
    const components = [
      "button.lua",
      "tab-button.lua",
      "header.lua",
      "status-card.lua",
      "stats-panel.lua",
      "history-panel.lua",
    ];

    for (const component of components) {
      const content = readLua(join(COMPONENTS_ROOT, component));
      // Should use Theme.FONTS, not Font.new directly
      const hardcodedFonts = content.match(/Font\.new\(/g) || [];
      expect(hardcodedFonts.length).toBe(0);
    }
  });

  test("all components use Theme.tween for animations", () => {
    const components = ["button.lua", "tab-button.lua", "status-card.lua", "history-panel.lua"];

    for (const component of components) {
      const content = readLua(join(COMPONENTS_ROOT, component));
      expect(content).toMatch(/Theme\.tween\(/);
    }
  });
});
