--!strict
-- Display formatting for HUD numbers (Lane 3). Display only: these functions
-- never change the value they are given, and callers must keep the real value.
--
-- Rules:
--   Cash      below 10,000: "$950", "$9,999" (whole dollars, comma groups).
--             from 10,000:  at most three significant digits with a suffix
--             K, M, B or T: "$12.4K", "$116K", "$1.2M", "$3.45B". Trailing
--             decimal zeros are dropped ("$1M", not "$1.00M"). Digits are
--             truncated, never rounded up (the established contract), so the
--             display never shows more than the player has, and a value just
--             under a suffix boundary stays in the lower suffix: $999,999 shows
--             "$999K", never "$1000K" or "$1M". From 1,000T, whole trillions
--             with commas.
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
	{ size = 1e3, letter = "K" },
}

Format.CashCompactFrom = 10000

-- "1.20" -> "1.2", "1.00" -> "1", "10.0" -> "10".
local function trimZeros(text: string): string
	if text:find(".", 1, true) then
		text = text:gsub("0+$", "")
		text = text:gsub("%.$", "")
	end
	return text
end

-- Three significant digits of value / size, truncated, using whole-number
-- arithmetic so float error cannot drop a digit: 1,999,999 / 1e6 -> "1.99".
local function threeSignificant(value: number, size: number): string
	local hundredths = value // (size // 100)
	if hundredths >= 10000 then
		return string.format("%d", hundredths // 100)
	elseif hundredths >= 1000 then
		local tenths = hundredths // 10
		return trimZeros(string.format("%d.%d", tenths // 10, tenths % 10))
	end
	return trimZeros(string.format("%d.%02d", hundredths // 100, hundredths % 100))
end

function Format.cash(amount: number): string
	local value = math.floor(sanitize(amount))
	if value < Format.CashCompactFrom then
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
