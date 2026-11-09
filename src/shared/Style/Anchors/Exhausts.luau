--!strict
-- Anchors.Exhausts (Round 8, T-02): per-car data keyed by the car model name under ReplicatedStorage.Cars (Normal edition name; Gold,
-- Diamond and Rainbow editions share it unless a key of their own exists). Shape frozen in
-- vault/design/specs/lane3-round8-contracts.md; only the owning workstream edits this file.
--
-- Frame: the car's own frame, the same as Model:GetPivot() of the model as built in assets/cars (pivot at the bottom centre of the car,
-- +X to the car's right, +Y up, FRONT toward -Z, so +Z points backwards, away from the car). Positions are studs at the model's STORED
-- size (the size of ReplicatedStorage.Cars[name] as built; its Model:GetScale()). A user scales a point by
-- model:GetScale() / storedModel:GetScale() (TrailFx does this for you: TrailFx.attachModel / handle:setCar).
--
-- Each point sits on the car's rear end where the exhaust tail pipes would be: low on the rear bumper, never at the middle or the roof.
-- Measured from the part sizes and positions of each assets/cars/<name>.rbxmx (pivot frame), then checked by raycasts from behind onto
-- the car mesh in Studio (rear surface found at each x, then the point placed 0.15 stud behind it). Most cars have two points; vans and
-- the pizza truck have one (on the left side, like a real van). wheelSmoke = true: the car has two rear wheels that Drift Smoke can
-- pour from (TrailFx finds them from the model's own wheel parts).
local Types = require(script.Parent.Types)

local data: { [string]: Types.Exhausts } = {
	["Apex"] = { points = { CFrame.new(-1.91, 0.7, 4.9), CFrame.new(1.91, 0.7, 4.9) }, wheelSmoke = true },
	["Beach Bug"] = { points = { CFrame.new(-1.6, 1.5, 3.6), CFrame.new(1.6, 1.5, 3.6) }, wheelSmoke = true },
	["Bolt"] = { points = { CFrame.new(-1.8, 0.7, 4.9), CFrame.new(1.8, 0.7, 4.9) }, wheelSmoke = true },
	["Brawler"] = { points = { CFrame.new(-1.8, 1, 4.3), CFrame.new(1.8, 1, 4.3) }, wheelSmoke = true },
	["Commuter"] = { points = { CFrame.new(-1.98, 1, 5.3), CFrame.new(1.98, 1, 5.3) }, wheelSmoke = true },
	["Cruiser"] = { points = { CFrame.new(-1.95, 0.7, 5.3), CFrame.new(1.95, 0.7, 5.3) }, wheelSmoke = true },
	["Desert King"] = { points = { CFrame.new(-1, 1.6, 4.5), CFrame.new(1, 1.6, 4.5) }, wheelSmoke = true },
	["Executive"] = { points = { CFrame.new(-1.88, 1, 5.3), CFrame.new(1.88, 1, 5.3) }, wheelSmoke = true },
	["Family Hauler"] = { points = { CFrame.new(-1.4, 1, 5.75) }, wheelSmoke = true },
	["Minnow"] = { points = { CFrame.new(-2.25, 1.1, 4.5), CFrame.new(2.25, 1.1, 4.5) }, wheelSmoke = true },
	["Monarch"] = { points = { CFrame.new(-1.98, 1.5, 5.1), CFrame.new(1.98, 1.5, 5.1) }, wheelSmoke = true },
	["Night Rider"] = { points = { CFrame.new(-1.86, 1, 5.5), CFrame.new(1.86, 1, 5.5) }, wheelSmoke = true },
	["Old Faithful"] = { points = { CFrame.new(-1.8, 1.1, 5.4), CFrame.new(1.8, 1.1, 5.4) }, wheelSmoke = true },
	["Phantom"] = { points = { CFrame.new(-2.08, 0.7, 5.3), CFrame.new(2.08, 0.7, 5.3) }, wheelSmoke = true },
	["Pizza Runner"] = { points = { CFrame.new(-1.5, 0.9, 5.4) }, wheelSmoke = true },
	["Putter"] = { points = { CFrame.new(-2.35, 1.5, 5.2), CFrame.new(2.35, 1.5, 5.2) }, wheelSmoke = true },
	["Rally Dog"] = { points = { CFrame.new(-2.09, 1.3, 4.8), CFrame.new(2.09, 1.3, 4.8) }, wheelSmoke = true },
	["Rustbucket"] = { points = { CFrame.new(-2.18, 1.1, 5.15), CFrame.new(2.18, 1.1, 5.15) }, wheelSmoke = true },
	["Street Kid"] = { points = { CFrame.new(-1.95, 0.7, 5.3), CFrame.new(1.95, 0.7, 5.3) }, wheelSmoke = true },
	["Sunny Camper"] = { points = { CFrame.new(-1.46, 1.2, 5.35) }, wheelSmoke = true },
	["Surf Wagon"] = { points = { CFrame.new(-1.24, 1, 5.5) }, wheelSmoke = true },
	["Thunder"] = { points = { CFrame.new(-1.95, 1, 4.55), CFrame.new(1.95, 1, 4.55) }, wheelSmoke = true },
	["Trailblazer"] = { points = { CFrame.new(-2.13, 1.9, 4.95), CFrame.new(2.13, 1.9, 4.95) }, wheelSmoke = true },
	["Velvet"] = { points = { CFrame.new(-1.85, 0.7, 5.2), CFrame.new(1.85, 0.7, 5.2) }, wheelSmoke = true },
	["Viper Strike"] = { points = { CFrame.new(-2.1, 0.7, 5.1), CFrame.new(2.1, 0.7, 5.1) }, wheelSmoke = true },
	["Workhorse"] = { points = { CFrame.new(-1.49, 1.2, 4.25) }, wheelSmoke = true },
	["Zip"] = { points = { CFrame.new(-2.16, 0.6, 5.3), CFrame.new(2.16, 0.6, 5.3) }, wheelSmoke = true },
}

return data
