--!strict
-- Parking bays show what is in them (Lane 3 Round 8, H-03; to R8-IMG-07). Adam: "there's no way right now to tell whether a
-- parking spot is filled or not. I want a transparent version of the car that is on the raceway in the parking spot."
--
-- Bay i belongs to slot i of the owner's Lineup (the cars racing on their Raceway). For every owned plot, on this client only:
--   FILLED bay   a see-through GHOST of exactly that car (the same model, scaled as the Raceway scales it, dressed in the owner's
--                look through CarLookApplier), about 65% transparent, a Highlight outline in the car's rarity colour, a faint
--                shimmer, no collision, no shadow, no touch or query; a small floating tag with the car's name in its rarity
--                colour and its "$X/lap"; a soft rarity-coloured glow painted round the bay.
--   EMPTY bay    a glowing dashed outline, a big "+" and EMPTY painted on the ground, and a short tag "Catch a car to fill".
--   LOCKED bay   (the next two bays not bought yet) a dark striped slab with a padlock and that bay's price in the K/M/B format,
--                the same number the Parking card shows for the next spot.
-- Other players see the same on your plot: everything is built from replicated data only (the plot's Owner, ParkingSpots,
-- ExpandedPaddock and SpeedwayLevel attributes, and the owner's BetaLineup, BetaCars and BetaStyle attributes), so there are no
-- server parts and no polling: an attribute change schedules one rebuild of that plot's bays, and a bay whose picture did not change
-- is left alone. A ghost or a marking that changes fades in or out in a quarter of a second.
--
-- Cost (performance-budget.md): a plot is built only while the camera is within ACTIVE studs of its Paddock, and everything on it is
-- removed beyond that (the Launch Pads and the runs are far away, so nothing is built there). A ghost is a copy of the car model
-- (5 to 8 meshes) plus, only within DETAIL studs of the camera (and at most MAX_DETAIL of them), its outline, tag, shimmer and
-- look. Markings are one flat invisible plate with one SurfaceGui per owned bay and per shown locked bay. No particles, no lights.
-- Reduce Motion: no shimmer; the fades stay (they are short).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BetaConfig = require(Shared:WaitForChild("Beta"):WaitForChild("BetaConfig"))
if not BetaConfig.enabled() then
	return
end
local LiveData = require(Shared:WaitForChild("UI"):WaitForChild("LiveData"))
local EconomyPreview = require(Shared.UI:WaitForChild("EconomyPreview"))
local Format = require(Shared.UI:WaitForChild("Format"))
local RosterFixtures = require(Shared.UI:WaitForChild("RosterFixtures"))
local Tokens = require(Shared.UI:WaitForChild("Tokens"))
local CarLook = require(Shared:WaitForChild("Style"):WaitForChild("CarLook"))
local Parking = require(Shared:WaitForChild("Island"):WaitForChild("Speedway"):WaitForChild("Parking"))
local Trove = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Trove"))
local ParkingLook = require(script.Parent:WaitForChild("Speedway"):WaitForChild("ParkingLook"))

local Prototype = script.Parent.Parent.Parent:WaitForChild("UI"):WaitForChild("Prototype")
local Motion = require(Prototype:WaitForChild("Motion"))
local RealCar = require(Prototype:WaitForChild("RealCar"))
local CarLookApplier = require(Prototype:WaitForChild("Style"):WaitForChild("CarLookApplier"))

local player = Players.LocalPlayer

local t0 = os.clock()
while not LiveData.active() and os.clock() - t0 < 15 do
	task.wait(0.25)
end
if not LiveData.active() then
	return
end

-- Tunables
local ACTIVE = 360 -- studs from the camera to a plot's Paddock: nearer than this the plot's bays are built
local ACTIVE_LEAVE = 400 -- and torn down beyond this (so a camera at the edge does not flicker)
local DETAIL = 170 -- a ghost this near gets its outline, tag, shimmer and look
local MAX_DETAIL = 24 -- at most this many ghosts at full detail across the island
local LOCKED_SHOWN = 2 -- locked bays drawn after the owned ones
local GHOST_TRANSPARENCY = 0.65 -- Adam: "transparent"; the brief says about 60 to 65%
local FADE_SECONDS = 0.25
local CAR_LENGTH = 12.6 -- the Raceway's cars (RacewayLineup): the same size, so a ghost is "exactly that car"
local CAR_HEIGHT = 5.2
local PX = 20 -- pixels per stud on a bay's painted plate

local NAVY = Color3.fromRGB(20, 33, 63)
local CREAM = Color3.fromRGB(255, 244, 218)
local GOLD = Color3.fromRGB(247, 198, 76)
local GREEN = Color3.fromRGB(110, 230, 120)
local WHITE = Color3.fromRGB(255, 255, 255)
-- the rarity colours the Raceway auras use (Style.RacewayAura); Common has none there, so it is a soft white
local RARITY: { [string]: Color3 } = {
	Common = Color3.fromRGB(226, 232, 244),
	Uncommon = Color3.fromRGB(80, 230, 120),
	Rare = Color3.fromRGB(60, 150, 255),
	Epic = Color3.fromRGB(176, 92, 246),
	Legendary = Color3.fromRGB(255, 200, 40),
}

type Trove = typeof(Trove.new())
type Want = {
	kind: "filled" | "empty" | "locked",
	key: string, -- what the bay's painted plate and ghost model were made from; the same key means nothing to redo
	car: string?,
	look: CarLook.Look?,
	rarity: string?,
	name: string?,
	pay: string?, -- the tag's second line
	price: string?,
}
type View = {
	lane: Lane,
	index: number,
	kind: string,
	key: string,
	trove: Trove,
	plate: Part,
	group: CanvasGroup,
	alpha: number,
	target: number,
	-- a ghost (filled bays)
	model: Model?,
	parts: { BasePart },
	colour: Color3,
	base: CFrame,
	carId: string?,
	look: CarLook.Look?,
	name: string,
	pay: string,
	detail: boolean,
	phase: number,
	highlight: Highlight?,
	tag: CanvasGroup?,
	nameLabel: TextLabel?,
	payLabel: TextLabel?,
	handle: { destroy: (any) -> () }?,
	dressed: boolean,
	destroyed: boolean,
	restackQueued: boolean,
}
type Lane = {
	plot: Model,
	index: number,
	bearing: number,
	centre: Vector3,
	folder: Folder,
	trove: Trove,
	ownerTrove: Trove,
	owner: Player?,
	active: boolean,
	scheduled: boolean,
	bays: { [number]: View },
}

local root = Instance.new("Folder")
root.Name = "Lane3_ParkingGhosts"
root.Parent = Workspace

local lanes: { [Model]: Lane } = {}
local animating: { [View]: boolean } = {}
local shimmering: { [View]: boolean } = {}
local reduced = Motion.reduced()
local warned: { [string]: boolean } = {}

local function make(className: string, props: { [string]: any }, parent: Instance?): any
	local inst = Instance.new(className)
	if inst:IsA("GuiObject") then
		inst.BorderSizePixel = 0
	end
	for k, v in props do
		(inst :: any)[k] = v
	end
	if parent then
		inst.Parent = parent
	end
	return inst
end

local function stroke(parent: Instance, thickness: number, colour: Color3, transparency: number?)
	make("UIStroke", {
		Color = colour,
		Thickness = thickness,
		Transparency = transparency or 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	}, parent)
end

local function round(parent: Instance, radius: number)
	make("UICorner", { CornerRadius = UDim.new(0, radius) }, parent)
end

-- The ground pictures -------------------------------------------------------------------------------------------------------------

-- a dashed line between two points of the plate (axis aligned), centred in its length
local function dashLine(parent: Instance, x0: number, y0: number, x1: number, y1: number, thick: number)
	local horizontal = y0 == y1
	local length = if horizontal then x1 - x0 else y1 - y0
	local dash, gap = 24, 15
	local count = math.max(1, math.floor((length + gap) / (dash + gap)))
	local first = (length - (count * dash + (count - 1) * gap)) / 2
	for i = 0, count - 1 do
		local at = first + i * (dash + gap)
		local piece = make("Frame", {
			BackgroundColor3 = WHITE,
			Position = if horizontal
				then UDim2.fromOffset(x0 + at, y0 - thick / 2)
				else UDim2.fromOffset(x0 - thick / 2, y0 + at),
			Size = if horizontal then UDim2.fromOffset(dash, thick) else UDim2.fromOffset(thick, dash),
		}, parent)
		round(piece, 3)
	end
end

local function drawFilled(group: CanvasGroup, w: number, h: number, colour: Color3)
	local glow = make("Frame", {
		Name = "Glow",
		Position = UDim2.fromOffset(2, 2),
		Size = UDim2.fromOffset(w - 4, h - 4),
		BackgroundColor3 = colour,
		BackgroundTransparency = 0.88,
	}, group)
	round(glow, 18)
	stroke(glow, 14, colour, 0.82)
	local line = make("Frame", {
		Name = "Edge",
		Position = UDim2.fromOffset(8, 8),
		Size = UDim2.fromOffset(w - 16, h - 16),
		BackgroundTransparency = 1,
	}, group)
	round(line, 14)
	stroke(line, 6, colour, 0.1)
end

local function drawEmpty(group: CanvasGroup, w: number, h: number)
	local tint = make("Frame", {
		Name = "Glow",
		Position = UDim2.fromOffset(2, 2),
		Size = UDim2.fromOffset(w - 4, h - 4),
		BackgroundColor3 = WHITE,
		BackgroundTransparency = 0.92,
	}, group)
	round(tint, 18)
	stroke(tint, 14, WHITE, 0.84)
	local pad = 16
	local dashes = make("Frame", {
		Name = "Dashes",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
	}, group)
	dashLine(dashes, pad, pad, w - pad, pad, 6)
	dashLine(dashes, pad, h - pad, w - pad, h - pad, 6)
	dashLine(dashes, pad, pad, pad, h - pad, 6)
	dashLine(dashes, w - pad, pad, w - pad, h - pad, 6)
	-- the big "+"
	local plus = make("Frame", {
		Name = "Plus",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(w / 2, h * 0.38),
		Size = UDim2.fromOffset(58, 58),
		BackgroundTransparency = 1,
	}, group)
	for _, size in { Vector2.new(58, 14), Vector2.new(14, 58) } do
		local bar = make("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(size.X, size.Y),
			BackgroundColor3 = WHITE,
		}, plus)
		round(bar, 6)
	end
	local word = make("TextLabel", {
		Name = "EmptyWord",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(w / 2, h * 0.58),
		Size = UDim2.fromOffset(w - 30, 44),
		FontFace = Tokens.font(),
		Text = "EMPTY",
		TextColor3 = WHITE,
		TextScaled = true,
	}, group)
	stroke(word, 3, NAVY)
	make("UITextSizeConstraint", { MaxTextSize = 44 }, word)
