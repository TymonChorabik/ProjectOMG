--[[
	Hud.luau
	HUD laid out like +1 Stone Skipping (sizes are for 1920x1080; UIController scales
	everything down on smaller screens):
	• Left         – 2x3 menu tiles: Shop, Rebirth (+%), Pets, Trails, Inventory, Gifts
	• Bottom-left  – rebirths, wins, friend boost
	• Bottom       – ⚡ Strength + multiplier, studded Level bar, and under it the +10K / +100K /
	                 +1M Strength packs plus AUTO SMASH (an on/off toggle once owned)
	• Top          – run distance (during a wall run)
	• Right        – Starter Pack, 2x Strength, 2x Wins offers + active boost timers
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Signal = require(Shared.Signal)

local ChunkyButton = require(script.Parent.ChunkyButton)
local Create = require(script.Parent.Create)
local StudPanel = require(script.Parent.StudPanel)
local Theme = require(script.Parent.Theme)

local Hud = {}

local PULSE_INFO = TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local HOVER_INFO = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local TILE = Vector2.new(86, 90)
local BOTTOM_WIDTH = 740
local LEVEL_HEIGHT = 72

local function hex(color: Color3): string
	return "#" .. color:ToHex()
end

-- "ONLY R$49" with ONLY in orange and the price in Robux green.
local function onlyPrice(price: number): string
	return `<font color="{hex(Theme.Colors.Orange)}">ONLY</font> <font color="{hex(Theme.Colors.GreenText)}">R${price}</font>`
end

local function container(props: { [string]: any }): (Frame, UIScale)
	props.BackgroundTransparency = 1
	local frame = Create("Frame", props)
	local scale = Create("UIScale", { Parent = frame })
	return frame, scale
end

local function statLine(parent: Instance, order: number, icon: string, height: number): TextLabel
	local row = Create("Frame", {
		BackgroundTransparency = 1,
		LayoutOrder = order,
		Size = UDim2.new(1, 0, 0, height),
		Parent = parent,
	})
	Create.Icon({ Text = icon, Size = UDim2.fromOffset(height, height), Parent = row })
	return Create.Label({
		Text = "0",
		TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.fromOffset(height + 8, 2),
		Size = UDim2.new(1, -(height + 8), 1, -4),
		StrokeThickness = 3.5,
		Parent = row,
	})
end

-- Big icon with a caption and no plate (the Starter Pack offer).
local function iconOffer(parent: Instance, order: number, icon: string, caption: string)
	local holder = Create("Frame", {
		Name = "StarterPack",
		BackgroundTransparency = 1,
		LayoutOrder = order,
		Size = UDim2.fromOffset(150, 124),
		Parent = parent,
	})
	local scale = Create("UIScale", { Parent = holder })
	local button = Create("TextButton", {
		Text = "",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Parent = holder,
	})
	Create.Icon({
		Text = icon,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.fromOffset(100, 100),
		Parent = holder,
	})
	Create.Label({
		Text = caption,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 1),
		Size = UDim2.new(1, 0, 0, 26),
		StrokeThickness = 3,
		ZIndex = 2,
		Parent = holder,
	})
	local activated = Signal.new()
	button.MouseEnter:Connect(function()
		TweenService:Create(scale, HOVER_INFO, { Scale = 1.08 }):Play()
	end)
	button.MouseLeave:Connect(function()
		TweenService:Create(scale, HOVER_INFO, { Scale = 1 }):Play()
	end)
	button.Activated:Connect(function()
		activated:Fire()
	end)
	return { Instance = holder, Activated = activated }
end

-- Studded offer button: big icon behind the title, "ONLY R$X" over the bottom edge.
local function offerButton(props: { [string]: any })
	local button = ChunkyButton.new({
		Name = props.Name,
		Text = props.Title,
		Color = props.Color,
		Rainbow = props.Rainbow,
		Size = props.Size,
		LayoutOrder = props.LayoutOrder,
		MaxTextSize = props.MaxTextSize or 30,
		StrokeThickness = 3,
		Parent = props.Parent,
	})
	local face = button.Face
	if props.Icon then
		Create.Icon({
			Name = "Art",
			Text = props.Icon,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.42),
			Size = UDim2.new(0, props.IconSize or 86, 0, props.IconSize or 86),
			Rotation = 12,
			ZIndex = 3,
			Parent = face,
		})
	end
	button.Label.ZIndex = 4
	if props.Price then
		button.Label.Size = UDim2.new(1, -14, 0.64, 0)
		button.Label.Position = UDim2.fromOffset(7, 6)
		local price = Create.Label({
			Name = "Price",
			Text = onlyPrice(props.Price),
			RichText = true,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, 0, 1, -8),
			Size = UDim2.new(1, -10, 0, 30),
			StrokeThickness = 3,
			MaxTextSize = 26,
			ZIndex = 10,
			Parent = button.Instance,
		})
		button.PriceLabel = price
	end
	return button
