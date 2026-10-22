--!strict
-- Typed UI sound hooks for the HUD prototype (Lane 3 preview). Components call
-- Sounds.play("CashGain") and never create sounds themselves.
--
-- HUD rebuild (2026-10-22): verified CANDIDATE sounds are loaded for Adam's listening test
-- (vault/design/research/sound-candidates.md: every id checked against the Roblox toolbox
-- details and economy APIs; creator Roblox (id 1) or the ProSoundEffects / APMOfficial partner
-- accounts; free; public). Status of every candidate: "candidate, not listened" until Adam has
-- heard it. Two candidates per category; `Sounds.useCandidate(category, 1 | 2)` switches them
-- for A/B listening. Nothing here is final audio.
--
-- Mix: one preview UI SoundGroup "Lane3PreviewUI" (the Settings effects volume), restrained
-- per-hook volumes (0.2–0.45), at most MAX_VOICES sounds at once and MAX_PER_HOOK per hook,
-- and a minimum interval per hook so high-frequency gains and ticks are throttled. Music goes
-- to a separate "Lane3PreviewMusic" group; positional ambience, if ever added, belongs in its own
-- group, not here.
--
--   Sounds.play(hook, volume?)                 -- one-shot (counted even when silent)
--   Sounds.rise(hook, progress01) -> nil       -- the capture riser: one voice, pitch follows
--                                                 progress (clamped 0.9–1.25), started on first
--                                                 call, continued after
--   Sounds.stopRise(hook)                      -- stop it now (cancel, destroy, run end)
--   Sounds.loop(hook) -> stop()                -- a looping tally; returns its stop function
--   Sounds.stopAll()                           -- every live voice (preview reset)
--
-- The approved big-gain behaviour keeps its "CashBig" hook and throttle exactly; no asset was
-- ever chosen for it, so none is assigned here (nothing to replace). See "Waiting for you".

local SoundService = game:GetService("SoundService")

local Sounds = {}

export type Hook =
	"Tap"
	| "Open"
	| "Close"
	| "CashGain"
	| "CashBig"
	| "CashSpend"
	| "Toast"
	| "TutorialDone"
	| "Unlock"
	| "LapPay"
	| "KeysTick"
	| "KeysRise"
	| "KeysCapture"
	| "Hop"
	| "Dash"
	| "Milestone"
	| "ResultsCount"
	| "ResultsTick"
	| "NewBest"
	| "Warning"
	| "Bonk"

type Config = { id: string, volume: number, minInterval: number }

local MAX_VOICES = 6
local MAX_PER_HOOK = 2

-- Candidates by category (ids verified 2026-10-22; see the research note for evidence).
local CANDIDATES: { [string]: { { id: string, title: string, volume: number } } } = {
	Click = {
		{ id = "rbxassetid://15675032796", title = "Roblox_UI_Small_Click (Roblox)", volume = 0.35 },
		{ id = "rbxassetid://15675059323", title = "Roblox_UI_Bright_Click (Roblox)", volume = 0.35 },
	},
	Cash = {
		{ id = "rbxassetid://127645268874265", title = "CoinTransfer_01 (Roblox)", volume = 0.3 },
		{ id = "rbxassetid://9126073001", title = "Synth Sparkle Tone ... Ding (Pro Sound Effects)", volume = 0.3 },
	},
	Rise = {
		{ id = "rbxassetid://16480578169", title = "Roblox_Pinball_8Bit_Riser_01 (Roblox)", volume = 0.3 },
		{ id = "rbxassetid://9117885256", title = "Power Up Sweeteners 10 (Pro Sound Effects)", volume = 0.3 },
	},
	Fanfare = {
		{ id = "rbxassetid://1842335078", title = "Cartoon Fanfare (c) (APM Music)", volume = 0.4 },
		{ id = "rbxassetid://12222253", title = "victory.wav (Roblox)", volume = 0.45 },
	},
	Chime = {
		{ id = "rbxassetid://17208361335", title = "Roblox GUI - Notification High (Roblox)", volume = 0.3 },
		{ id = "rbxassetid://15675043410", title = "Roblox_UI_Tonal_Stinger (Roblox)", volume = 0.35 },
	},
	Warning = {
		{ id = "rbxassetid://16480580213", title = "Roblox_Pinball_8Bit_Blip_01 (Roblox)", volume = 0.25 },
		{ id = "rbxassetid://17208353912", title = "Roblox GUI - Negative (Roblox)", volume = 0.25 },
	},
	Bonk = {
		{ id = "rbxassetid://9113854234", title = "Comic Boinks 1 (Pro Sound Effects)", volume = 0.35 },
		{ id = "rbxassetid://12222124", title = "Short spring sound.wav (Roblox)", volume = 0.35 },
	},
	Tick = {
		{ id = "rbxassetid://16480579910", title = "Roblox_Pinball_8Bit_Blip_03 (Roblox)", volume = 0.2 },
		{
			id = "rbxassetid://16480554151",
			title = "Roblox_Pinball_Scoreboard_Tally_Loop_01 (Roblox, loop)",
			volume = 0.2,
		},
	},
}

