--!strict
-- TutorialStrings: EVERY player-facing word of the tutorial, in one table, so it can be localized later (BRIEF M11-11).
-- Nothing else in src/client/UI/Tutorial or the banner contains tutorial copy. Round 2 (N8-01a, 2026-11-02): the twelve
-- steps now carry a headline, a green instruction and ONE delayed hint (revealed after 8 seconds without progress).
-- Where playtesting should change a word, change it here only. Keys are stable ids; a localization table can map them one
-- to one.
--
--   Strings.step(index, context?) -> { title, line, hint }   the active banner; placeholders are filled from `context`
--   Strings.get(key) -> string                               any other line, "?" for an unknown key (never an error)
--   Strings.format(key, ...) -> string                       string.format on a line
--   Strings.control(kind, device) -> string                  the device-aware control phrase ("Press A and D")
--   Strings.verb(device) -> string                           "Tap" / "Click" / "Select"
--
-- Placeholders (braces; never shown literally): {SteerControl}, {HopControl}, {Tap}, {done}. They are resolved by
-- Strings.step from `context`: device ("Keyboard" | "Touch" | "Gamepad"), done (a live count), and an optional
-- controlText(kind, device) -> string? that the run integration may supply, so the words always match the controls the
-- run really has. The defaults below follow the control legend the banner used before (A and D, Space, Tap, A button)
-- and never promise a drag, hold or tap control the run does not have.
--
-- Honesty rules kept in the copy (BRIEF M11):
--   * "It's yours!" is shown only when a run adapter can VERIFY a claim; the standalone fixture says "New car preview!".
--   * "Your new car is saved." is shown only when an adapter can verify a real save. In the beta nothing from a run is
--     saved, so the verified-claim line is "You got the keys!" instead.
--   * The results screen in the beta has Revive and Retry, and Retry puts the player back on the island, so step 6 says
--     "Tap Retry to walk home." there. The fixture results card has a Home button, so it says "Choose HOME on the Results
--     screen."

local Strings = {}

export type StepText = { title: string, line: string, hint: string }
export type Context = {
	device: string?,
	done: number?,
	controlText: ((kind: string, device: string) -> string?)?,
}

local STEPS: { [number]: StepText } = {
	[0] = {
		title = "Welcome to Car Hop!",
		line = "Collect cars. Build your Raceway.",
		hint = "Follow the arrows to Downtown.",
	},
	[1] = {
		title = "Go to Downtown!",
		line = "Walk into the Downtown portal.",
		hint = "Follow the glowing arrows to the portal.",
	},
	[2] = {
		title = "Steer your car!",
		line = "{SteerControl} to move left and right.",
		hint = "Try steering both ways: {done}/2.",
	},
	[3] = {
		title = "Hop to another car!",
		line = "{HopControl}, then land on a car.",
		hint = "Aim for the next car before you jump.",
	},
	[4] = {
		title = "Make this car yours!",
		line = "Stay aboard until the keys fill.",
		hint = "Keep riding this new car to collect it.",
	},
	[5] = {
		title = "Watch your ENGINE HEAT!",
		line = "Hop before the heat fills up.",
		hint = "The heat gauge shows when to switch cars.",
	},
	[6] = {
		title = "Head back home!",
		line = "Choose HOME on the Results screen.",
		hint = "The HOME button returns you to your island.",
	},
	[7] = {
		title = "Put your car to work!",
		line = "Add your car to a Raceway spot.",
		hint = "Open your lineup and choose your new car.",
	},
	[8] = {
		title = "Watch your Raceway earn!",
		line = "Your car earns Cash when it finishes a lap.",
		hint = "Watch your car cross the finish line.",
	},
	[9] = {
		title = "Upgrade your Raceway!",
		line = "Visit the Raceway shopkeeper.",
		hint = "Follow the arrows to see the next upgrade.",
	},
	[10] = {
		title = "Take a look in the Shop!",
		line = "Open the Shop to see what is available.",
		hint = "{Tap} the Shop button. No purchase is needed.",
	},
	[11] = {
		title = "You're ready!",
		line = "Collect more cars and grow your Raceway!",
		hint = "Downtown is ready whenever you are.",
	},
}

