--!strict
-- AssetIds types (Round 8, contract frozen by the lead).

export type Entry = {
	id: number?, -- the uploaded, group-owned (LEGION STUDI0S, 74306252) asset id; nil until the lead uploads it
	kind: ("Image" | "Mesh" | "Audio" | "Model")?, -- default Image
	size: Vector2?, -- the source pixel size (images)
	slice: Rect?, -- 9-slice centre in source pixels (frames that stretch)
	frames: number?, -- flipbook sheets: 4, 16 or 64 (2x2, 4x4, 8x8)
	source: string?, -- where it came from (file name, or the ParticleFX Studio page link)
}

return {}