end

local function padlock(parent: Instance, cx: number, cy: number)
	local bodyW, bodyH = 76, 62
	local shackleW, shackleH = 46, 56
	-- the shackle: a navy outline under a gold bar, both drawn as rounded outlines; the body hides their lower half
	for _, layer in { { thick = 17, colour = NAVY }, { thick = 9, colour = GOLD } } do
		local arc = make("Frame", {
			Name = "Shackle",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(cx, cy - bodyH / 2 - shackleH / 2 + 18),
			Size = UDim2.fromOffset(shackleW, shackleH),
			BackgroundTransparency = 1,
		}, parent)
		round(arc, shackleW / 2)
		stroke(arc, layer.thick, layer.colour)
	end
	local body = make("Frame", {
		Name = "LockBody",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(cx, cy),
		Size = UDim2.fromOffset(bodyW, bodyH),
		BackgroundColor3 = GOLD,
		ZIndex = 3,
	}, parent)
	round(body, 12)
	stroke(body, 5, NAVY)
	make("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new(Color3.fromRGB(255, 226, 130), Color3.fromRGB(226, 150, 24)),
	}, body)
	local hole = make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.3),
		Size = UDim2.fromOffset(13, 13),
		BackgroundColor3 = NAVY,
		ZIndex = 4,
	}, body)
	round(hole, 7)
	local slot = make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0.3, 9),
		Size = UDim2.fromOffset(7, 17),
		BackgroundColor3 = NAVY,
		ZIndex = 4,
	}, body)
	round(slot, 3)
