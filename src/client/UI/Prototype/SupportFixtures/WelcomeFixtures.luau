--!strict
-- PREVIEW fixtures for the Welcome back card (big round M14). Every amount, time and cap here is made up for review.
-- The offline amount, the time away and the earning caps are Brian L's; the card only shows what it is given and never
-- changes any balance (the Cash is already in the balance when the card appears).
--
-- THE SEAM FOR BRIAN L (the M18 message asks for these fields):
--   status           "Checking" until the server has the verified result, "Ready" once it does, "Error" if it failed
--   earned           the verified amount already credited, whole dollars; nil = unknown (never shown as $0)
--   awaySeconds      real time since the last session; nil = unknown (the line is hidden, not invented)
--   cappedSeconds    the part of that time that was paid (never more than awaySeconds); nil = same as awaySeconds
--   vip, capSeconds, vipCapSeconds   which cap applied and what each cap is; vip nil = unknown (the note is hidden)
--   lineup[]         the cars on the player's Raceway for the miniature lap (paint, family, name)

local WelcomeFixtures = {}

WelcomeFixtures.Source = "PREVIEW fixture: the real amount, time away and caps come from the game (Brian L)"

export type Status = "Checking" | "Ready" | "Error"

export type LineupCar = {
	id: string,
	name: string,
	family: string,
	paint: Color3,
}

export type Data = {
	source: string,
	status: Status,
	earned: number?,
	awaySeconds: number?,
	cappedSeconds: number?,
	vip: boolean?,
	capSeconds: number?, -- the cap for a player without VIP (fixture)
	vipCapSeconds: number?, -- the cap with VIP (fixture)
	lineup: { LineupCar },
}

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

local CARS: { LineupCar } = {
	{ id = "puglet", name = "Puglet", family = "Compact", paint = rgb(40, 120, 232) },
	{ id = "waffle", name = "Citrine Waffle Van", family = "Van", paint = rgb(194, 24, 91) },
	{ id = "rangy", name = "Rangy", family = "Pickup", paint = rgb(232, 179, 58) },
	{ id = "rev6", name = "Revolution 6", family = "Sedan", paint = rgb(30, 86, 200) },
}

local HOUR = 3600

