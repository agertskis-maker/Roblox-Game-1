--!strict
-- PLAYGROUND ONLY (Lane 3 preview). The Settings sound rows (2026-10-29, ledger vault/design/specs/settings-sound-ledger.md):
-- PASS / FAIL property checks of the two category groups, the slider and mute state, the preview tick and the music loop.
-- These are property checks: no level here was listened to (the review clip and its loudness readings are separate).
-- The slider changes go through the panel's own code (its slider set / pointer functions, the same path a drag takes);
-- real mouse clicks, key presses, respawn and rejoin are driven from outside (the Studio tools) and logged separately.

local Players = game:GetService("Players")

local Prototype = Players.LocalPlayer
	:WaitForChild("PlayerScripts")
	:WaitForChild("Client")
	:WaitForChild("UI")
	:WaitForChild("Prototype")
local AudioMix = require(Prototype:WaitForChild("AudioMix"))
local Music = require(Prototype:WaitForChild("Music"))
local Sounds = require(Prototype:WaitForChild("Sounds"))
local Store = require(Prototype:WaitForChild("Store"))
local MusicSetting = require(Prototype:WaitForChild("Home"):WaitForChild("MusicSetting"))

type Host = { [string]: any }

local function verdict(host: Host, name: string, ok: boolean, detail: string)
	host.log(string.format("%s %s: %s", if ok then "PASS" else "FAIL", name, detail))
end

-- the volume a Sound is heard at: its own Volume times every SoundGroup up its chain (nested groups multiply)
local function heard(s: Sound): (number, string)
	local factor = s.Volume
	local names = {}
	local node: Instance? = s.SoundGroup
	while node and node:IsA("SoundGroup") do
		factor *= node.Volume
		table.insert(names, node.Name)
		node = node.Parent
	end
	return factor, table.concat(names, " < ")
end

local function near(a: number, b: number): boolean
	return math.abs(a - b) < 0.005
end

local function panelOf(host: Host): any
	return host.api.components and host.api.components.settings
end

local S = {}

