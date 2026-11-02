--!strict
-- PLAYGROUND ONLY (Lane 3, BRIEF M11). Tutorial scenarios, driven by STAND-IN events through TutorialFixture. Nothing here
-- is a game rule: the run, the claim, the lap and the upgrade are all stand-ins, and every line says so. Run one with
-- Invoke("play", "<name>") on the HUD playground's control function. Each scenario stops any earlier tutorial first and
-- leaves its own running when it ends, so the last frame can be captured; Invoke("tutorialStop") is not needed: run the next
-- scenario, or call Tutorial.stop() from the command bar.
--
-- Components used (mounted by HudPlayground): tutorial (Home/TutorialBanner), route (Home/TutorialRoute), menu, shop, hop,
-- results. The scenario passes the mounted banner and trail to the tutorial, so there is only ever ONE banner on screen.
--
-- host = { store, api, wait(seconds), emit(kind, fields), log(text) } (see Scenarios.luau)

local Players = game:GetService("Players")

local Tutorial = require(
	Players.LocalPlayer:WaitForChild("PlayerScripts"):WaitForChild("Client"):WaitForChild("UI"):WaitForChild("Tutorial")
) :: any
local Fixture = require(
	Players.LocalPlayer
		:WaitForChild("PlayerScripts")
		:WaitForChild("Client")
		:WaitForChild("UI")
		:WaitForChild("Tutorial")
		:WaitForChild("TutorialFixture")
) :: any

local function begin(host: any, startStep: number?, timings: { [string]: number }?): any
	Tutorial.stop()
	host.store:set("tutorial", nil)
	host.wait(0.3)
	return Fixture.start(host.api, { startStep = startStep, timings = timings })
end

local function line(host: any, controller: any, label: string)
	local d = controller:getDebugState()
	local banner = d.banner or {}
	local route = d.route or {}
	local guide = d.guide or {}
	host.log(
		string.format(
			'%s: step %s %s (%s) | banner "%s" / "%s" size %s | trail %s chevrons | arrow %s hand %s | hints %s',
			label,
			tostring(d.step),
			tostring(d.key),
			tostring(d.phase),
			tostring(banner.objective),
			tostring(banner.instruction),
			tostring(banner.objectiveSize),
			tostring(route.chevrons),
			tostring(guide.groundVisible),
			tostring(guide.handVisible),
			tostring(d.hints)
		)
	)
end

return {
	-- Every step in order, each held for a moment, then completed by its stand-in events.
	["Tutorial 1: full walkthrough (stand-in events)"] = function(host: any)
		local controller = begin(host, 0)
		Fixture.walkthrough(host.api, controller, host.wait, 1.4)
		host.wait(0.5)
		local d = Tutorial.getDebugState()
		host.log(
			"walkthrough ended: status " .. tostring(d.status) .. ", funnel " .. tostring(d.funnel and d.funnel.entries)
		)
	end,

	-- Jump to each of the 12 steps and hold it so every state can be looked at (and captured).
	["Tutorial 2: step through all 12"] = function(host: any)
		local controller = begin(host, 0)
		for index = 0, 11 do
			Fixture.jump(host.api, controller, index)
			host.wait(2.6)
			line(host, controller, "step")
		end
	end,

	-- Stand at step 1 and do nothing: the arrow pulses once at 8 seconds and the banner wiggles, then it stays calm.
	["Tutorial 3: timed hint once per step"] = function(host: any)
		local controller = begin(host, 1)
		host.wait(7)
		line(host, controller, "7 s, no hint yet")
		host.wait(2.5)
		line(host, controller, "9.5 s, one hint")
		host.wait(6)
		line(host, controller, "15 s, still one hint")
	end,

	-- Walk far from the path, then back: the trail is rebuilt from where the player stands; nobody is moved by the tutorial.
	["Tutorial 4: wander and recover"] = function(host: any)
		local controller = begin(host, 1)
		host.wait(1)
		line(host, controller, "start")
		local character = Players.LocalPlayer.Character
		local home = host.api.backdrop.homeSpot
		if character then
			character:PivotTo(home * CFrame.new(70, 0, -40))
		end
		host.wait(1.5)
		line(host, controller, "wandered (trail from the new spot)")
		if character then
			character:PivotTo(home)
		end
		host.wait(1.5)
		line(host, controller, "back")
	end,

	-- The first hop misses: the line says "Try again", nothing is claimed, then a real landing completes the step.
	["Tutorial 5: first hop misses, then recovers"] = function(host: any)
		local controller = begin(host, 3)
		host.wait(1)
		controller:emitRun("HopPressed", { onCar = true })
		host.wait(0.4)
		line(host, controller, "a press alone is not a landing")
		controller:emitRun("HopMissed")
		host.wait(1.2)
		line(host, controller, "missed: Try again. Aim for a car.")
		controller:emitRun("HopPressed", { onCar = true })
		controller:emitRun("HopLanded", { onCar = true })
		host.wait(1)
		line(host, controller, "landed: next step")
	end,

	-- The run ends before the car is collected: step 4 is kept, the trail leads back to the portal, the next run resumes it.
	["Tutorial 6: run ends before the keys"] = function(host: any)
		local controller = begin(host, 4)
		host.wait(1)
		controller:emitRun("KeysStarted")
		host.wait(0.6)
		controller:emitRun("RunEnded", { cause = "Crashed" })
		controller:emitRun("RunClosed")
		controller:emitIsland("ArrivedHome")
		if host.api.goHome then
			host.api.goHome()
		end
		host.wait(1.5)
		line(host, controller, "back home, step 4 kept, guided to the portal")
		controller:emitRun("RunStarted")
		host.wait(1)
		line(host, controller, "next run: step 4 again")
	end,

	-- Heat never warns: step 5 waits, the run ends, and step 5 is skipped as NOT OBSERVED (recorded, never faked).
	["Tutorial 7: Heat never observed"] = function(host: any)
		local controller = begin(host, 5)
		host.wait(1.2)
		line(host, controller, "waiting for a real Heat warning")
		controller:emitRun("RunEnded", { cause = "Crashed" })
		controller:emitRun("ResultsShown")
		host.wait(1.2)
		line(host, controller, "step 5 skipped, step 6")
		local d = controller:getDebugState()
		host.log("skipped: " .. game:GetService("HttpService"):JSONEncode(d.skipped))
	end,

	-- Skip asks first. No keeps going, Yes ends it; Replay twice leaves exactly one tutorial and no duplicate listeners.
	["Tutorial 8: skip confirm and replay twice"] = function(host: any)
		local controller = begin(host, 4)
		host.wait(1)
		controller:requestSkip()
		host.wait(0.5)
		host.log("confirm open: " .. tostring(controller:getSkipCard():isOpen()))
		controller:getSkipCard():close() -- No
		host.wait(0.5)
		host.log("after No, still running: " .. tostring(Tutorial.isActive()))
		Tutorial.skip() -- Yes
		host.wait(0.5)
		host.log("after Yes, running: " .. tostring(Tutorial.isActive()))
		Tutorial.replay()
		host.wait(1)
		Tutorial.replay()
		host.wait(1)
		local d = Tutorial.getDebugState()
		host.log(
			string.format(
				"after two replays: status %s, step %s, funnel entries %s, session %s, route builds %s",
				tostring(d.status),
				tostring(d.step),
				tostring(d.funnel and d.funnel.entries),
				tostring(d.funnel and d.funnel.session),
				tostring(d.route and d.route.builds)
			)
		)
	end,
}
