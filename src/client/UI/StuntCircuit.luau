--!strict
-- StuntCircuit: puts the Stunt Circuit screens together (Round 6, C-02, C-03, C-04). Lane 3.
--
--   * The island's Stunt Circuit gate gets a "Race" prompt (made on this client) that opens the pre-race card.
--   * Pre-race card: your own cars (the live Garage, else the PREVIEW roster), the paint you wear (StyleState), the track
--     name and a big START. CUSTOMIZE opens the Garage's Style screen with that car's tab (C-04); TOP TIMES opens the board.
--   * START plays a lap through StuntCircuitFeed (the one adapter; a PREVIEW lap until Brian R's Circuit reports its
--     events), with the race HUD (StuntMock) counting checkpoints, then the results card: the time the SERVER measured,
--     your best this visit, NEW BEST! when it is, RETRY and HOME.
--   * This server's board (C-03): the best time of each player in this server, live, your own row highlighted, titled
--     "THIS SERVER". No other server's times, and no reward from a time.
--
--   StuntCircuit.attach(shell, mount, components, userPanel) -> cleanup

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local CosmeticPreviewCatalog = require(ReplicatedStorage.Shared.UI.CosmeticPreviewCatalog)
local LiveData = require(ReplicatedStorage.Shared.UI.LiveData)
local RosterFixtures = require(ReplicatedStorage.Shared.UI.RosterFixtures)
local Trove = require(ReplicatedStorage.Packages.Trove)

local Prototype = script.Parent:WaitForChild("Prototype")
local StyleState = require(Prototype:WaitForChild("StyleState")) :: any
local StuntFixtures = require(Prototype:WaitForChild("SupportFixtures"):WaitForChild("StuntFixtures")) :: any
local StuntCircuitFeed = require(script.Parent:WaitForChild("StuntCircuitFeed"))

local StuntCircuit = {}

StuntCircuit.TrackName = "Stunt Circuit"
StuntCircuit.PromptName = "RaceStuntCircuit"

local function paintColour(): Color3?
	local equipped = StyleState.get().equipped
	local item = equipped and CosmeticPreviewCatalog.byId("Paint", equipped.Paint)
	local colours = item and (item :: any).colours
	return if type(colours) == "table" then colours[1] else nil
end

-- The cars on the pre-race card: the player's own, best rarity first (stats are Brian R's: "not set yet" until then).
local function carsFor(): { any }
	local owned = LiveData.cars()
	local list = {}
	for _, car in RosterFixtures.Cars do
		if next(owned) == nil and not car.loaner then
			continue -- no live Garage (a preview): only the Loaners
		end
		if next(owned) ~= nil and owned[car.id] == nil then
			continue
		end
		table.insert(list, {
			id = car.id,
			name = car.name,
			family = car.name,
			paint = paintColour(),
			stats = nil,
			missingArt = false,
		})
	end
	return list
end

-- This server's board from the server's CircuitBoard attribute ("userId|name|time;..."), as a StuntFixtures.Board.
local function liveBoard(): any
	local net = ReplicatedStorage:FindFirstChild(LiveData.NetName)
	local text = net and net:GetAttribute("CircuitBoard")
	local entries, you = {}, nil
	if type(text) == "string" then
		for userId, name, time in string.gmatch(text, "(%d+)|([^|;]*)|([%d%.]+)") do
			local t = tonumber(time) :: number
			local rank = #entries + 1
			for _, e in entries do
				if e.time == t then
					rank = e.rank
					e.tied = true
				end
			end
			local entry = {
				rank = rank,
				rankText = tostring(rank),
				name = name,
				time = t,
				you = tonumber(userId) == Players.LocalPlayer.UserId,
				tied = rank ~= #entries + 1,
			}
			table.insert(entries, entry)
			if entry.you then
				you = entry
			end
		end
	end
	for _, e in entries do
		e.rankText = if e.tied then e.rank .. "=" else tostring(e.rank)
	end
	return {
		id = "ThisServer",
		label = "This server",
		state = if #entries == 0 then "Empty" else "Ready",
		entries = entries,
		you = you,
		youInTop = you ~= nil,
		week = "This server, right now",
	}
end

