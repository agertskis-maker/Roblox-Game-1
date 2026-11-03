--!strict
-- Stamina in the real run: the lightning bolts (Lane 3, Round 3; Adam: "so people can't have infinite runs"). 5 Stamina per run (Tunable,
-- Launch Pad redesign, B-01; it was 10), one spent on each hop that really happens, a refused press spends nothing, and at zero there
-- are no more hops, so the ride ends the run. Lives in the beta from outside Brian R's files: his input calls run:requestHop(), so a
-- field of that name on this run object goes first and his method does the hop. Move the rule into his RunController when agreed.
--
--   local s = RunStamina.attach(run, { max = n? })   s:value()   s:isOut()   s:refill(n)   s:destroy()
--
-- Nothing is bought here and nothing is saved: a new run starts full. Colours follow the share left: over half yellow, over a quarter
-- orange, then red; 0 is cracked.

local Players = game:GetService("Players")

local Prototype = script.Parent.Parent.Prototype
local CarKit = require(Prototype.CarKit)
local Motion = require(Prototype.Motion)
local StaminaBolt = require(Prototype.Run.StaminaBolt) :: any

local make = CarKit.make

local RunStamina = {}

RunStamina.Max = 5 -- Tunable
RunStamina.ReviveRefill = 2 -- Tunable
RunStamina.TutorialMax = 8 -- Tunable: the first run must leave room for a claim while a new player learns

local YELLOW = Color3.fromRGB(255, 216, 50)
local ORANGE = Color3.fromRGB(255, 150, 40)
local RED = Color3.fromRGB(255, 70, 60)
local SPENT = Color3.fromRGB(60, 68, 92)

local function colourFor(v: number, max: number): Color3
	local share = v / max
	return if share > 0.5 then YELLOW elseif share > 0.25 then ORANGE else RED
end

function RunStamina.attach(run: any, options: { max: number? }?): { [string]: any }
	local max = options and options.max or RunStamina.Max
	local value = max
	local viewport = (workspace.CurrentCamera :: Camera).ViewportSize
	local phone = math.min(viewport.X, viewport.Y) < 500
	local gui = make("ScreenGui", {
		Name = "Lane3RunStamina",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 6,
	}, Players.LocalPlayer:WaitForChild("PlayerGui")) :: ScreenGui
	local boltPx = if phone then 20 else 26 -- five big bolts read at a glance; a longer tutorial run takes a second row
	local heroPx = if phone then 32 else 42
	local perRow = 5
	local width = heroPx + 12 + (boltPx * 0.8 + 4) * perRow + 12
	local board = CarKit.board(gui, {
		size = UDim2.fromOffset(width, if phone then 58 else 72),
		position = UDim2.new(0, if phone then 10 else 18, 0.5, 40),
		anchor = Vector2.new(0, 0.5),
		radius = 12,
		top = Color3.fromRGB(20, 26, 50),
		bottom = Color3.fromRGB(10, 14, 30),
		name = "Stamina",
	})
	local hero = StaminaBolt.new(board, { height = heroPx, colour = YELLOW })
	hero.root.AnchorPoint = Vector2.new(0, 0.5)
	hero.root.Position = UDim2.new(0, 8, 0.5, 0)
	hero.root.ZIndex = 4
	local pips: { any } = {}
	local pipsX = heroPx * 0.75 + 16
	for i = 1, max do
		local pip = StaminaBolt.new(board, { height = boltPx, colour = YELLOW, slim = 0.9 })
		pip.root.AnchorPoint = Vector2.new(0, 0)
		local row = math.floor((i - 1) / perRow)
		local rowsTall = math.ceil(max / perRow)
		local top = if rowsTall > 1 then 4 else ((if phone then 58 else 72) - boltPx) / 2
		pip.root.Position = UDim2.fromOffset(pipsX + ((i - 1) % perRow) * (boltPx * 0.8 + 4), top + row * (boltPx + 2))
		pip.root.ZIndex = 4
		table.insert(pips, pip)
	end
	local out = CarKit.title(gui, "OUT OF BOLTS!", if phone then 26 else 34, {
		align = Enum.TextXAlignment.Center,
		size = UDim2.fromOffset(420, 44),
		position = UDim2.fromScale(0.5, 0.38),
		anchor = Vector2.new(0.5, 0.5),
		top = CarKit.Yellow,
		bottom = CarKit.Orange,
		z = 4,
		name = "Out",
	})
	out.Visible = false

	local function draw()
		local c = colourFor(value, max)
		hero:setColour(if value > 0 then c else SPENT)
		hero:setCracked(value <= 0)
		for i, pip in pips do
			pip:setColour(if i <= value then c else SPENT)
		end
	end
	draw()

	local shownOut = 0
	local function refused()
		out.Visible = true
		shownOut += 1
		local token = shownOut
		if not Motion.reduced() then
			Motion.pop(board, 1.12)
		end
		task.delay(1.2, function()
			if token == shownOut then
				out.Visible = false
			end
		end)
	end

	local original = run.requestHop
	run.requestHop = function(selfRun: any)
		if value <= 0 then
			refused()
			return
		end
		local before = selfRun:getDebugState().hops
		original(selfRun)
		if selfRun:getDebugState().hops > before then
			value -= 1
			draw()
			if value <= 0 then
				refused()
			end
		end
	end

	local self: { [string]: any } = {}

	function self.value(_self: any): number
		return value
	end

	function self.isOut(_self: any): boolean
		return value <= 0
	end

	function self.refill(_self: any, n: number)
		value = math.min(value + n, max)
		draw()
	end

	function self.destroy(_self: any)
		run.requestHop = nil
		gui:Destroy()
	end

	return self
end

return RunStamina
