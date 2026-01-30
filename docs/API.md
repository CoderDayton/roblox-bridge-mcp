# API Reference

Complete reference for all 205 methods available through the `roblox` tool.

## Usage

All operations are accessed through a single tool with two parameters:

- **method** (string) - The operation to execute
- **params** (object) - Method-specific parameters

```json
{
  "method": "CreateInstance",
  "params": {
    "className": "Part",
    "parentPath": "game.Workspace"
  }
}
```

## Path Format

All instance paths use dot notation starting from `game`:

- `game.Workspace.Model.Part`
- `game.ReplicatedStorage.Assets`
- `game.ServerScriptService.Scripts`

---

## Instance Management

| Method             | Parameters                                        | Returns   | Description           |
| ------------------ | ------------------------------------------------- | --------- | --------------------- |
| `CreateInstance`   | `className`, `parentPath`, `name?`, `properties?` | path      | Create a new instance |
| `DeleteInstance`   | `path`                                            | "Deleted" | Destroy an instance   |
| `ClearAllChildren` | `path`                                            | "Cleared" | Remove all children   |
| `CloneInstance`    | `path`, `parentPath?`                             | path      | Clone an instance     |
| `RenameInstance`   | `path`, `newName`                                 | "Renamed" | Rename an instance    |

## Discovery & Hierarchy

| Method                   | Parameters                   | Returns  | Description               |
| ------------------------ | ---------------------------- | -------- | ------------------------- |
| `GetFullName`            | `path`                       | string   | Get full instance path    |
| `GetParent`              | `path`                       | path/nil | Get parent path           |
| `IsA`                    | `path`, `className`          | boolean  | Check class inheritance   |
| `GetClassName`           | `path`                       | string   | Get instance class name   |
| `WaitForChild`           | `path`, `name`, `timeout?`   | path     | Wait for child to exist   |
| `FindFirstChild`         | `path`, `name`, `recursive?` | path/nil | Find child by name        |
| `FindFirstChildOfClass`  | `path`, `className`          | path/nil | Find child by class       |
| `FindFirstChildWhichIsA` | `path`, `className`          | path/nil | Find child by inheritance |
| `FindFirstDescendant`    | `path`, `name`               | path/nil | Find descendant by name   |
| `GetChildren`            | `path`                       | string[] | Get child names           |
| `GetDescendants`         | `path`                       | path[]   | Get all descendant paths  |
| `GetDescendantCount`     | `path`                       | number   | Count descendants         |
| `GetAncestors`           | `path`                       | path[]   | Get ancestor chain        |
| `GetService`             | `serviceName`                | path     | Get a Roblox service      |

## Properties

| Method        | Parameters                  | Returns | Description          |
| ------------- | --------------------------- | ------- | -------------------- |
| `SetProperty` | `path`, `property`, `value` | "Set"   | Set a property value |
| `GetProperty` | `path`, `property`          | any     | Get a property value |

## Selection

| Method           | Parameters | Returns     | Description          |
| ---------------- | ---------- | ----------- | -------------------- |
| `GetSelection`   | -          | path[]      | Get selected objects |
| `SetSelection`   | `paths[]`  | "Set"       | Set selection        |
| `ClearSelection` | -          | "Cleared"   | Clear selection      |
| `AddToSelection` | `paths[]`  | "Added"     | Add to selection     |
| `GroupSelection` | `name`     | path        | Group into Model     |
| `UngroupModel`   | `path`     | "Ungrouped" | Ungroup a Model      |

## Model Operations

