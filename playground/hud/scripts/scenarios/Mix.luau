--!strict
-- PLAYGROUND ONLY (Lane 3 Round 3, R3-A): the sound MIX and the Keys chime. PROPERTY CHECKS ONLY: levels, counts, spacing,
-- lifetimes and caps of the Sounds module. Nothing here can say how anything sounds (nothing was listened to), and no line
-- below should be read as "pleasant", "gentle to the ear" or "balanced to the ear": it checks numbers against stated caps.
-- Times are wall-clock; a throttled or unfocused Studio window can stretch them (re-run focused before believing a timing FAIL).
--
--   Mix: reference table          one Volume per hook, relative levels, the music bed ratio, the chime ladder numbers
--   Mix: peak overlap             capture confirm + Cash + warning (+ more) at once under music and tension: sums and counts
--   Mix: throttles                ten ticks in one second, a same-frame burst, every throttled hook's minimum spacing
--   Mix: Keys chime ladder        note count, spacing, pitch range, no retrigger, no per-frame property writes, stop and restart
--   Mix: ring-full cue and fanfare the ring-full cue is quiet and never a fanfare; the fanfare is once per key; trimmed
--   Mix: loops and cleanup        the tally loop starts from 0 and fades out; stopAll leaves zero voices, tweens and timers
--   Mix: capture flow             the REAL Keys flow: no fanfare while pending, exactly one on KeysConfirmed, none on cancel

local Players = game:GetService("Players")

local Prototype = Players.LocalPlayer
	:WaitForChild("PlayerScripts")
	:WaitForChild("Client")
	:WaitForChild("UI")
	:WaitForChild("Prototype")
local Music = require(Prototype:WaitForChild("Music"))
local Sounds = require(Prototype:WaitForChild("Sounds"))
local MusicSetting = require(Prototype:WaitForChild("Home"):WaitForChild("MusicSetting"))

type Host = { [string]: any }

local EPS = 1e-6

-- every hook the HUD uses (Sounds.Hook); the table must list a Volume for each
local HOOKS = {
	"Tap",
	"Open",
	"Close",
	"CashGain",
	"CashBig",
	"CashSpend",
	"Toast",
	"TutorialDone",
	"Unlock",
	"LapPay",
	"KeysTick",
	"KeysRise",
	"KeysPending",
	"KeysCapture",
	"Hop",
	"HopLock",
	"Dash",
	"Milestone",
	"ResultsCount",
	"ResultsTick",
	"NewBest",
	"Warning",
	"Bonk",
}

local counter = 0
local function nonce(): string
	counter += 1
	return string.format("%d-%d", math.floor(os.clock() * 1000), counter)
end

local function verdict(host: Host, name: string, ok: boolean, detail: string)
	host.log(string.format("%s %s: %s", if ok then "PASS" else "FAIL", name, detail))
end

local function clean()
	Music.reset()
	Sounds.stopAll()
	Sounds.resetThrottles()
	MusicSetting.reset()
end

-- raw and effective sums, count and per-hook counts of the effects in the SFX group right now
local function sfxNow(): (number, number, number, number, { [string]: number })
	local group = Sounds.group()
	local raw, eff, count, single = 0, 0, 0, 0
	local per: { [string]: number } = {}
	for _, child in group:GetChildren() do
		if child:IsA("Sound") then
			raw += child.Volume
			eff += child.Volume * group.Volume
			count += 1
			single = math.max(single, child.Volume)
			per[child.Name] = (per[child.Name] or 0) + 1
		end
	end
	return raw, eff, count, single, per
end

-- all music voices together, each times its dip and duck groups but NOT the player's own level (the parent group)
local function musicNow(): number
	local parent = Sounds.musicGroup()
	local sum = 0
	for _, d in parent:GetDescendants() do
		if d:IsA("Sound") then
			local factor = 1
			local node: Instance? = d.SoundGroup
			while node and node ~= parent and node:IsA("SoundGroup") do
				factor *= node.Volume
				node = node.Parent
			end
			sum += d.Volume * factor
		end
	end
	return sum
end

local function history(hook: string): { { hook: string, at: number, volume: number, speed: number } }
	local out = {}
	for _, entry in Sounds.history() do
		if entry.hook == hook then
			table.insert(out, entry)
		end
	end
	return out
