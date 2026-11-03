--!strict
-- TutorialSteps: the data of the six tutorial steps (Round 3, Adam's decision 5: go, hop, hold on, go home, park, done). Data only; the words live in
-- TutorialStrings and the rules that move between steps live in TutorialController. One step is active at a time.
--
-- Fields
--   index      0 to 5 (funnel step = index + 1)
--   key        stable id, also the funnel step name
--   icons      icon names to try in order (the banner icon; a kid who cannot read follows the picture). Round 2 (N8-01a):
--              the names are GameIcons painter names (Prototype/GameIcons.Painter), so the image family is drawn where it
--              has art and the older painters are only the fallback
--   accent     a colour glow behind the icon (the Downtown portal in Downtown blue)
--   iconLabel  a short caption on the icon ("HOME")
--   where      "Island" (walking), "Run" (needs a run in progress), "Results" (needs the results screen)
--   needs      capabilities the step cannot do without. When the adapters cannot supply one, the step is SKIPPED with the
--              reason recorded; it is never completed by a made-up signal (BRIEF B-06a)
--   ground     the island target the trail and the arrow lead to (TutorialIslandAdapter target keys)
--   ui         the UI target the pointing hand marks (resolved lazily, so a panel that opens later is still found)
--   mask       true: a light dim with a cutout round the UI target (only for steps that happen on the island)
--   controls   "Steer" or "Hop": the device-aware key / drag / tap legend shown inside the banner
--   counter    goal of the small banner counter ("1/2")
--   timer      seconds after which the step completes by itself (the last step only)
--   big        confetti on completion
--   hint       seconds without progress before the one timed hint (arrow grows and pulses, banner wiggles)

local Steps = {}

export type Where = "Island" | "Run" | "Results"

export type Step = {
	index: number,
	key: string,
	icons: { string },
	accent: Color3?,
	iconLabel: string?,
	where: Where,
	needs: { string },
	ground: string?,
	ui: string?,
	mask: boolean?,
	controls: string?,
	counter: number?,
	timer: number?,
	big: boolean?,
	hint: number,
}

Steps.HINT_SECONDS = 8 -- tunable (BRIEF M11-05)
Steps.DONE_SECONDS = 0.7 -- completion feedback before the next step (0.5 to 0.8, BRIEF M11-02a)
Steps.DOWNTOWN_COLOUR = Color3.fromRGB(52, 168, 255) -- the Downtown world colour (the playground's WorldRoutes)
Steps.START_SECONDS = 2 -- kept for the controller's timing table
Steps.READY_SECONDS = 3 -- the last step

local LIST: { Step } = {
	{
		index = 0,
		key = "Portal",
		icons = { "Portal", "Flag" },
		accent = Steps.DOWNTOWN_COLOUR,
		where = "Island",
		needs = { "portal" },
		ground = "DowntownPortal",
		hint = Steps.HINT_SECONDS,
	},
	{
		index = 1,
		key = "Hop",
		icons = { "Hop", "StuntCircuit", "HopCar" },
		where = "Run",
		needs = { "hopLand" },
		controls = "Hop",
		ui = "Hop",
		hint = Steps.HINT_SECONDS,
	},
	{
		index = 2,
		key = "Keys",
		icons = { "Keys", "Key", "KeyLock" },
		where = "Run",
		needs = { "claim" },
		big = true,
		hint = Steps.HINT_SECONDS,
	},
	{
		index = 3,
		key = "Home",
		icons = { "Home", "Garage" },
		iconLabel = "HOME",
		where = "Results",
		needs = { "home" },
		ui = "ResultsHome",
		hint = Steps.HINT_SECONDS,
	},
	{
		index = 4,
		key = "Park",
		icons = { "Parking", "Park" },
		where = "Island",
		needs = { "lineup" },
		ground = "Paddock",
		ui = "Park",
		mask = true,
		hint = Steps.HINT_SECONDS,
	},
	{
		index = 5,
		key = "Ready",
		icons = { "Medal", "Trophy" },
		where = "Island",
		needs = {},
		timer = Steps.READY_SECONDS,
		big = true,
		hint = Steps.HINT_SECONDS,
	},
}

Steps.List = LIST
Steps.Count = #LIST

function Steps.get(index: number): Step?
	return LIST[index + 1]
end

return Steps
