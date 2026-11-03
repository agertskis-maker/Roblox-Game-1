--!strict
-- LoadingBoot: the ReplicatedFirst bootstrap of the Car Hop loading screen (big round M15). A LocalScript that runs before
-- anything else on the client. SELF-CONTAINED: it needs only the three Loading modules mapped beside it, never a shared
-- game module (no Trove, no Tokens, no Packages), because none of those has replicated yet.
--
-- WHERE IT LIVES AND HOW IT IS MAPPED (the lead adds this to beta.project.json ONLY; default.project.json is not touched):
--
--   "ReplicatedFirst": {
--     "$className": "ReplicatedFirst",
--     "LoadingBoot": { "$path": "src/replicatedfirst/LoadingBoot.client.luau" },
--     "Loading": { "$path": "src/client/UI/Loading" }
--   }
--
-- This file sits OUTSIDE src/client on purpose: default.project.json maps all of src/client into StarterPlayerScripts, so a
-- LocalScript left under it would also run a second time there. The Loading folder holds ModuleScripts only (nothing runs
-- by itself), so it is safe for the same folder to be mapped here AND to arrive under src/client.
--
-- ORDER (BRIEF M15-02a). 1) require the modules inside pcall; if any is missing the default Roblox loading screen is left
-- alone (we return before touching it). 2) Build the screen in PlayerGui inside pcall; if that fails, again leave the default.
-- 3) ONLY THEN call ReplicatedFirst:RemoveDefaultLoadingScreen(). 4) Start the controller: a small preload manifest, the
-- essential readiness gates and the separate 12 s watchdog (see LoadingController). 5) On the way out set the LocalPlayer
-- attribute `Lane3LoadingDone` to true, which the Welcome back queue waits for (a card must not open over the loading screen).
--
-- READINESS. game:IsLoaded() is not enough. The screen also waits for the local character's root part and, once
-- REQUIRE_READY_FLAG is true, for the game to set the LocalPlayer attribute `Lane3GameReady` to true when streaming, the
-- profile and the controls are up. The flag is OFF by default so this ships without a handshake; the lead turns it on when
-- the game sets the attribute.

local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local TeleportService = game:GetService("TeleportService")

-- Edit these three to wire the beta ------------------------------------------------------------------------------------
local REQUIRE_READY_FLAG = false
local READY_ATTRIBUTE = "Lane3GameReady"
local DONE_ATTRIBUTE = "Lane3LoadingDone"
-- The preload manifest: ONLY what the first playable view and its immediate controls need, short and deduplicated. These two
-- ids already exist in the project (the UI click and the Cash tick of Prototype/Sounds.luau); the lead adds the first view's
-- art here. Never Workspace, never every World, never every shop item.
local MANIFEST = {
	"rbxassetid://15675032796",
	"rbxassetid://127645268874265",
}
local FADE_SECONDS = 0.45
---------------------------------------------------------------------------------------------------------------------------

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local loading = script.Parent:WaitForChild("Loading", 5)
if not loading then
	warn(
		"[LoadingBoot] the Loading folder is not mapped into ReplicatedFirst; leaving the default loading screen alone"
	)
	return
end

local okScreen, LoadingScreen = pcall(function()
	return require(loading:WaitForChild("LoadingScreen", 5) :: ModuleScript) :: any
end)
local okController, LoadingController = pcall(function()
	return require(loading:WaitForChild("LoadingController", 5) :: ModuleScript) :: any
end)
if not (okScreen and okController) then
	warn("[LoadingBoot] a Loading module is missing or failed to load; leaving the default loading screen alone")
	return
end

local okView, view = pcall(function()
	return LoadingScreen.new(playerGui)
end)
if not okView then
	warn(
		"[LoadingBoot] could not build the loading screen ("
			.. tostring(view)
			.. "); leaving the default loading screen alone"
	)
	return
end

-- the screen is mounted: now the engine's own screen may go
ReplicatedFirst:RemoveDefaultLoadingScreen()

local function markDone()
	player:SetAttribute(DONE_ATTRIBUTE, true)
end

local function character(): boolean
	local c = player.Character
	return c ~= nil and c:FindFirstChild("HumanoidRootPart") ~= nil
end

local env = {
	isLoaded = function(): boolean
		return game:IsLoaded()
	end,
	hasCharacter = character,
	gameReady = function(): boolean?
		if REQUIRE_READY_FLAG then
			return player:GetAttribute(READY_ATTRIBUTE) == true
		end
		return nil
	end,
	preload = function(ids: { string }, onItem: (string, string) -> ())
		-- PreloadAsync has no timeout argument: the controller's own watchdog decides when to stop waiting for it
		local ok, err = pcall(function()
			ContentProvider:PreloadAsync(ids, function(assetId: string, status: Enum.AssetFetchStatus)
				onItem(assetId, status.Name)
			end)
		end)
		if not ok then
			warn("[LoadingBoot] PreloadAsync failed: " .. tostring(err))
		end
	end,
	now = os.clock,
	wait = task.wait,
	spawn = function(fn: () -> ())
		task.spawn(fn)
	end,
	-- a working way out when the game never becomes ready: back into this place
	rejoin = function()
		local ok, err = pcall(function()
			TeleportService:Teleport(game.PlaceId, player)
		end)
		if not ok then
			warn("[LoadingBoot] rejoin failed: " .. tostring(err))
			view.setStatus("Could not reconnect from here. Please rejoin from the Roblox app.")
		end
	end,
}

local sink = LoadingScreen.sinkFor(view, FADE_SECONDS, markDone)

local started, startError = pcall(function()
	LoadingController.start(env, { manifest = MANIFEST, requireReadyFlag = REQUIRE_READY_FLAG }, sink)
end)
if not started then
	-- the controller itself failed: never leave a frozen splash over a working game
	warn("[LoadingBoot] the controller failed to start (" .. tostring(startError) .. "); closing the loading screen")
	view.fadeOut(0.2, markDone)
end
