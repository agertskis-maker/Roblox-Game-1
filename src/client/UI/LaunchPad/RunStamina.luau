--!strict
-- Stamina in the real run: the lightning bolts (Lane 3, Round 3; Adam: "so people can't have infinite runs"). The team's proposal from
-- HUD Round 2: 10 Stamina per run, one spent on each hop that really happens, a refused press spends nothing, and at zero there are
-- no more hops, so the ride ends the run. Lives in the beta from outside Brian R's files: his input calls run:requestHop(), so a
-- field of that name on this run object goes first and his method does the hop. Move the rule into his RunController when agreed.
--
--   local s = RunStamina.attach(run, { spent = fn? })   s:value()   s:isOut()   s:refill(n)   s:destroy()
--
-- Nothing is bought here and nothing is saved: a new run starts full. Colours: 6-10 yellow, 4-5 orange, 1-3 red, 0 cracked.

local Players = game:GetService("Players")

local Prototype = script.Parent.Parent.Prototype
local CarKit = require(Prototype.CarKit)
local Motion = require(Prototype.Motion)
local StaminaBolt = require(Prototype.Run.StaminaBolt) :: any

local make = CarKit.make

local RunStamina = {}

RunStamina.Max = 10
RunStamina.ReviveRefill = 3

local YELLOW = Color3.fromRGB(255, 216, 50)
local ORANGE = Color3.fromRGB(255, 150, 40)
local RED = Color3.fromRGB(255, 70, 60)
local SPENT = Color3.fromRGB(60, 68, 92)

local function colourFor(v: number): Color3
	return if v >= 6 then YELLOW elseif v >= 4 then ORANGE else RED
end

function RunStamina.attach(run: any): { [string]: any }
	local value = RunStamina.Max
	local viewport = (workspace.CurrentCamera :: Camera).ViewportSize
	local phone = math.min(viewport.X, viewport.Y) < 500
	local gui = make("ScreenGui", {
		Name = "Lane3RunStamina",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 6,
	}, Players.LocalPlayer:WaitForChild("PlayerGui")) :: ScreenGui
	local boltPx = if phone then 15 else 19
	local heroPx = if phone then 32 else 42
	local width = heroPx + 12 + (boltPx * 0.7 + 3) * 5 + 12
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
	for i = 1, RunStamina.Max do
		local pip = StaminaBolt.new(board, { height = boltPx, colour = YELLOW, slim = 0.8 })
		pip.root.AnchorPoint = Vector2.new(0, 0)
		local row = if i <= 5 then 0 else 1
		pip.root.Position = UDim2.fromOffset(pipsX + ((i - 1) % 5) * (boltPx * 0.7 + 3), 8 + row * (boltPx + 6))
		pip.root.ZIndex = 4
		table.insert(pips, pip)
	end
	local out = CarKit.title(gui, "OUT OF BOLTS!", if phone then 26 else 34, {
		align = Enum.TextXAlignment.Center,
		size = UDim2.fromOffset(420, 44),
		position = UDim2.fromScale(0.5, 0.3),
		anchor = Vector2.new(0.5, 0.5),
		top = CarKit.Yellow,
		bottom = CarKit.Orange,
		z = 4,
		name = "Out",
	})
	out.Visible = false

	local function draw()
		local c = colourFor(value)
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
		value = math.min(value + n, RunStamina.Max)
		draw()
	end

	function self.destroy(_self: any)
		run.requestHop = nil
		gui:Destroy()
	end

	return self
end

return RunStamina