end

function Hud.new(gui: ScreenGui)
	local hud = {
		Scales = {} :: { UIScale },
		Buttons = {},
		StrengthPacks = {},
		MenuPressed = Signal.new(), -- (name)
		PackPressed = Signal.new(), -- (productName)
		OfferPressed = Signal.new(), -- ("pass:X" | "product:X")
		AutoSmashPressed = Signal.new(),
	}

	----------------------------------------------------------------------------
	-- Left: menu tiles
	----------------------------------------------------------------------------
	local left, leftScale = container({
		Name = "MenuGrid",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 16, 0.5, 0),
		Size = UDim2.fromOffset(TILE.X * 2 + 10, TILE.Y * 3 + 20),
		Parent = gui,
	})
	table.insert(hud.Scales, leftScale)
	Create("UIGridLayout", {
		CellSize = UDim2.fromOffset(TILE.X, TILE.Y),
		CellPadding = UDim2.fromOffset(10, 10),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = left,
	})
	for order, entry in
		{
			{ Name = "Shop", Icon = "🛒" },
			{ Name = "Rebirth", Icon = "🔄" },
			{ Name = "Pets", Icon = "🐶" },
			{ Name = "Trails", Icon = "☄️" },
			{ Name = "Inventory", Icon = "🎒" },
			{ Name = "Gifts", Icon = "🎁" },
		}
	do
		local button = ChunkyButton.new({
			Name = entry.Name,
			Text = entry.Name,
			Icon = entry.Icon,
			Caption = entry.Name,
			Color = Theme.Colors.Tile,
			Studs = false,
			Size = UDim2.fromOffset(TILE.X, TILE.Y),
			LayoutOrder = order,
			MaxTextSize = 21,
			StrokeThickness = 2.5,
			Parent = left,
		})
		button.Activated:Connect(function()
			hud.MenuPressed:Fire(entry.Name)
		end)
		hud.Buttons[entry.Name] = button
	end

	----------------------------------------------------------------------------
	-- Bottom-left: rebirths, wins, friend boost
	----------------------------------------------------------------------------
	local stats, statsScale = container({
		Name = "Stats",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 18, 1, -14),
		Size = UDim2.fromOffset(250, 150),
		Parent = gui,
	})
	table.insert(hud.Scales, statsScale)
	Create("UIListLayout", {
		SortOrder = Enum.SortOrder.LayoutOrder,
		VerticalAlignment = Enum.VerticalAlignment.Bottom,
		Padding = UDim.new(0, 6),
		Parent = stats,
	})
	hud.RebirthsLabel = statLine(stats, 1, "🔄", 48)
	hud.WinsLabel = statLine(stats, 2, "🏆", 48)
	hud.FriendLabel = Create.Label({
		Text = "Friend Boost +0%",
		LayoutOrder = 3,
		TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.new(1, 0, 0, 28),
		StrokeThickness = 3,
		Parent = stats,
	})

	----------------------------------------------------------------------------
	-- Bottom centre: strength, level bar, Robux packs
	----------------------------------------------------------------------------
	local bottom, bottomScale = container({
		Name = "Bottom",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -12),
		Size = UDim2.fromOffset(BOTTOM_WIDTH, 214),
		Parent = gui,
	})
	table.insert(hud.Scales, bottomScale)

	Create.Icon({
		Text = "⚡",
		Position = UDim2.fromOffset(2, -6),
		Size = UDim2.fromOffset(50, 50),
		Rotation = 10,
		Parent = bottom,
	})
	hud.StrengthLabel = Create.Label({
		Text = "0 STRENGTH",
		TextColor3 = Theme.Colors.Gold,
		TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.fromOffset(52, 2),
		Size = UDim2.new(0.62, -52, 0, 36),
		StrokeThickness = 3.5,
		Parent = bottom,
	})
	hud.MultiplierLabel = Create.Label({
		Text = "x1 Multiplier",
		TextColor3 = Theme.Colors.Gold,
		TextXAlignment = Enum.TextXAlignment.Right,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -4, 0, 6),
		Size = UDim2.new(0.38, 0, 0, 30),
		StrokeThickness = 3,
		Parent = bottom,
	})

	-- Level bar: dark studded track, bright studded fill clipped to the progress.
	local levelTrack = StudPanel.new({
		Name = "LevelBar",
		Size = UDim2.fromOffset(BOTTOM_WIDTH, LEVEL_HEIGHT),
		Position = UDim2.fromOffset(0, 46),
		Color = Color3.fromRGB(18, 58, 140),
		CornerRadius = UDim.new(0, 14),
		Parent = bottom,
	})
	local fillClip = Create("Frame", {
		Name = "Fill",
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		Size = UDim2.fromScale(0, 1),
		ZIndex = 1,
		Parent = levelTrack,
	})
	local fill = StudPanel.new({
		Name = "Plastic",
		Size = UDim2.fromOffset(BOTTOM_WIDTH, LEVEL_HEIGHT),
		Color = Theme.Colors.Blue,
		CornerRadius = UDim.new(0, 14),
		StrokeThickness = 0,
		Parent = fillClip,
	})
	hud.LevelFill = fillClip
	hud._levelPlastic = fill
	hud.LevelLabel = Create.Label({
		Text = "Level 1",
		TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.fromOffset(20, 12),
		Size = UDim2.new(0.5, -20, 1, -24),
		StrokeThickness = 3.5,
		ZIndex = 3,
		Parent = levelTrack,
	})
	hud.LevelRightLabel = Create.Label({
		Text = "",
		TextXAlignment = Enum.TextXAlignment.Right,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -20, 0, 18),
		Size = UDim2.new(0.5, -20, 1, -36),
		StrokeThickness = 3,
		ZIndex = 3,
		Parent = levelTrack,
	})

	local packs = Create("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 128),
		Size = UDim2.new(1, 0, 0, 76),
		Parent = bottom,
	}, {
		Create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0, 12),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	-- Three packs + AUTO SMASH share the row under the level bar.
	local packWidth = math.floor((BOTTOM_WIDTH - 36) / 4)
	for order, entry in
		{
			{ Product = "Strength10K", Label = "+10K", Color = Color3.fromRGB(255, 190, 30) },
			{ Product = "Strength100K", Label = "+100K", Color = Color3.fromRGB(236, 60, 60) },
			{ Product = "Strength1M", Label = "+1M", Rainbow = true },
		}
	do
		local product = Config.Monetization.Products[entry.Product]
		local button = ChunkyButton.new({
			Name = entry.Product,
			Text = entry.Label,
			Color = entry.Color,
			Rainbow = entry.Rainbow,
			Size = UDim2.fromOffset(packWidth, 74),
			LayoutOrder = order,
			MaxTextSize = 40,
			StrokeThickness = 3.5,
			Parent = packs,
		})
		Create.Icon({
			Text = "⚡",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.45),
			Size = UDim2.fromOffset(96, 96),
			Rotation = 14,
			ZIndex = 3,
			Parent = button.Face,
		})
		button.Label.ZIndex = 4
		Create.Label({
			Name = "Price",
			Text = `R${product.Price}`,
			TextColor3 = Theme.Colors.GreenText,
			TextXAlignment = Enum.TextXAlignment.Right,
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -8, 1, -6),
			Size = UDim2.fromOffset(100, 30),
			StrokeThickness = 3,
			ZIndex = 10,
			Parent = button.Instance,
		})
		button.Activated:Connect(function()
			hud.PackPressed:Fire(entry.Product)
		end)
		hud.StrengthPacks[entry.Product] = button
	end

	hud.AutoSmashButton = offerButton({
		Name = "AutoSmash",
		Title = "AUTO SMASH",
		Color = Theme.Colors.Red,
		Size = UDim2.fromOffset(packWidth, 74),
		Price = Config.Monetization.GamePasses.AutoSmash.Price,
		LayoutOrder = 4,
		MaxTextSize = 28,
		Parent = packs,
	})
	Create.Icon({
		Text = "🤖",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(1, -4, 0, 4),
		Size = UDim2.fromOffset(48, 48),
		Rotation = 12,
		ZIndex = 9,
		Parent = hud.AutoSmashButton.Instance,
	})
	hud.AutoSmashButton.Activated:Connect(function()
		hud.AutoSmashPressed:Fire()
	end)

	----------------------------------------------------------------------------
	-- Top: run distance
	----------------------------------------------------------------------------
	local top, topScale = container({
		Name = "Top",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 14),
		Size = UDim2.fromOffset(440, 80),
		Parent = gui,
	})
	table.insert(hud.Scales, topScale)
	hud.DistanceLabel = Create.Label({
		Name = "Distance",
		Text = "0 m",
		Font = Enum.Font.FredokaOne,
		TextColor3 = Theme.Colors.Gold,
		Size = UDim2.fromScale(1, 1),
		StrokeThickness = 4,
		Visible = false,
		Parent = top,
	})

	----------------------------------------------------------------------------
	-- Right: offers + boost timers
	----------------------------------------------------------------------------
	local right, rightScale = container({
		Name = "Offers",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -16, 0.46, 0),
		Size = UDim2.fromOffset(214, 420),
		Parent = gui,
	})
	table.insert(hud.Scales, rightScale)
	Create("UIListLayout", {
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, 14),
		Parent = right,
	})
	local passes = Config.Monetization.GamePasses
	hud.Offers = {}
	local starter = iconOffer(right, 1, "🎁", "STARTER PACK")
	starter.Activated:Connect(function()
		hud.OfferPressed:Fire("product:StarterPack")
	end)
	hud.Offers["product:StarterPack"] = starter
	for order, entry in
		{
			{
				Key = "pass:DoubleStrength",
				Title = "+2x STRENGTH",
				Icon = "⚡",
				Color = Color3.fromRGB(120, 200, 40),
				Pass = "DoubleStrength",
			},
			{
				Key = "pass:DoubleWins",
				Title = "2x WINS",
				Icon = "🏆",
				Color = Color3.fromRGB(250, 170, 30),
				Pass = "DoubleWins",
			},
		}
	do
		local button = offerButton({
			Name = entry.Key,
			Title = entry.Title,
			Icon = entry.Icon,
			Color = entry.Color,
			Size = UDim2.fromOffset(210, 82),
			Price = passes[entry.Pass].Price,
			LayoutOrder = order + 1,
			MaxTextSize = 30,
			Parent = right,
		})
		button.Activated:Connect(function()
			hud.OfferPressed:Fire(entry.Key)
		end)
		hud.Offers[entry.Key] = button
	end
	hud.BoostList = Create("Frame", {
		Name = "Boosts",
		BackgroundTransparency = 1,
		LayoutOrder = 10,
		Size = UDim2.fromOffset(210, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Parent = right,
	}, {
		Create("UIListLayout", {
			SortOrder = Enum.SortOrder.LayoutOrder,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0, 6),
		}),
	})

	return hud