-- The island gate: the Stunt Circuit's gantry or sign in the built island (any part whose name says Stunt).
local function gatePart(): BasePart?
	local env = Workspace:FindFirstChild("Lane3_IslandEnvironment")
	local folder = env and env:FindFirstChild("Destinations")
	if not folder then
		return nil
	end
	local best: BasePart? = nil
	for _, d in folder:GetDescendants() do
		if d:IsA("BasePart") and string.find(string.lower(d.Name), "stunt") then
			if best == nil or d.Size.Magnitude > (best :: BasePart).Size.Magnitude then
				best = d
			end
		end
	end
	return best
end

function StuntCircuit.attach(
	shell: any,
	mount: (string, { string }, string, any?) -> (),
	components: any,
	userPanel: any
): () -> ()
	local trove = Trove.new()
	local feed: any = nil
	local selected: any = nil
	local live = LiveData.active()

	local function hud(): any
		return components.stuntHud
	end

	local function startLap()
		local h = hud()
		if h then
			h:open()
			h:setTime(0)
			h:setCheckpoint(0, StuntCircuitFeed.Checkpoints)
			h:setMedals(StuntFixtures.MedalTargets)
			h:play()
		end
		feed:fixtureLap()
	end

	mount("stuntResults", { "Screens", "StuntResults" }, "Overlay", {
		onRetry = function()
			components.stuntResults:close()
			startLap()
		end,
		onHome = function()
			components.stuntResults:close()
		end,
	})
	mount("stuntHud", { "Screens", "StuntMock" }, "Hud", {
		onExit = function()
			feed:cancel()
		end,
	})
	mount("stuntPre", { "Screens", "StuntPreRace" }, "Modal", {
		course = StuntCircuit.TrackName,
		onStart = function(car: any)
			selected = car
			components.stuntPre:close()
			startLap()
		end,
		-- C-04: straight into the Garage's Style screen, on Paint, for the selected car
		onCustomize = function(_car: any)
			components.stuntPre:close()
			shell.customizeAt("Paint")
		end,
		onTopTimes = function()
			userPanel("stuntBoard")
		end,
	})

	feed = StuntCircuitFeed.new({
		onEvent = function(kind: string, index: number?)
			local h = hud()
			if h and kind == StuntCircuitFeed.Events.Checkpoint and index then
				h:setCheckpoint(index, StuntCircuitFeed.Checkpoints)
				h:flashCheckpoint(index)
			end
		end,
		onResult = function(finished: boolean, time: number?, bestBefore: number?)
			local h = hud()
			if h then
				h:stop()
				h:close()
			end
			local results = components.stuntResults
			if results then
				results:show({
					id = "Live",
					label = if selected then selected.name else StuntCircuit.TrackName,
					finished = finished,
					time = time,
					best = bestBefore,
				})
			end
		end,
	})
	trove:Add(function()
		feed:destroy()
	end)

	local function openPre()
		local pre = components.stuntPre
		if not pre then
			return
		end
		pre:setCars(carsFor())
		pre:setGhost(if feed:best() then "Your best this visit: " .. StuntFixtures.formatTime(feed:best()) else nil)
		pre:open()
	end
	(StuntCircuit :: any).open = openPre

	-- the live board (C-03) replaces the PREVIEW one whenever a live server is here
	local function refreshBoard()
		local board = components.stuntBoard
		if board and live then
			board:setLabels("THIS SERVER: TOP TIMES", "Players in this server now")
			board:setBoard(liveBoard())
		end
	end
	local net = ReplicatedStorage:FindFirstChild(LiveData.NetName)
	if net then
		trove:Connect(net:GetAttributeChangedSignal("CircuitBoard"), refreshBoard)
	end
	task.defer(refreshBoard)

	-- the Race prompt at the gate (local to this player; the server only ever sees the lap events)
	trove:Add(task.spawn(function()
		for _ = 1, 60 do
			local part = gatePart()
			if part then
				local prompt = Instance.new("ProximityPrompt")
				prompt.Name = StuntCircuit.PromptName
				prompt.ActionText = "Race"
				prompt.ObjectText = StuntCircuit.TrackName
				prompt.KeyboardKeyCode = Enum.KeyCode.E
				prompt.HoldDuration = 0
				prompt.MaxActivationDistance = 14
				prompt.RequiresLineOfSight = false
				prompt.Parent = part
				trove:Add(prompt)
				trove:Connect(prompt.Triggered, openPre)
				return
			end
			task.wait(2)
		end
	end))
	return function()
		trove:Destroy()
	end
end

return StuntCircuit
