--[[
	ShopMenu.luau
	Robux shop laid out like +1 Stone Skipping's: big studded offer cards in sections.
	  ~ Packs ~          Starter Pack banner (what's inside as chips, slashed old price)
	  ~ Strength Packs ~ / ~ Wins Packs ~   2-column pack cards
	  ~ Gamepasses ~     3-column tall cards
	  ~ Limited Offer ~  Rainbow Egg with its pet odds, buy 1 / 3 / 8
	  ~ Boosts ~         Boost Bundle + single boosts
	  ~ Codes ~          code box (RedeemCode)
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
local ViewportPreview = require(script.Parent.Parent.ViewportPreview)

local ShopMenu = {}

local CREAM = Color3.fromRGB(255, 240, 190)

local STRENGTH_PACKS = {
	{ Product = "Strength10K", Title = "Tiny Pack", Count = 1 },
	{ Product = "Strength100K", Title = "Small Pack", Count = 2 },
	{ Product = "Strength1M", Title = "Big Pack", Count = 3 },
	{ Product = "Strength10M", Title = "Huge Pack", Count = 4 },
}
local WINS_PACKS = {
	{ Product = "WinsTiny", Title = "Tiny Pack", Count = 1 },
	{ Product = "WinsSmall", Title = "Small Pack", Count = 2 },
	{ Product = "WinsMedium", Title = "Medium Pack", Count = 3 },
	{ Product = "WinsLarge", Title = "Large Pack", Count = 4 },
}
local PASSES = {
	-- Soft pastels; gold and rainbow only for the two premium "always better" passes.
	{ Name = "AutoSmash", Color = Theme.Pastel.Teal },
	{ Name = "DoubleStrength", Color = Theme.Pastel.Blue },
	{ Name = "DoubleWins", Color = Theme.Pastel.Butter },
	{ Name = "PetSlots", Color = Theme.Pastel.Lavender },
	{ Name = "GoldenZone", Color = Theme.Pastel.Mint },
	{ Name = "DragonZone", Color = Theme.Pastel.Peach },
	{ Name = "CosmicZone", Color = Theme.Pastel.Slate },
	{ Name = "PhoenixRelic", Color = Theme.Colors.Yellow },
	{ Name = "LionKing", Rainbow = true },
}
local BOOSTS = {
	{ Product = "BoostStrength", Kind = "Strength", Title = "Strength Boost", Color = Theme.Pastel.Peach },
	{ Product = "BoostWins", Kind = "Wins", Title = "Wins Boost", Color = Theme.Pastel.Butter },
	{ Product = "BoostLuck", Kind = "Luck", Title = "Luck Boost", Color = Theme.Pastel.Mint },
}

-- Offsets for piles of 1-4 icons ("more stuff" for bigger packs).
local PILES = {
	{ Vector2.new(0, 0) },
	{ Vector2.new(-20, 8), Vector2.new(20, -6) },
	{ Vector2.new(-26, 14), Vector2.new(26, 14), Vector2.new(0, -14) },
	{ Vector2.new(-28, 18), Vector2.new(28, 18), Vector2.new(-14, -14), Vector2.new(16, -10) },
}

local price = Theme.Price

local function pile(parent: Instance, icon: string, count: number, size: number)
	for index, offset in PILES[math.clamp(count, 1, 4)] do
		Create.Icon({
			Text = icon,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, offset.X, 0.5, offset.Y),
			Size = UDim2.fromOffset(size, size),
			Rotation = (index % 2 == 0) and 12 or -10,
			ZIndex = 5 + index,
			Parent = parent,
		})
	end
end

-- Small frosted square showing one thing inside a pack ("x10K" etc.).
local function chip(parent: Instance, order: number, icon: string?, petId: string?, label: string)
	local frame = Create("Frame", {
		Name = "Chip",
		LayoutOrder = order,
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.6,
		Size = UDim2.fromOffset(78, 78),
		ZIndex = 5,
		Parent = parent,
	}, { Create.Corner(UDim.new(0, 12)), Create.Stroke(2.5, Color3.new(1, 1, 1), 0.2) })
	local art = Create("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(6, 2),
		Size = UDim2.new(1, -12, 1, -24),
		ZIndex = 6,
		Parent = frame,
	})
	if petId then
		ViewportPreview.Pet(art, petId, 1.2)
	else
		Create.Icon({ Text = icon or "", Size = UDim2.fromScale(1, 1), ZIndex = 6, Parent = art })
	end
	Create.Label({
		Text = label,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -3),
		Size = UDim2.new(1, -6, 0, 24),
		StrokeThickness = 2.5,
		ZIndex = 7,
		Parent = frame,
	})
