--!strict
-- TutorialStrings: EVERY player-facing word of the tutorial, in one table, so it can be localized later (BRIEF M11-11).
-- Nothing else in src/client/UI/Tutorial or the banner contains tutorial copy. The copy is the approved outline
-- (references/TUTORIAL-OUTLINE.md) with the wording from BRIEF M11-01b..g. Where playtesting should change a word, change
-- it here only. Keys are stable ids; a localization table can map them one to one.
--
--   Strings.step(index) -> { title, line }          the active banner (headline of 2 to 4 words, one short stripe line)
--   Strings.get(key) -> string                       any other line, "?" for an unknown key (never an error)
--   Strings.format(key, ...) -> string               string.format on a line
--
-- Honesty rules kept in the copy (BRIEF M11):
--   * "It's yours!" is shown only when a run adapter can VERIFY a claim; the standalone fixture says "New car preview!".
--   * "Your new car is saved." is shown only when an adapter can verify a real save. In the beta nothing from a run is
--     saved, so the verified-claim line is "You got the keys!" instead.
--   * The results screen in the beta has Revive and Retry, and Retry puts the player back on the island, so step 6 says
--     "Tap Retry to walk home." there. The fixture results card has a Home button, so it says "Tap Home on the results."
--   * The "Dusty Highway" line is a PREVIEW of a future goal while every beta portal is open.

local Strings = {}

export type StepText = { title: string, line: string }

local STEPS: { [number]: StepText } = {
	[0] = { title = "Let's get a car!", line = "Follow the arrows." },
	[1] = { title = "Go to Downtown!", line = "Walk into the Downtown portal." },
	[2] = { title = "Steer!", line = "Move left, then right." },
	[3] = { title = "Hop to a car!", line = "Aim for a car. Tap Hop." },
	[4] = { title = "Hold on!", line = "Stay until the Keys ring fills." },
	[5] = { title = "Too hot! Hop!", line = "Hop to another car." },
	[6] = { title = "Go home!", line = "Tap Home on the results." },
	[7] = { title = "Park your car!", line = "Pick your new car. Tap Park." },
	[8] = { title = "Cars earn cash!", line = "Watch your car finish a lap." },
	[9] = { title = "Upgrade your Raceway!", line = "Tap the free beta upgrade." },
	[10] = { title = "Check the Shop!", line = "Open the Shop. Take a look!" },
	[11] = { title = "You're ready!", line = "Get 5 cars to open Dusty Highway!" },
}

local LINES: { [string]: string } = {
	-- step 1
	["portal.retry"] = "Try the portal again.",
	-- step 2 and 3 (device hints sit beside the banner as icons; these are the words)
	["rerun"] = "Walk into a portal to try again.",
	["hop.miss"] = "Try again. Aim for a car.",
	-- step 4
	["claim.verified.title"] = "It's yours!",
	["claim.verified.line"] = "You got the keys!",
	["claim.saved.line"] = "Your new car is saved.",
	["claim.preview.title"] = "New car preview!",
	["claim.preview.line"] = "Preview only. Nothing is saved.",
	["claim.joyride.title"] = "Nice ride!",
	["claim.joyride.line"] = "You know this car already.",
	-- step 5 (waiting for a REAL Heat warning; the tutorial never makes Heat happen)
	["heat.wait.title"] = "Keep riding!",
	["heat.wait.line"] = "Hop to more cars.",
	-- step 6
	["home.fixture"] = "Tap Home on the results.",
	["home.retry"] = "Tap Retry to walk home.",
	["home.wait.title"] = "Keep riding!",
	["home.wait.line"] = "Hop on until the ride ends.",
	-- step 11 (a preview while all beta portals are open)
	["ready.preview"] = "Preview of a future goal. Portals are open in the beta.",
	-- banner done line
	["done.line"] = "Nice!",
	-- skip and replay
	["skip.button"] = "Skip",
	["skip.title"] = "Skip tutorial?",
	["skip.yes"] = "Yes",
	["skip.no"] = "No",
	["skip.done"] = "Tutorial skipped.",
	["replay.button"] = "Replay tutorial",
	["finished"] = "Tutorial done!",
	-- control legend words (the icons carry the meaning; these are the captions)
	["controls.left"] = "Left",
	["controls.right"] = "Right",
	["controls.space"] = "Space",
	["controls.tap"] = "Tap",
	["controls.drag"] = "Drag",
	["controls.hop"] = "Hop",
	-- accessibility labels and debug
	["a11y.skip"] = "Skip the tutorial",
	["unavailable"] = "Not in this build yet.",
}

function Strings.step(index: number): StepText
	return STEPS[index] or { title = "?", line = "?" }
end

function Strings.get(key: string): string
	return LINES[key] or "?"
end

function Strings.format(key: string, ...: any): string
	local ok, text = pcall(string.format, Strings.get(key), ...)
	return if ok then text else Strings.get(key)
end

-- Every string, for a localization export and for the playground's "longest line" checks.
function Strings.all(): { string }
	local out: { string } = {}
	for _, s in STEPS do
		table.insert(out, s.title)
		table.insert(out, s.line)
	end
	for _, line in LINES do
		table.insert(out, line)
	end
	return out
end

return Strings