end

-- Level bar: progress 0..1 fills the bar; turns green at max level.
function Hud.SetLevel(hud, level: number, progress: number, rightText: string, maxed: boolean)
	hud.LevelLabel.Text = `Level {level}`
	hud.LevelRightLabel.Text = rightText
	hud.LevelFill.Size = UDim2.fromScale(math.clamp(progress, 0, 1), 1)
	StudPanel.SetColor(hud._levelPlastic, if maxed then Theme.Colors.Green else Theme.Colors.Blue)
end

-- AUTO SMASH button: Robux offer ("ONLY R$25") until owned, then an ON / OFF toggle.
function Hud.SetAutoSmash(hud, owned: boolean, on: boolean)
	local button = hud.AutoSmashButton
	if owned then
		button.PriceLabel.Text = if on
			then `<font color="{hex(Theme.Colors.GreenText)}">ON</font>`
			else `<font color="{hex(Color3.fromRGB(255, 110, 110))}">OFF</font>`
		button:SetColor(if on then Theme.Colors.Green else Theme.Colors.GrayDark)
	else
		button.PriceLabel.Text = onlyPrice(Config.Monetization.GamePasses.AutoSmash.Price)
		button:SetColor(Theme.Colors.Red)
	end
end

-- Boost pills under the offers ("⚡ 2x Strength 9:41").
function Hud.SetBoosts(hud, active: { { Icon: string, Name: string, Seconds: number, Color: Color3 } })
	local list = hud.BoostList :: Frame
	for _, child in list:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	for order, boost in active do
		local seconds = math.max(0, math.floor(boost.Seconds))
		local pill = Create("Frame", {
			LayoutOrder = order,
			BackgroundColor3 = boost.Color,
			Size = UDim2.fromOffset(210, 34),
			Parent = list,
		}, { Create.Corner(UDim.new(0, 10)), Create.Stroke(3), Create.Bevel(0.25) })
		Create.Label({
			Text = string.format("%s %s  %d:%02d", boost.Icon, boost.Name, seconds // 60, seconds % 60),
			Position = UDim2.fromOffset(8, 4),
			Size = UDim2.new(1, -16, 1, -8),
			StrokeThickness = 2.5,
			Parent = pill,
		})
	end
end

function Hud.Pulse(label: GuiObject)
	local scale = label:FindFirstChildOfClass("UIScale") or Create("UIScale", { Parent = label })
	scale.Scale = 1.1
	TweenService:Create(scale, PULSE_INFO, { Scale = 1 }):Play()
end

return Hud