end

local function drawLocked(group: CanvasGroup, w: number, h: number, price: string?)
	local slab = make("Frame", {
		Name = "Slab",
		Position = UDim2.fromOffset(4, 4),
		Size = UDim2.fromOffset(w - 8, h - 8),
		BackgroundColor3 = Color3.fromRGB(24, 28, 42),
		BackgroundTransparency = 0.05,
	}, group)
	round(slab, 14)
	stroke(slab, 4, Color3.fromRGB(70, 78, 100))
	-- diagonal hazard stripes: hard colour steps in one gradient (five stripes, ten keypoints)
	local dark, light = Color3.fromRGB(22, 26, 40), Color3.fromRGB(44, 50, 70)
	local stops: { ColorSequenceKeypoint } = {}
	local steps = { 0, 0.2, 0.4, 0.6, 0.8 }
	for i, at in steps do
		local c = if i % 2 == 1 then dark else light
		table.insert(stops, ColorSequenceKeypoint.new(if at == 0 then 0 else at + 0.0001, c))
		table.insert(stops, ColorSequenceKeypoint.new(math.min(at + 0.2, 1), c))
	end
	stops[#stops] = ColorSequenceKeypoint.new(1, if #steps % 2 == 1 then dark else light)
	make("UIGradient", { Rotation = 45, Color = ColorSequence.new(stops) }, slab)
	padlock(group, w / 2, h * 0.36)
	if price then
		local pill = make("Frame", {
			Name = "Price",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(w / 2, h * 0.66),
			Size = UDim2.fromOffset(w - 24, 50),
			BackgroundColor3 = NAVY,
		}, group)
		round(pill, 25)
		stroke(pill, 4, GOLD)
		local label = make("TextLabel", {
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			FontFace = Tokens.font(),
			Text = price,
			TextColor3 = Color3.fromRGB(255, 226, 130),
			TextScaled = true,
		}, pill)
		make("UIPadding", {
			PaddingTop = UDim.new(0, 6),
			PaddingBottom = UDim.new(0, 6),
			PaddingLeft = UDim.new(0, 8),
			PaddingRight = UDim.new(0, 8),
		}, label)
	end
end

-- Ghost cars ----------------------------------------------------------------------------------------------------------------------

local function targetTransparency(stacked: boolean): number
	-- a painted body is two meshes on top of each other (the car and its paint shell): each is a little more see-through, so the
	-- two together read as the same 65% as one
	return if stacked then 1 - math.sqrt(1 - (1 - GHOST_TRANSPARENCY)) else GHOST_TRANSPARENCY
end

-- Makes every part of the ghost see-through, shadowless and untouchable, and fits its fade. The paint shell and the decals the look
-- adds later come through here too (DescendantAdded).
local function ghostify(view: View)
	local model = view.model
	if not model then
		return
	end
	local body: MeshPart? = nil
	for _, d in model:GetDescendants() do
		if d:IsA("MeshPart") and d.Name == "body_geom" then
			body = d
			break
		end
	end
	local stacked = false
	if body then
		for _, d in model:GetDescendants() do
			if d:IsA("MeshPart") and d ~= body and d.MeshId == body.MeshId and d.Name ~= "body_geom" then
				stacked = true
				break
			end
		end
	end
	local t = targetTransparency(stacked)
	table.clear(view.parts)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
			d.CastShadow = false
			d.Transparency = t
			d.LocalTransparencyModifier = 1 - view.alpha
			table.insert(view.parts, d)
		elseif d:IsA("Decal") or d:IsA("Texture") then
			d.Transparency = t
		elseif d:IsA("ParticleEmitter") or d:IsA("Trail") or d:IsA("Beam") or d:IsA("Fire") or d:IsA("Smoke") then
			d.Enabled = false -- a ghost never leaves a trail or smoke
		end
	end
end

local function queueGhostify(view: View)
	if view.restackQueued or view.destroyed then
		return
	end
	view.restackQueued = true
	task.defer(function()
		view.restackQueued = false
		if not view.destroyed then
			ghostify(view)
		end
	end)
end

local function applyAlpha(view: View)
	view.group.GroupTransparency = 1 - view.alpha
	for _, p in view.parts do
		p.LocalTransparencyModifier = 1 - view.alpha
	end
	local h = view.highlight
	if h then
		h.OutlineTransparency = 1 - 0.8 * view.alpha
		h.FillTransparency = 1 - 0.1 * view.alpha
	end
	local tag = view.tag
	if tag then
		tag.GroupTransparency = 1 - view.alpha
	end
end

local function buildModel(carId: string): Model?
	local model = RealCar.displayModel(carId)
	if not model then
		return nil
	end
	model.Name = "ParkingGhost"
	local _, size = model:GetBoundingBox()
	if size.Z > 0 and size.Y > 0 then
		model:ScaleTo(model:GetScale() * math.min(CAR_LENGTH / size.Z, CAR_HEIGHT / size.Y))
	end
	return model
end

local function tagGui(view: View, parent: Instance, adornee: BasePart)
	local gui = make("BillboardGui", {
		Name = "GhostTag",
		Adornee = adornee,
		Size = UDim2.fromOffset(176, 58),
		StudsOffsetWorldSpace = Vector3.new(0, 5.6, 0),
		MaxDistance = DETAIL + 40,
		AlwaysOnTop = false,
		LightInfluence = 0,
	}, parent)
	local card = make("CanvasGroup", {
		Name = "Card",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = NAVY,
		BackgroundTransparency = 0.04,
		GroupTransparency = 1 - view.alpha,
	}, gui)
	round(card, 16)
	stroke(card, 3, view.colour)
	local name = make("TextLabel", {
		Name = "CarName",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(8, 4),
		Size = UDim2.new(1, -16, 0, 30),
		FontFace = Tokens.font(),
		Text = view.name,
		TextColor3 = view.colour,
		TextScaled = true,
	}, card)
	make("UITextSizeConstraint", { MaxTextSize = 26, MinTextSize = 10 }, name)
	local pay = make("TextLabel", {
		Name = "LapPay",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(8, 33),
		Size = UDim2.new(1, -16, 0, 20),
		FontFace = Tokens.font(),
		Text = view.pay,
		TextColor3 = GREEN,
		TextScaled = true,
	}, card)
	make("UITextSizeConstraint", { MaxTextSize = 19, MinTextSize = 9 }, pay)
	view.tag = card
	view.nameLabel = name
	view.payLabel = pay
	view.trove:Add(gui)
end

-- the outline, the tag and the look: only for ghosts near the camera
local function setDetail(view: View, on: boolean)
	local model = view.model
	if view.detail == on or not model or view.destroyed then
		return
	end
	view.detail = on
	if on then
		local highlight = make("Highlight", {
			Name = "GhostOutline",
			Adornee = model,
			FillColor = view.colour,
			OutlineColor = view.colour,
			FillTransparency = 1 - 0.1 * view.alpha,
			OutlineTransparency = 1 - 0.8 * view.alpha,
			DepthMode = Enum.HighlightDepthMode.Occluded,
		}, model)
		view.highlight = highlight
		local body = model:FindFirstChild("body_geom", true)
		local adornee = if body and body:IsA("BasePart") then body else view.parts[1]
		if adornee then
			tagGui(view, model, adornee)
		end
		if not reduced then
			shimmering[view] = true
		end
		if not view.dressed and view.look then
			view.dressed = true
			local look = view.look
			task.spawn(function()
				-- the owner's look (paint, decals, wheels), built by WS-1's applier (a stub on branches without it)
				local ok, handle =
					pcall(CarLookApplier.apply, model, look, { lod = "low", trail = false, ghost = true })
				if ok and handle then
					if view.destroyed then
						pcall(handle.destroy, handle)
					else
						view.handle = handle :: any
						ghostify(view)
					end
				elseif not ok and not warned.apply then
					warned.apply = true
					warn("[ParkingGhosts] CarLookApplier.apply failed: " .. tostring(handle))
				end
			end)
		end
	else
		shimmering[view] = nil
		if view.highlight then
			view.highlight:Destroy()
			view.highlight = nil
		end
		local tag = view.tag
		if tag and tag.Parent then
			tag.Parent:Destroy()
		end
		view.tag = nil
		view.nameLabel = nil
		view.payLabel = nil
	end
end

-- Views ---------------------------------------------------------------------------------------------------------------------------

local function destroyView(view: View)
	if view.destroyed then
		return
	end
	local lane = view.lane
	view.destroyed = true
	animating[view] = nil
	shimmering[view] = nil
	if view.handle then
		pcall(view.handle.destroy, view.handle)
		view.handle = nil
	end
	if lane.bays[view.index] == view then
		lane.bays[view.index] = nil
	end
	view.trove:Destroy()
end

local function fadeTo(view: View, target: number)
	view.target = target
	if view.alpha ~= target then
		animating[view] = true
	end
end

-- A bay's picture that is no longer right: gone at once (far away), or fading out while its replacement fades in. The fade loop
-- destroys it at zero.
local function retire(view: View, instant: boolean)
	if instant then
		destroyView(view)
		return
	end
	local lane = view.lane
	if lane.bays[view.index] == view then
		lane.bays[view.index] = nil
	end
	shimmering[view] = nil
	fadeTo(view, 0)
end

local function newView(lane: Lane, index: number, want: Want): View?
	local pose = ParkingLook.bayPose(lane.plot, lane.bearing, index)
	if not pose then
		return nil
	end
	local viewTrove = Trove.new()
	local plate = make("Part", {
		Name = string.format("BayMark%02d", index),
		Anchored = true,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		CastShadow = false,
		Transparency = 1,
		Size = Vector3.new(pose.width, 0.04, pose.depth),
		CFrame = pose.plate * CFrame.new(0, -0.02, 0),
	}, lane.folder)
	viewTrove:Add(plate)
	local gui = make("SurfaceGui", {
		Name = "Mark",
		Face = Enum.NormalId.Top,
		SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud,
		PixelsPerStud = PX,
		LightInfluence = 0.6,
		MaxDistance = ACTIVE_LEAVE,
		AlwaysOnTop = false,
	}, plate)
	local w, h = math.floor(pose.width * PX), math.floor(pose.depth * PX)
	local group = make("CanvasGroup", {
		Name = "Paint",
		Size = UDim2.fromOffset(w, h),
		BackgroundTransparency = 1,
		GroupTransparency = 1,
	}, gui)
	local colour = RARITY[want.rarity or "Common"] or RARITY.Common
	local view: View = {
		lane = lane,
		index = index,
		kind = want.kind,
		key = want.key,
		trove = viewTrove,
		plate = plate,
		group = group,
		alpha = 0,
		target = 1,
		model = nil,
		parts = {},
		colour = colour,
		base = pose.car,
		carId = want.car,
		look = want.look,
		name = want.name or "",
		pay = want.pay or "",
		detail = false,
		phase = index * 1.7,
		highlight = nil,
		tag = nil,
		nameLabel = nil,
		payLabel = nil,
		handle = nil,
		dressed = false,
		destroyed = false,
		restackQueued = false,
	}
	if want.kind == "filled" then
		drawFilled(group, w, h, colour)
		local model = if want.car then buildModel(want.car) else nil
		if not model and want.car and not warned[want.car] then
			warned[want.car] = true
			warn("[ParkingGhosts] no model for " .. want.car .. "; its bay shows the glow and the tag only")
		end
		if model then
			view.model = model
			model.Parent = lane.folder
			model:PivotTo(pose.car)
			viewTrove:Add(model)
			ghostify(view)
			viewTrove:Connect(model.DescendantAdded, function()
				queueGhostify(view) -- the paint shell and the decals the look adds
			end)
		end
	elseif want.kind == "empty" then
		drawEmpty(group, w, h)
		-- the short tag over the bay, only close up
		local tip = make("BillboardGui", {
			Name = "EmptyTag",
			Adornee = plate,
			Size = UDim2.fromOffset(178, 34),
			StudsOffsetWorldSpace = Vector3.new(0, 3.4, 0),
			MaxDistance = 80,
			AlwaysOnTop = false,
			LightInfluence = 0,
		}, plate)
		local card =
			make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = NAVY, BackgroundTransparency = 0.08 }, tip)
		round(card, 17)
		stroke(card, 2, CREAM)
		local words = make("TextLabel", {
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			FontFace = Tokens.font(),
			Text = "Catch a car to fill",
			TextColor3 = CREAM,
			TextScaled = true,
		}, card)
		make("UIPadding", {
			PaddingTop = UDim.new(0, 5),
			PaddingBottom = UDim.new(0, 5),
			PaddingLeft = UDim.new(0, 10),
			PaddingRight = UDim.new(0, 10),
		}, words)
	else
		drawLocked(group, w, h, want.price)
	end
	lane.bays[index] = view
	animating[view] = true
	return view
