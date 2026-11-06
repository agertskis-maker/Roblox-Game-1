--!strict
-- BETA-ONLY STAND-IN for Brian L's pass ownership checks (the Robux table, economy-v1-answers-from-adam.md).
-- Same contract: the server alone decides who owns a pass and publishes it read-only. Delete when his real module lands.
--
-- Round 6 (R-01, R-04). A player owns a pass when Roblox says they own its Game Pass (MarketplaceService
-- UserOwnsGamePassAsync at join, and PromptGamePassPurchaseFinished on the server after a purchase, then checked again) OR
-- the save's beta-only `Owned` list has its id (the All Passes Bundle writes it there). Ownership is published as the Player
-- attribute BetaOwned ("vip,double-lap-pay"), read only; the client never tells the server what it owns.
-- In Studio a test purchase of a pass is never recorded by Roblox, so UserOwnsGamePassAsync stays false: the server's
-- PromptGamePassPurchaseFinished(purchased = true) is kept for that session, which is what makes Studio tests end to end.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BetaConfig = require(ReplicatedStorage.Shared.Beta.BetaConfig)
local BetaData = require(script.Parent.BetaData)
local BetaProducts = require(ReplicatedStorage.Shared.Beta.BetaProducts)
local Signal = require(ReplicatedStorage.Packages.Signal)

local BetaOwnership = {}

BetaOwnership.Changed = Signal.new() -- (player) after any ownership change
BetaOwnership.Attribute = BetaConfig.OwnedAttribute

local passes: { [Player]: { [string]: boolean } } = {}
local resolved: { [Player]: boolean } = {}

-- Does this player own `id` (a pass id, a bundle-granted pass, or a cosmetic the Starter Pack or VIP gave)?
function BetaOwnership.owns(player: Player, id: string): boolean
	local own = passes[player]
	if own and own[id] then
		return true
	end
	local data = BetaData.get(player) :: any
	return data ~= nil and type(data.Owned) == "table" and data.Owned[id] == true
end

-- Waits (at most `timeout` seconds) until the join-time Game Pass checks have finished. Returns whether they did.
function BetaOwnership.waitResolved(player: Player, timeout: number): boolean
	local t0 = os.clock()
	while not resolved[player] and player.Parent == Players and os.clock() - t0 < timeout do
		task.wait(0.1)
	end
	return resolved[player] == true
end

function BetaOwnership.publish(player: Player)
	local list = {}
	for _, item in BetaProducts.Items do
		if (item.kind == "GamePass" or item.oncePerPlayer) and BetaOwnership.owns(player, item.id) then
			table.insert(list, item.id)
		end
	end
	local data = BetaData.get(player) :: any
	if data and type(data.Owned) == "table" then
		for id, on in data.Owned do
			if on == true and BetaProducts.get(id) == nil then
				table.insert(list, id) -- cosmetics from the Starter Pack
			end
		end
	end
	table.sort(list)
	player:SetAttribute(BetaOwnership.Attribute, table.concat(list, ","))
	BetaOwnership.Changed:Fire(player)
end

-- Session-only ownership of a pass (a confirmed purchase this session).
function BetaOwnership.setPass(player: Player, id: string, on: boolean)
	passes[player] = passes[player] or {}
	passes[player][id] = if on then true else nil
	BetaOwnership.publish(player)
end

local function ownsPassAsync(player: Player, passId: number): boolean?
	for attempt = 1, 2 do
		local ok, result = pcall(function()
			return MarketplaceService:UserOwnsGamePassAsync(player.UserId, passId)
		end)
		if ok then
			return result == true
		end
		warn(
			string.format(
				"[CarHopBeta] UserOwnsGamePassAsync failed (%s, try %d): %s",
				player.Name,
				attempt,
				tostring(result)
			)
		)
		task.wait(1)
	end
	return nil -- unknown: treated as not owned for now, checked again after the next purchase
end

local function resolve(player: Player)
	passes[player] = passes[player] or {}
	for _, item in BetaProducts.passes() do
		if BetaProducts.created(item) and player.Parent == Players then
			if ownsPassAsync(player, item.robloxId) == true then
				passes[player][item.id] = true
			end
		end
	end
	resolved[player] = true
	BetaOwnership.publish(player)
end

-- R-04: VIP's name tag, a small gold "VIP" label over the player's head that everyone sees (server-made, so a client
-- cannot add one to itself). Re-applied on respawn and whenever ownership changes.
local function vipTag(player: Player)
	local character = player.Character
	local head = character and character:FindFirstChild("Head")
	if not head then
		return
	end
	local old = head:FindFirstChild("CarHopVipTag")
	local wants = BetaOwnership.owns(player, "vip")
	if old and not wants then
		old:Destroy()
	elseif wants and not old then
		local tag = Instance.new("BillboardGui")
		tag.Name = "CarHopVipTag"
		tag.Size = UDim2.fromOffset(64, 26)
		tag.StudsOffset = Vector3.new(0, 2.6, 0)
		tag.AlwaysOnTop = false
		tag.MaxDistance = 80
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundColor3 = Color3.fromRGB(255, 196, 46)
		label.TextColor3 = Color3.fromRGB(70, 36, 0)
		label.Font = Enum.Font.FredokaOne
		label.TextScaled = true
		label.Text = "VIP"
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0.5, 0)
		corner.Parent = label
		local stroke = Instance.new("UIStroke")
		stroke.Color = Color3.fromRGB(120, 70, 0)
		stroke.Thickness = 2
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		stroke.Parent = label
		label.Parent = tag
		tag.Parent = head
	end
end

function BetaOwnership.start()
	BetaData.Loaded:Connect(function(player: Player)
		resolve(player)
	end)
	BetaOwnership.Changed:Connect(vipTag)
	local function watch(player: Player)
		player.CharacterAdded:Connect(function(character: Model)
			character:WaitForChild("Head", 10)
			vipTag(player)
		end)
	end
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	Players.PlayerAdded:Connect(watch)
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(
		function(player: Player, passId: number, purchased: boolean)
			local item = BetaProducts.byPassId(passId)
			if not (item and purchased) then
				return
			end
			print(string.format("[CarHopBeta] %s bought the %s pass (%d)", player.Name, item.id, passId))
			BetaOwnership.setPass(player, item.id, true)
			-- checked again a little later (Roblox's own record can lag the prompt)
			task.delay(10, function()
				if player.Parent == Players and ownsPassAsync(player, passId) == false then
					print(
						string.format(
							"[CarHopBeta] %s's %s pass is not on Roblox's record yet (a Studio test purchase?)",
							player.Name,
							item.id
						)
					)
				end
			end)
		end
	)
	Players.PlayerRemoving:Connect(function(player: Player)
		passes[player] = nil
		resolved[player] = nil
	end)
end

return BetaOwnership
