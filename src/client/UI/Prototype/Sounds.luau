--!strict
-- Typed UI sound hooks for the HUD prototype (Lane 3 preview). Components call
-- Sounds.play("CashGain") and never create sounds themselves.
--
-- HUD rebuild (2026-10-22): verified CANDIDATE sounds are loaded for Adam's listening test
-- (vault/design/research/sound-candidates.md: every id checked against the Roblox toolbox
-- details and economy APIs; creator Roblox (id 1) or the ProSoundEffects / APMOfficial partner
-- accounts; free; public). Status of every candidate: "candidate, not listened" until Adam has
-- heard it. Two candidates per category; `Sounds.useCandidate(category, 1 | 2)` switches them
-- for A/B listening. Nothing here is final audio, and nothing here claims how anything SOUNDS:
-- every check on this module is a property check (volumes, counts, spacing, lifetimes).
--
-- ROUND 3 (R3-A):
--   * The Keys "riser" was a LOOPED copy of an 8-bit riser sample (Roblox_Pinball_8Bit_Riser_01) whose PlaybackSpeed was
--     rewritten on every progress update (0.9 to 1.25): a rising sample, looped, with its pitch pushed up, restarting
--     every two seconds. That sustained, stacked, per-frame-driven rise is the harsh screech. It is gone. The progress cue
--     is now a short gentle CHIME LADDER of discrete notes (MIX.chime): at most four notes a capture, one per quarter of
--     progress, never closer than 0.25 s, each note a fresh one-shot trimmed to about half a second, pitch set ONCE when
--     the note is created (never changed afterwards), the whole ladder within five semitones and never above the
--     sample's own pitch. The hook "KeysTick" (a click per lit segment) is retired: it would stack on the chime.
--   * The capture FANFARE ("KeysCapture", a short brass sting, trimmed to 1.8 s with a smooth tail) belongs to the CONFIRMED
--     capture only. The ring being full while the answer is pending gets the ladder's last note, quietly ("KeysPending").
--     `Sounds.playOnce(hook, key)` / `Sounds.fanfare(key)` give callers a once-per-capture guard (key = the run-scoped
--     capture identity); plain `Sounds.play` keeps working.
--   * One MIX table (below) holds every level: a Volume per hook, the reference group levels, the music bed at a documented
--     ratio under the effects, a cap on any one effect, a cap on the sum of live effects (a new sound is scaled to the
--     headroom, or dropped when under half of itself would fit), and the voice caps. Per-hook minimum intervals stay.
--     The warning (a safety cue) and the three stings that duck the music (KeysCapture, NewBest, Milestone) are PRIORITY
--     hooks: when the caps have no room they cut the oldest lower-priority effect first (never a tally loop) and may play
--     quieter, but are not dropped; the caps themselves never bend.
--   * No per-frame work anywhere: fades and trims are finite TweenService tweens (or a TweenInfo delay) that clean
--     themselves up; each voice has one cancellable safety timer. `getDebugState()` reports live counts for all of it.
--
-- Mix: one preview UI SoundGroup "Lane3PreviewUI" at the approved effects level and a separate music group
-- "Lane3PreviewMusic" (see Music.luau). Settings sound rows (2026-10-29): both are NESTED under the player's categories
-- (AudioMix: "Effects" and "Music", the Settings sliders), so the player's level multiplies the approved mix and never
-- replaces it. Positional ambience, if ever added, gets its own mix group under AudioMix.group("Effects"), not this one.
-- "VolumeTick" is the Settings SOUND EFFECTS preview: the small click trimmed to 70 ms, at most one per 150 ms.
--
--   Sounds.play(hook, volume?)                 -- one-shot (counted even when silent)
--   Sounds.playOnce(hook, key, volume?) -> bool-- one-shot at most once per key (bounded memory); false when already played
--   Sounds.fanfare(key) -> bool                -- Sounds.playOnce("KeysCapture", key): the confirmed-capture sting
--   Sounds.rise(hook, progress01) -> nil       -- the progress chime ladder (see above); safe to call every frame
--   Sounds.stopRise(hook, immediate?)          -- end the ladder: ringing notes fade out in 0.12 s (a just-played ring-full
--                                                 note is left to ring out unless `immediate` is true)
--   Sounds.loop(hook) -> stop()                -- a looping tally; returns its stop function (a 0.15 s fade-out)
--   Sounds.stopAll()                           -- every live voice (preview reset)
--   Sounds.resetThrottles()                    -- clear throttles, the ladder, the once-memory and the history (tests)
--   Sounds.getDebugState() / Sounds.history() / Sounds.played()   -- numbers for the playground and the Mix scenarios
--
-- The approved big-gain behaviour keeps its "CashBig" hook and throttle exactly; no asset was
-- ever chosen for it, so none is assigned here (nothing to replace). See "Waiting for you".

