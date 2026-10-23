--!strict
-- Shared helpers for the world-space presentation modules (Lane 3 preview, HUD rebuild
-- 2026-10-22, worker HW). Not a component. Every world piece built here is local to this
-- client, anchored, non-colliding, non-queryable, non-touchable and casts no shadow, so it can
-- never change physics, raycasts or the real character.
--
--   WorldKit.Ctx                      -- the component ctx incl. the screen-slot arbiter
--   WorldKit.rank(rarity) -> 1..5     -- Common 1 .. Legendary 5 (unknown -> 1)
--   WorldKit.rarity(rarity)           -- the PreviewTokens.Rarity entry (label, pips, light, deep)
--   WorldKit.billboardScale(ctx)      -- design px -> real viewport px for BillboardGuis
--   WorldKit.part(parent, name, size, cf, colour, material?) -> Part
--   WorldKit.mainPart(model) -> BasePart?      -- PrimaryPart or the first BasePart
--   WorldKit.box(model) -> (CFrame, Vector3)   -- oriented bounding box (yaw of the pivot)
--   WorldKit.groundY(at, exclude) -> number?   -- short downward ray, nil when nothing below
--   WorldKit.plate(parent, car, options) -> Plate   -- the kit nameplate (rarity + name + tags)

local TextService = game:GetService("TextService")
local Workspace = game:GetService("Workspace")

local Arcade = require(script.Parent.Parent.Arcade)
local PreviewTokens = require(script.Parent.Parent.PreviewTokens)
local Priority = require(script.Parent.Parent.Priority)
local Screen = require(script.Parent.Parent.Screen)
local Store = require(script.Parent.Parent.Store)

local A = PreviewTokens.Arcade
local make = Arcade.make

local WorldKit = {}

export type Ctx = {
	store: Store.StoreObject,
	screen: Screen.ScreenObject,
	layer: Frame,
	world: Folder,
	priority: Priority.Arbiter?,
}

-- The display fields a world label needs. Store.CarRef and Fixtures.CarRef both fit.
export type CarInfo = {
	name: string,
	rarity: string,
	variant: string?,
	owned: boolean?, -- nil = unknown (never NEW!); only `owned == false` shows NEW!
}

local RANK: { [string]: number } = { Common = 1, Uncommon = 2, Rare = 3, Epic = 4, Legendary = 5 }

function WorldKit.rank(rarity: string?): number
	return RANK[rarity or ""] or 1
end

function WorldKit.rarity(rarity: string?): { label: string, pips: number, light: Color3, deep: Color3 }
	local r = (PreviewTokens.Rarity :: any)[rarity or ""] or PreviewTokens.Rarity.Common
	return r
end

-- Only an explicit `owned == false` is "not owned". nil (unknown) never counts as new.
function WorldKit.isNew(car: CarInfo?): boolean
	return car ~= nil and car.owned == false
end

function WorldKit.billboardScale(ctx: Ctx): number
	return ctx.screen:uiScale() * ctx.screen:fitScale()
end

function WorldKit.part(
	parent: Instance,
	name: string,
	size: Vector3,
	cf: CFrame,
	colour: Color3,
	material: Enum.Material?
): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Size = size
	p.CFrame = cf
	p.Color = colour
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

function WorldKit.mainPart(model: Instance?): BasePart?
	if not model or not model.Parent then
		return nil
	end
	if model:IsA("BasePart") then
		return model
	end
	if model:IsA("Model") then
		local m = model :: Model
		if m.PrimaryPart then
			return m.PrimaryPart
		end
		return m:FindFirstChildWhichIsA("BasePart", true)
	end
	return nil
end

function WorldKit.box(model: Instance): (CFrame, Vector3)
	if model:IsA("Model") then
		return (model :: Model):GetBoundingBox()
	elseif model:IsA("BasePart") then
		local p = model :: BasePart
		return p.CFrame, p.Size
	end
	return CFrame.new(), Vector3.new(6, 4, 12)
end

-- Places a model so its bounding-box BOTTOM rests on cf.Y (ProxyCar's pivot is its body part,
-- so PivotTo alone would sink the wheels into the ground).
function WorldKit.seat(model: Model, cf: CFrame)
	model:PivotTo(cf)
	local box, size = model:GetBoundingBox()
	local bottom = box.Position.Y - size.Y / 2
	model:PivotTo(cf + Vector3.new(0, cf.Position.Y - bottom, 0))
end