S["Settings sound: groups and levels"] = function(host: Host)
	local store = host.store
	local original = table.clone(store:get().settings)
	-- 1. defaults: a new store starts at 100 / 100, both unmuted
	local d = Store.new():get().settings :: any
	verdict(
		host,
		"defaults are MUSIC 100 and SOUND EFFECTS 100, unmuted",
		d.music == 1 and d.sfx == 1 and d.musicOn ~= false and d.sfxOn ~= false,
		string.format(
			"music %s sfx %s musicOn %s sfxOn %s",
			tostring(d.music),
			tostring(d.sfx),
			tostring(d.musicOn),
			tostring(d.sfxOn)
		)
	)
	-- 2. the tree: the mix groups are nested under the player's categories, and are not duplicated
	local mix = Sounds.musicGroup()
	local ui = Sounds.group()
	local soundService = game:GetService("SoundService")
	local function count(name: string): number
		local n = 0
		for _, g in soundService:GetDescendants() do
			if g:IsA("SoundGroup") and g.Name == name then
				n += 1
			end
		end
		return n
	end
	verdict(
		host,
		"mix groups nested under Music and Effects, one of each, approved mix levels kept",
		mix.Parent == AudioMix.group("Music")
			and ui.Parent == AudioMix.group("Effects")
			and count("Music") == 1
			and count("Effects") == 1
			and count("Lane3PreviewMusic") == 1
			and count("Lane3PreviewUI") == 1
			and near(mix.Volume, Sounds.MIX.musicGroup)
			and near(ui.Volume, Sounds.MIX.sfxGroup),
		game:GetService("HttpService"):JSONEncode(AudioMix.getDebugState())
	)

	host.api.open("settings")
	host.wait(0.6)
	local panel = panelOf(host)
	if not panel then
		verdict(host, "settings panel mounted", false, "no components.settings")
		return
	end
	local music = panel._sliders.music
	local sfx = panel._sliders.sfx

	-- 3. 50 through the slider: group, percentage, fill, a new effect heard at half
	music.set(0.5, true, music.value)
	sfx.set(0.5, true, sfx.value)
	host.wait(0.2)
	local ds = panel:getDebugState()
	verdict(
		host,
		"50: both groups at 0.50, the rows read 50%, fills shown",
		near(AudioMix.group("Music").Volume, 0.5)
			and near(AudioMix.group("Effects").Volume, 0.5)
			and ds.musicText == "50%"
			and ds.sfxText == "50%"
			and ds.musicFill
			and ds.sfxFill,
		string.format("music %.2f effects %.2f texts %s / %s", ds.music, ds.sfx, ds.musicText, ds.sfxText)
	)
	Sounds.resetThrottles()
	Sounds.play("Toast")
	host.wait(0.05)
	local toast: Sound? = nil
	for _, child in ui:GetChildren() do
		if child:IsA("Sound") and child.Name == "UI_Toast" then
			toast = child
		end
	end
	if toast then
		local level, chain = heard(toast)
		verdict(
			host,
			"newly spawned effect joins Effects: heard = its Volume x 0.6 mix x 0.5 player",
			near(level, toast.Volume * Sounds.MIX.sfxGroup * 0.5),
			string.format("heard %.4f via %s", level, chain)
		)
	else
		verdict(host, "newly spawned effect joins Effects", false, "no UI_Toast Sound was made")
	end

	-- 4. 0 through the slider: muted, slash and MUTED, no fill; the drag's start level is kept for unmute
	music.set(0, true, 0.5)
	host.wait(0.2)
	ds = panel:getDebugState()
	verdict(
		host,
		"MUSIC slider to 0: muted (slash, MUTED, no fill), group at 0, level 0.50 kept",
		ds.music == 0
			and ds.musicText == "MUTED"
			and ds.musicSlash
			and not ds.musicFill
			and not ds.musicOn
			and near(ds.musicSetting, 0.5),
		string.format(
			"group %.2f text %s slash %s fill %s kept %.2f",
			ds.music,
			ds.musicText,
			tostring(ds.musicSlash),
			tostring(ds.musicFill),
			ds.musicSetting
		)
	)
	MusicSetting.toggle(store, "Music") -- the MUSIC mute button's handler
	host.wait(0.5)
	ds = panel:getDebugState()
	verdict(
		host,
		"MUSIC unmute: back to the kept 50%",
		near(ds.music, 0.5) and ds.musicText == "50%" and not ds.musicSlash and ds.musicOn,
		string.format("group %.2f text %s", ds.music, ds.musicText)
	)
	-- mute then unmute keeps the level; the Home switch is the same state
	MusicSetting.toggle(store, "Effects")
	host.wait(0.2)
	ds = panel:getDebugState()
	local mutedOk = ds.sfx == 0 and ds.sfxText == "MUTED" and ds.sfxSlash and near(ds.sfxSetting, 0.5)
	MusicSetting.toggle(store, "Effects")
	host.wait(0.2)
	ds = panel:getDebugState()
	verdict(
		host,
		"SOUND EFFECTS mute then unmute: 0 and MUTED, then the kept 50%",
		mutedOk and near(ds.sfx, 0.5) and ds.sfxText == "50%",
		string.format("after %.2f %s", ds.sfx, ds.sfxText)
	)
	MusicSetting.setOn(store, false) -- the Home Music switch
	host.wait(0.5)
	ds = panel:getDebugState()
	local homeOff = ds.musicText == "MUTED" and ds.music == 0 and not MusicSetting.isOn(store)
	MusicSetting.setOn(store, true)
	host.wait(0.5)
	ds = panel:getDebugState()
	verdict(
		host,
		"Home Music switch Off / On is the MUSIC mute (the two controls show one state)",
		homeOff and ds.musicText == "50%" and MusicSetting.isOn(store),
		string.format("off read MUTED: %s; on: %s", tostring(homeOff), ds.musicText)
	)
	-- unmute with nothing positive kept: 100
	store:set(
		"settings",
		(function()
			local s = table.clone(store:get().settings) :: any
			s.sfx = 0
			s.sfxOn = false
			return s
		end)()
	)
	MusicSetting.setSfxOn(store, true)
	host.wait(0.2)
	verdict(
		host,
		"unmute with no positive level kept goes to 100",
		near(AudioMix.group("Effects").Volume, 1),
		string.format("%.2f", AudioMix.group("Effects").Volume)
	)

	-- 5. close and reopen keeps the values
	music.set(0.37, true, music.value)
	sfx.set(0.64, true, sfx.value)
	host.wait(0.2)
	host.api.close("settings")
	host.wait(0.8)
	host.api.open("settings")
	host.wait(0.6)
	ds = panel:getDebugState()
	verdict(
		host,
		"close and reopen: 37% and 64% kept, groups unchanged",
		ds.musicText == "37%" and ds.sfxText == "64%" and near(ds.music, 0.37) and near(ds.sfx, 0.64),
		string.format("%s / %s, groups %.2f / %.2f", ds.musicText, ds.sfxText, ds.music, ds.sfx)
	)
	host.api.close("settings")
	host.wait(0.5)
	MusicSetting.setLevel(store, original.music)
	MusicSetting.setSfx(store, original.sfx)
	MusicSetting.setOn(store, original.musicOn ~= false)
	MusicSetting.setSfxOn(store, (original :: any).sfxOn ~= false)
	host.log("(property checks only: no level was listened to)")
