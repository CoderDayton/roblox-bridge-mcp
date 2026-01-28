# Changes

Added 59 new methods to expand functionality from 99 to 158 total methods.

## Modified Files

### `src/tools/roblox-tools.ts`
- **Added**: 59 new method identifiers to the `METHODS` array (lines 105-158)
- **Categories**: Animation & Character, GUI, Networking, DataStore, Tween, Raycasting, Constraints, Particles, Materials, Marketplace, Teams, Leaderstats

### `src/resources/index.ts`
- **Added**: Method documentation for all 59 new methods (lines 118-183)
- **Format**: Each method includes a concise description of its functionality

### `plugin/mcp-bridge.server.lua`
- **Added**: Implementation of 59 new methods (lines 1314-2027)
- **Version**: Maintained at 1.0.0 to respect original author
- **State Management**: Added animationTracks and activeTweens tracking tables

## New Methods by Category

### Animation & Character (5)

**PlayAnimation** - Play an animation on humanoid
- **Roblox API Used**: 
  - `Humanoid:LoadAnimation()` - Loads animation track
  - `AnimationTrack:Play()` - Plays the animation
  - `Instance.new("Animation")` - Creates animation instance
- **Modified**: Added `state.animationTracks` table to track active animations

**LoadAnimation** - Load an animation track
- **Roblox API Used**: 
  - `Humanoid:LoadAnimation()` - Loads animation track without playing
  - `AnimationTrack.Length` - Gets animation duration
  - `AnimationTrack.Priority` - Gets animation priority

**StopAnimation** - Stop a playing animation
- **Roblox API Used**: 
  - `AnimationTrack:Stop()` - Stops the animation
  - Removes track from `state.animationTracks`

**SetCharacterAppearance** - Set character appearance
- **Roblox API Used**: 
  - `HumanoidDescription.Shirt` - Shirt asset ID
  - `HumanoidDescription.Pants` - Pants asset ID
  - `Player.CharacterAppearanceLoaded` - Wait for appearance load

**GetCharacter** - Get player character info
- **Roblox API Used**: 
  - `Players:FindFirstChild()` - Find player by name
  - `Player.Character` - Get character model
  - `Model:FindFirstChildOfClass("Humanoid")` - Check for humanoid

### GUI (6)

**CreateGuiElement** - Create GUI element
- **Roblox API Used**: 
  - `Instance.new()` - Creates GUI instances (ScreenGui, Frame, TextLabel, TextButton, TextBox, ImageLabel, ImageButton, ScrollingFrame)
  - `Instance.new()` - Creates UI layout instances (UIGridLayout, UIListLayout, UIPadding, UISizeConstraint)

**SetGuiText** - Set GUI text content
- **Roblox API Used**: 
  - `TextLabel.Text` - Set text
  - `TextButton.Text` - Set text
  - `TextBox.Text` - Set text

**SetGuiSize** - Set GUI element size
- **Roblox API Used**: 
  - `GuiObject.Size` - Set UDim2 size

**SetGuiPosition** - Set GUI element position
- **Roblox API Used**: 
  - `GuiObject.Position` - Set UDim2 position

**SetGuiVisible** - Set GUI element visibility
- **Roblox API Used**: 
  - `GuiObject.Visible` - Set visibility state

**DestroyGuiElement** - Destroy GUI element
- **Roblox API Used**: 
  - `Instance:Destroy()` - Remove instance from game

### Networking (4)

**FireRemoteEvent** - Fire remote event to server
- **Roblox API Used**: 
  - `RemoteEvent:FireServer()` - Send data to server
  - `unpack()` - Unpack arguments table

**InvokeRemoteFunction** - Invoke remote function on server
- **Roblox API Used**: 
  - `RemoteFunction:InvokeServer()` - Request data from server with response

**CreateRemoteEvent** - Create remote event instance
- **Roblox API Used**: 
  - `Instance.new("RemoteEvent")` - Create remote event
  - Default parent: `game.ReplicatedStorage`

**CreateRemoteFunction** - Create remote function instance
- **Roblox API Used**: 
  - `Instance.new("RemoteFunction")` - Create remote function
  - Default parent: `game.ReplicatedStorage`

### DataStore (4)

**GetDataStore** - Get data store instance
- **Roblox API Used**: 
  - `DataStoreService:GetDataStore(name)` - Retrieve data store

**SetDataStoreValue** - Set value in data store
- **Roblox API Used**: 
  - `DataStoreService:GetDataStore()` - Get data store
  - `DataStore:SetAsync(key, value)` - Store data asynchronously
  - `pcall()` - Error handling wrapper

**GetDataStoreValue** - Get value from data store
- **Roblox API Used**: 
  - `DataStoreService:GetDataStore()` - Get data store
  - `DataStore:GetAsync(key)` - Retrieve data asynchronously

**RemoveDataStoreValue** - Remove value from data store
- **Roblox API Used**: 
  - `DataStoreService:GetDataStore()` - Get data store
  - `DataStore:RemoveAsync(key)` - Delete data asynchronously

### Tween (2)

**CreateTween** - Create and play tween
- **Roblox API Used**: 
  - `TweenService:Create(obj, tweenInfo, targetProps)` - Create tween
  - `TweenInfo.new(duration)` - Configure tween properties
  - `Tween:Play()` - Start tween animation
  - Added `state.activeTweens` table for tracking

