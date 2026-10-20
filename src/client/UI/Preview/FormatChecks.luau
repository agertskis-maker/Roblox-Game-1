--!strict
-- DEVELOPMENT CHECKS ONLY (Lane 3). Focused tests for Format.cash and
-- Format.distance. Nothing calls this in the game; run it from Studio:
--   require(<Client>.UI.Preview.FormatChecks).run()  -- returns pass count, total, failures

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Format = require(ReplicatedStorage.Shared.UI.Format)

local FormatChecks = {}

local CASES: { { fn: string, input: number, expected: string, why: string } } = {
	-- Requested examples
	{ fn = "cash", input = 950, expected = "$950", why = "example" },
	{ fn = "cash", input = 9999, expected = "$9,999", why = "example, last full number" },
	{ fn = "cash", input = 12400, expected = "$12.4K", why = "example" },
	{ fn = "cash", input = 116000, expected = "$116K", why = "example" },
	{ fn = "cash", input = 1200000, expected = "$1.2M", why = "example, trailing zero dropped" },
	{ fn = "cash", input = 3450000000, expected = "$3.45B", why = "example" },
	-- Zero and bad input
	{ fn = "cash", input = 0, expected = "$0", why = "zero" },
	{ fn = "cash", input = -5, expected = "$0", why = "negative shown as 0" },
	{ fn = "cash", input = 0 / 0, expected = "$0", why = "NaN shown as 0" },
	{ fn = "cash", input = 12.9, expected = "$12", why = "whole dollars, truncated" },
	-- 9,999 / 10,000 boundary
	{ fn = "cash", input = 10000, expected = "$10K", why = "first compact value" },
	{ fn = "cash", input = 10050, expected = "$10K", why = "truncated, not rounded" },
	{ fn = "cash", input = 12499, expected = "$12.4K", why = "truncated" },
	-- Values that would round into the next suffix
	{ fn = "cash", input = 999999, expected = "$999K", why = "never $1000K" },
	{ fn = "cash", input = 999999999, expected = "$999M", why = "never $1000M" },
	{ fn = "cash", input = 999999999999, expected = "$999B", why = "never $1000B" },
	{ fn = "cash", input = 1000000, expected = "$1M", why = "exact boundary" },
	{ fn = "cash", input = 1999999, expected = "$1.99M", why = "truncated" },
	{ fn = "cash", input = 1000000000, expected = "$1B", why = "exact boundary" },
	{ fn = "cash", input = 1e15, expected = "$1,000T", why = "beyond T" },
	-- Distance (unchanged rules)
	{ fn = "distance", input = 1240.7, expected = "1,240 m", why = "unchanged" },
	{ fn = "distance", input = 10000, expected = "10.0 km", why = "unchanged" },
	{ fn = "distance", input = 123456, expected = "123.4 km", why = "unchanged" },
}

function FormatChecks.run(): (number, number, { string })
	local passed = 0
	local failures = {}
	for _, case in CASES do
		local got = (Format :: any)[case.fn](case.input)
		if got == case.expected then
			passed += 1
		else
			table.insert(
				failures,
				string.format(
					"%s(%s) = %q, expected %q (%s)",
					case.fn,
					tostring(case.input),
					got,
					case.expected,
					case.why
				)
			)
		end
	end
	return passed, #CASES, failures
end

return FormatChecks
