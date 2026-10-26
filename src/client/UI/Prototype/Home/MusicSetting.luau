--!strict
-- The Home HUD's Music setting (Lane 3 preview). A REAL local preview setting, never saved:
-- store.settings.musicOn (the Home toggle row) and store.settings.music (the Settings panel's
-- level) decide the volume of the preview music SoundGroup "Lane3PreviewMusic" (Sounds.musicGroup).
--   on  -> group volume = settings.music
--   off -> group volume = 0 (the level is remembered, so turning Music back on restores it)
-- Nothing here writes a DataStore, a profile or an attribute that persists.
--
-- ROUND 3 (R3-A, finding 10): switching Music On or Off is a SHORT SMOOTH FADE of the group (FADE_SECONDS, at most 0.4 s) instead
-- of a cut. A slider drag is NOT faded (it follows the finger at once), and applying the same state again (every slider tick,
-- every panel refresh) never restarts or cuts a fade that is already heading to the same level. The store's setting is the one
-- authority: while Music is Off a level change keeps the group at 0, and nothing in the music controller (ducking, stings)
-- ever writes this group, so nothing can restore sound the player turned off.
--
--   MusicSetting.apply(store)            -- push the store's setting to the SoundGroup
--   MusicSetting.setOn(store, on)        -- the toggle row
--   MusicSetting.setLevel(store, level)  -- the Settings panel slider (0..1)
--   MusicSetting.setSfx(store, level)    -- the Settings panel effects slider (0..1)
--   MusicSetting.isOn(store) -> boolean
--   MusicSetting.reset()                 -- forget the last state and stop a running fade (unmount, tests)
--   MusicSetting.getDebugState() -> table

local TweenService = game:GetService("TweenService")

local Music = require(script.Parent.Parent.Music)
local Sounds = require(script.Parent.Parent.Sounds)
local Store = require(script.Parent.Parent.Store)

local MusicSetting = {}

MusicSetting.FADE_SECONDS = 0.3 -- the Music On / Off fade (R3-A: at most 0.4 s out, 0.3 s in)

local lastOn: boolean? = nil
local fade: Tween? = nil
local fadeDone: RBXScriptConnection? = nil
local fadeTarget = 0

local function stopFade()
	local tween = fade
	if tween then
		fade = nil
		local done = fadeDone
		fadeDone = nil
		if done then
			done:Disconnect()
		end
		tween:Cancel()
	end
end

-- Put the group at `target`: a smooth fade when `smooth`, otherwise at once. A fade already heading to the same target is left alone.
local function setGroup(g: SoundGroup, target: number, smooth: boolean)
	if fade and fadeTarget == target then
		return
	end
	stopFade()
	if not smooth or math.abs(g.Volume - target) < 0.001 then
		g.Volume = target
		return
	end
	local tween = TweenService:Create(
		g,
		TweenInfo.new(MusicSetting.FADE_SECONDS, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
		{ Volume = target }
	)
	fade = tween
	fadeTarget = target
	fadeDone = tween.Completed:Once(function()
		if fade ~= tween then
			return -- a replaced fade (signals can be deferred): the new one owns the bookkeeping
		end
		fade = nil
		fadeDone = nil
	end)
	tween:Play()
end

local function group(): SoundGroup?
	local fn = (Sounds :: any).musicGroup
	if type(fn) ~= "function" then
		return nil
	end
	local ok, g = pcall(fn)
	return if ok then g else nil
end

function MusicSetting.isOn(store: Store.StoreObject): boolean
	return store:get().settings.musicOn ~= false
end

function MusicSetting.apply(store: Store.StoreObject)
	local s = store:get().settings
	local on = s.musicOn ~= false
	local g = group()
	if g then
		local target = if on then math.clamp(s.music, 0, 1) else 0
		setGroup(g, target, lastOn ~= nil and lastOn ~= on) -- only the On / Off switch fades
	end
	lastOn = on
	Music.setMuted(not on) -- Music Off fades the run music out and keeps it off (Round 2)
	local ok, sfx = pcall(Sounds.group)
	if ok and sfx then
		sfx.Volume = math.clamp(s.sfx, 0, 1)
	end
end

local function write(store: Store.StoreObject, patch: { [string]: any })
	local s = table.clone(store:get().settings) :: any
	for k, v in patch do
		s[k] = v
	end
	store:set("settings", s)
	MusicSetting.apply(store)
end

function MusicSetting.setOn(store: Store.StoreObject, on: boolean)
	write(store, { musicOn = on })
end

function MusicSetting.setLevel(store: Store.StoreObject, level: number)
	write(store, { music = math.clamp(level, 0, 1) })
end

function MusicSetting.setSfx(store: Store.StoreObject, level: number)
	write(store, { sfx = math.clamp(level, 0, 1) })
end

function MusicSetting.reset()
	stopFade()
	lastOn = nil
end

function MusicSetting.getDebugState(): { [string]: any }
	return { fading = fade ~= nil, tweens = if fade then 1 else 0, lastOn = lastOn, heartbeatConnections = 0 }
end

return MusicSetting
