--!strict
-- BETA-ONLY, STUDIO-ONLY: the end-to-end look test (Round 8, C-02 and C-03). The client half of ServerStorage.CarHopBetaSelfTest "look"
-- (src/server/Beta/BetaLookTest). It goes through the REAL path a player takes and then asserts on the car in the run itself:
--   1. equips a paint, a decal, wheels and a trail through the real BuyStyle and EquipStyle remotes (StyleState.buy / .equip) and
--      picks a ride car through the real PickRideCar remote (RidePick.ask);
--   2. starts a run through the real launch pad: LaunchPad.enter and the launch card's START (CarHopBetaControl "launch"), which calls
--      the real StartRun remote;
--   3. waits for the run car (the model Lane3Ridden = true on Workspace.Lane1_RunZone.Traffic) and checks ON THAT CAR: the paint shell is
--      there and its drawn colour is the paint's; the decal instances sit on its body; its own wheels are hidden and the new wheel
--      parts are there; the trail's emitters, ribbons and beams exist and are enabled; and it is the car that was picked;
--   4. hops (the real requestHop: leap, then dive) and checks the trail MOVED to the new car and the new car kept its own paint,
--      decals and wheels (and the car left behind has no trail).
-- Every check is a PASS or FAIL line; a wait that runs out is a FAIL with its reason, never a pass. The server half grants the test
-- Cash on a TEST save only (Mock store) and prints the lines.
--
--   BetaLookTest.run(ctx) -> { string }      ctx = { control: (string, any?) -> any, debugState: () -> any?, hop: () -> () }

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local BetaConfig = require(ReplicatedStorage.Shared.Beta.BetaConfig)
local Catalog = require(ReplicatedStorage.Shared.UI.CosmeticPreviewCatalog)
local UI = script.Parent.Parent:WaitForChild("UI")
local RidePick = require(UI.Prototype.RidePick)
local StyleState = require(UI.Prototype.StyleState)

local BetaLookTest = {}

export type Context = {
	control: (command: string, arg: any?) -> any,
	debugState: () -> any?,
	hop: () -> (),
}

-- the four things worn, and the car picked (the test save owns Putter and Pizza Runner)
local WEAR: { { tab: string, id: string } } = {
	{ tab = "Paint", id = "fresh_lime" },
	{ tab = "Decals", id = "flames" },
	{ tab = "Wheels", id = "split_five" },
	{ tab = "Trails", id = "bubble_pop" },
}
local RIDE = "Pizza Runner"

local player = Players.LocalPlayer

local function waitFor(seconds: number, fn: () -> boolean): boolean
	local t0 = os.clock()
	while os.clock() - t0 < seconds do
		if fn() then
			return true
		end
		task.wait(0.1)
	end
	return fn()
end

local function styleAttribute(): any
	local text = player:GetAttribute(BetaConfig.StyleAttribute)
	if type(text) ~= "string" then
		return nil
	end
	local ok, data = pcall(function()
		return game:GetService("HttpService"):JSONDecode(text)
	end)
	return if ok then data else nil
end

local function traffic(): Instance?
	local zone = Workspace:FindFirstChild("Lane1_RunZone")
	return zone and zone:FindFirstChild("Traffic")
end

-- the car the player is on (Lane3Ridden is set by BetaRun.client when the run boards a car)
local function ridden(): Model?
	local folder = traffic()
	if folder then
		for _, m in folder:GetChildren() do
			if m:IsA("Model") and m:GetAttribute("Lane3Ridden") == true then
				return m
			end
		end
	end
	return nil
end

-- Reads the colour the paint shell is drawn in (its EditableImage), averaged over the painted pixels.
local function paintColour(shell: MeshPart): (Color3?, string)
	local ok, result = pcall(function(): Color3?
		local image = (shell.TextureContent :: any).Object
		if image == nil then
			return nil
		end
		local size = (image :: any).Size :: Vector2
		local pixels = (image :: any):ReadPixelsBuffer(Vector2.zero, size) :: buffer
		local r, g, b, n = 0, 0, 0, 0
		for i = 0, size.X * size.Y - 1 do
			local o = i * 4
			if buffer.readu8(pixels, o + 3) == 255 then
				r += buffer.readu8(pixels, o)
				g += buffer.readu8(pixels, o + 1)
				b += buffer.readu8(pixels, o + 2)
				n += 1
			end
		end
		if n == 0 then
			return nil
		end
		return Color3.fromRGB(r / n, g / n, b / n)
	end)
	if ok and result then
		return result :: Color3, "ok"
	end
	return nil, if ok then "no drawn pixels" else tostring(result)
