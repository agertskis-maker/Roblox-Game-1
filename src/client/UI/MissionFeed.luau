--!strict
-- MissionFeed: drives the Missions and Goals panel from the server's real mission state (Round 6, G-01). Lane 3.
--
-- The server (today the beta stand-in BetaMissions; Brian L's server later, same names) publishes the Player attribute
-- BetaMissions = "id=status:progress;..." (status before | active | ready | claimed) and takes ClaimMission(id). This module
-- only reads that and asks to claim: it never counts progress or pays anything, so there is no fake progress anywhere.
-- With no live server (the HUD playground, Studio previews) it does nothing and the panel keeps its PREVIEW fixtures.
--
--   MissionFeed.attach(panel) -> (() -> ())?   live updates and the claim round trip; returns a disconnect, nil when idle
--   MissionFeed.state(player?) -> State?       the panel state built from the attribute (nil when there is none)
--   MissionFeed.nextMission(player?) -> Mission?   the first unfinished mission (for the goal pill)
--   MissionFeed.claim(id) -> boolean           sends the claim when attached (false: no live feed, the preview resolves)
--   MissionFeed.claimable(player?) -> number   missions ready to claim (Round 7, U-05: the red count on the Missions button)
--   MissionFeed.goalLine(player?) -> string?   the one most useful next thing, in one short line (Round 7, H-01)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LiveData = require(ReplicatedStorage.Shared.UI.LiveData)
local MissionsPreview = require(ReplicatedStorage.Shared.UI.MissionsPreview)

local MissionFeed = {}

MissionFeed.Attribute = "BetaMissions"
MissionFeed.ClaimRemote = "ClaimMission"
local claimer: ((id: string) -> ())? = nil

type Entry = { status: string, progress: number }

local function parse(player: Player): { [string]: Entry }?
	local text = player:GetAttribute(MissionFeed.Attribute)
	if type(text) ~= "string" then
		return nil
	end
	local out: { [string]: Entry } = {}
	for id, status, progress in string.gmatch(text, "([^=;]+)=(%a+):(%d+)") do
		out[id] = { status = status, progress = tonumber(progress) :: number }
	end
	return out
end

local function card(mission: MissionsPreview.Mission, entry: Entry): { [string]: any }
	return {
		id = mission.id,
		text = mission.text,
		sub = if MissionsPreview.saved(mission) then nil else "Counts this visit",
		icon = mission.icon,
		target = mission.target,
		progress = entry.progress,
		format = mission.format,
		reward = mission.reward,
		claim = "None",
		tab = mission.tab, -- Round 7 (U-05): the panel's category tab
	}
end

function MissionFeed.state(player: Player?): { [string]: any }?
	local who = player or Players.LocalPlayer
	local entries = parse(who)
	if not entries then
		return nil
	end
	-- Round 7 (U-05): every open mission, each on its category tab; a ready one comes first in its tab
	local missions, pool = {}, {}
	for _, wantReady in { true, false } do
		for _, mission in MissionsPreview.List do
			local entry = entries[mission.id]
			if
				entry
				and (entry.status == "ready") == wantReady
				and entry.status ~= "before"
				and entry.status ~= "claimed"
			then
				table.insert(missions, card(mission, entry))
			end
		end
	end
	local goals = {}
	for _, id in MissionsPreview.Goals do
		local mission = MissionsPreview.get(id) :: MissionsPreview.Mission
		local entry = entries[id] or { status = "active", progress = 0 }
		table.insert(goals, {
			id = id,
			text = mission.text,
			icon = mission.icon,
			done = entry.status ~= "active",
			progress = entry.progress,
			target = mission.target,
			reward = mission.reward,
		})
	end
	return {
		source = "Your real progress. Rewards are PREVIEW Cash.",
		load = "Ready",
		missions = missions,
		goals = goals,
		pool = pool,
	}
end

function MissionFeed.nextMission(player: Player?): MissionsPreview.Mission?
	local entries = parse(player or Players.LocalPlayer)
	if not entries then
		return nil
	end
	for _, mission in MissionsPreview.List do
		local entry = entries[mission.id]
		if entry and entry.status == "active" then
			return mission
		end
	end
	return nil
end

function MissionFeed.claimable(player: Player?): number
	local entries = parse(player or Players.LocalPlayer)
	local n = 0
	for _, entry in entries or {} do
		if entry.status == "ready" then
			n += 1
		end
	end
	return n
end

-- H-01: one line for the top of the hub, from the server's mission state only: a claim waiting, else the next Goal, else the
-- next mission. nil with no live feed (the line hides).
local GOAL_LINE: { [string]: string } = {
	["first-catch"] = "Hop onto cars in a run to catch your first car!",
	["level-3"] = "Buy Raceway level 3 at your Raceway shop!",
	["downtown-5"] = "5 Downtown cars opens Dusty Highway!",
	dusty = "Open Dusty Highway at its portal!",
	gold = "Catch one car 25 times to make it GOLD!",
	summit = "Open Summit Pass at its portal!",
}

function MissionFeed.goalLine(player: Player?): string?
	local entries = parse(player or Players.LocalPlayer)
	if not entries then
		return nil
	end
	local ready = MissionFeed.claimable(player)
	if ready > 0 then
		return if ready == 1
			then "A Mission is ready! Tap MISSIONS to claim it."
			else "Missions are ready! Tap MISSIONS to claim them."
	end
	for _, id in MissionsPreview.Goals do
		local entry = entries[id]
		if entry and entry.status == "active" then
			return GOAL_LINE[id]
		end
	end
	local nextOne = MissionFeed.nextMission(player)
	return if nextOne then nextOne.text else "Catch cars to earn more money!"
end

function MissionFeed.claim(id: string): boolean
	local fn = claimer
	if fn then
		fn(id)
		return true
	end
	return false
end

function MissionFeed.attach(panel: any): (() -> ())?
	if not LiveData.active() then
		return nil
	end
	local player = Players.LocalPlayer
	local conns: { RBXScriptConnection } = {}
	local pending: string? = nil
	local holdUntil = 0
	local function push()
		local state = MissionFeed.state(player)
		if state and not pending and os.clock() >= holdUntil then
			panel:setState(state)
		end
	end
	table.insert(
		conns,
		player:GetAttributeChangedSignal(MissionFeed.Attribute):Connect(function()
			if os.clock() < holdUntil then
				task.delay(holdUntil - os.clock() + 0.05, push) -- after the claim celebration
			else
				push()
			end
		end)
	)
	local result = LiveData.onResult(function(what: string, ok: boolean)
		if what ~= "ClaimMission" or not pending then
			return
		end
		local id = pending :: string
		pending = nil
		holdUntil = os.clock() + 2.5 -- the panel's own celebration and replacement play first
		panel:resolveClaim(id, if ok then "Success" else "Error")
		task.delay(2.6, push)
	end)
	if result then
		table.insert(conns, result)
	end
	claimer = function(id: string)
		local remote = LiveData.remote(MissionFeed.ClaimRemote)
		if remote then
			pending = id
			remote:FireServer(id)
		end
	end
	push()
	return function()
		claimer = nil
		for _, c in conns do
			c:Disconnect()
		end
	end
end

return MissionFeed
