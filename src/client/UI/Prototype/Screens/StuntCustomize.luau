--!strict
-- StuntCustomize: the Stunt Circuit's "Customize" screen (Lane 3, Round 3 N4-01). It is the Shop's Style screen in its own overlay:
-- StyleStudio and StyleState are the one implementation, so the two can never disagree about what you own or wear.
--
--   local c = StuntCustomize.new(ctx, { onClose = fn?, onBuy = fn?, onViewShop = fn? })
--   c:open(returnTo?)  c:close()  c:isOpen()  c:layout()  c:setVisible(on)  c:destroy()
--   c:selectTab("Paint" | "Decals" | "Wheels" | "Trails")  c:select(itemId) -> boolean  c:pressAction()  c:getDebugState()

local Prototype = script.Parent.Parent
local CarKit = require(Prototype.CarKit)
local Overlay = require(script.Parent.Overlay)
local StyleStudio = require(script.Parent.StyleStudio)

local StuntCustomize = {}

export type Options = {
	onClose: (() -> ())?,
	onBuy: ((id: string, title: string, art: string?) -> ())?,
	onViewShop: (() -> ())?,
}

function StuntCustomize.new(ctx: Overlay.Ctx, options: Options?): { [string]: any }
	local opts: Options = options or {}
	local overlay = Overlay.new(ctx, { name = "StuntCustomize", dimTransparency = 0.5, slide = false })
	local trove = overlay.trove
	local buildTrove = trove:Extend()
	local studio: any = nil
	local isOpen = false
	local openView: { title: string?, tabs: { string }?, tab: string? }? = nil
	local self: { [string]: any } = {}

	local function build(view: { title: string?, tabs: { string }?, tab: string? }?)
		local v = view or {}
		buildTrove:Clean()
		CarKit.setStrokeScale(ctx.screen:uiScale())
		local D = overlay:designSize()
		local w, h = math.min(D.X - 16, 1400), math.min(D.Y - 16, 860)
		local shell = buildTrove:Add(CarKit.board(overlay.content, {
			size = UDim2.fromOffset(w, h),
			position = UDim2.fromScale(0.5, 0.5),
			anchor = Vector2.new(0.5, 0.5),
			z = 2,
			radius = 16,
			name = "Panel",
		})) :: Frame
		CarKit.title(shell, v.title or "CUSTOMIZE", 44, {
			position = UDim2.fromOffset(14, 2),
			size = UDim2.new(1, -80, 0, 50),
			top = CarKit.White,
			bottom = CarKit.Gold,
			z = 5,
		})
		local close = CarKit.make("ImageButton", {
			Name = "Close",
			BackgroundTransparency = 1,
			Image = "",
			Size = UDim2.fromOffset(46, 46),
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -8, 0, 4),
			ZIndex = 6,
		}, shell) :: ImageButton
		CarKit.slot(close, "close", 46, { position = UDim2.fromScale(0.5, 0.5), z = 6, fallback = "Close" })
		close.Activated:Connect(function()
			self:close()
		end)
		local stage = CarKit.make("Frame", {
			Name = "Stage",
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(10, 54),
			Size = UDim2.new(1, -20, 1, -62),
			ZIndex = 3,
		}, shell) :: Frame
		studio = StyleStudio.new(ctx, stage, {
			tab = v.tab or "Paint",
			tabs = v.tabs,
			size = Vector2.new(w - 20, h - 62),
			trove = buildTrove,
			onBuy = opts.onBuy,
			onGetCash = opts.onViewShop,
		})
	end

	function self.open(_self: any, returnTo: GuiObject?, view: { title: string?, tabs: { string }?, tab: string? }?)
		if isOpen then
			return
		end
		isOpen = true
		overlay:setBack(function()
			self:close()
		end)
		overlay:applyScale()
		overlay:open(nil, returnTo)
		openView = view
		build(view)
	end

	function self.close(_self: any)
		if not isOpen then
			return
		end
		isOpen = false
		buildTrove:Clean()
		studio = nil
		overlay:close()
		if opts.onClose then
			opts.onClose()
		end
	end

	function self.isOpen(_self: any): boolean
		return isOpen
	end

	function self.layout(_self: any)
		if isOpen then
			overlay:applyScale()
			build(openView)
		end
	end

	function self.setVisible(_self: any, on: boolean)
		overlay.root.Visible = on and isOpen
	end

	function self.selectTab(_self: any, name: string)
		if studio then
			studio:setTab(name)
		end
	end

	function self.select(_self: any, id: string): boolean
		return studio ~= nil and studio:select(id)
	end

	function self.pressAction(_self: any)
		if studio then
			studio:pressAction()
		end
	end

	function self.getDebugState(_self: any): { [string]: any }
		return { open = isOpen, studio = if studio then studio:getDebugState() else nil }
	end

	function self.destroy(_self: any)
		trove:Destroy()
	end

	self.root = overlay.root
	return self
end

return StuntCustomize
