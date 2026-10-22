--!strict
-- ROAD WIDTH STUDY (Lane 3 preview, ledger D-04 / D-05). Side-by-side straight road
-- cross-sections for lane widths 12.5 / 16 / 17 / 18 studs, each 4 lanes + 4-stud shoulders,
-- kerb and 12-stud sidewalks, with the fixture cars' proxy footprints placed in their lanes:
--   row A  every lane side by side (the tightest squeeze): bus, Puglet, pickup, motorcycle
--   row B  a staggered row behind with realistic along-lane gaps
-- It documents the spacing ratios (car width / lane width, the body gap between cars in
-- adjacent lanes, the Hop gap from the Puglet to its neighbour) for visual clearance and scale
-- only. No steering, no camera change, nothing for Lane 1 to adopt without Brian R; the chosen
-- route value (17) is a reversible preview. Metres are PROVISIONAL (1 stud = 0.28 m).

local HttpService = game:GetService("HttpService")
local Workspace = game:GetService("Workspace")

local Cars = require(script.Parent.Cars)
local Proxies = require(script.Parent.Proxies)
local Sequencer = require(script.Parent.Sequencer)
local Util = require(script.Parent.Util)

local RoadWidthStudy = {}

RoadWidthStudy.FOLDER = "Lane3_CityWidthStudy"
RoadWidthStudy.WIDTHS = table.freeze({ 12.5, 16, 17, 18 })
RoadWidthStudy.LANES = 4
RoadWidthStudy.SHOULDER = 4
RoadWidthStudy.LENGTH = 150
RoadWidthStudy.ORIGIN = CFrame.new(0, 0, 700) -- behind the city route's start (the route runs toward -Z)

-- row A: one car per lane, side by side, at u 40; row B: staggered with along-lane gaps
local ROW_A = { "fishbowl", "puglet", "rangy", "zoomurai" }
local ROW_B = { { "puglet", 92 }, { "rev6", 70 }, { "waffle", 104 }, { "puglet", 66 } }

export type Row = {
	laneWidth: number,
	laneWidthMetresProvisional: number,
	carriageway: number, -- lanes x width + 2 shoulders
	pugletWidthRatio: number,
	busWidthRatio: number,
	motorcycleWidthRatio: number,
	pugletSideClearance: number, -- (lane - Puglet width) / 2
	hopGapPugletToPuglet: number, -- body gap, Puglet next to a Puglet in the next lane
	hopGapPugletToBus: number,
	minAdjacentBodyGapRowA: number,
	alongLaneGapsRowB: { number }, -- bumper-to-bumper gaps, row A car to row B car per lane
}

export type Result = { rows: { Row }, summary: string, folder: Folder? }

local function laneCentre(width: number, lane: number): number
	return -RoadWidthStudy.LANES * width / 2 + width * (lane - 0.5)
end

local function r2(x: number): number
	return Util.round(x, 2)
end

-- The ratios only (pure; no instances).
function RoadWidthStudy.ratios(widths: { number }?): { Row }
	local rows: { Row } = {}
	local puglet = Cars.byId("puglet")
	local bus = Cars.byId("fishbowl")
	local moto = Cars.byId("zoomurai")
	for _, w in widths or RoadWidthStudy.WIDTHS do
		local minGap = math.huge
		for lane = 1, #ROW_A - 1 do
			local a, b = Cars.byId(ROW_A[lane]), Cars.byId(ROW_A[lane + 1])
			minGap = math.min(minGap, w - (a.width + b.width) / 2)
		end
		local gaps = {}
		for lane, entry in ROW_B do
			local a = Cars.byId(ROW_A[lane])
			local b = Cars.byId(entry[1] :: string)
			local du = (entry[2] :: number) - 40
			table.insert(gaps, r2(du - (a.length + b.length) / 2))
		end
		table.insert(rows, {
			laneWidth = w,
			laneWidthMetresProvisional = r2(w * Sequencer.STUDS_TO_METRES),
			carriageway = RoadWidthStudy.LANES * w + 2 * RoadWidthStudy.SHOULDER,
			pugletWidthRatio = r2(puglet.width / w),
			busWidthRatio = r2(bus.width / w),
			motorcycleWidthRatio = r2(moto.width / w),
			pugletSideClearance = r2((w - puglet.width) / 2),
			hopGapPugletToPuglet = r2(w - puglet.width),
			hopGapPugletToBus = r2(w - (puglet.width + bus.width) / 2),
			minAdjacentBodyGapRowA = r2(minGap),
			alongLaneGapsRowB = gaps,
		})
	end
	return rows
end