local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local AudioMix = require(script.Parent.AudioMix)

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
	| "KeysPending"
	| "KeysCapture"
	| "Hop"
	| "HopLock"
	| "Dash"
	| "Milestone"
	| "ResultsCount"
	| "ResultsTick"
	| "NewBest"
	| "Warning"
	| "Bonk"
	| "VolumeTick"

type Config = {
	id: string,
	volume: number,
	minInterval: number,
	ladder: boolean?, -- played only by Sounds.rise (the chime ladder), never by Sounds.play
	step: number?, -- plays this ladder step by itself (the ring-full cue)
	maxSeconds: number?,
	tail: number?,
}

----------------------------------------------------------------------------------------------
-- MIX: the one table of levels (TOKEN CANDIDATES: the lead may retune after listening)

export type Chime = {
	semitones: { number }, -- the ladder, relative to the sample's own pitch (all <= 0: never above it)
	gap: number, -- seconds between two notes, at least
	maxNotes: number, -- notes per capture, at most
	seconds: number, -- a note is trimmed to this long
	tail: number, -- the smooth fade at the end of that trim
}

export type Mix = {
	sfxGroup: number, -- reference level of "Lane3PreviewUI" (the Settings default)
	musicGroup: number, -- reference level of "Lane3PreviewMusic" (the Settings default)
	sfxReference: number, -- a typical effect's Sound.Volume (the click / Cash level)
	musicBedDb: number, -- the music bed under that effect, in dB-like amplitude terms (20 * log10 of the ratio)
	musicBed: number, -- derived: the music tracks' Sound.Volume at full fade level
	musicSumCap: number, -- all live music voices together, each times its dip and duck groups (bed plus tension at its peak)
	peakCap: number, -- no effect's Sound.Volume above this
	sumCap: number, -- all live effects' Sound.Volume together (raw, before the group)
	maxVoices: number, -- live effects at once
	maxPerHook: number, -- live effects of one hook at once
	fanfareSeconds: number, -- the confirmed-capture sting is trimmed to this
	hooks: { [string]: number }, -- target Sound.Volume per hook (before the group)
	chime: Chime,
}

local SFX_GROUP = 0.6
local MUSIC_GROUP = 0.5
local SFX_REFERENCE = 0.3
local MUSIC_BED_DB = -8

local HOOK_VOLUME: { [string]: number } = {
	-- clicks and the Settings feedback: the reference level, a little under it
	Tap = 0.26,
	Open = 0.26,
	Close = 0.2,
	VolumeTick = 0.22, -- the Settings SOUND EFFECTS preview: a little under a click
	-- money: Cash is the reference; Lap Pay is a quieter background tick of the same sound
	CashGain = 0.3,
	LapPay = 0.2,
	CashBig = 0.36, -- reserved: no asset chosen, so silent
	CashSpend = 0.26, -- reserved: no asset chosen, so silent
	-- notices and stings
	Toast = 0.24,
	TutorialDone = 0.28,
	Unlock = 0.28,
	Milestone = 0.28,
	-- danger and bumps: a warning sits above the reference so it is heard over music and chimes
	Warning = 0.32,
	Bonk = 0.3,
	-- the target cue (Hop): short and low, never louder than a click
	Hop = 0.2,
	HopLock = 0.16,
	Dash = 0.2, -- reserved: no asset chosen, so silent
	-- capture: gentle chime notes, a quieter ring-full cue, and the one big sting
	KeysRise = 0.22,
	KeysPending = 0.17,
	KeysTick = 0.1, -- retired hook: silent
	KeysCapture = 0.36,
	NewBest = 0.3,
	-- Results: the tally loop and any blip stay under the reference
	ResultsTick = 0.16,
	ResultsCount = 0.16,
}

