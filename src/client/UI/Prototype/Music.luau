--!strict
-- RUN MUSIC controller for the HUD prototype (Lane 3 preview, Round 2 R2-A, revised in Round 3 R3-A). One World loop at a
-- time, a tension layer driven by the capture progress the HUD is given, and ONE duck source. Presentation only: it never
-- changes game timing and reads only the progress it is handed.
--
-- LICENSED MUSIC IS METADATA-SCREENED ONLY. The eight candidates below (two per World and two tension layers) are
-- Creator Store tracks from the APMOfficial partner account: free, public, IsPublicDomain, ids taken from API responses
-- (vault/design/research/run-music-candidates.md). Round 3: Adam APPROVED these eight; they stay as they are. Nothing here
-- has been listened to: no claim is made that any of it sounds good, fits, or loops cleanly. Music is OFF by default
-- (Music.enable(true) is the audition switch; the A/B controls live only in the private audition harness). From
-- 2026-10-28 private review videos carry the game audio, music included, so Adam can judge it (his rule, CLAUDE.md).
--
-- Signal path (one parent the user controls, one duck, two groups; this module never touches the parent's volume):
--   Music (AudioMix: the player's MUSIC level and mute, Settings and the Home switch, 2026-10-29)
--   -> Lane3PreviewMusic (the approved mix level, 0.5)
--     -> Lane3Music_Duck (the single duck source: floor 0.6, attack ~80 ms, release ~400 ms)
--         -> Lane3Music_Base (the World loop; dips under the tension layer) -> Lane3Music_Tension (the tension layer)
-- The user's level is the parent's Volume and nothing here writes it, so a duck always releases to "whatever the user set
-- now" (a slider moved DURING a duck is honoured) and a muted parent (Music Off) stays silent: no restore here can un-mute.
-- Levels are quiet beneath the effects by design (Sounds.MIX.musicBed, about -8 dB under Cash at the reference mix).
--
-- ROUND 3 (finding 10): the controller is EVENT-DRIVEN. There is no Heartbeat connection and no polling thread. Every change
-- of state (World, mute, enable, tension, duck, candidate) starts a finite TweenService tween on the Sound or the group,
-- and the tween removes itself when it ends; the duck release is one cancellable task.delay per duck id. Fades are short
-- and smooth: at most FADE_OUT (0.4 s) out and FADE_IN (0.3 s) in, including a first start (from 0: no surprise loud
-- start), a World change, mute and unmute, enable, tension start and stop, and the eviction of an overflowing voice. A voice
-- that is still fading out when its track is wanted again is REVIVED (fade back in on the same Sound: no restart of the
-- loop, no new Sound), which also keeps rapid World changes to the live loop plus at most two fading ones. Nothing writes
-- Loop, SoundId or a per-frame property while the music is steady.
--
--   Music.enable(on) / Music.isEnabled()      -- default OFF
--   Music.setMuted(m)                         -- MusicSetting: Music toggle Off. Nothing plays while muted
--   Music.setWorld(id)                        -- crossfade the base loop to the World's track (no duplicate, no restart)
--   Music.useCandidate(key, 1 | 2)            -- A/B (private audition harness only): key is a World id or "Tension"
--   Music.tension(progress01, phase)          -- phase "Holding" | "Securing": the layer follows the supplied progress
--   Music.resolve() / Music.cancel()          -- confirmation resolves it (0.4 s); cancel / failure / exit fade it (0.3 s)
--   Music.duck(id, seconds)                   -- ref-counted by id: the same id never stacks
--   Music.stop(fade?)                         -- fade everything out (at most 0.4 s) and forget the World
--   Music.reset()                             -- everything now, no fades (preview reset, unmount, tests)
--   Music.state() / Music.getDebugState()     -- debug numbers for the playground and the audition (JSON safe)
--   Music.baseSound() -> Sound?               -- the live base loop (test seam; not part of the JSON state)

local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local AudioMix = require(script.Parent.AudioMix)
local Sounds = require(script.Parent.Sounds)

local Music = {}

export type Track = { id: string, title: string, seconds: number, volume: number, note: string }

Music.DUCK_FLOOR = 0.6
Music.DUCK_ATTACK = 0.08
Music.DUCK_RELEASE = 0.4
Music.FADE_IN = 0.3 -- the longest fade-in anywhere (R3-A: at most 0.3 s)
Music.FADE_OUT = 0.4 -- the longest fade-out anywhere (R3-A: at most 0.4 s)
Music.FADE_WORLD = 0.4 -- the old loop going out under a new World's loop
Music.FADE_RESOLVE = 0.4 -- the tension layer once the capture is confirmed
Music.FADE_CANCEL = 0.3 -- the tension layer on cancel, failure, leaving Run
Music.FADE_MUTE = 0.25 -- Music Off
Music.FADE_DISABLE = 0.3 -- the audition switch Off
Music.FADE_EVICT = 0.1 -- a fading voice pushed out by a new one finishes its fade this fast (never a hard cut)
Music.TENSION_PEAK = 0.8 -- the tension layer's level at ALMOST and while SECURING (modest, not a climax)
Music.TENSION_STEP = 0.05 -- the layer only moves when its target moves by a whole step (no churn on every progress tick)
Music.TENSION_RATE = 1.2 -- level per second while following progress; each step is still capped at FADE_IN
Music.BASE_DIP = 0.35 -- how far the base bed sinks under a full tension layer

local BED = Sounds.MIX.musicBed -- every track plays at the mix's music bed level (about -8 dB under Cash)
local MAX_DYING = 2 -- a burst of World changes never leaves more than the live loop and two fading ones

-- BALANCE PASS (round 3 close-out, 2026-10-28; lead's call, reversible). Measured from the private review recordings
-- (Studio's own output, process loopback, ffmpeg ebur128 integrated LUFS over 15 s of each track at the same bed level):
-- Downtown A -33.6, B -33.9; Dusty Highway A -37.6, B -35.3; Summit Pass A -40.2, B -35.4. Each World track more than
-- 1 LU from the Downtown pair's mean (-33.8) gets a trim in dB so every World sits at about the same loudness.
local function trimmed(db: number): number
	return BED * 10 ^ (db / 20)
end

local TRACKS: { [string]: { Track } } = {
	Downtown = {
		{
			id = "rbxassetid://9043233916",
			title = "On The Double Funk (Bruton, APM)",
			seconds = 31,
			volume = BED,
			note = "funk with sliding brass stabs; may be too busy under UI",
		},
		{
			id = "rbxassetid://9045963404",
			title = "Jazz In Cantina B (MUSICA.IT, APM)",
			seconds = 31,
			volume = BED,
			note = "bright lively swing",
		},
	},
	DustyHighway = {
		{
			id = "rbxassetid://9042728995",
			title = "That Summer (JGM Music, APM)",
			seconds = 30,
			volume = trimmed(3.8), -- measured -37.6 LUFS
			note = "relaxed acoustic guitar picks, warm bass, handclap-like percussion; not twangy",
		},
		{
			id = "rbxassetid://9042459623",
			title = "Goodnight Ladies (Soho, APM)",
			seconds = 30,
			volume = trimmed(1.5), -- measured -35.3 LUFS
			note = "bouncy country-western; may read comic",
		},
	},
	SummitPass = {
		{
			id = "rbxassetid://9045486243",
			title = "Songbird (a 30) (Ded Good, APM)",
			seconds = 32,
			volume = trimmed(6.4), -- measured -40.2 LUFS
			note = "fingerpicked guitar and twinkling glockenspiel; very gentle",
		},
		{
			id = "rbxassetid://1842008042",
			title = "Into the Blue Sky (a 30) (A. J. King, APM)",
			seconds = 31,
			volume = trimmed(1.6), -- measured -35.4 LUFS
			note = "animation-style uplifting orchestral",
		},
	},
	Tension = {
		{
			id = "rbxassetid://9042246814",
			title = "Inquisitive (A1 Stealthy) (KPM Toolkit, APM)",
			seconds = 24,
			volume = BED,
			note = "light-footed pizzicato and mallets, 120 bpm",
		},
		{
			id = "rbxassetid://1841766311",
			title = "Building Tension b (Tom Howe, APM)",
			seconds = 84,
			volume = BED,
			note = "light tension bed, orchestral hybrid",
		},
	},
}

type Slot = { tween: Tween?, done: RBXScriptConnection? }

-- state: "In" (fading in), "Live", "Out" (fading out; destroyed when the fade ends unless revived)
type Voice = {
	sound: Sound,
	slot: Slot,
	key: string,
	index: number,
	volume: number, -- the track's Sound.Volume at fade level 1
	state: string,
}

local enabled = false
local muted = false
local world: string? = nil
local chosen: { [string]: number } = {}
local base: Voice? = nil
local tensionVoice: Voice? = nil
local tensionTarget = 0
local dying: { Voice } = {} -- fading-out base voices, oldest first (the eviction order)
local all: { [Voice]: boolean } = {} -- every live voice, so a reset cannot miss one
local duckTimers: { [string]: thread } = {}
local duckHeld = false
local duckGroup: SoundGroup? = nil
local baseGroup: SoundGroup? = nil
local tensionGroup: SoundGroup? = nil
local duckSlot: Slot = {}
local dipSlot: Slot = {}
local tweenCount = 0
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

----------------------------------------------------------------------------------------------
-- Tweens: finite, one per slot, cancelled when replaced, and gone when they end

local function cancelSlot(slot: Slot)
	local tween = slot.tween
	if tween then
		slot.tween = nil
		tweenCount -= 1
		local done = slot.done
		slot.done = nil
		if done then
			done:Disconnect() -- so the cancel below runs no completion handler
		end
		tween:Cancel()
	end
end

local function runTween(slot: Slot, inst: Instance, target: number, seconds: number, onDone: (() -> ())?)
	cancelSlot(slot)
	if seconds <= 0 then
		(inst :: any).Volume = target
		if onDone then
			onDone()
		end
		return
	end
	local style = if seconds <= 0.1 then Enum.EasingStyle.Linear else Enum.EasingStyle.Sine
	local tween =
		TweenService:Create(inst, TweenInfo.new(seconds, style, Enum.EasingDirection.InOut), { Volume = target })
	slot.tween = tween
	tweenCount += 1
	slot.done = tween.Completed:Once(function()
		if slot.tween ~= tween then
			return -- a replaced tween (signals can be deferred): the new one owns the bookkeeping
		end
		slot.tween = nil
		slot.done = nil
		tweenCount -= 1
		if onDone then
			onDone()
		end
	end)
	tween:Play()
end

----------------------------------------------------------------------------------------------
-- Voices

local function newVoice(key: string, group: SoundGroup): Voice
	local track = pick(key)
	local s = Instance.new("Sound")
	s.Name = "Music_" .. key
	s.SoundId = track.id
	s.Looped = true
	s.Volume = 0 -- always starts silent; the fade brings it up
	s.SoundGroup = group
	s.Parent = group
	s:Play()
	created += 1
	local v: Voice = {
		sound = s,
		slot = {},
		key = key,
		index = chosen[key] or 1,
		volume = track.volume,
		state = "In",
	}
	all[v] = true
	return v
end

local function levelOf(v: Voice): number
	return if v.volume > 0 then v.sound.Volume / v.volume else 0
end

local function destroyVoice(v: Voice)
	cancelSlot(v.slot)
	all[v] = nil
	if v.sound.Parent then
		v.sound:Destroy()
		destroyed += 1
	end
end

local function fadeVoice(v: Voice, level: number, seconds: number, onDone: (() -> ())?)
	runTween(v.slot, v.sound, level * v.volume, seconds, onDone)
end

local function fadeIn(v: Voice, seconds: number)
	v.state = "In"
	fadeVoice(v, 1, math.min(seconds, Music.FADE_IN), function()
		v.state = "Live"
	end)
end

local function removeDying(v: Voice)
	local i = table.find(dying, v)
	if i then
		table.remove(dying, i)
	end
end

-- Start a voice's fade-out; it is destroyed when the fade ends (never sooner, never abruptly).
local function fadeOutVoice(v: Voice, seconds: number)
	v.state = "Out"
	fadeVoice(v, 0, math.min(seconds, Music.FADE_OUT), function()
		removeDying(v)
		if tensionVoice == v then
			tensionVoice = nil
		end
		destroyVoice(v)
	end)
end

-- A base voice goes to the fading list. If the list is full the quietest fading voice leaves it: a voice that is already
-- inaudible (under 5% of its level) is destroyed at once, any other finishes its fade in FADE_EVICT (a short smooth ramp
-- from where it is, never a one-frame cut of an audible voice). With the revive-first order in setWorld, a cycle of
-- Worlds never gets here: the list only overflows when A/B candidates create several different tracks of one World.
local function pushDying(v: Voice, seconds: number)
	while #dying >= MAX_DYING do
		local quietest = 1
		for i = 2, #dying do
			if dying[i].sound.Volume < dying[quietest].sound.Volume then
				quietest = i
			end
		end
		local out = table.remove(dying, quietest) :: Voice
		if levelOf(out) <= 0.05 then
			destroyVoice(out)
		else
			fadeOutVoice(out, Music.FADE_EVICT)
		end
	end
	table.insert(dying, v)
	fadeOutVoice(v, seconds)
end

local function takeDying(key: string, index: number): Voice?
	for i, v in dying do
		if v.key == key and v.index == index and v.sound.Parent then
			table.remove(dying, i)
			return v
		end
	end
	return nil
end

local function retireBase(seconds: number)
	local b = base
	if b then
		base = nil
		pushDying(b, seconds)
	end
end

-- The base bed sinks under the tension layer (a group tween, so it never fights the voice's own fade).
local function setDip(amount: number, seconds: number)
	if baseGroup then
		runTween(dipSlot, baseGroup, 1 - Music.BASE_DIP * math.clamp(amount, 0, 1), seconds)
	end
end

local function fadeOutTension(seconds: number)
	local tv = tensionVoice
	if not tv or tv.state == "Out" then
		return
	end
	tensionTarget = 0
	local s = math.min(seconds, Music.FADE_OUT)
	fadeOutVoice(tv, s)
	setDip(0, s)
end

----------------------------------------------------------------------------------------------
-- Public API

function Music.enable(on: boolean)
	enabled = on
	if not on then
		local w = world -- remembered, so enabling again resumes the same World
		Music.stop(Music.FADE_DISABLE)
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
		-- the parent group is already (or about to be) 0; also fade the voices out so nothing streams while Music is Off
		local w = world
		Music.stop(Music.FADE_MUTE)
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
	local index = chosen[id] or 1
	local b = base
	local sameWorld = world == id and b ~= nil and b.index == index
	world = id
	if not enabled or muted or sameWorld then
		return
	end
	ensureGroups()
	-- the track is still fading out from a moment ago: bring that Sound back (no restart, no new Sound). This comes BEFORE
	-- the current base is retired: retiring first could push the very voice we want back out of the fading list (the
	-- 4-voices-in-a-3-World-cycle bug) and then create a duplicate of it.
	local revived = takeDying(id, index)
	retireBase(Music.FADE_WORLD)
	local v = revived or newVoice(id, baseGroup :: SoundGroup)
	base = v
	fadeIn(v, Music.FADE_IN)
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
		-- the old tension track finishes its fade as a fading voice; the next progress tick starts the chosen one
		local tv = tensionVoice
		tensionVoice = nil
		tensionTarget = 0
		setDip(0, Music.FADE_CANCEL)
		if tv.state ~= "Out" then
			pushDying(tv, Music.FADE_CANCEL)
		end
	end
end

-- The tension layer follows the capture progress it is handed: nothing below 50%; 0.2 to 0.55 across 50-75%; at
-- ALMOST (75%+) and while SECURING it holds at TENSION_PEAK. It never resolves by itself: only Music.resolve() does.
-- It moves only when its target moves by a whole TENSION_STEP, so a progress tick that changes nothing changes nothing here.
function Music.tension(progress01: number, phase: string)
	if not enabled or muted or not world then
		return
	end
	local p = math.clamp(if progress01 ~= progress01 then 0 else progress01, 0, 1)
	local target: number
	if phase == "Securing" or p >= 0.75 then
		target = Music.TENSION_PEAK -- ALMOST and SECURING share the modest peak
	elseif p < 0.5 then
		target = 0
	else
		local raw = 0.2 + 0.35 * (p - 0.5) / 0.25
		target = math.floor(raw / Music.TENSION_STEP + 0.5) * Music.TENSION_STEP
	end
	local tv = tensionVoice
	if target <= 0 then
		if tv and tv.state ~= "Out" then
			fadeOutTension(Music.FADE_CANCEL)
		end
		return
	end
	if tv and tv.state ~= "Out" and target == tensionTarget then
		return
	end
	ensureGroups()
	local from = 0
	if not tv then
		tv = newVoice("Tension", tensionGroup :: SoundGroup)
		tensionVoice = tv
	else
		from = levelOf(tv) -- a layer still fading out is revived from where it is
	end
	local layer = tv :: Voice
	layer.state = "In"
	local seconds = math.clamp(math.abs(target - from) / Music.TENSION_RATE, 0.1, Music.FADE_IN)
	tensionTarget = target
	fadeVoice(layer, target, seconds, function()
		layer.state = "Live"
	end)
	setDip(target / Music.TENSION_PEAK, seconds)
end

function Music.resolve()
	fadeOutTension(Music.FADE_RESOLVE)
end

function Music.cancel()
	fadeOutTension(Music.FADE_CANCEL)
end

function Music.duck(id: string, seconds: number)
	if not enabled or muted or (base == nil and tensionVoice == nil) then
		return
	end
	ensureGroups()
	local old = duckTimers[id]
	if old then
		task.cancel(old) -- the same id refreshes its own entry: no stacking
	end
	duckTimers[id] = task.delay(math.max(seconds, 0.1), function()
		duckTimers[id] = nil
		if next(duckTimers) == nil then
			duckHeld = false
			if duckGroup then
				runTween(duckSlot, duckGroup, 1, Music.DUCK_RELEASE)
			end
		end
	end)
	if not duckHeld and duckGroup then
		duckHeld = true
		runTween(duckSlot, duckGroup, Music.DUCK_FLOOR, Music.DUCK_ATTACK)
	end
end

function Music.stop(fade: number?)
	local f = math.clamp(fade or Music.FADE_OUT, 0.05, Music.FADE_OUT)
	retireBase(f)
	fadeOutTension(f)
	world = nil
end

-- Everything now: no fades (preview reset, unmount, tests). The player's own level (the parent group) is never touched.
function Music.reset()
	for id, thread in duckTimers do
		task.cancel(thread)
		duckTimers[id] = nil
	end
	duckHeld = false
	cancelSlot(duckSlot)
	cancelSlot(dipSlot)
	if duckGroup then
		duckGroup.Volume = 1
	end
	if baseGroup then
		baseGroup.Volume = 1
	end
	for v in table.clone(all) do
		destroyVoice(v)
	end
	base = nil
	tensionVoice = nil
	tensionTarget = 0
	table.clear(dying)
	table.clear(all)
	world = nil
	enabled = false
	muted = false
	chosen = {}
end

function Music.tracks(): { [string]: { Track } }
	return TRACKS
end

function Music.baseSound(): Sound?
	local b = base
	return if b and b.sound.Parent then b.sound else nil
end

function Music.state(): { [string]: any }
	local ducks = 0
	for _ in duckTimers do
		ducks += 1
	end
	local live = 0
	local liveSum = 0
	for _, child in SoundService:GetDescendants() do
		if child:IsA("Sound") and string.sub(child.Name, 1, 6) == "Music_" then
			live += 1
			liveSum += child.Volume
		end
	end
	local b = base
	local tv = tensionVoice
	return {
		enabled = enabled,
		muted = muted,
		world = world,
		candidate = if world then (chosen[world] or 1) else nil,
		tensionCandidate = chosen.Tension or 1,
		baseId = if b then b.sound.SoundId else nil,
		baseLevel = if b then levelOf(b) else 0,
		-- the base bed's effective level inside the music parent: its own Volume times the dip group
		baseVolume = if b then b.sound.Volume * (if baseGroup then baseGroup.Volume else 1) else 0,
		baseLoaded = if b then b.sound.IsLoaded else false,
		baseSeconds = if b then b.sound.TimeLength else 0,
		tensionLevel = if tv then levelOf(tv) else 0,
		tensionTarget = tensionTarget,
		tensionOn = tv ~= nil,
		duckLevel = if duckGroup then duckGroup.Volume else 1,
		duckSources = ducks,
		liveMusicSounds = live,
		musicVolumeSum = liveSum,
		dying = #dying,
		created = created,
		destroyed = destroyed,
		tweens = tweenCount,
		timers = ducks,
		heartbeatConnections = 0, -- by construction: this module connects nothing per frame
		parentVolume = AudioMix.group("Music").Volume, -- the player's MUSIC level (Settings, 2026-10-29)
		mixVolume = Sounds.musicGroup().Volume, -- the approved mix level nested under it (0.5, never written)
	}
end

function Music.getDebugState(): { [string]: any }
	return Music.state()
end

-- The one duck source: the stings that matter (capture, new best, milestone) duck the music; ticks and Results counts do not.
Sounds.setDuckHandler(function(hook: string, seconds: number)
	Music.duck(hook, seconds)
end)

return Music
