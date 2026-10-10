--[[
	TrailsMenu.luau
	Trails bought with Wins (a coloured trail behind you plus extra walk speed), laid out like
	+1 Stone Skipping's: one full-width studded card per trail in its own colour, with a preview
	on the left, the name and bonus in the middle and the price / Equip button on the right.
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

local CARD_HEIGHT = 116
local REFRESH_KEYS = { Wins = true, OwnedTrails = true, EquippedTrail = true }

-- Dark rounded box on the left of a card holding the preview.
local function artBox(card: Frame): Frame
	return Create("Frame", {
		Name = "Art",
		BackgroundColor3 = Color3.fromRGB(20, 20, 28),
		BackgroundTransparency = 0.35,
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 12, 0.5, 0),
		Size = UDim2.fromOffset(150, CARD_HEIGHT - 24),
		ZIndex = 4,
		Parent = card,
	}, { Create.Corner(UDim.new(0, 12)), Create.Stroke(3) })
end

-- Trail preview: a glowing streak in the trail's colours.
local function streak(art: Frame, trail)
	local bar = Create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, -20, 0, 30),
		Rotation = -16,
		BackgroundColor3 = Color3.new(1, 1, 1),
		ZIndex = 5,
		Parent = art,
	}, { Create.Corner(UDim.new(1, 0)), Create.Stroke(3) })
	Create("UIGradient", {
		Color = if trail.Rainbow then Theme.Rainbow else ColorSequence.new(trail.Colors[1], trail.Colors[2]),
		Parent = bar,
	})
	Create.Icon({
		Text = "✨",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(1, -18, 0, 20),
		Size = UDim2.fromOffset(30, 30),
		ZIndex = 6,
		Parent = art,
	})
end

local function card(parent: Instance, order: number, color: Color3, rainbow: boolean?, title: string, stat: string)
	local frame = MenuWindow.Card({
		Parent = parent,
		Order = order,
		Size = UDim2.new(1, -8, 0, CARD_HEIGHT),
		Color = color,
		Rainbow = rainbow,
	})
	local art = artBox(frame)
	Create.Label({
		Name = "Name",
		Text = title,
		TextColor3 = Theme.Colors.Cream,
		TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.fromOffset(180, 12),
		Size = UDim2.new(1, -380, 0, 50),
		StrokeThickness = 4.5,
		MaxTextSize = 46,
		ZIndex = 6,
		Parent = frame,
	})
	Create.Label({
		Name = "Stat",
		Text = stat,
		TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.fromOffset(180, 62),
		Size = UDim2.new(1, -380, 0, 36),
		StrokeThickness = 3.5,
		MaxTextSize = 30,
		ZIndex = 6,
		Parent = frame,
	})
	local button = MenuWindow.PriceButton({
		Parent = frame,
		Text = "",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -16, 0.5, -2),
		Size = UDim2.fromOffset(180, 66),
		MaxTextSize = 32,
	})
	return art, button
end

function TrailsMenu.new(parent: Instance, ctx: { [string]: any })
	local window = MenuWindow.new({ Title = "Trails", Icon = "☄️", Size = Vector2.new(760, 540), Parent = parent })

	local noneArt, noneButton = card(window.Content, 0, Theme.Colors.GrayDark, false, "No Trail", "Just your fists")
	Create.Icon({ Text = "🚫", Size = UDim2.fromScale(1, 1), ZIndex = 5, Parent = noneArt })
	noneButton.Activated:Connect(function()
		ctx.Request("EquipTrail", "None")
	end)

	local buttons = {}
	for order, trail in Config.Trails do
		local art, button =
			card(window.Content, order, trail.Colors[2], trail.Rainbow, trail.Name, `+{trail.Speed} Walk Speed`)
		streak(art, trail)
		button.Activated:Connect(function()
			ctx.Request("BuyTrail", trail.Id)
		end)
		buttons[order] = button
	end

	local function refresh()
		local data = ClientData.Data
		if not data then
			return
		end
		local none = data.EquippedTrail == "None"
		noneButton:SetText(if none then "Equipped" else "Equip")
		noneButton:SetColor(if none then Theme.Colors.GrayDark else Theme.Colors.Blue)
		for order, trail in Config.Trails do
			local button = buttons[order]
			local owned = data.OwnedTrails[trail.Id] == true
			if owned and data.EquippedTrail == trail.Id then
				button:SetText("Equipped")
				button:SetColor(Theme.Colors.GrayDark)
			elseif owned then
				button:SetText("Equip")
				button:SetColor(Theme.Colors.Blue)
			else
				button:SetText(`🏆 {NumberFormat.Abbreviate(trail.Cost)}`)
				button:SetColor(if data.Wins >= trail.Cost then Theme.Colors.Green else Theme.Colors.Red)
			end
		end
	end

	ClientData.Changed:Connect(function(key)
		if REFRESH_KEYS[key] and window.IsOpen then
			refresh()
		end
	end)
	window.Opened:Connect(refresh)
	refresh()
	return window
end

return TrailsMenu
