--!strict
-- DEVELOPMENT REVIEW CAMERAS (Lane 3). The saved camera transforms used for matched before
-- and after captures of the island environment (world studs; eye level is 5.5 above the
-- walking surface). Each entry is a camera position and the point it looks at.

export type View = { name: string, position: Vector3, lookAt: Vector3 }

local ReviewCameras: { View } = {
	{ name = "PlazaToFalls", position = Vector3.new(-10, 5.5, -32), lookAt = Vector3.new(-120, 60, 278) },
	{ name = "Plot01Entrance", position = Vector3.new(-235.7, 5.5, -63.2), lookAt = Vector3.new(20, 50, 420) },
	{ name = "Plot03Entrance", position = Vector3.new(-64, 5.5, -238), lookAt = Vector3.new(-10, 55, 420) },
	{ name = "Plot06Entrance", position = Vector3.new(235.7, 5.5, -63.2), lookAt = Vector3.new(-20, 50, 420) },
	{ name = "LakeShore", position = Vector3.new(150, 6, 76), lookAt = Vector3.new(-120, 40, 262) },
	{ name = "WaterfallBase", position = Vector3.new(-100, 14, 205), lookAt = Vector3.new(-120, 62, 280) },
	{ name = "MidLedgeBasin", position = Vector3.new(-78, 86, 232), lookAt = Vector3.new(-124, 70, 286) },
	{ name = "TreeGroup", position = Vector3.new(-118, 7, -150), lookAt = Vector3.new(-170, 8, -60) },
	-- re-aimed 2026-10-21 at a real drift (red tulips south-west of the hub; the old camera saw lawn)
	{ name = "FlowerMeadow", position = Vector3.new(-376.3, 22.8, -689.7), lookAt = Vector3.new(-383, 18, -702) },
	{ name = "Overview", position = Vector3.new(0, 420, -860), lookAt = Vector3.new(0, 40, 200) },
}

return ReviewCameras