local function data(status: Status, earned: number?, away: number?, capped: number?, vip: boolean?, cars: number): Data
	local lineup: { LineupCar } = {}
	for i = 1, math.min(cars, #CARS) do
		table.insert(lineup, table.clone(CARS[i]))
	end
	return {
		source = WelcomeFixtures.Source,
		status = status,
		earned = earned,
		awaySeconds = away,
		cappedSeconds = capped,
		vip = vip,
		capSeconds = 8 * HOUR, -- the outline's default, tunable
		vipCapSeconds = 12 * HOUR,
		lineup = lineup,
	}
end

local presets: { [string]: () -> Data } = {
	Typical = function(): Data
		return data("Ready", 1240, 2 * HOUR, nil, false, 3)
	end,
	Small = function(): Data
		return data("Ready", 12, 20 * 60, nil, false, 3)
	end,
	Huge = function(): Data
		return data("Ready", 3400000000, 11 * HOUR, nil, true, 3)
	end,
	-- 18 hours away but only 12 hours paid (a VIP cap)
	CappedVip = function(): Data
		return data("Ready", 18400, 18 * HOUR, 12 * HOUR, true, 3)
	end,
	-- 52 hours away, paid for the non-VIP cap of 6 hours
	LongAwayNonVip = function(): Data
		return data("Ready", 5200, 52 * HOUR, 6 * HOUR, false, 3)
	end,
	-- a verified zero: the card is suppressed, not shown as "$0 earned"
	Zero = function(): Data
		return data("Ready", 0, 5 * 60, nil, false, 3)
	end,
	-- nothing known yet: a neutral waiting state, never $0
	Checking = function(): Data
		return data("Checking", nil, nil, nil, nil, 3)
	end,
	Error = function(): Data
		return data("Error", nil, nil, nil, nil, 3)
	end,
	-- the Raceway has no cars on it (the lap is empty; the amount still shows)
	NoCars = function(): Data
		return data("Ready", 640, HOUR, nil, false, 0)
	end,
	-- VIP status not known: the cap note is hidden rather than guessed
	VipUnknown = function(): Data
		return data("Ready", 1240, 2 * HOUR, nil, nil, 3)
	end,
}

WelcomeFixtures.PresetNames = table.freeze({
	"Typical",
	"Small",
	"Huge",
	"CappedVip",
	"LongAwayNonVip",
	"Zero",
	"Checking",
	"Error",
	"NoCars",
	"VipUnknown",
})

function WelcomeFixtures.preset(name: string): Data?
	local make = presets[name]
	if not make then
		return nil
	end
	return make()
end

-- "45m", "2h", "2h 30m", "1d 4h": whole units only, never a fake precision.
function WelcomeFixtures.span(seconds: number): string
	local s = math.max(0, math.floor(seconds))
	if s < HOUR then
		return string.format("%dm", math.max(1, s // 60))
	end
	local hours = s // HOUR
	local minutes = (s % HOUR) // 60
	if hours < 24 then
		if hours < 10 and minutes > 0 then
			return string.format("%dh %dm", hours, minutes)
		end
		return string.format("%dh", hours)
	end
	local days = hours // 24
	local rest = hours % 24
	if rest > 0 then
		return string.format("%dd %dh", days, rest)
	end
	return string.format("%dd", days)
end

-- "Away 18h · Earned for 12h" when the paid time is shorter than the time away, otherwise "Away 2h"; nil when the time
-- away is unknown. The two times are shown separately: the card never implies payment for all of the time away.
function WelcomeFixtures.timeLine(d: Data): string?
	local away = d.awaySeconds
	if away == nil or away ~= away or away < 0 then
		return nil
	end
	local paid = d.cappedSeconds
	if paid ~= nil and paid == paid and paid >= 0 and paid < away then
		return string.format("Away %s · Earned for %s", WelcomeFixtures.span(away), WelcomeFixtures.span(paid))
	end
	return string.format("Away %s", WelcomeFixtures.span(away))
end

-- The small honest cap note: it states the current caps and never promises earnings for time already gone.
function WelcomeFixtures.capNote(d: Data): string?
	if d.vip == nil then
		return nil
	end
	local vipCap = d.vipCapSeconds
	local cap = d.capSeconds
	if d.vip then
		if vipCap == nil then
			return nil
		end
		return string.format("VIP: earns for up to %s while you are away.", WelcomeFixtures.span(vipCap))
	end
	if cap == nil or vipCap == nil then
		return nil
	end
	return string.format(
		"Offline earnings stop after %s. VIP earns for up to %s from now on.",
		WelcomeFixtures.span(cap),
		WelcomeFixtures.span(vipCap)
	)
end

-- THE QUEUE GATE (BRIEF M14-02): the card is offered at most once per join, only after the loading screen has gone, never during
-- the first-time tutorial, and never over another modal (a group pop-up, the shop, Results). The lead supplies the three
-- answers; the gate only decides. A new join is a new gate (or gate:reset()).
export type GateInputs = {
	isLoadingDone: () -> boolean, -- the loading screen has gone (the LocalPlayer attribute Lane3LoadingDone)
	isTutorialActive: () -> boolean,
	isModalOpen: () -> boolean,
}

export type Gate = {
	check: (self: Gate) -> (boolean, string),
	recordShown: (self: Gate) -> (),
	reset: (self: Gate) -> (),
}

function WelcomeFixtures.newGate(inputs: GateInputs): Gate
	local shown = false
	local gate: Gate
	gate = {
		check = function(_self: Gate): (boolean, string)
			if shown then
				return false, "AlreadyShown"
			elseif not inputs.isLoadingDone() then
				return false, "Loading"
			elseif inputs.isTutorialActive() then
				return false, "Tutorial"
			elseif inputs.isModalOpen() then
				return false, "ModalOpen"
			end
			return true, "Ok"
		end,
		recordShown = function(_self: Gate)
			shown = true
		end,
		reset = function(_self: Gate)
			shown = false
		end,
	}
	return gate
end

return WelcomeFixtures
