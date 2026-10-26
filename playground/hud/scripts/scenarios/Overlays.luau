--!strict
-- PLAYGROUND ONLY (Lane 3 Round 3, W8; ledger R2-HM3 "finish style consistency on the retained overlays"). The
-- Toast stack, the Results card panels and the Milestones band were the three overlays still in the round 1 look
-- (dark navy bodies, a bare number). They are now arcade surfaces (kit fill, ONE dark outline, gloss). Every value
-- here is a synthetic fixture played through the preview store; nothing is saved, granted or bought. Each scenario
-- logs the numbers it checks and real PASS: / FAIL: lines (grep them).
--
--   Overlays: toast stack (six frames)       mounts, the run-view row and the Home spot, no touch-zone overlap, no
--                                            overlap with the protected road rectangle, ONE outline per surface, a
--                                            bright fill (no navy body), text >= 16 and never cut, the x2 / x99 tag
--   Overlays: results card (six frames)      the plates (rows and the Cash tally), the footer, no navy wells left,
--                                            ONE outline per surface, nothing nested, content above the footer,
--                                            inside the safe area, touch size, text, no rewards and many cars
--   Overlays: milestones band (six frames)   the gold band, its height against the protected rectangle, outline,
--                                            text, safe area, hides again
--   Overlays: leaks after destroy            a private copy of each overlay is built, exercised and destroyed:
--                                            the layer returns to its start; timers, connections and instances = 0
--   Overlays: reduced motion                 the toasts snap in, the results show at once, the band does not pop;
--                                            the normal path still slides, counts and pops
--   Overlays: specimen                       a timed tour for stills and video: toasts (Home), the milestone band
--                                            (run view, three in a row), the Results card
--
-- Component keys used (guarded; a missing one is reported, never skipped silently): toasts, milestones, results.
-- "Real" text size: a TextScaled label's real size is bounded below by its UITextSizeConstraint minimum and it is
-- only that small when TextFits is false, so both are read; a plain label reports TextSize itself.

local Players = game:GetService("Players")

local Prototype = Players.LocalPlayer
	:WaitForChild("PlayerScripts")
	:WaitForChild("Client")
	:WaitForChild("UI")
	:WaitForChild("Prototype")
local Motion = require(Prototype:WaitForChild("Motion"))
local PreviewTokens = require(Prototype:WaitForChild("PreviewTokens")) :: any
local RunLayout = require(Prototype:WaitForChild("Run"):WaitForChild("RunLayout")) :: any
local Milestones = require(Prototype:WaitForChild("Run"):WaitForChild("Milestones")) :: any
local ResultsCard = require(Prototype:WaitForChild("Screens"):WaitForChild("ResultsCard")) :: any
local Style = require(Prototype:WaitForChild("Screens"):WaitForChild("Style")) :: any
local ToastStack = require(Prototype:WaitForChild("Home"):WaitForChild("ToastStack")) :: any

type Host = { [string]: any }

local A = PreviewTokens.Arcade

local MIN_TEXT = 16 -- the approved minimum, design px
local TOUCH_MIN = 48 -- the approved touch minimum, design px
local WORDS = {
	"adapter",
	"schema",
	"catalog",
	"fixture",
	"runtime",
	"contract",
	"proposed",
	"tunable",
	"preview",
	"todo",
	"ids",
}

local function comp(host: Host, key: string): any
	return host.api.components and host.api.components[key]
end

-- TALLY ---------------------------------------------------------------------------------------------------------

type Tally = { check: (name: string, ok: boolean, detail: string) -> boolean, done: () -> () }

local function newTally(host: Host, label: string): Tally
	local passed, failed = 0, 0
	return {
		check = function(name: string, ok: boolean, detail: string): boolean
			if ok then
				passed += 1
			else
				failed += 1
			end
			host.log(string.format("%s: %s %s: %s", if ok then "PASS" else "FAIL", label, name, detail))
			return ok
		end,
		done = function()
			host.log(
				string.format(
					"%s: %s summary: %d passed, %d failed",
					if failed == 0 then "PASS" else "FAIL",
					label,
					passed,
					failed
				)
			)
		end,
	}
end

-- GEOMETRY ------------------------------------------------------------------------------------------------------

-- Overlap of two device-px rectangles (width, height; 0 when apart).
local function intersection(aPos: Vector2, aSize: Vector2, bPos: Vector2, bSize: Vector2): (number, number)
	local w = math.min(aPos.X + aSize.X, bPos.X + bSize.X) - math.max(aPos.X, bPos.X)
	local h = math.min(aPos.Y + aSize.Y, bPos.Y + bSize.Y) - math.max(aPos.Y, bPos.Y)
	return math.max(w, 0), math.max(h, 0)
end

local function rectOf(host: Host, g: GuiObject): (Vector2, Vector2)
	return host.api.screen:rectOf(g)
end

-- The part of a device rectangle that lies inside the protected road rectangle: (width, height) in DESIGN px.
local function protectedOverlap(host: Host, pos: Vector2, size: Vector2): (number, number)
	local profile = host.api.screen:profile()
	local prot = RunLayout.protectedRect(profile)
	local w, h = intersection(pos, size, prot.pos, prot.size)
	local s = host.api.screen:uiScale()
	return w / s, h / s
