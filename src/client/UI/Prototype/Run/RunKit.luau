--!strict
-- Small shared helpers for the rebuilt run HUD (Lane 3 preview, HUD rebuild worker HR,
-- 2026-10-22). Not a component. Everything visual still comes from the Arcade kit and the
-- PreviewTokens Arcade block; the few values below that have no token yet are marked
-- TOKEN CANDIDATE (listed in the worker report for the lead).
--
--   RunKit.icons2() -> module?                 -- HA's Prototype/Icons2 when present (pcall)
--   RunKit.keyLock(holder) -> KeyLockParts     -- Icons2.keyLock, else a kit-built fallback
--   RunKit.rarity(car) -> token entry           -- PreviewTokens.Rarity (Common when unknown)
--   RunKit.districtColour(id) -> Color3         -- tile ground colour behind the district art
--   RunKit.avatar(holder, trove)                -- local player's head shot; fallback glyph
--                                                  while loading or on failure (never blocks)
--   RunKit.nonInteractive(gui)
--   RunKit.thumb(holder, car) -> ViewportFrame?  -- a STATIC car thumbnail for small tiles (the claimed tray)
--   RunKit.disc(parent, name, size, colour, z) -> Frame   -- a round frame

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Arcade = require(script.Parent.Parent.Arcade)
local Icons = require(script.Parent.Parent.Icons)
local PreviewTokens = require(script.Parent.Parent.PreviewTokens)
local ProxyCar = require(script.Parent.Parent.ProxyCar)
local Store = require(script.Parent.Parent.Store)
local Trove = require(ReplicatedStorage.Packages.Trove)

local A = PreviewTokens.Arcade
local make = Arcade.make

local RunKit = {}

-- TOKEN CANDIDATE: silver ring / ribbon fill for an already-owned car (Joyride presentation).
RunKit.SilverFill = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(250, 252, 255)),
	ColorSequenceKeypoint.new(0.5, Color3.fromRGB(200, 210, 224)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(140, 152, 172)),
})
-- TOKEN CANDIDATE: unlit Keys segment / Heat slot (dark, readable against bright scenery).
RunKit.Slot = Color3.fromRGB(40, 50, 78)
-- TOKEN CANDIDATE: the warm cream-white centre plate of the Keys lock.
RunKit.Plate = Color3.fromRGB(255, 250, 236)

-- TOKEN CANDIDATE: district tile ground colours (behind HA's district art; the art carries the
-- landmark, the colour lets tiles read even before the art loads).
local DISTRICT_COLOURS: { [string]: Color3 } = {
	MainStreet = Color3.fromRGB(214, 92, 70), -- brick and marquee
	CityHall = Color3.fromRGB(232, 196, 110), -- sandstone
	HarborBridge = Color3.fromRGB(64, 150, 214), -- river
	Midtown = Color3.fromRGB(120, 132, 176), -- slate glass
	SkylinePark = Color3.fromRGB(104, 192, 96), -- park lawns
}

function RunKit.districtColour(id: string?): Color3
	return (id and DISTRICT_COLOURS[id]) or Color3.fromRGB(150, 160, 178)
end

