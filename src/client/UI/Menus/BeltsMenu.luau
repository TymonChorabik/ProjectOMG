--[[
	BeltsMenu.luau
	Belts & martial ranks: buy the next belt (needs Power + Coins), equip any owned belt.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Formulas = require(Shared.Formulas)
local NumberFormat = require(Shared.NumberFormat)

local ClientData = require(script.Parent.Parent.Parent.ClientData)
local Create = require(script.Parent.Parent.Create)
local MenuWindow = require(script.Parent.Parent.MenuWindow)
local Theme = require(script.Parent.Parent.Theme)

local BeltsMenu = {}

local REFRESH_KEYS = { Power = true, Coins = true, OwnedBelts = true, EquippedBelt = true }

-- Little belt icon: band + knot + tails.
local function drawBelt(swatch: Frame, belt)
	swatch.BackgroundColor3 = Theme.Colors.Cream
	local band = Create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.4),
		Size = UDim2.fromScale(0.9, 0.2),
		BackgroundColor3 = belt.Color,
		ZIndex = 4,
		Parent = swatch,
	}, { Create.Stroke(2) })
	Create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.4),
		Size = UDim2.fromScale(0.24, 0.3),
		BackgroundColor3 = belt.Color,
		ZIndex = 5,
		Parent = swatch,
	}, { Create.Stroke(2), Create.Corner(UDim.new(0, 4)) })
	for _, side in { -1, 1 } do
		Create("Frame", {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.fromScale(0.5 + side * 0.08, 0.5),
			Size = UDim2.fromScale(0.1, 0.38),
			Rotation = side * 14,
			BackgroundColor3 = belt.Stripe or belt.Color,
			ZIndex = 4,
			Parent = swatch,
		}, { Create.Stroke(2) })
	end
	return band
end

function BeltsMenu.new(parent: Instance, request: (string, string?) -> ())
	local window = MenuWindow.new({ Title = "Belts", Icon = "🥋", Color = Theme.Colors.Yellow, Parent = parent })
	local cards = {}

	for index, belt in Config.Belts do
		local card = MenuWindow.Card(window.Content, index)
		drawBelt(card.Swatch, belt)
		card.Title.Text = belt.Name
		card.Subtitle.Text = `{NumberFormat.Multiplier(belt.Multiplier)} chop power`
		card.Button.Activated:Connect(function()
			local data = ClientData.Data
			if data and data.OwnedBelts[belt.Id] then
				request("EquipBelt", belt.Id)
			else
				request("BuyBelt", belt.Id)
			end
		end)
		cards[index] = card
	end

	local function refresh()
		local data = ClientData.Data
		if not data then
			return
		end
		local nextBelt = Formulas.GetNextBelt(data)

		for index, belt in Config.Belts do
			local card = cards[index]
			local owned = data.OwnedBelts[belt.Id] == true
			local equipped = data.EquippedBelt == belt.Id
			local requirement = if belt.Cost > 0
				then `Needs ⚡{NumberFormat.Abbreviate(belt.RequiredPower)} + 🪙{NumberFormat.Abbreviate(belt.Cost)}`
				else "Starting rank"
			card.Info.Text = requirement
			card.Info.TextColor3 = Theme.Colors.Yellow

			if equipped then
				card.Button:SetText("EQUIPPED")
				card.Button:SetColor(Theme.Colors.Gray)
				card.Button:SetEnabled(false)
			elseif owned then
				card.Button:SetText("EQUIP")
				card.Button:SetColor(Theme.Colors.Blue)
				card.Button:SetEnabled(true)
			elseif nextBelt and nextBelt.Id == belt.Id then
				local ready = data.Power >= belt.RequiredPower and data.Coins >= belt.Cost
				card.Button:SetText(if ready then `RANK UP 🪙{NumberFormat.Abbreviate(belt.Cost)}` else "NOT READY")
				card.Button:SetColor(if ready then Theme.Colors.Green else Theme.Colors.GrayDark)
				card.Button:SetEnabled(true)
				card.Info.TextColor3 = if ready then Theme.Colors.Green else Theme.Colors.Yellow
			else
				card.Button:SetText("🔒 LOCKED")
				card.Button:SetColor(Theme.Colors.GrayDark)
				card.Button:SetEnabled(false)
			end
		end
	end

	ClientData.Changed:Connect(function(key)
		if REFRESH_KEYS[key] and window.IsOpen then
			refresh()
		end
	end)
	window.Instance:GetPropertyChangedSignal("Visible"):Connect(refresh)
	refresh()

	return window
end

return BeltsMenu
