--[[
	PetsMenu.luau
	Pet inventory as a grid of rarity-coloured tiles with live 3D previews and the Strength
	bonus. Click a tile to equip / unequip it (or delete it in delete mode); Equip Best picks
	your strongest pets. The grid is rebuilt only when the inventory changes.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Formulas = require(Shared.Formulas)
local NumberFormat = require(Shared.NumberFormat)

local ClientData = require(script.Parent.Parent.Parent.ClientData)
local ChunkyButton = require(script.Parent.Parent.ChunkyButton)
local Create = require(script.Parent.Parent.Create)
local MenuWindow = require(script.Parent.Parent.MenuWindow)
local Theme = require(script.Parent.Parent.Theme)
local ViewportPreview = require(script.Parent.Parent.ViewportPreview)

local PetsMenu = {}

local TILE = Vector2.new(110, 128)

function PetsMenu.new(parent: Instance, ctx: { [string]: any })
	local window = MenuWindow.new({ Title = "Pets", Icon = "🐶", Parent = parent })
	local deleteMode = false
	local tiles: { [string]: any } = {}
	local bonusTexts: { [string]: string } = {}
	local listDirty = true

	-- Toolbar: summary + Equip Best + Delete.
	local toolbar = Create("Frame", {
		Name = "Toolbar",
		LayoutOrder = 0,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -4, 0, 58),
		ZIndex = 2,
		Parent = window.Content,
	})
	local summary = Create.Label({
		Text = "",
		TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.fromOffset(4, 6),
		Size = UDim2.new(1, -330, 0, 26),
		StrokeThickness = 3,
		ZIndex = 3,
		Parent = toolbar,
	})
	local subSummary = Create.Label({
		Text = "",
		TextColor3 = Theme.Colors.Gold,
		TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.fromOffset(4, 34),
		Size = UDim2.new(1, -330, 0, 20),
		StrokeThickness = 2.5,
		ZIndex = 3,
		Parent = toolbar,
	})
	local bestButton = ChunkyButton.new({
		Text = "EQUIP BEST",
		Color = Theme.Colors.Blue,
		Size = UDim2.fromOffset(160, 54),
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -164, 0, 2),
		MaxTextSize = 22,
		Parent = toolbar,
	})
	bestButton.Activated:Connect(function()
		ctx.Request("EquipBestPets")
	end)
	local deleteButton = ChunkyButton.new({
		Text = "DELETE",
		Icon = "🗑️",
		Color = Theme.Colors.GrayDark,
		Size = UDim2.fromOffset(150, 54),
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -4, 0, 2),
		MaxTextSize = 22,
		Parent = toolbar,
	})

	local emptyLabel = Create.Label({
		Text = "No pets yet! Hatch eggs behind spawn with your Wins.",
		LayoutOrder = 1,
		Size = UDim2.new(1, -4, 0, 34),
		StrokeThickness = 3,
		ZIndex = 2,
		Visible = false,
		Parent = window.Content,
	})
	local grid = MenuWindow.Grid(window.Content, 2, TILE)

	local function refreshStates()
		local data = ClientData.Data
		if not data then
			return
		end
		local count = 0
		for _ in data.Pets do
			count += 1
		end
		summary.Text = `Equipped {#data.EquippedPets}/{Formulas.GetPetSlots(data)}`
		subSummary.Text =
			`{NumberFormat.Multiplier(1 + Formulas.GetEquippedPetBonus(data))} Strength  •  {count}/{Config.PetsConfig.MaxInventory} pets`
		emptyLabel.Visible = count == 0
		deleteButton:SetColor(if deleteMode then Theme.Colors.Red else Theme.Colors.GrayDark)

		for uid, tile in tiles do
			local equipped = table.find(data.EquippedPets, uid) ~= nil
			tile.Corner.Text = if equipped then "✅" else ""
			if deleteMode then
				tile.BarText.Text = "DELETE"
				tile.Bar.BackgroundColor3 = Theme.Colors.Red
			else
				tile.BarText.Text = bonusTexts[uid] or ""
				tile.Bar.BackgroundColor3 = if equipped then Theme.Colors.Green else Color3.fromRGB(40, 40, 48)
			end
		end
	end

	local function rebuild()
		listDirty = false
		for _, tile in tiles do
			tile.Button.Instance:Destroy()
		end
		table.clear(tiles)
		table.clear(bonusTexts)
		local data = ClientData.Data
		if not data then
			return
		end
		for order, uid in Formulas.GetBestPetUids(data, math.huge) do
			local petId = data.Pets[uid]
			local def = Config.Pets[petId]
			local rarity = Config.Rarities[def.Rarity]
			local tile = MenuWindow.Tile({
				Parent = grid,
				Order = order,
				Color = rarity.Color,
				Rainbow = def.Rarity == "Secret",
				Studs = false, -- up to 60 pets: keep the instance count down
				Title = def.Name,
				Bar = "",
			})
			ViewportPreview.Pet(tile.Art, petId, 1.35)
			bonusTexts[uid] = `+{NumberFormat.Percent(Formulas.GetPetBonus(data, petId))}`
			tile.Activated:Connect(function()
				local current = ClientData.Data
				if not current then
					return
				end
				if deleteMode then
					ctx.Request("DeletePet", uid)
				elseif table.find(current.EquippedPets, uid) then
					ctx.Request("UnequipPet", uid)
				else
					ctx.Request("EquipPet", uid)
				end
			end)
			tiles[uid] = tile
		end
		refreshStates()
	end

	deleteButton.Activated:Connect(function()
		deleteMode = not deleteMode
		refreshStates()
	end)

	ClientData.Changed:Connect(function(key)
		if key == "Pets" then
			listDirty = true
		end
		if not window.IsOpen then
			return
		end
		if listDirty then
			rebuild()
		elseif key == "EquippedPets" or key == "Passes" then
			refreshStates()
		end
	end)
	window.Instance:GetPropertyChangedSignal("Visible"):Connect(function()
		if window.Instance.Visible then
			if listDirty then
				rebuild()
			else
				refreshStates()
			end
		else
			deleteMode = false
		end
	end)
	return window
end

return PetsMenu
