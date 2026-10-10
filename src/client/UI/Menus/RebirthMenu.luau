--[[
	RebirthMenu.luau
	Rebirth at max level: reset Strength for a permanent multiplier and new training zones.
	Top: studded summary (multiplier now ➜ next, progress bar, REBIRTH! button). Below: the
	training zones as tiles with their unlock state.
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
local StudPanel = require(script.Parent.Parent.StudPanel)
local Theme = require(script.Parent.Parent.Theme)

local RebirthMenu = {}

local REFRESH_KEYS = { Strength = true, Rebirths = true, Passes = true }

local function hex(color: Color3): string
	return "#" .. color:ToHex()
end

function RebirthMenu.new(parent: Instance, ctx: { [string]: any })
	local window = MenuWindow.new({ Title = "Rebirth", Icon = "🔄", Parent = parent })

	local summary = StudPanel.new({
		Name = "Summary",
		LayoutOrder = 1,
		Size = UDim2.new(1, -6, 0, 196),
		Color = Theme.Colors.Blue,
		ZIndex = 2,
		Parent = window.Content,
	})
	local countLabel = Create.Label({
		TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.fromOffset(18, 12),
		Size = UDim2.new(1, -260, 0, 30),
		StrokeThickness = 3,
		ZIndex = 3,
		Parent = summary,
	})
	local boostLabel = Create.Label({
		RichText = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.fromOffset(18, 48),
		Size = UDim2.new(1, -260, 0, 40),
		StrokeThickness = 3.5,
		ZIndex = 3,
		Parent = summary,
	})
	Create.Label({
		Text = `+{NumberFormat.Percent(Config.Rebirth.WinsPerRebirth)} Wins with every rebirth`,
		TextColor3 = Theme.Colors.Cream,
		TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.fromOffset(18, 92),
		Size = UDim2.new(1, -260, 0, 20),
		StrokeThickness = 2.5,
		ZIndex = 3,
		Parent = summary,
	})

	local track = StudPanel.new({
		Size = UDim2.new(1, -262, 0, 40),
		Position = UDim2.fromOffset(18, 120),
		Color = Color3.fromRGB(20, 40, 90),
		Studs = false,
		CornerRadius = UDim.new(0, 10),
		ZIndex = 3,
		Parent = summary,
	})
	local fillClip = Create("Frame", {
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		Size = UDim2.fromScale(0, 1),
		ZIndex = 4,
		Parent = track,
	})
	local fill = StudPanel.new({
		Size = UDim2.new(1, 0, 1, 0),
		Color = Theme.Colors.Yellow,
		StrokeThickness = 0,
		CornerRadius = UDim.new(0, 10),
		ZIndex = 4,
		Parent = fillClip,
	})
	local barText = Create.Label({
		Size = UDim2.new(1, -16, 1, -10),
		Position = UDim2.fromOffset(8, 5),
		StrokeThickness = 3,
		ZIndex = 6,
		Parent = track,
	})
	Create.Label({
		Text = "Resets Strength. Keeps Wins, items, pets & trails.",
		TextColor3 = Theme.Colors.Cream,
		TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.fromOffset(18, 166),
		Size = UDim2.new(1, -262, 0, 18),
		StrokeThickness = 2,
		ZIndex = 3,
		Parent = summary,
	})

	local rebirthButton = ChunkyButton.new({
		Text = "REBIRTH!",
		Color = Theme.Colors.Green,
		Size = UDim2.fromOffset(210, 82),
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -18, 0.5, 6),
		MaxTextSize = 34,
		StrokeThickness = 3.5,
		Parent = summary,
	})
	rebirthButton.Instance.ZIndex = 3
	rebirthButton.Activated:Connect(function()
		ctx.Request("Rebirth")
	end)

	MenuWindow.Header(window.Content, 2, "Training Zones")
	local grid = MenuWindow.Grid(window.Content, 3, Vector2.new(140, 150))
	local zoneTiles = {}
	for index, zone in Config.TrainingZones do
		local tile = MenuWindow.Tile({
			Parent = grid,
			Order = index,
			Color = zone.Floor,
			Title = string.upper(zone.Name),
			Bar = "",
		})
		Create.Label({
			Text = NumberFormat.Multiplier(zone.Multiplier),
			TextColor3 = Theme.Colors.Gold,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(1, 0.8),
			StrokeThickness = 4,
			MaxTextSize = 46,
			ZIndex = 4,
			Parent = tile.Art,
		})
		tile.Activated:Connect(function()
			local data = ClientData.Data
			if zone.Pass and data and not Formulas.IsZoneUnlocked(data, zone.Id) then
				ctx.Purchase("pass:" .. zone.Pass)
			end
		end)
		zoneTiles[index] = tile
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
		countLabel.Text = `Rebirths: {rebirths}`
		boostLabel.Text = string.format(
			'<font color="%s">%s</font>  »  <font color="%s">%s</font> Strength',
			hex(Theme.Colors.Gold),
			NumberFormat.Multiplier(Formulas.GetRebirthMultiplier(rebirths)),
			hex(Theme.Colors.GreenText),
			NumberFormat.Multiplier(Formulas.GetRebirthMultiplier(rebirths + 1))
		)
		barText.Text = `⚡ {NumberFormat.Abbreviate(data.Strength)} / {NumberFormat.Abbreviate(cost)}`
		TweenService:Create(fillClip, TweenInfo.new(0.2), { Size = UDim2.fromScale(math.min(progress, 1), 1) }):Play()
		fill.Size = UDim2.new(1 / math.max(progress, 0.01), 0, 1, 0)
		StudPanel.SetColor(fill, if ready then Theme.Colors.Green else Theme.Colors.Yellow)
		rebirthButton:SetColor(if ready then Theme.Colors.Green else Theme.Colors.GrayDark)
		rebirthButton:SetText(if ready then "REBIRTH!" else `🔒 LEVEL {Config.Rebirth.MaxLevel}`)

		for index, zone in Config.TrainingZones do
			local tile = zoneTiles[index]
			local unlocked = Formulas.IsZoneUnlocked(data, zone.Id)
			tile.Shade.Visible = not unlocked
			tile.Corner.Text = if unlocked then "✅" else ""
			if unlocked then
				tile.BarText.Text = "UNLOCKED"
				tile.Bar.BackgroundColor3 = Theme.Colors.GreenDark
			elseif zone.Pass then
				tile.BarText.Text = `R$ {Config.Monetization.GamePasses[zone.Pass].Price}`
				tile.Bar.BackgroundColor3 = Theme.Colors.Green
			else
				tile.BarText.Text = `🔒 {zone.RequiredRebirths} REBIRTHS`
				tile.Bar.BackgroundColor3 = Theme.Colors.Red
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