**TweenProperty** - Tween single property
- **Roblox API Used**: 
  - `TweenService:Create()` - Create tween with single property
  - `Tween:Play()` - Start tween

### Raycasting (2)

**Raycast** - Perform raycast from origin
- **Roblox API Used**: 
  - `workspace:Raycast(origin, direction, raycastParams)` - Cast ray
  - `RaycastParams.new()` - Create raycast parameters
  - Returns: Instance, Position, Material, Distance

**RaycastTo** - Raycast toward target object
- **Roblox API Used**: 
  - `workspace:Raycast(origin, direction, raycastParams)` - Cast ray
  - `Vector3.Unit` - Normalize direction vector
  - `getObjectPosition()` - Get object position helper

### Constraints (2)

**CreateWeld** - Create weld constraint
- **Roblox API Used**: 
  - `Instance.new("WeldConstraint")` - Create weld
  - `Instance.new("Attachment")` - Create attachments
  - `WeldConstraint.Part0` / `WeldConstraint.Part1` - Set connected parts

**CreateMotor6D** - Create Motor6D constraint
- **Roblox API Used**: 
  - `Instance.new("Motor6D")` - Create motor joint
  - `Instance.new("Attachment")` - Create attachments
  - `Motor6D.Part0` / `Motor6D.Part1` - Set connected parts

### Particles (2)

**CreateParticleEmitter** - Create particle emitter
- **Roblox API Used**: 
  - `Instance.new("ParticleEmitter")` - Create emitter
  - Parent must be `BasePart`

**EmitParticles** - Emit particles
- **Roblox API Used**: 
  - `BasePart:FindFirstChildOfClass("ParticleEmitter")` - Find emitter
  - `ParticleEmitter:Emit(count)` - Emit particles

### Materials (2)

**ApplyDecal** - Apply decal texture
- **Roblox API Used**: 
  - `Instance.new("Decal")` - Create decal
  - `Decal.Texture` - Set texture ID (rbxassetid://)

**ApplyTexture** - Apply texture
- **Roblox API Used**: 
  - `Instance.new("Texture")` - Create texture
  - `Texture.Texture` - Set texture ID (rbxassetid://)

### Marketplace (2)

**InsertAsset** - Insert asset from marketplace
- **Roblox API Used**: 
  - `MarketplaceService:InsertAsset(assetId, parent)` - Insert asset

**InsertMesh** - Insert mesh part
- **Roblox API Used**: 
  - `Instance.new("Part")` - Create part
  - `Part.Shape = Enum.PartType.Ball` - Set shape
  - `Instance.new("SpecialMesh")` - Create mesh
  - `SpecialMesh.MeshId` - Set mesh ID

### Teams (3)

**CreateTeam** - Create team
- **Roblox API Used**: 
  - `Instance.new("Team")` - Create team
  - `Team.TeamColor = BrickColor.new()` - Set team color
  - Parent: `game.Teams`

**SetPlayerTeam** - Set player team
- **Roblox API Used**: 
  - `Players:FindFirstChild()` - Find player
  - `Teams:FindFirstChild()` - Find team
  - `Player.Team = team` - Assign team

**GetPlayerTeam** - Get player team name
- **Roblox API Used**: 
  - `Players:FindFirstChild()` - Find player
  - `Player.Team.Name` - Get team name

### Leaderstats (3)

**CreateLeaderstat** - Create leaderstat value
- **Roblox API Used**: 
  - `Instance.new("Folder")` - Create leaderstats folder
  - `Instance.new("IntValue")` - Create value object
  - Parent: `game.Players`

**SetLeaderstatValue** - Set leaderstat value
- **Roblox API Used**: 
  - `IntValue.Value` / `NumberValue.Value` / `StringValue.Value` - Set value

**GetLeaderstatValue** - Get leaderstat value
- **Roblox API Used**: 
  - `IntValue.Value` / `NumberValue.Value` / `StringValue.Value` - Get value

## Roblox Services Used

### New Services Added to Plugin
- **TweenService** - For creating smooth property animations
- **DataStoreService** - For persistent data storage
- **MarketplaceService** - For inserting marketplace assets
- **Teams** - For team management

### Existing Services Utilized
- **Players** - Player and character management
- **Workspace** - Scene management, raycasting
- **ChangeHistoryService** - Undo/redo waypoints
- **HttpService** - JSON encoding/decoding
- **CollectionService** - Tag management

## Implementation Details

### State Management
Added two new tracking tables to `state`:
```lua
animationTracks = {}  -- Tracks active animation tracks by character name
activeTweens = {}    -- Tracks active tweens by tween ID
```

### Error Handling
All new methods use `pcall()` for safe execution:
- DataStore operations wrapped in pcall for API limit handling
- Service access wrapped in pcall for graceful failure

### Change History
All destructive operations call `ChangeHistoryService:SetWaypoint()`:
- Enables undo/redo functionality in Roblox Studio
- Descriptive waypoint names for better UX

## Notes

- No breaking changes
- All existing methods unchanged
- Follows project code style
- Version maintained at 1.0.0 to respect original author
- Compatible with existing MCP clients
