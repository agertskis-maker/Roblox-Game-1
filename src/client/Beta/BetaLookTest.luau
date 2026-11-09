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
local RosterFixtures = require(ReplicatedStorage.Shared.UI.RosterFixtures)
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
local DOWNTOWN_RIDE = "Pizza Runner"
-- review D2: the World is the LocalPlayer attribute BetaLookTestWorld ("Downtown" when unset, "DustyHighway", "SummitPass"); in the
-- other two Worlds the run starts on that World's Loaner (always yours to pick), since a Downtown car never starts a run there
local WORLD_ATTRIBUTE = "BetaLookTestWorld"

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
	local asked = player:GetAttribute(WORLD_ATTRIBUTE)
	local world = if type(asked) == "string" and table.find(RosterFixtures.Worlds, asked :: any)
		then asked
		else "Downtown"
	local loaner = RosterFixtures.loaner(world)
	local RIDE = if world == "Downtown" then DOWNTOWN_RIDE elseif loaner then loaner.id else DOWNTOWN_RIDE
	table.insert(lines, "NOTE World " .. world .. ", ride car " .. RIDE)
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
		task.wait(0.4) -- the server answers one Style request per 0.3 s
		StyleState.equip(w.tab, w.id)
		local worn = waitFor(8, function()
			local a = styleAttribute()
			return a ~= nil and a.e ~= nil and a.e[w.tab] == w.id
		end)
		check("EquipStyle " .. w.id .. " is answered: the server says it is worn", worn, nil)
		task.wait(0.4)
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
	ctx.control("autopilot", true) -- steers round the car ahead so the run lasts long enough to hop
	ctx.control("launch", world)
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
	-- the paint shell is made beside the car's body mesh (which may sit in a sub-model), so it is looked for all the way down; a car with
	-- no paint mask is washed instead (PaintWash)
	local shell = rcModel:FindFirstChild("BodyPaint", true) :: MeshPart?
	local wash = rcModel:FindFirstChild("PaintWash", true) :: MeshPart?
	check(
		"C-02 paint: the paint shell (or the wash, on a car with no mask) is on the run car",
		shell ~= nil or (wash ~= nil and wash.Transparency < 1),
		if shell then "shell" elseif wash then "wash" else nil
	)
	if not shell and wash then
		local want = (Catalog.byId("Paint", "fresh_lime") :: Catalog.Item).colours[1]
		local h1 = wash.Color:ToHSV()
		local h2 = want:ToHSV()
		local diff = math.min(math.abs(h1 - h2), 1 - math.abs(h1 - h2))
		check("C-02 paint: the wash is Fresh Lime", diff < 0.06, string.format("hue off by %.3f", diff))
	end
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
	end
	do
		-- review D5(a): the decals are looked for on the whole car (shell or body), so a car with no paint shell is checked too
		local decals = 0
		for _, d in rcModel:GetDescendants() do
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

	-- 3b. can it be SEEN from the run's own camera (review D4: the instance checks above passed while Adam saw nothing) ------------
	-- Geometry from the camera's real position after the launch hero moment (X-01) is over, not pixels: a part counts as seen when it
	-- is in front of the camera, inside the view, big enough on screen, and the first thing a ray from the camera meets on the way
	-- to it is that part itself (or nothing). Any one of these failing is a FAIL.
	task.wait(1.6)
	local cam = Workspace.CurrentCamera :: Camera
	local camPos = cam.CFrame.Position
	local ignore: { Instance } = {}
	if player.Character then
		table.insert(ignore, player.Character)
	end
	for _, d in car:GetDescendants() do
		if d:IsA("BasePart") and d.Transparency >= 1 then
			table.insert(ignore, d) -- the run's hidden stand-in parts (the showroom car rides inside them)
		end
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	local function screen(p: Vector3): Vector2?
		local v, inView = cam:WorldToViewportPoint(p)
		return if inView and v.Z > 0 then Vector2.new(v.X, v.Y) else nil
	end
	local function seen(p: Vector3, target: Instance?): boolean
		local hit = Workspace:Raycast(camPos, p - camPos, params)
		if hit == nil or (hit.Position - camPos).Magnitude >= (p - camPos).Magnitude - 0.3 then
			return true
		end
		return target ~= nil and (hit.Instance == target or hit.Instance:IsDescendantOf(target))
	end
	-- the screen size of a box (a part, or a face of one): the widest gap between its corners on screen
	local function span(cf: CFrame, size: Vector3): number
		local pts: { Vector2 } = {}
		for _, x in { -0.5, 0.5 } do
			for _, y in { -0.5, 0.5 } do
				for _, z in { -0.5, 0.5 } do
					local s = screen((cf * CFrame.new(size.X * x, size.Y * y, size.Z * z)).Position)
					if s then
						table.insert(pts, s)
					end
				end
			end
		end
		local best = 0
		for i = 1, #pts do
			for j = i + 1, #pts do
				best = math.max(best, (pts[i] - pts[j]).Magnitude)
			end
		end
		return best
	end
	local body = shell or wash or (rcModel:FindFirstChild("body_geom", true) :: BasePart?)
	if body then
		local px = span(body.CFrame, body.Size)
		check(
			"C-02 seen: the painted body is on screen from the chase camera and at least 60 px across",
			screen(body.Position) ~= nil and px >= 60,
			string.format("%d px", math.floor(px))
		)
	end
	local rear: Decal? = nil
	for _, d in rcModel:GetDescendants() do
		if d:IsA("Decal") and d.Name == "StyleDecalRear" then
			rear = d
		end
	end
	check("C-02 decal: a decal is on the rear panel too (the face the chase camera sees)", rear ~= nil, nil)
	if rear and rear.Parent and rear.Parent:IsA("BasePart") then
		local part = rear.Parent :: BasePart
		local normal = part.CFrame:VectorToWorldSpace(Vector3.FromNormalId(rear.Face))
		local centre = part.Position + normal * (part.Size * Vector3.FromNormalId(rear.Face)).Magnitude * 0.5
		local facing = normal:Dot((camPos - centre).Unit)
		check("C-02 seen: the rear decal faces the chase camera", facing > 0.15, string.format("facing %.2f", facing))
		local below = centre - part.CFrame.UpVector * part.Size.Y * 0.15 -- the design sits in the lower band of the face
		check(
			"C-02 seen: the rear decal is on screen and nothing hides it",
			screen(below) ~= nil and seen(below, part),
			nil
		)
	end
	local lips, lipsSeen = 0, 0
	for _, d in rcModel:GetDescendants() do
		if d:IsA("BasePart") and d.Name == "RimLip" then
			lips += 1
			if screen(d.Position) and seen(d.Position, nil) then
				lipsSeen += 1
			end
		end
	end
	check(
		"C-02 seen: rim-coloured wheel lips show from the chase camera",
		lips > 0 and lipsSeen > 0,
		string.format("%d of %d lip pieces in view", lipsSeen, lips)
	)
	local trailPts: { Vector2 } = {}
	for _, holder in rcModel:GetDescendants() do
		if holder:IsA("BasePart") and holder:GetAttribute("CarLookTrail") ~= nil then
			for _, a in holder:GetDescendants() do
				if a:IsA("Attachment") then
					local s = screen(a.WorldPosition)
					if s then
						table.insert(trailPts, s)
					end
				end
			end
		end
	end
	local trailPx = 0
	for i = 1, #trailPts do
		for j = i + 1, #trailPts do
			trailPx = math.max(trailPx, (trailPts[i] - trailPts[j]).Magnitude)
		end
	end
	check(
		"C-02 seen: the trail's emitters are in view and spread at least 30 px",
		#trailPts > 0 and trailPx >= 30,
		string.format("%d points, %d px", #trailPts, math.floor(trailPx))
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
			check(
				"a caught car keeps its own paint (no paint shell, no wash)",
				rc2:FindFirstChild("BodyPaint", true) == nil and (rc2:FindFirstChild("PaintWash", true) == nil),
				nil
			)
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
	ctx.control("autopilot", false)
	ctx.control("end")
	task.wait(3)
	ctx.control("home")
	return done()
end

return BetaLookTest
