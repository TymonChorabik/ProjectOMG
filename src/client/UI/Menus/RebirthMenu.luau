--[[
	RebirthMenu.luau
	Rebirth: trade your Power for a permanent multiplier, and travel between the dojos that
	rebirths unlock.
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

local REFRESH_KEYS = { Power = true, Rebirths = true, Coins = true }

function RebirthMenu.new(parent: Instance, request: (string, string?) -> (), getCurrentDojo: () -> string?)
	local window = MenuWindow.new({ Title = "Rebirth", Icon = "🌀", Color = Theme.Colors.Red, Parent = parent })

	-- Rebirth summary panel ----------------------------------------------------
	local summary = Create("Frame", {
		Name = "Summary",
		LayoutOrder = 1,
		Size = UDim2.new(1, -6, 0, 200),
		BackgroundColor3 = Theme.Colors.PanelRed,
		BackgroundTransparency = 0.05,
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
		Name = "ProgressBack",
		Position = UDim2.fromOffset(16, 88),
		Size = UDim2.new(1, -32, 0, 30),
		BackgroundColor3 = Theme.Colors.Ink,
		ZIndex = 3,
		Parent = summary,
	}, { Create.Corner(UDim.new(1, 0)), Create.Stroke(3) })
	local barFill = Create("Frame", {
		Name = "Fill",
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = Theme.Colors.Yellow,
		ZIndex = 4,
		Parent = barBack,
	}, { Create.Corner(UDim.new(1, 0)), Create.Bevel(0.3) })
	local barText = Create.Label({
		Size = UDim2.new(1, -16, 1, -6),
		Position = UDim2.fromOffset(8, 3),
		ZIndex = 5,
		Parent = barBack,
	})

	Create.Label({
		Text = "Resets Power. Keeps coins, belts, auras & upgrades.",
		TextColor3 = Theme.Colors.Cream,
		Position = UDim2.fromOffset(16, 124),
		Size = UDim2.new(1, -250, 0, 22),
		StrokeThickness = 2,
		ZIndex = 3,
		Parent = summary,
	})

	local rebirthButton = ChunkyButton.new({
		Name = "RebirthButton",
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
		request("Rebirth")
	end)

	-- Dojo travel ----------------------------------------------------------------
	MenuWindow.Header(window.Content, 2, "⛩️ TRAINING DOJOS")

	local dojoCards = {}
	for index, dojo in Config.Dojos do
		local card = MenuWindow.Card(window.Content, 10 + index, 86)
		card.Swatch.BackgroundColor3 = dojo.Colors.Mat
		Create("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0.6, 0.6),
			BackgroundColor3 = dojo.Colors.Trim,
			ZIndex = 4,
			Parent = card.Swatch,
		}, { Create.Corner(UDim.new(0, 6)), Create.Stroke(2) })
		card.Title.Text = dojo.Name
		card.Subtitle.Text = `Training {NumberFormat.Multiplier(dojo.TrainingMultiplier)} power per chop`
		card.Button.Activated:Connect(function()
			request("Teleport", dojo.Id)
		end)
		dojoCards[index] = card
	end

	local function refresh()
		local data = ClientData.Data
		if not data then
			return
		end

		local rebirths = data.Rebirths
		local cost = Formulas.GetRebirthCost(rebirths)
		local progress = math.clamp(data.Power / cost, 0, 1)
		local ready = data.Power >= cost

		countLabel.Text = `REBIRTHS: {rebirths}`
		boostLabel.Text =
			`Power {NumberFormat.Multiplier(Formulas.GetRebirthMultiplier(rebirths))} ➜ {NumberFormat.Multiplier(
				Formulas.GetRebirthMultiplier(rebirths + 1)
			)}   •   Coins +{NumberFormat.Percent(Config.Rebirth.CoinBonusPerRebirth)}`
		barText.Text = `⚡ {NumberFormat.Abbreviate(data.Power)} / {NumberFormat.Abbreviate(cost)}`
		TweenService:Create(barFill, TweenInfo.new(0.2), { Size = UDim2.fromScale(progress, 1) }):Play()
		barFill.BackgroundColor3 = if ready then Theme.Colors.Green else Theme.Colors.Yellow
		rebirthButton:SetColor(if ready then Theme.Colors.Yellow else Theme.Colors.GrayDark)
		rebirthButton:SetEnabled(true)

		local here = getCurrentDojo()
		for index, dojo in Config.Dojos do
			local card = dojoCards[index]
			local unlocked = rebirths >= dojo.RequiredRebirths
			card.Info.Text = if dojo.RequiredRebirths == 0
				then "Always open"
				else `Requires {dojo.RequiredRebirths} rebirth(s)`
			if here == dojo.Id then
				card.Button:SetText("YOU'RE HERE")
				card.Button:SetColor(Theme.Colors.Gray)
				card.Button:SetEnabled(false)
			elseif unlocked then
				card.Button:SetText("TRAVEL")
				card.Button:SetColor(Theme.Colors.Blue)
				card.Button:SetEnabled(true)
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

	window.Refresh = refresh
	return window
end

return RebirthMenu
