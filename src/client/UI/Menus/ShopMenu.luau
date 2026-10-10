--[[
	ShopMenu.luau
	Robux shop: every game pass and developer product from Config.Monetization.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local NumberFormat = require(Shared.NumberFormat)

local ClientData = require(script.Parent.Parent.Parent.ClientData)
local Create = require(script.Parent.Parent.Create)
local MenuWindow = require(script.Parent.Parent.MenuWindow)
local Theme = require(script.Parent.Parent.Theme)

local ShopMenu = {}

local PASS_ORDER = {
	"AutoChop",
	"DoubleStrength",
	"DoubleWins",
	"PetSlots",
	"GoldenZone",
	"DragonZone",
	"CosmicZone",
	"PhoenixRelic",
	"LionKing",
}
local PRODUCT_ORDER = { "StarterPack", "Strength10K", "Strength100K", "Strength1M", "RainbowEgg" }
local PRODUCT_ICONS =
	{ StarterPack = "🎁", Strength10K = "⚡", Strength100K = "⚡", Strength1M = "⚡", RainbowEgg = "🌈" }

local function iconSwatch(swatch: Frame, icon: string, color: Color3)
	swatch.BackgroundColor3 = color
	Create.Label({
		Text = icon,
		Stroke = false,
		Size = UDim2.fromScale(0.8, 0.8),
		Position = UDim2.fromScale(0.1, 0.1),
		ZIndex = 4,
		Parent = swatch,
	})
end

function ShopMenu.new(parent: Instance, ctx: { [string]: any })
	local window = MenuWindow.new({ Title = "Shop", Icon = "🛒", Color = Theme.Colors.Red, Parent = parent })
	local passes, products = Config.Monetization.GamePasses, Config.Monetization.Products
	local passCards, productCards = {}, {}

	MenuWindow.Header(window.Content, 0, "⭐ GAME PASSES")
	for order, name in PASS_ORDER do
		local pass = passes[name]
		local card = MenuWindow.Card(window.Content, order, 76)
		iconSwatch(card.Swatch, pass.Icon, Color3.fromRGB(255, 220, 120))
		card.Title.Text = pass.Name
		card.Subtitle.Text = pass.Description
		card.Info.Text = ""
		card.Button.Activated:Connect(function()
			ctx.Purchase("pass:" .. name)
		end)
		passCards[name] = card
	end

	MenuWindow.Header(window.Content, 100, "💎 PACKS & BOOSTS")
	for order, name in PRODUCT_ORDER do
		local product = products[name]
		local card = MenuWindow.Card(window.Content, 100 + order, 76)
		iconSwatch(card.Swatch, PRODUCT_ICONS[name] or "💎", Color3.fromRGB(170, 230, 255))
		card.Title.Text = product.Name
		local parts = {}
		if product.Strength then
			table.insert(parts, `+{NumberFormat.Abbreviate(product.Strength)} Strength`)
		end
		if product.Wins then
			table.insert(parts, `+{product.Wins} Wins`)
		end
		if product.Pet then
			table.insert(parts, Config.Pets[product.Pet].Name)
		end
		if name == "RainbowEgg" then
			table.insert(parts, "Hatch a Rainbow Egg (best pets!)")
		end
		card.Subtitle.Text = table.concat(parts, " • ")
		card.Info.Text = if product.OneTime then "One-time offer" else ""
		card.Button.Activated:Connect(function()
			ctx.Purchase("product:" .. name)
		end)
		productCards[name] = card
	end

	local function refresh()
		local data = ClientData.Data
		if not data then
			return
		end
		for name, card in passCards do
			local owned = data.Passes[name] == true
			card.Button:SetText(if owned then "OWNED" else `R$ {passes[name].Price}`)
			card.Button:SetColor(if owned then Theme.Colors.Gray else Theme.Colors.Green)
			card.Button:SetEnabled(not owned)
		end
		for name, card in productCards do
			local soldOut = products[name].OneTime and data.StarterPackBought
			card.Button:SetText(if soldOut then "OWNED" else `R$ {products[name].Price}`)
			card.Button:SetColor(if soldOut then Theme.Colors.Gray else Theme.Colors.Green)
			card.Button:SetEnabled(not soldOut)
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
