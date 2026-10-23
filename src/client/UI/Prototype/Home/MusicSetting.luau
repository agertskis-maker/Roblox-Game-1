--!strict
-- The Home HUD's Music setting (Lane 3 preview). A REAL local preview setting, never saved:
-- store.settings.musicOn (the Home toggle row) and store.settings.music (the Settings panel's
-- level) decide the volume of the preview music SoundGroup "Lane3PreviewMusic" (Sounds.musicGroup).
--   on  -> group volume = settings.music
--   off -> group volume = 0 (the level is remembered, so turning Music back on restores it)
-- Nothing here writes a DataStore, a profile or an attribute that persists.
--
--   MusicSetting.apply(store)            -- push the store's setting to the SoundGroup
--   MusicSetting.setOn(store, on)        -- the toggle row
--   MusicSetting.setLevel(store, level)  -- the Settings panel slider (0..1)
--   MusicSetting.setSfx(store, level)    -- the Settings panel effects slider (0..1)
--   MusicSetting.isOn(store) -> boolean

local Music = require(script.Parent.Parent.Music)
local Sounds = require(script.Parent.Parent.Sounds)
local Store = require(script.Parent.Parent.Store)

local MusicSetting = {}

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
	local g = group()
	if g then
		g.Volume = if s.musicOn ~= false then math.clamp(s.music, 0, 1) else 0
	end
	Music.setMuted(s.musicOn == false) -- Music Off stops the run music and keeps it off (Round 2)
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

return MusicSetting