end

-- Inside the device's safe area (inset rectangle), 1 px of slack.
local function insideSafe(host: Host, pos: Vector2, size: Vector2): boolean
	local p = host.api.screen:profile()
	local i = p.insets
	return pos.X >= i.left - 1
		and pos.Y >= i.top - 1
		and pos.X + size.X <= p.size.X - i.right + 1
		and pos.Y + size.Y <= p.size.Y - i.bottom + 1
end

-- TEXT AND CONTRAST ---------------------------------------------------------------------------------------------

local function channel(c: number): number
	return if c <= 0.03928 then c / 12.92 else ((c + 0.055) / 1.055) ^ 2.4
end

local function luminance(c: Color3): number
	return 0.2126 * channel(c.R) + 0.7152 * channel(c.G) + 0.0722 * channel(c.B)
end

local function ratio(a: Color3, b: Color3): number
	local la, lb = luminance(a), luminance(b)
	return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05)
end

local function sample(seq: ColorSequence, t: number): Color3
	local kps = seq.Keypoints
	for i = 1, #kps - 1 do
		local a, b = kps[i], kps[i + 1]
		if t <= b.Time then
			local span = b.Time - a.Time
			local k = if span <= 0 then 0 else (t - a.Time) / span
			return a.Value:Lerp(b.Value, math.clamp(k, 0, 1))
		end
	end
	return kps[#kps].Value
end

-- The colour behind a label: the nearest ancestor with a solid-ish background (its gradient's middle when it has one).
local function behind(label: GuiObject): Color3
	local node: Instance? = label.Parent
	while node do
		if node:IsA("GuiObject") and node.BackgroundTransparency < 0.5 then
			local g = node:FindFirstChildOfClass("UIGradient")
			if g and g.Enabled then
				return sample(g.Color, 0.5)
			end
			return node.BackgroundColor3
		end
		node = node.Parent
	end
	return Color3.new(0, 0, 0)
end

local function shown(root: Instance, d: Instance): boolean
	local node: Instance? = d
	while node do
		if node:IsA("GuiObject") then
			if not node.Visible or node:GetAttribute("PreviewCaption") == true then
				return false
			end
		elseif node:IsA("LayerCollector") and not node.Enabled then
			return false
		end
		if node == root then
			break
		end
		node = node.Parent
	end
	return true
end

-- The approved kit's own measure, taken live from the token table: a white label against the middle of each fill an
-- approved button or banner uses (Arcade.button fills, the Tutorial banner and the Capture ribbon's Gold). A label on
-- these overlays must reach the lowest of them (or 4.5:1); the dark outline is how every kit label reads.
local KIT_FILLS = { "Rainbow", "Garage", "Missions", "Retry", "Settings", "Home", "Gold", "Green" }
local KIT_FLOOR = math.huge
local KIT_LOWEST = ""
local KIT_LINE = {}
for _, name in KIT_FILLS do
	local r = ratio(Color3.new(1, 1, 1), sample(A.Fill[name], 0.5))
	table.insert(KIT_LINE, string.format("%s %.2f", name, r))
	if r < KIT_FLOOR then
		KIT_FLOOR, KIT_LOWEST = r, name
	end
end

local function logKitContrast(host: Host)
	host.log(
		string.format(
			"INFO: kit contrast, white label on the middle of each approved fill: %s; floor %.2f:1 (%s)",
			table.concat(KIT_LINE, ", "),
			KIT_FLOOR,
			KIT_LOWEST
		)
	)
end

type Audit = {
	labels: number,
	minSize: number,
	unfit: { string },
	ellipsis: { string },
	words: { string },
	illegible: { string },
	minRatio: number,
}

-- Reads every visible text label under `root` (skipping the subtrees named in `skip`).
local function auditText(root: GuiObject, skip: { string }?): Audit
	local a: Audit =
		{ labels = 0, minSize = math.huge, unfit = {}, ellipsis = {}, words = {}, illegible = {}, minRatio = math.huge }
	for _, d in root:GetDescendants() do
		if not d:IsA("TextLabel") or d.Text == "" or d.TextTransparency >= 0.99 or not shown(root, d) then
			continue
		end
		local skipped = false
		if skip then
			for _, name in skip do
				if d:FindFirstAncestor(name) and d:FindFirstAncestor(name):IsDescendantOf(root) then
					skipped = true
				end
			end
		end
		if skipped then
			continue
		end
		a.labels += 1
		local size = d.TextSize
		if d.TextScaled then
			local c = d:FindFirstChildOfClass("UITextSizeConstraint")
			size = if c then c.MinTextSize else 0
		end
		a.minSize = math.min(a.minSize, size)
		local tag = d.Name .. "=" .. d.Text
		if not d.TextFits then
			table.insert(a.unfit, tag)
		end
		if
			d.TextTruncate ~= Enum.TextTruncate.None
			or string.find(d.Text, "…", 1, true)
			or string.find(d.Text, "...", 1, true)
		then
			table.insert(a.ellipsis, tag)
		end
		local lower = string.lower(d.Text)
		for _, w in WORDS do
			if string.find(lower, "%f[%a]" .. w .. "%f[%A]") then
				table.insert(a.words, tag)
			end
		end
		-- legible = 4.5:1 on the fill, or the kit's dark outline AND at least the approved kit's lowest fill contrast
		local face = d:FindFirstChildOfClass("UIGradient")
		local textColour = if face then sample(face.Color, 0.5) else d.TextColor3
		local r = ratio(textColour, behind(d))
		a.minRatio = math.min(a.minRatio, r)
		local stroke = d:FindFirstChildOfClass("UIStroke")
		local outlined = stroke ~= nil and luminance(stroke.Color) < 0.05 and stroke.Thickness >= 1.5
		if not (r >= 4.5 or (outlined and r >= KIT_FLOOR - 0.01)) then
			table.insert(a.illegible, string.format("%s (%.1f:1)", tag, r))
		end
	end
	if a.labels == 0 then
		a.minSize = 0
		a.minRatio = 0
	end
	return a
end

local function joined(list: { string }): string
	return if #list == 0 then "none" else table.concat(list, "; ")
end

-- Text checks as PASS / FAIL lines for one component on one frame.
local function textChecks(t: Tally, tag: string, a: Audit)
	t.check(
		tag .. " text size",
		a.labels > 0 and a.minSize >= MIN_TEXT,
		string.format("%d labels, smallest real size %s (min %d)", a.labels, tostring(a.minSize), MIN_TEXT)
	)
	t.check(
		tag .. " text not cut",
		#a.unfit == 0 and #a.ellipsis == 0,
		"does not fit: " .. joined(a.unfit) .. " | ellipsis: " .. joined(a.ellipsis)
	)
	t.check(tag .. " plain words", #a.words == 0, "developer words: " .. joined(a.words))
	t.check(
		tag .. " legible",
		#a.illegible == 0,
		string.format(
			"lowest text-on-fill contrast %.2f:1, approved kit floor %.2f:1 (%s); below it: %s",
			a.minRatio,
			KIT_FLOOR,
			KIT_LOWEST,
			joined(a.illegible)
		)
	)
end

-- SURFACES ------------------------------------------------------------------------------------------------------

type SurfaceRow = { name: string, outlines: number, gradients: number, gloss: boolean }

-- ONE outline per surface (a UIStroke on the frame itself), one fill gradient, and the gloss where `gloss` says.
local function surfaceChecks(t: Tally, tag: string, rows: { SurfaceRow }, gloss: { [string]: boolean }?)
	local bad = {}
	for _, s in rows do
		local needGloss = if gloss and gloss[s.name] ~= nil then gloss[s.name] else true
		if s.outlines ~= 1 or s.gradients ~= 1 or s.gloss ~= needGloss then
			table.insert(
				bad,
				string.format(
					"%s outlines=%d gradients=%d gloss=%s",
					s.name,
					s.outlines,
					s.gradients,
					tostring(s.gloss)
				)
			)
		end
	end
	t.check(
		tag .. " one outline per surface",
		#rows > 0 and #bad == 0,
		string.format("%d surfaces; wrong: %s", #rows, joined(bad))
	)
end

-- A heavy border (>= the button outline) on a non-text frame anywhere under `frame` would be nested inside it.
-- Icon art draws its own bands with strokes, so anything under an "Icon" holder is not a surface border.
local function nestedHeavy(frame: GuiObject): number
	local n = 0
	for _, d in frame:GetDescendants() do
		if d:IsA("UIStroke") and d.Thickness >= A.OutlineButton - 0.01 then
			local p = d.Parent
			if p and p:IsA("GuiObject") and not p:IsA("TextLabel") and not p:FindFirstAncestor("Icon") then
				n += 1
			end
		end
	end
	return n
end

-- RUN HELPERS ---------------------------------------------------------------------------------------------------

local function freshRun(host: Host)
	local store = host.store
	Motion.setOverride(nil)
	if store:get().mode == "Run" then
		store:setMode("Home")
	end
	host.enterRun()
	host.wait(0.4)
end

local function toHome(host: Host)
	local mode = host.store:get().mode
	if mode == "Results" then
		host.store:set("results", nil)
	end
	if mode ~= "Home" and host.store:setMode("Home") then
		host.store:set("run", nil)
	end
	host.api.applyMode()
end

local function typical(host: Host): { [string]: any }
	return {
		distance = 1240,
		roadCoins = 35,
		totalIncludesPickups = true,
		best = 1100,
		newBest = true,
		claimed = { host.car("rev6"), host.car("zoomurai") },
		earnings = 340,
		joyride = 50,
		milestones = 2,
		endReason = "Overheated",
	}
end

local function nothing(host: Host): { [string]: any }
	local _ = host
	return {
		distance = 85,
		roadCoins = 0,
		totalIncludesPickups = true,
		best = 1100,
		newBest = false,
		claimed = {},
		earnings = 0,
	}
end

local function many(host: Host): { [string]: any }
	local cars = {}
	for _, id in { "rev6", "puglet", "fishbowl", "rangy", "zoomurai", "hurrikan", "hyperion" } do
		table.insert(cars, host.car(id))
	end
	return {
		distance = 4820,
		roadCoins = 120,
		totalIncludesPickups = true,
		best = 4100,
		newBest = true,
		claimed = cars,
		earnings = 2150,
		joyride = 150,
		milestones = 5,
	}
end

-- Run -> Results with a payload, through the store's checked transitions, then the card.
local function present(host: Host, res: { [string]: any })
	host.enterRun()
	host.wait(0.6)
	host.store:set("results", res)
	host.store:setMode("Results")
	local card = comp(host, "results")
	if card and card.show then
		card:show(res, res.claimed)
	end
end

local S: { [string]: (Host) -> () } = {}

-- 1. TOAST STACK ------------------------------------------------------------------------------------------------

S["Overlays: toast stack (six frames)"] = function(host: Host)
	local t = newTally(host, "Toasts")
	logKitContrast(host)
	local original = host.api.screen:profile().name
	Motion.setOverride(nil)
	local stack = comp(host, "toasts")
	if
		not t.check(
			"mounted",
			stack ~= nil,
			'components.toasts (mount line: mount("toasts", { "Home", "ToastStack" }, "Feedback"))'
		)
	then
		t.done()
		return
	end
	toHome(host)
	-- the Home spot first: unchanged placement, away from the touch zones (the stack asks for no slot in Home)
	for _, profile in host.api.profiles do
		host.api.setProfile(profile)
		stack:clear()
		host.wait(0.3)
		local d = stack:getDebugState()
		t.check(
			profile .. " Home spot",
			d.placement == "Home" and d.maxVisible == PreviewTokens.Motion.ToastMaxVisible and d.reservedOverlap == nil,
			string.format(
				"placement %s, up to %d visible, touch-zone overlap %s",
				tostring(d.placement),
				d.maxVisible,
				tostring(d.reservedOverlap)
			)
		)
	end
	-- the run view: the Upper row, three tones, one duplicate
	freshRun(host)
	for _, profile in host.api.profiles do
		host.api.setProfile(profile)
		stack:clear()
		host.wait(0.3)
		host.emit("Toast", { text = "Dusty Highway is coming soon", tone = "Info" })
		host.emit("Toast", { text = "New paint unlocked", tone = "Unlock" })
		host.emit("Toast", { text = "Car added to your Garage", tone = "Success" })
		host.emit("Toast", { text = "Dusty Highway is coming soon", tone = "Info" }) -- coalesces: x2
		host.wait(0.8)
		local d = stack:getDebugState()
		local tag = profile
		t.check(
			tag .. " run row and cap",
			d.placement == "Upper" and d.shownCount == d.maxVisible and d.queueCount == 3 - d.maxVisible,
			string.format(
				"placement %s, %d shown of at most %d, %d waiting (expected %d), fixed-height rows %s",
				tostring(d.placement),
				d.shownCount,
				d.maxVisible,
				d.queueCount,
				3 - d.maxVisible,
				tostring(d.fixedHeight)
			)
		)
		local first = d.shown[1]
		t.check(
			tag .. " duplicate coalesced",
			first ~= nil and first.count == 2,
			string.format(
				"first toast %q count %s (expected 2)",
				tostring(first and first.text),
				tostring(first and first.count)
			)
		)
		local zones, wBest, hBest = {}, 0, 0
		local inside = true
		for _, s in d.shown do
			local zone = host.api.screen:overlapsReserved(s.devicePos, s.deviceSize)
			if zone then
				table.insert(zones, zone)
			end
			local w, h = protectedOverlap(host, s.devicePos, s.deviceSize)
			if w > 0.5 and h > 0.5 and w * h > wBest * hBest then
				wBest, hBest = w, h
			end
			inside = inside and insideSafe(host, s.devicePos, s.deviceSize)
		end
		t.check(tag .. " touch zones clear", #zones == 0, "overlaps: " .. joined(zones))
		t.check(
			tag .. " protected road rectangle clear",
			wBest == 0 or hBest == 0,
			string.format("overlap %.0f x %.0f design px (0 = clear)", wBest, hBest)
		)
		t.check(tag .. " inside the safe area", inside, "every visible toast")
		surfaceChecks(t, tag, d.surfaces, nil)
		-- a bright arcade fill on every visible body (no navy body): the fill's middle luminance
		local darkest = 1
		for _, g in stack.root:GetDescendants() do
			if g:IsA("Frame") and g.Name == "Body" and shown(stack.root, g) then
				local grad = g:FindFirstChildOfClass("UIGradient")
				if grad then
					darkest = math.min(darkest, luminance(sample(grad.Color, 0.5)))
				end
			end
		end
		t.check(
			tag .. " bright fill",
			darkest > 0.15,
			string.format("darkest visible body fill luminance %.2f (the old Info navy was 0.03)", darkest)
		)
		textChecks(t, tag, auditText(stack.root))
	end
	-- boundaries on the narrowest frame: long text, the two-digit tag, 99, the bounded queue
	host.api.setProfile("PhoneSmall")
	stack:clear()
	host.wait(0.3)
	stack:push("Car added to your Garage and a new paint is ready to try", "Info")
	host.wait(0.4)
	local long = stack:getDebugState()
	local longFits = long.shown[1] ~= nil and long.shown[1].textFits == true
	t.check(
		"long text wraps and fits",
		longFits,
		string.format("height %s, fits %s", tostring(long.shown[1] and long.shown[1].height), tostring(longFits))
	)
	stack:clear()
	host.wait(0.2)
	for _ = 1, 12 do
		stack:push("Lap complete", "Success")
	end
	host.wait(0.3)
	local tag12 = nil
	for _, c in stack.root:GetDescendants() do
		if
			c:IsA("TextLabel")
			and c.Name == "Text"
			and c.Parent
			and c.Parent.Name == "Count"
			and shown(stack.root, c)
		then
			tag12 = c
		end
	end
	t.check(
		"two-digit count tag",
		tag12 ~= nil and tag12.Text == "×12" and tag12.TextFits,
		string.format("tag %s, fits %s", tostring(tag12 and tag12.Text), tostring(tag12 and tag12.TextFits))
	)
	for _ = 1, 100 do
		stack:push("Lap complete", "Success")
	end
	host.wait(0.3)
	tag12 = nil
	for _, c in stack.root:GetDescendants() do
		if
			c:IsA("TextLabel")
			and c.Name == "Text"
			and c.Parent
			and c.Parent.Name == "Count"
			and shown(stack.root, c)
		then
			tag12 = c
		end
	end
	t.check(
		"count stops at 99",
		tag12 ~= nil and tag12.Text == "×99" and tag12.TextFits,
		string.format("tag %s, fits %s", tostring(tag12 and tag12.Text), tostring(tag12 and tag12.TextFits))
	)
	stack:clear()
	host.wait(0.2)
	for i = 1, 12 do
		stack:push("Queue test " .. i, "Info")
	end
	local q = stack:getDebugState()
	t.check(
		"queue stays bounded",
		q.queueCount <= q.queueLimit and q.dropped >= 1,
		string.format("%d waiting (limit %d), %d dropped", q.queueCount, q.queueLimit, q.dropped)
	)
	stack:clear()
	host.api.setProfile(original)
	toHome(host)
	t.done()
end

-- 2. RESULTS CARD -----------------------------------------------------------------------------------------------

local function resultsChecks(host: Host, t: Tally, card: any, tag: string, expectRows: { string })
	local d = card:getDebugState()
	t.check(
		tag .. " open",
		d.open == true,
		string.format("heading %q, kind %s", tostring(d.reasonHeading), tostring(d.kind))
	)
	local missing = {}
	for _, row in expectRows do
		if not table.find(d.rows, row) then
			table.insert(missing, row)
		end
	end
	t.check(
		tag .. " rows",
		#missing == 0,
		string.format("visible %s; missing %s", table.concat(d.rows, ", "), joined(missing))
	)
	surfaceChecks(t, tag, d.surfaces, { Panel = false })
	-- no dark navy well is left on the card, and nothing heavy is nested inside a plate
	local wells, nested = 0, 0
	for _, f in card.root:GetDescendants() do
		if f:IsA("Frame") and f.BackgroundColor3 == Style.Well and f.BackgroundTransparency < 1 then
			wells += 1
		end
		if f:IsA("Frame") and (string.sub(f.Name, 1, 4) == "Row_" or f.Name == "Cash") then
			nested += nestedHeavy(f)
		end
	end
	t.check(tag .. " no navy wells", wells == 0, string.format("%d frames still use the old well colour", wells))
	t.check(
		tag .. " nothing heavy nested in a plate",
		nested == 0,
		string.format("%d heavy borders inside plates", nested)
	)
	t.check(
		tag .. " content above footer",
		d.separated == true,
		string.format("content bottom %.0f, footer top %.0f", d.contentBottom, d.footerTop)
	)
	-- the panel (and its lip) inside the safe area; the two buttons are at least the touch size
	local panel = card.root:FindFirstChild("Panel", true) :: GuiObject?
	if panel then
		local pos, size = rectOf(host, panel)
		local lip = panel:FindFirstChild("Lip") :: GuiObject?
		local lipBottom = pos.Y + size.Y
		if lip then
			local lipPos, lipSize = rectOf(host, lip)
			lipBottom = math.max(lipBottom, lipPos.Y + lipSize.Y)
		end
		local p = host.api.screen:profile()
		local ok = insideSafe(host, pos, Vector2.new(size.X, lipBottom - pos.Y))
		t.check(
			tag .. " panel inside the safe area",
			ok,
			string.format("panel %.0fx%.0f at (%.0f, %.0f) on %s", size.X, size.Y, pos.X, pos.Y, p.name)
		)
	else
		t.check(tag .. " panel inside the safe area", false, "Panel frame not found")
	end
	local s = host.api.screen:uiScale()
	local bad = {}
	local boxes = {}
	for _, name in { "Retry", "GoHome" } do
		local b = card.root:FindFirstChild(name, true) :: GuiObject?
		if b then
			local pos, size = rectOf(host, b)
			table.insert(boxes, { pos = pos, size = size })
			if size.Y / s < TOUCH_MIN - 0.5 then
				table.insert(bad, string.format("%s %.0f px tall", name, size.Y / s))
			end
		else
			table.insert(bad, name .. " missing")
		end
	end
	if #boxes == 2 then
		local w, h = intersection(boxes[1].pos, boxes[1].size, boxes[2].pos, boxes[2].size)
		if w > 0.5 and h > 0.5 then
			table.insert(bad, "buttons overlap")
		end
	end
	t.check(tag .. " buttons", #bad == 0 and #boxes == 2, "touch size >= 48 design px, apart: " .. joined(bad))
	-- the card is a full-screen modal over the run view, so it necessarily covers the assumed touch zones: numbers only
	local over = {}
	for i, b in boxes do
		local zone = host.api.screen:overlapsReserved(b.pos, b.size)
		if zone then
			table.insert(over, (if i == 1 then "RETRY" else "GO HOME") .. " over " .. zone)
		end
	end
	host.log(
		string.format(
			"INFO: Results %s modal buttons over assumed touch zones: %s (a modal, so reported only)",
			tag,
			joined(over)
		)
	)
	textChecks(t, tag, auditText(card.root, { "ClaimGrid" }))
end

S["Overlays: results card (six frames)"] = function(host: Host)
	local t = newTally(host, "Results")
	logKitContrast(host)
	local original = host.api.screen:profile().name
	Motion.setOverride(nil)
	local card = comp(host, "results")
	if
		not t.check(
			"mounted",
			card ~= nil,
			'components.results (mount line: mount("results", { "Screens", "ResultsCard" }, "Modal", ...))'
		)
	then
		t.done()
		return
	end
	host.api.setProfile("Desktop")
	toHome(host)
	present(host, typical(host))
	host.wait(0.6)
	card:skip()
	host.wait(0.5)
	for _, profile in host.api.profiles do
		host.api.setProfile(profile)
		host.wait(0.5)
		resultsChecks(host, t, card, profile, { "Row_Distance", "Row_Best", "Cash" })
	end
	-- boundary payloads on the narrowest frame: no rewards at all, and many cars
	host.api.setProfile("PhoneSmall")
	card:hide()
	toHome(host)
	present(host, nothing(host))
	host.wait(0.6)
	card:skip()
	host.wait(0.5)
	resultsChecks(host, t, card, "PhoneSmall no rewards", { "Row_Distance", "Row_Best", "Cash" })
	card:hide()
	toHome(host)
	present(host, many(host))
	host.wait(0.6)
	card:skip()
	host.wait(0.6)
	resultsChecks(host, t, card, "PhoneSmall many cars", { "Row_Distance", "Row_Best", "Cash" })
	card:hide()
	toHome(host)
	host.api.setProfile(original)
	t.done()
end

-- 3. MILESTONES BAND --------------------------------------------------------------------------------------------

S["Overlays: milestones band (six frames)"] = function(host: Host)
	local t = newTally(host, "Milestones")
	logKitContrast(host)
	local original = host.api.screen:profile().name
	Motion.setOverride(nil)
	local ms = comp(host, "milestones")
	if
		not t.check(
			"mounted",
			ms ~= nil,
			'components.milestones (mount line: mount("milestones", { "Run", "Milestones" }, "Feedback"))'
		)
	then
		t.done()
		return
	end
	freshRun(host)
	local stack = comp(host, "toasts")
	for _, profile in host.api.profiles do
		host.api.setProfile(profile)
		if stack then
			stack:clear() -- the toast stack shares the Upper slot
		end
		host.wait(0.4)
		host.emit("Milestone", { text = "1 KM!" })
		host.wait(0.5)
		local d = ms:getDebugState()
		local tag = profile
		t.check(tag .. " shows", d.showing == "1 KM!", string.format("showing %s", tostring(d.showing)))
		t.check(
			tag .. " band size",
			d.bandHeight >= 36 and d.bandHeight <= 52 and d.textSize >= 22,
			string.format("band %.0f design px tall (36 to 52), number %.0f px", d.bandHeight, d.textSize)
		)
		surfaceChecks(t, tag, {
			{
				name = "Band",
				outlines = d.surface.outlines,
				gradients = d.surface.gradients,
				gloss = d.surface.gloss,
			},
		}, nil)
		local holder = ms.root:FindFirstChild("Milestone") :: GuiObject
		local pos, size = rectOf(host, holder)
		local zone = host.api.screen:overlapsReserved(pos, size)
		t.check(tag .. " touch zones clear", zone == nil, "overlaps: " .. tostring(zone))
		local w, h = protectedOverlap(host, pos, size)
		t.check(
			tag .. " protected road rectangle clear",
			w == 0 or h == 0,
			string.format(
				"overlap %.0f x %.0f design px (0 = clear); the debug state says %.0f deep, upper row at y %.0f, band %.0f tall",
				w,
				h,
				d.protectedOverlapY,
				d.upperY,
				d.bandHeight
			)
		)
		t.check(
			tag .. " inside the safe area",
			insideSafe(host, pos, size),
			string.format("band %.0fx%.0f at (%.0f, %.0f)", size.X, size.Y, pos.X, pos.Y)
		)
		local text = holder:FindFirstChild("Text", true) :: TextLabel
		local flag = holder:FindFirstChild("Flag", true) :: GuiObject
		local pad = 8 * host.api.screen:uiScale() * host.api.screen:fitScale() -- the 8 design px gap, in screen px
		local content = text.AbsoluteSize.X + flag.AbsoluteSize.X + pad
		t.check(
			tag .. " content inside the band",
			content <= holder.AbsoluteSize.X + 1,
			string.format("flag + number %.0f px, band %.0f px", content, holder.AbsoluteSize.X)
		)
		textChecks(t, tag, auditText(ms.root))
		host.wait(1.6)
		local after = ms:getDebugState()
		t.check(
			tag .. " hides again",
			after.showing == nil and not holder.Visible,
			string.format("showing %s, visible %s", tostring(after.showing), tostring(holder.Visible))
		)
	end
	-- boundary: the longest plausible text, on the narrowest frame
	host.api.setProfile("PhoneSmall")
	host.wait(0.4)
	host.emit("Milestone", { text = "100 KM!" })
	host.wait(0.5)
	local holder = ms.root:FindFirstChild("Milestone") :: GuiObject
	local text = holder:FindFirstChild("Text", true) :: TextLabel
	local flag = holder:FindFirstChild("Flag", true) :: GuiObject
	local pad = 8 * host.api.screen:uiScale() * host.api.screen:fitScale()
	t.check(
		"long number fits",
		text.TextFits and text.AbsoluteSize.X + flag.AbsoluteSize.X + pad <= holder.AbsoluteSize.X + 1,
		string.format("%s, number %.0f px wide, band %.0f px", text.Text, text.AbsoluteSize.X, holder.AbsoluteSize.X)
	)
	host.wait(1.6)
	host.api.setProfile(original)
	toHome(host)
	t.done()
end

-- 4. LEAKS ------------------------------------------------------------------------------------------------------

-- A private copy of an overlay (no arbiter, so it cannot disturb the mounted one) is built on the same layer,
-- exercised while it is mid-animation, destroyed, and the layer must hold exactly what it held before.
local function leakCase(
	host: Host,
	t: Tally,
	label: string,
	layerName: string,
	build: (ctx: any) -> any,
	exercise: (obj: any) -> ()
)
	local layer = host.api.layers[layerName]
	local before = #layer:GetDescendants()
	local ctx =
		{ store = host.store, screen = host.api.screen, layer = layer, world = host.api.backdrop.world, priority = nil }
	local obj = build(ctx)
	exercise(obj)
	host.wait(0.3)
	local live = #layer:GetDescendants()
	obj:destroy()
	host.wait(0.5)
	local after = #layer:GetDescendants()
	t.check(
		label .. " layer back to start",
		after == before,
		string.format("%d before, %d while live, %d after destroy", before, live, after)
	)
	local ok, d = pcall(function()
		return obj:getDebugState()
	end)
	if ok and type(d) == "table" then
		local timers = d.timers or 0
		local conns = d.connections or 0
		local inst = d.instances or 0
		t.check(
			label .. " timers, connections, instances",
			timers == 0 and conns == 0 and inst == 0,
			string.format(
				"timers %s, connections %s, instances %s (all 0 after destroy)",
				tostring(timers),
				tostring(conns),
				tostring(inst)
			)
		)
	else
		t.check(
			label .. " timers, connections, instances",
			false,
			"getDebugState failed after destroy: " .. tostring(d)
		)
	end
	-- a second destroy is harmless
	local again = pcall(function()
		obj:destroy()
	end)
	t.check(label .. " destroy twice", again, "no error")
end

S["Overlays: leaks after destroy"] = function(host: Host)
	local t = newTally(host, "Leaks")
	Motion.setOverride(nil)
	freshRun(host)
	leakCase(host, t, "Toast stack", "Feedback", function(ctx: any)
		return ToastStack.new(ctx)
	end, function(obj: any)
		obj:push("Car added to your Garage", "Success")
		obj:push("New paint unlocked", "Unlock")
		obj:push("Dusty Highway is coming soon", "Info")
		obj:push("Car added to your Garage", "Success")
		host.wait(0.4)
	end)
	leakCase(host, t, "Milestones band", "Feedback", function(ctx: any)
		return Milestones.new(ctx)
	end, function(obj: any)
		obj:show("500 m!")
		host.wait(0.4)
	end)
	leakCase(host, t, "Results card", "Modal", function(ctx: any)
		return ResultsCard.new(ctx, {})
	end, function(obj: any)
		local res = typical(host)
		obj:show(res, res.claimed)
		host.wait(0.6)
	end)
	toHome(host)
	t.done()
end

-- 5. REDUCED MOTION ---------------------------------------------------------------------------------------------

S["Overlays: reduced motion"] = function(host: Host)
	local t = newTally(host, "Reduced motion")
	local stack, ms, card = comp(host, "toasts"), comp(host, "milestones"), comp(host, "results")
	if not t.check("mounted", stack ~= nil and ms ~= nil and card ~= nil, "toasts, milestones and results") then
		t.done()
		return
	end
	host.api.setProfile("Desktop")
	freshRun(host)
	-- toasts: the same toast sampled 0.05 s and 0.5 s after it arrives; reduced = no slide, normal = it slides in
	local function slide(label: string, reduced: boolean)
		Motion.setOverride(if reduced then true else nil)
		stack:clear()
		host.wait(0.3)
		host.emit("Toast", { text = "Car added to your Garage " .. label, tone = "Success" })
		host.wait(0.08)
		local early = stack:getDebugState().shown[1]
		host.wait(0.5)
		local late = stack:getDebugState().shown[1]
		if not (early and late) then
			return nil
		end
		return (early.devicePos - late.devicePos).Magnitude
	end
	local still = slide("(reduced)", true)
	t.check(
		"toasts snap in",
		still ~= nil and still < 0.5,
		string.format("moved %s device px between 0.05 s and 0.5 s (expected 0)", tostring(still))
	)
	local moving = slide("(normal)", false)
	t.check(
		"toasts still slide in normally",
		moving ~= nil and moving >= 1,
		string.format("moved %s device px (expected a visible slide)", tostring(moving))
	)
	stack:clear()
	-- milestones: reduced = a fade only (no pop scale); normal = the pop exists
	Motion.setOverride(true)
	host.wait(0.3)
	host.emit("Milestone", { text = "500 m!" })
	host.wait(0.06)
	local pop = ms.root:FindFirstChild("Pop", true) :: UIScale?
	t.check(
		"band does not pop",
		pop == nil or pop.Scale == 1,
		string.format("pop scale %s (expected none or 1)", tostring(pop and pop.Scale))
	)
	host.wait(1.6)
	Motion.setOverride(nil)
	host.emit("Milestone", { text = "1 KM!" })
	host.wait(0.06)
	pop = ms.root:FindFirstChild("Pop", true) :: UIScale?
	t.check("band still pops normally", pop ~= nil, string.format("pop scale %s", tostring(pop and pop.Scale)))
	host.wait(1.6)
	-- results: reduced = the final values at once; normal = a reveal and a count
	Motion.setOverride(true)
	present(host, typical(host))
	host.wait(0.15)
	local r = card:getDebugState()
	t.check(
		"results show at once",
		r.open == true and r.revealing == false and r.buttonsEnabled == true and r.shownEarnings == r.earnings,
		string.format(
			"open %s, revealing %s, buttons %s, cash %s of %s",
			tostring(r.open),
			tostring(r.revealing),
			tostring(r.buttonsEnabled),
			tostring(r.shownEarnings),
			tostring(r.earnings)
		)
	)
	card:hide()
	toHome(host)
	Motion.setOverride(nil)
	present(host, typical(host))
	host.wait(0.3)
	r = card:getDebugState()
	t.check(
		"results still reveal normally",
		r.revealing == true,
		string.format(
			"revealing %s, cash %s of %s",
			tostring(r.revealing),
			tostring(r.shownEarnings),
			tostring(r.earnings)
		)
	)
	card:skip()
	host.wait(0.3)
	card:hide()
	toHome(host)
	Motion.setOverride(nil)
	t.done()
end

-- 6. SPECIMEN ---------------------------------------------------------------------------------------------------

S["Overlays: specimen"] = function(host: Host)
	Motion.setOverride(nil)
	local stack, ms, card = comp(host, "toasts"), comp(host, "milestones"), comp(host, "results")
	if not (stack and ms and card) then
		host.log("FAIL: Overlays specimen: toasts, milestones and results must all be mounted")
		return
	end
	local profile = host.api.screen:profile().name
	-- Stage 1 (Home): three toasts, two visible and one waiting; the first two are re-sent so they stay up and show the tag
	toHome(host)
	stack:clear()
	host.wait(0.4)
	host.emit("Toast", { text = "Dusty Highway is coming soon", tone = "Info" })
	host.emit("Toast", { text = "New paint unlocked", tone = "Unlock" })
	host.emit("Toast", { text = "Car added to your Garage", tone = "Success" })
	host.log("SPECIMEN: toast stack on " .. profile .. " (Info and Unlock up, Success waiting): capture now, 7 s")
	for _ = 1, 4 do
		host.wait(1.8)
		host.emit("Toast", { text = "Dusty Highway is coming soon", tone = "Info" })
		host.emit("Toast", { text = "New paint unlocked", tone = "Unlock" })
	end
	host.log("SPECIMEN: the waiting Success toast shows next (2.5 s)")
	host.wait(4.5)
	stack:clear()
	-- Stage 2 (run view): three milestone bands in a row (each stays 1.2 s)
	freshRun(host)
	for _, text in { "500 m!", "1 KM!", "2 KM!" } do
		host.log("SPECIMEN: milestone band " .. text .. " on " .. profile .. " (1.2 s): capture now")
		host.emit("Milestone", { text = text })
		host.wait(2)
	end
	-- Stage 3: the Results card, reveal skipped, held for a still
	present(host, typical(host))
	host.wait(0.8)
	card:skip()
	host.log("SPECIMEN: Results card on " .. profile .. " (plates, footer, buttons): capture now, 6 s")
	host.wait(6)
	card:hide()
	toHome(host)
	host.log("SPECIMEN: done")
end

return S
