--[[
	InventoryMenu.luau
	Hand items (wraps → gauntlets): unlocked by lifetime Wins, equip any unlocked one.
	The Phoenix Relic game pass is always 125% better than your best unlocked item.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Formulas = require(Shared.Formulas)
local NumberFormat = require(Shared.NumberFormat)

local ClientData = require(script.Parent.Parent.Parent.ClientData)
local MenuWindow = require(script.Parent.Parent.MenuWindow)
local Theme = require(script.Parent.Parent.Theme)
local ViewportPreview = require(script.Parent.Parent.ViewportPreview)

local InventoryMenu = {}

local REFRESH_KEYS = { TotalWins = true, EquippedItem = true, Passes = true }

function InventoryMenu.new(parent: Instance, ctx: { [string]: any })
	local window =
		MenuWindow.new({ Title = "Inventory", Icon = "🎒", Color = Color3.fromRGB(200, 140, 80), Parent = parent })
	local entries = {}

	local items = table.clone(Config.HandItems)
	table.insert(items, Config.PremiumItem)

	for order, item in items do
		local card = MenuWindow.Card(window.Content, order, 92)
		card.Swatch.BackgroundColor3 = Color3.fromRGB(220, 235, 250)
		ViewportPreview.Item(card.Swatch, item)
		card.Title.Text = item.Name
		card.Title.TextColor3 = if item.Pass then Color3.fromRGB(255, 170, 60) else Theme.Colors.White
		card.Button.Activated:Connect(function()
			local data = ClientData.Data
			if item.Pass and data and not Formulas.HasPass(data, item.Pass) then
				ctx.Purchase("pass:" .. item.Pass)
			else
				ctx.Request("EquipItem", item.Id)
			end
		end)
		table.insert(entries, { Item = item, Card = card })
	end

	local function refresh()
		local data = ClientData.Data
		if not data then
			return
		end
		local best = Formulas.GetBestUnlockedItem(data)
		for _, entry in entries do
			local item, card = entry.Item, entry.Card
			local unlocked = Formulas.IsItemUnlocked(data, item.Id)
			local bonus = if item.Pass then best.Bonus * (1 + item.BetterBy) else item.Bonus
			card.Subtitle.Text = `+{NumberFormat.Abbreviate(bonus)} Strength per chop`
			if item.Pass then
				card.Info.Text = "Always 125% better than your best"
			else
				card.Info.Text = if item.Wins == 0
					then "Starter"
					else `Unlocks at {NumberFormat.Abbreviate(item.Wins)} Wins`
			end

			if data.EquippedItem == item.Id and unlocked then
				card.Button:SetText("EQUIPPED")
				card.Button:SetColor(Theme.Colors.Gray)
				card.Button:SetEnabled(false)
			elseif unlocked then
				card.Button:SetText("EQUIP")
				card.Button:SetColor(Theme.Colors.Blue)
				card.Button:SetEnabled(true)
			elseif item.Pass then
				card.Button:SetText(`R$ {Config.Monetization.GamePasses[item.Pass].Price}`)
				card.Button:SetColor(Theme.Colors.Green)
				card.Button:SetEnabled(true)
			else
				card.Button:SetText(`🔒 {NumberFormat.Abbreviate(item.Wins)} WINS`)
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

return InventoryMenu
