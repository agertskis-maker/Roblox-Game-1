--!strict
-- TutorialSteps: the data of the twelve tutorial steps (BRIEF M11-01, approved outline). Data only; the words live in
-- TutorialStrings and the rules that move between steps live in TutorialController. One step is active at a time.
--
-- Fields
--   index      0 to 11 (the outline's numbers; funnel step = index + 1)
--   key        stable id, also the funnel step name
--   icons      icon names to try in order (the banner icon; a kid who cannot read follows the picture)
--   where      "Island" (walking), "Run" (needs a run in progress), "Results" (needs the results screen)
--   needs      capabilities the step cannot do without. When the adapters cannot supply one, the step is SKIPPED with the
--              reason recorded; it is never completed by a made-up signal (BRIEF B-06a)
--   ground     the island target the trail and the arrow lead to (TutorialIslandAdapter target keys)
--   ui         the UI target the pointing hand marks (resolved lazily, so a panel that opens later is still found)
--   mask       true: a light dim with a cutout round the UI target (only for steps that happen on the island)
--   controls   "Steer" or "Hop": the device-aware key / drag / tap legend shown inside the banner
--   counter    goal of the small banner counter ("1/2")
--   timer      seconds after which the step completes by itself (steps 0 and 11 only)
--   big        confetti on completion
--   hint       seconds without progress before the one timed hint (arrow grows and pulses, banner wiggles)

local Steps = {}

export type Where = "Island" | "Run" | "Results"

export type Step = {
	index: number,
	key: string,
	icons: { string },
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
Steps.START_SECONDS = 2 -- step 0
Steps.READY_SECONDS = 3 -- step 11

local LIST: { Step } = {
	{
		index = 0,
		key = "Start",
		icons = { "Car", "CarCount" },
		where = "Island",
		needs = { "portal" },
		ground = "DowntownPortal",
		timer = Steps.START_SECONDS,
		hint = Steps.HINT_SECONDS,
	},
	{
		index = 1,
		key = "Portal",
		icons = { "Portal", "Flag" },
		where = "Island",
		needs = { "portal" },
		ground = "DowntownPortal",
		hint = Steps.HINT_SECONDS,
	},
	{
		index = 2,
		key = "Steer",
		icons = { "Steer", "Gamepad" },
		where = "Run",
		needs = { "steer" },
		controls = "Steer",
		counter = 2,
		hint = Steps.HINT_SECONDS,
	},
	{
		index = 3,
		key = "Hop",
		icons = { "Hop", "HopCar" },
		where = "Run",
		needs = { "hopLand" },
		controls = "Hop",
		ui = "Hop",
		hint = Steps.HINT_SECONDS,
	},
	{
		index = 4,
		key = "Keys",
		icons = { "HoldKey", "Key", "Keys" },
		where = "Run",
		needs = { "claim" },
		big = true,
		hint = Steps.HINT_SECONDS,
	},
	{
		index = 5,
		key = "Heat",
		icons = { "TooHot", "Flame" },
		where = "Run",
		needs = { "heat" },
		controls = "Hop",
		hint = Steps.HINT_SECONDS,
	},
	{
		index = 6,
		key = "Home",
		icons = { "Home", "Back" },
		where = "Results",
		needs = { "home" },
		ui = "ResultsHome",
		hint = Steps.HINT_SECONDS,
	},
	{
		index = 7,
		key = "Park",
		icons = { "Park", "Parking" },
		where = "Island",
		needs = { "lineup" },
		ground = "Paddock",
		ui = "Park",
		mask = true,
		hint = Steps.HINT_SECONDS,
	},
	{
		index = 8,
		key = "Earn",
		icons = { "Earn", "Cash" },
		where = "Island",
		needs = { "lapCue" },
		ground = "Raceway",
		hint = Steps.HINT_SECONDS,
	},
	{
		index = 9,
		key = "Upgrade",
		icons = { "Upgrade", "Raceway" },
		where = "Island",
		needs = { "upgrade" },
		ground = "Shopkeeper",
		ui = "UpgradeBuy",
		mask = true,
		hint = Steps.HINT_SECONDS,
	},
	{
		index = 10,
		key = "Shop",
		icons = { "Shop", "Cart" },
		where = "Island",
		needs = { "shop" },
		ui = "ShopButton",
		mask = true,
		hint = Steps.HINT_SECONDS,
	},
	{
		index = 11,
		key = "Ready",
		icons = { "Ready", "Trophy" },
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
