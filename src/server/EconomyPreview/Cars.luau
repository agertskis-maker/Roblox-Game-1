--!strict
-- Reads car facts from Brian L's models in ReplicatedStorage.Cars (Lane 2, PREVIEW). A car's id
-- is its Normal model's CarName attribute; its rarity is that model's Rarity attribute.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Catalog = require(ReplicatedStorage.Shared.Catalog.EconomyPreview)

local Cars = {}

local rarityById: { [string]: Catalog.Rarity } = {}

local VALID: { [string]: boolean } = {
	COMMON = true,
	UNCOMMON = true,
	RARE = true,
	EPIC = true,
	LEGENDARY = true,
}

function Cars.load()
	table.clear(rarityById)
	local folder = ReplicatedStorage:FindFirstChild("Cars")
	if not folder then
		warn("[EconomyPreview] ReplicatedStorage.Cars is missing; no car pays Lap Pay")
		return
	end
	for _, model in folder:GetChildren() do
		local id = model:GetAttribute("CarName")
		local rarity = model:GetAttribute("Rarity")
		if
			model:IsA("Model")
			and model:GetAttribute("Variant") == "Normal"
			and typeof(id) == "string"
			and typeof(rarity) == "string"
			and VALID[rarity]
		then
			rarityById[id] = rarity :: Catalog.Rarity
		end
	end
end

function Cars.rarity(id: string): Catalog.Rarity?
	return rarityById[id]
end

function Cars.exists(id: string): boolean
	return rarityById[id] ~= nil
end

function Cars.all(): { [string]: Catalog.Rarity }
	return table.clone(rarityById)
end

return Cars
