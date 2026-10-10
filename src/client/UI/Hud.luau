--[[
	Hud.luau
	Compact HUD laid out like +1 Stone Skipping (sizes are for 1920x1080; UIController scales
	everything down on smaller screens):
	• Left         – 2x3 grid of icon tiles: Shop, Rebirth (+%), Pets, Trails, Inventory, Gifts
	• Bottom-left  – rebirths, wins, friend boost
	• Bottom       – ⚡ Strength + multiplier, studded Level bar, three Robux Strength packs
	• Top          – AUTO CHOP banner (turns into an on/off toggle once owned) + run distance
	• Right        – Starter Pack, 2x Strength, 2x Wins offers + active boost timers
	• Bottom-right – round CHOP! / SMASH! button
	Panels and buttons use studded plastic, the same studs as the map.
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
local TILE = 70

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
	Create.Label({ Text = icon, Stroke = false, Size = UDim2.fromOffset(height, height), Parent = row })
	return Create.Label({
		Text = "0",
		Font = Theme.Fonts.Title,
		TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.fromOffset(height + 6, 0),
		Size = UDim2.new(1, -(height + 6), 1, 0),
		StrokeThickness = 2,
		Parent = row,
	})
end

function Hud.new(gui: ScreenGui)
	local hud = {
		Scales = {} :: { UIScale },
		Buttons = {},
		StrengthPacks = {},
		MenuPressed = Signal.new(), -- (name)
		PackPressed = Signal.new(), -- (productName)
		OfferPressed = Signal.new(), -- ("pass:X" | "product:X")
		AutoChopPressed = Signal.new(),
		ActionPressed = Signal.new(),
	}

	----------------------------------------------------------------------------
	-- Left: icon grid
	----------------------------------------------------------------------------
	local left, leftScale = container({
		Name = "MenuGrid",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 12, 0.5, 0),
		Size = UDim2.fromOffset(TILE * 2 + 6, TILE * 3 + 18),
		Parent = gui,
	})
	table.insert(hud.Scales, leftScale)
	Create("UIGridLayout", {
		CellSize = UDim2.fromOffset(TILE, TILE + 2),
		CellPadding = UDim2.fromOffset(6, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = left,
	})
	for order, entry in
		{
			{ Name = "Shop", Icon = "🛒" },
			{ Name = "Rebirth", Icon = "🌀" },
			{ Name = "Pets", Icon = "🐾" },
			{ Name = "Trails", Icon = "✨" },
			{ Name = "Inventory", Icon = "🎒" },
			{ Name = "Gifts", Icon = "🎁" },
		}
	do
		local button = ChunkyButton.new({
			Name = entry.Name,
			Text = entry.Name,
			Icon = entry.Icon,
			Caption = entry.Name,
			Color = Color3.fromRGB(52, 58, 74),
			Size = UDim2.fromOffset(TILE, TILE + 2),
			LayoutOrder = order,
			MaxTextSize = 14,
			Studs = true,
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
		Position = UDim2.new(0, 16, 1, -14),
		Size = UDim2.fromOffset(190, 84),
		Parent = gui,
	})
	table.insert(hud.Scales, statsScale)
	Create("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 2), Parent = stats })
	hud.RebirthsLabel = statLine(stats, 1, "🌀", 28)
	hud.WinsLabel = statLine(stats, 2, "🏆", 28)
	hud.FriendLabel = Create.Label({
		Text = "Friend Boost +0%",
		LayoutOrder = 3,
		TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.new(1, 0, 0, 20),
		StrokeThickness = 2,
		Parent = stats,
	})

	----------------------------------------------------------------------------
	-- Bottom centre: strength, level bar, Robux packs
	----------------------------------------------------------------------------
	local bottom, bottomScale = container({
		Name = "Bottom",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -10),
		Size = UDim2.fromOffset(470, 132),
		Parent = gui,
	})
	table.insert(hud.Scales, bottomScale)

	hud.StrengthLabel = Create.Label({
		Text = "⚡ 0 STRENGTH",
		Font = Theme.Fonts.Title,
		TextColor3 = Theme.Colors.Yellow,
		TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.fromOffset(4, 0),
		Size = UDim2.new(0.6, 0, 0, 24),
		StrokeThickness = 2,
		Parent = bottom,
	})
	hud.MultiplierLabel = Create.Label({
		Text = "x1 Multiplier",
		Font = Theme.Fonts.Title,
		TextColor3 = Theme.Colors.Yellow,
		TextXAlignment = Enum.TextXAlignment.Right,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -4, 0, 2),
		Size = UDim2.new(0.4, 0, 0, 20),
		StrokeThickness = 2,
		Parent = bottom,
	})

	local levelBar = StudPanel.new({
		Name = "LevelBar",
		Size = UDim2.new(1, 0, 0, 44),
		Position = UDim2.fromOffset(0, 28),
		Color = Color3.fromRGB(30, 120, 240),
		Parent = bottom,
	})
	hud.LevelFill = Create("Frame", {
		Name = "Fill",
		BackgroundColor3 = Color3.fromRGB(120, 220, 255),
		BackgroundTransparency = 0.55,
		Size = UDim2.fromScale(0, 1),
		ZIndex = 1,
		Parent = levelBar,
	}, { Create.Corner() })
	hud.LevelLabel = Create.Label({
		Text = "Level 1",
		Font = Theme.Fonts.Title,
		TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.fromOffset(14, 6),
		Size = UDim2.new(0.5, -14, 1, -12),
		StrokeThickness = 2.5,
		ZIndex = 3,
		Parent = levelBar,
	})
	hud.LevelRightLabel = Create.Label({
		Text = "",
		Font = Theme.Fonts.Title,
		TextXAlignment = Enum.TextXAlignment.Right,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -14, 0, 11),
		Size = UDim2.new(0.5, -14, 1, -22),
		StrokeThickness = 2,
		ZIndex = 3,
		Parent = levelBar,
	})

	local packs = Create("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 78),
		Size = UDim2.new(1, 0, 0, 54),
		Parent = bottom,
	}, {
		Create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0, 9),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	for order, entry in
		{
			{ Product = "Strength10K", Label = "+10K", Color = Color3.fromRGB(255, 196, 40) },
			{ Product = "Strength100K", Label = "+100K", Color = Color3.fromRGB(235, 64, 64) },
			{ Product = "Strength1M", Label = "+1M", Color = Color3.fromRGB(165, 80, 255) },
		}
	do
		local product = Config.Monetization.Products[entry.Product]
		local button = ChunkyButton.new({
			Name = entry.Product,
			Text = "⚡ " .. entry.Label,
			Color = entry.Color,
			Size = UDim2.fromOffset(150, 52),
			LayoutOrder = order,
			MaxTextSize = 24,
			Studs = true,
			Parent = packs,
		})
		local price = Create.Label({
			Name = "Price",
			Text = `R${product.Price}`,
			BackgroundTransparency = 0,
			BackgroundColor3 = Color3.fromRGB(40, 170, 70),
			AnchorPoint = Vector2.new(1, 1),
			Position = UDim2.new(1, 4, 1, 2),
			Size = UDim2.fromOffset(44, 20),
			StrokeThickness = 1.5,
			ZIndex = 10,
			Parent = button.Instance,
		})
		Create.Corner(UDim.new(0, 6)).Parent = price
		Create.Stroke(2).Parent = price
		button.Activated:Connect(function()
			hud.PackPressed:Fire(entry.Product)
		end)
		hud.StrengthPacks[entry.Product] = button
	end

	----------------------------------------------------------------------------
	-- Top: auto chop banner + run distance
	----------------------------------------------------------------------------
	local top, topScale = container({
		Name = "Top",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 6),
		Size = UDim2.fromOffset(220, 130),
		Parent = gui,
	})
	table.insert(hud.Scales, topScale)
	hud.AutoChopButton = ChunkyButton.new({
		Name = "AutoChop",
		Text = "AUTO CHOP\nONLY R$" .. Config.Monetization.GamePasses.AutoChop.Price,
		Color = Theme.Colors.Red,
		Size = UDim2.fromOffset(220, 54),
		MaxTextSize = 20,
		Studs = true,
		Parent = top,
	})
	hud.AutoChopButton.Activated:Connect(function()
		hud.AutoChopPressed:Fire()
	end)
	hud.DistanceLabel = Create.Label({
		Name = "Distance",
		Text = "0 m",
		Font = Theme.Fonts.Title,
		TextColor3 = Theme.Colors.Yellow,
		Position = UDim2.fromOffset(-60, 60),
		Size = UDim2.new(1, 120, 0, 56),
		StrokeThickness = 3,
		Visible = false,
		Parent = top,
	})

	----------------------------------------------------------------------------
	-- Right: offers + boost timers
	----------------------------------------------------------------------------
	local right, rightScale = container({
		Name = "Offers",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0.45, 0),
		Size = UDim2.fromOffset(156, 290),
		Parent = gui,
	})
	table.insert(hud.Scales, rightScale)
	Create("UIListLayout", {
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = Enum.HorizontalAlignment.Right,
		Padding = UDim.new(0, 8),
		Parent = right,
	})
	local passes, products = Config.Monetization.GamePasses, Config.Monetization.Products
	hud.Offers = {}
	for order, entry in
		{
			{
				Key = "product:StarterPack",
				Icon = "🎁",
				Caption = "STARTER PACK",
				Color = Color3.fromRGB(255, 110, 190),
				Size = UDim2.fromOffset(92, 84),
			},
			{
				Key = "pass:DoubleStrength",
				Text = `⚡ 2x STRENGTH\nONLY R${passes.DoubleStrength.Price}`,
				Color = Color3.fromRGB(110, 200, 50),
				Size = UDim2.fromOffset(152, 52),
			},
			{
				Key = "pass:DoubleWins",
				Text = `🏆 2x WINS\nONLY R${passes.DoubleWins.Price}`,
				Color = Color3.fromRGB(250, 175, 35),
				Size = UDim2.fromOffset(152, 52),
			},
		}
	do
		local button = ChunkyButton.new({
			Name = entry.Key,
			Text = entry.Text or entry.Caption,
			Icon = entry.Icon,
			Caption = entry.Caption,
			Color = entry.Color,
			Size = entry.Size,
			LayoutOrder = order,
			MaxTextSize = 17,
			Studs = true,
			Parent = right,
		})
		if entry.Key == "product:StarterPack" then
			button:SetTag(`R${products.StarterPack.Price}`)
		end
		button.Activated:Connect(function()
			hud.OfferPressed:Fire(entry.Key)
		end)
		hud.Offers[entry.Key] = button
	end
	hud.BoostList = Create("Frame", {
		Name = "Boosts",
		BackgroundTransparency = 1,
		LayoutOrder = 10,
		Size = UDim2.fromOffset(152, 80),
		Parent = right,
	}, {
		Create("UIListLayout", {
			SortOrder = Enum.SortOrder.LayoutOrder,
			HorizontalAlignment = Enum.HorizontalAlignment.Right,
			Padding = UDim.new(0, 3),
		}),
	})

	----------------------------------------------------------------------------
	-- Bottom-right: CHOP! / SMASH!
	----------------------------------------------------------------------------
	local actionHolder, actionScale = container({
		Name = "ActionHolder",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -18, 1, -18),
		Size = UDim2.fromOffset(96, 100),
		Parent = gui,
	})
	table.insert(hud.Scales, actionScale)
	hud.ActionButton = ChunkyButton.new({
		Name = "Action",
		Text = "CHOP!",
		Color = Theme.Colors.Red,
		Size = UDim2.fromScale(1, 1),
		CornerRadius = UDim.new(0.5, 0),
		Depth = 6,
		MaxTextSize = 24,
		Studs = true,
		Silent = true,
		Parent = actionHolder,
	})
	hud.ActionButton.Activated:Connect(function()
		hud.ActionPressed:Fire()
	end)

	return hud
end

-- Small boost pill ("⚡ 2x Strength 9:41").
function Hud.SetBoosts(hud, active: { { Icon: string, Name: string, Seconds: number, Color: Color3 } })
	local list = hud.BoostList :: Frame
	for _, child in list:GetChildren() do
		if child:IsA("TextLabel") then
			child:Destroy()
		end
	end
	for order, boost in active do
		local seconds = math.max(0, math.floor(boost.Seconds))
		local pill = Create.Label({
			LayoutOrder = order,
			Text = string.format("%s %s %d:%02d", boost.Icon, boost.Name, seconds // 60, seconds % 60),
			BackgroundTransparency = 0.1,
			BackgroundColor3 = boost.Color,
			Size = UDim2.fromOffset(150, 22),
			StrokeThickness = 1.5,
			Parent = list,
		})
		Create.Corner(UDim.new(0, 8)).Parent = pill
		Create.Stroke(2).Parent = pill
	end
end

function Hud.Pulse(label: GuiObject)
	local scale = label:FindFirstChildOfClass("UIScale") or Create("UIScale", { Parent = label })
	scale.Scale = 1.1
	TweenService:Create(scale, PULSE_INFO, { Scale = 1 }):Play()
end

return Hud
