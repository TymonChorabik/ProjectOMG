--[[
	WorldController.luau
	Makes the hub interactive and keeps its signs in sync with your data:
	• hand item pedestals – "Equip" prompt; sign shows LOCKED / UNLOCKED / EQUIPPED
	• eggs – "Hatch" prompt (Wins) or Robux purchase for the Rainbow Egg
	• "Best in game" showcase – buy prompt
	• training zones – sign shows UNLOCKED / rebirths needed / Robux price / OWNED
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Formulas = require(Shared.Formulas)
local NumberFormat = require(Shared.NumberFormat)

local ClientData = require(script.Parent.Parent.ClientData)

local WorldController = {}

local GREEN = Color3.fromRGB(120, 255, 120)
local RED = Color3.fromRGB(255, 90, 90)
local YELLOW = Color3.fromRGB(255, 220, 70)

type Ctx = { Request: (string, string?) -> (), Purchase: (string) -> () }

local itemSigns: { [string]: TextLabel } = {}
local zoneSigns: { [string]: TextLabel } = {}

local function signLabel(model: Instance, name: string): TextLabel?
	local sign = model:FindFirstChild("Sign")
	local info = sign and sign:FindFirstChild("Info")
	local label = info and info:FindFirstChild(name)
	return if label and label:IsA("TextLabel") then label else nil
end

local function prompt(parent: Instance, action: string, object: string, onTriggered: () -> ())
	local proximity = Instance.new("ProximityPrompt")
	proximity.ActionText = action
	proximity.ObjectText = object
	proximity.HoldDuration = 0
	proximity.MaxActivationDistance = 12
	proximity.RequiresLineOfSight = false
	proximity.Triggered:Connect(onTriggered)
	proximity.Parent = parent
	return proximity
end

local function refreshSigns()
	local data = ClientData.Data
	if not data then
		return
	end
	for itemId, label in itemSigns do
		if Formulas.IsItemUnlocked(data, itemId) then
			local equipped = data.EquippedItem == itemId
			label.Text = if equipped then "EQUIPPED" else "UNLOCKED"
			label.TextColor3 = if equipped then YELLOW else GREEN
		else
			label.Text = "LOCKED"
			label.TextColor3 = RED
		end
	end
	for zoneId, label in zoneSigns do
		local zone = Formulas.GetZone(zoneId)
		if zone then
			if Formulas.IsZoneUnlocked(data, zoneId) then
				label.Text = if zone.Pass then "OWNED" else "UNLOCKED"
				label.TextColor3 = GREEN
			elseif zone.Pass then
				label.Text = `R$ {Config.Monetization.GamePasses[zone.Pass].Price}`
				label.TextColor3 = GREEN
			else
				label.Text = `🔒 🌀 {zone.RequiredRebirths} Rebirths`
				label.TextColor3 = RED
			end
		end
	end
end

function WorldController.Start(ctx: Ctx)
	task.spawn(function()
		local map = workspace:WaitForChild("Map")

		-- Hand item pedestals.
		local items = map:WaitForChild("Items")
		for _, model in items:GetChildren() do
			local itemId = model:GetAttribute("ItemId")
			local item = Formulas.GetItem(itemId)
			local top = model:FindFirstChild("Top")
			if type(itemId) == "string" and item and top then
				prompt(
					top,
					if item.Pass then `Buy (R$ {Config.Monetization.GamePasses[item.Pass].Price})` else "Equip",
					item.Name,
					function()
						local data = ClientData.Data
						if item.Pass and data and not Formulas.HasPass(data, item.Pass) then
							ctx.Purchase("pass:" .. item.Pass)
						else
							ctx.Request("EquipItem", itemId)
						end
					end
				)
				local status = signLabel(model, "Status")
				if status then
					itemSigns[itemId] = status
				end
			end
		end

		-- Eggs.
		local eggs = map:WaitForChild("Eggs")
		for _, model in eggs:GetChildren() do
			local egg = Formulas.GetEgg(model:GetAttribute("EggId"))
			local pad = model:FindFirstChild("Pad")
			if egg and pad then
				local action = if egg.Cost
					then `Hatch ({NumberFormat.Abbreviate(egg.Cost)} Wins)`
					else `Hatch (R$ {Config.Monetization.Products[egg.Product].Price})`
				prompt(pad, action, egg.Name, function()
					if egg.Product then
						ctx.Purchase("product:" .. egg.Product)
					else
						ctx.Request("HatchEgg", egg.Id)
					end
				end)
			end
		end

		-- Best-in-game showcase.
		local showcase = map:WaitForChild("Showcase")
		local base = showcase:WaitForChild("Base")
		local lionPass = Config.Monetization.GamePasses.LionKing
		prompt(base, `Buy (R$ {lionPass.Price})`, lionPass.Name, function()
			ctx.Purchase("pass:LionKing")
		end)

		-- Training zone signs.
		local zones = map:WaitForChild("TrainingZones")
		for _, model in zones:GetChildren() do
			local zoneId = model:GetAttribute("ZoneId")
			local status = signLabel(model, "Status")
			if type(zoneId) == "string" and status then
				zoneSigns[zoneId] = status
			end
		end

		refreshSigns()
	end)

	ClientData.Changed:Connect(function(key)
		if key == "TotalWins" or key == "EquippedItem" or key == "Passes" or key == "Rebirths" then
			refreshSigns()
		end
	end)
end

return WorldController
