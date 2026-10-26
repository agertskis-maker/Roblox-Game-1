--!strict
-- PLAYGROUND ONLY (Lane 3 Round 3, R3-GA): the collection screen. Studio Play numbers, never a screenshot claim. Every
-- scenario logs PASS / FAIL lines (grep "Collection"). Nothing here is a game rule: the cars, Lap Pay figures and acquisition
-- numbers are fixtures built inside the scenario (the Catalog module is not in this place, so the roster names come from
-- vault/design/cars/roster.md, which is a proposal).
--
--   Collection: sort orders (pure)             hand-written orders for Rarest / LapPay / Newest: ties, unknown values, empty,
--                                              the source array and the cars untouched
--   Collection: Garage sort controls           the live Garage on all six frames: order, text + shape of the active sort,
--                                              selection and World tab kept, sort with a detail open, World switch,
--                                              empty list, reopen and reset, touch size, source and fixtures untouched
--   Collection: no ellipsis and full words     the longest roster names x all five rarities x the six frames: whole names, full
--                                              rarity words, no truncation, nothing clipped, equal header heights
--   Collection: states sheet names and words   the same rules on the CarCard states sheet (narrow, smallest and long names)
--   Collection: six facts detail               exactly image, name, rarity, World, Lap Pay, finishes; no other text; the fixed bar
--   Collection: finishes and unknown values    TradingCard.detailFacts: owned / not owned / unknown, "?" and no leaks (pure)
--   Collection: no small duplicate cards       the trading sheet and the Garage show each car once, large cards only
--   Collection: scroll bounds                  the last card is reachable; the facts never scroll under the fixed bar
--   Collection: no developer words             a word scan over every card, sheet, Garage and detail text
--   Collection: leaks and reset                repeated open / sort / tab / close leaves the same instances; destroy leaves zero

local Players = game:GetService("Players")
local TextService = game:GetService("TextService")

local Prototype = Players.LocalPlayer
	:WaitForChild("PlayerScripts")
	:WaitForChild("Client")
	:WaitForChild("UI")
	:WaitForChild("Prototype")
local Fixtures = require(Prototype:WaitForChild("Fixtures")) :: any
local Cards = Prototype:WaitForChild("Cards")
local Screens = Prototype:WaitForChild("Screens")
local CardGrid = require(Cards:WaitForChild("CardGrid")) :: any
local CarCard = require(Cards:WaitForChild("CarCard")) :: any
local TradingCard = require(Cards:WaitForChild("TradingCard")) :: any
local CardDetail = require(Screens:WaitForChild("CardDetail")) :: any
local GarageMock = require(Screens:WaitForChild("GarageMock")) :: any

type Host = { [string]: any }

local RARITIES = { "Common", "Uncommon", "Rare", "Epic", "Legendary" }
local RARITY_WORD: { [string]: string } =
	{ Common = "COMMON", Uncommon = "UNCOMMON", Rare = "RARE", Epic = "EPIC", Legendary = "LEGENDARY" }
local SORT_WORD: { [string]: string } = { Rarest = "RAREST", LapPay = "LAP PAY", Newest = "NEWEST" }
local SORT_STATUS: { [string]: string } =
	{ Rarest = "Rarest first", LapPay = "Highest Lap Pay first", Newest = "Newest first" }
local NO_SORT_STATUS = "Collection order"
local ROW_LABELS = { "WORLD", "LAP PAY", "FINISHES" }

-- The proposed roster (vault/design/cars/roster.md; not the Catalog). The longest by characters and by words are found by code.
local ROSTER = {
	"Puglet",
	"Fishbowl Express",
	"Citrine Waffle Van",
	"Rangy",
	"Revolution 6",
	"Zoomurai",
	"Hurrikan",
	"Hyperion",
	"Razzer",
	"Peterbolt",
	"Winnie Bravo",
	"Chopsticks",
	"Recharger",
	"Baja Bruiser",
	"Forty-Niner",
	"Thunderfoot",
	"Re-Snow 4",
	"Hi-Ice",
	"Snowmog",
	"Snowva",
	"Subaroo",
	"Huskvarna",
	"Lance Stratus",
	"Yeti 6x6",
}

-- words a child must never read (Round 2 finding 13) and phrases that belong to the removed detail fields
local DEVELOPER_WORDS = {
	"adapter",
	"schema",
	"catalog",
	"fixture",
	"fixtures",
	"runtime",
	"contract",
	"proposed",
	"tunable",
	"preview",
	"todo",
	"id",
	"ids",
}
local REMOVED_PHRASES = { "per second", "heat capacity", "heat", "capacity", "unavailable (proposed)", "preview value" }

local function verdict(host: Host, name: string, ok: boolean, detail: string)
	host.log(string.format("%s %s: %s", if ok then "PASS" else "FAIL", name, detail))
end

local function comp(host: Host, key: string): any
	return host.api.components and host.api.components[key]
end