| Method           | Parameters             | Returns        | Description             |
| ---------------- | ---------------------- | -------------- | ----------------------- |
| `GetBoundingBox` | `path`                 | {cframe, size} | Get model bounding box  |
| `GetExtentsSize` | `path`                 | [x,y,z]        | Get model extents       |
| `ScaleTo`        | `path`, `scale`        | "Scaled"       | Scale model uniformly   |
| `GetScale`       | `path`                 | number         | Get model scale         |
| `TranslateBy`    | `path`, `delta[x,y,z]` | "Translated"   | Move model by delta     |
| `SetPrimaryPart` | `path`, `partPath`     | "Set"          | Set model's PrimaryPart |
| `GetPrimaryPart` | `path`                 | path/nil       | Get model's PrimaryPart |

## Transforms

| Method        | Parameters                | Returns     | Description            |
| ------------- | ------------------------- | ----------- | ---------------------- |
| `MoveTo`      | `path`, `position[x,y,z]` | "Moved"     | Move Model or BasePart |
| `SetPosition` | `path`, `x`, `y`, `z`     | "Set"       | Set Position property  |
| `SetRotation` | `path`, `x`, `y`, `z`     | "Set"       | Set rotation (degrees) |
| `SetSize`     | `path`, `x`, `y`, `z`     | "Set"       | Set Size property      |
| `SetCFrame`   | `path`, `cframe[12]`      | "Set"       | Set CFrame directly    |
| `PivotTo`     | `path`, `cframe[12]`      | "Set"       | Set CFrame via PivotTo |
| `GetPivot`    | `path`                    | [12 floats] | Get CFrame components  |
| `SetScale`    | `path`, `scale`           | "Set"       | Scale a part           |

## Physics

| Method                    | Parameters               | Returns   | Description                 |
| ------------------------- | ------------------------ | --------- | --------------------------- |
| `SetAnchored`             | `path`, `anchored`       | "Set"     | Set Anchored property       |
| `SetCanCollide`           | `path`, `canCollide`     | "Set"     | Set CanCollide property     |
| `SetMassless`             | `path`, `massless`       | "Set"     | Set Massless property       |
| `ApplyImpulse`            | `path`, `impulse[x,y,z]` | "Applied" | Apply linear impulse        |
| `ApplyAngularImpulse`     | `path`, `impulse[x,y,z]` | "Applied" | Apply angular impulse       |
| `GetMass`                 | `path`                   | number    | Get part mass               |
| `GetAssemblyMass`         | `path`                   | number    | Get assembly total mass     |
| `GetCenterOfMass`         | `path`                   | [x,y,z]   | Get part center of mass     |
| `GetAssemblyCenterOfMass` | `path`                   | [x,y,z]   | Get assembly center of mass |

## Velocity

| Method               | Parameters                | Returns | Description                 |
| -------------------- | ------------------------- | ------- | --------------------------- |
| `GetVelocity`        | `path`                    | [x,y,z] | Get AssemblyLinearVelocity  |
| `SetVelocity`        | `path`, `velocity[x,y,z]` | "Set"   | Set AssemblyLinearVelocity  |
| `GetAngularVelocity` | `path`                    | [x,y,z] | Get AssemblyAngularVelocity |
| `SetAngularVelocity` | `path`, `velocity[x,y,z]` | "Set"   | Set AssemblyAngularVelocity |

## Assembly

| Method            | Parameters         | Returns | Description            |
| ----------------- | ------------------ | ------- | ---------------------- |
| `GetRootPart`     | `path`             | path    | Get assembly root part |
| `SetRootPriority` | `path`, `priority` | "Set"   | Set RootPriority       |
| `GetRootPriority` | `path`             | number  | Get RootPriority       |

## Collision

| Method              | Parameters          | Returns | Description         |
| ------------------- | ------------------- | ------- | ------------------- |
| `SetCollisionGroup` | `path`, `groupName` | "Set"   | Set collision group |
| `GetCollisionGroup` | `path`              | string  | Get collision group |

## Joints & Welds