end

-- What each bay of a plot should show now, from replicated data only.
local function wanted(lane: Lane): { [number]: Want }
	local out: { [number]: Want } = {}
	local owner = lane.owner
	if not lane.active or not owner then
		return out
	end
	local lineupText = owner:GetAttribute(BetaConfig.LineupAttribute)
	if type(lineupText) ~= "string" then
		return out -- the owner's data has not reached this client yet: show nothing rather than a wrong EMPTY
	end
	local list = BetaConfig.splitList(lineupText)
	local cars = LiveData.cars(owner)
	local styleJson = owner:GetAttribute(BetaConfig.StyleAttribute)
	local level = lane.plot:GetAttribute("SpeedwayLevel")
	local spots = ParkingLook.resolve(lane.plot, lane.index)
	local max = Parking.maxFor(lane.plot)
	local extra = if Parking.hasExpanded(lane.plot) then EconomyPreview.ExpandedPaddockSpots else 0
	for i = 1, spots do
		local carId = list[i]
		if carId then
			local info = RosterFixtures.byId(carId)
			local save = cars[carId]
			local pay = if info
				then math.floor(
					EconomyPreview.lapPay(
						info.rarity,
						if save then save.Edition else 1,
						if type(level) == "number" then level else 1,
						info.world
					)
				)
				else nil
			local look = CarLook.fromAttribute(carId, styleJson)
			out[i] = {
				kind = "filled",
				key = "filled|" .. CarLook.key(look),
				car = carId,
				look = look,
				rarity = if info then info.rarity else "Common",
				name = if info then info.name else carId,
				pay = if pay then Format.cash(pay) .. "/lap" else "",
			}
		else
			out[i] = { kind = "empty", key = "empty" }
		end
	end
	for i = spots + 1, math.min(spots + LOCKED_SHOWN, max) do
		-- the price of buying this bay when it is the next one: the number the Parking card shows (the pass's bays are free)
		local price = EconomyPreview.spotPrice(i - extra)
		out[i] = {
			kind = "locked",
			key = "locked|" .. tostring(price),
			price = if price then Format.cash(price) else nil,
		}
	end
	return out
end

local function sync(lane: Lane)
	local want = wanted(lane)
	for index, view in table.clone(lane.bays) do
		local w = want[index]
		if not w or w.kind ~= view.kind or w.key ~= view.key then
			-- a bay that changed: the old picture fades out while the new one fades in (never wrong for a moment)
			retire(view, not lane.active)
		end
	end
	for index, w in want do
		local view = lane.bays[index]
		if view == nil then
			newView(lane, index, w)
		elseif w.kind == "filled" and view.pay ~= (w.pay or "") then
			view.pay = w.pay or ""
			if view.payLabel then
				view.payLabel.Text = view.pay
			end
		end
	end
end

local function schedule(lane: Lane)
	if lane.scheduled then
		return
	end
	lane.scheduled = true
	task.defer(function()
		lane.scheduled = false
		if lane.plot.Parent then
			sync(lane)
		end
	end)
end

local function bindOwner(lane: Lane)
	lane.ownerTrove:Clean()
	local id = lane.plot:GetAttribute("Owner")
	local owner = if type(id) == "number" then Players:GetPlayerByUserId(id) else nil
	lane.owner = owner
	if owner then
		for _, name in { BetaConfig.LineupAttribute, BetaConfig.CarsAttribute, BetaConfig.StyleAttribute } do
			lane.ownerTrove:Connect(owner:GetAttributeChangedSignal(name), function()
				schedule(lane)
			end)
		end
	end
	schedule(lane)
end

local function watch(plot: Instance)
	if not plot:IsA("Model") or lanes[plot] then
		return
	end
	local bearing = plot:GetAttribute("BearingDeg")
	if type(bearing) ~= "number" then
		return
	end
	local index = plot:GetAttribute("PlotIndex")
	if type(index) ~= "number" then
		index = tonumber(string.match(plot.Name, "%d+")) or 0
	end
	local folder = Instance.new("Folder")
	folder.Name = plot.Name
	folder.Parent = root
	local lane: Lane = {
		plot = plot,
		index = index :: number,
		bearing = bearing,
		centre = ParkingLook.paddockCentre(plot, bearing),
		folder = folder,
		trove = Trove.new(),
		ownerTrove = Trove.new(),
		owner = nil,
		active = false,
		scheduled = false,
		bays = {},
	}
	lane.trove:Add(folder)
	lane.trove:Add(lane.ownerTrove)
	lanes[plot] = lane
	local function again()
		schedule(lane)
	end
	lane.trove:Connect(plot:GetAttributeChangedSignal("Owner"), function()
		bindOwner(lane)
	end)
	for _, name in { "ParkingSpots", "ExpandedPaddock", "SpeedwayLevel" } do
		lane.trove:Connect(plot:GetAttributeChangedSignal(name), again)
	end
	lane.trove:Connect(plot.Destroying, function()
		for _, view in table.clone(lane.bays) do
			destroyView(view)
		end
		lane.trove:Destroy()
		lanes[plot] = nil
	end)
	bindOwner(lane)
end

-- Fades and the shimmer ------------------------------------------------------------------------------------------------------------

RunService.RenderStepped:Connect(function(dt: number)
	if next(animating) ~= nil then
		local step = dt / FADE_SECONDS
		for view in table.clone(animating) do
			if view.destroyed then
				animating[view] = nil
				continue
			end
			if view.alpha < view.target then
				view.alpha = math.min(view.target, view.alpha + step)
			else
				view.alpha = math.max(view.target, view.alpha - step)
			end
			applyAlpha(view)
			if view.alpha == view.target then
				animating[view] = nil
				if view.target == 0 then
					destroyView(view)
				end
			end
		end
	end
	if next(shimmering) ~= nil and not reduced then
		local t = os.clock() * 2.2
		for view in shimmering do
			local h = view.highlight
			if h and view.alpha >= 1 then
				local wave = math.sin(t + view.phase)
				h.OutlineTransparency = 0.2 + 0.18 * wave
				h.FillTransparency = 0.9 + 0.05 * wave
			end
		end
	end
end)

Motion.onReducedChanged(function(now: boolean)
	reduced = now
	for view in shimmering do
		if now then
			shimmering[view] = nil
			applyAlpha(view)
		end
	end
	if not now then
		for _, lane in lanes do
			for _, view in lane.bays do
				if view.detail and view.kind == "filled" then
					shimmering[view] = true
				end
			end
		end
	end
end)

-- Distance: a plot is built only near the camera, and only the nearest ghosts get their detail ------------------------------------------

local lastCheck = 0
RunService.Heartbeat:Connect(function()
	local now = os.clock()
	if now - lastCheck < 0.5 then
		return
	end
	lastCheck = now
	local camera = Workspace.CurrentCamera
	local eye = if camera then camera.CFrame.Position else Vector3.new(0, 1e6, 0)
	for _, lane in lanes do
		local d = (lane.centre - eye).Magnitude
		local active = if lane.active then d < ACTIVE_LEAVE else d < ACTIVE
		if active ~= lane.active then
			lane.active = active
			schedule(lane)
		end
	end
	local near: { { view: View, d: number } } = {}
	for _, lane in lanes do
		for _, view in lane.bays do
			if view.kind == "filled" and view.model and not view.destroyed then
				table.insert(near, { view = view, d = (view.base.Position - eye).Magnitude })
			end
		end
	end
	table.sort(near, function(a, b)
		return a.d < b.d
	end)
	for i, item in near do
		setDetail(item.view, i <= MAX_DETAIL and item.d < DETAIL)
	end
end)

-- Wiring ---------------------------------------------------------------------------------------------------------------------------

local function plotsFolder(): Instance?
	local island = Workspace:FindFirstChild("Lane3_IslandPreview")
	island = island and island:FindFirstChild("Island")
	return island and island:FindFirstChild("Plots")
end

local plots = plotsFolder()
while not plots do
	task.wait(1)
	plots = plotsFolder()
end
for _, plot in (plots :: Instance):GetChildren() do
	watch(plot)
end
(plots :: Instance).ChildAdded:Connect(watch)

-- an owner who joins after the plot got its Owner attribute, or leaves: the bays follow at once
Players.PlayerAdded:Connect(function(joining: Player)
	for _, lane in lanes do
		if lane.plot:GetAttribute("Owner") == joining.UserId then
			bindOwner(lane)
		end
	end
end)
Players.PlayerRemoving:Connect(function(leaving: Player)
	for _, lane in lanes do
		if lane.owner == leaving then
			bindOwner(lane)
		end
	end
end)
-- the Studio preview of the parking spot count (ParkingLook.resolve)
player.AttributeChanged:Connect(function(name: string)
	if string.find(name, "^Lane3ParkingPreviewSpots") then
		for _, lane in lanes do
			schedule(lane)
		end
	end
end)