-- Yaw-only frame at a position (keeps ground cues level when a car pitches).
function WorldKit.flat(cf: CFrame, position: Vector3?): CFrame
	local at = position or cf.Position
	local look = cf.LookVector
	local flat = Vector3.new(look.X, 0, look.Z)
	if flat.Magnitude < 1e-3 then
		return CFrame.new(at)
	end
	return CFrame.lookAt(at, at + flat)
end

-- A short downward ray (at most `depth` studs) that ignores `exclude`. Parts with CanQuery off
-- (every preview piece and the proxy cars) are never hit anyway.
function WorldKit.groundY(at: Vector3, exclude: { Instance }, depth: number?): number?
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = exclude
	params.IgnoreWater = true
	local result = Workspace:Raycast(at, Vector3.new(0, -(depth or 30), 0), params)
	return if result then result.Position.Y else nil
end

-- Quantise a value to a step (fewer property writes, so billboards keep their render cache).
function WorldKit.quantise(v: number, step: number): number
	return math.floor(v / step + 0.5) * step
end

-- PLATE -------------------------------------------------------------------------------------
-- The kit nameplate: an optional tag row (NEW! and the variant tag, never merged with rarity),
-- the rarity row (pip diamonds + the outlined rarity word; the word and pip count carry the
-- meaning, colour is a third cue), the car name, and an optional state row (CAPTURING).
-- Rows stack from the bottom, so hidden rows collapse toward the car.

export type Plate = {
	holder: Frame,
	width: number,
	height: number,
	tags: Frame,
	newTag: TextLabel,
	variantTag: TextLabel,
	rarityWord: TextLabel,
	pips: Frame,
	name: TextLabel,
	state: TextLabel,
	fadeables: { { obj: Instance, prop: string, base: number } },
	setCar: (car: CarInfo) -> (),
	setState: (state: string?) -> (),
	setAlpha: (alpha: number) -> (),
}

WorldKit.PlateWidthMin = 200
WorldKit.PlateWidthMax = 360
WorldKit.PlateRows = table.freeze({ Tags = 24, Rarity = 34, Name = 28, State = 26 })
WorldKit.PlateText = table.freeze({ Rarity = 28, Name = 22, Tag = 20, State = 20 })

-- Variant tag colours (finishes, not rarities). TOKEN CANDIDATE.
local VARIANT_FACE: { [string]: ColorSequence } = {
	Gold = A.Face.Keys,
	Chrome = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(196, 210, 228)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(130, 146, 170)),
	}),
	Rainbow = A.Fill.Rainbow,
}

local function measure(text: string, size: number): number
	local ok, v = pcall(function()
		return TextService:GetTextSize(text, size, Enum.Font.FredokaOne, Vector2.new(4000, 200))
	end)
	return if ok then (v :: Vector2).X else #text * size * 0.55
end

