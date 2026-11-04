--!strict
-- Boundary tests for Format.cash (Round 4, E-07). Run from the Studio command bar or the MCP:
--   print(require(game.ReplicatedStorage.Shared.UI.FormatTests).selfTest())
-- Returns the failures; an empty list means every case passed.

local Format = require(script.Parent.Format)

local FormatTests = {}

local CASHES: { { number | string } } = {
	{ 0, "$0" },
	{ 950, "$950" },
	{ 9999, "$9,999" },
	{ 9999.99, "$9,999" },
	{ 10000, "$10K" },
	{ 12499, "$12.4K" },
	{ 999999, "$999K" },
	{ 1000000, "$1M" },
	{ 1999999, "$1.99M" },
	{ 999999999, "$999M" },
	{ 1000000000, "$1B" },
	{ 999999999999, "$999B" },
	{ 1e12, "$1T" },
	{ 2e12, "$2T" },
	{ 999.99e12, "$999T" },
	{ 999999999999999, "$999T" },
	{ 1e15, "$1Qa" },
	{ 1.23e15, "$1.23Qa" },
	{ 1.239e15, "$1.23Qa" },
	{ 999e15, "$999Qa" },
	{ 1000e15, "$1,000Qa" },
	{ 0 / 0, "$0" },
	{ -5, "$0" },
	{ -1e15, "$0" },
	{ math.huge, "$0" },
}

-- Economy v1 values that Lane 3 screens draw at their biggest (E-08).
local ECONOMY: { { number | string } } = {
	{ 2e12, "$2T" }, -- Raceway level 12
	{ 265e6, "$265M" }, -- parking spot 15
	{ 5e6, "$5M" }, -- World 2 unlock
	{ 1e9, "$1B" }, -- World 3 unlock
	{ 25000 * 1000 * 250, "$6.25B" }, -- a Galaxy Legendary lap at Raceway level 12
}

function FormatTests.selfTest(): { string }
	local failures: { string } = {}
	local function run(cases: { { number | string } })
		for _, case in cases do
			local value = case[1] :: number
			local want = case[2] :: string
			local got = Format.cash(value)
			if got ~= want then
				table.insert(failures, string.format("cash(%s) = %s, want %s", tostring(value), got, want))
			end
		end
	end
	run(CASHES)
	run(ECONOMY)
	-- Either side of every suffix boundary stays in its own suffix (never rounds up into the next).
	for _, size in { 1e3, 1e6, 1e9, 1e12, 1e15 } do
		local below = Format.cash(size * 10 - 1)
		if below:find("1000", 1, true) then
			table.insert(failures, "rounded up below " .. tostring(size * 10) .. ": " .. below)
		end
	end
	return failures
end

return FormatTests
