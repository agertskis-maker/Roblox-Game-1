--!strict
-- IconsFamily: the rest of ONE icon family (Lane 3, BRIEF M9-01..M9-03, 2026-11-01). Original art, drawn only from
-- Frames, UICorner, UIStroke, UIGradient and rotation with the SAME kit Icons2 already uses: a thick navy outline, a
-- darker lower-right lip, a top-to-bottom gradient measured over the whole group, one small highlight, light from the
-- top-left. Nothing is traced, uploaded or copied; no logo; no Robux symbol (BRIEF M10-10c: the word, never a drawn
-- or substituted symbol); no currency glyph on Cash art.
--
-- It is installed INTO Icons2 (Icons2.luau calls `Family.install(kit)` once at load), so every existing caller
-- (Arcade.icon, Style.header, Overlay.closeButton, the Home menu fallbacks, StuntMock, ResultsCard, PortalCardMock, ...)
-- picks the new art by name with no edit. Icons.draw forwards the same names to Icons2 (M9-03 aliasing). Names that
-- already had Icons2 art (Gift, Cart, GarageBook, Clipboard, CashStack, Car, CarCount, Flame, Bolt, KeyLock, Padlock,
-- CarJump, HopCar, Trophy, Star, Music, Track, Stamp, Warning, Event) are reused, not redrawn.
--
-- Every painter stays inside the frame budget (40 frames: group = 3 per shape, flat = 1, outlined ring = 3, plain
-- ring = 1, shine = 1, within = 1 + its content); the sheet (IconsSheet.luau) prints each icon's count so the budget
-- is visible, and the existing Specimen gallery checks it too.
--
-- The older flat icons the Settings panel and the Foot Dash draw by name (Speaker, Motion, Gamepad, Keyboard, Touch,
-- Sneaker) are redrawn here too, so the old Icons.luau painters are now only a fallback for a name the family lacks.

local Family = {}

-- The icon sheet's order (M9-05). Every name here must resolve through Icons2.has.
Family.Groups = {
	{
		title = "Menu",
		names = {
			"Shop",
			"Garage",
			"Index",
			"Missions",
			"Goals",
			"Settings",
			"Music",
			"Raceway",
			"Parking",
			"Trophy",
			"StuntCircuit",
			"Portal",
			"Lock",
			"Gift",
			"Group",
			"Close",
			"Back",
			"Plus",
			"Info",
			"New",
		},
	},
	{
		title = "Currency and stats",
		names = {
			"Cash",
			"CashPerSecond",
			"Bolt",
			"Flame",
			"Keys",
			"Key",
			"Distance",
			"Timer",
			"CarCount",
		},
	},
	{
		title = "Shop",
		names = {
			"StarterPack",
			"VipCrown",
			"DoubleLapPay",
			"Paddock",
			"PaintBucket",
			"Decal",
			"Wheel",
			"Bundle",
			"CashBag",
			"CashChest",
			"CashVault",
		},
	},
	{
		title = "Tutorial",
		names = {
			"Steer",
			"Hop",
			"HoldKey",
			"TooHot",
			"Home",
			"Park",
			"Earn",
			"Upgrade",
			"Ready",
			"Hand",
			"ArrowDown",
			"Check",
			"Flag",
			"Medal",
		},
	},
	{
		title = "Settings and controls",
		names = { "Speaker", "Motion", "Gamepad", "Keyboard", "Touch", "Sneaker" },
	},
	{
		title = "Rarities",
		names = {
			"Rarity_Common",
			"Rarity_Uncommon",
			"Rarity_Rare",
			"Rarity_Epic",
			"Rarity_Legendary",
		},
	},
}

export type Kit = { [string]: any }

