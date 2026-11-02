--!strict
-- RunResults: the card at the end of a run (Lane 3, Round 3 N8; reference R3-IMG-04). Fed by plain data, so it knows nothing about how a
-- run works. Two moods: "RUN OVER!" with what you caught, and "SO CLOSE!" for a run with no cars, which is never a sad empty screen:
-- a friendly silhouette, a tip with its icon, and your best distance.
--
--   local r = RunResults.new(ctx, { onRetry = fn, onHome = fn, onRevive = fn?, onEarnFaster = fn? })
--   r:show({ metres, best, isBest, cars = { { name, rarity, isNew } }, cash, revives })  r:hide()  r:isOpen()  r:destroy()
--   r:pressRetry()  r:pressHome()
--
-- Order: the card pops in; the distance counts up (0.7 s); the cars pop in one at a time; the Cash counts up; a new best stamps on with
-- confetti. Any press skips to the end. Reduce Motion shows it all at once. `cash` is a PREVIEW figure until Lane 2's run report exists.

local Prototype = script.Parent.Parent
local CarKit = require(Prototype.CarKit)
local Motion = require(Prototype.Motion)
local Overlay = require(script.Parent.Overlay)
local Sounds = require(Prototype.Sounds)
local Format = game:GetService("ReplicatedStorage").Shared.UI.Format

local Formatter = require(Format) :: any

local make = CarKit.make

local RunResults = {}

export type Car = { name: string, rarity: string?, isNew: boolean? }
export type Data = {
	metres: number,
	best: number,
	isBest: boolean,
	cars: { Car },
	cash: number,
	revives: number,
}

export type Options = {
	onRetry: () -> (),
	onHome: () -> (),
	onRevive: (() -> ())?,
	onEarnFaster: (() -> ())?,
}

-- Short, true and friendly. One is picked per run.
RunResults.Tips = {
	{ icon = "hop", text = "Hop sooner when the ring turns green!" },
	{ icon = "keys", text = "Hold on to a car to keep it!" },
	{ icon = "steer", text = "Steer into a gap, then hop!" },
	{ icon = "stamina", text = "Hop before your car overheats!" },
	{ icon = "goals", text = "Every run gets you further!" },
}

local function metres(n: number): string
	return Formatter.group(math.floor(n)) .. " m"
end