-- Which category (and minimum interval, seconds) each hook uses. Hooks absent here stay silent.
local ROUTES: { [string]: { category: string, minInterval: number, volumeScale: number? } } = {
	Tap = { category = "Click", minInterval = 0.06 },
	Open = { category = "Click", minInterval = 0.1 },
	Close = { category = "Click", minInterval = 0.1, volumeScale = 0.8 },
	CashGain = { category = "Cash", minInterval = 0.12 },
	LapPay = { category = "Cash", minInterval = 0.25, volumeScale = 0.7 },
	KeysRise = { category = "Rise", minInterval = 0 },
	KeysCapture = { category = "Fanfare", minInterval = 1.5 },
	NewBest = { category = "Fanfare", minInterval = 2, volumeScale = 0.85 },
	Toast = { category = "Chime", minInterval = 0.4 },
	Milestone = { category = "Chime", minInterval = 0.6 },
	TutorialDone = { category = "Chime", minInterval = 1 },
	Unlock = { category = "Chime", minInterval = 0.6 },
	Warning = { category = "Warning", minInterval = 1.2 },
	Bonk = { category = "Bonk", minInterval = 0.5 },
	Hop = { category = "Bonk", minInterval = 0.3, volumeScale = 0.6 },
	ResultsTick = { category = "Tick", minInterval = 0.08 },
	ResultsCount = { category = "Tick", minInterval = 0.3 },
}

local chosen: { [string]: number } = {}
local ids: { [string]: Config } = {}
local counts: { [string]: number } = {}
local lastPlayed: { [string]: number } = {}
local live: { [Sound]: string } = {}
local liveCount = 0
local perHook: { [string]: number } = {}
local risers: { [string]: Sound } = {}
local group: SoundGroup? = nil
local music: SoundGroup? = nil

local function ensureGroup(): SoundGroup
	if group and group.Parent then
		return group
	end
	local g = SoundService:FindFirstChild("Lane3PreviewUI") :: SoundGroup?
	if not g then
		local created = Instance.new("SoundGroup")
		created.Name = "Lane3PreviewUI"
		created.Volume = 0.6
		created.Parent = SoundService
		g = created
	end
	group = g
	return g :: SoundGroup
end

function Sounds.musicGroup(): SoundGroup
	if music and music.Parent then
		return music
	end
	local g = SoundService:FindFirstChild("Lane3PreviewMusic") :: SoundGroup?
	if not g then
		local created = Instance.new("SoundGroup")
		created.Name = "Lane3PreviewMusic"
		created.Volume = 0.5
		created.Parent = SoundService
		g = created
	end
	music = g
	return g :: SoundGroup
end

function Sounds.group(): SoundGroup
	return ensureGroup()
end

local function applyRoutes()
	for hook, route in ROUTES do
		local list = CANDIDATES[route.category]
		local pick = list and list[chosen[route.category] or 1]
		if pick then
			ids[hook] = {
				id = pick.id,
				volume = pick.volume * (route.volumeScale or 1),
				minInterval = route.minInterval,
			}
		end
	end
