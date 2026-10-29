--!strict
-- PLAYGROUND ONLY (Lane 3 Round 2 R2-A, extended in Round 3 R3-A): run music scenarios. They check PROPERTIES and counts of
-- the music controller (voices, levels, fades, tweens, the one duck source); nothing here can say how any track SOUNDS (all
-- eight candidates are metadata-screened, never listened to). Music is OFF by default; each scenario enables it for itself
-- and resets after. Times are wall-clock: a throttled or unfocused Studio window can stretch them, so a timing FAIL there is
-- a reason to re-run focused, not proof of a bug.
--
--   Music: default off and mute         nothing plays by default, Music Off keeps it off, unmuting resumes
--   Music: world crossfade              one loop at a time, a changed World crossfades, no duplicate, no leak
--   Music: tension layer                follows the supplied progress, holds while SECURING, resolves only on confirmation
--   Music: single duck source           one duck, floor 0.6, attack and release, no stacking, no pumping on Results ticks
--   Music: load check                   the base loop's SoundId loaded and its TimeLength read (property check only)
-- Round 3:
--   Music: fades and mute during a fade first start from 0, fade-in <= 0.3 s, fade-out <= 0.4 s, mute / unmute during a fade
--   Music: world churn and unmount      30 rapid World changes, then a reset in the middle of a fade: nothing left behind
--   Music: slider drag and idle         50 slider ticks restart nothing; a steady loop writes no property and runs no tween
--   Music: duck restores the user level the duck restores what the player set (even if changed DURING it); Off stays Off
--   Music: ticks never duck             repeated ticks, chime notes and cues cause no duck; only the stings duck
--
-- Round 3 edits to the Round 2 assertions (the behaviour they encoded changed on purpose; the assertions themselves stay):
--   world crossfade: the two-voice check reads at 0.2 s (the old loop now fades out in 0.4 s, it was 1.2 s)
--   tension layer: the mid-way check reads at 0.2 s and "gone" at 0.7 s (resolve takes 0.4 s now, it took 0.8 s)
--   single duck source: the release check waits 1.5 s (a timing margin; the release is still about 0.4 s)

local Players = game:GetService("Players")

local Prototype = Players.LocalPlayer
	:WaitForChild("PlayerScripts")
	:WaitForChild("Client")
	:WaitForChild("UI")
	:WaitForChild("Prototype")
local AudioMix = require(Prototype:WaitForChild("AudioMix"))
local Music = require(Prototype:WaitForChild("Music"))
local Sounds = require(Prototype:WaitForChild("Sounds"))
local MusicSetting = require(Prototype:WaitForChild("Home"):WaitForChild("MusicSetting"))

type Host = { [string]: any }

local function verdict(host: Host, name: string, ok: boolean, detail: string)
	host.log(string.format("%s %s: %s", if ok then "PASS" else "FAIL", name, detail))
end

local function st(): { [string]: any }
	return Music.state()
end

local function fmt(s: { [string]: any }): string
	return string.format(
		"enabled=%s muted=%s world=%s sounds=%d base=%.2f tension=%.2f(%s) duck=%.2f(%d) dying=%d tweens=%d parent=%.2f",
		tostring(s.enabled),
		tostring(s.muted),
		tostring(s.world),
		s.liveMusicSounds,
		s.baseLevel,
		s.tensionLevel,
		tostring(s.tensionOn),
		s.duckLevel,
		s.duckSources,
		s.dying,
		s.tweens,
		s.parentVolume
	)
end

-- poll until `done()` or `limit` seconds; returns the seconds it took
local function timeUntil(host: Host, limit: number, done: () -> boolean): number
	local t0 = os.clock()
	while not done() and os.clock() - t0 < limit do
		host.wait(0.02)
	end
	return os.clock() - t0
end

local function clean()
	Music.reset()
	Sounds.stopAll()
	Sounds.resetThrottles()
	MusicSetting.reset()
end

local S: { [string]: (Host) -> () } = {}

