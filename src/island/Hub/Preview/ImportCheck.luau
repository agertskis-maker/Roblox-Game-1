--!strict
-- DEVELOPMENT PREVIEW ONLY (Lane 3). Checks a 3D Importer batch right after the import, in Adam's
-- private island test place (edit mode), and writes the id lines to paste into the asset table.
-- Used for the group-owned re-import of the island's 97 Task 4 kit meshes
-- (vault/design/specs/island-group-reimport.md) and for the Speedway kit upload.
--
--   local C = require(game.ServerStorage.Island:Clone().Hub.Preview.ImportCheck)
--   print(C.run(workspace["island-kit"], "Task4", 12345678))   -- the imported model, set, group id
--   print(C.run(workspace["island-kit-speedway"], "Speedway", 12345678))
--
-- Checks: every expected mesh name present once and nothing extra; one distinct MeshId each;
-- MeshSize matches the recorded bounds (within 0.01 studs); and, with a group id, that
-- MarketplaceService reports the group as each asset's creator (sampled: every 8th mesh and the
-- first and last, to stay within request limits). Nothing is changed in the place.

local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local KitManifest = require(script.Parent.Parent.Environment.KitManifest)

local ImportCheck = {}

local TASK4_GROUPS = { park4 = true, gates = true, stunt = true, garage = true }

type Entry = { min: Vector3, max: Vector3 }

local function expected(set: string): { [string]: Entry }
	local out: { [string]: Entry } = {}
	if set == "Task4" then
		for name, e in KitManifest :: any do
			if TASK4_GROUPS[e.group] then
				out[name] = e
			end
		end
	elseif set == "Speedway" then
		local shared = ReplicatedStorage:FindFirstChild("Shared") :: any
		local manifest = (require :: any)(shared:Clone().Island.Speedway.KitManifest)
		for name, e in manifest do
			out[name] = e
		end
	else
		error("unknown set " .. set)
	end
	return out
end

local function idNumber(meshId: string): number?
	return tonumber(string.match(meshId, "%d+$"))
end

function ImportCheck.run(model: Instance, set: string, groupId: number?): { [string]: any }
	local want = expected(set)
	local found: { [string]: MeshPart } = {}
	local duplicates, extras, sizeOff = {}, {}, {}
	local ids: { [string]: string } = {}
	for _, d in model:GetDescendants() do
		if d:IsA("MeshPart") then
			if not want[d.Name] then
				table.insert(extras, d.Name)
			elseif found[d.Name] then
				table.insert(duplicates, d.Name)
			else
				found[d.Name] = d
			end
		end
	end
	local missing = {}
	local names = {}
	for name, e in want do
		local part = found[name]
		if not part then
			table.insert(missing, name)
			continue
		end
		table.insert(names, name)
		local size = e.max - e.min
		local diff = (part.MeshSize - size).Magnitude
		if diff > 0.01 then
			table.insert(sizeOff, string.format("%s %.3f", name, diff))
		end
		local id = part.MeshId
		if ids[id] then
			table.insert(duplicates, name .. " shares " .. ids[id])
		end
		ids[id] = name
	end
	table.sort(names)
	table.sort(missing)
	-- creator check (sampled)
	local creator = { checked = 0, group = 0, other = {} }
	if groupId then
		for i, name in names do
			if i == 1 or i == #names or i % 8 == 0 then
				local n = idNumber(found[name].MeshId)
				local ok, info = pcall(function()
					return MarketplaceService:GetProductInfo(n :: number, Enum.InfoType.Asset)
				end)
				creator.checked += 1
				if
					ok
					and info.Creator
					and info.Creator.CreatorType == "Group"
					and info.Creator.CreatorTargetId == groupId
				then
					creator.group += 1
				else
					table.insert(
						creator.other,
						name .. " " .. (if ok then tostring(info.Creator and info.Creator.Name) else tostring(info))
					)
				end
			end
		end
	end
	-- the lines to paste (name = id(...)), sorted
	local lines = {}
	for _, name in names do
		table.insert(lines, string.format("\t%s = id(%s),", name, tostring(idNumber(found[name].MeshId))))
	end
	return {
		set = set,
		expected = (function()
			local n = 0
			for _ in want do
				n += 1
			end
			return n
		end)(),
		found = #names,
		missing = missing,
		extras = extras,
		duplicates = duplicates,
		sizeMismatches = sizeOff,
		creator = creator,
		idLines = table.concat(lines, "\n"),
	}
end

return ImportCheck
