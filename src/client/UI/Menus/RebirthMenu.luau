--[[
	RebirthMenu.luau
	Rebirth at max level: reset Strength for a permanent multiplier and new training zones.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Formulas = require(Shared.Formulas)
local NumberFormat = require(Shared.NumberFormat)

local ClientData = require(script.Parent.Parent.Parent.ClientData)
local ChunkyButton = require(script.Parent.Parent.ChunkyButton)
local Create = require(script.Parent.Parent.Create)
local MenuWindow = require(script.Parent.Parent.MenuWindow)
local Theme = require(script.Parent.Parent.Theme)

local RebirthMenu = {}

local REFRESH_KEYS = { Strength = true, Rebirths = true, Passes = true }

function RebirthMenu.new(parent: Instance, ctx: { [string]: any })
	local window = MenuWindow.new({ Title = "Rebirth", Icon = "🌀", Color = Theme.Colors.Blue, Parent = parent })

	local summary = Create("Frame", {
		Name = "Summary",
		LayoutOrder = 1,
		Size = UDim2.new(1, -6, 0, 200),
		BackgroundColor3 = Color3.fromRGB(30, 90, 190),
		ZIndex = 2,
		Parent = window.Content,
	}, { Create.Corner(UDim.new(0, 12)), Create.Stroke(3), Create.Bevel(0.2) })

	local countLabel = Create.Label({
		Font = Theme.Fonts.Title,
		Position = UDim2.fromOffset(16, 10),
		Size = UDim2.new(1, -32, 0, 36),
		ZIndex = 3,
		Parent = summary,
	})
	local boostLabel = Create.Label({
		TextColor3 = Theme.Colors.Yellow,
		Position = UDim2.fromOffset(16, 50),
		Size = UDim2.new(1, -32, 0, 28),
		ZIndex = 3,
		Parent = summary,
	})
	local barBack = Create("Frame", {
		Position = UDim2.fromOffset(16, 88),
		Size = UDim2.new(1, -32, 0, 30),
		BackgroundColor3 = Theme.Colors.Ink,
		ZIndex = 3,
		Parent = summary,
	}, { Create.Corner(UDim.new(1, 0)), Create.Stroke(3) })
	local barFill = Create(
		"Frame",
		{ Size = UDim2.fromScale(0, 1), BackgroundColor3 = Theme.Colors.Yellow, ZIndex = 4, Parent = barBack },
		{
			Create.Corner(UDim.new(1, 0)),
			Create.Bevel(0.3),
		}
	)
	local barText = Create.Label({
		Size = UDim2.new(1, -16, 1, -6),
		Position = UDim2.fromOffset(8, 3),
		ZIndex = 5,
		Parent = barBack,
	})
	Create.Label({
		Text = "Resets Strength. Keeps Wins, items, pets & trails.",
		TextColor3 = Theme.Colors.Cream,
		Position = UDim2.fromOffset(16, 128),
		Size = UDim2.new(1, -250, 0, 22),
		StrokeThickness = 2,
		ZIndex = 3,
		Parent = summary,
	})
	local rebirthButton = ChunkyButton.new({
		Text = "REBIRTH!",
		Icon = "🌀",
		Color = Theme.Colors.Yellow,
		Font = Theme.Fonts.Title,
		Size = UDim2.fromOffset(210, 64),
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -14, 1, -10),
		Parent = summary,
	})
	rebirthButton.Instance.ZIndex = 3
	rebirthButton.Activated:Connect(function()
		ctx.Request("Rebirth")
	end)

	MenuWindow.Header(window.Content, 2, "⛩️ TRAINING ZONES")
	local zoneCards = {}
	for index, zone in Config.TrainingZones do
		local card = MenuWindow.Card(window.Content, 10 + index, 80)
		card.Swatch.BackgroundColor3 = zone.Floor
		Create("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0.45, 0.6),
			BackgroundColor3 = zone.Accent,
			ZIndex = 4,
			Parent = card.Swatch,
		}, { Create.Corner(UDim.new(0, 6)), Create.Stroke(2) })
		card.Title.Text = zone.Name
		card.Subtitle.Text = `{NumberFormat.Multiplier(zone.Multiplier)} Strength while training`
		card.Button.Activated:Connect(function()
			if zone.Pass then
				ctx.Purchase("pass:" .. zone.Pass)
			end
		end)
		zoneCards[index] = card
	end

	local function refresh()
		local data = ClientData.Data
		if not data then
			return
		end
		local rebirths = data.Rebirths
		local cost = Formulas.GetRebirthCost(rebirths)
		local progress = Formulas.GetRebirthProgress(data)
		local ready = progress >= 1
		countLabel.Text = `REBIRTHS: {rebirths}`
		boostLabel.Text =
			`Strength {NumberFormat.Multiplier(Formulas.GetRebirthMultiplier(rebirths))} ➜ {NumberFormat.Multiplier(
				Formulas.GetRebirthMultiplier(rebirths + 1)
			)}   •   Wins +{NumberFormat.Percent(Config.Rebirth.WinsPerRebirth)}`
		barText.Text = `⚡ {NumberFormat.Abbreviate(data.Strength)} / {NumberFormat.Abbreviate(cost)}`
		TweenService:Create(barFill, TweenInfo.new(0.2), { Size = UDim2.fromScale(progress, 1) }):Play()
		barFill.BackgroundColor3 = if ready then Theme.Colors.Green else Theme.Colors.Yellow
		rebirthButton:SetColor(if ready then Theme.Colors.Yellow else Theme.Colors.GrayDark)

		for index, zone in Config.TrainingZones do
			local card = zoneCards[index]
			local unlocked = Formulas.IsZoneUnlocked(data, zone.Id)
			if zone.Pass then
				card.Info.Text = "Game pass zone"
			else
				card.Info.Text = if zone.RequiredRebirths == 0
					then "Always open"
					else `Needs {zone.RequiredRebirths} rebirths`
			end
			if unlocked then
				card.Button:SetText("UNLOCKED")
				card.Button:SetColor(Theme.Colors.Gray)
				card.Button:SetEnabled(false)
			elseif zone.Pass then
				card.Button:SetText(`R$ {Config.Monetization.GamePasses[zone.Pass].Price}`)
				card.Button:SetColor(Theme.Colors.Green)
				card.Button:SetEnabled(true)
			else
				card.Button:SetText(`🔒 🌀 {zone.RequiredRebirths}`)
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

return RebirthMenu