end

S["Settings sound: music keeps time"] = function(host: Host)
	local store = host.store
	local original = table.clone(store:get().settings)
	host.enterRun()
	Music.enable(true)
	Music.setWorld("Downtown")
	host.wait(2.5)
	local loop = Music.baseSound()
	local created = Music.state().created
	local t0 = if loop then loop.TimePosition else -1
	local times = { t0 }
	-- slider moves, a mute, an unmute, more moves: the loop must be the same Sound and keep advancing
	for i = 1, 20 do
		MusicSetting.setLevel(store, 0.3 + 0.03 * i, store:get().settings.music)
		host.wait(0.05)
	end
	table.insert(times, if loop then loop.TimePosition else -1)
	MusicSetting.setOn(store, false)
	host.wait(0.8)
	table.insert(times, if loop then loop.TimePosition else -1)
	MusicSetting.setOn(store, true)
	host.wait(0.8)
	table.insert(times, if loop then loop.TimePosition else -1)
	MusicSetting.setLevel(store, 0, 0.8)
	host.wait(0.5)
	MusicSetting.setLevel(store, 0.7)
	host.wait(0.5)
	table.insert(times, if loop then loop.TimePosition else -1)
	local advancing = true
	for i = 2, #times do
		-- a looped track may wrap; a wrap still counts as advancing only if it passed the end
		if times[i] <= times[i - 1] and not (loop and times[i - 1] > loop.TimeLength - 2) then
			advancing = false
		end
	end
	local s = Music.state()
	verdict(
		host,
		"music keeps time across 20 slider moves, mute, unmute and a slider to 0 and back: one Sound, never restarted",
		loop ~= nil
			and Music.baseSound() == loop
			and s.created == created
			and s.liveMusicSounds == 1
			and advancing
			and t0 > 0,
		string.format(
			"TimePosition %s; created %d -> %d",
			table.concat(
				(function()
					local out = {}
					for _, t in times do
						table.insert(out, string.format("%.2f", t))
					end
					return out
				end)(),
				" -> "
			),
			created,
			s.created
		)
	)
	-- World switch: the new World's loop is in the Music category at the player's level
	Music.setWorld("DustyHighway")
	host.wait(1.2)
	local dusty = Music.baseSound()
	if dusty then
		local level, chain = heard(dusty)
		verdict(
			host,
			"World switch: the new World loop is routed through Music at the player's level (0.70)",
			string.find(chain, "Music$") ~= nil and near(AudioMix.group("Music").Volume, 0.7) and level > 0,
			string.format("heard %.4f via %s", level, chain)
		)
	else
		verdict(host, "World switch: a loop exists", false, "no base Sound")
	end
	Music.enable(false)
	host.wait(0.6)
	MusicSetting.setLevel(store, original.music)
	MusicSetting.setOn(store, original.musicOn ~= false)
end