S["Music: default off and mute"] = function(host: Host)
	Music.reset()
	host.enterRun()
	host.wait(0.4)
	Music.setWorld("Downtown")
	host.wait(0.5)
	local s = st()
	verdict(host, "off by default", not s.enabled and s.liveMusicSounds == 0, fmt(s))
	Music.enable(true)
	Music.setWorld("Downtown")
	host.wait(0.4)
	s = st()
	verdict(host, "enabled plays one loop", s.liveMusicSounds == 1 and s.world == "Downtown", fmt(s))
	Music.setMuted(true)
	host.wait(0.6)
	s = st()
	verdict(host, "muted: silent and stays silent", s.liveMusicSounds == 0 and s.muted, fmt(s))
	Music.setWorld("SummitPass")
	host.wait(0.4)
	s = st()
	verdict(host, "muted: a World change plays nothing", s.liveMusicSounds == 0 and s.world == "SummitPass", fmt(s))
	Music.setMuted(false)
	host.wait(0.4)
	s = st()
	verdict(host, "unmuted resumes the remembered World", s.liveMusicSounds == 1 and s.world == "SummitPass", fmt(s))
	-- review finding: every Settings slider tick calls setMuted(false); that must not restart the loop
	local createdBefore = s.created
	for _ = 1, 5 do
		Music.setMuted(false)
	end
	host.wait(0.3)
	s = st()
	verdict(
		host,
		"repeated setMuted(false) restarts nothing (a slider tick)",
		s.created == createdBefore and s.liveMusicSounds == 1,
		string.format("created %d -> %d, %s", createdBefore, s.created, fmt(s))
	)
	-- switching Music off in the audition panel and on again resumes the same World
	Music.enable(false)
	host.wait(0.6)
	local offState = st()
	Music.enable(true)
	host.wait(0.4)
	s = st()
	verdict(
		host,
		"enable off then on resumes the same World",
		offState.liveMusicSounds == 0 and s.liveMusicSounds == 1 and s.world == "SummitPass",
		fmt(s)
	)
	Music.reset()
	host.wait(0.2)
	verdict(host, "reset leaves nothing behind", st().liveMusicSounds == 0, fmt(st()))
end

S["Music: world crossfade"] = function(host: Host)
	Music.reset()
	Music.enable(true)
	host.enterRun()
	Music.setWorld("Downtown")
	host.wait(0.3)
	local s = st()
	verdict(host, "one loop", s.liveMusicSounds == 1, fmt(s))
	Music.setWorld("Downtown")
	host.wait(0.2)
	verdict(host, "same World again: no duplicate", st().liveMusicSounds == 1 and st().created == s.created, fmt(st()))
	Music.setWorld("DustyHighway")
	host.wait(0.2)
	s = st()
	verdict(host, "World change: old fading, new rising (two voices)", s.liveMusicSounds == 2 and s.dying == 1, fmt(s))
	host.wait(1.6)
	s = st()
	verdict(
		host,
		"after the fade: one voice, full level",
		s.liveMusicSounds == 1 and s.baseLevel > 0.99 and s.dying == 0,
		fmt(s)
	)
	-- rapid World changes: never more than a handful of voices, and it settles to one
	local peak = 0
	for i = 1, 10 do
		Music.setWorld(if i % 2 == 0 then "Downtown" else "SummitPass")
		host.wait(0.06)
		peak = math.max(peak, st().liveMusicSounds)
	end
	host.wait(2.0)
	s = st()
	verdict(
		host,
		"rapid World changes: peak voices " .. peak .. " (at most 3), settles to one",
		s.liveMusicSounds == 1 and s.dying == 0 and peak <= 3,
		fmt(s)
	)
	verdict(
		host,
		"no leak (created minus destroyed equals live)",
		s.created - s.destroyed == s.liveMusicSounds,
		string.format("created %d destroyed %d live %d", s.created, s.destroyed, s.liveMusicSounds)
	)
	-- A/B: switching a candidate crossfades to the other track
	local before = st().baseId
	Music.useCandidate(st().world, 2) -- the World that is playing now
	host.wait(1.6)
	verdict(
		host,
		"A/B: candidate B is a different track",
		st().baseId ~= before and st().candidate == 2,
		tostring(before) .. " -> " .. tostring(st().baseId)
	)
	Music.reset()
end

