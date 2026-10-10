--[[
	PetsMenu.luau
	Pet inventory: equip / unequip, Equip Best, delete mode. Pets show as live 3D previews.
	The list is rebuilt only when the inventory changes; equip states refresh in place.
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

function PetsMenu.new(parent: Instance, ctx: { [string]: any })
	local window =
		MenuWindow.new({ Title = "Pets", Icon = "🐾", Color = Color3.fromRGB(255, 160, 60), Parent = parent })
	local deleteMode = false
	local cards: { [string]: any } = {}
	local listDirty = true

	-- Toolbar.
	local toolbar = Create("Frame", {
		Name = "Toolbar",
		LayoutOrder = 0,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -6, 0, 66),
		ZIndex = 2,
		Parent = window.Content,
	})
	local summary = Create.Label({
		Text = "",
		TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.new(1, -330, 1, -16),
		Position = UDim2.fromOffset(6, 8),
		ZIndex = 3,
		Parent = toolbar,
	})
	local bestButton = ChunkyButton.new({
		Text = "EQUIP BEST",
		Color = Theme.Colors.Blue,
		Font = Theme.Fonts.Title,
		Size = UDim2.fromOffset(150, 58),
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -168, 0, 2),
		MaxTextSize = 22,
		Parent = toolbar,
	})
	bestButton.Activated:Connect(function()
		ctx.Request("EquipBestPets")
	end)
	local deleteButton = ChunkyButton.new({
		Text = "🗑 DELETE",
		Color = Theme.Colors.GrayDark,
		Font = Theme.Fonts.Title,
		Size = UDim2.fromOffset(150, 58),
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -8, 0, 2),
		MaxTextSize = 22,
		Parent = toolbar,
	})

	local emptyLabel = Create.Label({
		Text = "No pets yet! Hatch eggs behind spawn with your Wins.",
		LayoutOrder = 1,
		Size = UDim2.new(1, -6, 0, 40),
		ZIndex = 2,
		Visible = false,
		Parent = window.Content,
	})

	local function refreshStates()
		local data = ClientData.Data
		if not data then
			return
		end
		local count = 0
		for _ in data.Pets do
			count += 1
		end
		local multiplier = NumberFormat.Multiplier(1 + Formulas.GetEquippedPetBonus(data))
		summary.Text =
			`Equipped {#data.EquippedPets}/{Formulas.GetPetSlots(data)}  •  Pets {multiplier}  •  {count}/{Config.PetsConfig.MaxInventory}`
		emptyLabel.Visible = count == 0
		deleteButton:SetColor(if deleteMode then Theme.Colors.Red else Theme.Colors.GrayDark)

		for uid, card in cards do
			local equipped = table.find(data.EquippedPets, uid) ~= nil
			if deleteMode then
				card.Button:SetText("DELETE")
				card.Button:SetColor(Theme.Colors.Red)
			elseif equipped then
				card.Button:SetText("UNEQUIP")
				card.Button:SetColor(Theme.Colors.Gray)
			else
				card.Button:SetText("EQUIP")
				card.Button:SetColor(Theme.Colors.Green)
			end
			card.Frame.BackgroundColor3 = if equipped then Color3.fromRGB(70, 110, 60) else Theme.Colors.Card
		end
	end

	local function rebuild()
		listDirty = false
		for _, card in cards do
			card.Frame:Destroy()
		end
		table.clear(cards)
		local data = ClientData.Data
		if not data then
			return
		end
		local uids = Formulas.GetBestPetUids(data, math.huge)
		for order, uid in uids do
			local petId = data.Pets[uid]
			local def = Config.Pets[petId]
			local card = MenuWindow.Card(window.Content, 10 + order, 92)
			card.Swatch.BackgroundColor3 = Color3.fromRGB(225, 240, 255)
			ViewportPreview.Pet(card.Swatch, petId)
			card.Title.Text = def.Name
			card.Title.TextColor3 = Config.Rarities[def.Rarity].Color
			card.Subtitle.Text = def.Rarity
			card.Info.Text = `+{NumberFormat.Percent(Formulas.GetPetBonus(data, petId))} Strength`
			card.Button.Activated:Connect(function()
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
			cards[uid] = card
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