S["Settings sound: preview tick"] = function(host: Host)
	local store = host.store
	local original = table.clone(store:get().settings)
	host.api.open("settings")
	host.wait(0.6)
	local panel = panelOf(host)
	if not panel then
		verdict(host, "settings panel mounted", false, "no components.settings")
		return
	end
	local sfx = panel._sliders.sfx
	local track: Frame = sfx.track
	local left, width = track.AbsolutePosition.X, track.AbsoluteSize.X
	Sounds.resetThrottles()
	local before = panel._ticks
	-- a 1.2 s drag, a pointer move every 16 ms, through the panel's own pointer function (the drag code path)
	sfx.dragStart = sfx.value
	panel._dragSlider = sfx
	local maxLive = 0
	local t0 = os.clock()
	while os.clock() - t0 < 1.2 do
		local k = (os.clock() - t0) / 1.2
		panel:_setFromX(sfx, left + width * (0.2 + 0.6 * k))
		local live = 0
		for _, child in Sounds.group():GetChildren() do
			if child:IsA("Sound") and child.Name == "UI_VolumeTick" then
				live += 1
			end
		end
		maxLive = math.max(maxLive, live)
		host.wait(0.016)
	end
	panel:_endDrag()
	host.wait(0.4)
	local hist = {}
	for _, e in Sounds.history() do
		if e.hook == "VolumeTick" then
			table.insert(hist, e.at)
		end
	end
	local minGap = math.huge
	for i = 2, #hist do
		minGap = math.min(minGap, hist[i] - hist[i - 1])
	end
	verdict(
		host,
		"drag ticks: at most one per 150 ms, never two at once, about 8 in 1.2 s plus the release",
		#hist >= 5 and #hist <= 10 and minGap >= 0.149 and maxLive <= 1,
		string.format(
			"%d ticks, min gap %.3f s, most live at once %d, panel ticks %d",
			#hist,
			if #hist > 1 then minGap else 0,
			maxLive,
			panel._ticks - before
		)
	)
	-- silent at 0: dragging to 0 plays nothing
	Sounds.resetThrottles()
	host.wait(0.2)
	panel._dragSlider = sfx
	sfx.dragStart = sfx.value
	panel:_setFromX(sfx, left - 200) -- outside the card: clamps to 0
	host.wait(0.2)
	panel:_endDrag()
	host.wait(0.3)
	local zeroTicks = 0
	for _, e in Sounds.history() do
		if e.hook == "VolumeTick" then
			zeroTicks += 1
		end
	end
	local ds = panel:getDebugState()
	verdict(
		host,
		"a pointer left of the card clamps to 0: muted, and no tick at 0",
		zeroTicks == 0 and ds.sfx == 0 and ds.sfxText == "MUTED",
		string.format("ticks %d, effects %.2f, %s", zeroTicks, ds.sfx, ds.sfxText)
	)
	panel._dragSlider = sfx
	panel:_setFromX(sfx, left + width + 300) -- right of the card: clamps to 100
	panel:_endDrag()
	host.wait(0.3)
	ds = panel:getDebugState()
	verdict(host, "a pointer right of the card clamps to 100", ds.sfxText == "100%", ds.sfxText)
	-- the tick's real length: trimmed to 70 ms whatever the sample is
	local tickSound: Sound? = nil
	Sounds.resetThrottles()
	Sounds.play("VolumeTick")
	for _, child in Sounds.group():GetChildren() do
		if child:IsA("Sound") and child.Name == "UI_VolumeTick" then
			tickSound = child
		end
	end
	local born = os.clock()
	while tickSound and tickSound.Parent and os.clock() - born < 1 do
		host.wait(0.005)
	end
	verdict(
		host,
		"the tick lasts about 70 ms (trimmed), through Effects",
		tickSound ~= nil and os.clock() - born < 0.14,
		string.format(
			"sample length %.3f s, gone after %.3f s",
			if tickSound then tickSound.TimeLength else -1,
			os.clock() - born
		)
	)
	host.api.close("settings")
	host.wait(0.4)
	MusicSetting.setSfx(store, original.sfx)
	MusicSetting.setSfxOn(store, (original :: any).sfxOn ~= false)
end

