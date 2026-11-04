--!strict
-- Gives each joining player the lowest free island plot and frees it on leave (Lane 2, PREVIEW).
-- Sets the plot attributes Lane 3's Raceway already reads: Owner (UserId), OwnerDisplayName,
-- SpeedwayLevel and ParkingSpots, and the player attribute HomePlot. The plot-marker contract
-- with Lane 3 is still a draft (vault/decisions/draft-plot-marker-contract.md).

local Workspace = game:GetService("Workspace")

local Plots = {}

local owners: { [Model]: Player } = {}

function Plots.folder(): Folder?
	local root = Workspace:FindFirstChild("Lane3_IslandPreview")
	local island = root and root:FindFirstChild("Island")
	local plots = island and island:FindFirstChild("Plots")
	return if plots and plots:IsA("Folder") then plots else nil
end

local function ordered(): { Model }
	local folder = Plots.folder()
	local list: { Model } = {}
	if folder then
		for _, child in folder:GetChildren() do
			if child:IsA("Model") then
				table.insert(list, child)
			end
		end
	end
	table.sort(list, function(a, b)
		return a.Name < b.Name
	end)
	return list
end

function Plots.of(player: Player): Model?
	for plot, owner in owners do
		if owner == player then
			return plot
		end
	end
	return nil
end

function Plots.assign(player: Player): Model?
	local existing = Plots.of(player)
	if existing then
		return existing
	end
	for _, plot in ordered() do
		if owners[plot] == nil then
			owners[plot] = player
			plot:SetAttribute("Owner", player.UserId)
			plot:SetAttribute("OwnerDisplayName", player.DisplayName)
			-- the plot number, as the beta's client reads it ("Plot03" -> 3)
			player:SetAttribute("HomePlot", tonumber(string.match(plot.Name, "%d+")) or plot.Name)
			return plot
		end
	end
	warn("[EconomyPreview] no free plot for " .. player.Name)
	return nil
end

function Plots.publish(player: Player, racewayLevel: number, parkingSpots: number)
	local plot = Plots.of(player)
	if plot then
		plot:SetAttribute("SpeedwayLevel", racewayLevel)
		plot:SetAttribute("ParkingSpots", parkingSpots)
	end
end

function Plots.release(player: Player)
	local plot = Plots.of(player)
	if plot then
		owners[plot] = nil
		plot:SetAttribute("Owner", nil)
		plot:SetAttribute("OwnerDisplayName", nil)
		plot:SetAttribute("SpeedwayLevel", nil)
		plot:SetAttribute("ParkingSpots", nil)
	end
	player:SetAttribute("HomePlot", nil)
end

return Plots
