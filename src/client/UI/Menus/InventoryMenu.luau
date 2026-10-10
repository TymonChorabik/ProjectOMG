--[[
	InventoryMenu.luau
	Hand items (wraps → gauntlets) as studded tiles with 3D previews: unlocked by lifetime Wins,
	click any unlocked one to equip it. The Phoenix Relic game pass (rainbow tile) is always
	125% better than your best unlocked item.
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

local TILE = Vector2.new(110, 136)
local REFRESH_KEYS = { TotalWins = true, EquippedItem = true, Passes = true }

function InventoryMenu.new(parent: Instance, ctx: { [string]: any })
	local window = MenuWindow.new({ Title = "Inventory", Icon = "🎒", Parent = parent })
	local entries = {}

	local items = table.clone(Config.HandItems)
	table.insert(items, 1, Config.PremiumItem)

	local grid = MenuWindow.Grid(window.Content, 1, TILE)
	for order, item in items do
		local tile = MenuWindow.Tile({
			Parent = grid,
			Order = order,
			Color = Theme.Colors.Blue,
			Rainbow = item.Pass ~= nil,
			Title = "",
			Bar = "",
		})
		ViewportPreview.Item(tile.Art, item, 1.3)
		tile.Activated:Connect(function()
			local data = ClientData.Data
			if item.Pass and data and not Formulas.HasPass(data, item.Pass) then
				ctx.Purchase("pass:" .. item.Pass)
			else
				ctx.Request("EquipItem", item.Id)
			end
		end)
		table.insert(entries, { Item = item, Tile = tile })
	end

	local function refresh()
		local data = ClientData.Data
		if not data then
			return
		end
		local best = Formulas.GetBestUnlockedItem(data)
		for _, entry in entries do
			local item, tile = entry.Item, entry.Tile
			local unlocked = Formulas.IsItemUnlocked(data, item.Id)
			local equipped = unlocked and data.EquippedItem == item.Id
			local bonus = if item.Pass then best.Bonus * (1 + item.BetterBy) else item.Bonus
			tile.Title.Text = `+{NumberFormat.Abbreviate(bonus)}`
			tile.Corner.Text = if equipped then "✅" else ""
			if not item.Pass then
				tile.Button:SetColor(
					if equipped then Theme.Colors.Green elseif unlocked then Theme.Colors.Blue else Theme.Colors.GrayDark
				)
			end
			tile.Shade.Visible = not unlocked and not item.Pass
			if equipped then
				tile.BarText.Text = "EQUIPPED"
				tile.Bar.BackgroundColor3 = Theme.Colors.GreenDark
			elseif unlocked then
				tile.BarText.Text = "EQUIP"
				tile.Bar.BackgroundColor3 = Theme.Colors.BlueDark
			elseif item.Pass then
				tile.BarText.Text = `R$ {Config.Monetization.GamePasses[item.Pass].Price}`
				tile.Bar.BackgroundColor3 = Theme.Colors.Green
			else
				tile.BarText.Text = `🏆 {NumberFormat.Abbreviate(item.Wins)}`
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

return InventoryMenu