local LINES: { [string]: string } = {
	-- step 1
	["portal.retry"] = "Try the portal again.",
	["portal.retry.hint"] = "Walk into the glowing portal.",
	-- step 2 and 3
	["rerun"] = "Walk into a portal to try again.",
	["rerun.hint"] = "Follow the glowing arrows to the portal.",
	["hop.miss"] = "Try again. Aim for a car.",
	["hop.miss.hint"] = "Aim for the next car before you jump.",
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
	["home.fixture"] = "Choose HOME on the Results screen.",
	["home.retry"] = "Tap Retry to walk home.",
	["home.retry.hint"] = "Retry puts you back on your island.",
	["home.wait.title"] = "Keep riding!",
	["home.wait.line"] = "Hop on until the ride ends.",
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
	-- the banner's tutorial progress words ("2 / 12"), kept as a format so a locale can reorder them
	["progress.format"] = "%d / %d",
	-- returning players (N8-05): the goal pill words
	["return.upgrade.title"] = "UPGRADE READY!",
	["return.upgrade.line"] = "You can afford the next Raceway upgrade.",
	["return.portal.title"] = "NEXT WORLD READY!",
	["return.portal.line"] = "Walk into its portal!",
	["return.mission.title"] = "REWARD WAITING!",
	["return.mission.line"] = "Open Missions to claim it.",
	-- accessibility labels and debug
	["a11y.skip"] = "Skip the tutorial",
	["unavailable"] = "Not in this build yet.",
}

-- Control phrases by device. Defaults mirror the legend the banner showed before Round 2 (A and D, Space, Tap Hop, the A
-- button); the run integration may override them through Context.controlText so they always match the real controls.
local CONTROLS: { [string]: { [string]: string } } = {
	Steer = {
		Keyboard = "Press A and D",
		Touch = "Use the thumbstick",
		Gamepad = "Use the left stick",
	},
	Hop = {
		Keyboard = "Press Space",
		Touch = "Tap Hop",
		Gamepad = "Press A",
	},
}

local VERBS: { [string]: string } = { Keyboard = "Click", Touch = "Tap", Gamepad = "Select" }

function Strings.control(kind: string, device: string): string
	local byKind = CONTROLS[kind]
	return if byKind then (byKind[device] or byKind.Keyboard) else "?"
end

function Strings.verb(device: string): string
	return VERBS[device] or VERBS.Keyboard
end

local function fill(text: string, context: Context?): string
	if not string.find(text, "{", 1, true) then
		return text
	end
	local ctx: Context = context or {}
	local device = ctx.device or "Keyboard"
	local function control(kind: string): string
		local custom = ctx.controlText
		if custom then
			local ok, value = pcall(custom, kind, device)
			if ok and type(value) == "string" and value ~= "" then
				return value
			end
		end
		return Strings.control(kind, device)
	end
	local out = string.gsub(text, "{(%w+)}", function(name: string): string
		if name == "SteerControl" then
			return control("Steer")
		elseif name == "HopControl" then
			return control("Hop")
		elseif name == "Tap" then
			return Strings.verb(device)
		elseif name == "done" then
			return tostring(math.clamp(math.floor(ctx.done or 0), 0, 99))
		end
		return "{" .. name .. "}" -- an unknown placeholder is left as it is, never an error
	end)
	return out
end

function Strings.step(index: number, context: Context?): StepText
	local raw = STEPS[index]
	if not raw then
		return { title = "?", line = "?", hint = "?" }
	end
	return { title = fill(raw.title, context), line = fill(raw.line, context), hint = fill(raw.hint, context) }
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
		table.insert(out, s.hint)
	end
	for _, line in LINES do
		table.insert(out, line)
	end
	return out
end

return Strings
