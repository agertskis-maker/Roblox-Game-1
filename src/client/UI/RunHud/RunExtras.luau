--!strict
-- Round 7 (Lane 3, Module R presentation): what the run shows around Brian R's run, from Adam's reference video.
--   * A big round HOP button (bottom right; Space and the gamepad A button do the same) that flashes PRESS AGAIN! while you float
--     on a first run (R-01).
--   * END RUN (top right, 44 px or more) with "End this run? You keep the cars you caught." and KEEP DRIVING; the run waits while
--     it asks (R-07).
--   * BONK! over the spot where a bump, a road landing or a throw cost a bolt (R-04).
--   * IT'S YOURS! sliding in on the left with the car's name and "Keep going!", a burst of stars and hearts, and the SECURED counter
--     with small chips of this run's catches. Both update only from the server's grants, never on a dive (R-11).
--   * The distance in metres at the top centre and a district banner when you reach a new part of the World (R-11).
--   * LUCK x2 with a clover when the run's luck is above 1, and LUCKY! when a Rare or better joins the road while it is (R-12, L-03).
--   * An Epic's soft chime, a Legendary's fanfare and a gold arrow at the screen edge while that Legendary is off screen (R-10).
--   * WRECKED! when the bolts run out, with the line that names the fix (R-06, H-05).
-- It reads the run's public parts only (getDebugState, StaminaChanged, Bonk, requestHop, finish, setPaused) and the run zone.
--
--   local extras = RunExtras.attach(run, { world = "Downtown", floatHelp = true })
--   extras:claimed(carId, carName, rarity, isNew)    extras:destroy()

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Prototype = script.Parent.Parent:WaitForChild("Prototype")
local Motion = require(Prototype:WaitForChild("Motion"))
local Sounds = require(Prototype:WaitForChild("Sounds")) :: any
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Format = require(ReplicatedStorage.Shared.UI.Format)
local Trove = require(ReplicatedStorage.Packages.Trove)

local RunExtras = {}

local FONT = Font.new("rbxasset://fonts/families/FredokaOne.json")
local CREAM = Color3.fromRGB(255, 248, 232)
local NAVY = Color3.fromRGB(24, 36, 72)
local ORANGE = Color3.fromRGB(255, 140, 30)
local RED = Color3.fromRGB(226, 52, 52)
local GREEN = Color3.fromRGB(70, 200, 90)
local GOLD = Color3.fromRGB(255, 205, 50)
local RARITY: { [string]: Color3 } = {
	Common = Color3.fromRGB(255, 255, 255),
	Uncommon = Color3.fromRGB(110, 230, 120),
	Rare = Color3.fromRGB(80, 170, 255),
	Epic = Color3.fromRGB(196, 110, 255),
	Legendary = GOLD,
}

