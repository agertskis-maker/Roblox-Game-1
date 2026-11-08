--!strict
-- CarLookApplier (Lane 3 Round 8, C-01; API frozen by the lead in vault/design/specs/lane3-round8-contracts.md, body built by
-- WS-1): puts a CarLook.Look on a car model, the same way everywhere (Style Shop turntable, shop tiles, launch card, Garage,
-- Raceway racing cars, parking ghosts, the run car). Wraps Style.BodyPaint, Style.DecalArt, the wheel kit and Style.TrailFx.
-- Everything it creates is owned by the handle's Trove and removed on update() or destroy().
--
--   local h = CarLookApplier.apply(model: Model, look: CarLook.Look, options: Options?) -> Handle
--   h:update(look)              re-dress (only the tabs that changed are rebuilt)
--   h:setTrailSpeed(0..1)       T-03: 0 = standing / launch card, 1 = top run speed
--   h:burst(moment)             T-04: "leap" | "dive" | "catch" | "flare"
--   h:moveTrailTo(model)        C-02: the trail follows the player to the next car (paint, decal, wheels stay behind)
--   h:setWheelSpin(radians)     turntables and the Raceway; the run turns wheels itself
--   h:destroy()
--
-- Options: ghost (H-03: see-through, no collision, no shadow, rarity outline, no trail), lod ("full" | "low": tiles and ghosts use
-- "low": no particles, no animated paint redraw), trail (default true), reduceMotion.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CarLook = require(ReplicatedStorage.Shared.Style.CarLook)
local Trove = require(ReplicatedStorage.Packages.Trove)

local CarLookApplier = {}

export type Options = {
	ghost: boolean?,
	ghostTransparency: number?, -- default 0.65
	outline: Color3?, -- ghost rarity outline
	lod: ("full" | "low")?,
	trail: boolean?,
	reduceMotion: boolean?,
}

export type Moment = "leap" | "dive" | "catch" | "flare"

export type Handle = {
	model: Model,
	look: CarLook.Look,
	update: (self: Handle, look: CarLook.Look) -> (),
	setTrailSpeed: (self: Handle, speed: number) -> (),
	burst: (self: Handle, moment: Moment) -> (),
	moveTrailTo: (self: Handle, model: Model) -> (),
	setWheelSpin: (self: Handle, radians: number) -> (),
	destroy: (self: Handle) -> (),
}

local Applied = {}
Applied.__index = Applied

function CarLookApplier.apply(model: Model, look: CarLook.Look, options: Options?): Handle
	local self = setmetatable({
		model = model,
		look = look,
		options = options or {},
		trove = Trove.new(),
	}, Applied)
	-- WS-1 builds the body: paint, decal, wheels, trail through the Style modules.
	return (self :: any) :: Handle
end

function Applied.update(self: any, look: CarLook.Look)
	self.look = look
end

function Applied.setTrailSpeed(_self: any, _speed: number) end

function Applied.burst(_self: any, _moment: Moment) end

function Applied.moveTrailTo(self: any, model: Model)
	self.trailModel = model
end

function Applied.setWheelSpin(_self: any, _radians: number) end

function Applied.destroy(self: any)
	self.trove:Destroy()
end

return CarLookApplier