function RunResults.new(ctx: Overlay.Ctx, options: Options): { [string]: any }
	local overlay = Overlay.new(ctx, { name = "RunResults", dimTransparency = 0.72, slide = false })
	local trove = overlay.trove
	local buildTrove = trove:Extend()
	local isOpen = false
	local token = 0
	local earnFasterShown = false
	local tipIndex = 0
	local self: { [string]: any } = {}

	local function countUp(label: TextLabel, target: number, seconds: number, format: (number) -> string, me: number)
		if Motion.reduced() then
			label.Text = format(target)
			return
		end
		local t0 = os.clock()
		while os.clock() - t0 < seconds and me == token do
			local u = (os.clock() - t0) / seconds
			label.Text = format(target * (1 - (1 - u) ^ 3))
			task.wait()
		end
		if me == token then
			label.Text = format(target)
		end
	end

	local function confetti(parent: Frame, z: number)
		if Motion.reduced() then
			return
		end
		local colours = { CarKit.Yellow, CarKit.Red, CarKit.Green, Color3.fromRGB(70, 170, 255), CarKit.White }
		for i = 1, 26 do
			local p = make("Frame", {
				Name = "Confetti",
				BorderSizePixel = 0,
				BackgroundColor3 = colours[i % #colours + 1],
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.26),
				Size = UDim2.fromOffset(9, 6),
				Rotation = math.random(0, 360),
				ZIndex = z,
			}, parent)
			local a = math.random() * math.pi * 2
			local d = 0.3 + math.random() * 0.34
			Motion.tween(p, "Fly", Motion.info(0.85, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Position = UDim2.fromScale(0.5 + math.cos(a) * d, 0.26 + math.sin(a) * d * 0.9 + 0.1),
				Rotation = p.Rotation + 200,
				BackgroundTransparency = 1,
			})
			task.delay(0.95, function()
				p:Destroy()
			end)
		end
	end

	local function carCard(parent: Instance, car: Car, at: UDim2, size: Vector2, z: number): Frame
		local rarity = (CarKit.Rarity :: any)[car.rarity or "Common"] or CarKit.Rarity.Common
		local holder = make("Frame", {
			Name = "Car",
			BackgroundColor3 = rarity,
			Position = at,
			Size = UDim2.fromOffset(size.X, size.Y),
			ZIndex = z,
		}, parent) :: Frame
		make("UICorner", { CornerRadius = UDim.new(0, 10) }, holder)
		make("UIStroke", { Thickness = 2.5, Color = CarKit.Ink, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, holder)
		make(
			"UIGradient",
			{ Rotation = 90, Color = ColorSequence.new(CarKit.White, Color3.fromRGB(150, 160, 190)) },
			holder
		)
		CarKit.art(holder, "thumb_car_body", {
			size = UDim2.new(1, -6, 1, -24),
			position = UDim2.new(0.5, 0, 0.5, -8),
			color = rarity:Lerp(CarKit.White, 0.1),
			z = z + 1,
			placeholder = false,
		})
		CarKit.art(holder, "thumb_car_top", {
			size = UDim2.new(1, -6, 1, -24),
			position = UDim2.new(0.5, 0, 0.5, -8),
			z = z + 3,
			placeholder = false,
		})
		CarKit.title(holder, car.name, math.clamp(math.round(size.X / 9), 13, 20), {
			align = Enum.TextXAlignment.Center,
			size = UDim2.new(1, -6, 0, 22),
			position = UDim2.new(0, 3, 1, -23),
			z = z + 4,
			shadow = false,
			stroke = 1.5,
		})
		if car.isNew then
			local stamp = make("Frame", {
				Name = "New",
				BackgroundColor3 = CarKit.Red,
				Position = UDim2.fromOffset(-5, -6),
				Size = UDim2.fromOffset(58, 24),
				Rotation = -8,
				ZIndex = z + 5,
			}, holder)
			make("UICorner", { CornerRadius = UDim.new(0, 5) }, stamp)
			make(
				"UIStroke",
				{ Thickness = 2, Color = CarKit.Ink, ApplyStrokeMode = Enum.ApplyStrokeMode.Border },
				stamp
			)
			CarKit.title(stamp, "NEW!", 18, {
				align = Enum.TextXAlignment.Center,
				z = z + 6,
				shadow = false,
				stroke = 1.5,
				color = CarKit.Yellow,
			})
		end
		return holder
	end

	local function build(data: Data)
		buildTrove:Clean()
		token += 1
		local me = token
		CarKit.setStrokeScale(ctx.screen:uiScale())
		local D = overlay:designSize()
		local h = math.min(D.Y - 12, 640)
		local w = math.min(D.X - 24, math.max(h * 0.86, 460))
		local k = h / 640
		local caught = #data.cars
		local good = caught > 0
		local card = buildTrove:Add(CarKit.board(overlay.content, {
			size = UDim2.fromOffset(w, h),
			position = UDim2.fromScale(0.5, 0.5),
			anchor = Vector2.new(0.5, 0.5),
			z = 3,
			radius = math.round(20 * k),
			top = if good then Color3.fromRGB(20, 120, 74) else Color3.fromRGB(30, 62, 130),
			bottom = Color3.fromRGB(12, 20, 44),
			bolts = true,
			name = "Results",
		})) :: Frame
		local rays = CarKit.pattern(card, "rays", {
			color = if good then Color3.fromRGB(180, 255, 170) else Color3.fromRGB(170, 210, 255),
			transparency = 0.88,
			size = UDim2.new(1, 0, 0.5, 0),
			z = 3,
		})
		if rays then
			make("UICorner", { CornerRadius = UDim.new(0, math.round(20 * k)) }, rays)
		end

		-- the ribbon
		local ribbonH = math.round(84 * k)
		local ribbon = make("Frame", {
			Name = "Ribbon",
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, -math.round(10 * k)),
			Size = UDim2.new(0.86, 0, 0, ribbonH),
			BackgroundColor3 = if good then CarKit.Red else Color3.fromRGB(26, 104, 232),
			ZIndex = 6,
		}, card) :: Frame
		make("UICorner", { CornerRadius = UDim.new(0, 14) }, ribbon)
		make("UIStroke", { Thickness = 3.5, Color = CarKit.Ink, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, ribbon)
		CarKit.title(ribbon, if good then "RUN OVER!" else "SO CLOSE!", math.round(66 * k), {
			align = Enum.TextXAlignment.Center,
			top = if good then CarKit.Yellow else CarKit.White,
			bottom = if good then CarKit.Orange else Color3.fromRGB(190, 220, 255),
			z = 7,
		})
		for _, side in { -1, 1 } do
			CarKit.art(ribbon, "fx_flag", {
				size = UDim2.fromOffset(ribbonH * 1.2, ribbonH * 0.6),
				position = UDim2.new(if side < 0 then 0 else 1, side * -ribbonH * 0.2, 0.5, 0),
				rotation = side * 8,
				z = 6,
				placeholder = false,
			})
		end

		-- the distance
		local y = ribbonH - math.round(6 * k)
		CarKit.text(card, "DISTANCE", math.max(math.round(20 * k), 14), {
			align = Enum.TextXAlignment.Center,
			size = UDim2.new(1, 0, 0, 24),
			position = UDim2.fromOffset(0, y),
			color = CarKit.Soft,
			z = 6,
		})
		y += math.round(20 * k)
		local bigPx = math.round(92 * k)
		local distance = CarKit.title(card, "0 m", bigPx, {
			align = Enum.TextXAlignment.Center,
			size = UDim2.new(1, 0, 0, bigPx * 1.04),
			position = UDim2.fromOffset(0, y),
			top = if good then CarKit.Yellow else CarKit.White,
			bottom = if good then CarKit.Orange else Color3.fromRGB(190, 220, 255),
			z = 6,
			name = "Distance",
		})
		y += bigPx * 1.02
		local bestPx = math.max(math.round(28 * k), 18)
		local bestBar = CarKit.title(card, "", bestPx, {
			align = Enum.TextXAlignment.Center,
			size = UDim2.new(1, 0, 0, bestPx * 1.1),
			position = UDim2.fromOffset(0, y),
			color = CarKit.Yellow,
			stroke = 2.5,
			z = 6,
			name = "Best",
		})
		if not data.isBest then
			bestBar.Text = "Best: " .. metres(data.best)
		end
		y += bestPx * 1.2

		-- the cars, or the friendly empty slot
		local bandH = math.round(150 * k)
		local band = CarKit.board(card, {
			size = UDim2.new(1, -math.round(28 * k), 0, bandH),
			position = UDim2.fromOffset(math.round(14 * k), y),
			z = 5,
			radius = 12,
			top = CarKit.Well,
			bottom = CarKit.Well,
			name = "Cars",
		})
		CarKit.text(band, ("CARS CAUGHT (%d)"):format(caught), math.max(math.round(16 * k), 13), {
			position = UDim2.fromOffset(10, 3),
			size = UDim2.new(1, -20, 0, 20),
			color = CarKit.Soft,
			z = 7,
		})
		local cards: { Frame } = {}
		if good then
			local shown = math.min(caught, 3)
			local gap = 8
			local cw = math.floor((w - 28 * k - 20 - gap * (shown - 1)) / shown)
			local ch = bandH - 30
			cw = math.min(cw, math.round(ch * 1.7))
			local x0 = ((w - 28 * k) - (cw * shown + gap * (shown - 1))) / 2
			for i = 1, shown do
				local c =
					carCard(band, data.cars[i], UDim2.fromOffset(x0 + (i - 1) * (cw + gap), 24), Vector2.new(cw, ch), 7)
				c.Visible = Motion.reduced()
				table.insert(cards, c)
			end
		else
			local slot = make("Frame", {
				Name = "EmptySlot",
				BackgroundTransparency = 1,
				Position = UDim2.fromOffset(10, 24),
				Size = UDim2.new(1, -20, 1, -32),
				ZIndex = 6,
			}, band) :: Frame
			make("UICorner", { CornerRadius = UDim.new(0, 10) }, slot)
			make("UIStroke", {
				Thickness = 2,
				Color = CarKit.ChromeBottom,
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			}, slot)
			CarKit.art(slot, "thumb_car_body", {
				color = Color3.fromRGB(46, 58, 92),
				size = UDim2.fromScale(0.74, 1.05),
				z = 7,
				placeholder = false,
			})
			CarKit.title(
				slot,
				"?",
				math.round(70 * k),
				{ align = Enum.TextXAlignment.Center, z = 8, color = CarKit.Soft }
			)
		end
		y += bandH + math.round(8 * k)

		-- a tip, on a run with no cars
		if not good then
			tipIndex = tipIndex % #RunResults.Tips + 1
			local tip = RunResults.Tips[tipIndex]
			local tipH = math.round(52 * k)
			local bar = CarKit.board(card, {
				size = UDim2.new(1, -math.round(28 * k), 0, tipH),
				position = UDim2.fromOffset(math.round(14 * k), y),
				z = 5,
				radius = 12,
				top = CarKit.Well,
				bottom = CarKit.Well,
				name = "Tip",
			})
			local iconPx = math.max(tipH - 8, 32)
			CarKit.slot(bar, tip.icon, iconPx, { position = UDim2.new(0, iconPx / 2 + 8, 0.5, 0), z = 7 })
			CarKit.text(bar, tip.text, math.max(math.round(21 * k), 14), {
				position = UDim2.fromOffset(iconPx + 16, 0),
				size = UDim2.new(1, -iconPx - 24, 1, 0),
				z = 7,
				name = "TipText",
			})
			y += tipH + math.round(6 * k)
		end

		-- Cash
		local rowH = math.round(66 * k)
		local row = make("Frame", {
			Name = "CashRow",
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(0, y),
			Size = UDim2.new(1, 0, 0, rowH),
			ZIndex = 5,
		}, card) :: Frame
		CarKit.art(row, "art_cash2", {
			size = UDim2.fromOffset(rowH * 1.1, rowH * 1.1),
			position = UDim2.new(0.3, 0, 0.5, 0),
			z = 6,
			placeholder = false,
		})
		local cashPx = math.round(54 * k)
		local cashLabel = CarKit.title(row, "+$0", cashPx, {
			position = UDim2.new(0.38, 0, 0, 0),
			size = UDim2.new(0.6, 0, 1, 0),
			color = CarKit.CashText,
			z = 7,
			name = "Cash",
		})

		-- the buttons
		local bh = math.round(math.max(84 * k, 54))
		local gap = math.round(12 * k)
		local bw = (w - 32 * k - gap) / 2
		CarKit.button(card, {
			text = "RETRY",
			tone = "Orange",
			icon = "retry",
			px = math.max(math.round(50 * k), 30),
			size = UDim2.fromOffset(bw, bh),
			position = UDim2.new(0, 16 * k, 1, -math.round(14 * k)),
			anchor = Vector2.new(0, 1),
			z = 7,
			name = "Retry",
			onPress = function()
				self:pressRetry()
			end,
		})
		CarKit.button(card, {
			text = "HOME",
			tone = "Blue",
			icon = "home",
			px = math.max(math.round(50 * k), 30),
			size = UDim2.fromOffset(bw, bh),
			position = UDim2.new(1, -16 * k, 1, -math.round(14 * k)),
			anchor = Vector2.new(1, 1),
			z = 7,
			name = "Home",
			onPress = function()
				self:pressHome()
			end,
		})
		if data.revives > 0 and options.onRevive then
			CarKit.button(card, {
				text = ("REVIVE (%d)"):format(data.revives),
				tone = "Navy",
				px = 20,
				size = UDim2.fromOffset(150, 46),
				position = UDim2.new(1, -8, 0, -2),
				anchor = Vector2.new(1, 1),
				z = 8,
				name = "Revive",
				onPress = options.onRevive,
			})
		end
		if good and not earnFasterShown and options.onEarnFaster then
			earnFasterShown = true
			local link = make("TextButton", {
				Name = "EarnFaster",
				Text = "",
				AutoButtonColor = false,
				BackgroundTransparency = 1,
				Position = UDim2.new(0.62, 0, 0, 0),
				Size = UDim2.new(0.36, 0, 1, 0),
				ZIndex = 8,
			}, row)
			CarKit.text(link, "Earn faster: Double Lap Pay", 14, {
				align = Enum.TextXAlignment.Right,
				alignY = Enum.TextYAlignment.Bottom,
				wrap = true,
				color = CarKit.Soft,
				z = 8,
			})
			link.Activated:Connect(options.onEarnFaster)
		end

		overlay:focus(nil)
		Motion.pop(card, 0.9)

		-- the sequence
		buildTrove:Add(task.spawn(function()
			countUp(distance, data.metres, 0.7, metres, me)
			if me ~= token then
				return
			end
			for _, c in cards do
				c.Visible = true
				Motion.pop(c, 0.7)
				pcall(function()
					Sounds.play("Press")
				end)
				task.wait(if Motion.reduced() then 0 else 0.16)
			end
			countUp(cashLabel, data.cash, 0.5, function(n: number): string
				return "+$" .. Formatter.group(math.floor(n))
			end, me)
			if me ~= token then
				return
			end
			if data.isBest then
				bestBar.Text = "NEW BEST!"
				Motion.pop(bestBar, 1.4)
				confetti(card, 30)
			elseif good then
				confetti(card, 30)
			end
		end))
	end

	function self.show(_self: any, data: Data)
		isOpen = true
		overlay:setBack(function()
			self:pressHome()
		end)
		overlay:applyScale()
		if not overlay:isOpen() then
			overlay:open(nil, nil)
		end
		build(data)
	end

	function self.hide(_self: any)
		if not isOpen then
			return
		end
		isOpen = false
		token += 1
		buildTrove:Clean()
		overlay:close()
	end

	function self.pressRetry(_self: any)
		if isOpen then
			self:hide()
			options.onRetry()
		end
	end

	function self.pressHome(_self: any)
		if isOpen then
			self:hide()
			options.onHome()
		end
	end

	function self.isOpen(_self: any): boolean
		return isOpen
	end

	function self.destroy(_self: any)
		trove:Destroy()
	end

	return self
end

return RunResults