| Method          | Parameters                        | Returns  | Description             |
| --------------- | --------------------------------- | -------- | ----------------------- |
| `CreateWeld`    | `part0Path`, `part1Path`, `name?` | path     | Create a WeldConstraint |
| `CreateMotor6D` | `part0Path`, `part1Path`, `name?` | path     | Create a Motor6D        |
| `BreakJoints`   | `path`                            | "Broken" | Break all joints        |
| `MakeJoints`    | `path`                            | "Made"   | Create surface joints   |

## Attachments

| Method                  | Parameters                         | Returns | Description             |
| ----------------------- | ---------------------------------- | ------- | ----------------------- |
| `CreateAttachment`      | `parentPath`, `name?`, `position?` | path    | Create an Attachment    |
| `GetAttachmentPosition` | `path`                             | [x,y,z] | Get attachment position |
| `SetAttachmentPosition` | `path`, `position[x,y,z]`          | "Set"   | Set attachment position |

## Constraints

| Method             | Parameters                                    | Returns | Description         |
| ------------------ | --------------------------------------------- | ------- | ------------------- |
| `CreateConstraint` | `type`, `att0Path`, `att1Path`, `properties?` | path    | Create a constraint |

## Raycasting & Spatial Queries

| Method                 | Parameters                                                        | Returns                           | Description             |
| ---------------------- | ----------------------------------------------------------------- | --------------------------------- | ----------------------- |
| `Raycast`              | `origin[x,y,z]`, `direction[x,y,z]`, `filterType?`, `filterList?` | {hit, position, normal, material} | Cast a ray              |
| `RaycastFromTo`        | `from[x,y,z]`, `to[x,y,z]`, `filterType?`, `filterList?`          | {hit, position, normal, material} | Cast ray between points |
| `GetPartsInRadius`     | `position[x,y,z]`, `radius`                                       | path[]                            | Find parts in sphere    |
| `GetPartsInRegion`     | `min[x,y,z]`, `max[x,y,z]`                                        | path[]                            | Find parts in region    |
| `GetPartsTouchingPart` | `path`                                                            | path[]                            | Find touching parts     |
| `GetPartsInBox`        | `cframe[12]`, `size[x,y,z]`                                       | path[]                            | Find parts in box       |
| `Shapecast`            | `path`, `direction[x,y,z]`                                        | {hit, position, normal}           | Cast part shape         |
| `Blockcast`            | `cframe[12]`, `size[x,y,z]`, `direction[x,y,z]`                   | {hit, position, normal}           | Cast a block            |
| `Spherecast`           | `position[x,y,z]`, `radius`, `direction[x,y,z]`                   | {hit, position, normal}           | Cast a sphere           |

## Appearance

| Method            | Parameters            | Returns | Description            |
| ----------------- | --------------------- | ------- | ---------------------- |
| `SetColor`        | `path`, `r`, `g`, `b` | "Set"   | Set Color3 (0-255 RGB) |
| `SetTransparency` | `path`, `value`       | "Set"   | Set Transparency (0-1) |
| `SetMaterial`     | `path`, `material`    | "Set"   | Set Material enum      |

## Lighting

| Method                 | Parameters                                    | Returns | Description                |
| ---------------------- | --------------------------------------------- | ------- | -------------------------- |
| `SetTimeOfDay`         | `time`                                        | "Set"   | Set TimeOfDay ("14:00:00") |
| `SetBrightness`        | `brightness`                                  | "Set"   | Set Lighting.Brightness    |
| `SetAtmosphereDensity` | `density`                                     | "Set"   | Set Atmosphere.Density     |
| `SetAtmosphereColor`   | `r`, `g`, `b`, `haze?`                        | "Set"   | Set Atmosphere.Color       |
| `SetGlobalShadows`     | `enabled`                                     | "Set"   | Toggle global shadows      |
| `SetFog`               | `start?`, `fogEnd?`, `color?`                 | "Set"   | Configure fog              |
| `CreateLight`          | `parentPath`, `type`, `brightness?`, `color?` | path    | Create a light             |

## Sky & Atmosphere