end

-- Switch one category to its first or second candidate (A/B listening).
function Sounds.useCandidate(category: string, index: number)
	chosen[category] = index
	applyRoutes()
end

-- Override a single hook (or silence it with nil). Record the source of any id used.
function Sounds.configure(hook: Hook, id: string?, volume: number?)
	if not id or id == "" then
		ids[hook] = nil
		return
	end
	local route = ROUTES[hook]
	ids[hook] = { id = id, volume = volume or 0.3, minInterval = route and route.minInterval or 0.1 }
end

-- Disable every candidate (silent preview, the overnight behaviour).
function Sounds.silence()
	table.clear(ids)
end

function Sounds.candidates(): { [string]: { { id: string, title: string, volume: number } } }
	return CANDIDATES
end

local function track(s: Sound, hook: string)
	live[s] = hook
	liveCount += 1
	perHook[hook] = (perHook[hook] or 0) + 1
	s.Destroying:Once(function()
		if live[s] then
			live[s] = nil
			liveCount -= 1
			perHook[hook] -= 1
		end
	end)
end

local function makeSound(cfg: Config, volume: number?): Sound
	local s = Instance.new("Sound")
	s.SoundId = cfg.id
	s.Volume = volume or cfg.volume
	s.SoundGroup = ensureGroup()
	s.Parent = ensureGroup()
	return s
end

function Sounds.play(hook: Hook, volume: number?)
	counts[hook] = (counts[hook] or 0) + 1
	local cfg = ids[hook]
	if not cfg then
		return
	end
	local now = os.clock()
	if now - (lastPlayed[hook] or -math.huge) < cfg.minInterval then
		return
	end
	if liveCount >= MAX_VOICES or (perHook[hook] or 0) >= MAX_PER_HOOK then
		return
	end
	lastPlayed[hook] = now
	local s = makeSound(cfg, volume)
	track(s, hook)
	s.Ended:Once(function()
		s:Destroy()
	end)
	s:Play()
	task.delay(6, function()
		if s.Parent then
			s:Destroy()
		end
	end)
end

-- The capture riser: one voice per hook whose pitch follows the supplied progress (clamped).
-- It never changes game timing; it only reads the progress it is given.
function Sounds.rise(hook: Hook, progress01: number)
	counts[hook] = (counts[hook] or 0) + 1
	local cfg = ids[hook]
	if not cfg then
		return
	end
	local s = risers[hook]
	if not (s and s.Parent) then
		if liveCount >= MAX_VOICES then
			return
		end
		local created = makeSound(cfg)
		created.Looped = true
		track(created, hook)
		created:Play()
		risers[hook] = created
		s = created
	end
	local riser = s :: Sound
	riser.PlaybackSpeed = math.clamp(0.9 + 0.35 * math.clamp(progress01, 0, 1), 0.9, 1.25)
end

function Sounds.stopRise(hook: Hook)
	local s = risers[hook]
	risers[hook] = nil
	if s then
		s:Destroy()
	end
end

-- A looping tally (Results count-up); returns a stop function. Always stop it when the count
-- ends or the component is destroyed.
function Sounds.loop(hook: Hook): () -> ()
	counts[hook] = (counts[hook] or 0) + 1
	local cfg = ids[hook]
	if not cfg or liveCount >= MAX_VOICES then
		return function() end
	end
	local s = makeSound(cfg)
	s.Looped = true
	track(s, hook)
	s:Play()
	task.delay(8, function()
		if s.Parent then
			s:Destroy()
		end
	end)
	return function()
		if s.Parent then
			s:Destroy()
		end
	end
end

function Sounds.stopAll()
	for s in table.clone(live) do
		s:Destroy()
	end
	table.clear(risers)
end

function Sounds.counts(): { [string]: number }
	return table.clone(counts)
end

function Sounds.liveVoices(): number
	return liveCount
end

function Sounds.resetCounts()
	table.clear(counts)
end

applyRoutes()

return Sounds
