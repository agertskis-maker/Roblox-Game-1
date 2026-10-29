--!strict
-- The Home HUD's sound settings (Lane 3 preview). REAL local preview settings, kept for this client session and never saved:
-- no DataStore, profile or persistent attribute is written (spec vault/design/ui/settings-sound.md section 4).
--
-- SETTINGS SOUND ROWS (2026-10-29, Design 7): two player categories, MUSIC and SOUND EFFECTS, each a level 0..1 (shown 0 to
-- 100, default 1) and a mute flag, applied to the category SoundGroups in AudioMix ("Music", "Effects"). The approved mix
-- levels live in the nested mix groups (Sounds.musicGroup 0.5, Sounds.group 0.6) and nothing here writes them.
--   store.settings.music / sfx      the level; while muted it holds the last non-zero level of this session
--   store.settings.musicOn / sfxOn  false = muted (nil counts as on)
--   effective = on and level or 0  -> AudioMix.setLevel(category, effective)
-- Music On / Off is FOLDED into the MUSIC mute: the Home switch and the Settings mute button write the same `musicOn`, so they
-- can never disagree. Mute only silences the group: the music loop keeps playing and keeping time underneath, so muting,
-- unmuting and every slider move never seek, restart, duplicate or reload it (Music.setMuted is no longer called here).
-- Fades: a level change ramps the group in AudioMix.RAMP (0.05 s); the MUSIC mute / unmute keeps the approved Round 3 fade
-- (FADE_SECONDS). Applying the same state again never restarts a ramp that is already heading there.
--
--   MusicSetting.apply(store)                      -- push the store's settings to the category groups
--   MusicSetting.setOn(store, on)                  -- MUSIC mute (the Home switch, the Settings mute button)
--   MusicSetting.setLevel(store, level, kept?)     -- the MUSIC slider (0..1); above 0 unmutes, 0 mutes keeping `kept`
--   MusicSetting.setSfx(store, level, kept?)       -- the SOUND EFFECTS slider, the same rules
--   MusicSetting.setSfxOn(store, on)               -- SOUND EFFECTS mute
--   MusicSetting.toggle(store, category)           -- a mute button: mute, or unmute to the kept level (100 when none)
--   MusicSetting.isOn(store) / sfxIsOn(store) -> boolean
--   MusicSetting.effective(store, category) -> number   -- 0..1 as heard (0 while muted)
--   MusicSetting.reset()                           -- forget the last state and stop ramps (unmount, tests)
--   MusicSetting.getDebugState() -> table

local AudioMix = require(script.Parent.Parent.AudioMix)
local Store = require(script.Parent.Parent.Store)

local MusicSetting = {}

MusicSetting.FADE_SECONDS = 0.3 -- the MUSIC mute / unmute fade (R3-A: at most 0.4 s out, 0.3 s in)

export type Category = "Music" | "Effects"

local KEYS: { [string]: { level: string, on: string } } = {
	Music = { level = "music", on = "musicOn" },
	Effects = { level = "sfx", on = "sfxOn" },
}

local lastOn: { [string]: boolean } = {}
local fadeNext: { [string]: number } = {} -- the fade of the change being written (MUSIC mute switch only)

local function snap(level: number): number
	return math.floor(math.clamp(if level ~= level then 0 else level, 0, 1) * 100 + 0.5) / 100
end

local function read(store: Store.StoreObject, category: Category): (number, boolean)
	local s = store:get().settings :: any
	local k = KEYS[category]
	local level = tonumber(s[k.level]) or 1
	return math.clamp(level, 0, 1), s[k.on] ~= false
end

function MusicSetting.effective(store: Store.StoreObject, category: Category): number
	local level, on = read(store, category)
	return if on then level else 0
end

function MusicSetting.isOn(store: Store.StoreObject): boolean
	local level, on = read(store, "Music")
	return on and level > 0
end

function MusicSetting.sfxIsOn(store: Store.StoreObject): boolean
	local level, on = read(store, "Effects")
	return on and level > 0
end

-- Every apply (this module's writes, and the Home menu's store subscriber, which runs inside the same write) uses the fade
-- the change asked for: the MUSIC mute switch sets fadeNext for the length of its write, everything else is the short ramp.
-- So two applies of one change agree, and the second never restarts or shortens the first one's ramp.
function MusicSetting.apply(store: Store.StoreObject)
	for _, category: Category in { "Music" :: Category, "Effects" :: Category } do
		local level, on = read(store, category)
		AudioMix.setLevel(category, if on then level else 0, fadeNext[category] or AudioMix.RAMP)
		lastOn[category] = on
	end
end

local function write(store: Store.StoreObject, patch: { [string]: any }, fade: { [string]: number }?)
	local s = table.clone(store:get().settings) :: any
	for k, v in patch do
		s[k] = v
	end
	if fade then
		for k, v in fade do
			fadeNext[k] = v
		end
	end
	store:set("settings", s)
	MusicSetting.apply(store)
	table.clear(fadeNext)
end

-- A slider value. Above 0 it is the level and unmutes; 0 mutes and keeps `kept` (the level the drag started from) or the
-- level already kept, so unmute brings back the previous positive value.
local function setCategoryLevel(store: Store.StoreObject, category: Category, level: number, kept: number?)
	local k = KEYS[category]
	local v = snap(level)
	if v > 0 then
		write(store, { [k.level] = v, [k.on] = true })
		return
	end
	local current = read(store, category)
	local keep = if kept and kept > 0 then snap(kept) elseif current > 0 then current else 1
	write(store, { [k.level] = keep, [k.on] = false })
end

function MusicSetting.setLevel(store: Store.StoreObject, level: number, kept: number?)
	setCategoryLevel(store, "Music", level, kept)
end

function MusicSetting.setSfx(store: Store.StoreObject, level: number, kept: number?)
	setCategoryLevel(store, "Effects", level, kept)
end

local function setCategoryOn(store: Store.StoreObject, category: Category, on: boolean)
	local k = KEYS[category]
	local level = read(store, category)
	if on and level <= 0 then
		level = 1 -- nothing positive was ever kept: unmute to 100
	end
	-- only the MUSIC mute switch gets the approved Round 3 fade; a slider reaching 0 follows the finger (short ramp)
	write(
		store,
		{ [k.level] = level, [k.on] = on },
		if category == "Music" then { Music = MusicSetting.FADE_SECONDS } else nil
	)
end

function MusicSetting.setOn(store: Store.StoreObject, on: boolean)
	setCategoryOn(store, "Music", on)
end

function MusicSetting.setSfxOn(store: Store.StoreObject, on: boolean)
	setCategoryOn(store, "Effects", on)
end

function MusicSetting.toggle(store: Store.StoreObject, category: Category)
	setCategoryOn(store, category, MusicSetting.effective(store, category) <= 0)
end

function MusicSetting.reset()
	AudioMix.reset()
	table.clear(lastOn)
end

function MusicSetting.getDebugState(): { [string]: any }
	local mix = AudioMix.getDebugState()
	return {
		fading = mix.Music.ramping or mix.Effects.ramping,
		tweens = (if mix.Music.ramping then 1 else 0) + (if mix.Effects.ramping then 1 else 0),
		lastOn = lastOn.Music,
		lastSfxOn = lastOn.Effects,
		music = mix.Music.volume,
		effects = mix.Effects.volume,
		heartbeatConnections = 0,
	}
end

return MusicSetting