| Method         | Parameters                                                                   | Returns | Description         |
| -------------- | ---------------------------------------------------------------------------- | ------- | ------------------- |
| `SetSkybox`    | `skyboxBk?`, `skyboxDn?`, `skyboxFt?`, `skyboxLf?`, `skyboxRt?`, `skyboxUp?` | path    | Set skybox textures |
| `CreateClouds` | `cover?`, `density?`, `color?`                                               | path    | Create cloud layer  |

## Effects

| Method                  | Parameters                                                           | Returns   | Description            |
| ----------------------- | -------------------------------------------------------------------- | --------- | ---------------------- |
| `HighlightObject`       | `path`, `color?`, `duration?`                                        | path      | Add Highlight effect   |
| `CreateBeam`            | `attachment0Path`, `attachment1Path`, `color?`, `width0?`, `width1?` | path      | Create a Beam          |
| `CreateTrail`           | `attachment0Path`, `attachment1Path`, `lifetime?`, `color?`          | path      | Create a Trail         |
| `CreateParticleEmitter` | `parentPath`, `properties?`                                          | path      | Create ParticleEmitter |
| `EmitParticles`         | `path`, `count?`                                                     | "Emitted" | Emit particles         |

## Decals & Textures

| Method         | Parameters                         | Returns | Description     |
| -------------- | ---------------------------------- | ------- | --------------- |
| `ApplyDecal`   | `parentPath`, `textureId`, `face?` | path    | Apply a Decal   |
| `ApplyTexture` | `parentPath`, `textureId`, `face?` | path    | Apply a Texture |

## GUI

| Method              | Parameters                                           | Returns     | Description         |
| ------------------- | ---------------------------------------------------- | ----------- | ------------------- |
| `CreateGuiElement`  | `className`, `parentPath?`, `name?`, `properties?`   | path        | Create GUI element  |
| `SetGuiText`        | `path`, `text`                                       | "Set"       | Set text content    |
| `SetGuiSize`        | `path`, `scaleX?`, `offsetX?`, `scaleY?`, `offsetY?` | "Set"       | Set UDim2 size      |
| `SetGuiPosition`    | `path`, `scaleX?`, `offsetX?`, `scaleY?`, `offsetY?` | "Set"       | Set UDim2 position  |
| `SetGuiVisible`     | `path`, `visible`                                    | "Set"       | Toggle visibility   |
| `DestroyGuiElement` | `path`                                               | "Destroyed" | Destroy GUI element |

## Scripting

| Method               | Parameters                                | Returns    | Description                            |
| -------------------- | ----------------------------------------- | ---------- | -------------------------------------- |
| `CreateScript`       | `name`, `parentPath`, `source`, `type?`   | path       | Create Script/LocalScript/ModuleScript |
| `GetScriptSource`    | `path`                                    | string     | Read script source                     |
| `SetScriptSource`    | `path`, `source`                          | "Set"      | Replace script source                  |
| `AppendToScript`     | `path`, `code`                            | "Appended" | Append code to script                  |
| `ReplaceScriptLines` | `path`, `startLine`, `endLine`, `content` | "Replaced" | Replace line range                     |
| `InsertScriptLines`  | `path`, `lineNumber`, `content`           | "Inserted" | Insert lines at position               |
| `RunConsoleCommand`  | `code`                                    | any        | Execute Luau in sandbox                |

## Audio

| Method      | Parameters                                  | Returns   | Description  |
| ----------- | ------------------------------------------- | --------- | ------------ |
| `PlaySound` | `soundId` or `path`, `volume?`, `duration?` | path      | Play a sound |
| `StopSound` | `path`                                      | "Stopped" | Stop a sound |

## Tweening

