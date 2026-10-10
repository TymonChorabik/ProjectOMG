--[[
	AurasMenu.luau
	Hand auras & gloves: glowing particle hands that multiply power and add crit chance.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local NumberFormat = require(Shared.NumberFormat)

local ClientData = require(script.Parent.Parent.Parent.ClientData)
local Create = require(script.Parent.Parent.Create)
local MenuWindow = require(script.Parent.Parent.MenuWindow)
local Theme = require(script.Parent.Parent.Theme)

local AurasMenu = {}

local REFRESH_KEYS = { Coins = true, Rebirths = true, OwnedAuras = true, EquippedAura = true }

local function drawOrb(swatch: Frame, color: Color3, secondary: Color3)
	swatch.BackgroundColor3 = Theme.Colors.Ink
	Create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.72, 0.72),
		BackgroundColor3 = Color3.new(1, 1, 1),
		ZIndex = 4,
		Parent = swatch,
	}, {
		Create.Corner(UDim.new(0.5, 0)),
		Create.Stroke(3, color),
		Create("UIGradient", {
			Rotation = 45,
			Color = ColorSequence.new(color, secondary),
		}),
	})
	Create.Label({
		Text = "✋",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.5, 0.5),
		ZIndex = 5,
		Parent = swatch,
	})
end

function AurasMenu.new(parent: Instance, request: (string, string?) -> ())
	local window = MenuWindow.new({ Title = "Auras", Icon = "🔥", Color = Theme.Colors.Purple, Parent = parent })
	local cards = {}

	-- "No aura" card.
	local noneCard = MenuWindow.Card(window.Content, 0, 80)
	noneCard.Swatch.BackgroundColor3 = Theme.Colors.GrayDark
	noneCard.Title.Text = "Bare Hands"
	noneCard.Subtitle.Text = "Train the old-fashioned way."
	noneCard.Info.Text = ""
	noneCard.Button.Activated:Connect(function()
		request("EquipAura", "None")
	end)

	for index, aura in Config.Auras do
		local card = MenuWindow.Card(window.Content, index)
		drawOrb(card.Swatch, aura.Particle.Colors[1], aura.Particle.Colors[2])
		card.Title.Text = aura.Name
		card.Title.TextColor3 = aura.Color
		card.Subtitle.Text = aura.Description
		card.Info.Text =
			`{NumberFormat.Multiplier(aura.PowerMultiplier)} power  •  +{NumberFormat.Percent(aura.CritChance)} crit`
		card.Button.Activated:Connect(function()
			local data = ClientData.Data
			if data and data.OwnedAuras[aura.Id] then
				request("EquipAura", aura.Id)
			else
				request("BuyAura", aura.Id)
			end
		end)
		cards[index] = card
	end

	local function refresh()
		local data = ClientData.Data
		if not data then
			return
		end

		local bareEquipped = data.EquippedAura == "None"
		noneCard.Button:SetText(if bareEquipped then "EQUIPPED" else "UNEQUIP")
		noneCard.Button:SetColor(if bareEquipped then Theme.Colors.Gray else Theme.Colors.Blue)
		noneCard.Button:SetEnabled(not bareEquipped)

		for index, aura in Config.Auras do
			local button = cards[index].Button
			local owned = data.OwnedAuras[aura.Id] == true
			if data.EquippedAura == aura.Id then
				button:SetText("EQUIPPED")
				button:SetColor(Theme.Colors.Gray)
				button:SetEnabled(false)
			elseif owned then
				button:SetText("EQUIP")
				button:SetColor(Theme.Colors.Blue)
				button:SetEnabled(true)
			elseif data.Rebirths < aura.RequiredRebirths then
				button:SetText(`🔒 REBIRTH {aura.RequiredRebirths}`)
				button:SetColor(Theme.Colors.GrayDark)
				button:SetEnabled(false)
			else
				local affordable = data.Coins >= aura.Cost
				button:SetText(`🪙 {NumberFormat.Abbreviate(aura.Cost)}`)
				button:SetColor(if affordable then Theme.Colors.Green else Theme.Colors.GrayDark)
				button:SetEnabled(true)
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

return AurasMenu
