--!strict
-- Anchors types (Round 8, contract frozen by the lead). All positions are in the car model's own space: relative to the model's
-- pivot (Model:GetPivot()), studs, at the model's unscaled size. Appliers scale them with the model (ScaleTo) themselves.

export type Wheels = {
	hubs: { CFrame }, -- four hub frames: front-left, front-right, rear-left, rear-right; +X points OUT of the car
	radius: number, -- tyre outer radius
	width: number, -- tyre width
	hideParts: { string }?, -- names of the car's own wheel parts to hide when custom wheels are worn
}

export type Exhausts = {
	points: { CFrame }, -- one or two exhaust frames; +Z points backwards, away from the car
	wheelSmoke: boolean?, -- Drift Smoke style trails come from the rear wheels instead
}

export type DecalPanels = {
	left: CFrame, -- centre of the left body panel, +Z out of the panel
	right: CFrame,
	size: Vector2, -- usable panel size (length along the car, height), avoiding windows, arches, lights and door gaps
}

export type PaintParts = {
	body: { string }?, -- part names that take body paint (when a car is made of several parts)
	never: { string }?, -- part names that never take paint (glass, lights, tyres, rims, grille, chrome, plates, signs, racks)
	mask: string?, -- PaintMasks key when one mesh mixes body and glass
}

return {}