-- PASS when there is no problem, else FAIL with the first few.
local function report(host: Host, name: string, problems: { string }, okDetail: string)
	if #problems == 0 then
		verdict(host, name, true, okDetail)
		return
	end
	local shown = {}
	for i = 1, math.min(#problems, 5) do
		table.insert(shown, problems[i])
	end
	local more = if #problems > 5 then string.format(" (+%d more)", #problems - 5) else ""
	verdict(host, name, false, table.concat(shown, "; ") .. more)
end

-- Runs a scenario body so that an error is a FAIL line (not a silent stop) and the cleanup always runs.
local function guarded(host: Host, name: string, body: () -> (), cleanup: (() -> ())?)
	local ok, err = pcall(body)
	if not ok then
		verdict(host, name, false, "error: " .. tostring(err))
	end
	if cleanup then
		pcall(cleanup)
	end
end

local function sameList(a: { any }, b: { any }): boolean
	if #a ~= #b then
		return false
	end
	for i, v in a do
		if b[i] ~= v then
			return false
		end
	end
	return true
end

local function listText(list: { any }): string
	local out = {}
	for _, v in list do
		table.insert(out, tostring(v))
	end
	return "{" .. table.concat(out, ", ") .. "}"
end

local function deepCopy(value: any): any
	if type(value) ~= "table" then
		return value
	end
	local out = {}
	for k, v in value do
		out[k] = deepCopy(v)
	end
	return out
end

local function deepEqual(a: any, b: any): boolean
	if type(a) ~= type(b) then
		return false
	end
	if type(a) ~= "table" then
		return a == b
	end
	for k, v in a do
		if not deepEqual(v, b[k]) then
			return false
		end
	end
	for k in b do
		if a[k] == nil then
			return false
		end
	end
	return true
end

local function ids(cars: { any }): { string }
	local out = {}
	for _, c in cars do
		table.insert(out, c.id)
	end
	return out
end

-- a test car: the first fixture car with its own id, name, rarity and ownership
local function car(id: string, name: string, rarity: string, owned: boolean): any
	local c = table.clone(Fixtures.Cars[1]) :: any
	c.id = id
	c.name = name
	c.rarity = rarity
	c.owned = owned
	c.variant = "None"
	c.unseen = nil
	return c
end

----------------------------------------------------------------------------------------------
-- text helpers

local function chainVisible(gui: Instance, root: Instance): boolean
	local node: Instance? = gui
	while node do
		if node:IsA("GuiObject") and not (node :: GuiObject).Visible then
			return false
		end
		if node == root then
			return true
		end
		node = node.Parent
	end
	return true
end

-- a harness caption (PreviewCaption) is not child-facing text
local function isHarness(gui: Instance): boolean
	local node: Instance? = gui
	while node do
		if node:GetAttribute("PreviewCaption") == true then
			return true
		end
		node = node.Parent
	end
	return false
end

-- every visible, non-empty text object under `root`, harness captions left out
local function textObjects(root: Instance): { any }
	local out = {}
	for _, d in root:GetDescendants() do
		if d:IsA("TextLabel") or d:IsA("TextButton") then
			local g = d :: any
			if g.Text ~= "" and chainVisible(g, root) and not isHarness(g) then
				table.insert(out, g)
			end
		end
	end
	return out
end

-- the product of every UIScale that applies to `gui` (the HUD scale, the panel pop and the device fit)
local function effectiveScale(gui: Instance): number
	local scale = 1
	local node: Instance? = gui
	while node do
		for _, child in node:GetChildren() do
			if child:IsA("UIScale") then
				scale *= (child :: UIScale).Scale
			end
		end
		node = node.Parent
	end
	return scale
end

-- Does the text fit its box? Design px (TextService does not see UIScale, so the box is divided by the scale), plus the
-- engine's own TextFits flag. A TextScaled label is judged by the engine flag alone (its size is the engine's choice).
local function fitProblem(label: any): string?
	local scale = effectiveScale(label)
	local size: Vector2 = label.AbsoluteSize / scale
	if size.X < 1 or size.Y < 1 then
		return nil -- not laid out
	end
	local pad = label:FindFirstChildOfClass("UIPadding")
	local padX, padY = 0, 0
	if pad then
		padX = pad.PaddingLeft.Offset + pad.PaddingRight.Offset
		padY = pad.PaddingTop.Offset + pad.PaddingBottom.Offset
	end
	local availW, availH = size.X - padX, size.Y - padY
	local okEngine, engine = pcall(function()
		return label.TextFits
	end)
	if okEngine and engine == false then
		return string.format("%q: the engine says it does not fit (%.0f x %.0f)", label.Text, availW, availH)
	end
	if not label.TextScaled and label.TextSize > 0 then
		local params = Instance.new("GetTextBoundsParams")
		params.Text = label.Text
		params.Font = label.FontFace
		params.Size = label.TextSize
		params.Width = if label.TextWrapped then math.max(availW, 1) else 100000
		local ok, bounds = pcall(function()
			return TextService:GetTextBoundsAsync(params)
		end)
		params:Destroy()
		if ok and typeof(bounds) == "Vector2" then
			if bounds.X > availW + 1 then
				return string.format("%q is %.0f wide in a %.0f box", label.Text, bounds.X, availW)
			end
			if bounds.Y > availH + 1 then
				return string.format("%q is %.0f tall in a %.0f box", label.Text, bounds.Y, availH)
			end
		end
	end
	return nil
end

local function hasEllipsis(text: string): boolean
	return string.find(text, "\u{2026}", 1, true) ~= nil or string.find(text, "...", 1, true) ~= nil
end

local function containsWord(text: string, word: string): boolean
	return string.find(string.lower(text), "%f[%w]" .. word .. "%f[%W]") ~= nil
end

-- every visible text under `root`: no truncation, no ellipsis, nothing clipped. Returns the problems and the count.
local function textProblems(root: Instance, label: string): ({ string }, number)
	local problems: { string } = {}
	local objects = textObjects(root)
	for _, t in objects do
		if t.TextTruncate ~= Enum.TextTruncate.None then
			table.insert(
				problems,
				label .. ": " .. string.format("%q", t.Text) .. " has TextTruncate " .. t.TextTruncate.Name
			)
		end
		if hasEllipsis(t.Text) then
			table.insert(problems, label .. ": " .. string.format("%q", t.Text) .. " contains an ellipsis")
		end
		local why = fitProblem(t)
		if why then
			table.insert(problems, label .. ": " .. why)
		end
	end
	return problems, #objects
end

-- the cards of a grid, by car id (the grid names each card root "CarCard_<id>")
local function gridCards(root: Instance): { [string]: { root: Frame, name: TextLabel, rarity: TextLabel } }
	local out = {}
	for _, d in root:GetDescendants() do
		if d:IsA("Frame") and string.sub(d.Name, 1, 8) == "CarCard_" then
			local name = d:FindFirstChild("CarName", true)
			local rarity = d:FindFirstChild("RarityLabel", true)
			if name and rarity then
				out[string.sub(d.Name, 9)] = { root = d, name = name :: TextLabel, rarity = rarity :: TextLabel }
			end
		end
	end
	return out
end

----------------------------------------------------------------------------------------------
-- test data

-- (name x rarity) cars: the longest roster names, the Round 2 stress names and "Revolution 6", each in all five rarities
local function textCars(): ({ any }, { string }, string, string)
	local byChars, byWords = ROSTER[1], ROSTER[1]
	local function words(s: string): number
		local n = 0
		for _ in string.gmatch(s, "%S+") do
			n += 1
		end
		return n
	end
	for _, n in ROSTER do
		if #n > #byChars then
			byChars = n
		end
		if words(n) > words(byWords) then
			byWords = n
		end
	end
	local names: { string } = {}
	local seen: { [string]: boolean } = {}
	for _, n in
		{
			byChars,
			byWords,
			"Revolution 6",
			"Fishbowl Express",
			"Citrine Waffle Van Deluxe Edition",
			Fixtures.LongName.name,
		}
	do
		if not seen[n] then
			seen[n] = true
			table.insert(names, n)
		end
	end
	local cars: { any } = {}
	for i, n in names do
		for j, r in RARITIES do
			table.insert(cars, car(string.format("t%d-%d", i, j), n, r, true))
		end
	end
	return cars, names, byChars, byWords
end

-- the Garage test collection: ties, an unowned car (its Lap Pay and date are hidden), a car with no Lap Pay, one with no
-- date and a long name. The expected orders are written by hand.
local function garageData(): ({ any }, (any) -> any?, { [string]: number }, { [string]: { string } })
	local list = {
		car("g1", "Aaa Common", "Common", true),
		car("g2", "Bbb Rare", "Rare", true),
		car("g3", "Ccc Legend", "Legendary", true),
		car("g4", "Ddd Epic", "Epic", true),
		car("g5", "Eee Uncommon", "Uncommon", false),
		car("g6", "Fff Rare", "Rare", true),
		car("g7", "Ggg Common", "Common", true),
		car("g8", "Citrine Waffle Van Deluxe Edition", "Uncommon", true),
	}
	local pay: { [string]: number } = { g1 = 100, g2 = 300, g3 = 300, g5 = 999, g6 = 50, g7 = 0, g8 = 120 } -- g4: none
	local acquired: { [string]: number } = { g1 = 10, g2 = 30, g4 = 20, g5 = 99, g6 = 30, g7 = 5, g8 = 1 } -- g3: none
	local function infoOf(c: any): any?
		return { world = "Downtown", lapPay = pay[c.id], variants = { Gold = true, Chrome = false, Rainbow = false } }
	end
	local expected = {
		source = { "g1", "g2", "g3", "g4", "g5", "g6", "g7", "g8" },
		Rarest = { "g3", "g4", "g2", "g6", "g8", "g5", "g1", "g7" },
		LapPay = { "g2", "g3", "g8", "g1", "g6", "g7", "g4", "g5" },
		Newest = { "g2", "g6", "g4", "g1", "g7", "g8", "g3", "g5" },
	}
	return list, infoOf, acquired, expected