end

local function minGap(list: { { at: number } }): number
	local gap = math.huge
	for i = 2, #list do
		gap = math.min(gap, list[i].at - list[i - 1].at)
	end
	return gap
end

local function setKeys(host: Host, id: string, car: any, progress: number, status: string)
	local run = host.store:get().run
	if not run then
		return
	end
	local merged = table.clone(run) :: any
	merged.keys = { id = id, target = car, progress = progress, status = status }
	host.store:set("run", merged)
end

local function send(host: Host, kind: string, fields: { [string]: any }?)
	local e = fields or {}
	e.id = e.id or (kind .. "-" .. nonce())
	return host.emit(kind, e)
end

local S: { [string]: (Host) -> () } = {}

S["Mix: reference table"] = function(host: Host)
	local mix = Sounds.MIX
	local h = mix.hooks
	local missing = {}
	local loudest = 0
	for _, hook in HOOKS do
		local v = h[hook]
		if v == nil or v <= 0 then
			table.insert(missing, hook)
		else
			loudest = math.max(loudest, v)
		end
	end
	verdict(
		host,
		"one target Volume for each of the 23 hooks, none above the peak cap",
		#missing == 0 and loudest <= mix.peakCap + EPS,
		string.format("missing [%s], loudest %.2f, cap %.2f", table.concat(missing, ","), loudest, mix.peakCap)
	)
	verdict(
		host,
		"relative levels: the warning is not under the reference; ticks, lock-on cue and chime notes are under it; the ring-full cue is under the notes; the capture fanfare is the largest",
		h.Warning >= mix.sfxReference
			and h.ResultsTick < mix.sfxReference
			and h.HopLock < mix.sfxReference
			and h.KeysRise < mix.sfxReference
			and h.KeysPending < h.KeysRise
			and h.KeysCapture >= loudest - EPS
			and h.KeysCapture > h.CashGain,
		string.format(
			"reference %.2f; warning %.2f, tick %.2f, lock-on %.2f, note %.2f, ring-full %.2f, fanfare %.2f, cash %.2f",
			mix.sfxReference,
			h.Warning,
			h.ResultsTick,
			h.HopLock,
			h.KeysRise,
			h.KeysPending,
			h.KeysCapture,
			h.CashGain
		)
	)
	local bed = mix.musicBed * mix.musicGroup
	local reference = mix.sfxReference * mix.sfxGroup
	local ratio = bed / reference
	local wanted = 10 ^ (mix.musicBedDb / 20)
	verdict(
		host,
		string.format("the music bed sits %d dB under the reference effect (documented ratio)", mix.musicBedDb),
		math.abs(ratio - wanted) < 0.01 * wanted,
		string.format("effective bed %.3f / reference %.3f = %.3f (wanted %.3f)", bed, reference, ratio, wanted)
	)
	local quietestEffect = math.huge
	for _, hook in { "Tap", "CashGain", "Warning", "KeysCapture", "ResultsTick", "HopLock", "KeysPending", "LapPay" } do
		quietestEffect = math.min(quietestEffect, h[hook] * mix.sfxGroup)
	end
	verdict(
		host,
		"the music bed is under every routed effect (effective levels at the reference groups)",
		bed < quietestEffect,
		string.format("bed %.3f, quietest checked effect %.3f", bed, quietestEffect)
	)
	local c = mix.chime
	local top, bottom = -math.huge, math.huge
	for _, semitones in c.semitones do
		top = math.max(top, semitones)
		bottom = math.min(bottom, semitones)
	end
	verdict(
		host,
		"chime ladder: 4 discrete notes, within 5 semitones, never above the sample's own pitch, 0.25 s apart at least",
		#c.semitones == c.maxNotes and c.maxNotes <= 4 and top - bottom <= 5 and top <= 0 and c.gap >= 0.25,
		string.format("%d notes, range %d semitones, top %d, gap %.2f s", #c.semitones, top - bottom, top, c.gap)
	)
	verdict(
		host,
		"caps are stated: sum cap, voice cap and per-hook cap",
		mix.sumCap >= mix.peakCap and mix.maxVoices >= mix.maxPerHook and mix.maxPerHook >= 1,
		string.format(
			"sum %.2f, peak %.2f, voices %d, per hook %d, music sum %.2f",
			mix.sumCap,
			mix.peakCap,
			mix.maxVoices,
			mix.maxPerHook,
			mix.musicSumCap
		)
	)
	host.log("(property checks only: no level was listened to)")
end

S["Mix: peak overlap"] = function(host: Host)
	clean()
	local store = host.store
	local original = table.clone(store:get().settings)
	host.enterRun()
	MusicSetting.setOn(store, true)
	MusicSetting.setLevel(store, 0.5) -- the reference groups: music 0.5, effects 0.6
	MusicSetting.setSfx(store, 0.6)
	Music.enable(true)
	Music.setWorld("Downtown")
	host.wait(0.6)
	Music.tension(0.9, "Holding") -- a capture is in progress: the tension layer is up, the bed is dipped
	host.wait(0.6)
	local mix = Sounds.MIX
	local group = Sounds.group()
	-- confirm + Cash + warning together, with a click, a bump, a toast and a chime note on top
	Sounds.play("KeysCapture")
	Sounds.play("CashGain")
	Sounds.play("Warning")
	Sounds.play("Tap")
	Sounds.play("Bonk")
	Sounds.play("Toast")
	Sounds.rise("KeysRise", 0.3)
	local maxRaw, maxEff, maxCount, maxSingle, maxPer, maxMusic, lowestDuck = 0, 0, 0, 0, 0, 0, 1
	local fanfareGone: number? = nil
	local t0 = os.clock()
	while os.clock() - t0 < 2.4 do
		local raw, eff, count, single, per = sfxNow()
		maxRaw = math.max(maxRaw, raw)
		maxEff = math.max(maxEff, eff)
		maxCount = math.max(maxCount, count)
		maxSingle = math.max(maxSingle, single)
		for _, n in per do
			maxPer = math.max(maxPer, n)
		end
		maxMusic = math.max(maxMusic, musicNow())
		lowestDuck = math.min(lowestDuck, Music.state().duckLevel)
		if not fanfareGone and per.UI_KeysCapture == nil and os.clock() - t0 > 0.05 then
			fanfareGone = os.clock() - t0
		end
		host.wait(0.03)
	end
	local plays = Sounds.played()
	verdict(
		host,
		"peak overlap: the sum of live effect Volumes stays within the sum cap, before and after the group",
		maxRaw <= mix.sumCap + EPS and maxEff <= mix.sumCap * group.Volume + EPS,
		string.format(
			"raw %.3f / cap %.2f; effective %.3f / cap %.3f at group %.2f",
			maxRaw,
			mix.sumCap,
			maxEff,
			mix.sumCap * group.Volume,
			group.Volume
		)
	)
	verdict(
		host,
		"peak overlap: Sound count in the effects group within the voice cap and the per-hook cap; no single Volume over the peak cap",
		maxCount <= mix.maxVoices and maxPer <= mix.maxPerHook and maxSingle <= mix.peakCap + EPS,
		string.format(
			"count %d / %d, per hook %d / %d, single %.2f / %.2f",
			maxCount,
			mix.maxVoices,
			maxPer,
			mix.maxPerHook,
			maxSingle,
			mix.peakCap
		)
	)
	verdict(
		host,
		"peak overlap: the confirm sting, Cash and the warning all sounded (the cap scales the last one, it does not silence it)",
		(plays.KeysCapture or 0) >= 1 and (plays.CashGain or 0) >= 1 and (plays.Warning or 0) >= 1,
		string.format(
			"KeysCapture %d, CashGain %d, Warning %d, Tap %d, Bonk %d, Toast %d, KeysRise %d",
			plays.KeysCapture or 0,
			plays.CashGain or 0,
			plays.Warning or 0,
			plays.Tap or 0,
			plays.Bonk or 0,
			plays.Toast or 0,
			plays.KeysRise or 0
		)
	)
	verdict(
		host,
		"peak overlap: the music (bed and tension layer) stays within the music cap",
		maxMusic <= mix.musicSumCap + EPS,
		string.format("music sum %.3f / cap %.3f (before the player's own level)", maxMusic, mix.musicSumCap)
	)
	verdict(
		host,
		"fanfare under music: the duck reached its floor, and released to 1 afterwards",
		lowestDuck <= Music.DUCK_FLOOR + 0.02 and Music.state().duckLevel > 0.999,
		string.format("lowest duck %.2f, now %.3f", lowestDuck, Music.state().duckLevel)
	)
	verdict(
		host,
		"the fanfare is trimmed: its Sound is gone within its 1.8 s limit",
		fanfareGone ~= nil and fanfareGone <= mix.fanfareSeconds + 0.2,
		string.format("gone after %s s (limit %.1f s + 0.2 s)", tostring(fanfareGone), mix.fanfareSeconds)
	)
	MusicSetting.setLevel(store, original.music)
	MusicSetting.setSfx(store, original.sfx)
	MusicSetting.setOn(store, original.musicOn ~= false)
	host.wait(0.4)
	clean()
	local state = Sounds.getDebugState()
	verdict(
		host,
		"cleanup: no voice, tween or timer left in Sounds, none in Music",
		state.liveVoices == 0 and state.tweens == 0 and state.timers == 0 and Music.state().tweens == 0,
		string.format("voices %d, tweens %d, timers %d", state.liveVoices, state.tweens, state.timers)
	)
	host.log("(property checks only: no level was listened to)")
end

S["Mix: throttles"] = function(host: Host)
	clean()
	-- ten ticks in one second
	for _ = 1, 10 do
		Sounds.play("ResultsTick")
		host.wait(0.1)
	end
	local ticks = history("ResultsTick")
	local interval = Sounds.minInterval("ResultsTick") or 0
	verdict(
		host,
		"ten ticks in one second: fewer than ten sound and none closer than the throttle",
		#ticks >= 1 and #ticks < 10 and minGap(ticks) >= interval - EPS,
		string.format("%d of 10 sounded, closest pair %.3f s, throttle %.2f s", #ticks, minGap(ticks), interval)
	)
	-- a burst inside one frame
	Sounds.stopAll()
	Sounds.resetThrottles()
	for _ = 1, 40 do
		Sounds.play("ResultsTick")
		Sounds.play("Tap")
		Sounds.rise("KeysRise", 0.3)
		Sounds.play("KeysRise") -- the notes belong to the ladder: a plain play of the hook makes no sound
	end
	local plays = Sounds.played()
	verdict(
		host,
		"a burst of 40 calls in one frame: one ResultsTick, one Tap, one chime note",
		plays.ResultsTick == 1 and plays.Tap == 1 and plays.KeysRise == 1,
		string.format(
			"ResultsTick %d, Tap %d, KeysRise %d (40 calls of each)",
			plays.ResultsTick or 0,
			plays.Tap or 0,
			plays.KeysRise or 0
		)
	)
	-- every throttled hook, called every frame for 1.3 s
	local bad = {}
	local rows = {}
	for _, hook in
		{
			"Tap",
			"Open",
			"CashGain",
			"LapPay",
			"Toast",
			"Warning",
			"Bonk",
			"Hop",
			"HopLock",
			"ResultsTick",
			"Milestone",
		}
	do
		Sounds.stopAll()
		Sounds.resetThrottles()
		local t0 = os.clock()
		while os.clock() - t0 < 1.3 do
			Sounds.play(hook :: any)
			host.wait(0.016)
		end
		local list = history(hook)
		local throttle = Sounds.minInterval(hook :: any) or 0
		local most = math.floor(1.3 / math.max(throttle, 0.001)) + 1
		table.insert(rows, string.format("%s %d (limit %d, gap %.2f)", hook, #list, most, minGap(list)))
		if #list > most or minGap(list) < throttle - EPS then
			table.insert(bad, hook)
		end
	end
	verdict(
		host,
		"every hook sounds no faster than its own throttle, even when called every frame",
		#bad == 0,
		table.concat(rows, "; ")
	)
	Sounds.stopAll()
	Sounds.resetThrottles()
end

S["Mix: Keys chime ladder"] = function(host: Host)
	clean()
	local mix = Sounds.MIX
	local seen: { [Instance]: number } = {}
	local changed, looped = false, false
	local maxLive = 0
	local function sample()
		local live = 0
		for _, child in Sounds.group():GetChildren() do
			if child:IsA("Sound") and child.Name == "UI_KeysRise" then
				live += 1
				local first = seen[child]
				if first == nil then
					seen[child] = child.PlaybackSpeed
				elseif first ~= child.PlaybackSpeed then
					changed = true
				end
				if child.Looped then
					looped = true
				end
			end
		end
		maxLive = math.max(maxLive, live)
	end
	-- a steady climb from 0 to 100% in 1.6 s, called every frame
	local t0 = os.clock()
	while os.clock() - t0 < 1.6 do
		Sounds.rise("KeysRise", (os.clock() - t0) / 1.6)
		sample()
		host.wait()
	end
	Sounds.rise("KeysRise", 1)
	sample()
	local notes = history("KeysRise")
	local slowest, fastest = math.huge, 0
	local ascending = true
	for i, entry in notes do
		slowest = math.min(slowest, entry.speed)
		fastest = math.max(fastest, entry.speed)
		if i > 1 and entry.speed <= notes[i - 1].speed then
			ascending = false
		end
	end
	verdict(
		host,
		"chime ladder: one note a quarter of progress, 4 in all, never more",
		#notes == mix.chime.maxNotes,
		string.format("%d notes", #notes)
	)
	verdict(
		host,
		"chime ladder: never closer than 0.25 s",
		minGap(notes) >= mix.chime.gap - EPS,
		string.format("closest pair %.3f s", minGap(notes))
	)
	verdict(
		host,
		"chime ladder: pitch ascends by discrete steps, within 5 semitones, never above the sample's own pitch",
		ascending and fastest <= 1 + EPS and fastest / slowest <= 2 ^ (5 / 12) + EPS,
		string.format("speeds %.3f to %.3f (ratio %.3f, limit %.3f)", slowest, fastest, fastest / slowest, 2 ^ (5 / 12))
	)
	verdict(
		host,
		"chime ladder: notes are one-shots, stacked at most to the per-hook cap, and PlaybackSpeed is never rewritten",
		not looped and not changed and maxLive <= mix.maxPerHook,
		string.format(
			"looped %s, speed rewritten %s, most notes alive at once %d",
			tostring(looped),
			tostring(changed),
			maxLive
		)
	)
	-- a note is a short one-shot: its Sound is gone well within a second of the last note
	host.wait(0.9)
	verdict(
		host,
		"chime ladder: every note Sound is gone within 0.55 s + a moment",
		(Sounds.getDebugState().perHook.KeysRise or 0) == 0,
		string.format("alive %d", Sounds.getDebugState().perHook.KeysRise or 0)
	)
	-- jitter and a repeated value never replay a note
	clean()
	Sounds.rise("KeysRise", 0.3)
	host.wait(0.3)
	Sounds.rise("KeysRise", 0.28)
	Sounds.rise("KeysRise", 0.3)
	Sounds.rise("KeysRise", 0.31)
	host.wait(0.3)
	verdict(
		host,
		"progress that wobbles inside one quarter plays that note once",
		#history("KeysRise") == 1,
		string.format("%d notes", #history("KeysRise"))
	)
	-- a fast jump: at most one note per 0.25 s
	clean()
	for _, p in { 0.3, 0.55, 0.8, 1 } do
		Sounds.rise("KeysRise", p)
		host.wait(0.016)
	end
	local fast = history("KeysRise")
	verdict(
		host,
		"a jump from 0 to 100% in four frames: one note, then the gap rule holds (no stacked burst)",
		#fast == 1 and minGap(fast) >= mix.chime.gap - EPS,
		string.format("%d notes in four frames", #fast)
	)
	-- cancel in the middle of a ladder: ringing notes stop, the ladder starts over
	clean()
	Sounds.rise("KeysRise", 0.3)
	host.wait(0.3)
	Sounds.rise("KeysRise", 0.55)
	local before = Sounds.getDebugState()
	Sounds.stopRise("KeysRise")
	host.wait(0.3)
	local after = Sounds.getDebugState()
	verdict(
		host,
		"cancel mid-ladder: ringing notes are gone within 0.3 s, no tween left, the ladder is back at step 0",
		(before.perHook.KeysRise or 0) >= 1
			and (after.perHook.KeysRise or 0) == 0
			and after.chimeStep == 0
			and after.tweens == 0
			and after.chimeNotes == 0,
		string.format(
			"alive %d -> %d, step %d, tweens %d",
			before.perHook.KeysRise or 0,
			after.perHook.KeysRise or 0,
			after.chimeStep,
			after.tweens
		)
	)
	-- a new capture after that starts a fresh ladder
	host.wait(0.3)
	Sounds.rise("KeysRise", 0.3)
	verdict(
		host,
		"a new capture after a cancel gets its own notes again",
		#history("KeysRise") == 3,
		string.format("%d notes in all", #history("KeysRise"))
	)
	-- a restart without stopRise (progress falls back a long way) also starts over
	clean()
	Sounds.rise("KeysRise", 0.8)
	host.wait(0.3)
	Sounds.rise("KeysRise", 0.1)
	host.wait(0.3)
	Sounds.rise("KeysRise", 0.3)
	verdict(
		host,
		"progress that restarts from near 0 starts a new ladder by itself",
		#history("KeysRise") == 2 and Sounds.getDebugState().chimeStep == 1,
		string.format("%d notes, step %d", #history("KeysRise"), Sounds.getDebugState().chimeStep)
	)
	clean()
	host.log("(property checks only: no note was listened to)")
end

S["Mix: ring-full cue and fanfare"] = function(host: Host)
	clean()
	local mix = Sounds.MIX
	-- a full ring whose answer is pending: the ladder's last note, quiet, never a fanfare
	Sounds.rise("KeysRise", 0.3)
	host.wait(0.3)
	Sounds.rise("KeysRise", 0.55)
	host.wait(0.3)
	Sounds.rise("KeysRise", 0.8)
	host.wait(0.3)
	Sounds.play("KeysPending")
	Sounds.play("KeysPending")
	Sounds.play("KeysPending")
	local list = history("KeysPending")
	local plays = Sounds.played()
	verdict(
		host,
		"ring full, answer pending: one quiet cue (the last ladder note), repeated calls add nothing",
		#list == 1 and list[1].volume <= mix.hooks.KeysRise + EPS and list[1].speed == 1,
		string.format(
			"%d cue(s), Volume %.2f (note level %.2f), speed %.2f",
			#list,
			list[1] and list[1].volume or -1,
			mix.hooks.KeysRise,
			list[1] and list[1].speed or -1
		)
	)
	verdict(
		host,
		"ring full, answer pending: no fanfare, no new-best sting",
		(plays.KeysCapture or 0) == 0 and (plays.NewBest or 0) == 0,
		string.format("KeysCapture %d, NewBest %d", plays.KeysCapture or 0, plays.NewBest or 0)
	)
	-- the ladder already played its last note: the cue does not duplicate it
	clean()
	for i, p in { 0.3, 0.55, 0.8, 1 } do
		Sounds.rise("KeysRise", p)
		if i < 4 then
			host.wait(0.3)
		end
	end
	Sounds.play("KeysPending")
	verdict(
		host,
		"a ladder that reached 100% already played the last note: the pending cue adds none",
		#history("KeysRise") == 4 and #history("KeysPending") == 0,
		string.format("%d ladder notes, %d cue", #history("KeysRise"), #history("KeysPending"))
	)
	-- stopRise right after the ring-full note (the capture moves on to pending) lets that note finish
	local ringing = Sounds.getDebugState().perHook.KeysRise or 0
	Sounds.stopRise("KeysRise")
	host.wait(0.2)
	local letRing = Sounds.getDebugState().perHook.KeysRise or 0
	host.wait(0.6)
	verdict(
		host,
		"stopRise right after the ring-full note leaves that note to finish on its own (gone within its 0.55 s)",
		ringing >= 1 and letRing >= 1 and (Sounds.getDebugState().perHook.KeysRise or 0) == 0,
		string.format(
			"alive %d -> %d after the plain stop -> %d later",
			ringing,
			letRing,
			Sounds.getDebugState().perHook.KeysRise or 0
		)
	)
	-- stopRise(immediate) (a cancel) fades the same note out within 0.12 s
	clean()
	for i, p in { 0.3, 0.55, 0.8, 1 } do
		Sounds.rise("KeysRise", p)
		if i < 4 then
			host.wait(0.3)
		end
	end
	Sounds.stopRise("KeysRise", true)
	host.wait(0.3)
	verdict(
		host,
		"stopRise(immediate) after the ring-full note leaves no note and no tween",
		(Sounds.getDebugState().perHook.KeysRise or 0) == 0 and Sounds.getDebugState().tweens == 0,
		string.format("alive %d", Sounds.getDebugState().perHook.KeysRise or 0)
	)
	-- the fanfare is once per key
	clean()
	local first = Sounds.fanfare("runA:capture1")
	local again = Sounds.fanfare("runA:capture1")
	host.wait(1.6) -- past the hook's own 1.5 s throttle
	local nextRun = Sounds.fanfare("runB:capture1") -- the same capture id in a later run still sounds
	verdict(
		host,
		"fanfare: once per run-scoped key; the same id in a later run sounds again",
		first and not again and nextRun and (Sounds.played().KeysCapture or 0) == 2,
		string.format(
			"first %s, repeat %s, next run %s, played %d",
			tostring(first),
			tostring(again),
			tostring(nextRun),
			Sounds.played().KeysCapture or 0
		)
	)
	-- and it is short
	local entry = history("KeysCapture")[2]
	local t0 = os.clock()
	while (Sounds.getDebugState().perHook.KeysCapture or 0) > 0 and os.clock() - t0 < 3 do
		host.wait(0.02)
	end
	local lasted = os.clock() - (if entry then entry.at else os.clock())
	verdict(
		host,
		"fanfare: the Sound is gone within its limit (1.8 s) after it started",
		entry ~= nil and lasted <= mix.fanfareSeconds + 0.3 and (Sounds.getDebugState().perHook.KeysCapture or 0) == 0,
		string.format("gone %.2f s after it began, limit %.1f s", lasted, mix.fanfareSeconds)
	)
	clean()
	host.log("(property checks only: no fanfare was listened to)")
end

S["Mix: loops and cleanup"] = function(host: Host)
	clean()
	local stop = Sounds.loop("ResultsCount")
	local group = Sounds.group()
	local loop: Sound? = nil
	for _, child in group:GetChildren() do
		if child:IsA("Sound") and child.Name == "UI_ResultsCount" then
			loop = child
		end
	end
	verdict(
		host,
		"tally loop: one looped voice that starts from 0 (no surprise start)",
		loop ~= nil and loop.Looped and loop.Volume <= 0.02,
		string.format("voice %s, Volume %.3f", tostring(loop ~= nil), if loop then loop.Volume else -1)
	)
	host.wait(0.3)
	verdict(
		host,
		"tally loop: faded in to its Mix level",
		loop ~= nil and math.abs(loop.Volume - Sounds.MIX.hooks.ResultsCount) < 0.01,
		string.format("Volume %.3f (target %.2f)", if loop then loop.Volume else -1, Sounds.MIX.hooks.ResultsCount)
	)
	stop()
	stop() -- a second stop is harmless
	host.wait(0.05)
	local mid = loop ~= nil and loop.Parent ~= nil
	host.wait(0.4)
	verdict(
		host,
		"tally loop: stop fades it out (still there at 0.1 s, gone by 0.4 s), a second stop does nothing",
		mid and (loop == nil or loop.Parent == nil) and Sounds.liveVoices() == 0 and Sounds.getDebugState().tweens == 0,
		string.format("voices %d, tweens %d", Sounds.liveVoices(), Sounds.getDebugState().tweens)
	)
	-- two stops of the same voice plus stopAll in the middle of fades
	local s1 = Sounds.loop("ResultsCount")
	Sounds.play("CashGain")
	Sounds.play("Tap")
	Sounds.rise("KeysRise", 0.3)
	host.wait(0.05)
	s1()
	Sounds.stopAll()
	local state = Sounds.getDebugState()
	verdict(
		host,
		"stopAll in the middle of fades and trims: zero voices, tweens and timers; no Sound left in the group",
		state.liveVoices == 0 and state.tweens == 0 and state.timers == 0 and #Sounds.group():GetChildren() == 0,
		string.format(
			"voices %d, tweens %d, timers %d, children %d",
			state.liveVoices,
			state.tweens,
			state.timers,
			#Sounds.group():GetChildren()
		)
	)
	verdict(
		host,
		"no per-frame connection in Sounds, Music or the Music setting",
		state.heartbeatConnections == 0
			and Music.state().heartbeatConnections == 0
			and MusicSetting.getDebugState().heartbeatConnections == 0,
		"by construction (no RunService connection exists in these modules)"
	)
	-- 60 one-shots over three seconds leave no timers behind once they ended
	for i = 1, 60 do
		Sounds.play(if i % 2 == 0 then "Tap" else "CashGain")
		host.wait(0.05)
	end
	host.wait(7) -- the longest safety timer is 6 s for a one-shot
	state = Sounds.getDebugState()
	verdict(
		host,
		"60 one-shots later: no voice, tween or timer remains (every voice released its safety timer)",
		state.liveVoices == 0 and state.tweens == 0 and state.timers == 0,
		string.format("voices %d, tweens %d, timers %d", state.liveVoices, state.tweens, state.timers)
	)
	clean()
end

S["Mix: capture flow"] = function(host: Host)
	clean()
	host.api.setProfile("Desktop")
	host.api.setSpeed(0)
	if host.store:get().mode == "Run" then
		host.store:setMode("Home")
	end
	host.enterRun()
	host.wait(0.8)
	local car = table.clone(host.car("rev6")) :: any
	car.owned = false
	local id = "mix-" .. nonce()
	Sounds.stopAll()
	Sounds.resetThrottles()
	setKeys(host, id, car, 0.05, "Holding")
	host.wait(0.3)
	for _, p in { 0.15, 0.3, 0.45, 0.6, 0.75, 0.9, 0.98 } do
		setKeys(host, id, car, p, "Holding")
		host.wait(0.4)
	end
	setKeys(host, id, car, 1, "Pending")
	host.wait(1.2)
	local plays = Sounds.played()
	local notes = history("KeysRise")
	verdict(
		host,
		"capture flow, ring full and pending: no fanfare and no new-best sting",
		(plays.KeysCapture or 0) == 0 and (plays.NewBest or 0) == 0,
		string.format("KeysCapture %d, NewBest %d", plays.KeysCapture or 0, plays.NewBest or 0)
	)
	verdict(
		host,
		"capture flow, a climb 0 to 100%: at most 4 chime notes, 0.25 s apart at the least, no ticks",
		#notes <= Sounds.MIX.chime.maxNotes
			and minGap(notes) >= Sounds.MIX.chime.gap - EPS
			and (plays.KeysTick or 0) == 0,
		string.format("%d notes, closest %.3f s, KeysTick sounded %d", #notes, minGap(notes), plays.KeysTick or 0)
	)
	host.log(string.format("  (info) ring-full cue sounded %d time(s) while pending", plays.KeysPending or 0))
	-- the confirmation arrives: exactly one fanfare, and a duplicate adds nothing
	send(host, "KeysConfirmed", { captureId = id, car = car })
	host.wait(2.4)
	local confirmed = Sounds.played().KeysCapture or 0
	send(host, "KeysConfirmed", { captureId = id, car = car })
	host.wait(1.0)
	verdict(
		host,
		"capture flow, confirmed: exactly one fanfare, and a repeated confirmation adds no second",
		confirmed == 1 and (Sounds.played().KeysCapture or 0) == 1,
		string.format("after the confirmation %d, after the repeat %d", confirmed, Sounds.played().KeysCapture or 0)
	)
	-- a capture that is canceled: no fanfare, no note left ringing, the ladder is reset
	local id2 = "mix-" .. nonce()
	for _, p in { 0.1, 0.3, 0.6 } do
		setKeys(host, id2, car, p, "Holding")
		host.wait(0.4)
	end
	send(host, "KeysCanceled", { captureId = id2 })
	host.wait(1.6)
	local state = Sounds.getDebugState()
	verdict(
		host,
		"capture flow, canceled: no fanfare, no chime note left, the ladder is back at step 0",
		(Sounds.played().KeysCapture or 0) == 1 and (state.perHook.KeysRise or 0) == 0 and state.chimeStep == 0,
		string.format(
			"KeysCapture total %d, notes alive %d, step %d",
			Sounds.played().KeysCapture or 0,
			state.perHook.KeysRise or 0,
			state.chimeStep
		)
	)
	host.api.setSpeed(nil)
	clean()
	host.log("(property checks only: this checks which hooks fired, never how anything sounds)")
end

return S