end

-- How many live trail parts (particle emitters, ribbons, beams) are on the part the applier marked as a trail holder (the attribute
-- CarLookTrail), and how many of those are enabled.
local function trailParts(root: Instance): (number, number)
	local total, enabled = 0, 0
	for _, holder in root:GetDescendants() do
		if holder:IsA("BasePart") and holder:GetAttribute("CarLookTrail") ~= nil then
			for _, d in holder:GetDescendants() do
				if d:IsA("ParticleEmitter") or d:IsA("Trail") or d:IsA("Beam") then
					total += 1
					if (d :: any).Enabled then
						enabled += 1
					end
				end
			end
		end
	end
	return total, enabled
end

-- Parts a car has that the showroom model does not: the wheel models and rims the look added.
local function addedParts(rc: Instance, carName: string): number
	local cars = ReplicatedStorage:FindFirstChild("Cars")
	local source = cars and cars:FindFirstChild(carName)
	local known: { [string]: boolean } = {}
	if source then
		for _, d in source:GetDescendants() do
			known[d.Name] = true
		end
	end
	local n = 0
	for _, d in rc:GetDescendants() do
		if
			d:IsA("BasePart")
			and not known[d.Name]
			and d.Name ~= "BodyPaint"
			and d.Name ~= "PaintWash"
			and d.Transparency < 1
		then
			n += 1
		end
	end
	return n
end

local function hidden(rc: Instance): (number, number)
	local own, hiddenOwn = 0, 0
	for _, d in rc:GetDescendants() do
		if d:IsA("BasePart") and string.find(d.Name, "wheel", 1, true) then
			own += 1
			if d.Transparency >= 1 then
				hiddenOwn += 1
			end
		end
	end
	return own, hiddenOwn
end

