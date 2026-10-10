--[[
	TrailsMenu.luau
	Trails bought with Wins (a coloured trail behind you plus extra walk speed), as studded
	tiles in the trail's own colours.
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

local TILE = Vector2.new(140, 158)
local REFRESH_KEYS = { Wins = true, OwnedTrails = true, EquippedTrail = true }

-- Trail preview: a streak in the trail's colours with the speed bonus on top.
local function streak(art: Frame, trail)
	local bar = Create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, -6, 0, 30),
		Rotation = -14,
		BackgroundColor3 = Color3.new(1, 1, 1),
		ZIndex = 4,
		Parent = art,
	}, { Create.Corner(UDim.new(1, 0)), Create.Stroke(3) })
	Create("UIGradient", {
		Color = if trail.Rainbow then Theme.Rainbow else ColorSequence.new(trail.Colors[1], trail.Colors[2]),
		Parent = bar,
	})
	Create.Label({
		Text = `+{trail.Speed} SPEED`,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 1),
		Size = UDim2.new(1, 0, 0, 22),
		StrokeThickness = 2.5,
		ZIndex = 5,
		Parent = art,
	})
end

function TrailsMenu.new(parent: Instance, ctx: { [string]: any })
	local window = MenuWindow.new({ Title = "Trails", Icon = "☄️", Parent = parent })
	local grid = MenuWindow.Grid(window.Content, 1, TILE)

	local noneTile = MenuWindow.Tile({
		Parent = grid,
		Order = 0,
		Color = Theme.Colors.GrayDark,
		Title = "NO TRAIL",
		Icon = "🚫",
		Bar = "",
	})
	noneTile.Activated:Connect(function()
		ctx.Request("EquipTrail", "None")
	end)

	local tiles = {}
	for order, trail in Config.Trails do
		local tile = MenuWindow.Tile({
			Parent = grid,
			Order = order,
			Color = trail.Colors[2],
			Rainbow = trail.Rainbow,
			Title = string.upper(trail.Name),
			Bar = "",
		})
		streak(tile.Art, trail)
		tile.Activated:Connect(function()
			ctx.Request("BuyTrail", trail.Id)
		end)
		tiles[order] = tile
	end

	local function refresh()
		local data = ClientData.Data
		if not data then
			return
		end
		local none = data.EquippedTrail == "None"
		noneTile.BarText.Text = if none then "EQUIPPED" else "UNEQUIP"
		noneTile.Bar.BackgroundColor3 = if none then Theme.Colors.GreenDark else Theme.Colors.BlueDark
		noneTile.Corner.Text = if none then "✅" else ""
		for order, trail in Config.Trails do
			local tile = tiles[order]
			local owned = data.OwnedTrails[trail.Id] == true
			local equipped = owned and data.EquippedTrail == trail.Id
			tile.Corner.Text = if equipped then "✅" else ""
			if equipped then
				tile.BarText.Text = "EQUIPPED"
				tile.Bar.BackgroundColor3 = Theme.Colors.GreenDark
			elseif owned then
				tile.BarText.Text = "EQUIP"
				tile.Bar.BackgroundColor3 = Theme.Colors.BlueDark
			else
				tile.BarText.Text = `🏆 {NumberFormat.Abbreviate(trail.Cost)}`
				tile.Bar.BackgroundColor3 = if data.Wins >= trail.Cost then Theme.Colors.Green else Theme.Colors.Red
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