| Method          | Parameters                                                                                                               | Returns    | Description                      |
| --------------- | ------------------------------------------------------------------------------------------------------------------------ | ---------- | -------------------------------- |
| `CreateTween`   | `path`, `goals`, `duration?`, `easingStyle?`, `easingDirection?`, `repeatCount?`, `reverses?`, `delayTime?`, `autoPlay?` | tweenId    | Create and optionally play tween |
| `TweenProperty` | `path`, `property`, `value`, `duration?`                                                                                 | "Tweening" | Quick single-property tween      |

## Networking

| Method                 | Parameters                     | Returns | Description           |
| ---------------------- | ------------------------------ | ------- | --------------------- |
| `CreateRemoteEvent`    | `name`, `parentPath?`          | path    | Create RemoteEvent    |
| `CreateRemoteFunction` | `name`, `parentPath?`          | path    | Create RemoteFunction |
| `FireRemoteEvent`      | `path`, `playerName?`, `args?` | "Fired" | Fire to client(s)     |
| `InvokeRemoteFunction` | `path`, `playerName`, `args?`  | any     | Invoke on client      |

## DataStore

| Method                 | Parameters                  | Returns          | Description             |
| ---------------------- | --------------------------- | ---------------- | ----------------------- |
| `GetDataStore`         | `name`, `scope?`            | "DataStore:name" | Get DataStore reference |
| `SetDataStoreValue`    | `storeName`, `key`, `value` | "Set"            | Set DataStore value     |
| `GetDataStoreValue`    | `storeName`, `key`          | any              | Get DataStore value     |
| `RemoveDataStoreValue` | `storeName`, `key`          | "Removed"        | Remove DataStore key    |

## Marketplace

| Method        | Parameters                                     | Returns    | Description               |
| ------------- | ---------------------------------------------- | ---------- | ------------------------- |
| `InsertAsset` | `assetId`, `parentPath?`                       | "Inserted" | Insert asset from library |
| `InsertMesh`  | `meshId`, `textureId?`, `name?`, `parentPath?` | path       | Insert MeshPart           |

## Terrain

| Method              | Parameters                                                     | Returns                                     | Description               |
| ------------------- | -------------------------------------------------------------- | ------------------------------------------- | ------------------------- |
| `GetTerrainInfo`    | -                                                              | {maxExtents, waterWaveSize, waterWaveSpeed} | Get terrain info          |
| `FillTerrainRegion` | `min[x,y,z]`, `max[x,y,z]`, `material`                         | "Filled"                                    | Fill region with material |
| `ClearTerrain`      | -                                                              | "Cleared"                                   | Clear all terrain         |
| `FillBall`          | `center[x,y,z]`, `radius`, `material`                          | "Filled"                                    | Fill sphere               |
| `FillBlock`         | `position[x,y,z]`, `size[x,y,z]`, `material`                   | "Filled"                                    | Fill block                |
| `FillCylinder`      | `position[x,y,z]`, `height`, `radius`, `material`              | "Filled"                                    | Fill cylinder             |
| `FillWedge`         | `position[x,y,z]`, `size[x,y,z]`, `material`                   | "Filled"                                    | Fill wedge                |
| `FillTerrain`       | `minX`, `minY`, `minZ`, `maxX`, `maxY`, `maxZ`, `material`     | "Filled"                                    | Fill region (legacy)      |
| `ReplaceMaterial`   | `min[x,y,z]`, `max[x,y,z]`, `sourceMaterial`, `targetMaterial` | "Replaced"                                  | Replace terrain material  |

## Camera

| Method               | Parameters         | Returns              | Description                   |
| -------------------- | ------------------ | -------------------- | ----------------------------- |
| `SetCameraPosition`  | `x`, `y`, `z`      | "Set"                | Set camera position           |
| `SetCameraTarget`    | `x`, `y`, `z`      | "Set"                | Point camera at position      |
| `SetCameraFocus`     | `path`             | "Set"                | Point camera at instance      |
| `SetCameraType`      | `cameraType`       | "Set"                | Set CameraType enum           |
| `GetCameraType`      | -                  | string               | Get current CameraType        |
| `ZoomCamera`         | `distance`         | "Zoomed"             | Move camera along look vector |
| `GetCameraPosition`  | -                  | [x,y,z]              | Get camera position           |
| `ScreenPointToRay`   | `x`, `y`, `depth?` | {origin, direction}  | Screen to world ray           |
| `ViewportPointToRay` | `x`, `y`, `depth?` | {origin, direction}  | Viewport to world ray         |
| `WorldToScreenPoint` | `x`, `y`, `z`      | {position, onScreen} | World to screen coords        |

