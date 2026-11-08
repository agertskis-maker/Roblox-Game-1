--!strict
-- CarLook (Lane 3 Round 8, C-01; contract frozen by the lead in vault/design/specs/lane3-round8-contracts.md): the ONE data shape
-- for "how a car looks". Every place that shows a car dressed in a player's style (Style Shop turntable, shop tiles, launch card,
-- Garage, Raceway racing cars, parking ghosts, the run car) builds a Look here and hands it to the client applier
-- (src/client/UI/Prototype/Style/CarLookApplier.luau). Data only: no instances, no remotes, safe on server and client.
--
-- The look belongs to the PLAYER (Round 7 rule kept, decision 0043): the save's `Equipped` holds one id per tab and the look
-- applies to whichever car the player rides or displays. Caught cars in a run keep their own look; only the trail follows you.
--
--   CarLook.fromEquipped(car, equipped) -> Look      equipped = { Paint = id?, Decals = id?, Wheels = id?, Trails = id? }
--   CarLook.fromAttribute(car, json?) -> Look         the Player attribute BetaStyle ({ o = owned, e = equipped })
--   CarLook.plain(car) -> Look                        the car as Brian L made it
--   CarLook.equal(a, b) -> boolean                    CarLook.withCar(look, car) -> Look
--   CarLook.key(look) -> string                       a stable cache key (tiles, ghosts)

local HttpService = game:GetService("HttpService")

local CarLook = {}

export type Look = {
	car: string, -- the car model name under ReplicatedStorage.Cars (Brian L's ids are model names)
	paint: string?, -- CosmeticPreviewCatalog Paint id; nil = factory paint
	decal: string?, -- Decals id; nil = no decal
	wheels: string?, -- Wheels id; nil = stock wheels
	trail: string?, -- Trails id; nil = no trail
	matchPaint: boolean?, -- T-08: take the trail colour from the paint (only trails that allow it)
}

local NONE: { [string]: boolean } = {
	[""] = true,
	none = true, -- CosmeticPreviewCatalog.defaultEquipped(): factory_paint, none, stock_five, no_trail
	factory_paint = true,
	stock_five = true,
	no_trail = true,
}

local function clean(id: any): string?
	if type(id) ~= "string" or NONE[id] or #id > 64 then
		return nil
	end
	return id
end

function CarLook.plain(car: string): Look
	return { car = car }
end

function CarLook.fromEquipped(car: string, equipped: { [string]: any }?): Look
	local e = equipped or {}
	return {
		car = car,
		paint = clean(e.Paint),
		decal = clean(e.Decals),
		wheels = clean(e.Wheels),
		trail = clean(e.Trails),
		matchPaint = if e.MatchPaint == true then true else nil,
	}
end

function CarLook.fromAttribute(car: string, json: any): Look
	if type(json) ~= "string" or json == "" then
		return CarLook.plain(car)
	end
	local ok, data = pcall(function()
		return HttpService:JSONDecode(json)
	end)
	if not ok or type(data) ~= "table" then
		return CarLook.plain(car)
	end
	return CarLook.fromEquipped(car, if type(data.e) == "table" then data.e else nil)
end

function CarLook.withCar(look: Look, car: string): Look
	local copy = table.clone(look)
	copy.car = car
	return copy
end

function CarLook.equal(a: Look?, b: Look?): boolean
	if a == nil or b == nil then
		return a == b
	end
	return a.car == b.car
		and a.paint == b.paint
		and a.decal == b.decal
		and a.wheels == b.wheels
		and a.trail == b.trail
		and (a.matchPaint == true) == (b.matchPaint == true)
end

function CarLook.key(look: Look): string
	return table.concat({
		look.car,
		look.paint or "-",
		look.decal or "-",
		look.wheels or "-",
		look.trail or "-",
		if look.matchPaint then "m" else "-",
	}, "|")
end

return CarLook
