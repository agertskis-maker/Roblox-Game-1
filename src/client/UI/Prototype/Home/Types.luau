--!strict
-- Shared types for the Home HUD prototype components (Lane 3 preview). Matches the component
-- contract in vault/design/specs/hud-prototype-architecture.md.

local Screen = require(script.Parent.Parent.Screen)
local Store = require(script.Parent.Parent.Store)

export type Ctx = {
	store: Store.StoreObject,
	screen: Screen.ScreenObject,
	layer: Frame,
	world: Folder,
}

return {}