## Lighting Time

| Method                    | Parameters | Returns | Description               |
| ------------------------- | ---------- | ------- | ------------------------- |
| `GetSunDirection`         | -          | [x,y,z] | Get sun direction vector  |
| `GetMoonDirection`        | -          | [x,y,z] | Get moon direction vector |
| `GetMinutesAfterMidnight` | -          | number  | Get time as minutes       |
| `SetMinutesAfterMidnight` | `minutes`  | "Set"   | Set time as minutes       |

## History (Undo/Redo)

| Method       | Parameters | Returns    | Description             |
| ------------ | ---------- | ---------- | ----------------------- |
| `RecordUndo` | `name`     | "Recorded" | Create undo waypoint    |
| `Undo`       | -          | "Undone"   | Undo last action        |
| `Redo`       | -          | "Redone"   | Redo last undo          |
| `GetCanUndo` | -          | boolean    | Check if undo available |
| `GetCanRedo` | -          | boolean    | Check if redo available |

## Pathfinding

| Method        | Parameters                                                                               | Returns               | Description             |
| ------------- | ---------------------------------------------------------------------------------------- | --------------------- | ----------------------- |
| `ComputePath` | `start[x,y,z]`, `endPos[x,y,z]`, `agentRadius?`, `agentHeight?`, `canJump?`, `canClimb?` | {status, waypoints[]} | Compute navigation path |

## Place Info

| Method            | Parameters | Returns                                                 | Description        |
| ----------------- | ---------- | ------------------------------------------------------- | ------------------ |
| `GetPlaceInfo`    | -          | {PlaceId, PlaceVersion, GameId, CreatorId, CreatorType} | Get place metadata |
| `GetPlaceVersion` | -          | number                                                  | Get place version  |
| `GetGameId`       | -          | number                                                  | Get game ID        |
| `SavePlace`       | -          | string                                                  | Trigger save       |

## Attributes

| Method            | Parameters              | Returns       | Description         |
| ----------------- | ----------------------- | ------------- | ------------------- |
| `SetAttribute`    | `path`, `name`, `value` | "Set"         | Set an attribute    |
| `GetAttribute`    | `path`, `name`          | any           | Get an attribute    |
| `GetAttributes`   | `path`                  | {name: value} | Get all attributes  |
| `RemoveAttribute` | `path`, `name`          | "Removed"     | Remove an attribute |

## Tags

| Method      | Parameters    | Returns   | Description               |
| ----------- | ------------- | --------- | ------------------------- |
| `AddTag`    | `path`, `tag` | "Added"   | Add CollectionService tag |
| `RemoveTag` | `path`, `tag` | "Removed" | Remove a tag              |
| `GetTags`   | `path`        | string[]  | Get all tags              |
| `GetTagged` | `tag`         | path[]    | Get instances with tag    |
| `HasTag`    | `path`, `tag` | boolean   | Check if has tag          |

## World Settings

| Method       | Parameters | Returns | Description           |
| ------------ | ---------- | ------- | --------------------- |
| `SetGravity` | `gravity`  | "Set"   | Set workspace gravity |
| `GetGravity` | -          | number  | Get workspace gravity |

## Runtime State