-- A STATIC thumbnail of a car for small tiles: one ViewportFrame with the part-built proxy (or the real model once one
-- exists), fitted ONCE at a front three-quarter angle. No spin and no render loop: the caller keeps at most four alive
-- (the tray's slot count) and destroys the frame when the slot changes. nil when there is no model to show, so the
-- caller keeps its icon.
function RunKit.thumb(holder: Frame, car: Store.CarRef?): ViewportFrame?
	if not car then
		return nil
	end
	local model: Model? = nil
	if car.model == "Proxy" then
		model = ProxyCar.build(car)
	elseif car.model ~= nil then
		local folder = ReplicatedStorage:FindFirstChild("Cars")
		local source = folder and folder:FindFirstChild(car.model)
		if source and source:IsA("Model") then
			model = source:Clone()
		end
	end
	if not model then
		return nil
	end
	local m = model :: Model
	local cf, bounds = m:GetBoundingBox()
	m:PivotTo(m:GetPivot() - Vector3.new(cf.X, cf.Y - bounds.Y / 2, cf.Z))
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
		elseif d:IsA("Script") or d:IsA("LocalScript") or d:IsA("Sound") or d:IsA("ParticleEmitter") then
			d:Destroy()
		end
	end
	local vp = Instance.new("ViewportFrame")
	vp.Name = "Thumb"
	vp.BackgroundTransparency = 1
	vp.Size = UDim2.fromScale(1, 1)
	vp.Ambient = Color3.fromRGB(190, 196, 210)
	vp.LightColor = Color3.fromRGB(255, 252, 240)
	vp.LightDirection = Vector3.new(-0.4, -0.9, -0.5)
	m.Parent = vp
	local camera = Instance.new("Camera")
	camera.FieldOfView = 30
	camera.Parent = vp
	vp.CurrentCamera = camera
	-- fit once: the footprint fills about 80% of the width, three-quarter front, a little elevation
	local el, yaw = math.rad(15), math.rad(35)
	local radius = 0.5 * math.sqrt(bounds.X ^ 2 + bounds.Z ^ 2)
	local tanH = math.tan(math.rad(camera.FieldOfView) / 2)
	local distance = math.max(radius / math.sin(math.atan(0.8 * tanH)), bounds.Y / tanH)
	local target = Vector3.new(0, bounds.Y * 0.5, 0)
	local dir = Vector3.new(math.sin(yaw) * math.cos(el), math.sin(el), -math.cos(yaw) * math.cos(el))
	camera.CFrame = CFrame.lookAt(target + dir * distance, target)
	vp.Parent = holder
	return vp
end

local icons2: any = nil
local icons2Tried = false
function RunKit.icons2(): any
	if icons2Tried then
		return icons2
	end
	icons2Tried = true
	local module = script.Parent.Parent:FindFirstChild("Icons2")
	if module and module:IsA("ModuleScript") then
		local ok, result = pcall(require, module)
		if ok then
			icons2 = result
		end
	end
	return icons2
end

function RunKit.rarity(car: Store.CarRef?): any
	local r = car and (PreviewTokens.Rarity :: any)[car.rarity]
	return r or PreviewTokens.Rarity.Common
end

function RunKit.nonInteractive(g: GuiObject)
	g.Active = false
	pcall(function()
		(g :: any).Interactable = false
	end)
end

function RunKit.disc(parent: Instance, name: string, size: number, colour: Color3, z: number): Frame
	local f = make("Frame", {
		Name = name,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(size, size),
		BackgroundColor3 = colour,
		BorderSizePixel = 0,
		ZIndex = z,
		Parent = parent,
	})
	make("UICorner", { CornerRadius = UDim.new(0.5, 0), Parent = f })
	return f
end

export type KeyLockParts = {
	shackle: GuiObject,
	key: GuiObject,
	body: GuiObject,
	fallback: boolean,
}

-- A key-in-lock: gold padlock body with a keyhole, an outline shackle above it and a key in the
-- keyhole. Built from the kit when HA's Icons2.keyLock is not available.
local function fallbackKeyLock(holder: Frame): KeyLockParts
	local z = holder.ZIndex
	local shackle = make("Frame", {
		Name = "Shackle",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.5, 0.42),
		BackgroundTransparency = 1,
		ZIndex = z + 1,
		Parent = holder,
	})
	Arcade.corner(shackle, 999)
	local ring = make("UIStroke", {
		Thickness = 5,
		Color = A.Ink,
		Parent = shackle,
	})
	local _ = ring
	local inner = make("Frame", {
		Name = "Steel",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = z + 1,
		Parent = shackle,
	})
	Arcade.corner(inner, 999)
	make("UIStroke", { Thickness = 2.5, Color = Color3.fromRGB(214, 222, 236), Parent = inner })
	local body = make("Frame", {
		Name = "Body",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.42),
		Size = UDim2.fromScale(0.72, 0.5),
		BackgroundColor3 = Color3.new(1, 1, 1),
		ZIndex = z + 2,
		Parent = holder,
	})
	Arcade.corner(body, 6)
	Arcade.outline(body, "Major")
	make("UIGradient", { Color = A.Fill.Gold, Rotation = 90, Parent = body })
	local key = make("Frame", {
		Name = "Key",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.55),
		Size = UDim2.fromScale(0.62, 0.62),
		BackgroundTransparency = 1,
		ZIndex = z + 4,
		Parent = body,
	})
	Icons.draw(key, "Key", A.Ink)
	return { shackle = shackle, key = key, body = body, fallback = true }