-- Review captures: holds each state for HOLD seconds on every landscape frame and logs "HOLD <profile> <state>" when it is
-- on screen, so the driver can take a still. States: MUSIC 50 / SOUND EFFECTS 100; MUSIC muted by its button / SOUND
-- EFFECTS 35; both at 0 by the slider.
S["Settings sound: review states"] = function(host: Host)
	local store = host.store
	local original = table.clone(store:get().settings)
	local hold = tonumber(host.api.reviewHold) or 4
	local profiles =
		{ "Desktop", "Tablet", "PhoneLandscape", "PhoneSmall", "PhoneLandscapeLeft", "PhoneLandscapeRight" }
	for _, profile in profiles do
		host.api.setProfile(profile)
		host.wait(0.4)
		host.api.open("settings")
		host.wait(0.6)
		MusicSetting.setLevel(store, 0.5)
		MusicSetting.setSfx(store, 1)
		MusicSetting.setSfxOn(store, true)
		host.wait(0.4)
		host.log("HOLD " .. profile .. " music50")
		host.wait(hold)
		MusicSetting.toggle(store, "Music")
		MusicSetting.setSfx(store, 0.35)
		host.wait(0.6)
		host.log("HOLD " .. profile .. " musicMuted")
		host.wait(hold)
		MusicSetting.setLevel(store, 0, 0.5)
		MusicSetting.setSfx(store, 0, 0.35)
		host.wait(0.4)
		host.log("HOLD " .. profile .. " bothZero")
		host.wait(hold)
		host.api.close("settings")
		host.wait(0.5)
	end
	host.log("HOLD done")
	MusicSetting.setLevel(store, original.music)
	MusicSetting.setSfx(store, original.sfx)
	MusicSetting.setOn(store, original.musicOn ~= false)
	MusicSetting.setSfxOn(store, (original :: any).sfxOn ~= false)
end

-- The review clip (real time, with the game audio): run music on, the card open over the run, and timed phases logged as
-- "CLIP <phase> <unix ms>" so the recording can be cut and measured per phase. Slider moves go through the panel's own
-- pointer function (a drag), so the SOUND EFFECTS ticks are the real ones.
S["Settings sound: review clip"] = function(host: Host)
	local store = host.store
	local original = table.clone(store:get().settings)
	local function mark(phase: string)
		host.log(string.format("CLIP %s %d", phase, DateTime.now().UnixTimestampMillis))
	end
	host.enterRun()
	MusicSetting.setLevel(store, 1)
	MusicSetting.setSfx(store, 1)
	MusicSetting.setOn(store, true)
	MusicSetting.setSfxOn(store, true)
	Music.enable(true)
	Music.setWorld("Downtown")
	host.wait(2.5)
	host.api.open("settings")
	host.wait(0.8)
	local panel = panelOf(host)
	if not panel then
		host.log("FAIL review clip: no panel")
		return
	end
	local function sweep(slider: any, from: number, to: number, seconds: number)
		local track: Frame = slider.track
		local left, width = track.AbsolutePosition.X, track.AbsoluteSize.X
		panel._dragSlider = slider
		slider.dragStart = slider.value
		local t0 = os.clock()
		while os.clock() - t0 < seconds do
			local k = (os.clock() - t0) / seconds
			panel:_setFromX(slider, left + width * (from + (to - from) * k))
			host.wait(0.016)
		end
		panel:_setFromX(slider, left + width * to)
		panel:_endDrag()
	end
	local function toast()
		Sounds.resetThrottles()
		Sounds.play("Toast")
	end
	mark("music100")
	host.wait(3)
	toast()
	host.wait(2)
	mark("sweepMusic")
	sweep(panel._sliders.music, 1, 0.5, 1)
	mark("music50")
	host.wait(3)
	toast()
	host.wait(2)
	mark("musicMute")
	MusicSetting.toggle(store, "Music")
	host.wait(4)
	mark("musicUnmute")
	MusicSetting.toggle(store, "Music")
	host.wait(4)
	mark("sweepSfx")
	sweep(panel._sliders.sfx, 1, 0.3, 2)
	host.wait(1.5)
	mark("sfx30toast")
	toast()
	host.wait(2)
	mark("sfx0")
	sweep(panel._sliders.sfx, 0.3, -0.5, 0.4)
	host.wait(1)
	toast()
	host.wait(2)
	mark("end")
	host.api.close("settings")
	host.wait(0.5)
	Music.enable(false)
	MusicSetting.setLevel(store, original.music)
	MusicSetting.setSfx(store, original.sfx)
	MusicSetting.setOn(store, original.musicOn ~= false)
	MusicSetting.setSfxOn(store, (original :: any).sfxOn ~= false)
end

return S