function RoadWidthStudy.describe(rows: { Row }): string
	local lines = {
		"=== Road width study (studs; metres PROVISIONAL at 1 stud = 0.28 m; visual clearance only) ===",
		string.format(
			"Puglet %.2f x %.2f x %.2f; Fishbowl bus %.2f wide; Zoomurai %.2f wide",
			Cars.PUGLET.length,
			Cars.PUGLET.width,
			Cars.PUGLET.height,
			Cars.byId("fishbowl").width,
			Cars.byId("zoomurai").width
		),
	}
	for _, r in rows do
		local gaps = {}
		for _, g in r.alongLaneGapsRowB do
			table.insert(gaps, tostring(g))
		end
		table.insert(
			lines,
			string.format(
				"lane %5.1f (%.2f m): road %5.1f | Puglet/lane %.2f, bus/lane %.2f, moto/lane %.2f | Puglet side clearance %.2f | Hop gap Puglet-Puglet %.2f, Puglet-bus %.2f | min adjacent gap row A %.2f | along-lane gaps row B %s",
				r.laneWidth,
				r.laneWidthMetresProvisional,
				r.carriageway,
				r.pugletWidthRatio,
				r.busWidthRatio,
				r.motorcycleWidthRatio,
				r.pugletSideClearance,
				r.hopGapPugletToPuglet,
				r.hopGapPugletToBus,
				r.minAdjacentBodyGapRowA,
				table.concat(gaps, " / ")
			)
		)
	end
	table.insert(
		lines,
		"Route preview value: lane " .. Sequencer.LANE_WIDTH .. " (reversible; Brian R owns lane geometry)."
	)
	return table.concat(lines, "\n")
end

export type Options = { parent: Instance?, origin: CFrame?, widths: { number }?, labels: boolean? }

-- Builds the study (destroying an earlier one) and returns the ratios.
function RoadWidthStudy.build(options: Options?): Result
	local opts = options or {}
	local parent = opts.parent or Workspace
	local old = parent:FindFirstChild(RoadWidthStudy.FOLDER)
	if old then
		old:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = RoadWidthStudy.FOLDER
	folder:SetAttribute("Note", "Lane 3 road width study (preview; visual clearance and scale only)")
	local origin = opts.origin or RoadWidthStudy.ORIGIN
	local widths = opts.widths or RoadWidthStudy.WIDTHS
	local rows = RoadWidthStudy.ratios(widths)
	local x = 0
	local totalWidth = 0
	for _, w in widths do
		totalWidth += 2 * (RoadWidthStudy.LANES * w / 2 + RoadWidthStudy.SHOULDER + 12) + 16
	end
	x = -totalWidth / 2
	local ground = Proxies.block("StudyGround")
	ground.Size = Vector3.new(totalWidth + 80, 1, RoadWidthStudy.LENGTH + 80)
	ground.CFrame = origin * CFrame.new(0, -0.85, -RoadWidthStudy.LENGTH / 2)
	ground.Color = Color3.fromRGB(200, 196, 184)
	ground.CastShadow = false
	ground.Parent = folder
	for i, w in widths do
		local halfRoad = RoadWidthStudy.LANES * w / 2 + RoadWidthStudy.SHOULDER
		local stripHalf = halfRoad + 12
		x += stripHalf
		local base = origin * CFrame.new(x, 0, 0)
		local strip = Instance.new("Folder")
		strip.Name = string.format("Lane%s", tostring(w))
		strip.Parent = folder
		local road = Proxies.road({
			kind = "Straight",
			length = RoadWidthStudy.LENGTH,
			bend = 0,
			radius = 360,
		}, {
			lanes = RoadWidthStudy.LANES,
			laneWidth = w,
			shoulder = RoadWidthStudy.SHOULDER,
			halfRoad = halfRoad,
			kerb = 0.8,
			sidewalk = 12,
		}, false)
		road:PivotTo(base)
		road.Parent = strip
		for lane, id in ROW_A do
			local car = Cars.byId(id)
			local model = Cars.build(car)
			model:PivotTo(base * CFrame.new(laneCentre(w, lane), 0, -40))
			model.Parent = strip
		end
		for lane, entry in ROW_B do
			local car = Cars.byId(entry[1] :: string)
			local model = Cars.build(car)
			model:PivotTo(base * CFrame.new(laneCentre(w, lane), 0, -(entry[2] :: number)))
			model.Parent = strip
		end
		local row = rows[i]
		local board = Proxies.block("StudyBoard")
		board.Size = Vector3.new(2 * halfRoad, 9, 0.4)
		board.Color = Color3.fromRGB(30, 42, 74)
		board.CFrame = base * CFrame.new(0, 14, 8) * CFrame.Angles(0, math.pi, 0)
		board.Parent = strip
		Proxies.text(
			board,
			Enum.NormalId.Front,
			string.format(
				"LANE %s studs (%.2f m PROVISIONAL)\nPuglet %.0f%% of lane | Hop gap %.1f | bus %.0f%%",
				tostring(w),
				row.laneWidthMetresProvisional,
				row.pugletWidthRatio * 100,
				row.hopGapPugletToPuglet,
				row.busWidthRatio * 100
			),
			Color3.fromRGB(255, 244, 220)
		)
		x += stripHalf + 16
	end
	folder.Parent = parent
	local summary = RoadWidthStudy.describe(rows)
	print(summary)
	print("[Lane3City] widthStudy " .. HttpService:JSONEncode(rows))
	return { rows = rows, summary = summary, folder = folder }
end

-- An overview camera on the study (edit mode or Play client).
function RoadWidthStudy.view(origin: CFrame?)
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end
	local o = origin or RoadWidthStudy.ORIGIN
	camera.CameraType = Enum.CameraType.Scriptable
	camera.FieldOfView = 70
	camera.CFrame = CFrame.lookAt((o * CFrame.new(0, 150, 150)).Position, (o * CFrame.new(0, 0, -50)).Position)
end

return RoadWidthStudy