end

function RunKit.keyLock(holder: Frame): KeyLockParts
	local mod = RunKit.icons2()
	if mod and type(mod.keyLock) == "function" then
		local ok, parts = pcall(mod.keyLock, holder)
		if ok and type(parts) == "table" and parts.shackle and parts.key and parts.body then
			return { shackle = parts.shackle, key = parts.key, body = parts.body, fallback = false }
		end
		holder:ClearAllChildren()
	end
	return fallbackKeyLock(holder)
end

-- The local player's head shot in a round holder (an ImageLabel named "Head" is created). A
-- simple face glyph shows while it loads or if it fails; the request never blocks.
local headCache: string? = nil
function RunKit.avatar(holder: Frame, trove: Trove.Trove)
	local z = holder.ZIndex
	local glyph = RunKit.disc(holder, "Fallback", 1, Color3.fromRGB(255, 214, 160), z + 1)
	glyph.Size = UDim2.fromScale(0.8, 0.8)
	for i, x in { 0.35, 0.65 } do
		local eye = RunKit.disc(glyph, "Eye" .. i, 1, A.Ink, z + 2)
		eye.Size = UDim2.fromScale(0.14, 0.14)
		eye.Position = UDim2.fromScale(x, 0.42)
	end
	local smile = make("Frame", {
		Name = "Smile",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.68),
		Size = UDim2.fromScale(0.36, 0.08),
		BackgroundColor3 = A.Ink,
		BorderSizePixel = 0,
		ZIndex = z + 2,
		Parent = glyph,
	})
	Arcade.corner(smile, 3)
	local image = make("ImageLabel", {
		Name = "Head",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Image = "",
		Visible = false,
		ZIndex = z + 3,
		Parent = holder,
	})
	Arcade.corner(image, 999)
	local function show(content: string)
		if image.Parent then
			image.Image = content
			image.Visible = true
			glyph.Visible = false
		end
	end
	if headCache then
		show(headCache)
		return
	end
	local player = Players.LocalPlayer
	if not player or player.UserId <= 0 then
		return
	end
	local thread = task.spawn(function()
		local ok, content = pcall(function()
			return Players:GetUserThumbnailAsync(
				player.UserId,
				Enum.ThumbnailType.HeadShot,
				Enum.ThumbnailSize.Size48x48
			)
		end)
		if ok and type(content) == "string" and content ~= "" then
			headCache = content
			show(content)
		end
	end)
	trove:Add(function()
		if coroutine.status(thread) == "suspended" then
			pcall(task.cancel, thread)
		end
	end)
end

-- Truthful reason text. Codes map to short child-friendly lines; a supplied sentence (contains a
-- space) is shown as given; anything else shows nothing rather than an invented reason.
local KEYS_REASONS: { [string]: string } = {
	HoppedOff = "You hopped off",
	Hopped = "You hopped off",
	Dismounted = "You hopped off",
	Crashed = "The car crashed",
	Despawned = "The car drove off",
	RunEnded = "The run ended",
	NotConfirmed = "Not confirmed",
	Timeout = "Not confirmed",
	Rejected = "Not confirmed",
}

function RunKit.keysReason(reason: string?): string?
	if type(reason) ~= "string" or reason == "" then
		return nil
	end
	local mapped = KEYS_REASONS[reason]
	if mapped then
		return mapped
	end
	if string.find(reason, " ", 1, true) then
		return reason
	end
	return nil
end

return RunKit