end

local function useFrame(host: Host, profile: string)
	host.api.setProfile(profile)
	host.wait(0.45)
end

local function leaveGarage(host: Host)
	local garage = comp(host, "garage")
	if garage then
		pcall(function()
			garage:setSort(nil)
			garage:setSource(nil)
			garage:selectTab("Downtown")
		end)
	end
	host.api.close("garage")
	host.api.close("cardDetail")
	host.api.close("cardSheet")
	host.api.close("tradingSheet")
	host.api.setProfile("Desktop")
end

local S: { [string]: (Host) -> () } = {}

----------------------------------------------------------------------------------------------

S["Collection: sort orders (pure)"] = function(host: Host)
	guarded(host, "Collection: sort orders (pure)", function()
		local function mk(id: string, name: string, rarity: string): any
			return { id = id, name = name, rarity = rarity, variant = "None", owned = true }
		end
		-- Rarest: rarity rank, then name A to Z (not case sensitive), then id; an unknown rarity word is last
		local rarity = {
			mk("c1", "Zed", "Common"),
			mk("r2", "Alpha", "Rare"),
			mk("l1", "Mu", "Legendary"),
			mk("e1", "Beta", "Epic"),
			mk("u1", "Gamma", "Uncommon"),
			mk("r1", "alpha", "Rare"),
			mk("r3", "Bravo", "Rare"),
			mk("x1", "Odd", "Mythic"),
		}
		local snapshot = deepCopy(rarity)
		local refs = table.clone(rarity)
		local got = ids(CardGrid.sortCars(rarity, "Rarest"))
		local want = { "l1", "e1", "r1", "r2", "r3", "u1", "c1", "x1" }
		verdict(
			host,
			"Sort Rarest: rarity, then name, then id, unknown last",
			sameList(got, want),
			listText(got) .. " expected " .. listText(want)
		)
		-- Lap Pay: the supplied numbers, highest first; a tie keeps the source order; 0 is a number; nil and NaN are unknown
		local list = {
			mk("a", "Z", "Common"),
			mk("b", "Y", "Common"),
			mk("c", "X", "Common"),
			mk("d", "W", "Common"),
			mk("e", "V", "Common"),
			mk("f", "U", "Common"),
			mk("g", "T", "Common"),
		}
		local pay: { [string]: number } = { a = 150, b = 300, d = 150, e = 0, g = 0 / 0 }
		local keys = {
			lapPay = function(c: any): number?
				return pay[c.id]
			end,
		}
		got = ids(CardGrid.sortCars(list, "LapPay", keys))
		want = { "b", "a", "d", "e", "c", "f", "g" }
		verdict(
			host,
			"Sort Lap Pay: numbers high to low, ties in source order, unknown last",
			sameList(got, want),
			listText(got) .. " expected " .. listText(want)
		)
		-- Newest: the supplied acquisition numbers only; the array position is never a date
		local dated = {
			mk("p", "P", "Rare"),
			mk("q", "Q", "Rare"),
			mk("r", "R", "Rare"),
			mk("s", "S", "Rare"),
			mk("t", "T", "Rare"),
		}
		local when: { [string]: number } = { p = 5, q = 9, s = 9, t = 1 }
		local newestKeys = {
			acquired = function(c: any): number?
				return when[c.id]
			end,
		}
		got = ids(CardGrid.sortCars(dated, "Newest", newestKeys))
		want = { "q", "s", "p", "t", "r" }
		verdict(
			host,
			"Sort Newest: supplied numbers, a tie in source order, no date last",
			sameList(got, want),
			listText(got) .. " expected " .. listText(want)
		)
		local reversed = { dated[5], dated[4], dated[3], dated[2], dated[1] }
		got = ids(CardGrid.sortCars(reversed, "Newest", newestKeys))
		want = { "s", "q", "p", "t", "r" }
		verdict(
			host,
			"Sort Newest: a reversed array changes only the tie (source order), never the dates",
			sameList(got, want),
			listText(got) .. " expected " .. listText(want)
		)
		-- Lap Pay mode reads only the Lap Pay key (a date key is ignored), Newest only the date key
		got = ids(CardGrid.sortCars(dated, "LapPay", newestKeys))
		verdict(
			host,
			"Each sort reads only its own key",
			sameList(got, ids(dated)),
			"Lap Pay with no Lap Pay numbers keeps " .. listText(got)
		)
		-- every unknown: the collection order, in a NEW array
		local none = CardGrid.sortCars(list, "Newest", {})
		verdict(
			host,
			"Sort with no numbers at all keeps the collection order",
			sameList(ids(none), ids(list)) and none ~= list,
			listText(ids(none))
		)
		-- empty, one car, no mode
		local empty = CardGrid.sortCars({}, "Rarest")
		local one = CardGrid.sortCars({ list[1] }, "LapPay", keys)
		local plain = CardGrid.sortCars(list, nil)
		verdict(
			host,
			"Sort: empty list, one car, no mode",
			#empty == 0 and #one == 1 and sameList(ids(plain), ids(list)) and plain ~= list,
			string.format("%d, %d, %d cars", #empty, #one, #plain)
		)
		-- the source array and its cars are untouched: same length, same cars in the same places, same fields
		local untouched = #rarity == #refs and deepEqual(rarity, snapshot)
		for i, c in rarity do
			if c ~= refs[i] then
				untouched = false
			end
		end
		verdict(host, "Sorting never changes the source array or its cars", untouched, "identity, order and fields")
	end)
end

----------------------------------------------------------------------------------------------

-- the sort checks on the live Garage for the frame that is set now
local function garageSortChecks(host: Host, garage: any, profile: string, expected: { [string]: { string } })
	local problems: { string } = {}
	local function check(ok: boolean, what: string)
		if not ok then
			table.insert(problems, what)
		end
	end
	local function marks(mode: string?)
		local ds = garage:getDebugState()
		if ds.sortForm == "Cycle" then
			local c = ds.sortCycle
			check(c.visible == true, "the one sort button is not visible")
			check(c.active == (mode ~= nil), "cycle button active flag")
			check(
				c.checkVisible == (mode ~= nil) and c.underlineVisible == (mode ~= nil),
				"cycle button check / underline"
			)
			check(c.text == (if mode then SORT_WORD[mode] else "SORT"), "cycle button text " .. tostring(c.text))
		else
			local on = 0
			for _, b in ds.sortButtons do
				check(b.visible == true, b.id .. " button is not visible")
				check(b.active == (b.id == mode), b.id .. " active flag")
				check(b.checkVisible == b.active and b.underlineVisible == b.active, b.id .. " check / underline")
				check(b.text == SORT_WORD[b.id], b.id .. " text " .. tostring(b.text))
				if b.active then
					on += 1
				end
			end
			check(on == (if mode then 1 else 0), "buttons marked: " .. on)
		end
		check(ds.sortStatus == (if mode then SORT_STATUS[mode] else NO_SORT_STATUS), "status text " .. ds.sortStatus)
		check(ds.sort == (mode or "None"), "sort " .. ds.sort)
	end
	-- the sort buttons are touch targets of at least 48 design px
	for _, name in { "Sort_Rarest", "Sort_LapPay", "Sort_Newest", "Sort_Cycle" } do
		local b = garage.root:FindFirstChild(name, true) :: GuiObject?
		if b and chainVisible(b, garage.root) and b.Size.Y.Offset < 48 then
			check(false, name .. " is " .. b.Size.Y.Offset .. " px tall")
		end
	end
	garage:setSort(nil)
	local start = garage:getDebugState().order
	check(sameList(start, expected.source), "collection order " .. listText(start))
	marks(nil)
	for _, mode in { "Rarest", "LapPay", "Newest" } do
		garage:setSort(mode)
		host.wait(0.1)
		local order = garage:getDebugState().order
		check(
			sameList(order, expected[mode]),
			mode .. " " .. listText(order) .. " expected " .. listText(expected[mode])
		)
		marks(mode)
	end
	garage:setSort(nil)
	marks(nil)
	report(
		host,
		"Garage sort order and controls (" .. profile .. ")",
		problems,
		"orders, text and shape, 48 px targets"
	)
end

-- selection, World tab and an open detail survive a sort; a World switch with a detail open is clean
local function garageRetention(host: Host, garage: any, profile: string, expected: { [string]: { string } })
	local problems: { string } = {}
	local function check(ok: boolean, what: string)
		if not ok then
			table.insert(problems, what)
		end
	end
	garage:setSort(nil)
	garage:selectTab("Downtown")
	garage:selectCar("g3") -- a phone frame opens the detail view
	host.wait(0.25)
	local before = garage:getDebugState()
	check(before.selectedId == "g3", "selected before the sort " .. tostring(before.selectedId))
	for _, mode in { "Rarest", "Newest", "LapPay" } do
		garage:setSort(mode)
		host.wait(0.1)
		local after = garage:getDebugState()
		check(after.selectedId == "g3" and after.grid.selectedId == "g3", mode .. ": the selected car was lost")
		check(after.tab == "Downtown", mode .. ": the World tab changed to " .. after.tab)
		check(after.detailOpen == before.detailOpen, mode .. ": the open detail changed")
		check(after.facts ~= nil and after.facts.carId == "g3", mode .. ": the detail shows another car")
	end
	-- a World switch while a detail is open
	garage:selectTab("Dusty")
	host.wait(0.25)
	local dusty = garage:getDebugState()
	check(
		dusty.tab == "Dusty" and dusty.selectedId == nil,
		"Dusty: tab " .. dusty.tab .. " selected " .. tostring(dusty.selectedId)
	)
	check(
		dusty.detailOpen == false and #dusty.order == 0 and dusty.grid.empty == true,
		"Dusty: the empty World is not clean"
	)
	garage:setSort("Rarest") -- sorting an empty World changes nothing and breaks nothing
	check(garage:getSort() == "Rarest" and #garage:getDebugState().order == 0, "sort on an empty World")
	garage:selectTab("Summit") -- the loading World
	host.wait(0.2)
	check(
		garage:getDebugState().grid.loading == true and garage:getDebugState().selectedId == nil,
		"Summit: loading case"
	)
	garage:selectTab("Downtown")
	host.wait(0.3)
	local back = garage:getDebugState()
	check(back.tab == "Downtown" and back.selectedId == "g3", "Downtown again: selected " .. tostring(back.selectedId))
	check(sameList(back.order, expected.Rarest), "Downtown again: order " .. listText(back.order))
	garage:setSort(nil)
	report(
		host,
		"Garage sort keeps selection, World and detail (" .. profile .. ")",
		problems,
		"sort, World switch, back"
	)
end

S["Collection: Garage sort controls"] = function(host: Host)
	local name = "Collection: Garage sort controls"
	local garage = comp(host, "garage")
	if not garage then
		verdict(host, name, false, "the garage component is not mounted")
		return
	end
	guarded(host, name, function()
		local list, infoOf, acquired, expected = garageData()
		local snapshot = deepCopy(list)
		local refs = table.clone(list)
		local fixturesBefore = deepCopy(Fixtures.Cars)
		garage:setSource(list, infoOf, acquired)
		host.api.open("garage")
		for _, profile in host.api.profiles do
			useFrame(host, profile)
			garageSortChecks(host, garage, profile, expected)
			garageRetention(host, garage, profile, expected)
		end
		-- an empty list: every sort works, nothing is selected
		garage:setSource({}, infoOf, acquired)
		host.wait(0.2)
		local problems: { string } = {}
		for _, mode in { "Rarest", "LapPay", "Newest" } do
			garage:setSort(mode)
			local ds = garage:getDebugState()
			if #ds.order ~= 0 or ds.sourceCount ~= 0 or ds.selectedId ~= nil or ds.grid.empty ~= true then
				table.insert(problems, mode .. " on an empty collection")
			end
		end
		garage:setSort(nil)
		report(host, "Garage with an empty collection", problems, "three sorts, nothing selected, the empty message")
		-- reopen: the sort is local state that stays while the screen is built; setSort(nil) is the reset
		garage:setSource(list, infoOf, acquired)
		garage:setSort("Rarest")
		host.api.close("garage")
		host.wait(0.4)
		host.api.open("garage")
		host.wait(0.4)
		local reopened = garage:getDebugState()
		garage:setSort(nil)
		local reset = garage:getDebugState()
		verdict(
			host,
			"Garage reopen keeps the sort until it is reset",
			reopened.sort == "Rarest"
				and sameList(reopened.order, expected.Rarest)
				and reset.sort == "None"
				and sameList(reset.order, expected.source),
			string.format("after reopen %s %s, after reset %s", reopened.sort, listText(reopened.order), reset.sort)
		)
		-- the collection array and the shared fixtures were only read
		local untouched = #list == #refs and deepEqual(list, snapshot) and deepEqual(Fixtures.Cars, fixturesBefore)
		for i, c in list do
			if c ~= refs[i] then
				untouched = false
			end
		end
		verdict(
			host,
			"Garage sorting never changed the collection or the shared cars",
			untouched,
			"identity, order, fields"
		)
	end, function()
		leaveGarage(host)
	end)
end

----------------------------------------------------------------------------------------------

S["Collection: no ellipsis and full words"] = function(host: Host)
	local name = "Collection: no ellipsis and full words"
	local garage = comp(host, "garage")
	if not garage then
		verdict(host, name, false, "the garage component is not mounted")
		return
	end
	guarded(host, name, function()
		local cars, names, byChars, byWords = textCars()
		host.log(
			string.format(
				"Longest roster name by characters: %q, by words: %q; %d names x 5 rarities",
				byChars,
				byWords,
				#names
			)
		)
		local byId: { [string]: any } = {}
		for _, c in cars do
			byId[c.id] = c
		end
		garage:setSource(cars, function()
			return { world = "Downtown", lapPay = 100 }
		end, {})
		host.api.open("garage")
		for _, profile in host.api.profiles do
			useFrame(host, profile)
			host.wait(1.0) -- the name measurements settle
			local problems: { string } = {}
			local found = gridCards(garage.root)
			local count = 0
			local words: { [string]: boolean } = {}
			local rows: { [number]: { number } } = {}
			local heights: { number } = {}
			for id, parts in found do
				count += 1
				local c = byId[id]
				if not c then
					continue
				end
				local label = parts.name
				if label.Text ~= c.name then
					table.insert(problems, string.format("%s shows %q", c.name, label.Text))
				end
				if label.TextTruncate ~= Enum.TextTruncate.None or label.TextScaled or label.TextSize < 16 then
					table.insert(
						problems,
						string.format(
							"%s: truncate %s scaled %s size %d",
							c.name,
							label.TextTruncate.Name,
							tostring(label.TextScaled),
							label.TextSize
						)
					)
				end
				local why = fitProblem(label)
				if why then
					table.insert(problems, why)
				end
				words[parts.rarity.Text] = true
				if parts.rarity.Text ~= RARITY_WORD[c.rarity] then
					table.insert(problems, string.format("%s rarity word %q", c.rarity, parts.rarity.Text))
				end
				local rarityWhy = fitProblem(parts.rarity)
				if rarityWhy then
					table.insert(problems, rarityWhy)
				end
				table.insert(heights, label.Size.Y.Offset)
				local row = math.floor(parts.root.AbsolutePosition.Y + 0.5)
				rows[row] = rows[row] or {}
				table.insert(rows[row], label.AbsoluteSize.Y)
			end
			-- equal header heights in the grid and in every row
			for _, h in heights do
				if math.abs(h - heights[1]) > 0.01 then
					table.insert(problems, string.format("header heights differ: %.1f and %.1f", heights[1], h))
					break
				end
			end
			for y, list in rows do
				local lo, hi = math.huge, -math.huge
				for _, h in list do
					lo, hi = math.min(lo, h), math.max(hi, h)
				end
				if hi - lo > 0.6 then
					table.insert(problems, string.format("row at %d: header heights %.1f to %.1f", y, lo, hi))
				end
			end
			local wordCount = 0
			for _ in words do
				wordCount += 1
			end
			if count ~= #cars then
				table.insert(problems, string.format("%d cards of %d", count, #cars))
			end
			if wordCount ~= 5 then
				table.insert(problems, string.format("%d of the 5 rarity words", wordCount))
			end
			local all = garage:getDebugState().grid
			report(
				host,
				"Cards show whole names and full rarity words (" .. profile .. ")",
				problems,
				string.format(
					"%d cards, header %d lines of %.0f px, all five words, no truncation, nothing clipped",
					count,
					all.nameLines,
					heights[1] or 0
				)
			)
		end
	end, function()
		leaveGarage(host)
	end)
end

S["Collection: states sheet names and words"] = function(host: Host)
	local name = "Collection: states sheet names and words"
	local sheet = comp(host, "cardSheet")
	if not sheet then
		verdict(host, name, false, "the states sheet is not mounted")
		return
	end
	guarded(host, name, function()
		host.api.setProfile("Desktop")
		host.wait(0.4)
		sheet:open()
		host.wait(1.5)
		local ds = sheet:getDebugState()
		local problems: { string } = {}
		local lines: { string } = {}
		for _, s in ds.states do
			local c = s.card
			if c.shownName ~= c.name or c.truncated ~= false then
				table.insert(problems, string.format("%s: name shown as %q", s.label, c.shownName))
			end
			if c.nameFit == "Overflow" or c.nameFit == "Pending" or c.nameSize < 16 then
				table.insert(problems, string.format("%s: name fit %s at %d", s.label, c.nameFit, c.nameSize))
			end
			if c.rarityLabel ~= RARITY_WORD[c.rarity] or c.rarityFits ~= true then
				table.insert(
					problems,
					string.format("%s: rarity %q fits %s", s.label, c.rarityLabel, tostring(c.rarityFits))
				)
			end
			table.insert(lines, string.format("%s = %s (%s %d)", s.label, c.shownName, c.nameFit, c.nameSize))
		end
		local textIssues = textProblems(sheet.root, "sheet")
		for _, p in textIssues do
			table.insert(problems, p)
		end
		host.log("States sheet names: " .. table.concat(lines, " | "))
		report(
			host,
			"States sheet: whole names, full rarity words, nothing clipped",
			problems,
			string.format("%d cards", ds.cards)
		)
	end, function()
		leaveGarage(host)
	end)
end

----------------------------------------------------------------------------------------------

-- every visible text of a detail surface must be one of the six facts or a control; anything else is an extra field
local function allowedTexts(c: any, info: any, extra: { string }): { [string]: boolean }
	local facts = TradingCard.detailFacts(c, info)
	local allowed: { [string]: boolean } = {}
	for _, t in
		{
			facts.name,
			facts.rarity,
			facts.world,
			facts.lapPay,
			"WORLD",
			"LAP PAY",
			"FINISHES",
			"GOLD",
			"CHROME",
			"RAINBOW",
			"OWNED",
			"NOT OWNED",
			"?",
			"BACK",
			"DRIVE",
			"CLOSE",
			"LOADING",
			"NOT READY YET",
		}
	do
		allowed[string.upper(t)] = true
	end
	for _, t in extra do
		allowed[string.upper(t)] = true
	end
	return allowed
end

local function extraTexts(root: Instance, allowed: { [string]: boolean }): { string }
	local extras: { string } = {}
	for _, t in textObjects(root) do
		if not allowed[string.upper(t.Text)] then
			table.insert(extras, string.format("%q", t.Text))
		end
	end
	return extras
end

-- the six facts as the detail debug state reports them (what is really drawn)
local function factProblems(ds: any, c: any, info: any, want: { string }?): { string }
	local problems: { string } = {}
	local facts = TradingCard.detailFacts(c, info)
	if #ds.facts ~= 6 then
		table.insert(problems, "facts: " .. #ds.facts)
		return problems
	end
	for i, key in CardDetail.FactKeys do
		if ds.facts[i].key ~= key then
			table.insert(problems, "fact " .. i .. " is " .. tostring(ds.facts[i].key))
		end
	end
	if not sameList(ds.rowLabels, ROW_LABELS) then
		table.insert(problems, "row labels " .. listText(ds.rowLabels))
	end
	if ds.facts[2].shown ~= c.name then
		table.insert(problems, string.format("name %q", tostring(ds.facts[2].shown)))
	end
	if ds.facts[3].shown ~= RARITY_WORD[c.rarity] then
		table.insert(problems, string.format("rarity %q", tostring(ds.facts[3].shown)))
	end
	if ds.facts[4].shown ~= facts.world then
		table.insert(problems, string.format("world %q expected %q", tostring(ds.facts[4].shown), facts.world))
	end
	if ds.facts[5].shown ~= facts.lapPay then
		table.insert(problems, string.format("Lap Pay %q expected %q", tostring(ds.facts[5].shown), facts.lapPay))
	end
	local chips = ds.facts[6].shown
	for i, finish in { "GOLD", "CHROME", "RAINBOW" } do
		local chip = chips[i]
		local state = facts.finishes[i].state
		local word = if state == "Owned" then "OWNED" elseif state == "NotOwned" then "NOT OWNED" else "?"
		if chip == nil or chip.finish ~= finish or chip.state ~= word then
			table.insert(
				problems,
				string.format(
					"finish %d shows %s %s expected %s %s",
					i,
					tostring(chip and chip.finish),
					tostring(chip and chip.state),
					finish,
					word
				)
			)
		end
	end
	if want then
		local kinds = { chips[1].kind, chips[2].kind, chips[3].kind }
		if not sameList(kinds, want) then
			table.insert(problems, "finish states " .. listText(kinds) .. " expected " .. listText(want))
		end
	end
	return problems
end

S["Collection: six facts detail"] = function(host: Host)
	local name = "Collection: six facts detail"
	local detail = comp(host, "cardDetail")
	if not detail then
		verdict(host, name, false, "the card detail is not mounted")
		return
	end
	guarded(host, name, function()
		local _, names = textCars()
		local info = { world = "DustyHighway", lapPay = 220, variants = { Gold = true, Chrome = false } } -- Rainbow: not supplied
		for _, profile in host.api.profiles do
			useFrame(host, profile)
			local problems: { string } = {}
			-- five rarities with the long names, owned: Gold OWNED, Chrome NOT OWNED, Rainbow "?"
			for i, rarity in RARITIES do
				local c = car("d" .. i, names[(i - 1) % #names + 1], rarity, true)
				detail:open(c, info)
				host.wait(0.55)
				local ds = detail:getDebugState()
				for _, p in factProblems(ds, c, info, { "Owned", "NotOwned", "Unknown" }) do
					table.insert(problems, rarity .. ": " .. p)
				end
				for _, extra in extraTexts(detail.root, allowedTexts(c, info, { "COLLECTIBLE CARD" })) do
					table.insert(problems, rarity .. ": extra text " .. extra)
				end
				local textIssues = textProblems(detail.root, rarity)
				for _, p in textIssues do
					table.insert(problems, p)
				end
				if ds.scrollsBehindBar or ds.gapToBar < -0.5 then
					table.insert(
						problems,
						string.format("%s: the content reaches the fixed bar (gap %.1f)", rarity, ds.gapToBar)
					)
				end
				-- the last row is reachable: scroll to the end and the Rainbow chip sits inside the area above the bar
				local scroll = detail.root:FindFirstChild("Scroll", true) :: ScrollingFrame?
				local chip = detail.root:FindFirstChild("Chip_Rainbow", true) :: GuiObject?
				local bar = detail.root:FindFirstChild("Actions", true) :: GuiObject?
				if scroll and chip and bar then
					scroll.CanvasPosition = Vector2.new(0, 100000)
					host.wait(0.1)
					local bottom = chip.AbsolutePosition.Y + chip.AbsoluteSize.Y
					if
						bottom > scroll.AbsolutePosition.Y + scroll.AbsoluteSize.Y + 1
						or bottom > bar.AbsolutePosition.Y + 0.5
					then
						table.insert(problems, rarity .. ": the finishes cannot be scrolled clear of the bar")
					end
				end
				detail:close()
				host.wait(0.25)
			end
			-- not owned: the silhouette, "?" for Lap Pay, every finish NOT OWNED, the World still shown
			local unowned = car("du", "Revolution 6", "Rare", false)
			detail:open(unowned, info)
			host.wait(0.55)
			local ds = detail:getDebugState()
			for _, p in factProblems(ds, unowned, info, { "NotOwned", "NotOwned", "NotOwned" }) do
				table.insert(problems, "not owned: " .. p)
			end
			if ds.facts[5].shown ~= "?" or ds.card == nil or ds.card.status ~= "Unowned" then
				table.insert(
					problems,
					"not owned: Lap Pay "
						.. tostring(ds.facts[5].shown)
						.. " status "
						.. tostring(ds.card and ds.card.status)
				)
			end
			for _, extra in extraTexts(detail.root, allowedTexts(unowned, info, { "COLLECTIBLE CARD" })) do
				table.insert(problems, "not owned: extra text " .. extra)
			end
			detail:close()
			host.wait(0.25)
			-- owned, nothing supplied: every unknown value reads "?"
			local bare = car("db", "Revolution 6", "Rare", true)
			detail:open(bare, {})
			host.wait(0.55)
			ds = detail:getDebugState()
			for _, p in factProblems(ds, bare, {}, { "Unknown", "Unknown", "Unknown" }) do
				table.insert(problems, "nothing supplied: " .. p)
			end
			if ds.facts[4].shown ~= "?" or ds.facts[5].shown ~= "?" then
				table.insert(
					problems,
					"nothing supplied: World "
						.. tostring(ds.facts[4].shown)
						.. " Lap Pay "
						.. tostring(ds.facts[5].shown)
				)
			end
			detail:close()
			host.wait(0.25)
			report(
				host,
				"Detail shows exactly the six facts (" .. profile .. ")",
				problems,
				"5 rarities, not owned, nothing supplied; fixed bar clear"
			)
		end
	end, function()
		leaveGarage(host)
	end)

	-- the Garage detail (a pane on wide frames, a full view on phones) shows the same six facts
	local garage = comp(host, "garage")
	if not garage then
		return
	end
	guarded(host, name, function()
		local list, infoOf, acquired = garageData()
		garage:setSource(list, infoOf, acquired)
		host.api.open("garage")
		for _, profile in host.api.profiles do
			useFrame(host, profile)
			local problems: { string } = {}
			for _, id in { "g3", "g5", "g8" } do
				garage:selectCar(id)
				host.wait(0.4)
				local ds = garage:getDebugState()
				local c: any = nil
				for _, candidate in list do
					if candidate.id == id then
						c = candidate
					end
				end
				if ds.facts == nil then
					table.insert(problems, id .. ": no detail")
					continue
				end
				local info = infoOf(c)
				for _, p in factProblems(ds.facts, c, info, nil) do
					table.insert(problems, id .. ": " .. p)
				end
				local pane = garage.root:FindFirstChild("Detail", true)
				if pane then
					for _, extra in extraTexts(pane, allowedTexts(c, info, {})) do
						table.insert(problems, id .. ": extra text " .. extra)
					end
				end
				if ds.detailGapToBar < -0.5 then
					table.insert(
						problems,
						string.format("%s: the facts reach the bar (gap %.1f)", id, ds.detailGapToBar)
					)
				end
			end
			report(
				host,
				"Garage detail shows exactly the six facts (" .. profile .. ")",
				problems,
				"3 cars, owned and not owned"
			)
		end
	end, function()
		leaveGarage(host)
	end)
end

----------------------------------------------------------------------------------------------

S["Collection: finishes and unknown values"] = function(host: Host)
	guarded(host, "Collection: finishes and unknown values", function()
		local owned = car("f1", "Revolution 6", "Rare", true)
		local function states(facts: any): { string }
			local out = {}
			for _, f in facts.finishes do
				table.insert(out, f.finish .. "=" .. f.state)
			end
			return out
		end
		-- owned, flags supplied: true is OWNED, false NOT OWNED, nil is not guessed
		local mixed = TradingCard.detailFacts(
			owned,
			{ world = "Downtown", lapPay = 220, variants = { Gold = true, Chrome = false } }
		)
		verdict(
			host,
			"Finishes: owned, not owned and unknown are three different states",
			sameList(states(mixed), { "Gold=Owned", "Chrome=NotOwned", "Rainbow=Unknown" }),
			listText(states(mixed))
		)
		verdict(
			host,
			"Lap Pay is the supplied number, in dollars per lap",
			mixed.lapPay == "$220 / lap" and mixed.lapPayValue == 220 and mixed.world == "Downtown",
			mixed.lapPay .. " / " .. mixed.world
		)
		-- not owned: nothing leaks, whatever the data says
		local hidden = TradingCard.detailFacts(
			car("f2", "Revolution 6", "Rare", false),
			{ world = "SummitPass", lapPay = 500, variants = { Gold = true, Chrome = true, Rainbow = true } }
		)
		verdict(
			host,
			"A car the player does not own: Lap Pay is ?, no finish is owned, the World is still shown",
			hidden.lapPay == "?"
				and hidden.lapPayValue == nil
				and hidden.hidden == true
				and hidden.world == "Summit Pass"
				and sameList(states(hidden), { "Gold=NotOwned", "Chrome=NotOwned", "Rainbow=NotOwned" }),
			hidden.lapPay .. " / " .. hidden.world .. " / " .. listText(states(hidden))
		)
		-- nothing supplied: "?" and unknown, never an invented value
		local bare = TradingCard.detailFacts(owned, nil)
		verdict(
			host,
			"Nothing supplied reads ? and unknown, never an invented value",
			bare.world == "?"
				and bare.lapPay == "?"
				and bare.lapPayValue == nil
				and sameList(states(bare), { "Gold=Unknown", "Chrome=Unknown", "Rainbow=Unknown" }),
			bare.world .. " / " .. bare.lapPay
		)
		-- zero is a number; the full rarity words; the name is whole
		local zero = TradingCard.detailFacts(owned, { lapPay = 0 })
		local words: { string } = {}
		for _, r in RARITIES do
			table.insert(words, TradingCard.detailFacts(car("f3", "X", r, true), {}).rarity)
		end
		verdict(
			host,
			"Zero Lap Pay is a number; the five rarity words are whole",
			zero.lapPay == "$0 / lap"
				and zero.lapPayValue == 0
				and sameList(words, { "COMMON", "UNCOMMON", "RARE", "EPIC", "LEGENDARY" })
				and zero.name == "Revolution 6",
			zero.lapPay .. " / " .. table.concat(words, ",")
		)
		-- exactly the six facts: no per-second, Heat, family, quirk, flavour, number or date field exists
		local keys: { string } = {}
		for k in mixed do
			table.insert(keys, k)
		end
		table.sort(keys)
		verdict(
			host,
			"detailFacts holds only the six facts (and the hidden flag)",
			sameList(keys, { "finishes", "hidden", "lapPay", "lapPayValue", "name", "rarity", "world" })
				or sameList(keys, { "finishes", "hidden", "lapPay", "name", "rarity", "world" }),
			listText(keys)
		)
	end)
end

----------------------------------------------------------------------------------------------

S["Collection: no small duplicate cards"] = function(host: Host)
	local name = "Collection: no small duplicate cards"
	local sheet = comp(host, "tradingSheet")
	local garage = comp(host, "garage")
	guarded(host, name, function()
		host.api.setProfile("Desktop")
		host.wait(0.4)
		if sheet then
			host.api.open("tradingSheet")
			host.wait(1.2)
			local ds = sheet:getDebugState()
			local problems: { string } = {}
			local seen: { [string]: boolean } = {}
			for _, s in ds.states do
				if s.card.variant ~= "Reward" then
					table.insert(problems, s.label .. ": a " .. tostring(s.card.variant) .. " card")
				end
				if seen[s.card.id] then
					table.insert(problems, s.label .. ": the car " .. s.card.id .. " is listed twice")
				end
				seen[s.card.id] = true
			end
			if sheet.root:FindFirstChild("CompactCards", true) then
				table.insert(problems, "the compact card grid still exists")
			end
			report(
				host,
				"Trading sheet lists each car once, as a large card",
				problems,
				string.format("%d large cards, no compact grid", ds.cards)
			)
			host.api.close("tradingSheet")
			host.wait(0.3)
		else
			verdict(host, name, false, "the trading sheet is not mounted")
		end
		if garage then
			garage:setSource(nil)
			host.api.open("garage")
			host.wait(1.0)
			local problems: { string } = {}
			local found = gridCards(garage.root)
			local grid = garage:getDebugState().grid
			local scale = effectiveScale(garage.root:FindFirstChild("CardGrid", true) :: Instance)
			local count = 0
			for id, parts in found do
				count += 1
				local w, h = parts.root.AbsoluteSize.X / scale, parts.root.AbsoluteSize.Y / scale
				if math.abs(w - grid.cell[1]) > 1 or math.abs(h - grid.cell[2]) > 1 then
					table.insert(
						problems,
						string.format("%s is %.0f x %.0f, not %.0f x %.0f", id, w, h, grid.cell[1], grid.cell[2])
					)
				end
				if w < CarCard.MinSize.X - 1 then
					table.insert(problems, id .. " is narrower than the smallest card")
				end
			end
			local order = garage:getDebugState().order
			local unique: { [string]: boolean } = {}
			for _, id in order do
				if unique[id] then
					table.insert(problems, id .. " is listed twice")
				end
				unique[id] = true
			end
			if count ~= #order then
				table.insert(problems, string.format("%d cards for %d cars", count, #order))
			end
			report(
				host,
				"Garage shows each car once, every card at the grid size",
				problems,
				string.format("%d cards of %.0f x %.0f", count, grid.cell[1], grid.cell[2])
			)
			host.api.close("garage")
		end
		-- the compact claimed-run tray is another screen and stays
		verdict(
			host,
			"The claimed-run tray is still mounted",
			comp(host, "tray") ~= nil,
			"Run/ClaimTray was not touched"
		)
	end, function()
		leaveGarage(host)
	end)
end

----------------------------------------------------------------------------------------------

S["Collection: scroll bounds"] = function(host: Host)
	local name = "Collection: scroll bounds"
	local garage = comp(host, "garage")
	if not garage then
		verdict(host, name, false, "the garage component is not mounted")
		return
	end
	guarded(host, name, function()
		local cars = textCars()
		garage:setSource(cars, function()
			return { world = "Downtown", lapPay = 100, variants = { Gold = false, Chrome = false, Rainbow = false } }
		end, {})
		host.api.open("garage")
		for _, profile in host.api.profiles do
			useFrame(host, profile)
			host.wait(0.6)
			local problems: { string } = {}
			-- the grid: scroll to the end and the last card is whole inside the viewport
			local gridRoot = garage.root:FindFirstChild("CardGrid", true) :: Instance
			local scroll = gridRoot:FindFirstChild("Scroll") :: ScrollingFrame
			local before = scroll.AbsoluteCanvasSize.Y > scroll.AbsoluteSize.Y
			scroll.CanvasPosition = Vector2.new(0, 100000)
			host.wait(0.25)
			local lastBottom = -math.huge
			for _, parts in gridCards(garage.root) do
				lastBottom = math.max(lastBottom, parts.root.AbsolutePosition.Y + parts.root.AbsoluteSize.Y)
			end
			local viewportBottom = scroll.AbsolutePosition.Y + scroll.AbsoluteSize.Y
			if lastBottom > viewportBottom + 0.5 then
				table.insert(
					problems,
					string.format("the last card ends %.1f px below the viewport", lastBottom - viewportBottom)
				)
			end
			local panel = garage.root:FindFirstChild("Panel", true) :: GuiObject
			if viewportBottom > panel.AbsolutePosition.Y + panel.AbsoluteSize.Y + 0.5 then
				table.insert(problems, "the grid reaches below the panel")
			end
			scroll.CanvasPosition = Vector2.zero
			-- the detail: the facts end above the fixed bar and the last chip can be scrolled into view
			garage:selectCar("t1-1")
			host.wait(0.4)
			local ds = garage:getDebugState()
			if ds.detailGapToBar < -0.5 then
				table.insert(problems, string.format("the facts reach the fixed bar (gap %.1f)", ds.detailGapToBar))
			end
			local factsScroll = garage.root:FindFirstChild("FactsScroll", true) :: ScrollingFrame?
			local chip = garage.root:FindFirstChild("Chip_Rainbow", true) :: GuiObject?
			if factsScroll and chip then
				factsScroll.CanvasPosition = Vector2.new(0, 100000)
				host.wait(0.15)
				local chipBottom = chip.AbsolutePosition.Y + chip.AbsoluteSize.Y
				if chipBottom > factsScroll.AbsolutePosition.Y + factsScroll.AbsoluteSize.Y + 1 then
					table.insert(problems, "the Rainbow chip cannot be scrolled into view")
				end
			end
			report(
				host,
				"Scroll bounds (" .. profile .. ")",
				problems,
				string.format(
					"grid scrolls %s, last card whole, facts clear of the bar (gap %.1f), scrolls %s",
					tostring(before),
					ds.detailGapToBar,
					tostring(ds.detailScrolls)
				)
			)
			-- back to the list on a phone frame
			if ds.detailOpen then
				garage:selectTab("Downtown")
			end
		end
	end, function()
		leaveGarage(host)
	end)
end

----------------------------------------------------------------------------------------------

S["Collection: no developer words"] = function(host: Host)
	local name = "Collection: no developer words"
	local garage = comp(host, "garage")
	local detail = comp(host, "cardDetail")
	local trading = comp(host, "tradingSheet")
	local states = comp(host, "cardSheet")
	guarded(host, name, function()
		local problems: { string } = {}
		local scanned = 0
		local function scan(root: Instance, label: string, removed: boolean)
			for _, t in textObjects(root) do
				scanned += 1
				for _, word in DEVELOPER_WORDS do
					if containsWord(t.Text, word) then
						table.insert(problems, string.format("%s: %q contains %q", label, t.Text, word))
					end
				end
				if removed then
					for _, phrase in REMOVED_PHRASES do
						if string.find(string.lower(t.Text), phrase, 1, true) then
							table.insert(problems, string.format("%s: %q contains %q", label, t.Text, phrase))
						end
					end
				end
			end
		end
		for _, profile in { "Desktop", "PhoneLandscape" } do
			useFrame(host, profile)
			if garage then
				garage:setSource(nil)
				host.api.open("garage")
				host.wait(0.6)
				for _, id in { "rev6", "puglet", "hyperion", "longname", "missing" } do
					garage:selectCar(id)
					host.wait(0.3)
					scan(garage.root, "Garage " .. profile .. " " .. id, true)
				end
				for _, tab in { "Dusty", "Summit", "Downtown" } do
					garage:selectTab(tab)
					host.wait(0.25)
					scan(garage.root, "Garage " .. profile .. " " .. tab, true)
				end
				host.api.close("garage")
				host.wait(0.3)
			end
			if detail then
				for _, id in { "rev6", "hyperion" } do
					for _, owned in { true, false } do
						host.api.openCardDetail(id, owned)
						host.wait(0.5)
						scan(detail.root, "Detail " .. profile .. " " .. id, true)
						host.api.close("cardDetail")
						host.wait(0.25)
					end
				end
			end
		end
		if trading then
			host.api.open("tradingSheet")
			host.wait(1.0)
			scan(trading.root, "Trading sheet", false)
			host.api.close("tradingSheet")
			host.wait(0.3)
		end
		if states then
			host.api.open("cardSheet")
			host.wait(1.0)
			scan(states.root, "States sheet", false)
			host.api.close("cardSheet")
			host.wait(0.3)
		end
		report(
			host,
			name,
			problems,
			string.format(
				"%d texts scanned for %d developer words (the harness captions are not child-facing and are skipped)",
				scanned,
				#DEVELOPER_WORDS
			)
		)
	end, function()
		leaveGarage(host)
	end)
end

----------------------------------------------------------------------------------------------

S["Collection: leaks and reset"] = function(host: Host)
	local name = "Collection: leaks and reset"
	local garage = comp(host, "garage")
	if not garage then
		verdict(host, name, false, "the garage component is not mounted")
		return
	end
	guarded(host, name, function()
		host.api.setProfile("Desktop")
		host.wait(0.4)
		garage:setSource(nil)
		garage:setSort(nil)
		host.api.open("garage")
		host.wait(0.8)
		garage:selectCar("waffle")
		host.wait(0.3)
		local base = #garage.root:GetDescendants()
		local tickerBase = CarCard.tickerState().cards
		for _ = 1, 8 do
			for _, mode in { "Rarest", "LapPay", "Newest" } do
				garage:setSort(mode)
			end
			garage:setSort(nil)
			garage:selectTab("Dusty")
			garage:selectTab("Summit")
			garage:selectTab("Downtown")
			garage:selectCar("waffle")
			host.api.close("garage")
			host.wait(0.25)
			host.api.open("garage")
			host.wait(0.25)
		end
		host.wait(0.6)
		local after = #garage.root:GetDescendants()
		local ticker = CarCard.tickerState().cards
		verdict(
			host,
			"Garage: 8 rounds of sort, World switch and reopen leave the same instances",
			after == base and ticker == tickerBase,
			string.format("instances %d -> %d, card tickers %d -> %d", base, after, tickerBase, ticker)
		)
		host.api.close("garage")
		host.wait(0.3)
		-- a Garage built and destroyed here leaves nothing behind
		local api = host.api
		local ok, made = pcall(function()
			return GarageMock.new({
				store = host.store,
				screen = api.screen,
				layer = api.layers.Overlay,
				world = api.backdrop and api.backdrop.world,
				priority = api.priority,
			}, {})
		end)
		if not ok then
			verdict(host, "A temporary Garage", false, "could not be built: " .. tostring(made))
			return
		end
		local layerBefore = #api.layers.Overlay:GetDescendants()
		made:setSort("Rarest")
		made:selectTab("Dusty")
		made:selectTab("Downtown")
		host.wait(0.3)
		local mid = made:getDebugState().instances
		made:destroy()
		host.wait(0.2)
		local layerAfter = #api.layers.Overlay:GetDescendants()
		verdict(
			host,
			"A destroyed Garage leaves zero instances and no card ticker",
			mid > 0 and layerAfter < layerBefore and CarCard.tickerState().cards == tickerBase,
			string.format(
				"instances %d while alive, layer %d -> %d, card tickers %d",
				mid,
				layerBefore,
				layerAfter,
				CarCard.tickerState().cards
			)
		)
	end, function()
		leaveGarage(host)
	end)
end

return S