S["Music: tension layer"] = function(host: Host)
	Music.reset()
	Music.enable(true)
	host.enterRun()
	Music.setWorld("Downtown")
	host.wait(1.5)
	Music.tension(0.3, "Holding")
	host.wait(0.2)
	verdict(host, "below 50%: no layer", not st().tensionOn, fmt(st()))
	Music.tension(0.6, "Holding")
	host.wait(1.0)
	local s = st()
	verdict(
		host,
		"60%: the layer is rising (target about 0.35)",
		s.tensionOn and s.tensionLevel > 0.1 and s.tensionTarget < 0.4,
		fmt(s)
	)
	local baseBefore = s.baseVolume
	Music.tension(0.85, "Holding")
	host.wait(1.8)
	s = st()
	verdict(
		host,
		"ALMOST: holds at the modest peak (0.8), never above",
		s.tensionLevel <= 0.8 + 1e-3 and s.tensionLevel > 0.7,
		fmt(s)
	)
	verdict(
		host,
		"the base bed sinks under the layer",
		s.baseVolume < baseBefore,
		string.format("base volume %.3f -> %.3f", baseBefore, s.baseVolume)
	)
	Music.tension(1, "Securing")
	host.wait(1.0)
	s = st()
	verdict(host, "SECURING: holds, does not resolve", s.tensionOn and s.tensionLevel > 0.7, fmt(s))
	Music.resolve()
	host.wait(0.2)
	s = st()
	verdict(host, "resolve: fading (mid-way)", s.tensionOn and s.tensionLevel < 0.8 and s.tensionLevel > 0.0, fmt(s))
	host.wait(0.5)
	s = st()
	verdict(host, "resolve: gone within ~0.4 s, base restored", not s.tensionOn and s.liveMusicSounds == 1, fmt(s))
	-- cancel path, then repeated cancels are harmless
	Music.tension(0.9, "Holding")
	host.wait(1.2)
	Music.cancel()
	host.wait(0.7)
	s = st()
	verdict(host, "cancel: gone within ~0.3 s", not s.tensionOn and s.liveMusicSounds == 1, fmt(s))
	Music.cancel()
	Music.cancel()
	verdict(host, "repeated cancel is harmless", st().liveMusicSounds == 1, fmt(st()))
	-- failure / exit while the layer is up
	Music.tension(0.9, "Holding")
	host.wait(0.8)
	host.store:setMode("Home")
	host.wait(1.4)
	verdict(host, "leaving Run stops it all", st().liveMusicSounds == 0, fmt(st()))
	Music.reset()
end

S["Music: single duck source"] = function(host: Host)
	Music.reset()
	Sounds.resetThrottles()
	Music.enable(true)
	host.enterRun()
	Music.setWorld("Downtown")
	host.wait(1.5)
	local s = st()
	verdict(host, "no duck at rest", s.duckLevel > 0.999 and s.duckSources == 0, fmt(s))
	for _ = 1, 5 do
		Music.duck("KeysCapture", 1.0)
		host.wait(0.02)
	end
	s = st()
	verdict(host, "the same id never stacks (one source)", s.duckSources == 1, fmt(s))
	host.wait(0.15)
	s = st()
	verdict(
		host,
		"attack reaches the floor 0.6 within about 0.15 s",
		s.duckLevel <= 0.62 and s.duckLevel >= 0.599,
		fmt(s)
	)
	host.wait(1.5)
	s = st()
	verdict(host, "released back to 1 after the duck ends", s.duckLevel > 0.97 and s.duckSources == 0, fmt(s))
	-- two different stings overlap: still one floor (no accumulation below 0.6)
	Music.duck("KeysCapture", 1.0)
	Music.duck("NewBest", 1.0)
	host.wait(0.3)
	s = st()
	verdict(host, "two ids, one floor (no deeper duck)", s.duckSources == 2 and s.duckLevel >= 0.599, fmt(s))
	host.wait(1.6)
	-- Results ticks and counts never duck
	for _ = 1, 8 do
		Sounds.play("ResultsTick")
		Sounds.play("ResultsCount")
		host.wait(0.05)
	end
	s = st()
	verdict(host, "Results ticks do not duck", s.duckSources == 0 and s.duckLevel > 0.999, fmt(s))
	-- the real capture sting ducks through Sounds (the hook is the only source)
	Sounds.play("KeysCapture")
	host.wait(0.3)
	s = st()
	verdict(host, "the KeysCapture sting ducks via Sounds", s.duckSources == 1 and s.duckLevel < 0.8, fmt(s))
	host.wait(2.0)
	clean()
