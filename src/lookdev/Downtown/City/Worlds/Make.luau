--!strict
-- Small constructors shared by the World data modules, so a lot module or a palette is one readable line.

local Catalog = require(script.Parent.Parent.Catalog)

local Make = {}

function Make.palette(id: string, wall: Color3, trim: Color3, accent: Color3, roof: Color3): Catalog.Palette
	return { id = id, wall = wall, trim = trim, accent = accent, roof = roof }
end

-- A roadside lot module (kind building / park / courtyard). Kit geometry replaces the proxy when a mesh of this exact
-- name exists in the kit; until then it is a labelled proxy and the planner does not care.
function Make.lot(
	name: string,
	kind: Catalog.LotKind,
	width: number,
	depth: number,
	height: number,
	heightClass: Catalog.HeightClass,
	finish: string,
	districts: { string },
	shop: boolean
): Catalog.LotModule
	local typeName = if kind == "park"
		then "Park"
		elseif kind == "courtyard" then "Court"
		elseif heightClass == "mid" then "Mid"
		else "Shop"
	return {
		name = name,
		type = typeName,
		kind = kind,
		width = width,
		depth = depth,
		height = height,
		heightClass = heightClass,
		orientation = "front",
		mirrorOf = nil,
		finish = finish,
		districts = districts,
		shop = shop,
		lod = "near",
		sockets = {},
		facing = "-Z",
		fromKit = false,
	}
end

function Make.landmark(
	id: string,
	name: string,
	label: string,
	width: number,
	depth: number,
	height: number,
	districts: { string },
	placement: "frontage" | "skyline" | "bridge"
): Catalog.Landmark
	return {
		id = id,
		name = name,
		label = label,
		width = width,
		depth = depth,
		height = height,
		districts = districts,
		placement = placement,
		fromKit = false,
	}
end

return Make
