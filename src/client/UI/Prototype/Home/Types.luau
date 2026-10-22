--!strict
-- Shared types for the Home HUD prototype components (Lane 3 preview). Matches the component
-- contract in vault/design/specs/hud-prototype-architecture.md and the rebuild worker guide
-- (vault/design/specs/hud-rebuild-worker-guide.md): ctx = { store, screen, layer, world, priority }.
-- `priority` is optional here so a component still mounts when a harness has not supplied the
-- arbiter yet; components that need a slot treat a missing arbiter as "always granted".

local Priority = require(script.Parent.Parent.Priority)
local Screen = require(script.Parent.Parent.Screen)
local Store = require(script.Parent.Parent.Store)

export type Ctx = {
	store: Store.StoreObject,
	screen: Screen.ScreenObject,
	layer: Frame,
	world: Folder,
	priority: Priority.Arbiter?,
}

return {}