function BetaLookTest.run(ctx: Context): { string }
	local lines: { string } = {}
	local fails = 0
	local function check(name: string, ok: boolean, detail: any?)
		if not ok then
			fails += 1
		end
		table.insert(
			lines,
			string.format(
				"%s %s%s",
				if ok then "PASS" else "FAIL",
				name,
				if detail ~= nil then ": " .. tostring(detail) else ""
			)
		)
	end
	local function done(): { string }
		table.insert(
			lines,
			string.format("%s end-to-end look test: %d check(s) failed", if fails == 0 then "PASS" else "FAIL", fails)
		)
		return lines
	end

	-- 1. the real remotes ---------------------------------------------------------------------------------------------------
	local t0 = os.clock()
	while player:GetAttribute("Lane3LoadingDone") ~= true and os.clock() - t0 < 40 do
		task.wait(0.25)
	end
	if not waitFor(15, function()
		return styleAttribute() ~= nil
	end) then
		check("the save's style reaches the client (BetaStyle attribute)", false, "no attribute after 15 s")
		return done()
	end
	for _, w in WEAR do
		local item = Catalog.byId(w.tab :: any, w.id)
		check(w.tab .. " item " .. w.id .. " exists in the catalog", item ~= nil, nil)
		StyleState.buy(w.tab, w.id)
		local owned = waitFor(8, function()
			local a = styleAttribute()
			return a ~= nil and table.find(a.o, w.id) ~= nil
		end)
		check("BuyStyle " .. w.id .. " is answered: the server lists it as owned", owned, nil)
		StyleState.equip(w.tab, w.id)
		local worn = waitFor(8, function()
			local a = styleAttribute()
			return a ~= nil and a.e ~= nil and a.e[w.tab] == w.id
		end)
		check("EquipStyle " .. w.id .. " is answered: the server says it is worn", worn, nil)
	end
	RidePick.ask(RIDE)
	check(
		"PickRideCar " .. RIDE .. " is answered: BetaRideCar says so",
		waitFor(8, function()
			return player:GetAttribute(RidePick.Attribute) == RIDE
		end),
		player:GetAttribute(RidePick.Attribute)
	)
	check(
		"the launch card's car follows the saved pick",
		waitFor(4, function()
			return StyleState.car() == RIDE
		end),
		StyleState.car()
	)

	-- 2. the real launch --------------------------------------------------------------------------------------------------------
	ctx.control("launch", "Downtown")
	local boarded = waitFor(30, function()
		return ridden() ~= nil
	end)
	check("a run starts from the launch card's START and boards a car", boarded, nil)
	if not boarded then
		return done()
	end
	local car = ridden() :: Model
	local rc: Instance? = nil
	waitFor(8, function()
		rc = car:FindFirstChild("RealCar")
		return rc ~= nil
	end)
	check("the run car is a showroom car (a RealCar rig)", rc ~= nil, nil)
	if not rc then
		return done()
	end
	local rcModel = rc :: Instance
	check(
		"it is the car that was picked (" .. RIDE .. ")",
		rcModel:GetAttribute("CarName") == RIDE,
		rcModel:GetAttribute("CarName")
	)

	-- 3. the look on the run car ---------------------------------------------------------------------------------------------
	local shell = rcModel:FindFirstChild("BodyPaint") :: MeshPart?
	check("C-02 paint: the paint shell is on the run car", shell ~= nil, nil)
	if shell then
		local colour, why = paintColour(shell)
		local want = (Catalog.byId("Paint", "fresh_lime") :: Catalog.Item).colours[1]
		if colour then
			local h1, s1 = colour:ToHSV()
			local h2 = want:ToHSV()
			local diff = math.abs(h1 - h2)
			diff = math.min(diff, 1 - diff)
			check(
				"C-02 paint: the painted body is Fresh Lime (hue and saturation)",
				diff < 0.06 and s1 > 0.4,
				string.format("hue off by %.3f, saturation %.2f", diff, s1)
			)
		else
			check("C-02 paint: the drawn colour can be read", false, why)
		end
		local decals = 0
		for _, d in shell:GetChildren() do
			if d:IsA("Decal") and d.Name == "StyleDecal" then
				decals += 1
				check(
					"C-02 decal: a Flames image is set on face " .. d.Face.Name,
					(d :: any).ColorMapContent.Object ~= nil,
					nil
				)
			end
		end
		check("C-02 decal: the decal sits on both sides of the body", decals >= 2, decals)
	end
	local own, hiddenOwn = hidden(rcModel)
	check(
		"C-02 wheels: the car's own wheels are hidden",
		own > 0 and hiddenOwn == own,
		string.format("%d of %d hidden", hiddenOwn, own)
	)
	local added = addedParts(rcModel, RIDE)
	check("C-02 wheels: the new wheel parts are there (four tyres and rims or more)", added >= 4, added)
	local total, enabled = trailParts(rcModel)
	check("C-02 trail: emitters, ribbons or beams are on the run car", total >= 2, total)
	check(
		"C-02 trail: and every one is enabled",
		total > 0 and enabled == total,
		string.format("%d of %d", enabled, total)
	)

	-- 4. a hop: the trail follows, the caught car keeps its own look -----------------------------------------------------------
	local first = car
	local hopped = false
	local deadline = os.clock() + 60
	while os.clock() < deadline and not hopped do
		local s = ctx.debugState()
		if s and s.mode == "Ended" then
			break
		end
		if s and s.target ~= nil and (s.mode == "Riding" or s.mode == "Float") then
			ctx.hop()
		end
		task.wait(0.5)
		local now = ridden()
		hopped = now ~= nil and now ~= first
	end
	check("a real hop (leap, then dive) lands on another car", hopped, nil)
	if hopped then
		task.wait(0.6)
		local second = ridden() :: Model
		local rc2 = second:FindFirstChild("RealCar")
		local total2, enabled2 = trailParts(second)
		check(
			"C-02 your trail followed you onto the new car",
			total2 >= 2 and enabled2 == total2,
			string.format("%d of %d enabled", enabled2, total2)
		)
		local left, _ = trailParts(first)
		check("... and the car you left has no trail", left == 0, left)
		if rc2 then
			check("a caught car keeps its own paint (no paint shell)", rc2:FindFirstChild("BodyPaint") == nil, nil)
			local decals2 = 0
			for _, d in rc2:GetDescendants() do
				if d.Name == "StyleDecal" then
					decals2 += 1
				end
			end
			check("... its own decals (none added)", decals2 == 0, decals2)
			local name2 = rc2:GetAttribute("CarName")
			check("... and its own wheels (none added)", type(name2) == "string" and addedParts(rc2, name2) == 0, name2)
		else
			table.insert(
				lines,
				"NOTE the car you landed on has no showroom rig (a placeholder): the trail check above still counts"
			)
		end
	end
	ctx.control("end")
	task.wait(3)
	ctx.control("home")
	return done()
end

return BetaLookTest
