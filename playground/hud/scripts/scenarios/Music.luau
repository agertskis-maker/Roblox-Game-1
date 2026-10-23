--!strict
-- PLAYGROUND ONLY (Lane 3 Round 2, R2-A): run music scenarios. They check PROPERTIES and counts of the music controller
-- (voices, levels, fades, the one duck source); nothing here can say how any track SOUNDS (all eight candidates are
-- metadata-screened, never listened to). Music is OFF by default; each scenario enables it for itself and resets after.
--
--   Music: default off and mute         nothing plays by default, Music Off keeps it off, unmuting resumes
--   Music: world crossfade              one loop at a time, a changed World crossfades, no duplicate, no leak
--   Music: tension layer                follows the supplied progress, holds while SECURING, resolves only on confirmation
--   Music: single duck source           one duck, floor 0.6, attack and release, no stacking, no pumping on Results ticks
--   Music: load check                   the base loop's SoundId loaded and its TimeLength read (property check only)

local Players = game:GetService("Players")

local Prototype = Players.LocalPlayer
	:WaitForChild("PlayerScripts")
	:WaitForChild("Client")
	:WaitForChild("UI")
	:WaitForChild("Prototype")
local Music = require(Prototype:WaitForChild("Music"))
local Sounds = require(Prototype:WaitForChild("Sounds"))

type Host = { [string]: any }

local function verdict(host: Host, name: string, ok: boolean, detail: string)
	host.log(string.format("%s %s: %s", if ok then "PASS" else "FAIL", name, detail))
end

local function st(): { [string]: any }
	return Music.state()
end

local function fmt(s: { [string]: any }): string
	return string.format(
		"enabled=%s muted=%s world=%s sounds=%d base=%.2f tension=%.2f(%s) duck=%.2f(%d) dying=%d parent=%.2f",
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
		s.parentVolume
	)
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
	host.wait(0.3)
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
		"60%: the layer is rising (target about 0.27)",
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
	host.wait(0.4)
	s = st()
	verdict(host, "resolve: fading (mid-way)", s.tensionOn and s.tensionLevel < 0.8 and s.tensionLevel > 0.0, fmt(s))
	host.wait(0.7)
	s = st()
	verdict(host, "resolve: gone within ~0.8 s, base restored", not s.tensionOn and s.liveMusicSounds == 1, fmt(s))
	-- cancel path, then repeated cancels are harmless
	Music.tension(0.9, "Holding")
	host.wait(1.2)
	Music.cancel()
	host.wait(0.7)
	s = st()
	verdict(host, "cancel: gone within ~0.4 s", not s.tensionOn and s.liveMusicSounds == 1, fmt(s))
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
	host.wait(1.3)
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
	Music.reset()
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

return S
