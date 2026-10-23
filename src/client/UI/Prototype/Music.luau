--!strict
-- RUN MUSIC controller for the HUD prototype (Lane 3 preview, Round 2, R2-A). One World loop at a time, a tension layer
-- driven by the capture progress the HUD is given, and ONE duck source. Presentation only: it never changes game timing
-- and reads only the progress it is handed.
--
-- LICENSED MUSIC IS METADATA-SCREENED ONLY. The eight candidates below (two per World and two tension layers) are
-- Creator Store tracks from the APMOfficial partner account: free, public, IsPublicDomain, ids taken from API responses
-- (vault/design/research/run-music-candidates.md). Nothing here has been listened to: no claim is made that any of it sounds
-- good, fits, or loops cleanly. Music is OFF by default (Music.enable(true) is the audition switch), and review exports
-- stay muted until the rights for video are established.
--
-- Signal path (one parent the user controls, one duck, two fades; this module never touches the parent's volume):
--   Lane3PreviewMusic (Settings level / Home toggle, MusicSetting)
--     -> Lane3Music_Duck (the single duck source: floor 0.6, attack ~80 ms, release ~400 ms)
--         -> Lane3Music_Base (the World loop; crossfades)   -> Lane3Music_Tension (the tension layer)
-- A muted parent (Music Off) is silence for everything below it.
--
--   Music.enable(on) / Music.isEnabled()      -- default OFF
--   Music.setMuted(m)                         -- MusicSetting: Music toggle Off. Nothing plays while muted
--   Music.setWorld(id)                        -- crossfade the base loop to the World's track (no duplicate, no restart)
--   Music.useCandidate(key, 1 | 2)            -- A/B: key is a World id or "Tension"
--   Music.tension(progress01, phase)          -- phase "Holding" | "Securing": the layer follows the supplied progress
--   Music.resolve() / Music.cancel()          -- confirmation resolves it (0.8 s); cancel / failure / exit fade it (0.4 s)
--   Music.duck(id, seconds)                   -- ref-counted by id: the same id never stacks
--   Music.stop(fade?)                         -- fade everything out and forget the World
--   Music.state() -> table                    -- debug numbers for the playground and the audition

local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")

local Sounds = require(script.Parent.Sounds)

local Music = {}

export type Track = { id: string, title: string, seconds: number, volume: number, note: string }

Music.DUCK_FLOOR = 0.6
Music.DUCK_ATTACK = 0.08
Music.DUCK_RELEASE = 0.4
Music.FADE_WORLD = 1.2
Music.FADE_RESOLVE = 0.8
Music.FADE_CANCEL = 0.4
Music.TENSION_PEAK = 0.8 -- the tension layer's level at ALMOST and while SECURING (modest, not a climax)
Music.BASE_DIP = 0.35 -- how far the base bed sinks under a full tension layer

local TRACKS: { [string]: { Track } } = {
	Downtown = {
		{
			id = "rbxassetid://9043233916",
			title = "On The Double Funk (Bruton, APM)",
			seconds = 31,
			volume = 0.5,
			note = "funk with sliding brass stabs; may be too busy under UI",
		},
		{
			id = "rbxassetid://9045963404",
			title = "Jazz In Cantina B (MUSICA.IT, APM)",
			seconds = 31,
			volume = 0.5,
			note = "bright lively swing",
		},
	},
	DustyHighway = {
		{
			id = "rbxassetid://9042728995",
			title = "That Summer (JGM Music, APM)",
			seconds = 30,
			volume = 0.5,
			note = "relaxed acoustic guitar picks, warm bass, handclap-like percussion; not twangy",
		},
		{
			id = "rbxassetid://9042459623",
			title = "Goodnight Ladies (Soho, APM)",
			seconds = 30,
			volume = 0.5,
			note = "bouncy country-western; may read comic",
		},
	},
	SummitPass = {
		{
			id = "rbxassetid://9045486243",
			title = "Songbird (a 30) (Ded Good, APM)",
			seconds = 32,
			volume = 0.5,
			note = "fingerpicked guitar and twinkling glockenspiel; very gentle",
		},
		{
			id = "rbxassetid://1842008042",
			title = "Into the Blue Sky (a 30) (A. J. King, APM)",
			seconds = 31,
			volume = 0.5,
			note = "animation-style uplifting orchestral",
		},
	},
	Tension = {
		{
			id = "rbxassetid://9042246814",
			title = "Inquisitive (A1 Stealthy) (KPM Toolkit, APM)",
			seconds = 24,
			volume = 0.5,
			note = "light-footed pizzicato and mallets, 120 bpm",
		},
		{
			id = "rbxassetid://1841766311",
			title = "Building Tension b (Tom Howe, APM)",
			seconds = 84,
			volume = 0.5,
			note = "light tension bed, orchestral hybrid",
		},
	},
}

type Voice = {
	sound: Sound,
	level: number,
	target: number,
	rate: number,
	volume: number,
	kill: boolean,
	key: string,
	index: number,
}

local enabled = false
local muted = false
local world: string? = nil
local chosen: { [string]: number } = {}
local base: Voice? = nil
local tensionVoice: Voice? = nil
local tensionLevel = 0
local tensionTarget = 0
local dying: { Voice } = {}
local duckUntil: { [string]: number } = {}
local duckLevel = 1
local duckGroup: SoundGroup? = nil
local baseGroup: SoundGroup? = nil
local tensionGroup: SoundGroup? = nil
local connection: RBXScriptConnection? = nil
local clock = 0
local created = 0
local destroyed = 0

local function ensureGroups()
	local parent = Sounds.musicGroup()
	local function child(name: string, of: Instance): SoundGroup
		local g = of:FindFirstChild(name) :: SoundGroup?
		if not g then
			local made = Instance.new("SoundGroup")
			made.Name = name
			made.Volume = 1
			made.Parent = of
			g = made
		end
		return g :: SoundGroup
	end
	local duck = child("Lane3Music_Duck", parent)
	duckGroup = duck
	baseGroup = child("Lane3Music_Base", duck)
	tensionGroup = child("Lane3Music_Tension", duck)
end

local function pick(key: string): Track
	local list = TRACKS[key]
	return list[math.clamp(chosen[key] or 1, 1, #list)]
end

local function newVoice(key: string, group: SoundGroup, fadeSeconds: number): Voice
	local track = pick(key)
	local s = Instance.new("Sound")
	s.Name = "Music_" .. key
	s.SoundId = track.id
	s.Looped = true
	s.Volume = 0
	s.SoundGroup = group
	s.Parent = group
	s:Play()
	created += 1
	return {
		sound = s,
		level = 0,
		target = 1,
		rate = 1 / math.max(fadeSeconds, 0.05),
		volume = track.volume,
		kill = false,
		key = key,
		index = chosen[key] or 1,
	}
end

local MAX_DYING = 2 -- a burst of World changes never leaves more than the live loop and two fading ones

local function fadeOut(v: Voice, seconds: number)
	while #dying >= MAX_DYING do
		local oldest = table.remove(dying, 1) :: Voice
		if oldest.sound.Parent then
			oldest.sound:Destroy()
			destroyed += 1
		end
	end
	v.target = 0
	v.rate = math.max(v.level, 0.01) / math.max(seconds, 0.05)
	v.kill = true
	table.insert(dying, v)
end

local function destroyVoice(v: Voice)
	if v.sound.Parent then
		v.sound:Destroy()
		destroyed += 1
	end
end

local function approach(current: number, target: number, step: number): number
	if current < target then
		return math.min(target, current + step)
	end
	return math.max(target, current - step)
end

local function activeDuck(now: number): boolean
	for id, untilTime in duckUntil do
		if untilTime > now then
			return true
		end
		duckUntil[id] = nil
	end
	return false
end

local function idle(): boolean
	return base == nil
		and tensionVoice == nil
		and #dying == 0
		and tensionLevel <= 0.001
		and duckLevel >= 0.999
		and next(duckUntil) == nil
end

local function step(dt: number)
	clock += dt
	local now = clock
	-- the single duck source: attack to the floor, release back to 1
	local wantDuck = if activeDuck(now) then Music.DUCK_FLOOR else 1
	local rate = if wantDuck < duckLevel
		then (1 - Music.DUCK_FLOOR) / Music.DUCK_ATTACK
		else (1 - Music.DUCK_FLOOR) / Music.DUCK_RELEASE
	duckLevel = approach(duckLevel, wantDuck, rate * dt)
	if duckGroup then
		duckGroup.Volume = duckLevel
	end
	-- the tension layer follows its target (rise slowly, fall at the fade rate set by resolve / cancel)
	local tv = tensionVoice
	if tv then
		tensionLevel = approach(tensionLevel, tensionTarget, tv.rate * dt)
		tv.level = tensionLevel
		tv.sound.Volume = tensionLevel * tv.volume
		if tensionLevel <= 0.001 and tensionTarget <= 0 then
			destroyVoice(tv)
			tensionVoice = nil
			tensionLevel = 0
		end
	end
	local b = base
	if b then
		b.level = approach(b.level, b.target, b.rate * dt)
		local dip = 1 - Music.BASE_DIP * math.clamp(tensionLevel / Music.TENSION_PEAK, 0, 1)
		b.sound.Volume = b.level * b.volume * dip
	end
	for i = #dying, 1, -1 do
		local v = dying[i]
		v.level = approach(v.level, 0, v.rate * dt)
		v.sound.Volume = v.level * v.volume
		if v.level <= 0.001 then
			destroyVoice(v)
			table.remove(dying, i)
		end
	end
	if idle() and connection then
		connection:Disconnect()
		connection = nil
	end
end

local function ensureLoop()
	if not connection then
		connection = RunService.Heartbeat:Connect(step)
	end
end

function Music.enable(on: boolean)
	enabled = on
	if not on then
		local w = world -- remembered, so enabling again resumes the same World
		Music.stop(0.3)
		world = w
	elseif world and not muted and not base then
		local w = world
		world = nil
		Music.setWorld(w)
	end
end

function Music.isEnabled(): boolean
	return enabled
end

function Music.setMuted(m: boolean)
	local was = muted
	muted = m
	if m then
		-- the parent group is already 0; also stop the voices so nothing streams while Music is Off
		local w = world
		Music.stop(0.05)
		world = w
	elseif was and enabled and world and not base then
		-- only a real unmute starts the loop again; a repeated setMuted(false) (every Settings slider tick calls it) is a no-op
		local w = world
		world = nil
		Music.setWorld(w)
	end
end

function Music.setWorld(id: string)
	if not TRACKS[id] or id == "Tension" then
		return
	end
	local sameWorld = world == id and base ~= nil and not base.kill and base.index == (chosen[id] or 1)
	world = id
	if not enabled or muted or sameWorld then
		return
	end
	ensureGroups()
	if base then
		fadeOut(base, Music.FADE_WORLD)
	end
	base = newVoice(id, baseGroup :: SoundGroup, Music.FADE_WORLD)
	ensureLoop()
end

function Music.useCandidate(key: string, index: number)
	if not TRACKS[key] then
		return
	end
	chosen[key] = math.clamp(index, 1, #TRACKS[key])
	if key == world and enabled and not muted then
		local w = world
		world = nil
		Music.setWorld(w)
	elseif key == "Tension" and tensionVoice then
		fadeOut(tensionVoice, Music.FADE_CANCEL)
		tensionVoice = nil
		tensionLevel = 0
	end
end

-- The tension layer follows the capture progress it is handed: nothing below 50%; 0.2 to 0.55 across 50-75%; at
-- ALMOST (75%+) and while SECURING it holds at TENSION_PEAK. It never resolves by itself: only Music.resolve() does.
function Music.tension(progress01: number, phase: string)
	if not enabled or muted or not world then
		return
	end
	local p = math.clamp(progress01, 0, 1)
	local target: number
	if phase == "Securing" or p >= 0.75 then
		target = Music.TENSION_PEAK -- ALMOST and SECURING share the modest peak
	elseif p < 0.5 then
		target = 0
	else
		target = 0.2 + 0.35 * (p - 0.5) / 0.25
	end
	if target <= 0 and not tensionVoice then
		return
	end
	if not tensionVoice and target > 0 then
		ensureGroups()
		local v = newVoice("Tension", tensionGroup :: SoundGroup, 1.5)
		v.rate = 0.6 -- the layer rises over about a second and a half
		tensionVoice = v
		tensionLevel = 0
	end
	local tv = tensionVoice
	if tv then
		tv.rate = if target >= tensionLevel then 0.6 else 1 / Music.FADE_CANCEL
		tensionTarget = target
	end
	ensureLoop()
end

function Music.resolve()
	local tv = tensionVoice
	if tv then
		tensionTarget = 0
		tv.rate = math.max(tensionLevel, 0.01) / Music.FADE_RESOLVE
		ensureLoop()
	end
end

function Music.cancel()
	local tv = tensionVoice
	if tv then
		tensionTarget = 0
		tv.rate = math.max(tensionLevel, 0.01) / Music.FADE_CANCEL
		ensureLoop()
	end
end

function Music.duck(id: string, seconds: number)
	if not enabled or muted or (base == nil and tensionVoice == nil) then
		return
	end
	duckUntil[id] = clock + math.max(seconds, 0.1) -- the same id refreshes its own entry: no stacking
	ensureLoop()
end

function Music.stop(fade: number?)
	local f = fade or Music.FADE_WORLD
	if base then
		fadeOut(base, f)
		base = nil
	end
	if tensionVoice then
		tensionTarget = 0
		fadeOut(tensionVoice, f)
		tensionVoice = nil
		tensionLevel = 0
	end
	world = nil
	if #dying > 0 then
		ensureLoop()
	end
end

-- Everything now: no fade (preview reset, tests).
function Music.reset()
	Music.stop(0.05)
	for _, v in dying do
		destroyVoice(v)
	end
	table.clear(dying)
	table.clear(duckUntil)
	duckLevel = 1
	if duckGroup then
		duckGroup.Volume = 1
	end
	if connection then
		connection:Disconnect()
		connection = nil
	end
	enabled = false
	muted = false
	chosen = {}
end

function Music.tracks(): { [string]: { Track } }
	return TRACKS
end

function Music.state(): { [string]: any }
	local ducks = 0
	for _ in duckUntil do
		ducks += 1
	end
	local live = 0
	for _, child in SoundService:GetDescendants() do
		if child:IsA("Sound") and string.sub(child.Name, 1, 6) == "Music_" then
			live += 1
		end
	end
	local b = base
	return {
		enabled = enabled,
		muted = muted,
		world = world,
		candidate = if world then (chosen[world] or 1) else nil,
		tensionCandidate = chosen.Tension or 1,
		baseId = if b then b.sound.SoundId else nil,
		baseLevel = if b then b.level else 0,
		baseVolume = if b then b.sound.Volume else 0,
		baseLoaded = if b then b.sound.IsLoaded else false,
		baseSeconds = if b then b.sound.TimeLength else 0,
		tensionLevel = tensionLevel,
		tensionTarget = tensionTarget,
		tensionOn = tensionVoice ~= nil,
		duckLevel = duckLevel,
		duckSources = ducks,
		liveMusicSounds = live,
		dying = #dying,
		created = created,
		destroyed = destroyed,
		looping = connection ~= nil,
		parentVolume = Sounds.musicGroup().Volume,
	}
end

-- The one duck source: the stings that matter (capture, new best, milestone) duck the music; ticks and Results counts do not.
Sounds.setDuckHandler(function(hook: string, seconds: number)
	Music.duck(hook, seconds)
end)

return Music
