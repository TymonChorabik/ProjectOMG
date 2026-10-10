--[[
	TrailsMenu.luau
	Trails bought with Wins: a coloured trail behind you plus extra walk speed.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local NumberFormat = require(Shared.NumberFormat)

local ClientData = require(script.Parent.Parent.Parent.ClientData)
local Create = require(script.Parent.Parent.Create)
local MenuWindow = require(script.Parent.Parent.MenuWindow)
local Theme = require(script.Parent.Parent.Theme)

local TrailsMenu = {}

local REFRESH_KEYS = { Wins = true, OwnedTrails = true, EquippedTrail = true }

function TrailsMenu.new(parent: Instance, ctx: { [string]: any })
	local window = MenuWindow.new({ Title = "Trails", Icon = "✨", Color = Theme.Colors.Purple, Parent = parent })

	local noneCard = MenuWindow.Card(window.Content, 0, 76)
	noneCard.Swatch.BackgroundColor3 = Theme.Colors.GrayDark
	noneCard.Title.Text = "No Trail"
	noneCard.Subtitle.Text = `Walk speed {Config.BaseWalkSpeed}`
	noneCard.Info.Text = ""
	noneCard.Button.Activated:Connect(function()
		ctx.Request("EquipTrail", "None")
	end)

	local cards = {}
	for order, trail in Config.Trails do
		local card = MenuWindow.Card(window.Content, order, 88)
		card.Swatch.BackgroundColor3 = Color3.new(1, 1, 1)
		local gradient = if trail.Rainbow
			then ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 60, 60)),
				ColorSequenceKeypoint.new(0.33, Color3.fromRGB(255, 220, 60)),
				ColorSequenceKeypoint.new(0.66, Color3.fromRGB(80, 220, 120)),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(80, 120, 255)),
			})
			else ColorSequence.new(trail.Colors[1], trail.Colors[2])
		Create("UIGradient", { Color = gradient, Rotation = 45, Parent = card.Swatch })
		card.Title.Text = trail.Name
		card.Subtitle.Text = `+{trail.Speed} walk speed`
		card.Button.Activated:Connect(function()
			ctx.Request("BuyTrail", trail.Id)
		end)
		cards[order] = card
	end

	local function refresh()
		local data = ClientData.Data
		if not data then
			return
		end
		local none = data.EquippedTrail == "None"
		noneCard.Button:SetText(if none then "EQUIPPED" else "UNEQUIP")
		noneCard.Button:SetColor(if none then Theme.Colors.Gray else Theme.Colors.Blue)
		noneCard.Button:SetEnabled(not none)
		for order, trail in Config.Trails do
			local card = cards[order]
			local owned = data.OwnedTrails[trail.Id] == true
			card.Info.Text = if owned then "Owned" else `Costs {NumberFormat.Abbreviate(trail.Cost)} Wins`
			if owned and data.EquippedTrail == trail.Id then
				card.Button:SetText("EQUIPPED")
				card.Button:SetColor(Theme.Colors.Gray)
				card.Button:SetEnabled(false)
			elseif owned then
				card.Button:SetText("EQUIP")
				card.Button:SetColor(Theme.Colors.Blue)
				card.Button:SetEnabled(true)
			else
				card.Button:SetText(`🏆 {NumberFormat.Abbreviate(trail.Cost)}`)
				card.Button:SetColor(if data.Wins >= trail.Cost then Theme.Colors.Green else Theme.Colors.GrayDark)
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

return TrailsMenu