-- District names per World (Claude Code's call, Round 7 ledger), by metres from the start; the last one holds for the rest of the run.
RunExtras.DISTRICTS = table.freeze({
	Downtown = { { 0, "Main Street" }, { 600, "Harbor" }, { 1500, "Neon Row" }, { 3000, "Uptown" } },
	DustyHighway = { { 0, "Gas Stop" }, { 600, "Canyon Run" }, { 1500, "Mesa Flats" }, { 3000, "Sunset Strip" } },
	SummitPass = { { 0, "Pine Base" }, { 600, "Snow Bridge" }, { 1500, "Ice Pass" }, { 3000, "Peak View" } },
} :: { [string]: { { any } } })
RunExtras.WORLD_NAMES = table.freeze(
	{ Downtown = "Downtown", DustyHighway = "Dusty Highway", SummitPass = "Summit Pass" } :: { [string]: string }
)

-- H-05: every way a run ends names one thing to do about it.
function RunExtras.lessonFor(cause: string?): (string, string)
	if cause == "Overheated" then
		return "OVERHEATED!", "Too hot! Hop to a new car sooner."
	elseif cause == "Wrecked by bumps" then
		return "WRECKED!", "Steer around traffic, and get more bolts at the Pit Stop."
	end
	return "WRECKED!", "Out of Stamina! Get more bolts at the Pit Stop."
end

function RunExtras.isWreck(cause: string?): boolean
	return cause == "Out of Stamina" or cause == "Wrecked by bumps" or cause == "Overheated"
end

local function make(className: string, props: { [string]: any }, parent: Instance?): any
	local inst = Instance.new(className)
	for k, v in props do
		(inst :: any)[k] = v
	end
	if parent then
		inst.Parent = parent
	end
	return inst
end

local function round(parent: Instance, radius: number?)
	make("UICorner", { CornerRadius = if radius then UDim.new(0, radius) else UDim.new(1, 0) }, parent)
end

local function label(parent: Instance, text: string, size: number, colour: Color3, props: { [string]: any }?): TextLabel
	local l = make("TextLabel", {
		BackgroundTransparency = 1,
		FontFace = FONT,
		Text = text,
		TextSize = size,
		TextColor3 = colour,
		TextStrokeColor3 = NAVY,
		TextStrokeTransparency = 0,
	}, parent)
	for k, v in props or {} do
		(l :: any)[k] = v
	end
	return l
end

export type Options = { world: string, floatHelp: boolean? }

function RunExtras.attach(run: any, options: Options): any
	local player = Players.LocalPlayer
	local trove = Trove.new()
	local reduced = Motion.reduced()
	local gui = trove:Add(make("ScreenGui", {
		Name = "CarHopRunExtras",
		ResetOnSpawn = false,
		IgnoreGuiInset = false,
		DisplayOrder = 12,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	}))

	-- HOP (R-01) ----------------------------------------------------------------------------------
	local hop = make("TextButton", {
		Name = "Hop",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -28, 1, -28),
		Size = UDim2.fromOffset(124, 124),
		BackgroundColor3 = ORANGE,
		AutoButtonColor = true,
		FontFace = FONT,
		Text = "HOP",
		TextSize = 36,
		TextColor3 = CREAM,
		TextStrokeColor3 = NAVY,
		TextStrokeTransparency = 0,
	}, gui)
	round(hop)
	make("UIStroke", { Color = NAVY, Thickness = 5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, hop)
	label(hop, "SPACE", 14, CREAM, {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -14),
		Size = UDim2.new(1, 0, 0, 16),
	})
	local again = label(gui, "PRESS AGAIN!", 30, GOLD, {
		Name = "PressAgain",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -8, 1, -160),
		Size = UDim2.fromOffset(240, 40),
		Visible = false,
	})
	trove:Connect(hop.Activated, function()
		run:requestHop()
	end)

	-- END RUN (R-07) ------------------------------------------------------------------------------
	local endBtn = make("TextButton", {
		Name = "EndRun",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -16, 0, 64),
		Size = UDim2.fromOffset(120, 48),
		BackgroundColor3 = NAVY,
		FontFace = FONT,
		Text = "END RUN",
		TextSize = 20,
		TextColor3 = CREAM,
	}, gui)
	round(endBtn, 14)
	make("UIStroke", { Color = RED, Thickness = 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, endBtn)
	local confirm = make("Frame", {
		Name = "ConfirmEnd",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(420, 210),
		BackgroundColor3 = CREAM,
		Visible = false,
		ZIndex = 20,
	}, gui)
	round(confirm, 22)
	make("UIStroke", { Color = NAVY, Thickness = 4 }, confirm)
	label(confirm, "End this run?", 32, NAVY, {
		Position = UDim2.fromOffset(0, 18),
		Size = UDim2.new(1, 0, 0, 40),
		TextStrokeTransparency = 1,
		ZIndex = 21,
	})
	label(confirm, "You keep the cars you caught.", 20, NAVY, {
		Position = UDim2.fromOffset(0, 62),
		Size = UDim2.new(1, 0, 0, 28),
		TextStrokeTransparency = 1,
		ZIndex = 21,
	})
	local function button(text: string, colour: Color3, x: number): TextButton
		local b = make("TextButton", {
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(x, 0, 1, -22),
			Size = UDim2.fromOffset(176, 60),
			BackgroundColor3 = colour,
			FontFace = FONT,
			Text = text,
			TextSize = 22,
			TextColor3 = CREAM,
			TextStrokeColor3 = NAVY,
			TextStrokeTransparency = 0.3,
			ZIndex = 21,
		}, confirm)
		round(b, 16)
		return b
	end
	local yes = button("END RUN", RED, 0.27)
	local no = button("KEEP DRIVING", GREEN, 0.73)
	local function setConfirm(open: boolean)
		confirm.Visible = open
		if run.setPaused then
			run:setPaused(open)
		end
	end
	trove:Connect(endBtn.Activated, function()
		if run:getDebugState().mode ~= "Ended" then
			setConfirm(true)
		end
	end)
	trove:Connect(no.Activated, function()
		setConfirm(false)
	end)
	trove:Connect(yes.Activated, function()
		setConfirm(false)
		run:finish("Ended by you")
	end)

	-- top centre: distance, district, luck ----------------------------------------------------------
	local top = make("Frame", {
		Name = "Top",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 8),
		Size = UDim2.fromOffset(180, 46),
		BackgroundColor3 = NAVY,
		BackgroundTransparency = 0.15,
		Visible = false, -- Lane 3's RunHud already shows the distance at the top centre (R-11)
	}, gui)
	round(top)
	local metres = label(top, "0 m", 30, CREAM, { Size = UDim2.fromScale(1, 1) })
	local district = label(gui, "", 26, GOLD, {
		Name = "District",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 92),
		Size = UDim2.fromOffset(420, 34),
		TextTransparency = 1,
		TextStrokeTransparency = 1,
	})
	local lucky = make("Frame", {
		Name = "Luck",
		Position = UDim2.fromOffset(16, 12),
		Size = UDim2.fromOffset(150, 44),
		BackgroundColor3 = Color3.fromRGB(30, 120, 60),
		Visible = (run.luck or 1) > 1,
	}, gui)
	round(lucky)
	make("UIStroke", { Color = GOLD, Thickness = 2 }, lucky)
	label(lucky, "🍀", 26, CREAM, { Size = UDim2.fromOffset(44, 44), TextStrokeTransparency = 1 })
	label(lucky, string.format("LUCK x%g", run.luck or 1), 22, CREAM, {
		Position = UDim2.fromOffset(42, 0),
		Size = UDim2.new(1, -46, 1, 0),
		TextXAlignment = Enum.TextXAlignment.Left,
	})

	-- SECURED and IT'S YOURS (R-11) -----------------------------------------------------------------
	local secured = make("Frame", {
		Name = "Secured",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 16, 0.76, 0),
		Size = UDim2.fromOffset(170, 60),
		BackgroundColor3 = NAVY,
		BackgroundTransparency = 0.15,
		Visible = false,
	}, gui)
	round(secured, 16)
	local securedText = label(secured, "0 SECURED", 22, CREAM, {
		Position = UDim2.fromOffset(0, 4),
		Size = UDim2.new(1, 0, 0, 26),
	})
	local chips = make("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(8, 32),
		Size = UDim2.new(1, -16, 0, 22),
	}, secured)
	make("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 4),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, chips)
	local count = 0
	local yours = make("Frame", {
		Name = "ItsYours",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, -420, 0.2, 0),
		Size = UDim2.fromOffset(330, 104),
		BackgroundColor3 = CREAM,
		Visible = false,
	}, gui)
	round(yours, 20)
	local yoursStroke = make("UIStroke", { Color = GOLD, Thickness = 4 }, yours)
	label(yours, "IT'S YOURS!", 38, ORANGE, {
		Position = UDim2.fromOffset(0, 6),
		Size = UDim2.new(1, 0, 0, 44),
	})
	local yoursName = label(yours, "", 24, NAVY, {
		Position = UDim2.fromOffset(0, 50),
		Size = UDim2.new(1, 0, 0, 28),
		TextStrokeTransparency = 1,
	})
	label(yours, "Keep going!", 20, GREEN, {
		Position = UDim2.fromOffset(0, 80),
		Size = UDim2.new(1, 0, 0, 24),
		TextStrokeTransparency = 1,
	})
	local yoursToken = 0

	-- the screen-edge arrow toward an off-screen Legendary (R-10)
	local arrow = label(gui, "▲", 54, GOLD, {
		Name = "LegendaryArrow",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(60, 60),
		Visible = false,
	})

	local self: any = {}

	-- a burst of stars and hearts from a screen point (UI only, stopped under Reduce Motion)
	local function burst(at: Vector2)
		if reduced then
			return
		end
		for i = 1, 10 do
			local glyph = label(gui, if i % 2 == 0 then "♥" else "★", 28, if i % 2 == 0 then RED else GOLD, {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromOffset(at.X, at.Y),
				Size = UDim2.fromOffset(32, 32),
				TextStrokeTransparency = 0.4,
			})
			local angle = (i / 10) * math.pi * 2
			local d = 90 + (i % 3) * 30
			Motion.tween(glyph, "burst", Motion.info(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Position = UDim2.fromOffset(at.X + math.cos(angle) * d, at.Y + math.sin(angle) * d),
				TextTransparency = 1,
				TextStrokeTransparency = 1,
			})
			task.delay(0.75, function()
				glyph:Destroy()
			end)
		end
	end

	-- After the server granted a claim (never on the dive): IT'S YOURS! and one more SECURED chip.
	function self.claimed(_self: any, carName: string, rarity: string, isNew: boolean)
		count += 1
		secured.Visible = true
		securedText.Text = string.format("%d SECURED", count)
		local chip = make("Frame", {
			Size = UDim2.fromOffset(20, 20),
			BackgroundColor3 = RARITY[rarity] or CREAM,
			LayoutOrder = count,
		}, chips)
		round(chip, 6)
		make("UIStroke", { Color = CREAM, Thickness = 1.5 }, chip)
		if #chips:GetChildren() > 8 then -- seven chips at most, the newest kept
			for _, c in chips:GetChildren() do
				if c:IsA("Frame") then
					c:Destroy()
					break
				end
			end
		end
		yoursName.Text = string.upper(carName) .. (if isNew then "" else "  (another copy)")
		yoursStroke.Color = RARITY[rarity] or GOLD
		yours.Visible = true
		yoursToken += 1
		local token = yoursToken
		if reduced then
			yours.Position = UDim2.new(0, 16, 0.2, 0)
		else
			yours.Position = UDim2.new(0, -420, 0.2, 0)
			Motion.tween(yours, "slide", Motion.info(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
				Position = UDim2.new(0, 16, 0.2, 0),
			})
		end
		local cam = Workspace.CurrentCamera
		burst(if cam then Vector2.new(cam.ViewportSize.X * 0.5, cam.ViewportSize.Y * 0.45) else Vector2.new(400, 300))
		pcall(Sounds.play, "KeysCapture")
		task.delay(2.4, function()
			if token == yoursToken then
				yours.Visible = false
			end
		end)
	end

	-- BONK! (R-04): a pop over the spot, in the world
	local zone = Workspace:FindFirstChild("Lane1_RunZone")
	if run.Bonk then
		trove:Connect(run.Bonk, function(kind: string, at: CFrame)
			local anchor = make("Part", {
				Anchored = true,
				CanCollide = false,
				CanQuery = false,
				CanTouch = false,
				Transparency = 1,
				Size = Vector3.one,
				CFrame = at,
			}, zone or Workspace)
			local pop = make("BillboardGui", {
				Size = UDim2.fromOffset(200, 80),
				AlwaysOnTop = true,
				LightInfluence = 0,
				Adornee = anchor,
			}, anchor)
			local text = label(pop, if kind == "Thrown" then "TOO HOT!" else "BONK!", 54, RED, {
				Size = UDim2.fromScale(1, 1),
				TextStrokeColor3 = Color3.new(1, 1, 1),
			})
			pcall(Sounds.play, "Bonk")
			if not reduced then
				text.TextSize = 20
				Motion.tween(
					text,
					"pop",
					Motion.info(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
					{ TextSize = 58 }
				)
			end
			task.delay(0.8, function()
				anchor:Destroy()
			end)
		end)
	end

	-- the rarer cars' entrance cues (R-10, H-06), at most one sound a second
	local lastCue = 0
	local legendaries: { Model } = {}
	local function watchCar(model: Instance)
		if not model:IsA("Model") then
			return
		end
		local rarity = model:GetAttribute("Rarity")
		local now = os.clock()
		if rarity == "Legendary" then
			table.insert(legendaries, model)
			if now - lastCue > 1 then
				lastCue = now
				pcall(Sounds.fanfare, "legendary-" .. model.Name)
			end
		elseif rarity == "Epic" and now - lastCue > 1 then
			lastCue = now
			pcall(Sounds.play, "Unlock", 0.5)
		end
		-- L-03: LUCKY! when a Rare or better joins the road while luck is on (luck is the reason it MAY be there, never claimed)
		if (run.luck or 1) > 1 and (rarity == "Rare" or rarity == "Epic" or rarity == "Legendary") then
			local tagged = model:FindFirstChild("Tag", true)
			if tagged and tagged:IsA("BillboardGui") then
				local l = label(tagged, "LUCKY!", 18, Color3.fromRGB(90, 230, 110), {
					Name = "Lucky",
					AnchorPoint = Vector2.new(0.5, 1),
					Position = UDim2.fromScale(0.5, 0),
					Size = UDim2.new(1, 0, 0, 22),
				})
				task.delay(2.5, function()
					l:Destroy()
				end)
			end
		end
	end
	local traffic = zone and zone:FindFirstChild("Traffic")
	if traffic then
		trove:Connect(traffic.ChildAdded, watchCar)
	end

	-- per frame: distance, district, PRESS AGAIN!, the Legendary arrow, WRECKED!
	local lastDistrict = ""
	local wreckShown = false
	local districts = RunExtras.DISTRICTS[options.world] or RunExtras.DISTRICTS.Downtown
	trove:Connect(RunService.RenderStepped, function()
		local s = run:getDebugState()
		metres.Text = Format.distance(s.metres)
		-- district banner
		local name = districts[1][2]
		for _, d in districts do
			if s.metres >= d[1] then
				name = d[2]
			end
		end
		if name ~= lastDistrict then
			lastDistrict = name
			district.Text = (RunExtras.WORLD_NAMES[options.world] or options.world) .. ": " .. name
			district.TextTransparency = 0
			district.TextStrokeTransparency = 0
			task.delay(2.5, function()
				if lastDistrict == name then
					Motion.tween(
						district,
						"fade",
						Motion.info(0.5),
						{ TextTransparency = 1, TextStrokeTransparency = 1 }
					)
				end
			end)
		end
		-- PRESS AGAIN! on first runs while floating
		local floating = s.mode == "Float"
		again.Visible = options.floatHelp == true and floating and (reduced or math.floor(os.clock() * 4) % 2 == 0)
		hop.Text = if floating then "DIVE" else "HOP"
		hop.BackgroundColor3 = if floating and s.target then GOLD else ORANGE
		-- the arrow toward an off-screen Legendary
		local cam = Workspace.CurrentCamera
		local shown = false
		for i = #legendaries, 1, -1 do
			local m = legendaries[i]
			if not m.Parent then
				table.remove(legendaries, i)
				continue
			end
			if cam and not shown and s.mode ~= "Ended" then
				local p, onScreen = cam:WorldToViewportPoint(m:GetPivot().Position)
				local size = cam.ViewportSize
				if not onScreen or p.X < 0 or p.X > size.X or p.Y < 0 or p.Y > size.Y then
					local centre = size / 2
					local dir = Vector2.new(p.X, p.Y) - centre
					if p.Z < 0 then
						dir = -dir
					end
					if dir.Magnitude > 1 then
						dir = dir.Unit
						local edge = centre + dir * (math.min(size.X, size.Y) / 2 - 50)
						arrow.Position = UDim2.fromOffset(edge.X, edge.Y)
						arrow.Rotation = math.deg(math.atan2(dir.Y, dir.X)) + 90
						shown = true
					end
				end
			end
		end
		arrow.Visible = shown
		-- WRECKED! (R-06)
		if s.mode == "Ended" and not wreckShown and RunExtras.isWreck(s.cause) then
			wreckShown = true
			endBtn.Visible = false
			hop.Visible = false
			local title, line = RunExtras.lessonFor(s.cause)
			local card = make("Frame", {
				Name = "Wrecked",
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.45),
				Size = UDim2.fromOffset(560, 190),
				BackgroundColor3 = NAVY,
				BackgroundTransparency = 0.05,
				ZIndex = 30,
			}, gui)
			round(card, 26)
			make("UIStroke", { Color = RED, Thickness = 5 }, card)
			local big = label(card, title, 72, RED, {
				Size = UDim2.new(1, 0, 0, 100),
				TextStrokeColor3 = Color3.new(1, 1, 1),
				ZIndex = 31,
			})
			label(card, line, 22, CREAM, {
				Position = UDim2.fromOffset(16, 104),
				Size = UDim2.new(1, -32, 0, 30),
				TextWrapped = true,
				ZIndex = 31,
			})
			label(card, "⚡⚡⚡", 30, GOLD, {
				Position = UDim2.fromOffset(0, 140),
				Size = UDim2.new(1, 0, 0, 36),
				ZIndex = 31,
			})
			pcall(Sounds.play, "Warning")
			if not reduced then
				big.TextSize = 24
				Motion.tween(
					big,
					"slam",
					Motion.info(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
					{ TextSize = 72 }
				)
			end
		end
	end)

	function self.destroy(_self: any)
		if run.setPaused then
			pcall(run.setPaused, run, false)
		end
		trove:Destroy()
	end

	gui.Parent = player:WaitForChild("PlayerGui")
	return self
end

-- How long the Launch Pad waits before Results: longer after a WRECKED! moment, so it is seen.
function RunExtras.resultsDelay(cause: string?): number
	return if RunExtras.isWreck(cause) then 2.2 else 0.8
end

return RunExtras
