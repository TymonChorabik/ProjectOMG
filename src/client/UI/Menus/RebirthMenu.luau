--[[
	RebirthMenu.luau
	Rebirth, laid out like +1 Stone Skipping's: "Before ➡️ After" Strength multiplier cards,
	a red warning, the studded level bar and two buttons: Rebirth (at max level) and Skip
	Rebirth (Robux: rebirth right away).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

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

local REFRESH_KEYS = { Strength = true, Rebirths = true }
local BAR_WIDTH = 500

-- Yellow card: big ⚡ and "x2 STRENGTH".
local function multiplierCard(parent: Instance, xScale: number): TextLabel
	local card = MenuWindow.Card({
		Parent = parent,
		Size = UDim2.fromOffset(280, 104),
		Position = UDim2.new(xScale, 0, 0, 60),
		AnchorPoint = Vector2.new(0.5, 0),
		Color = Theme.Colors.Yellow,
	})
	Create.Icon({
		Text = "⚡",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 10, 0.5, 0),
		Size = UDim2.fromOffset(92, 92),
		Rotation = 10,
		ZIndex = 5,
		Parent = card,
	})
	return Create.Label({
		Text = "x1\nSTRENGTH",
		Position = UDim2.fromOffset(104, 10),
		Size = UDim2.new(1, -114, 1, -20),
		StrokeThickness = 4,
		MaxTextSize = 40,
		ZIndex = 6,
		Parent = card,
	})
end

function RebirthMenu.new(parent: Instance, ctx: { [string]: any })
	local window = MenuWindow.new({ Title = "Rebirth", Icon = "🔄", Size = Vector2.new(720, 520), Parent = parent })
	window.Content.Visible = false

	local body = Create("Frame", {
		Name = "Body",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(16, 56),
		Size = UDim2.new(1, -32, 1, -70),
		ZIndex = 2,
		Parent = window.Instance,
	})

	for _, entry in { { "Before", 0.25 }, { "After", 0.75 } } do
		Create.Label({
			Text = entry[1],
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.fromScale(entry[2], 0),
			Size = UDim2.fromOffset(280, 54),
			StrokeThickness = 5,
			MaxTextSize = 52,
			ZIndex = 3,
			Parent = body,
		})
	end
	local beforeLabel = multiplierCard(body, 0.25)
	local afterLabel = multiplierCard(body, 0.75)
	Create.Icon({
		Text = "➡️",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0, 112),
		Size = UDim2.fromOffset(64, 64),
		ZIndex = 4,
		Parent = body,
	})

	Create.Label({
		Text = "Resets your LEVEL and STRENGTH!",
		TextColor3 = Color3.fromRGB(255, 60, 60),
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 180),
		Size = UDim2.new(1, -40, 0, 44),
		StrokeThickness = 4.5,
		MaxTextSize = 40,
		ZIndex = 3,
		Parent = body,
	})

	-- Level bar: dark studded track, bright studded fill clipped to the progress.
	local track = StudPanel.new({
		Size = UDim2.fromOffset(BAR_WIDTH, 70),
		Position = UDim2.new(0.5, 0, 0, 232),
		AnchorPoint = Vector2.new(0.5, 0),
		Color = Color3.fromRGB(18, 58, 140),
		CornerRadius = UDim.new(0, 14),
		StrokeThickness = 4,
		ZIndex = 3,
		Parent = body,
	})
	local fillClip = Create("Frame", {
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		Size = UDim2.fromScale(0, 1),
		ZIndex = 3,
		Parent = track,
	})
	local fill = StudPanel.new({
		Size = UDim2.fromOffset(BAR_WIDTH, 70),
		Color = Theme.Colors.Blue,
		CornerRadius = UDim.new(0, 14),
		StrokeThickness = 0,
		ZIndex = 3,
		Parent = fillClip,
	})
	local levelText = Create.Label({
		Text = "Level 1 / Level 40",
		Position = UDim2.fromOffset(12, 10),
		Size = UDim2.new(1, -24, 1, -20),
		StrokeThickness = 4.5,
		MaxTextSize = 46,
		ZIndex = 6,
		Parent = track,
	})

	local rebirthButton = ChunkyButton.new({
		Text = "Rebirth",
		Color = Theme.Colors.Green,
		Size = UDim2.fromOffset(220, 78),
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(0.5, -14, 0, 322),
		MaxTextSize = 44,
		StrokeThickness = 4,
		Parent = body,
	})
	rebirthButton.Instance.ZIndex = 3
	rebirthButton.Activated:Connect(function()
		ctx.Request("Rebirth")
	end)

	local skip = Config.Monetization.Products.SkipRebirth
	local skipButton = ChunkyButton.new({
		Text = "Skip Rebirth",
		Color = Theme.Colors.Purple,
		Size = UDim2.fromOffset(240, 78),
		Position = UDim2.new(0.5, 14, 0, 322),
		MaxTextSize = 36,
		StrokeThickness = 4,
		Parent = body,
	})
	skipButton.Instance.ZIndex = 3
	Create.Label({
		Text = `{Theme.Robux}{skip.Price}`,
		TextColor3 = Theme.Colors.GreenText,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, 6, 0, 2),
		Size = UDim2.fromOffset(90, 32),
		TextXAlignment = Enum.TextXAlignment.Right,
		StrokeThickness = 3.5,
		ZIndex = 12,
		Parent = skipButton.Instance,
	})
	skipButton.Activated:Connect(function()
		ctx.Purchase("product:SkipRebirth")
	end)

	Create.Label({
		Text = `+{NumberFormat.Percent(Config.Rebirth.WinsPerRebirth)} Wins every rebirth  •  Keeps Wins, items, pets & trails`,
		TextColor3 = Theme.Colors.Cream,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -4),
		Size = UDim2.new(1, -40, 0, 26),
		StrokeThickness = 3,
		ZIndex = 3,
		Parent = body,
	})

	local function refresh()
		local data = ClientData.Data
		if not data then
			return
		end
		local rebirths = data.Rebirths
		local level = Formulas.GetLevel(data.Strength, rebirths)
		local maxLevel = Config.Rebirth.MaxLevel
		local ready = Formulas.GetRebirthProgress(data) >= 1
		beforeLabel.Text = `{NumberFormat.Multiplier(Formulas.GetRebirthMultiplier(rebirths))}\nSTRENGTH`
		afterLabel.Text = `{NumberFormat.Multiplier(Formulas.GetRebirthMultiplier(rebirths + 1))}\nSTRENGTH`
		levelText.Text = `Level {math.min(level, maxLevel)} / Level {maxLevel}`
		fillClip.Size = UDim2.fromScale(math.clamp(level / maxLevel, 0, 1), 1)
		StudPanel.SetColor(fill, if ready then Theme.Colors.Green else Theme.Colors.Blue)
		rebirthButton:SetColor(if ready then Theme.Colors.Green else Theme.Colors.GrayDark)
		rebirthButton:SetText(if ready then "Rebirth" else "🔒 Rebirth")
	end

	ClientData.Changed:Connect(function(key)
		if REFRESH_KEYS[key] and window.IsOpen then
			refresh()
		end
	end)
	window.Opened:Connect(refresh)
	refresh()
	return window
end

return RebirthMenu
