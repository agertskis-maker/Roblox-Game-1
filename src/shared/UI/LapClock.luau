--!strict
-- LapClock: the ONE schedule for Lap Pay on a Raceway (Round 5, L-02). Pure maths, shared by the server that pays and the
-- client that draws the lap, so the car crossing the line and the "+$" pop follow the same clock and a late network event
-- can never add a lap. Times are server times (workspace:GetServerTimeNow()); the plot carries the epoch and the lap length.
--
-- Slot s crosses the line at  epoch + offset(s) + k * lap  for every whole k. Offsets are spread by the golden ratio, so a
-- slot keeps its moment when cars are added, removed or swapped (no extra lap), and payouts never bunch up.
--
--   LapClock.offset(slot, lap) -> number           seconds after the epoch slot `slot` first crosses
--   LapClock.phase(now, epoch, slot, lap) -> number 0..1 along the lap (0 = on the line)
--   LapClock.nextDue(now, epoch, slot, lap) -> number the next crossing strictly after `now`
--   LapClock.selfTest() -> { string }

local LapClock = {}

local GOLDEN = 0.6180339887

function LapClock.offset(slot: number, lap: number): number
	return (((slot - 1) * GOLDEN) % 1) * lap
end

function LapClock.phase(now: number, epoch: number, slot: number, lap: number): number
	if lap <= 0 then
		return 0
	end
	return ((now - epoch - LapClock.offset(slot, lap)) / lap) % 1
end

function LapClock.nextDue(now: number, epoch: number, slot: number, lap: number): number
	local base = epoch + LapClock.offset(slot, lap)
	local k = math.floor((now - base) / lap) + 1
	return base + k * lap
end

function LapClock.selfTest(): { string }
	local failures: { string } = {}
	local function expect(name: string, ok: boolean)
		if not ok then
			table.insert(failures, name)
		end
	end
	expect("slot 1 starts on the line", LapClock.offset(1, 15) == 0)
	expect("slot 2 is spread", math.abs(LapClock.offset(2, 15) - 9.27) < 0.01)
	expect("phase 0 at a crossing", LapClock.phase(100 + 15 * 3, 100, 1, 15) < 1e-9)
	expect("half a lap", math.abs(LapClock.phase(107.5, 100, 1, 15) - 0.5) < 1e-9)
	expect("next due is strictly later", LapClock.nextDue(115, 100, 1, 15) == 130)
	expect("next due mid lap", LapClock.nextDue(101, 100, 1, 15) == 115)
	local seen = {}
	for slot = 1, 18 do
		local o = math.floor(LapClock.offset(slot, 15) * 100)
		expect("slot " .. slot .. " has its own moment", not seen[o])
		seen[o] = true
	end
	return failures
end

return LapClock
