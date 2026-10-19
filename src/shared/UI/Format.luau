--!strict
-- Display formatting for HUD numbers (Lane 3). Display only: these functions
-- never change the value they are given, and callers must keep the real value.
--
-- Rules:
--   Cash      below 1,000,000: "$12,480" (whole dollars, comma groups).
--             from 1,000,000:  three significant digits with a suffix,
--             "$1.23M", "$12.3M", "$123M", then B and T. Digits are truncated,
--             never rounded up, so the display never shows more than the
--             player has ($1,999,999 shows "$1.99M").
--   Distance  below 10,000 m: "1,240 m" (whole metres).
--             from 10,000 m:  kilometres, one decimal truncated below 1,000 km
--             ("12.4 km"), whole kilometres with commas after that
--             ("1,234 km").
--   Negative, NaN or infinite input is shown as 0.

local Format = {}

local function sanitize(value: number): number
	if value ~= value or value == math.huge or value == -math.huge or value < 0 then
		return 0
	end
	return value
end

-- 1234567 -> "1,234,567"
function Format.group(whole: number): string
	local digits = string.format("%d", math.floor(sanitize(whole)))
	local out = digits:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	if out:sub(1, 1) == "," then
		out = out:sub(2)
	end
	return out
end

local SUFFIXES = {
	{ size = 1e12, letter = "T" },
	{ size = 1e9, letter = "B" },
	{ size = 1e6, letter = "M" },
}

-- Three significant digits of value / size, truncated, using whole-number
-- arithmetic so float error cannot drop a digit: 1,999,999 / 1e6 -> "1.99".
local function threeSignificant(value: number, size: number): string
	local hundredths = value // (size // 100)
	if hundredths >= 10000 then
		return string.format("%d", hundredths // 100)
	elseif hundredths >= 1000 then
		local tenths = hundredths // 10
		return string.format("%d.%d", tenths // 10, tenths % 10)
	end
	return string.format("%d.%02d", hundredths // 100, hundredths % 100)
end

function Format.cash(amount: number): string
	local value = math.floor(sanitize(amount))
	if value < 1e6 then
		return "$" .. Format.group(value)
	end
	for _, suffix in SUFFIXES do
		if value >= suffix.size then
			if suffix.letter == "T" and value >= 1000 * suffix.size then
				return "$" .. Format.group(value // suffix.size) .. "T"
			end
			return "$" .. threeSignificant(value, suffix.size) .. suffix.letter
		end
	end
	return "$" .. Format.group(value)
end

-- Returns the number text and the unit separately so the HUD can keep the
-- unit in a fixed slot while the digits change.
function Format.distanceParts(metres: number): (string, string)
	local value = sanitize(metres)
	if value < 10000 then
		return Format.group(math.floor(value)), "m"
	end
	local tenthsOfKm = math.floor(value) // 100
	if tenthsOfKm < 10000 then
		return string.format("%d.%d", tenthsOfKm // 10, tenthsOfKm % 10), "km"
	end
	return Format.group(tenthsOfKm // 10), "km"
end

function Format.distance(metres: number): string
	local number, unit = Format.distanceParts(metres)
	return number .. " " .. unit
end

return table.freeze(Format)
