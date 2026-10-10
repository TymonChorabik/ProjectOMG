--[[
	ShopMenu.luau
	Robux shop: every game pass and developer product from Config.Monetization, as studded
	tiles (name, big icon, green price bar). Owned passes turn grey with a tick.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)

local ClientData = require(script.Parent.Parent.Parent.ClientData)
local MenuWindow = require(script.Parent.Parent.MenuWindow)
local Theme = require(script.Parent.Parent.Theme)

local ShopMenu = {}

local TILE = Vector2.new(140, 158)

local PASSES = {
	{ Name = "AutoSmash", Color = Theme.Colors.Red },
	{ Name = "DoubleStrength", Color = Color3.fromRGB(120, 200, 40) },
	{ Name = "DoubleWins", Color = Color3.fromRGB(250, 170, 30) },
	{ Name = "PetSlots", Color = Theme.Colors.Blue },
	{ Name = "GoldenZone", Color = Color3.fromRGB(240, 190, 30) },
	{ Name = "DragonZone", Color = Color3.fromRGB(220, 70, 50) },
	{ Name = "CosmicZone", Color = Theme.Colors.Purple },
	{ Name = "PhoenixRelic", Color = Color3.fromRGB(255, 120, 40) },
	{ Name = "LionKing", Rainbow = true },
}
local PRODUCTS = {
	{ Name = "StarterPack", Title = "STARTER PACK", Icon = "🎁", Color = Theme.Colors.Pink },
	{ Name = "Strength10K", Title = "+10K STRENGTH", Icon = "⚡", Color = Color3.fromRGB(255, 190, 30) },
	{ Name = "Strength100K", Title = "+100K STRENGTH", Icon = "⚡", Color = Theme.Colors.Red },
	{ Name = "Strength1M", Title = "+1M STRENGTH", Icon = "⚡", Rainbow = true },
	{ Name = "RainbowEgg", Title = "RAINBOW EGG", Icon = "🥚", Rainbow = true },
}

local function price(amount: number): string
	return `R$ {amount}`
end

function ShopMenu.new(parent: Instance, ctx: { [string]: any })
	local window = MenuWindow.new({ Title = "Shop", Icon = "🛒", Parent = parent })
	local passes, products = Config.Monetization.GamePasses, Config.Monetization.Products
	local passTiles, productTiles = {}, {}

	MenuWindow.Header(window.Content, 1, "Game Passes")
	local passGrid = MenuWindow.Grid(window.Content, 2, TILE)
	for order, entry in PASSES do
		local pass = passes[entry.Name]
		local tile = MenuWindow.Tile({
			Parent = passGrid,
			Order = order,
			Color = entry.Color or Theme.Colors.Blue,
			Rainbow = entry.Rainbow,
			Title = string.upper(pass.Name),
			Icon = pass.Icon,
			Bar = price(pass.Price),
			BarColor = Theme.Colors.Green,
		})
		tile.Activated:Connect(function()
			ctx.Purchase("pass:" .. entry.Name)
		end)
		passTiles[entry.Name] = tile
	end

	MenuWindow.Header(window.Content, 3, "Packs")
	local productGrid = MenuWindow.Grid(window.Content, 4, TILE)
	for order, entry in PRODUCTS do
		local tile = MenuWindow.Tile({
			Parent = productGrid,
			Order = order,
			Color = entry.Color or Theme.Colors.Blue,
			Rainbow = entry.Rainbow,
			Title = entry.Title,
			Icon = entry.Icon,
			Bar = price(products[entry.Name].Price),
			BarColor = Theme.Colors.Green,
		})
		tile.Activated:Connect(function()
			ctx.Purchase("product:" .. entry.Name)
		end)
		productTiles[entry.Name] = tile
	end

	local function setOwned(tile, owned: boolean, label: string)
		tile.BarText.Text = if owned then "OWNED" else label
		tile.Bar.BackgroundColor3 = if owned then Theme.Colors.GrayDark else Theme.Colors.Green
		tile.Corner.Text = if owned then "✅" else ""
		tile.Shade.Visible = owned
	end

	local function refresh()
		local data = ClientData.Data
		if not data then
			return
		end
		for name, tile in passTiles do
			setOwned(tile, data.Passes[name] == true, price(passes[name].Price))
		end
		for name, tile in productTiles do
			setOwned(tile, products[name].OneTime == true and data.StarterPackBought, price(products[name].Price))
		end
	end

	ClientData.Changed:Connect(function(key)
		if (key == "Passes" or key == "StarterPackBought") and window.IsOpen then
			refresh()
		end
	end)
	window.Instance:GetPropertyChangedSignal("Visible"):Connect(refresh)
	refresh()
	return window
end

return ShopMenu