end

S["Music: load check"] = function(host: Host)
	Music.reset()
	Music.enable(true)
	host.enterRun()
	local rows = {}
	for _, world in { "Downtown", "DustyHighway", "SummitPass" } do
		for index = 1, 2 do
			Music.useCandidate(world, index)
			Music.setWorld(world)
			local t0 = os.clock()
			while os.clock() - t0 < 6 and not st().baseLoaded do
				host.wait(0.2)
			end
			local s = st()
			table.insert(
				rows,
				string.format(
					"%s %d: %s loaded=%s length=%.1f s",
					world,
					index,
					tostring(s.baseId),
					tostring(s.baseLoaded),
					s.baseSeconds
				)
			)
			host.log("  " .. rows[#rows])
			host.wait(0.3)
		end
	end
	Music.useCandidate("Tension", 1)
	Music.reset()
	host.log("(loaded and length are PROPERTY checks only: no track was listened to)")
end

----------------------------------------------------------------------------------------------
-- Round 3

S["Music: fades and mute during a fade"] = function(host: Host)
	clean()
	host.enterRun()
	Music.enable(true)
	-- the first start comes up from silence: no surprise loud start
	Music.setWorld("Downtown")
	local s = st()
	verdict(
		host,
		"first start begins at 0 (no surprise loud start)",
		s.liveMusicSounds == 1 and s.baseVolume <= 0.001,
		fmt(s)
	)
	local up = timeUntil(host, 1.5, function()
		return st().baseLevel >= 0.99
	end)
	verdict(
		host,
		"fade-in takes at most 0.3 s",
		up <= Music.FADE_IN + 0.15 and st().baseLevel >= 0.99,
		string.format("%.2f s (limit %.2f s + 0.15 s of frame slack)", up, Music.FADE_IN)
	)
	-- the level crosses 0.99 a frame or two before the tween reports completion: give it a short moment to clean up
	timeUntil(host, 0.5, function()
		return st().tweens == 0
	end)
	verdict(host, "the fade-in cleaned up its tween", st().tweens == 0, fmt(st()))
	-- fade-out: stop
	Music.stop()
	local down = timeUntil(host, 1.5, function()
		return st().liveMusicSounds == 0
	end)
	s = st()
	verdict(
		host,
		"fade-out takes at most 0.4 s, then the Sound is gone",
		down <= Music.FADE_OUT + 0.15 and s.liveMusicSounds == 0 and s.tweens == 0 and s.dying == 0,
		string.format("%.2f s (limit %.2f s + 0.15 s); %s", down, Music.FADE_OUT, fmt(s))
	)
	-- mute DURING a fade-in
	Music.setWorld("Downtown")
	host.wait(0.1)
	local parentBefore = AudioMix.group("Music").Volume -- the player level (Music.state().parentVolume)
	Music.setMuted(true)
	host.wait(Music.FADE_MUTE + 0.2)
	s = st()
	verdict(
		host,
		"mute during a fade-in: silent within the mute fade, nothing left, parent untouched",
		s.liveMusicSounds == 0 and s.tweens == 0 and s.dying == 0 and s.parentVolume == parentBefore,
		fmt(s)
	)
	-- unmute: the remembered World comes back from 0
	Music.setMuted(false)
	host.wait(0.5)
	s = st()
	verdict(
		host,
		"unmute after a mute: one voice back at full level",
		s.liveMusicSounds == 1 and s.baseLevel >= 0.99 and s.tweens == 0,
		fmt(s)
	)
	-- unmute DURING the mute fade-out: the same Sound returns, the loop is not restarted
	local sound = Music.baseSound()
	local createdBefore = s.created
	local position = if sound then sound.TimePosition else 0
	Music.setMuted(true)
	host.wait(0.08)
	local mid = st()
	Music.setMuted(false)
	host.wait(0.5)
	s = st()
	verdict(
		host,
		"unmute during the fade-out: the same Sound comes back (no new voice, no restart)",
		mid.liveMusicSounds == 1
			and mid.dying == 1
			and sound ~= nil
			and Music.baseSound() == sound
			and s.created == createdBefore
			and s.liveMusicSounds == 1
			and s.baseLevel >= 0.99,
		string.format("created %d -> %d; %s", createdBefore, s.created, fmt(s))
	)
	if sound and sound.IsLoaded and position > 0.3 then
		verdict(
			host,
			"the loop position was not reset by the mute / unmute",
			sound.TimePosition >= position - 0.05,
			string.format("TimePosition %.2f -> %.2f s", position, sound.TimePosition)
		)
	else
		host.log("  loop-position check skipped (the track had not started playing yet: a property check only)")
	end
	-- the audition switch during a fade
	Music.enable(false)
	host.wait(0.1)
	Music.enable(true)
	host.wait(0.5)
	s = st()
	verdict(
		host,
		"enable off then on inside a fade: one voice, same World, nothing leaked",
		s.liveMusicSounds == 1
			and s.world == "Downtown"
			and s.baseLevel >= 0.99
			and s.tweens == 0
			and s.created - s.destroyed == s.liveMusicSounds,
		fmt(s)
	)
	clean()
end

S["Music: world churn and unmount"] = function(host: Host)
	clean()
	host.enterRun()
	Music.enable(true)
	Music.setWorld("Downtown")
	host.wait(0.6)
	local worlds = { "Downtown", "DustyHighway", "SummitPass" }
	local peak, peakTweens = 0, 0
	for i = 1, 30 do
		Music.setWorld(worlds[(i % 3) + 1])
		host.wait(0.05)
		local s = st()
		peak = math.max(peak, s.liveMusicSounds)
		peakTweens = math.max(peakTweens, s.tweens)
	end
	host.wait(0.9)
	local s = st()
	verdict(
		host,
		"30 rapid World changes: at most 3 voices while it runs",
		peak <= 3,
		string.format("peak voices %d, peak tweens %d", peak, peakTweens)
	)
	verdict(
		host,
		"30 rapid World changes: settles to one voice at full level, 0 tweens and 0 timers left",
		s.liveMusicSounds == 1 and s.baseLevel >= 0.99 and s.dying == 0 and s.tweens == 0 and s.timers == 0,
		fmt(s)
	)
	verdict(
		host,
		"30 rapid World changes: no leak",
		s.created - s.destroyed == s.liveMusicSounds,
		string.format("created %d destroyed %d live %d", s.created, s.destroyed, s.liveMusicSounds)
	)
	-- unmount in the middle of a crossfade, a tension rise and a duck
	Music.setWorld("DustyHighway")
	host.wait(0.1)
	Music.tension(0.9, "Holding")
	Music.duck("KeysCapture", 1.6)
	host.wait(0.1)
	local mid = st()
	Music.reset()
	s = st()
	verdict(
		host,
		"reset in the middle of a fade (crossfade, tension rise and duck): no Sound, tween or timer left",
		mid.tweens > 0
			and s.liveMusicSounds == 0
			and s.tweens == 0
			and s.timers == 0
			and s.dying == 0
			and not s.tensionOn
			and s.duckLevel == 1
			and s.created == s.destroyed,
		string.format("before %s | after %s", fmt(mid), fmt(s))
	)
	host.wait(1.8) -- the cancelled duck timer must not fire into the next run
	s = st()
	verdict(
		host,
		"reset: nothing comes back later (no stale timer, no stray Sound)",
		s.liveMusicSounds == 0 and s.timers == 0 and s.duckLevel == 1 and s.heartbeatConnections == 0,
		fmt(s)
	)
	-- stop during a fade, then reset: also clean
	Music.enable(true)
	Music.setWorld("SummitPass")
	host.wait(0.1)
	Music.stop()
	host.wait(0.05)
	Music.reset()
	verdict(host, "stop then reset mid-fade leaves nothing", st().liveMusicSounds == 0 and st().tweens == 0, fmt(st()))
	clean()
end

S["Music: slider drag and idle"] = function(host: Host)
	clean()
	local store = host.store
	local original = table.clone(store:get().settings)
	host.enterRun()
	MusicSetting.setOn(store, true)
	MusicSetting.setLevel(store, 0.5)
	Music.enable(true)
	Music.setWorld("Downtown")
	host.wait(1.0)
	local sound = Music.baseSound()
	local createdBefore = st().created
	local position = if sound then sound.TimePosition else 0
	for i = 1, 50 do
		MusicSetting.setLevel(store, 0.2 + 0.6 * (i / 50)) -- the Settings slider: every tick calls apply()
		host.wait(0.016)
	end
	host.wait(0.3)
	local s = st()
	verdict(
		host,
		"slider drag, 50 ticks: the same Sound, no restart, no new voice",
		sound ~= nil
			and Music.baseSound() == sound
			and s.created == createdBefore
			and s.liveMusicSounds == 1
			and s.tweens == 0
			and sound.Looped,
		string.format("created %d -> %d; %s", createdBefore, s.created, fmt(s))
	)
	verdict(
		host,
		"slider drag: the parent level followed the player to 0.80, the music controller wrote nothing to it",
		math.abs(s.parentVolume - 0.8) < 1e-4 and s.duckLevel == 1,
		fmt(s)
	)
	if sound and sound.IsLoaded and position > 0.3 then
		verdict(
			host,
			"slider drag: the loop position was not reset",
			sound.TimePosition >= position - 0.05,
			string.format("TimePosition %.2f -> %.2f s", position, sound.TimePosition)
		)
	else
		host.log("  loop-position check skipped (the track had not started playing yet: a property check only)")
	end
	-- a steady loop writes no property: sample the Volume of the loop and the duck group for a second
	local base = Music.baseSound()
	local first = if base then base.Volume else -1
	local steady = true
	for _ = 1, 10 do
		host.wait(0.1)
		local b = Music.baseSound()
		if not b or b.Volume ~= first then
			steady = false
		end
	end
	s = st()
	verdict(
		host,
		"idle: a steady loop has no tween, no timer and no per-frame connection; its Volume is constant",
		steady
			and s.tweens == 0
			and s.timers == 0
			and s.heartbeatConnections == 0
			and Sounds.getDebugState().heartbeatConnections == 0
			and MusicSetting.getDebugState().tweens == 0,
		fmt(s)
	)
	-- MUSIC mute (2026-10-29: the Home switch and the Settings mute button): the player group fades (not a cut) to 0 and the
	-- loop keeps playing underneath, so unmute neither restarts nor re-creates it. While muted the kept level is the slider's.
	local loop = Music.baseSound()
	MusicSetting.setLevel(store, 0.6)
	host.wait(0.2)
	MusicSetting.setOn(store, false)
	host.wait(0.1)
	local midVolume = AudioMix.group("Music").Volume
	local mutedAt = if loop then loop.TimePosition else 0
	host.wait(0.6)
	s = st()
	verdict(
		host,
		"Music mute: the player group fades (not a cut) to 0; the same loop keeps playing and keeping time",
		midVolume > 0
			and midVolume < 0.6
			and s.parentVolume == 0
			and s.liveMusicSounds == 1
			and Music.baseSound() == loop
			and loop ~= nil
			and loop.IsPlaying,
		string.format(
			"mid-fade %.2f; TimePosition %.2f -> %.2f s; %s",
			midVolume,
			mutedAt,
			if loop then loop.TimePosition else -1,
			fmt(s)
		)
	)
	local createdMuted = st().created
	MusicSetting.setOn(store, true)
	host.wait(0.8)
	s = st()
	verdict(
		host,
		"Music unmute: back at the kept level (0.60), the same voice, nothing created",
		math.abs(s.parentVolume - 0.6) < 1e-4
			and s.liveMusicSounds == 1
			and Music.baseSound() == loop
			and s.created == createdMuted
			and MusicSetting.getDebugState().tweens == 0,
		fmt(s)
	)
	MusicSetting.setLevel(store, original.music)
	MusicSetting.setOn(store, original.musicOn ~= false)
	host.wait(0.5)
	clean()
end

S["Music: duck restores the user level"] = function(host: Host)
	clean()
	local store = host.store
	local original = table.clone(store:get().settings)
	host.enterRun()
	MusicSetting.setOn(store, true)
	MusicSetting.setLevel(store, 0.3)
	Music.enable(true)
	Music.setWorld("Downtown")
	host.wait(0.8)
	local parent = AudioMix.group("Music") -- the player's MUSIC level (2026-10-29)
	Music.duck("KeysCapture", 1.0)
	host.wait(0.2)
	local s = st()
	verdict(
		host,
		"ducked: the duck group is at the floor and the player's level (0.30) is untouched",
		math.abs(parent.Volume - 0.3) < 1e-4 and s.duckLevel >= 0.599 and s.duckLevel <= 0.62,
		fmt(s)
	)
	MusicSetting.setLevel(store, 0.7) -- the player moves the slider DURING the duck
	host.wait(0.1)
	s = st()
	verdict(
		host,
		"slider during a duck: the new level applies at once, the duck keeps its floor",
		math.abs(parent.Volume - 0.7) < 1e-4 and s.duckLevel <= 0.62,
		fmt(s)
	)
	host.wait(1.3)
	s = st()
	verdict(
		host,
		"after the duck: the level is the player's latest (0.70, not 1, not the old 0.30) and the duck is back to 1",
		math.abs(parent.Volume - 0.7) < 1e-4 and s.duckLevel > 0.999 and s.duckSources == 0 and s.tweens == 0,
		fmt(s)
	)
	-- Music Off stays Off through a fanfare: nothing un-mutes it, nothing ducks, nothing plays
	MusicSetting.setOn(store, false)
	host.wait(0.6)
	Sounds.resetThrottles()
	Sounds.play("KeysCapture")
	Sounds.play("NewBest")
	Sounds.play("Milestone")
	host.wait(2.2)
	s = st()
	verdict(
		host,
		"Music muted through three stings: still silent (player level 0), nothing un-mutes it; the loop keeps time silently",
		s.parentVolume == 0 and s.liveMusicSounds == 1 and parent.Volume == 0,
		fmt(s)
	)
	-- the same stings with Music On: the duck releases to the player's level
	MusicSetting.setOn(store, true)
	host.wait(0.8)
	Sounds.resetThrottles()
	Sounds.play("KeysCapture")
	host.wait(0.3)
	local ducked = st().duckLevel
	host.wait(2.4)
	s = st()
	verdict(
		host,
		"Music On: the sting ducks, then the level returns to 0.70",
		ducked < 0.8 and math.abs(parent.Volume - 0.7) < 1e-4 and s.duckLevel > 0.999 and s.duckSources == 0,
		string.format("duck %.2f then %s", ducked, fmt(s))
	)
	MusicSetting.setLevel(store, original.music)
	MusicSetting.setOn(store, original.musicOn ~= false)
	host.wait(0.5)
	clean()
end

S["Music: ticks never duck"] = function(host: Host)
	clean()
	host.enterRun()
	Music.enable(true)
	Music.setWorld("Downtown")
	host.wait(0.8)
	local lowest = 1
	local ducks = 0
	for i = 1, 90 do
		Sounds.play("ResultsTick")
		Sounds.play("ResultsCount")
		Sounds.play("Tap")
		Sounds.play("CashGain")
		Sounds.play("LapPay")
		Sounds.play("KeysTick")
		Sounds.rise("KeysRise", i / 90)
		Sounds.play("KeysPending")
		host.wait(0.016)
		local s = st()
		lowest = math.min(lowest, s.duckLevel)
		ducks = math.max(ducks, s.duckSources)
	end
	verdict(
		host,
		"90 frames of ticks, taps, Cash, chime notes and the ring-full cue: the duck group never leaves 1",
		lowest == 1 and ducks == 0,
		string.format("lowest duck %.3f, most duck sources %d", lowest, ducks)
	)
	Sounds.play("Milestone")
	host.wait(0.3)
	verdict(
		host,
		"a real sting (Milestone) does duck: the one source",
		st().duckSources == 1 and st().duckLevel < 0.8,
		fmt(st())
	)
	host.wait(1.6)
	verdict(host, "and the duck released", st().duckLevel > 0.999 and st().duckSources == 0, fmt(st()))
	clean()
end

return S
