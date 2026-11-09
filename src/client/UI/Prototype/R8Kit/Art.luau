--!strict
-- R8Kit.Art (Lane 3 Round 8): picks the uploaded (or local-test) art of a kit piece, and its 9-slice, from AssetIds.UpgradeCards.
-- Every kit piece also draws itself in code, so `apply` returning false just means "show the code-drawn version".
--
--   Art.image(key) -> string                     "" when the art is not available here
--   Art.has(key) -> boolean
--   Art.apply(img, key) -> boolean               sets Image (+ ScaleType Slice and SliceCenter when the entry has a slice);
--                                                false (the label is blanked and hidden) when there is no art
--   Art.fitSlice(trove, img, key, axis)          keeps SliceScale = the label's real pixel size / the art's pixel size along
--                                                "x" or "y", so the corners keep their drawn proportions at any card size
--   Art.sprite(img, key, cell, cols, cellPx)     shows cell `cell` (1-based, row-major) of a sprite sheet

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AssetIds = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Style"):WaitForChild("AssetIds"))
local Trove = require(ReplicatedStorage.Packages.Trove)

local Art = {}

function Art.image(key: string): string
	return AssetIds.image(key)
end

function Art.has(key: string): boolean
	return AssetIds.image(key) ~= ""
end

function Art.apply(img: ImageLabel | ImageButton, key: string): boolean
	local url = AssetIds.image(key)
	if url == "" then
		img.Image = ""
		img.Visible = false
		return false
	end
	img.Image = url
	img.Visible = true
	local entry = AssetIds.entry(key)
	if entry and entry.slice then
		img.ScaleType = Enum.ScaleType.Slice
		img.SliceCenter = entry.slice
	else
		img.ScaleType = Enum.ScaleType.Stretch
	end
	return true
end

function Art.fitSlice(trove: Trove.Trove, img: ImageLabel | ImageButton, key: string, axis: string)
	local entry = AssetIds.entry(key)
	if not (entry and entry.size and entry.slice) then
		return
	end
	local art = entry.size
	local function update()
		local size = img.AbsoluteSize
		local s = if axis == "x" then size.X / art.X else size.Y / art.Y
		if s > 0 then
			img.SliceScale = s
		end
	end
	update()
	trove:Add(img:GetPropertyChangedSignal("AbsoluteSize"):Connect(update))
end

function Art.sprite(img: ImageLabel | ImageButton, key: string, cell: number, cols: number, cellPx: number): boolean
	local url = AssetIds.image(key)
	if url == "" then
		img.Image = ""
		img.Visible = false
		return false
	end
	img.Image = url
	img.Visible = true
	img.ScaleType = Enum.ScaleType.Stretch
	local index = cell - 1
	img.ImageRectOffset = Vector2.new((index % cols) * cellPx, (index // cols) * cellPx)
	img.ImageRectSize = Vector2.new(cellPx, cellPx)
	return true
end

return Art
