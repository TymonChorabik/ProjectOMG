--[[
	UpgradesMenu.luau
	Coin upgrades: Iron Palms (+base power), Inner Focus (+crit), Golden Touch (+coins),
	Swift Strikes (faster Auto-Chop). Shows current → next effect for each level.
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

local UpgradesMenu = {}

local REFRESH_KEYS = { Coins = true, Upgrades = true, Rebirths = true }

-- Human-readable effect of an upgrade at a given level.
local function describe(upgradeId: string, level: number, data): string
	local probe = table.clone(data)
	probe.Upgrades = table.clone(data.Upgrades)
	probe.Upgrades[upgradeId] = level

	if upgradeId == "IronPalms" then
		return `{NumberFormat.Abbreviate(Formulas.GetBaseChopPower(probe))} base`
	elseif upgradeId == "Focus" then
		return NumberFormat.Percent(Formulas.GetCritChance(probe)) .. " crit"
	elseif upgradeId == "Greed" then
		return NumberFormat.Multiplier(Formulas.GetCoinMultiplier(probe)) .. " coins"
	elseif upgradeId == "Speed" then
		return string.format("%.2fs swing", Formulas.GetAutoChopInterval(probe))
	end
	return tostring(level)
end

function UpgradesMenu.new(parent: Instance, request: (string, string?) -> ())
	local window = MenuWindow.new({ Title = "Upgrades", Icon = "⬆️", Color = Theme.Colors.Green, Parent = parent })
	local cards = {}

	for index, upgrade in Config.Upgrades do
		local card = MenuWindow.Card(window.Content, index)
		card.Swatch.BackgroundColor3 = Theme.Colors.Cream
		Create.Label({
			Text = upgrade.Icon,
			Size = UDim2.fromScale(0.8, 0.8),
			Position = UDim2.fromScale(0.1, 0.1),
			Stroke = false,
			ZIndex = 4,
			Parent = card.Swatch,
		})
		card.Button.Activated:Connect(function()
			request("BuyUpgrade", upgrade.Id)
		end)
		cards[index] = card
	end

	local function refresh()
		local data = ClientData.Data
		if not data then
			return
		end
		for index, upgrade in Config.Upgrades do
			local card = cards[index]
			local level = Formulas.GetUpgradeLevel(data, upgrade.Id)
			local maxed = level >= upgrade.MaxLevel
			card.Title.Text = `{upgrade.Name}  Lv.{level}/{upgrade.MaxLevel}`
			card.Subtitle.Text = upgrade.Description

			if maxed then
				card.Info.Text = "Now: " .. describe(upgrade.Id, level, data)
				card.Button:SetText("MAXED")
				card.Button:SetColor(Theme.Colors.Gray)
				card.Button:SetEnabled(false)
			else
				local cost = Formulas.GetUpgradeCost(upgrade.Id, level)
				card.Info.Text = `{describe(upgrade.Id, level, data)}  ➜  {describe(upgrade.Id, level + 1, data)}`
				card.Button:SetText(`🪙 {NumberFormat.Abbreviate(cost)}`)
				card.Button:SetColor(if data.Coins >= cost then Theme.Colors.Green else Theme.Colors.GrayDark)
				card.Button:SetEnabled(true)
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

return UpgradesMenu