local MIX: Mix = {
	sfxGroup = SFX_GROUP,
	musicGroup = MUSIC_GROUP,
	sfxReference = SFX_REFERENCE,
	musicBedDb = MUSIC_BED_DB,
	-- the bed's EFFECTIVE level (Volume x parent group) is 10^(dB/20) of the reference effect's effective level:
	-- 0.3 * 0.6 * 0.398 / 0.5 = 0.143 Sound.Volume (about 0.072 effective, against 0.18 for Cash and 0.156 for a click)
	musicBed = SFX_REFERENCE * SFX_GROUP * 10 ^ (MUSIC_BED_DB / 20) / MUSIC_GROUP,
	musicSumCap = 0.22, -- bed 0.143 x (0.65 under the dip + 0.8 tension peak) = 0.207 at most (before the player's own level)
	peakCap = 0.4,
	sumCap = 0.9, -- fanfare 0.36 + Cash 0.3 + Warning 0.32 = 0.98: the last one is scaled to the headroom
	maxVoices = 6,
	maxPerHook = 2,
	fanfareSeconds = 1.8,
	hooks = HOOK_VOLUME,
	chime = {
		semitones = { -5, -3, -1, 0 }, -- G A B C rising to the sample's own pitch: five semitones in all
		gap = 0.25,
		maxNotes = 4,
		seconds = 0.55,
		tail = 0.15,
	},
}
Sounds.MIX = MIX

local FANFARE_TAIL = 0.3 -- the smooth end of the trimmed fanfare
local LOOP_FADE_IN = 0.12
local LOOP_FADE_OUT = 0.15
local STOP_FADE = 0.12 -- ringing chime notes at stopRise
local SHOT_SAFETY = 6 -- a one-shot that never reports Ended is destroyed after this
local LOOP_SAFETY = 8 -- a tally loop that nobody stopped is destroyed after this
local MIN_FRACTION = 0.5 -- a sound that would have to be scaled below this share of itself is dropped instead
-- Hooks that must still sound in a pile-up: the warning is a SAFETY cue (never silenced, at most quieter), the stings are
-- the three that duck the music. When the voice cap or the sum cap has no room they make room by cutting the oldest
-- lowest-priority effect (a short blip or click; never a tally loop and never a hook of their own or higher priority) and,
-- if still short, play scaled down to the headroom (at least PRIORITY_FRACTION of themselves). The caps themselves never bend.
local PRIORITY: { [string]: number } = { Warning = 3, KeysCapture = 2, NewBest = 2, Milestone = 2 }
local PRIORITY_FRACTION = 0.25
local ONCE_MEMORY = 64
local HISTORY_MAX = 128

----------------------------------------------------------------------------------------------
-- Assets (ids verified 2026-10-22; see the research note for evidence and the Round 3 list of what each one is used for)

local CANDIDATES: { [string]: { { id: string, title: string } } } = {
	Click = {
		{ id = "rbxassetid://15675032796", title = "Roblox_UI_Small_Click (Roblox)" },
		{ id = "rbxassetid://15675059323", title = "Roblox_UI_Bright_Click (Roblox)" },
	},
	Cash = {
		{ id = "rbxassetid://127645268874265", title = "CoinTransfer_01 (Roblox)" },
		{ id = "rbxassetid://9126073001", title = "Synth Sparkle Tone ... Ding (Pro Sound Effects)" },
	},
	Rise = { -- the one-shot lock-on whoosh of the Hop cue only (NOT the Keys progress cue any more)
		{ id = "rbxassetid://16480578169", title = "Roblox_Pinball_8Bit_Riser_01 (Roblox)" },
		{ id = "rbxassetid://9117885256", title = "Power Up Sweeteners 10 (Pro Sound Effects)" },
	},
	Note = { -- the gentle Keys chime notes: ONE sample played at the ladder's pitches
		{ id = "rbxassetid://9126073001", title = "Synth Sparkle Tone High Pitch Bell Tone Ding (Pro Sound Effects)" },
		{ id = "rbxassetid://15675043410", title = "Roblox_UI_Tonal_Stinger (Roblox)" },
	},
	Fanfare = {
		{ id = "rbxassetid://1842335078", title = "Cartoon Fanfare (c) (APM Music)" },
		{ id = "rbxassetid://12222253", title = "victory.wav (Roblox)" },
	},
	Chime = {
		{ id = "rbxassetid://17208361335", title = "Roblox GUI - Notification High (Roblox)" },
		{ id = "rbxassetid://15675043410", title = "Roblox_UI_Tonal_Stinger (Roblox)" },
	},
	Warning = {
		{ id = "rbxassetid://16480580213", title = "Roblox_Pinball_8Bit_Blip_01 (Roblox)" },
		{ id = "rbxassetid://17208353912", title = "Roblox GUI - Negative (Roblox)" },
	},
	Bonk = {
		{ id = "rbxassetid://9113854234", title = "Comic Boinks 1 (Pro Sound Effects)" },
		{ id = "rbxassetid://12222124", title = "Short spring sound.wav (Roblox)" },
	},
	Tick = {
		{ id = "rbxassetid://16480579910", title = "Roblox_Pinball_8Bit_Blip_03 (Roblox)" },
		{ id = "rbxassetid://16480580213", title = "Roblox_Pinball_8Bit_Blip_01 (Roblox)" },
	},
	Tally = { -- the Results count-up: a designed LOOP first (a short blip looped would be a buzz), the blip second
		{ id = "rbxassetid://16480554151", title = "Roblox_Pinball_Scoreboard_Tally_Loop_01 (Roblox, loop)" },
		{ id = "rbxassetid://16480579910", title = "Roblox_Pinball_8Bit_Blip_03 (Roblox)" },
	},
}

-- Which category (and minimum interval, seconds) each hook uses. Hooks absent here stay silent: KeysTick (retired),
-- CashBig, CashSpend and Dash (no asset ever chosen).
type Route = {
	category: string,
	minInterval: number,
	ladder: boolean?,
	step: number?,
	maxSeconds: number?,
	tail: number?,
}
local ROUTES: { [string]: Route } = {
	Tap = { category = "Click", minInterval = 0.06 },
	Open = { category = "Click", minInterval = 0.1 },
	Close = { category = "Click", minInterval = 0.1 },
	-- the Settings SOUND EFFECTS preview tick: trimmed to 70 ms, so ticks 150 ms apart never overlap into a buzz
	VolumeTick = { category = "Click", minInterval = 0.15, maxSeconds = 0.07, tail = 0.03 },
	CashGain = { category = "Cash", minInterval = 0.12 },
	LapPay = { category = "Cash", minInterval = 0.25 },
	-- the Keys progress chime: driven by Sounds.rise (one note a quarter of progress, 0.25 s apart at the closest)
	KeysRise = { category = "Note", minInterval = 0.25, ladder = true },
	-- the ring is full and the answer is still pending: only the ladder's last note, quiet (never a victory)
	KeysPending = { category = "Note", minInterval = 1.5, step = 4 },
	-- the confirmed-capture sting: short, with a smooth tail
	KeysCapture = { category = "Fanfare", minInterval = 1.5, maxSeconds = MIX.fanfareSeconds, tail = FANFARE_TAIL },
	NewBest = { category = "Fanfare", minInterval = 2, maxSeconds = MIX.fanfareSeconds, tail = FANFARE_TAIL },
	Toast = { category = "Chime", minInterval = 0.4 },
	Milestone = { category = "Chime", minInterval = 0.6 },
	TutorialDone = { category = "Chime", minInterval = 1 },
	Unlock = { category = "Chime", minInterval = 0.6 },
	Warning = { category = "Warning", minInterval = 1.2 },
	Bonk = { category = "Bonk", minInterval = 0.5 },
	Hop = { category = "Bonk", minInterval = 0.3 },
	-- the soft lock-on whoosh when a target is selected; throttled so target flicker cannot spam it (Round 2)
	HopLock = { category = "Rise", minInterval = 0.6 },
	-- repeated high-frequency blips are throttled to about eight a second at the most
	ResultsTick = { category = "Tick", minInterval = 0.12 },
	ResultsCount = { category = "Tally", minInterval = 0.3 },
}

-- Round 2: the one duck source for the run music. Only the stings that matter duck it (seconds); ticks and Results counts
-- never do. Music registers its handler (Music.luau), so Sounds does not depend on Music.
local DUCK: { [string]: number } = { KeysCapture = 1.6, NewBest = 1.2, Milestone = 0.8 }
local duckHandler: ((string, number) -> ())? = nil

----------------------------------------------------------------------------------------------
-- State

type Voice = {
	hook: string,
	volume: number, -- the Volume it was created with (an upper bound while it fades)
	step: number?,
	prio: number, -- 3 safety cue, 2 sting, 1 everything else (see PRIORITY)
	born: number, -- os.clock() at creation: the oldest of the lowest priority is evicted first
	looped: boolean, -- a tally loop is never evicted (its owner stops it)
	leaving: boolean?, -- already fading out: a second stop leaves it alone
	timer: thread?,
	tween: Tween?,
	done: RBXScriptConnection?,
}

type Played = { hook: string, at: number, volume: number, speed: number }

local chosen: { [string]: number } = {}
local ids: { [string]: Config } = {}
local counts: { [string]: number } = {}
local playedCount: { [string]: number } = {}
local lastPlayed: { [string]: number } = {}
local voices: { [Sound]: Voice } = {}
local liveCount = 0
local perHook: { [string]: number } = {}
local tweenCount = 0
local timerCount = 0
local history: { Played } = {}
local onceSeen: { [string]: boolean } = {}
local onceOrder: { string } = {}
local group: SoundGroup? = nil
local music: SoundGroup? = nil

-- the chime ladder of the capture in progress
local chime = { step = 0, notes = 0, lastAt = -math.huge, highest = 0 }

-- A mix group nested under the player's category (AudioMix): found where it is (an older build left it in SoundService)
-- and moved under the category, or made there. Its Volume is the approved mix level and nothing else writes it.
local function mixGroup(name: string, category: AudioMix.Category, level: number): SoundGroup
	local parent = AudioMix.group(category)
	local g = parent:FindFirstChild(name) or SoundService:FindFirstChild(name)
	if not (g and g:IsA("SoundGroup")) then
		local created = Instance.new("SoundGroup")
		created.Name = name
		g = created
	end
	local sg = g :: SoundGroup
	sg.Volume = level
	sg.Parent = parent
	return sg
end

local function ensureGroup(): SoundGroup
	local g = group
	if g and g.Parent and g.Parent == AudioMix.group("Effects") then
		return g
	end
	local made = mixGroup("Lane3PreviewUI", "Effects", MIX.sfxGroup)
	group = made
	return made
end

function Sounds.musicGroup(): SoundGroup
	local g = music
	if g and g.Parent and g.Parent == AudioMix.group("Music") then
		return g
	end
	local made = mixGroup("Lane3PreviewMusic", "Music", MIX.musicGroup)
	music = made
	return made
end

function Sounds.group(): SoundGroup
	return ensureGroup()
end

function Sounds.setDuckHandler(fn: ((string, number) -> ())?)
	duckHandler = fn
end

local function applyRoutes()
	for hook, route in ROUTES do
		local list = CANDIDATES[route.category]
		local pick = list and list[chosen[route.category] or 1]
		if pick then
			ids[hook] = {
				id = pick.id,
				volume = HOOK_VOLUME[hook] or MIX.sfxReference,
				minInterval = route.minInterval,
				ladder = route.ladder,
				step = route.step,
				maxSeconds = route.maxSeconds,
				tail = route.tail,
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
	ids[hook] = {
		id = id,
		volume = volume or HOOK_VOLUME[hook] or MIX.sfxReference,
		minInterval = route and route.minInterval or 0.1,
	}
end

-- Disable every candidate (silent preview, the overnight behaviour).
function Sounds.silence()
	table.clear(ids)
end

function Sounds.candidates(): { [string]: { { id: string, title: string } } }
	return CANDIDATES
end

----------------------------------------------------------------------------------------------
-- Voices: every effect is one Sound with one safety timer and at most one finite tween, all released when it is destroyed

local function cancelTween(v: Voice)
	local tween = v.tween
	if tween then
		v.tween = nil
		tweenCount -= 1
		local done = v.done
		v.done = nil
		if done then
			done:Disconnect()
		end
		tween:Cancel()
	end
end

local function runTween(s: Sound, v: Voice, info: TweenInfo, volume: number, onDone: (() -> ())?)
	cancelTween(v)
	local tween = TweenService:Create(s, info, { Volume = volume })
	v.tween = tween
	tweenCount += 1
	v.done = tween.Completed:Once(function()
		if v.tween ~= tween then
			return -- a replaced tween (signals can be deferred): the new one owns the bookkeeping
		end
		v.tween = nil
		v.done = nil
		tweenCount -= 1
		if onDone then
			onDone()
		end
	end)
	tween:Play()
end

local function onGone(s: Sound)
	local v = voices[s]
	if not v then
		return
	end
	voices[s] = nil
	liveCount -= 1
	perHook[v.hook] -= 1
	cancelTween(v)
	local timer = v.timer
	if timer then
		v.timer = nil
		timerCount -= 1
		task.cancel(timer)
	end
end

-- Destroy a voice and settle its bookkeeping NOW (the Destroying signal may be deferred, so the counts must not wait for it).
local function release(s: Sound)
	onGone(s)
	if s.Parent then
		s:Destroy()
	end
end

local function sumLive(): number
	local sum = 0
	for _, v in voices do
		sum += v.volume
	end
	return sum
end

type SpawnOptions = {
	speed: number?,
	looped: boolean?,
	fadeIn: number?,
	seconds: number?, -- trim the sound to this long, with a smooth `tail`
	tail: number?,
	step: number?,
}

-- Cut the oldest effect of the lowest priority that is below `prio` (never a loop). False when nothing may be cut.
local function evictFor(prio: number): boolean
	local victim: Sound? = nil
	local chosenVoice: Voice? = nil
	for s, v in voices do
		if v.prio < prio and not v.looped then
			if
				not chosenVoice
				or v.prio < chosenVoice.prio
				or (v.prio == chosenVoice.prio and v.born < chosenVoice.born)
			then
				victim = s
				chosenVoice = v
			end
		end
	end
	if victim then
		release(victim)
		return true
	end
	return false
end

-- Create, play and track one effect. Returns nil when a cap says no (voices, per hook, or not enough headroom in the sum cap).
-- A priority hook (PRIORITY) first cuts lower-priority effects to make room, so the counts and the sum stay inside the caps.
local function spawn(hook: string, cfg: Config, wanted: number?, options: SpawnOptions?): Sound?
	local prio = PRIORITY[hook] or 1
	if (perHook[hook] or 0) >= MIX.maxPerHook then
		return nil
	end
	while liveCount >= MIX.maxVoices do
		if not evictFor(prio) then
			return nil
		end
	end
	local want = math.min(wanted or cfg.volume, MIX.peakCap)
	while MIX.sumCap - sumLive() < want * MIN_FRACTION do
		if not evictFor(prio) then
			break
		end
	end
	local volume = math.min(want, MIX.sumCap - sumLive())
	if volume < want * (if prio > 1 then PRIORITY_FRACTION else MIN_FRACTION) then
		return nil
	end
	local opts: SpawnOptions = options or {}
	local looped = opts.looped == true
	local s = Instance.new("Sound")
	s.Name = "UI_" .. hook
	s.SoundId = cfg.id
	s.Volume = if opts.fadeIn then 0 else volume
	s.Looped = looped
	local speed = opts.speed or 1
	if opts.speed then
		s.PlaybackSpeed = speed -- set once, here; nothing ever rewrites it
	end
	local g = ensureGroup()
	s.SoundGroup = g
	s.Parent = g
	local v: Voice = { hook = hook, volume = volume, step = opts.step, prio = prio, born = os.clock(), looped = looped }
	voices[s] = v
	liveCount += 1
	perHook[hook] = (perHook[hook] or 0) + 1
	s.Destroying:Once(function()
		onGone(s)
	end)
	if not looped then
		s.Ended:Once(function()
			release(s)
		end)
	end
	timerCount += 1
	v.timer = task.delay(if looped then LOOP_SAFETY else SHOT_SAFETY, function()
		v.timer = nil
		timerCount -= 1
		release(s)
	end)
	if opts.fadeIn then
		runTween(s, v, TweenInfo.new(opts.fadeIn, Enum.EasingStyle.Linear), volume)
	elseif opts.seconds then
		-- the trim: one tween whose DelayTime holds the note at full level, then fades it to nothing and destroys it
		local tail = math.min(opts.tail or 0.1, opts.seconds)
		local info =
			TweenInfo.new(tail, Enum.EasingStyle.Linear, Enum.EasingDirection.In, 0, false, opts.seconds - tail)
		runTween(s, v, info, 0, function()
			release(s)
		end)
	end
	s:Play()
	playedCount[hook] = (playedCount[hook] or 0) + 1
	table.insert(history, { hook = hook, at = os.clock(), volume = volume, speed = speed })
	if #history > HISTORY_MAX then
		table.remove(history, 1)
	end
	return s
end

-- A short smooth fade, then destroy (stopRise, loop stop). A voice already on its way out keeps going.
local function fadeAndDestroy(s: Sound, seconds: number)
	local v = voices[s]
	if not v or not s.Parent or v.leaving then
		return
	end
	v.leaving = true
	runTween(s, v, TweenInfo.new(seconds, Enum.EasingStyle.Linear), 0, function()
		release(s)
	end)
end

----------------------------------------------------------------------------------------------
-- The chime ladder

local function chimeReset()
	chime.step = 0
	chime.notes = 0
	chime.highest = 0
end

local function playNote(hook: string, cfg: Config, step: number): boolean
	if chime.notes >= MIX.chime.maxNotes then
		return false
	end
	local now = os.clock()
	if now - chime.lastAt < MIX.chime.gap then
		return false
	end
	local semitones = MIX.chime.semitones[step]
	if not semitones then
		return false
	end
	local s = spawn(hook, cfg, nil, {
		speed = 2 ^ (semitones / 12),
		seconds = MIX.chime.seconds,
		tail = MIX.chime.tail,
		step = step,
	})
	if not s then
		return false
	end
	chime.lastAt = now
	chime.step = step
	chime.notes += 1
	if step == #MIX.chime.semitones then
		-- the ring-full note has sounded (as the ladder's last note or as the pending cue): no second one for this capture,
		-- even if stopRise resets the ladder a moment later
		lastPlayed.KeysPending = now
	end
	return true
end

-- The progress cue: call it with the supplied progress as often as you like (even every frame). A note plays only when
-- progress reaches a new quarter, no closer than MIX.chime.gap to the last note, and at most MIX.chime.maxNotes a capture.
-- A skipped note (too soon) is simply tried again by the next call; nothing loops and nothing is retriggered.
function Sounds.rise(hook: Hook, progress01: number)
	counts[hook] = (counts[hook] or 0) + 1
	local cfg = ids[hook]
	if not cfg then
		return
	end
	local p = math.clamp(if progress01 ~= progress01 then 0 else progress01, 0, 1)
	if p + 0.2 < chime.highest then
		chimeReset() -- progress fell back a long way: a new capture started without a stopRise
	end
	chime.highest = math.max(chime.highest, p)
	local count = #MIX.chime.semitones
	local step = math.floor(p * count + 1e-6)
	if step < 1 or step <= chime.step then
		return
	end
	playNote(hook, cfg, step)
end

-- End the ladder (cancel, replace, run end, destroy): ringing notes fade out in STOP_FADE. A ring-full note that has only
-- just sounded (the capture is moving on to its pending state, not being cancelled) is left to ring out, unless `immediate`.
function Sounds.stopRise(hook: Hook, immediate: boolean?)
	local last = #MIX.chime.semitones
	local ringing = chime.step >= last and os.clock() - chime.lastAt < MIX.chime.seconds
	chimeReset()
	for s, v in table.clone(voices) do
		if (v.hook == hook or v.hook == "KeysPending") and not (ringing and v.step == last and not immediate) then
			fadeAndDestroy(s, STOP_FADE)
		end
	end
end

----------------------------------------------------------------------------------------------
-- Playing

function Sounds.play(hook: Hook, volume: number?)
	counts[hook] = (counts[hook] or 0) + 1
	local cfg = ids[hook]
	if not cfg then
		return
	end
	if cfg.ladder then
		return -- the chime notes are played by Sounds.rise only
	end
	local now = os.clock()
	if now - (lastPlayed[hook] or -math.huge) < cfg.minInterval then
		return
	end
	local step = cfg.step
	if step then
		-- the ring-full cue (KeysPending): one quiet note, once per capture. Skipped when the ladder's last note has
		-- already sounded for this capture (chime.step) or sounded within the last 1.5 s (lastPlayed, set by playNote).
		if chime.step < step then
			playNote(hook, cfg, step)
		end
		return
	end
	local s = spawn(hook, cfg, volume, { seconds = cfg.maxSeconds, tail = cfg.tail })
	if not s then
		return -- a cap said no (a priority hook cuts lower-priority effects first, see PRIORITY)
	end
	lastPlayed[hook] = now
	local duckFor = DUCK[hook]
	if duckFor and duckHandler then
		duckHandler(hook, duckFor)
	end
end

-- At most once per key: the guard for a sting that belongs to one event (key = the run-scoped capture identity, for
-- example runId .. ":" .. captureId, so a repeated id in a later run still sounds). The memory is bounded.
function Sounds.playOnce(hook: Hook, key: string, volume: number?): boolean
	local k = hook .. "|" .. key
	if onceSeen[k] then
		return false
	end
	onceSeen[k] = true
	table.insert(onceOrder, k)
	if #onceOrder > ONCE_MEMORY then
		onceSeen[table.remove(onceOrder, 1) :: string] = nil
	end
	Sounds.play(hook, volume)
	return true
end

-- The confirmed-capture sting. Call it ONLY for a confirmed capture (never for a pending or canceled one).
function Sounds.fanfare(key: string): boolean
	return Sounds.playOnce("KeysCapture", key)
end

-- A looping tally (Results count-up); returns a stop function. Always stop it when the count
-- ends or the component is destroyed.
function Sounds.loop(hook: Hook): () -> ()
	counts[hook] = (counts[hook] or 0) + 1
	local cfg = ids[hook]
	if not cfg then
		return function() end
	end
	local s = spawn(hook, cfg, nil, { looped = true, fadeIn = LOOP_FADE_IN })
	if not s then
		return function() end
	end
	return function()
		if s.Parent then
			fadeAndDestroy(s, LOOP_FADE_OUT)
		end
	end
end

function Sounds.stopAll()
	for s in table.clone(voices) do
		release(s)
	end
	chimeReset()
end

function Sounds.resetThrottles()
	table.clear(lastPlayed)
	table.clear(onceSeen)
	table.clear(onceOrder)
	table.clear(history)
	table.clear(playedCount)
	chimeReset()
	chime.lastAt = -math.huge
end

function Sounds.counts(): { [string]: number }
	return table.clone(counts)
end

-- Effects that actually made a Sound (counts() also counts throttled and silent calls).
function Sounds.played(): { [string]: number }
	return table.clone(playedCount)
end

-- The last HISTORY_MAX effects that made a Sound, oldest first: { hook, at (os.clock), volume, speed }.
function Sounds.history(): { Played }
	return table.clone(history)
end

function Sounds.liveVoices(): number
	return liveCount
end

-- The minimum interval of a hook, in seconds (nil when the hook is silent): the throttle the Mix scenarios check against.
function Sounds.minInterval(hook: Hook): number?
	local cfg = ids[hook]
	return if cfg then cfg.minInterval else nil
end

function Sounds.resetCounts()
	table.clear(counts)
end

-- Live numbers for the leak and mix checks. There is no per-frame connection in this module, by construction.
function Sounds.getDebugState(): { [string]: any }
	local perHookNow: { [string]: number } = {}
	for hook, n in perHook do
		if n > 0 then
			perHookNow[hook] = n
		end
	end
	return {
		liveVoices = liveCount,
		liveSum = sumLive(),
		perHook = perHookNow,
		tweens = tweenCount,
		timers = timerCount,
		heartbeatConnections = 0,
		chimeStep = chime.step,
		chimeNotes = chime.notes,
		onceKeys = #onceOrder,
	}
end

applyRoutes()

return Sounds