| Method      | Parameters | Returns | Description                |
| ----------- | ---------- | ------- | -------------------------- |
| `IsStudio`  | -          | boolean | Check if running in Studio |
| `IsRunMode` | -          | boolean | Check if in run mode       |
| `IsEdit`    | -          | boolean | Check if in edit mode      |
| `IsRunning` | -          | boolean | Check if game running      |

## Workspace Utilities

| Method              | Parameters       | Returns                     | Description              |
| ------------------- | ---------------- | --------------------------- | ------------------------ |
| `GetServerTimeNow`  | -                | number                      | Get server time          |
| `GetRealPhysicsFPS` | -                | number                      | Get physics FPS          |
| `GetDistance`       | `path1`, `path2` | number                      | Distance between objects |
| `Chat`              | `message`        | "Sent"/"Chat not available" | Send system message      |

## Players

| Method              | Parameters                    | Returns                                | Description            |
| ------------------- | ----------------------------- | -------------------------------------- | ---------------------- |
| `GetPlayers`        | -                             | string[]                               | Get player names       |
| `GetPlayerInfo`     | `name`                        | {UserId, DisplayName, Team, Character} | Get player info        |
| `GetPlayerPosition` | `username`                    | [x,y,z]                                | Get character position |
| `TeleportPlayer`    | `username`, `position[x,y,z]` | "Teleported"                           | Teleport player        |
| `KickPlayer`        | `username`, `reason?`         | "Kicked"                               | Kick from game         |

## Teams

| Method          | Parameters                          | Returns    | Description           |
| --------------- | ----------------------------------- | ---------- | --------------------- |
| `CreateTeam`    | `name`, `color?`, `autoAssignable?` | path       | Create a Team         |
| `SetPlayerTeam` | `playerName`, `teamName`            | "Set"      | Assign player to team |
| `GetPlayerTeam` | `playerName`                        | string/nil | Get player's team     |

## Leaderstats

| Method               | Parameters                                              | Returns | Description       |
| -------------------- | ------------------------------------------------------- | ------- | ----------------- |
| `CreateLeaderstat`   | `playerName`, `statName`, `valueType?`, `initialValue?` | path    | Create leaderstat |
| `SetLeaderstatValue` | `playerName`, `statName`, `value`                       | "Set"   | Set stat value    |
| `GetLeaderstatValue` | `playerName`, `statName`                                | any     | Get stat value    |

## Character

| Method                   | Parameters              | Returns   | Description         |
| ------------------------ | ----------------------- | --------- | ------------------- |
| `GetCharacter`           | `playerName`            | path/nil  | Get character model |
| `SetCharacterAppearance` | `playerName`, `userId?` | "Applied" | Apply appearance    |

## Animation

| Method          | Parameters                                  | Returns   | Description          |
| --------------- | ------------------------------------------- | --------- | -------------------- |
| `LoadAnimation` | `humanoidPath`, `animationId`               | trackId   | Load animation track |
| `PlayAnimation` | `trackId`, `fadeTime?`, `weight?`, `speed?` | "Playing" | Play animation       |
| `StopAnimation` | `trackId`, `fadeTime?`                      | "Stopped" | Stop animation       |

## Humanoid

| Method                   | Parameters                      | Returns                | Description                |
| ------------------------ | ------------------------------- | ---------------------- | -------------------------- |
| `GetHumanoidState`       | `humanoidPath`                  | string                 | Get current state          |
| `ChangeHumanoidState`    | `humanoidPath`, `state`         | "Changed"              | Set humanoid state         |
| `TakeDamage`             | `humanoidPath`, `amount`        | "Damaged"              | Apply damage               |
| `GetAccessories`         | `humanoidPath`                  | path[]                 | Get worn accessories       |
| `AddAccessory`           | `humanoidPath`, `accessoryPath` | "Added"                | Equip accessory            |
| `RemoveAccessories`      | `humanoidPath`                  | "Removed"              | Remove all accessories     |
| `GetHumanoidDescription` | `humanoidPath`                  | {HeadColor, scales...} | Get appearance description |
