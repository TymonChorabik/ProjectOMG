--[[
	Hud.luau
	HUD laid out like +1 Stone Skipping:
	• Left        – 2x3 grid of chunky icon buttons: Shop, Rebirth (+%), Pets, Trails, Inventory, Gifts
	• Bottom-left – rebirths, wins, friend boost
	• Bottom      – ⚡ Strength + multiplier, studded Level bar, three Robux Strength packs
	• Top         – AUTO CHOP banner (turns into an on/off toggle once owned)
	• Right       – Starter Pack, 2x Strength, 2x Wins offers + active boost timers
	• Bottom-right – big round CHOP! / SMASH! button
	• Run HUD     – distance counter ("904 m")
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

local function container(props: { [string]: any }): (Frame, UIScale)
	props.BackgroundTransparency = 1
	local frame = Create("Frame", props)
	local scale = Create("UIScale", { Parent = frame })
	return frame, scale
end

local function statLine(parent: Instance, order: number, icon: string, height: number)
	local row = Create("Frame", {
		BackgroundTransparency = 1,
		LayoutOrder = order,
		Size = UDim2.new(1, 0, 0, height),
		Parent = parent,
	})
	Create.Label({ Text = icon, Stroke = false, Size = UDim2.fromOffset(height, height), Parent = row })
	local value = Create.Label({
		Text = "0",
		Font = Theme.Fonts.Title,
		TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.fromOffset(height + 8, 0),
		Size = UDim2.new(1, -(height + 8), 1, 0),
		StrokeThickness = 3,
		Parent = row,
	})
	return value
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
		Position = UDim2.new(0, 14, 0.45, 0),
		Size = UDim2.fromOffset(196, 300),
		Parent = gui,
	})
	table.insert(hud.Scales, leftScale)
	Create("UIGridLayout", {
		CellSize = UDim2.fromOffset(92, 94),
		CellPadding = UDim2.fromOffset(10, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = left,
	})
	for order, entry in
		{
			{ Name = "Shop", Icon = "🛒", Color = Color3.fromRGB(255, 80, 90) },
			{ Name = "Rebirth", Icon = "🌀", Color = Color3.fromRGB(80, 170, 255) },
			{ Name = "Pets", Icon = "🐾", Color = Color3.fromRGB(255, 160, 60) },
			{ Name = "Trails", Icon = "✨", Color = Color3.fromRGB(170, 90, 255) },
			{ Name = "Inventory", Icon = "🎒", Color = Color3.fromRGB(150, 100, 70) },
			{ Name = "Gifts", Icon = "🎁", Color = Color3.fromRGB(70, 200, 90) },
		}
	do
		local button = ChunkyButton.new({
			Name = entry.Name,
			Text = entry.Name,
			Icon = entry.Icon,
			Caption = entry.Name,
			Color = entry.Color,
			Size = UDim2.fromOffset(92, 94),
			LayoutOrder = order,
			MaxTextSize = 20,
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
		Position = UDim2.new(0, 18, 1, -16),
		Size = UDim2.fromOffset(250, 128),
		Parent = gui,
	})
	table.insert(hud.Scales, statsScale)
	Create("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 4), Parent = stats })
	hud.RebirthsLabel = statLine(stats, 1, "🌀", 42)
	hud.WinsLabel = statLine(stats, 2, "🏆", 42)
	hud.FriendLabel = Create.Label({
		Text = "Friend Boost +0%",
		LayoutOrder = 3,
		TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.new(1, 0, 0, 28),
		Parent = stats,
	})

	----------------------------------------------------------------------------
	-- Bottom centre: strength, level bar, Robux packs
	----------------------------------------------------------------------------
	local bottom, bottomScale = container({
		Name = "Bottom",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -12),
		Size = UDim2.fromOffset(640, 196),
		Parent = gui,
	})
	table.insert(hud.Scales, bottomScale)

	hud.StrengthLabel = Create.Label({
		Text = "⚡ 0 STRENGTH",
		Font = Theme.Fonts.Title,
		TextColor3 = Theme.Colors.Yellow,
		TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.new(0.6, 0, 0, 34),
		StrokeThickness = 3,
		Parent = bottom,
	})
	hud.MultiplierLabel = Create.Label({
		Text = "x1 Multiplier",
		Font = Theme.Fonts.Title,
		TextColor3 = Theme.Colors.Yellow,
		TextXAlignment = Enum.TextXAlignment.Right,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.new(0.4, 0, 0, 30),
		StrokeThickness = 3,
		Parent = bottom,
	})

	local levelBar = StudPanel.new({
		Name = "LevelBar",
		Size = UDim2.new(1, 0, 0, 66),
		Position = UDim2.fromOffset(0, 40),
		Color = Color3.fromRGB(30, 110, 230),
		Transparency = 0,
		StudTint = Color3.fromRGB(150, 210, 255),
		Parent = bottom,
	})
	hud.LevelFill = Create("Frame", {
		Name = "Fill",
		BackgroundColor3 = Color3.fromRGB(60, 200, 255),
		BackgroundTransparency = 0.35,
		Size = UDim2.fromScale(0, 1),
		ZIndex = 1,
		Parent = levelBar,
	}, { Create.Corner() })
	hud.LevelLabel = Create.Label({
		Text = "Level 1",
		Font = Theme.Fonts.Title,
		TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.fromOffset(20, 8),
		Size = UDim2.new(0.5, -20, 1, -16),
		StrokeThickness = 3,
		ZIndex = 3,
		Parent = levelBar,
	})
	hud.LevelRightLabel = Create.Label({
		Text = "",
		Font = Theme.Fonts.Title,
		TextXAlignment = Enum.TextXAlignment.Right,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -20, 0, 14),
		Size = UDim2.new(0.5, -20, 1, -28),
		StrokeThickness = 3,
		ZIndex = 3,
		Parent = levelBar,
	})

	local packs = Create("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 114),
		Size = UDim2.new(1, 0, 0, 78),
		Parent = bottom,
	}, {
		Create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0, 11),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	for order, entry in
		{
			{ Product = "Strength10K", Label = "+10K", Color = Color3.fromRGB(255, 200, 40) },
			{ Product = "Strength100K", Label = "+100K", Color = Color3.fromRGB(235, 60, 60) },
			{ Product = "Strength1M", Label = "+1M", Color = Color3.fromRGB(170, 70, 255) },
		}
	do
		local product = Config.Monetization.Products[entry.Product]
		local button = ChunkyButton.new({
			Name = entry.Product,
			Text = "⚡ " .. entry.Label,
			Color = entry.Color,
			Font = Theme.Fonts.Title,
			Size = UDim2.fromOffset(206, 74),
			LayoutOrder = order,
			MaxTextSize = 34,
			Parent = packs,
		})
		button:SetBadge(`R${product.Price}`)
		local badge = button.Instance:FindFirstChild("Badge") :: TextLabel
		badge.BackgroundColor3 = Color3.fromRGB(40, 170, 60)
		badge.Size = UDim2.fromOffset(52, 26)
		badge.Position = UDim2.new(1, -14, 1, -8)
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
		Position = UDim2.new(0.5, 0, 0, 8),
		Size = UDim2.fromOffset(300, 180),
		Parent = gui,
	})
	table.insert(hud.Scales, topScale)
	hud.AutoChopButton = ChunkyButton.new({
		Name = "AutoChop",
		Text = "🤖 AUTO CHOP\nONLY R$" .. Config.Monetization.GamePasses.AutoChop.Price,
		Color = Theme.Colors.Red,
		Font = Theme.Fonts.Title,
		Size = UDim2.fromOffset(300, 78),
		MaxTextSize = 30,
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
		Position = UDim2.fromOffset(-50, 86),
		Size = UDim2.new(1, 100, 0, 80),
		StrokeThickness = 5,
		Visible = false,
		Parent = top,
	})

	----------------------------------------------------------------------------
	-- Right: offers + boost timers
	----------------------------------------------------------------------------
	local right, rightScale = container({
		Name = "Offers",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -14, 0.42, 0),
		Size = UDim2.fromOffset(200, 330),
		Parent = gui,
	})
	table.insert(hud.Scales, rightScale)
	Create("UIListLayout", {
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = Enum.HorizontalAlignment.Right,
		Padding = UDim.new(0, 10),
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
				Color = Color3.fromRGB(255, 120, 200),
				Height = 112,
			},
			{
				Key = "pass:DoubleStrength",
				Text = `⚡ 2x STRENGTH\nONLY R${passes.DoubleStrength.Price}`,
				Color = Color3.fromRGB(120, 210, 60),
				Height = 72,
			},
			{
				Key = "pass:DoubleWins",
				Text = `🏆 2x WINS\nONLY R${passes.DoubleWins.Price}`,
				Color = Color3.fromRGB(255, 180, 40),
				Height = 72,
			},
		}
	do
		local button = ChunkyButton.new({
			Name = entry.Key,
			Text = entry.Text or entry.Caption,
			Icon = entry.Icon,
			Caption = entry.Caption,
			Color = entry.Color,
			Font = Theme.Fonts.Title,
			Size = UDim2.fromOffset(entry.Caption and 140 or 196, entry.Height),
			LayoutOrder = order,
			MaxTextSize = 24,
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
		Size = UDim2.fromOffset(196, 110),
		Parent = right,
	}, {
		Create("UIListLayout", {
			SortOrder = Enum.SortOrder.LayoutOrder,
			HorizontalAlignment = Enum.HorizontalAlignment.Right,
			Padding = UDim.new(0, 4),
		}),
	})

	----------------------------------------------------------------------------
	-- Bottom-right: CHOP! / SMASH!
	----------------------------------------------------------------------------
	local actionHolder, actionScale = container({
		Name = "ActionHolder",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -24, 1, -24),
		Size = UDim2.fromOffset(136, 142),
		Parent = gui,
	})
	table.insert(hud.Scales, actionScale)
	hud.ActionButton = ChunkyButton.new({
		Name = "Action",
		Text = "CHOP!",
		Color = Theme.Colors.Red,
		Font = Theme.Fonts.Title,
		Size = UDim2.fromScale(1, 1),
		CornerRadius = UDim.new(0.5, 0),
		Depth = 8,
		MaxTextSize = 34,
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
			Size = UDim2.fromOffset(190, 30),
			Parent = list,
		})
		Create.Corner(UDim.new(0, 10)).Parent = pill
		Create.Stroke(2).Parent = pill
	end
end

function Hud.Pulse(label: GuiObject)
	local scale = label:FindFirstChildOfClass("UIScale") or Create("UIScale", { Parent = label })
	scale.Scale = 1.12
	TweenService:Create(scale, PULSE_INFO, { Scale = 1 }):Play()
end

return Hud