function WorldKit.plate(parent: Instance, car: CarInfo, options: { width: number? }?): Plate
	local rows = WorldKit.PlateRows
	local sizes = WorldKit.PlateText
	local height = rows.Tags + rows.Rarity + rows.Name + rows.State
	local width = (options and options.width) or 280
	local holder = make("Frame", {
		Name = "Plate",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(width, height),
		Parent = parent,
	})
	make("UIListLayout", {
		FillDirection = Enum.FillDirection.Vertical,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Bottom,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = holder,
	})
	local fadeables: { { obj: Instance, prop: string, base: number } } = {}
	local function track(gui: Instance)
		for _, d in gui:GetDescendants() do
			if d:IsA("TextLabel") then
				table.insert(fadeables, { obj = d, prop = "TextTransparency", base = d.TextTransparency })
			elseif d:IsA("UIStroke") then
				table.insert(fadeables, { obj = d, prop = "Transparency", base = d.Transparency })
			elseif d:IsA("Frame") and d.BackgroundTransparency < 1 then
				table.insert(fadeables, { obj = d, prop = "BackgroundTransparency", base = d.BackgroundTransparency })
			end
		end
	end

	local function row(name: string, h: number, order: number, horizontal: boolean): Frame
		local r = make("Frame", {
			Name = name,
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, h),
			LayoutOrder = order,
			Parent = holder,
		})
		if horizontal then
			make("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 8),
				Parent = r,
			})
		end
		return r
	end

	local tags = row("Tags", rows.Tags, 1, true)
	local newTag = Arcade.text(tags, {
		text = "NEW!",
		role = "Label",
		name = "New",
		size = sizes.Tag,
		colour = A.Badge,
		italic = true,
		outline = "Major",
		autoWidth = true,
	})
	newTag.LayoutOrder = 1
	local variantTag = Arcade.text(tags, {
		text = "",
		role = "Label",
		name = "Variant",
		size = sizes.Tag,
		italic = true,
		outline = "Major",
		autoWidth = true,
	})
	variantTag.LayoutOrder = 2
	local variantGrad = make("UIGradient", { Rotation = 0, Parent = variantTag })

	local rarityRow = row("Rarity", rows.Rarity, 2, true)
	local pips = make("Frame", {
		Name = "Pips",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(0, 16),
		AutomaticSize = Enum.AutomaticSize.X,
		LayoutOrder = 1,
		Parent = rarityRow,
	})
	make("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, 5),
		Parent = pips,
	})
	local pipFrames: { Frame } = {}
	for i = 1, 5 do
		local holderPip = make("Frame", {
			Name = "Pip" .. i,
			BackgroundTransparency = 1,
			Size = UDim2.fromOffset(13, 16),
			Parent = pips,
		})
		local diamond = make("Frame", {
			Name = "Diamond",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(10, 10),
			Rotation = 45,
			BackgroundColor3 = Color3.new(1, 1, 1),
			Parent = holderPip,
		})
		Arcade.corner(diamond, 2)
		Arcade.outline(diamond, "Minor")
		table.insert(pipFrames, holderPip)
	end
	local rarityWord = Arcade.text(rarityRow, {
		text = "COMMON",
		role = "Value",
		name = "RarityWord",
		size = sizes.Rarity,
		outline = "Major",
		autoWidth = true,
	})
	rarityWord.LayoutOrder = 2
	local rarityGrad = make("UIGradient", { Rotation = 90, Parent = rarityWord })

	local nameRow = row("Name", rows.Name, 3, false)
	local name = Arcade.text(nameRow, {
		text = car.name,
		role = "Label",
		name = "CarName",
		size = sizes.Name,
		outline = "Major",
	})
	name.Size = UDim2.fromScale(1, 1)
	name.TextTruncate = Enum.TextTruncate.AtEnd

	local stateRow = row("State", rows.State, 4, false)
	local state = Arcade.text(stateRow, {
		text = "CAPTURING",
		role = "Label",
		name = "PlateState",
		size = sizes.State,
		face = "Keys",
		italic = true,
		outline = "Major",
	})
	state.Size = UDim2.fromScale(1, 1)
	stateRow.Visible = false

	track(holder)

	local plate: Plate
	local function setCar(c: CarInfo)
		local r = WorldKit.rarity(c.rarity)
		rarityWord.Text = r.label
		rarityGrad.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, r.light:Lerp(Color3.new(1, 1, 1), 0.35)),
			ColorSequenceKeypoint.new(0.55, r.light),
			ColorSequenceKeypoint.new(1, r.deep),
		})
		for i, p in pipFrames do
			p.Visible = i <= r.pips
			local d = p:FindFirstChild("Diamond") :: Frame
			d.BackgroundColor3 = r.light
		end
		name.Text = c.name
		local isNew = WorldKit.isNew(c)
		newTag.Visible = isNew
		local v = c.variant
		local hasVariant = v ~= nil and v ~= "None" and v ~= ""
		variantTag.Visible = hasVariant
		if hasVariant then
			variantTag.Text = string.upper(v :: string)
			variantGrad.Color = VARIANT_FACE[v :: string] or ColorSequence.new(Color3.new(1, 1, 1))
			variantTag.TextColor3 = Color3.new(1, 1, 1)
		end
		tags.Visible = isNew or hasVariant
		-- width follows the name (never below the minimum text size; long names truncate)
		local w = math.clamp(measure(c.name, sizes.Name) + 28, WorldKit.PlateWidthMin, WorldKit.PlateWidthMax)
		plate.width = w
		holder.Size = UDim2.fromOffset(w, height)
	end
	local function setState(s: string?)
		stateRow.Visible = s ~= nil
		if s then
			state.Text = s
		end
	end
	local function setAlpha(alpha: number)
		for _, f in fadeables do
			(f.obj :: any)[f.prop] = 1 - (1 - f.base) * alpha
		end
	end
	plate = {
		holder = holder,
		width = width,
		height = height,
		tags = tags,
		newTag = newTag,
		variantTag = variantTag,
		rarityWord = rarityWord,
		pips = pips,
		name = name,
		state = state,
		fadeables = fadeables,
		setCar = setCar,
		setState = setState,
		setAlpha = setAlpha,
	}
	setCar(car)
	return plate
end

return WorldKit