function Family.install(kit: Kit)
	local rect, circle, bar = kit.rect, kit.circle, kit.bar
	local group, flat, shine, ring, within = kit.group, kit.flat, kit.shine, kit.ring, kit.within
	local lighten, darken = kit.lighten, kit.darken
	local painters = kit.painters
	local c = kit.colors
	local INK, WHITE = kit.INK, kit.WHITE

	local function reg(name: string, default: Color3?, tilt: number?, painter: (pen: any) -> ())
		kit.register(name, painter, default, tilt)
	end

	-- A four-point glint as two flat bars (never larger than a quarter of the icon).
	local function glint(x: number, y: number, s: number, colour: Color3): { any }
		return { bar(x - s, y, x + s, y, s * 0.36, colour), bar(x, y - s, x, y + s, s * 0.36, colour) }
	end

	-- MENU ---------------------------------------------------------------------------------------------------------

	-- Shop: a market bag with a round handle, a deep band and a gold seal (not a Robux symbol).
	reg("Shop", c.GIFT_RED, -8, function(pen)
		ring(pen, 0.5, 0.3, 0.4, 0.42, 0.07, c.SILVER)
		group(pen, { rect(0.5, 0.64, 0.8, 0.56, 0.1) })
		group(pen, { rect(0.5, 0.4, 0.88, 0.13, 0.04, darken(pen.main, 0.2)) })
		flat(pen, { circle(0.5, 0.66, 0.26, c.GOLD), circle(0.5, 0.66, 0.16, lighten(c.GOLD, 0.5)) })
		shine(pen, 0.26, 0.55, 0.05, 0.16, 10)
	end)

	-- Garage: a cream building, a red roof, a rolled-up door with a small car parked inside.
	reg("Garage", c.PAGE, -4, function(pen)
		group(pen, { rect(0.5, 0.64, 0.8, 0.5, 0.05) })
		group(pen, { rect(0.5, 0.36, 0.92, 0.2, 0.06, c.GIFT_RED), rect(0.5, 0.25, 0.62, 0.14, 0.05, c.GIFT_RED) })
		flat(pen, {
			rect(0.5, 0.7, 0.5, 0.36, 0.03, c.ASPHALT),
			rect(0.5, 0.58, 0.5, 0.04, 0, lighten(c.ASPHALT, 0.3)),
			rect(0.5, 0.66, 0.5, 0.04, 0, lighten(c.ASPHALT, 0.3)),
			rect(0.5, 0.78, 0.32, 0.1, -1, c.CAR_CYAN),
			circle(0.42, 0.84, 0.07, INK),
			circle(0.58, 0.84, 0.07, INK),
		})
		shine(pen, 0.2, 0.34, 0.07, 0.03)
	end)

	kit.alias("Index", "GarageBook")
	kit.alias("Missions", "Clipboard")

	-- Goals: a target with an arrow in the middle ring.
	reg("Goals", WHITE, -6, function(pen)
		group(pen, { circle(0.46, 0.54, 0.8) })
		flat(pen, {
			circle(0.46, 0.54, 0.6, c.GIFT_RED),
			circle(0.46, 0.54, 0.4, WHITE),
			circle(0.46, 0.54, 0.2, c.GIFT_RED),
		})
		group(pen, { bar(0.46, 0.54, 0.84, 0.16, 0.09, c.GOLD) })
		flat(pen, { bar(0.8, 0.2, 0.93, 0.19, 0.07, c.STAMP_RED), bar(0.8, 0.2, 0.81, 0.07, 0.07, c.STAMP_RED) })
		shine(pen, 0.24, 0.3, 0.1, 0.04, -40)
	end)

	-- Settings: an eight-tooth steel gear with a dark open centre.
	reg("Settings", c.GEAR, 0, function(pen)
		local specs = { circle(0.5, 0.5, 0.64) }
		for _, a in { 0, 45, 90, 135 } do
			table.insert(specs, rect(0.5, 0.5, 0.92, 0.2, 0.04, nil, a))
		end
		group(pen, specs)
		flat(pen, { circle(0.5, 0.5, 0.3, darken(pen.main, 0.55)), circle(0.5, 0.5, 0.2, INK) })
		shine(pen, 0.34, 0.3, 0.12, 0.04, -35)
	end)

	-- Raceway: the oval track with a green infield and a small car on the finish straight.
	reg("Raceway", c.ASPHALT, -6, function(pen)
		flat(pen, { rect(0.5, 0.52, 0.68, 0.4, -1, c.GRASS) })
		ring(pen, 0.5, 0.52, 0.94, 0.7, 0.13)
		flat(pen, { rect(0.5, 0.235, 0.1, 0.03, -1, WHITE), rect(0.095, 0.52, 0.03, 0.1, -1, WHITE) })
		within(pen, 0.5, 0.8, 0.36, 0, "Car", function()
			kit.carShape(pen, c.CAR_CYAN, false)
		end)
	end)

	-- Parking: a bold blue sign with a white P.
	reg("Parking", c.SIGN_BLUE, -4, function(pen)
		group(pen, { rect(0.5, 0.5, 0.84, 0.84, 0.16) })
		flat(pen, { bar(0.38, 0.26, 0.38, 0.76, 0.12, WHITE) })
		ring(pen, 0.52, 0.4, 0.34, 0.34, 0.1, WHITE, false)
		shine(pen, 0.26, 0.24, 0.1, 0.04, -40)
	end)

	kit.alias("Leaderboard", "Trophy")

	-- StuntCircuit: a launch ramp and a car in the air with a dotted arc behind it.
	reg("StuntCircuit", c.EVENT_ORANGE, -4, function(pen)
		group(pen, { rect(0.42, 0.84, 0.74, 0.16, 0.04, nil, -20) })
		group(pen, { rect(0.2, 0.9, 0.3, 0.12, 0.03, darken(pen.main, 0.2)) })
		flat(
			pen,
			{ circle(0.16, 0.62, 0.06, c.GOLD), circle(0.26, 0.46, 0.06, c.GOLD), circle(0.4, 0.34, 0.06, c.GOLD) }
		)
		within(pen, 0.66, 0.4, 0.6, -22, "Car", function()
			kit.carShape(pen, c.CAR_CYAN, true)
		end)
	end)

	-- Portal: a violet ring around a glowing swirl.
	reg("Portal", c.PORTAL, 0, function(pen)
		ring(pen, 0.5, 0.5, 0.74, 0.94, 0.13)
		flat(pen, { rect(0.5, 0.5, 0.46, 0.7, -1, lighten(pen.main, 0.55)), rect(0.5, 0.5, 0.3, 0.5, -1, WHITE) })
		flat(pen, {
			bar(0.4, 0.4, 0.58, 0.42, 0.06, pen.main),
			bar(0.58, 0.42, 0.6, 0.58, 0.06, pen.main),
			bar(0.6, 0.58, 0.42, 0.6, 0.06, pen.main),
		})
		shine(pen, 0.25, 0.3, 0.04, 0.16, 12)
	end)

	kit.alias("Lock", "Padlock")

	-- Group: three heads and shoulders, the middle one in front.
	reg("Group", c.CAR_CYAN, 0, function(pen)
		local function person(x: number, headY: number, bodyY: number, scale: number, colour: Color3)
			group(pen, { circle(x, headY, 0.22 * scale, c.PAGE) })
			group(pen, { rect(x, bodyY, 0.34 * scale, 0.34 * scale, 0.16, colour) })
		end
		person(0.2, 0.36, 0.72, 0.84, c.EVENT_ORANGE)
		person(0.8, 0.36, 0.72, 0.84, c.TICK_GREEN)
		person(0.5, 0.3, 0.7, 1.1, pen.main)
		shine(pen, 0.4, 0.62, 0.1, 0.04, -20)
	end)

	-- Close: a bold rounded X (white; it sits on the red button).
	reg("Close", WHITE, 0, function(pen)
		group(pen, { bar(0.26, 0.26, 0.74, 0.74, 0.2), bar(0.74, 0.26, 0.26, 0.74, 0.2) })
		shine(pen, 0.33, 0.28, 0.06, 0.03, 45)
	end)

	-- Back: a chunky left arrow.
	reg("Back", WHITE, 0, function(pen)
		group(pen, {
			bar(0.8, 0.5, 0.26, 0.5, 0.18),
			bar(0.26, 0.5, 0.52, 0.24, 0.18),
			bar(0.26, 0.5, 0.52, 0.76, 0.18),
		})
		shine(pen, 0.5, 0.43, 0.14, 0.035)
	end)

	-- Plus: a bold white plus (the Cash counter's "+" sits on a green button).
	reg("Plus", WHITE, 0, function(pen)
		group(pen, { bar(0.2, 0.5, 0.8, 0.5, 0.22), bar(0.5, 0.2, 0.5, 0.8, 0.22) })
		shine(pen, 0.3, 0.43, 0.1, 0.035)
	end)

	-- Info: a blue disc with a white i.
	reg("Info", c.SIGN_BLUE, -6, function(pen)
		group(pen, { circle(0.5, 0.5, 0.86) })
		flat(pen, { circle(0.5, 0.27, 0.12, WHITE), bar(0.5, 0.45, 0.5, 0.74, 0.13, WHITE) })
		shine(pen, 0.3, 0.3, 0.1, 0.04, -40)
	end)

	-- New: a red badge with a white exclamation mark (a real earned "!" only; the caller decides when).
	reg("New", c.GIFT_RED, -8, function(pen)
		group(pen, { circle(0.5, 0.5, 0.86) })
		flat(pen, { bar(0.5, 0.24, 0.5, 0.56, 0.15, WHITE), circle(0.5, 0.74, 0.16, WHITE) })
		shine(pen, 0.3, 0.3, 0.1, 0.04, -40)
	end)

	-- CURRENCY AND STATS -------------------------------------------------------------------------------------------

	kit.alias("Cash", "CashStack")
	kit.alias("Coin", "CashStack")

	-- CashPerSecond: the cash stack with a small stopwatch (the rate per second).
	reg("CashPerSecond", c.BILL, -6, function(pen)
		within(pen, 0.4, 0.42, 0.8, 0, "Cash", function()
			painters.CashStack(pen)
		end)
		group(pen, { circle(0.76, 0.74, 0.42, WHITE), rect(0.76, 0.51, 0.1, 0.06, 0.02, c.SILVER) })
		flat(pen, { bar(0.76, 0.74, 0.76, 0.6, 0.05, INK), bar(0.76, 0.74, 0.86, 0.8, 0.05, INK) })
	end)

	-- Key: a gold key with a round bow and two teeth.
	local function keyArt(pen: any)
		ring(pen, 0.3, 0.3, 0.44, 0.44, 0.11)
		group(pen, {
			bar(0.44, 0.44, 0.82, 0.82, 0.15),
			bar(0.68, 0.68, 0.78, 0.58, 0.12),
			bar(0.56, 0.56, 0.64, 0.48, 0.1),
		})
		shine(pen, 0.24, 0.2, 0.08, 0.04, -30)
	end
	reg("Key", c.GOLD, -8, keyArt)

	-- Keys: two keys crossed (the stat; the single Key above is the capture's key).
	reg("Keys", c.GOLD, 0, function(pen)
		local main = pen.main
		pen.main = darken(main, 0.22)
		within(pen, 0.45, 0.5, 0.88, -14, "KeyBack", function()
			keyArt(pen)
		end)
		pen.main = main
		within(pen, 0.55, 0.5, 0.88, 16, "KeyFront", function()
			keyArt(pen)
		end)
	end)

	-- Distance: a red map pin standing on a short dashed road.
	reg("Distance", c.GIFT_RED, -4, function(pen)
		flat(pen, {
			rect(0.5, 0.88, 0.7, 0.1, -1, c.ASPHALT),
			rect(0.32, 0.88, 0.1, 0.025, -1, WHITE),
			rect(0.5, 0.88, 0.1, 0.025, -1, WHITE),
			rect(0.68, 0.88, 0.1, 0.025, -1, WHITE),
		})
		group(pen, { circle(0.5, 0.36, 0.5), rect(0.5, 0.56, 0.3, 0.3, 0.04, nil, 45) })
		flat(pen, { circle(0.5, 0.36, 0.2, WHITE) })
		shine(pen, 0.36, 0.26, 0.08, 0.04, -40)
	end)

	-- Timer: an orange stopwatch with a crown button and two hands.
	reg("Timer", c.EVENT_ORANGE, -6, function(pen)
		group(pen, {
			circle(0.5, 0.58, 0.74),
			rect(0.5, 0.15, 0.2, 0.09, 0.03),
			rect(0.8, 0.27, 0.1, 0.08, 0.02, nil, 42),
		})
		flat(pen, {
			circle(0.5, 0.58, 0.54, c.PAGE),
			bar(0.5, 0.58, 0.5, 0.4, 0.06, INK),
			bar(0.5, 0.58, 0.63, 0.66, 0.06, INK),
			circle(0.5, 0.58, 0.08, pen.main),
		})
		shine(pen, 0.26, 0.42, 0.05, 0.13, 30)
	end)

	-- SHOP ---------------------------------------------------------------------------------------------------------

	-- StarterPack: a green present with a gold ribbon and bow, two glints.
	reg("StarterPack", c.TICK_GREEN, -8, function(pen)
		group(pen, { rect(0.5, 0.66, 0.74, 0.46, 0.06) })
		group(pen, { rect(0.5, 0.64, 0.14, 0.46, 0, c.GOLD) })
		group(pen, { rect(0.5, 0.44, 0.84, 0.18, 0.05) })
		group(pen, { rect(0.5, 0.44, 0.15, 0.18, 0, c.GOLD) })
		group(pen, {
			rect(0.38, 0.28, 0.26, 0.15, -1, c.GOLD, 28),
			rect(0.62, 0.28, 0.26, 0.15, -1, c.GOLD, -28),
			circle(0.5, 0.31, 0.13, c.GOLD),
		})
		flat(pen, glint(0.86, 0.12, 0.08, WHITE))
		shine(pen, 0.26, 0.6, 0.05, 0.16)
	end)

	-- VipCrown: a gold crown, three jewels and three pearls.
	reg("VipCrown", c.GOLD, -6, function(pen)
		group(pen, {
			rect(0.24, 0.4, 0.2, 0.2, 0.03, nil, 45),
			rect(0.5, 0.3, 0.24, 0.24, 0.03, nil, 45),
			rect(0.76, 0.4, 0.2, 0.2, 0.03, nil, 45),
			rect(0.5, 0.54, 0.62, 0.3, 0.02),
			rect(0.5, 0.7, 0.76, 0.2, 0.04),
		})
		flat(pen, {
			circle(0.32, 0.7, 0.1, c.GIFT_RED),
			circle(0.5, 0.7, 0.1, c.CAR_CYAN),
			circle(0.68, 0.7, 0.1, c.TICK_GREEN),
			circle(0.12, 0.3, 0.07, WHITE),
			circle(0.5, 0.14, 0.07, WHITE),
			circle(0.88, 0.3, 0.07, WHITE),
		})
		shine(pen, 0.3, 0.52, 0.04, 0.12, 12)
	end)

	-- The gold coin with a rim and a hub (a wheel hub, not a currency symbol).
	local function coinGold(pen: any)
		group(pen, { circle(0.5, 0.5, 0.86) })
		ring(pen, 0.5, 0.5, 0.64, 0.64, 0.05, darken(pen.main, 0.22), false)
		flat(pen, { circle(0.5, 0.5, 0.26, darken(pen.main, 0.18)), circle(0.5, 0.5, 0.18, lighten(pen.main, 0.3)) })
		shine(pen, 0.3, 0.28, 0.1, 0.045, -40)
	end

	-- DoubleLapPay: a gold coin with a red badge that reads 2x.
	reg("DoubleLapPay", c.GOLD, -6, function(pen)
		within(pen, 0.42, 0.56, 0.84, 0, "Coin", function()
			coinGold(pen)
		end)
		group(pen, { circle(0.74, 0.28, 0.46, c.GIFT_RED) })
		local cx, cy = 0.73, 0.28
		flat(pen, {
			bar(cx - 0.1, cy - 0.07, cx - 0.05, cy - 0.11, 0.045, WHITE),
			bar(cx - 0.05, cy - 0.11, cx, cy - 0.07, 0.045, WHITE),
			bar(cx, cy - 0.07, cx - 0.1, cy + 0.1, 0.045, WHITE),
			bar(cx - 0.1, cy + 0.1, cx + 0.01, cy + 0.1, 0.045, WHITE),
			bar(cx + 0.06, cy - 0.03, cx + 0.14, cy + 0.08, 0.04, WHITE),
			bar(cx + 0.14, cy - 0.03, cx + 0.06, cy + 0.08, 0.04, WHITE),
		})
	end)

	-- Paddock: the parking sign with a green plus (extra spots).
	reg("Paddock", c.SIGN_BLUE, -4, function(pen)
		within(pen, 0.42, 0.46, 0.84, 0, "Sign", function()
			painters.Parking(pen)
		end)
		group(pen, { circle(0.8, 0.8, 0.36, c.TICK_GREEN) })
		flat(pen, { rect(0.8, 0.8, 0.2, 0.07, -1, WHITE), rect(0.8, 0.8, 0.07, 0.2, -1, WHITE) })
	end)

	-- PaintBucket: a steel bucket with a pink top, a band and a drip.
	reg("PaintBucket", c.SILVER, -6, function(pen)
		ring(pen, 0.5, 0.34, 0.7, 0.56, 0.05)
		group(pen, { rect(0.5, 0.6, 0.64, 0.5, 0.07) })
		flat(pen, {
			rect(0.5, 0.37, 0.64, 0.14, -1, c.NOTE_PINK),
			rect(0.5, 0.64, 0.64, 0.14, 0, c.NOTE_PINK),
			bar(0.74, 0.42, 0.74, 0.66, 0.09, c.NOTE_PINK),
			circle(0.74, 0.69, 0.11, c.NOTE_PINK),
		})
		shine(pen, 0.3, 0.56, 0.05, 0.14)
	end)

	-- Decal: a violet sticker with a gold star and a curled corner.
	reg("Decal", c.BOARD_VIOLET, -8, function(pen)
		group(pen, { rect(0.46, 0.48, 0.78, 0.78, 0.14) })
		flat(pen, { rect(0.46, 0.48, 0.64, 0.64, 0.1, lighten(pen.main, 0.18)) })
		local saved = pen.main
		pen.main = c.GOLD
		within(pen, 0.44, 0.46, 0.46, 0, "Star", function()
			painters.Star(pen)
		end)
		pen.main = saved
		group(pen, { rect(0.8, 0.8, 0.26, 0.26, 0.04, c.PAGE, 45) })
	end)

	-- Wheel: a dark tyre, a silver rim, five spokes and a hub.
	reg("Wheel", c.TYRE, 0, function(pen)
		group(pen, { circle(0.5, 0.5, 0.88) })
		ring(pen, 0.5, 0.5, 0.58, 0.58, 0.1, c.SILVER, false)
		local spokes = {}
		for k = 0, 4 do
			local a = math.rad(-90 + 72 * k)
			table.insert(spokes, bar(0.5, 0.5, 0.5 + 0.22 * math.cos(a), 0.5 + 0.22 * math.sin(a), 0.07, c.SILVER))
		end
		flat(pen, spokes)
		flat(pen, { circle(0.5, 0.5, 0.16, lighten(c.SILVER, 0.3)), circle(0.5, 0.5, 0.07, INK) })
		shine(pen, 0.26, 0.28, 0.1, 0.04, -40)
	end)

	-- Bundle: three boxes (blue, green, a big red one with a gold bow in front).
	reg("Bundle", c.GIFT_RED, -6, function(pen)
		local function box(x: number, y: number, w: number, h: number, colour: Color3)
			group(pen, { rect(x, y, w, h, 0.05, colour) })
			flat(pen, { rect(x, y, w * 0.18, h, 0, c.GOLD) })
		end
		box(0.27, 0.46, 0.34, 0.3, c.CAR_CYAN)
		box(0.74, 0.42, 0.32, 0.28, c.TICK_GREEN)
		box(0.5, 0.7, 0.6, 0.42, pen.main)
		group(pen, {
			rect(0.4, 0.46, 0.18, 0.1, -1, c.GOLD, 28),
			rect(0.6, 0.46, 0.18, 0.1, -1, c.GOLD, -28),
			circle(0.5, 0.48, 0.09, c.GOLD),
		})
		shine(pen, 0.27, 0.64, 0.05, 0.14)
	end)

	-- CashBag: a tan sack tied with gold and a green label.
	reg("CashBag", c.SACK, -6, function(pen)
		group(pen, { circle(0.5, 0.64, 0.7), rect(0.5, 0.34, 0.26, 0.24, 0.06) })
		flat(pen, {
			rect(0.5, 0.44, 0.36, 0.07, -1, c.GOLD),
			circle(0.5, 0.67, 0.3, c.BILL),
			circle(0.5, 0.67, 0.18, lighten(c.BILL, 0.4)),
		})
		shine(pen, 0.3, 0.56, 0.05, 0.14, 12)
	end)

	-- CashChest: a wooden chest with gold bands, a lock and bills peeking out of the lid.
	reg("CashChest", c.WOOD_BROWN, -4, function(pen)
		flat(pen, {
			rect(0.38, 0.2, 0.28, 0.14, 0.02, c.BILL, -14),
			rect(0.62, 0.19, 0.28, 0.14, 0.02, lighten(c.BILL, 0.2), 12),
		})
		group(pen, { rect(0.5, 0.68, 0.8, 0.4, 0.05) })
		group(pen, { rect(0.5, 0.42, 0.8, 0.3, 0.12) })
		flat(pen, {
			rect(0.24, 0.56, 0.07, 0.6, 0, c.GOLD),
			rect(0.76, 0.56, 0.07, 0.6, 0, c.GOLD),
			circle(0.5, 0.56, 0.17, c.GOLD),
			circle(0.5, 0.55, 0.06, INK),
		})
		shine(pen, 0.3, 0.36, 0.1, 0.04, -12)
	end)

	-- CashVault: a steel safe door with a gold dial and four bolts.
	reg("CashVault", c.STEEL, 0, function(pen)
		group(pen, { rect(0.5, 0.5, 0.86, 0.86, 0.1) })
		flat(pen, {
			circle(0.5, 0.5, 0.62, darken(pen.main, 0.3)),
			circle(0.5, 0.5, 0.52, lighten(pen.main, 0.2)),
			circle(0.5, 0.5, 0.26, c.GOLD),
			bar(0.5, 0.5, 0.5, 0.3, 0.06, INK),
			bar(0.5, 0.5, 0.68, 0.58, 0.06, INK),
			circle(0.16, 0.16, 0.06, darken(pen.main, 0.35)),
			circle(0.84, 0.16, 0.06, darken(pen.main, 0.35)),
			circle(0.16, 0.84, 0.06, darken(pen.main, 0.35)),
			circle(0.84, 0.84, 0.06, darken(pen.main, 0.35)),
		})
		shine(pen, 0.3, 0.3, 0.12, 0.04, -40)
	end)

	-- TUTORIAL -----------------------------------------------------------------------------------------------------

	-- Steer: a steering wheel with three spokes and a hub.
	reg("Steer", c.SILVER, -8, function(pen)
		ring(pen, 0.5, 0.5, 0.9, 0.9, 0.12)
		group(pen, {
			bar(0.16, 0.5, 0.84, 0.5, 0.1),
			bar(0.5, 0.5, 0.5, 0.84, 0.1),
			circle(0.5, 0.5, 0.26),
		})
		flat(pen, { circle(0.5, 0.5, 0.1, INK) })
		shine(pen, 0.26, 0.24, 0.1, 0.04, -40)
	end)

	kit.alias("Hop", "CarJump")

	-- HoldKey: a key cap with a down arrow (press and hold).
	reg("HoldKey", WHITE, -6, function(pen)
		group(pen, { rect(0.5, 0.6, 0.84, 0.66, 0.16, darken(pen.main, 0.18)) })
		group(pen, { rect(0.5, 0.48, 0.64, 0.46, 0.12) })
		flat(pen, {
			bar(0.5, 0.34, 0.5, 0.58, 0.1, INK),
			bar(0.5, 0.6, 0.4, 0.5, 0.09, INK),
			bar(0.5, 0.6, 0.6, 0.5, 0.09, INK),
		})
		shine(pen, 0.34, 0.3, 0.1, 0.04, -20)
	end)

	-- TooHot: the Heat flame with a red exclamation disc.
	reg("TooHot", c.FLAME, -4, function(pen)
		within(pen, 0.45, 0.46, 0.9, 0, "Flame", function()
			painters.Flame(pen)
		end)
		group(pen, { circle(0.8, 0.78, 0.34, c.STAMP_RED) })
		flat(pen, { bar(0.8, 0.68, 0.8, 0.8, 0.07, WHITE), circle(0.8, 0.88, 0.07, WHITE) })
	end)

	-- Home: a cream house with a red roof, a wooden door and two windows.
	reg("Home", c.PAGE, -4, function(pen)
		group(pen, { rect(0.72, 0.2, 0.1, 0.2, 0.01, c.BRICK) })
		group(pen, { rect(0.5, 0.34, 0.5, 0.5, 0.05, c.GIFT_RED, 45) })
		group(pen, { rect(0.5, 0.67, 0.64, 0.4, 0.04) })
		flat(pen, {
			rect(0.5, 0.74, 0.16, 0.24, 0.03, c.WOOD_BROWN),
			rect(0.3, 0.64, 0.1, 0.1, 0.01, c.GLASS),
			rect(0.7, 0.64, 0.1, 0.1, 0.01, c.GLASS),
		})
		shine(pen, 0.26, 0.46, 0.04, 0.1, 40)
	end)

	kit.alias("Park", "Parking")

	-- Earn: the cash stack with a green arrow rising.
	reg("Earn", c.BILL, -4, function(pen)
		within(pen, 0.4, 0.6, 0.8, 0, "Cash", function()
			painters.CashStack(pen)
		end)
		group(pen, {
			bar(0.78, 0.5, 0.78, 0.14, 0.14, c.TICK_GREEN),
			bar(0.78, 0.14, 0.62, 0.3, 0.12, c.TICK_GREEN),
			bar(0.78, 0.14, 0.94, 0.3, 0.12, c.TICK_GREEN),
		})
	end)

	-- Upgrade: a fat green up arrow with two glints.
	reg("Upgrade", c.TICK_GREEN, 0, function(pen)
		group(pen, {
			bar(0.5, 0.84, 0.5, 0.42, 0.28),
			bar(0.5, 0.14, 0.2, 0.46, 0.22),
			bar(0.5, 0.14, 0.8, 0.46, 0.22),
		})
		flat(pen, glint(0.14, 0.2, 0.07, WHITE))
		shine(pen, 0.4, 0.62, 0.05, 0.16)
	end)

	kit.alias("Ready", "Trophy")

	-- Hand: a white glove with the index finger up (the tutorial's pointer; rotate the holder to aim it).
	reg("Hand", WHITE, 0, function(pen)
		group(pen, {
			bar(0.4, 0.16, 0.4, 0.52, 0.2),
			rect(0.54, 0.7, 0.62, 0.4, 0.16),
			circle(0.56, 0.52, 0.2),
			circle(0.68, 0.55, 0.2),
			circle(0.78, 0.6, 0.18),
			bar(0.22, 0.62, 0.3, 0.72, 0.16),
		})
		group(pen, { rect(0.54, 0.9, 0.5, 0.12, 0.03, c.STAMP_RED) })
		shine(pen, 0.34, 0.2, 0.04, 0.14)
	end)

	-- ArrowDown: a bold gold arrow pointing down (the bouncing marker).
	reg("ArrowDown", c.GOLD, 0, function(pen)
		group(pen, {
			bar(0.5, 0.12, 0.5, 0.52, 0.28),
			bar(0.5, 0.9, 0.18, 0.52, 0.24),
			bar(0.5, 0.9, 0.82, 0.52, 0.24),
		})
		shine(pen, 0.42, 0.22, 0.05, 0.16)
	end)

	-- Check: a chunky tick.
	reg("Check", WHITE, 0, function(pen)
		group(pen, { bar(0.2, 0.54, 0.42, 0.76, 0.2), bar(0.42, 0.76, 0.82, 0.3, 0.2) })
		shine(pen, 0.3, 0.55, 0.05, 0.03, 45)
	end)

	-- Flag: a chequered flag on a silver pole.
	reg("Flag", WHITE, -6, function(pen)
		group(pen, { bar(0.2, 0.14, 0.2, 0.9, 0.09, c.SILVER) })
		group(pen, { rect(0.56, 0.34, 0.66, 0.44, 0.03) })
		local cw, ch = 0.66 / 3, 0.44 / 2
		local cells = {}
		for _, cell in { { 0, 0 }, { 2, 0 }, { 1, 1 } } do
			table.insert(cells, rect(0.23 + (cell[1] + 0.5) * cw, 0.12 + (cell[2] + 0.5) * ch, cw, ch, 0, INK))
		end
		flat(pen, cells)
	end)

	-- Medal: a gold disc on a V of ribbon.
	reg("Medal", c.GOLD, -6, function(pen)
		group(pen, {
			bar(0.3, 0.06, 0.44, 0.5, 0.18, c.CAR_CYAN),
			bar(0.7, 0.06, 0.56, 0.5, 0.18, c.CAR_CYAN_DEEP),
		})
		group(pen, { circle(0.5, 0.66, 0.56) })
		ring(pen, 0.5, 0.66, 0.38, 0.38, 0.05, darken(pen.main, 0.22), false)
		flat(pen, { circle(0.5, 0.66, 0.12, darken(pen.main, 0.2)) })
		shine(pen, 0.34, 0.54, 0.08, 0.04, -40)
	end)

	-- SETTINGS AND CONTROLS: the older flat icons the Settings panel and the Foot Dash draw by name, redrawn in the family so
	-- no screen keeps the old look (Icons.draw forwards these names here too).

	-- Speaker: a cyan speaker with two white sound bars.
	reg("Speaker", c.CAR_CYAN, -4, function(pen)
		group(pen, { rect(0.24, 0.5, 0.22, 0.32, 0.05), rect(0.42, 0.5, 0.2, 0.62, 0.06) })
		group(pen, { bar(0.7, 0.4, 0.7, 0.6, 0.08, WHITE), bar(0.84, 0.3, 0.84, 0.7, 0.08, WHITE) })
		shine(pen, 0.26, 0.42, 0.05, 0.1)
	end)

	-- Motion: a wave line (reduce motion).
	reg("Motion", c.TICK_GREEN, 0, function(pen)
		local pts = { { 0.1, 0.6 }, { 0.3, 0.38 }, { 0.5, 0.6 }, { 0.7, 0.38 }, { 0.9, 0.6 } }
		local specs = {}
		for i = 1, #pts - 1 do
			table.insert(specs, bar(pts[i][1], pts[i][2], pts[i + 1][1], pts[i + 1][2], 0.14))
		end
		group(pen, specs)
		shine(pen, 0.3, 0.32, 0.08, 0.03, -40)
	end)

	-- Gamepad: a rounded controller with a cross pad and two buttons.
	reg("Gamepad", c.STEEL, 0, function(pen)
		group(pen, { rect(0.5, 0.5, 0.9, 0.42, 0.2), circle(0.24, 0.66, 0.34), circle(0.76, 0.66, 0.34) })
		flat(pen, {
			bar(0.18, 0.5, 0.34, 0.5, 0.07, INK),
			bar(0.26, 0.42, 0.26, 0.58, 0.07, INK),
			circle(0.7, 0.46, 0.1, c.GOLD),
			circle(0.8, 0.56, 0.1, c.GIFT_RED),
		})
		shine(pen, 0.36, 0.36, 0.1, 0.03, -10)
	end)

	-- Keyboard: one key cap (a darker base and a raised face).
	reg("Keyboard", WHITE, 0, function(pen)
		group(pen, { rect(0.5, 0.58, 0.82, 0.66, 0.16, darken(pen.main, 0.2)) })
		group(pen, { rect(0.5, 0.46, 0.62, 0.46, 0.1) })
		shine(pen, 0.34, 0.34, 0.1, 0.04, -20)
	end)

	kit.alias("Touch", "Hand")

	-- Sneaker: a white running shoe with a teal sole (the Foot Dash).
	reg("Sneaker", WHITE, -6, function(pen)
		group(pen, { rect(0.38, 0.52, 0.44, 0.38, 0.14), bar(0.4, 0.63, 0.84, 0.65, 0.22) })
		group(pen, { bar(0.12, 0.8, 0.88, 0.8, 0.12, c.TEAL) })
		flat(pen, { bar(0.44, 0.47, 0.52, 0.5, 0.05, INK), bar(0.5, 0.41, 0.58, 0.45, 0.05, INK) })
		shine(pen, 0.26, 0.46, 0.05, 0.1)
	end)

	-- RARITIES (M9-01): five badges that differ by SHAPE and by pip count as well as colour (colour is never the only
	-- signal): a disc with 1 pip, a rounded square with 2, a diamond with 3, a shield with 4 and a star with 5.
	local rarity = kit.rarity
	local function pips(pen: any, count: number)
		local items = {}
		for i = 1, count do
			local x = 0.5 + (i - (count + 1) / 2) * 0.15
			table.insert(items, circle(x, 0.9, 0.14, INK))
			table.insert(items, circle(x, 0.9, 0.09, WHITE))
		end
		flat(pen, items)
	end
	local function rarityPainter(name: string, shape: string, count: number)
		local entry = rarity[name]
		local tint = entry.light:Lerp(entry.deep, 0.45)
		reg("Rarity_" .. name, tint, 0, function(pen)
			if shape == "disc" then
				group(pen, { circle(0.5, 0.44, 0.74) })
			elseif shape == "square" then
				group(pen, { rect(0.5, 0.44, 0.66, 0.66, 0.16) })
			elseif shape == "diamond" then
				group(pen, { rect(0.5, 0.44, 0.5, 0.5, 0.06, nil, 45) })
			elseif shape == "shield" then
				group(pen, { rect(0.5, 0.32, 0.7, 0.46, 0.1), rect(0.5, 0.56, 0.44, 0.44, 0.05, nil, 45) })
			else
				within(pen, 0.5, 0.46, 0.86, 0, "Star", function()
					painters.Star(pen)
				end)
			end
			if shape ~= "star" then
				shine(pen, 0.34, 0.3, 0.1, 0.04, -40)
			end
			pips(pen, count)
		end)
	end
	rarityPainter("Common", "disc", 1)
	rarityPainter("Uncommon", "square", 2)
	rarityPainter("Rare", "diamond", 3)
	rarityPainter("Epic", "shield", 4)
	rarityPainter("Legendary", "star", 5)
end

return Family
