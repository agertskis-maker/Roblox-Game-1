# Island build recipes (Lane 3)

The island is built in Studio from Git-tracked Luau recipes, not saved by hand. This folder
holds the notes; the recipe modules live in `src/island/` (server-only: they map to
`ServerStorage.Island` and are never sent to players).

## Where the recipes sync from (read this first)

`default.project.json` does not map `src/island` yet. A shared `ServerStorage` entry is
proposed on the board and needs all three lane owners to agree. Until then the private
island place uses a **stopgap** project file outside the repository:

    C:\Users\agert\Documents\Car-Hop-Art\island-preview.project.json

It maps everything `default.project.json` maps, plus `ServerStorage.Island` from this
worktree's `src/island`. It is used only for `CarHop-Island-Test.rbxl`, served on port 34873,
never committed, and **must be deleted once the team decides** on the permanent entry.

## Rebuild (Studio edit mode, private island place only)

1. From the island worktree: `rojo serve C:\Users\agert\Documents\Car-Hop-Art\island-preview.project.json --port 34873`, then connect the Rojo plugin in `CarHop-Island-Test.rbxl`.
2. Command bar (edit mode): `require(game.ServerStorage.Island.IslandBuild).build()`.
   Rebuilding cleans up first. `build({ helpers = false })` leaves out the dimension helpers.
3. Checks: `require(game.ServerStorage.Island.Preview.LayoutChecks).run()`.
4. Playtest measurements (server side): `require(game.ServerStorage.Island.Preview.WalkTests).spawnApproaches()` and `.routes()`.
5. Lapping performance test (client side, in a playtest):
   `require(game.Players.LocalPlayer.PlayerScripts.Client.Home.Island.LappingPreview).start()`, then `.measure(10)`, then `.stop()`.

## Cleanup

`require(game.ServerStorage.Island.IslandBuild).cleanup()` removes `Workspace.Lane3_IslandPreview`,
clears only the island's terrain box (x and z from -320 to 320, y from -16 to 4) and restores the
terrain grass and sand colours and the water settings saved before the first build. It never
clears Workspace or Terrain globally.

See `manifest.md` for what the build makes and where the numbers come from.