end

function ShopMenu.new(parent: Instance, ctx: { [string]: any })
	local window = MenuWindow.new({ Title = "Shop", Icon = "🛒", Parent = parent })
	local content = window.Content
	local passes, products = Config.Monetization.GamePasses, Config.Monetization.Products
	local passButtons: { [string]: any } = {}
	local starterButton

	local function buy(key: string)
		return function()
			ctx.Purchase(key)
		end
	end

	----------------------------------------------------------------------------
	-- Packs: Starter Pack banner
	----------------------------------------------------------------------------
	MenuWindow.Header(content, 1, "Packs")
	do
		local starter = products.StarterPack
		local card = MenuWindow.Card({ Parent = content, Order = 2, Size = UDim2.new(1, 0, 0, 214), Rainbow = true })
		local art = Create("Frame", {
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 12, 0.5, 0),
			Size = UDim2.fromOffset(190, 190),
			ZIndex = 4,
			Parent = card,
		})
		ViewportPreview.Pet(art, starter.Pet, 1.15)
		Create.Icon({
			Text = "⚡",
			Position = UDim2.fromOffset(0, 0),
			Size = UDim2.fromOffset(64, 64),
			Rotation = -12,
			ZIndex = 6,
			Parent = art,
		})
		Create.Label({
			Text = starter.Name,
			TextColor3 = CREAM,
			Position = UDim2.fromOffset(212, 10),
			Size = UDim2.new(1, -226, 0, 58),
			StrokeThickness = 5,
			MaxTextSize = 56,
			ZIndex = 6,
			Parent = card,
		})
		local chips = Create("Frame", {
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(212, 64),
			Size = UDim2.new(1, -226, 0, 78),
			ZIndex = 5,
			Parent = card,
		}, {
			Create("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				Padding = UDim.new(0, 10),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
		})
		chip(chips, 1, nil, starter.Pet, "x1")
		chip(chips, 2, "⚡", nil, `x{NumberFormat.Abbreviate(starter.Strength)}`)
		chip(chips, 3, "🏆", nil, `x{NumberFormat.Abbreviate(starter.Wins)}`)
		MenuWindow.WasPrice(card, price(starter.WasPrice), {
			AnchorPoint = Vector2.new(1, 1),
			Position = UDim2.new(1, -186, 1, -16),
		})
		starterButton = MenuWindow.PriceButton({
			Parent = card,
			Text = price(starter.Price),
			AnchorPoint = Vector2.new(1, 1),
			Position = UDim2.new(1, -16, 1, -10),
		})
		starterButton.Activated:Connect(buy("product:StarterPack"))
	end

	----------------------------------------------------------------------------
	-- Strength + Wins packs (2 columns)
	----------------------------------------------------------------------------
	local function packSection(order: number, title: string, packs, icon: string, color: Color3, unit: string)
		MenuWindow.Header(content, order, title)
		local grid = MenuWindow.Grid(content, order + 1, Vector2.new(0, 176), nil, 2)
		for index, pack in packs do
			local product = products[pack.Product]
			local card = MenuWindow.Card({ Parent = grid, Order = index, Size = UDim2.fromScale(1, 1), Color = color })
			Create.Label({
				Text = pack.Title,
				Position = UDim2.fromOffset(14, 10),
				Size = UDim2.new(1, -28, 0, 42),
				StrokeThickness = 4.5,
				MaxTextSize = 38,
				ZIndex = 6,
				Shadow = true,
				Parent = card,
			})
			local art = Create("Frame", {
				BackgroundTransparency = 1,
				Position = UDim2.fromOffset(12, 52),
				Size = UDim2.fromOffset(130, 112),
				ZIndex = 5,
				Parent = card,
			})
			MenuWindow.Glow(card, UDim2.fromOffset(77, 108), 120)
			pile(art, icon, pack.Count, 80)
			Create.Label({
				Text = `+{NumberFormat.Abbreviate(product[unit])} {unit}`,
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, -12, 0, 62),
				Size = UDim2.fromOffset(170, 36),
				TextXAlignment = Enum.TextXAlignment.Right,
				StrokeThickness = 3.5,
				ZIndex = 6,
				Parent = card,
			})
			if product.WasPrice then
				MenuWindow.WasPrice(card, price(product.WasPrice), {
					AnchorPoint = Vector2.new(1, 0),
					Position = UDim2.new(1, -168, 0, 112),
					Size = UDim2.fromOffset(90, 32),
				})
			end
			local button = MenuWindow.PriceButton({
				Parent = card,
				Text = price(product.Price),
				Size = UDim2.fromOffset(150, 56),
				AnchorPoint = Vector2.new(1, 1),
				Position = UDim2.new(1, -12, 1, -10),
			})
			button.Activated:Connect(buy("product:" .. pack.Product))
		end
	end
	packSection(3, "Strength Packs", STRENGTH_PACKS, "⚡", Theme.Pastel.Blue, "Strength")
	packSection(5, "Wins Packs", WINS_PACKS, "🏆", Theme.Pastel.Butter, "Wins")

	----------------------------------------------------------------------------
	-- Gamepasses (3 columns)
	----------------------------------------------------------------------------
	MenuWindow.Header(content, 7, "Gamepasses")
	local passGrid = MenuWindow.Grid(content, 8, Vector2.new(0, 238), nil, 3)
	for index, entry in PASSES do
		local pass = passes[entry.Name]
		local card = MenuWindow.Card({
			Parent = passGrid,
			Order = index,
			Size = UDim2.fromScale(1, 1),
			Color = entry.Color,
			Rainbow = entry.Rainbow,
		})
		Create.Label({
			Text = pass.Name,
			Position = UDim2.fromOffset(14, 10),
			Size = UDim2.new(1, -28, 0, 32),
			StrokeThickness = 4,
			MaxTextSize = 28,
			ZIndex = 6,
			Shadow = true,
			Parent = card,
		})
		MenuWindow.Glow(card, UDim2.new(0.5, 0, 0, 106), 150)
		Create.Icon({
			Text = pass.Icon,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, 0, 0, 106),
			Size = UDim2.fromOffset(112, 112),
			ZIndex = 5,
			Parent = card,
		})
		local button = MenuWindow.PriceButton({
			Parent = card,
			Text = price(pass.Price),
			Size = UDim2.new(1, -24, 0, 58),
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -10),
		})
		button.Activated:Connect(buy("pass:" .. entry.Name))
		passButtons[entry.Name] = button
	end

	----------------------------------------------------------------------------
	-- Limited offer: Rainbow Egg + odds
	----------------------------------------------------------------------------
	MenuWindow.Header(content, 9, "Limited Offer")
	do
		local egg = Formulas.GetEgg("Rainbow")
		local card = MenuWindow.Card({
			Parent = content,
			Order = 10,
			Size = UDim2.new(1, 0, 0, 252),
			Color = Theme.Pastel.Lavender,
		})
		Create.Label({
			Text = egg and egg.Name or "Rainbow Egg",
			TextColor3 = CREAM,
			TextXAlignment = Enum.TextXAlignment.Left,
			Position = UDim2.fromOffset(18, 8),
			Size = UDim2.new(0.6, 0, 0, 52),
			StrokeThickness = 5,
			MaxTextSize = 48,
			ZIndex = 6,
			Parent = card,
		})
		local eggArt = Create("Frame", {
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(6, 52),
			Size = UDim2.fromOffset(170, 176),
			ZIndex = 4,
			Parent = card,
		})
		ViewportPreview.Egg(eggArt, if egg then egg.Color else Color3.fromRGB(255, 120, 220))
		local odds = Create("Frame", {
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(186, 58),
			Size = UDim2.new(1, -200, 0, 104),
			ZIndex = 5,
			Parent = card,
		}, {
			Create("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				Padding = UDim.new(0, 12),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
		})
		for index, entry in Formulas.GetEggOdds("Rainbow") do
			local def = Config.Pets[entry.PetId]
			local slot = Create("Frame", {
				LayoutOrder = index,
				BackgroundTransparency = 1,
				Size = UDim2.fromOffset(96, 104),
				ZIndex = 5,
				Parent = odds,
			})
			local art = Create("Frame", {
				BackgroundColor3 = if def then Config.Rarities[def.Rarity].Color else Color3.new(1, 1, 1),
				Size = UDim2.fromOffset(96, 80),
				ZIndex = 5,
				Parent = slot,
			}, { Create.Corner(UDim.new(0, 12)), Create.Stroke(3), Create.Bevel(0.3) })
			ViewportPreview.Pet(art, entry.PetId, 1.3)
			Create.Label({
				Text = `{math.floor(entry.Chance * 100 + 0.5)}%`,
				AnchorPoint = Vector2.new(0.5, 1),
				Position = UDim2.new(0.5, 0, 1, 0),
				Size = UDim2.new(1, 0, 0, 30),
				StrokeThickness = 3.5,
				ZIndex = 8,
				Parent = slot,
			})
		end
		-- Buy 1 / 3 / 8 at once.
		local row = Create("Frame", {
			BackgroundTransparency = 1,
			Position = UDim2.new(0, 186, 1, -70),
			Size = UDim2.new(1, -200, 0, 60),
			ZIndex = 5,
			Parent = card,
		}, {
			Create("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				Padding = UDim.new(0, 8),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
		})
		for order, count in Config.PetsConfig.HatchCounts do
			local productName = if count == 1
				then "RainbowEgg"
				elseif egg and egg.MultiProducts then egg.MultiProducts[count]
				else nil
			local product = productName and products[productName]
			if product then
				local button = MenuWindow.PriceButton({
					Parent = row,
					Text = `{count}x  {price(product.Price)}`,
					Size = UDim2.fromOffset(146, 58),
					MaxTextSize = 26,
				})
				button.Instance.LayoutOrder = order
				button.Activated:Connect(buy("product:" .. productName))
			end
		end
	end

	----------------------------------------------------------------------------
	-- Boosts
	----------------------------------------------------------------------------
	MenuWindow.Header(content, 11, "Boosts")
	do
		local bundle = products.BoostBundle
		local card = MenuWindow.Card({
			Parent = content,
			Order = 12,
			Size = UDim2.new(1, 0, 0, 190),
			Gradient = ColorSequence.new(Theme.Pastel.Teal, Theme.Pastel.Blue),
		})
		pile(
			Create("Frame", {
				BackgroundTransparency = 1,
				Position = UDim2.fromOffset(16, 30),
				Size = UDim2.fromOffset(130, 130),
				ZIndex = 4,
				Parent = card,
			}),
			"🧪",
			3,
			84
		)
		Create.Label({
			Text = "Boost\nBundle",
			TextColor3 = CREAM,
			Position = UDim2.fromOffset(150, 20),
			Size = UDim2.fromOffset(220, 150),
			StrokeThickness = 5,
			MaxTextSize = 58,
			ZIndex = 6,
			Parent = card,
		})
		local lines = {}
		for _, boost in bundle.Boosts do
			table.insert(lines, `- {Config.Boosts[boost.Kind].Name} ({boost.Minutes} min)`)
		end
		Create.Label({
			Text = table.concat(lines, "\n"),
			TextXAlignment = Enum.TextXAlignment.Left,
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -16, 0, 16),
			Size = UDim2.fromOffset(250, 90),
			StrokeThickness = 3,
			ZIndex = 6,
			Parent = card,
		})
		MenuWindow.WasPrice(card, price(bundle.WasPrice), {
			AnchorPoint = Vector2.new(1, 1),
			Position = UDim2.new(1, -186, 1, -18),
		})
		local button = MenuWindow.PriceButton({
			Parent = card,
			Text = price(bundle.Price),
			AnchorPoint = Vector2.new(1, 1),
			Position = UDim2.new(1, -16, 1, -12),
		})
		button.Activated:Connect(buy("product:BoostBundle"))
	end
	local boostGrid = MenuWindow.Grid(content, 13, Vector2.new(0, 232), nil, 3)
	for index, entry in BOOSTS do
		local product = products[entry.Product]
		local boost = Config.Boosts[entry.Kind]
		local card =
			MenuWindow.Card({ Parent = boostGrid, Order = index, Size = UDim2.fromScale(1, 1), Color = entry.Color })
		Create.Label({
			Text = entry.Title,
			Position = UDim2.fromOffset(14, 10),
			Size = UDim2.new(1, -28, 0, 32),
			StrokeThickness = 4,
			MaxTextSize = 28,
			ZIndex = 6,
			Shadow = true,
			Parent = card,
		})
		MenuWindow.Glow(card, UDim2.new(0.5, 0, 0, 96), 120)
		Create.Icon({
			Text = boost.Icon,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, 0, 0, 96),
			Size = UDim2.fromOffset(90, 90),
			ZIndex = 5,
			Parent = card,
		})
		Create.Label({
			Text = `{string.upper(boost.Name)}\nfor {product.Boosts[1].Minutes} min`,
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -74),
			Size = UDim2.new(1, -28, 0, 40),
			StrokeThickness = 3,
			ZIndex = 6,
			Parent = card,
		})
		local button = MenuWindow.PriceButton({
			Parent = card,
			Text = price(product.Price),
			Size = UDim2.new(1, -24, 0, 56),
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -10),
		})
		button.Activated:Connect(buy("product:" .. entry.Product))
	end

	----------------------------------------------------------------------------
	-- Codes
	----------------------------------------------------------------------------
	MenuWindow.Header(content, 14, "Codes")
	do
		local card = MenuWindow.Card({
			Parent = content,
			Order = 15,
			Size = UDim2.new(1, 0, 0, 196),
			Gradient = ColorSequence.new(Theme.Pastel.Teal, Theme.Pastel.Blue),
		})
		Create.Label({
			Text = "Redeem codes for Free Strength,\nWins & Boosts!",
			Position = UDim2.fromOffset(20, 14),
			Size = UDim2.new(1, -40, 0, 76),
			StrokeThickness = 4,
			MaxTextSize = 36,
			ZIndex = 6,
			Parent = card,
		})
		local box = Create("TextBox", {
			Name = "CodeBox",
			Text = "",
			PlaceholderText = "Enter Code Here...",
			PlaceholderColor3 = Color3.fromRGB(180, 200, 240),
			TextColor3 = Theme.Colors.White,
			Font = Theme.Fonts.Body,
			TextScaled = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			ClearTextOnFocus = false,
			BackgroundColor3 = Color3.fromRGB(25, 60, 150),
			Position = UDim2.fromOffset(24, 104),
			Size = UDim2.new(1, -232, 0, 66),
			ZIndex = 6,
			Parent = card,
		}, {
			Create.Corner(UDim.new(0, 12)),
			Create.Stroke(3.5),
			Create("UIPadding", {
				PaddingLeft = UDim.new(0, 16),
				PaddingRight = UDim.new(0, 12),
				PaddingTop = UDim.new(0, 14),
				PaddingBottom = UDim.new(0, 14),
			}),
		})
		local redeem = MenuWindow.PriceButton({
			Parent = card,
			Text = "Redeem",
			Size = UDim2.fromOffset(180, 70),
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -24, 0, 102),
			MaxTextSize = 38,
		})
		local redeeming = false
		redeem.Activated:Connect(function()
			if redeeming or box.Text == "" then
				return
			end
			redeeming = true
			task.spawn(function()
				local result = ctx.RequestAsync("RedeemCode", string.sub(box.Text, 1, 32))
				if result and result.ok then
					box.Text = ""
				end
				redeeming = false
			end)
		end)
	end

	----------------------------------------------------------------------------
	-- Owned state
	----------------------------------------------------------------------------
	local function setOwned(button, owned: boolean, label: string)
		button:SetText(if owned then "OWNED" else label)
		button:SetColor(if owned then Theme.Colors.GrayDark else Theme.Colors.Green)
		button:SetEnabled(not owned)
	end

	local function refresh()
		local data = ClientData.Data
		if not data then
			return
		end
		for name, button in passButtons do
			setOwned(button, data.Passes[name] == true, price(passes[name].Price))
		end
		setOwned(starterButton, data.StarterPackBought == true, price(products.StarterPack.Price))
	end

	ClientData.Changed:Connect(function(key)
		if (key == "Passes" or key == "StarterPackBought") and window.IsOpen then
			refresh()
		end
	end)
	window.Opened:Connect(refresh)
	refresh()
	return window
end

return ShopMenu
