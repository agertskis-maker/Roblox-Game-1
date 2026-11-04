--!strict
-- Two extra viewport profiles for the big round's supporting screens (M12 to M16): the cramped 667 x 375 landscape phone
-- and the 1024 x 768 tablet that the brief's evidence standard names beside the playground's own 844 x 390 phone and
-- 1920 x 1080 desktop. The playground's Screen module owns the profile table; this only adds two entries to it:
--
--   local SizeProfiles = require(Prototype.SupportFixtures.SizeProfiles)
--   SizeProfiles.register(Screen)            -- once, in the playground, before the screens are mounted
--   api.setProfile("Phone667")  /  api.setProfile("Tablet1024")
--
-- The insets and reserved touch zones follow Screen.luau's own assumptions (a landscape phone and a tablet); like every
-- profile they prove layout, clipping and hit-box sizes at that size, not a real device.

local SizeProfiles = {}

SizeProfiles.Names = table.freeze({ "Phone667", "Tablet1024" })

local function zonesFor(size: Vector2): { any }
	local short = math.min(size.X, size.Y)
	local jump = if short <= 500 then 70 else 120
	local jumpPos = if short <= 500
		then Vector2.new(size.X - 95, size.Y - 90)
		else Vector2.new(size.X - jump * 1.5, size.Y - jump * 1.75)
	return {
		{
			name = "Thumbstick",
			position = Vector2.new(0, size.Y * 0.55),
			size = Vector2.new(size.X * 0.4, size.Y * 0.45),
		},
		{ name = "Jump", position = jumpPos, size = Vector2.new(jump, jump) },
	}
end

-- Adds the two profiles to Screen.Profiles (Screen is the playground's Screen module). Safe to call twice.
function SizeProfiles.register(Screen: any)
	local profiles = Screen.Profiles
	local phone = Vector2.new(667, 375)
	profiles.Phone667 = {
		name = "Phone667",
		kind = "Phone",
		label = "Phone landscape 667 x 375",
		size = phone,
		insets = { top = 44, bottom = 21, left = 47, right = 47 },
		touch = true,
		zones = zonesFor(phone),
	}
	local tablet = Vector2.new(1024, 768)
	profiles.Tablet1024 = {
		name = "Tablet1024",
		kind = "Tablet",
		label = "Tablet 1024 x 768",
		size = tablet,
		insets = { top = 58, bottom = 20, left = 0, right = 0 },
		touch = true,
		zones = zonesFor(tablet),
	}
end

return SizeProfiles
