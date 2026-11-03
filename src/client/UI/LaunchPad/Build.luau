--!strict
-- The Launch Pads' world (Lane 3, Launch Pad redesign, Direction B: Sky Launch Platform). One measured layout, three skins: a round
-- platform floating over its World, the arrival pad in the south, the emblem in the middle, the ramp and START gantry north, the
-- kiosks round the edge and a real HOME portal south-west. Built on the client when first needed, far from the island and the run
-- road. Only the floor, ramp and invisible edge walls collide. Local +Z is south, -Z is north, y = 0 is the floor.
--
--   Build.build(world, origin) -> Pad
--   Pad = { folder, arrival: CFrame, rampCentre, rampHalf, home: Vector3, stalls = { Cars = Part, Trails = Part, Paint = Part } }
--   pad:step(dt)                 motion, called while the pad is on show
--   pad:showChevrons(on)         the way to the ramp
--   pad:setLight(i, colour?)     one of the four start lights; nil is off
--   pad:destroy()

local Motion = require(script.Parent.Parent.Prototype.Motion)
local StyleState = require(script.Parent.Parent.Prototype.StyleState)
local PadBackdrop = require(script.Parent.PadBackdrop)
local PadKit = require(script.Parent.PadKit)
local PadParts = require(script.Parent.PadParts)

local Build = {}

export type Pad = {
	folder: Folder,
	arrival: CFrame,
	rampCentre: Vector3,
	rampHalf: Vector2,
	home: Vector3,
	stalls: { [string]: BasePart },
	gantryView: CFrame,
	theme: any,
	floorY: number,
	step: (self: Pad, dt: number) -> (),
	showChevrons: (self: Pad, on: boolean) -> (),
	setLight: (self: Pad, index: number, colour: Color3?) -> (),
	destroy: (self: Pad) -> (),
}

local LIGHT_OFF = Color3.fromRGB(60, 26, 30)
local WORLD_NAME: { [string]: string } =
	{ Downtown = "DOWNTOWN", DustyHighway = "DUSTY HIGHWAY", SummitPass = "SUMMIT PASS" }

function Build.build(world: string, origin: CFrame): Pad
	local theme = PadKit.Themes[world] or PadKit.Themes.Downtown
	local folder = Instance.new("Folder")
	folder.Name = "Lane3_LaunchPad_" .. world
	local k = PadKit.new(folder, origin)

	local updates: { (number, number) -> () } = {}
	local function life(fn: (number, number) -> ())
		table.insert(updates, fn)
	end

	PadBackdrop.build(k, world, theme, life)
	PadParts.platform(k, theme)
	PadParts.emblem(k, theme)
	local name = WORLD_NAME[world] or world
	local chevrons = PadParts.arrival(k, theme, name)
	PadParts.ramp(k, theme)
	local lights = PadParts.gantry(k, theme, name)
	local home = PadParts.homePortal(k, theme, life)
	local stalls, syncCars = PadParts.kiosks(k, theme, life)
	PadParts.touches(k, theme, world, life)

	local chevronsOn = false
	local rings: { BasePart } = {}
	for _, ring in stalls do
		table.insert(rings, ring)
	end
	life(function(t: number, _dt: number)
		-- the stand circles breathe; the chevrons run toward the ramp
		local still = Motion.reduced()
		for i, ring in rings do
			ring.Transparency = if still then 0.15 else 0.2 + 0.2 * math.sin(t * 2.4 + i)
		end
		if chevronsOn then
			for _, c in chevrons do
				local s = c:GetAttribute("Step") :: number
				c.Transparency = if still then 0.1 else 0.15 + 0.7 * ((t * 1.6 + s * 0.2) % 1)
			end
		end
	end)

	local carWatch = StyleState.Changed:Connect(syncCars)
	local clock = 0
	local foot = PadParts.RampFoot
	local pad: any = {
		folder = folder,
		arrival = origin * CFrame.new(0, 3.2, 34),
		rampCentre = (origin * CFrame.new(0, 4, foot - 9)).Position,
		rampHalf = Vector2.new(PadParts.RampWidth / 2 + 1, 8),
		home = home,
		stalls = stalls,
		gantryView = CFrame.lookAt(
			(origin * CFrame.new(0, 10, foot + 7)).Position,
			(origin * CFrame.new(0, 19, foot - 21)).Position
		),
		theme = theme,
		floorY = origin.Y,
	}
	function pad.step(_self: Pad, dt: number)
		clock += dt
		for _, fn in updates do
			fn(clock, dt)
		end
	end
	function pad.showChevrons(_self: Pad, on: boolean)
		chevronsOn = on
		if not on then
			for _, c in chevrons do
				c.Transparency = 1
			end
		end
	end
	function pad.setLight(_self: Pad, index: number, colour: Color3?)
		local lamp = lights[index]
		if lamp then
			lamp.Color = colour or LIGHT_OFF
			lamp.Material = if colour then Enum.Material.Neon else Enum.Material.Glass
		end
	end
	function pad.destroy(self: Pad)
		carWatch:Disconnect()
		self.folder:Destroy()
	end
	return pad :: Pad
end

return Build
