--[[
	WorldController.luau
	Makes the hub interactive and keeps its signs in sync with your data:
	• hand item pedestals – "Equip" prompt; sign shows LOCKED / UNLOCKED / EQUIPPED
	• eggs – walk up to one and the EggPanel (pet chances, Hatch 1 / 3 / 8) appears beside it
	• "Best in game" showcase – buy prompt
	• training floors – sign shows UNLOCKED / LOCKED (the pill above it shows the requirement)
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Formulas = require(Shared.Formulas)

local ClientData = require(script.Parent.Parent.ClientData)

local WorldController = {}

local GREEN = Color3.fromRGB(120, 255, 120)
local RED = Color3.fromRGB(255, 90, 90)
local YELLOW = Color3.fromRGB(255, 220, 70)

type Ctx = { Request: (string, string?) -> (), Purchase: (string) -> (), EggPanel: any }

local EGG_RANGE = 15 -- studs from the egg where its panel shows up

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
		local unlocked = Formulas.IsZoneUnlocked(data, zoneId)
		label.Text = if unlocked then "UNLOCKED" else "LOCKED"
		label.TextColor3 = if unlocked then GREEN else RED
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

		-- Eggs: show the egg panel beside the nearest egg in range.
		local eggSpots: { { Id: string, Part: BasePart } } = {}
		for _, model in map:WaitForChild("Eggs"):GetChildren() do
			local egg = Formulas.GetEgg(model:GetAttribute("EggId"))
			local part = model:FindFirstChild("Egg")
			if egg and part and part:IsA("BasePart") then
				table.insert(eggSpots, { Id = egg.Id, Part = part })
			end
		end
		RunService.RenderStepped:Connect(function()
			local character = Players.LocalPlayer.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			local camera = workspace.CurrentCamera
			local nearest, nearestDistance = nil, EGG_RANGE
			if root and root:IsA("BasePart") then
				for _, spot in eggSpots do
					local offset = spot.Part.Position - root.Position
					local distance = Vector2.new(offset.X, offset.Z).Magnitude
					if distance < nearestDistance then
						nearest, nearestDistance = spot, distance
					end
				end
			end
			if nearest and camera then
				local edge = nearest.Part.Position + camera.CFrame.RightVector * (nearest.Part.Size.X / 2 + 0.5)
				local point, onScreen = camera:WorldToScreenPoint(edge)
				if onScreen then
					ctx.EggPanel:SetScreenPosition(point.X, point.Y, camera.ViewportSize)
					ctx.EggPanel:SetEgg(nearest.Id)
					return
				end
			end
			ctx.EggPanel:SetEgg(nil)
		end)

		-- Best-in-game showcase.
		local showcase = map:WaitForChild("Showcase")
		local base = showcase:WaitForChild("Base")
		local lionPass = Config.Monetization.GamePasses.LionKing
		prompt(base, `Buy (R$ {lionPass.Price})`, lionPass.Name, function()
			ctx.Purchase("pass:LionKing")
		end)

		-- Training floor signs.
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
