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

-- Edit these to wire the beta ---------------------------------------------------------------------------------------
local REQUIRE_READY_FLAG = false
local READY_ATTRIBUTE = "Lane3GameReady"
local DONE_ATTRIBUTE = "Lane3LoadingDone"
-- The two sounds of the first view (the UI click and the Cash tick of Prototype/Sounds.luau).
local SOUNDS = {
	"rbxassetid://15675032796",
	"rbxassetid://127645268874265",
}
-- Round 4 (C-06): the art budget. The screen waits for the manifest at most this long from the start, then lets the player in
-- as soon as the game is ready and keeps fetching the rest in the background (the controller's "ReadyBackground").
local OPTIONAL_SECONDS = 8
-- How long to wait for Lane 3's icon table (Client.UI.Prototype.GameIconIds) to replicate before going on without it.
local ICON_TABLE_WAIT = 4
local FADE_SECONDS = 0.45
---------------------------------------------------------------------------------------------------------------------------

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- THE MANIFEST (Round 4, C-06): the two sounds plus every uploaded image and mesh in GameIconIds (the HUD icons, the Shop art,
-- the kiosk and Garage art, the car kit meshes): known ids, deduplicated, so the count on screen is a real one. Images are
-- fetched through ImageLabels and meshes through SpecialMeshes (a bare rbxassetid string has no asset type, and an uploaded
-- image fails that way). Never Workspace and never every World. The showroom cars are warmed after the screen, uncounted.
local KIND: { [string]: string } = {}
local function iconTable(): { [string]: string }?
	local ok, result = pcall(function()
		local t0 = os.clock()
		local node: Instance? = player:WaitForChild("PlayerScripts", ICON_TABLE_WAIT)
		for _, step in { "Client", "UI", "Prototype", "GameIconIds" } do
			local left = math.max(0.1, ICON_TABLE_WAIT - (os.clock() - t0))
			node = if node then node:WaitForChild(step, left) else nil
		end
		return if node and node:IsA("ModuleScript") then require(node) :: any else nil
	end)
	return if ok and type(result) == "table" then result else nil
end

local function buildManifest(): { string }
	local ids: { string } = {}
	for _, id in SOUNDS do
		KIND[id] = "Sound"
		table.insert(ids, id)
	end
	local icons = iconTable()
	if not icons then
		warn("[LoadingBoot] GameIconIds did not arrive in time; preloading the sounds only")
		return ids
	end
	local keys: { string } = {}
	for key in icons do
		table.insert(keys, key)
	end
	table.sort(keys)
	for _, key in keys do
		local id = icons[key]
		if type(id) == "string" and KIND[id] == nil then
			KIND[id] = if string.sub(key, 1, 4) == "car_" then "Mesh" else "Image"
			table.insert(ids, id)
		end
	end
	return ids
end

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
		-- PreloadAsync has no timeout argument: the controller's own watchdog decides when to stop waiting for it. Each id goes
		-- in as an instance of its kind, so the engine knows what it is fetching.
		local holders: { Instance } = {}
		for _, id in ids do
			local kind = KIND[id]
			if kind == "Sound" then
				local s = Instance.new("Sound")
				s.SoundId = id
				table.insert(holders, s)
			elseif kind == "Mesh" then
				local m = Instance.new("SpecialMesh")
				m.MeshType = Enum.MeshType.FileMesh
				m.MeshId = id
				table.insert(holders, m)
			else
				local l = Instance.new("ImageLabel")
				l.Image = id
				table.insert(holders, l)
			end
		end
		local ok, err = pcall(function()
			ContentProvider:PreloadAsync(holders, function(assetId: string, status: Enum.AssetFetchStatus)
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

local handle: any = nil
local function finished()
	markDone()
	if handle then
		local s = handle.summary()
		print(
			string.format(
				"[LoadingBoot] playable after %.2f s (%s): %d / %d art items loaded, %d failed",
				s.elapsed,
				s.reason,
				s.succeeded,
				s.assetsTotal,
				s.failed
			)
		)
	end
	-- the showroom cars, warmed in the background for the Garage and the Launch Pad (not counted on the screen)
	task.spawn(function()
		local cars = game:GetService("ReplicatedStorage"):WaitForChild("Cars", 10)
		if cars then
			local normal = {}
			for _, model in cars:GetChildren() do
				if model:GetAttribute("Variant") == "Normal" then
					table.insert(normal, model)
				end
			end
			pcall(function()
				ContentProvider:PreloadAsync(normal)
			end)
		end
	end)
end

local sink = LoadingScreen.sinkFor(view, FADE_SECONDS, finished)

local started, startError = pcall(function()
	handle = LoadingController.start(
		env,
		{ manifest = buildManifest(), optionalSeconds = OPTIONAL_SECONDS, requireReadyFlag = REQUIRE_READY_FLAG },
		sink
	)
end)
if not started then
	-- the controller itself failed: never leave a frozen splash over a working game
	warn("[LoadingBoot] the controller failed to start (" .. tostring(startError) .. "); closing the loading screen")
	view.fadeOut(0.2, markDone)
end
