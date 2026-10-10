--[[
	InventoryMenu.luau
	"My Pets" window in the +1 Stone Skipping style, with big tabs down the left edge:
	  🥊 Hands   hand items (the game's "stones"): unlocked by lifetime Wins, equip one
	  🐾 Pets    pet inventory: equip / delete, Equip Best, more slots
	  🧪 Boosts  timed 2x boosts: time left, buy more
	Every tab has the same layout: a count line on top, an info panel for the selected entry on
	the left, a dark grid on the right and action buttons along the bottom.

	UIController opens a tab with window:SetTab(name); window.Tab is the current one.
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
local StudPanel = require(script.Parent.Parent.StudPanel)
local Theme = require(script.Parent.Parent.Theme)
local ViewportPreview = require(script.Parent.Parent.ViewportPreview)

local InventoryMenu = {}

local TEAL = Color3.fromRGB(30, 200, 190)
local GRID_COLOR = Color3.fromRGB(20, 20, 26)
local INFO_COLOR = Color3.fromRGB(70, 70, 84)
local INFO_WIDTH = 236
local CELL = Vector2.new(96, 106)
local TOP = 52 -- grid / info panel start below the count line
local BOTTOM = 72 -- action bar height

local TABS = {
	{ Name = "Hands", Title = "My Hands", Icon = "🥊" },
	{ Name = "Pets", Title = "My Pets", Icon = "🐾" },
	{ Name = "Boosts", Title = "My Boosts", Icon = "🧪" },
}

local BOOSTS = {
	{ Kind = "Strength", Product = "BoostStrength", Text = "Doubles the Strength you train" },
	{ Kind = "Wins", Product = "BoostWins", Text = "Doubles the Wins from every run" },
	{ Kind = "Luck", Product = "BoostLuck", Text = "Rarer pets from every egg" },
}

local function formatTime(seconds: number): string
	seconds = math.max(0, math.ceil(seconds))
	if seconds >= 3600 then
		return string.format("%d:%02d:%02d", seconds // 3600, (seconds // 60) % 60, seconds % 60)
	end
	return string.format("%02d:%02d", seconds // 60, seconds % 60)
end

local function label(parent: Instance, props: { [string]: any }): TextLabel
	props.Parent = parent
	props.ZIndex = props.ZIndex or 6
	props.StrokeThickness = props.StrokeThickness or 3.5
	return Create.Label(props)
end

local function button(parent: Instance, props: { [string]: any })
	props.Parent = parent
	props.StrokeThickness = props.StrokeThickness or 3.5
	local new = ChunkyButton.new(props)
	new.Instance.ZIndex = 6
	return new
end

-- White outline around the selected cell.
local function setSelected(tile, selected: boolean)
	local stroke = tile.Face:FindFirstChildOfClass("UIStroke")
	if stroke then
		stroke.Color = if selected then Color3.new(1, 1, 1) else Theme.Colors.Ink
		stroke.Thickness = if selected then 4.5 else Theme.StrokeThickness
	end
end

-- A grid cell: bonus on top, 3D preview / icon filling the rest, tick in the corner.
local function cell(parent: Instance, order: number, color: Color3, rainbow: boolean?, studs: boolean?)
	local tile = MenuWindow.Tile({
		Parent = parent,
		Order = order,
		Color = color,
		Rainbow = rainbow,
		Studs = studs,
		Title = "",
		Bar = "",
	})
	tile.Bar.Visible = false
	tile.Art.Position = UDim2.new(0.5, 0, 0, 26)
	tile.Art.Size = UDim2.new(1, -10, 1, -32)
	tile.Corner.AnchorPoint = Vector2.new(1, 1)
	tile.Corner.Position = UDim2.new(1, -3, 1, -3)
	return tile
end

-- The shared tab layout: count line, info panel, dark grid, action bar.
local function scaffold(body: Instance, name: string)
	local page = Create("Frame", {
		Name = name,
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Visible = false,
		ZIndex = 2,
		Parent = body,
	})
	local count = label(page, {
		Text = "",
		TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.fromOffset(6, 2),
		Size = UDim2.new(0.5, 0, 0, 44),
		StrokeThickness = 4,
		MaxTextSize = 36,
		ZIndex = 3,
	})

	local info = StudPanel.new({
		Name = "Info",
		Size = UDim2.new(0, INFO_WIDTH, 1, -(TOP + BOTTOM)),
		Position = UDim2.fromOffset(0, TOP),
		Color = INFO_COLOR,
		StrokeThickness = 3.5,
		ZIndex = 3,
		Parent = page,
	})
	local art = Create("Frame", {
		Name = "Art",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 8),
		Size = UDim2.fromOffset(150, 140),
		ZIndex = 5,
		Parent = info,
	})
	local icon = Create.Icon({
		Text = "",
		Size = UDim2.fromScale(1, 1),
		ZIndex = 6,
		Parent = art,
	})
	local title = label(info, {
		Text = "",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 150),
		Size = UDim2.new(1, -16, 0, 34),
		StrokeThickness = 4,
		MaxTextSize = 30,
	})
	local sub = label(info, {
		Text = "",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 184),
		Size = UDim2.new(1, -16, 0, 24),
		StrokeThickness = 3,
		MaxTextSize = 22,
	})
	local stat = label(info, {
		Text = "",
		TextColor3 = Theme.Colors.Gold,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 210),
		Size = UDim2.new(1, -16, 0, 30),
		MaxTextSize = 26,
	})
	local hint = label(info, {
		Text = "",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.45),
		Size = UDim2.new(1, -30, 0, 90),
		StrokeThickness = 3,
		MaxTextSize = 26,
		Visible = false,
	})
	local primary = button(info, {
		Text = "Equip",
		Color = Theme.Colors.Green,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 10, 1, -10),
		Size = UDim2.new(1, -20, 0, 54),
		MaxTextSize = 30,
	})

	local gridHolder = Create("Frame", {
		Name = "GridHolder",
		BackgroundColor3 = GRID_COLOR,
		BackgroundTransparency = 0.45,
		Position = UDim2.fromOffset(INFO_WIDTH + 12, TOP),
		Size = UDim2.new(1, -(INFO_WIDTH + 12), 1, -(TOP + BOTTOM)),
		ZIndex = 3,
		Parent = page,
	}, { Create.Corner(UDim.new(0, 14)), Create.Stroke(3.5) })
	local grid = Create("ScrollingFrame", {
		Name = "Grid",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(4, 4),
		Size = UDim2.new(1, -8, 1, -8),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 6,
		ScrollBarImageTransparency = 0.3,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ZIndex = 4,
		Parent = gridHolder,
	}, {
		Create("UIGridLayout", {
			CellSize = UDim2.fromOffset(CELL.X, CELL.Y),
			CellPadding = UDim2.fromOffset(8, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		Create("UIPadding", {
			PaddingTop = UDim.new(0, 8),
			PaddingBottom = UDim.new(0, 8),
			PaddingLeft = UDim.new(0, 8),
			PaddingRight = UDim.new(0, 8),
		}),
	})
	local empty = label(gridHolder, {
		Text = "",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, -60, 0, 90),
		TextColor3 = Theme.Colors.Cream,
		StrokeThickness = 3,
		MaxTextSize = 28,
		Visible = false,
	})

	local actions = Create("Frame", {
		Name = "Actions",
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 0, 1, -(BOTTOM - 10)),
		Size = UDim2.new(1, 0, 0, BOTTOM - 10),
		ZIndex = 3,
		Parent = page,
	}, {
		Create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, 12),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	local summary = label(page, {
		Text = "",
		TextColor3 = Theme.Colors.Gold,
		TextXAlignment = Enum.TextXAlignment.Right,
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -4, 1, -12),
		Size = UDim2.new(1, -420, 0, 40), -- tabs with fewer buttons widen it
		StrokeThickness = 3.5,
		MaxTextSize = 30,
		ZIndex = 3,
	})

	return {
		Page = page,
		Count = count,
		Info = info,
		Art = art,
		Icon = icon,
		Title = title,
		Sub = sub,
		Stat = stat,
		Hint = hint,
		Primary = primary,
		Grid = grid,
		Empty = empty,
		Actions = actions,
		Summary = summary,
	}
end

-- Shows a 3D preview in the info panel (rebuilt only when the shown thing changes).
local function showArt(ui, key: string?, build: (() -> ())?)
	if ui.ArtKey == key then
		return
	end
	ui.ArtKey = key
	for _, child in ui.Art:GetChildren() do
		if child:IsA("ViewportFrame") then
			child:Destroy()
		end
	end
	ui.Icon.Text = ""
	if build then
		build()
	end
end

local function setInfoVisible(ui, visible: boolean)
	ui.Art.Visible = visible
	ui.Title.Visible = visible
	ui.Sub.Visible = visible
	ui.Stat.Visible = visible
	ui.Primary.Instance.Visible = visible
	ui.Hint.Visible = not visible
end

--------------------------------------------------------------------------------
-- 🥊 Hands
--------------------------------------------------------------------------------

local function handsTab(body: Instance, ctx: { [string]: any })
	local ui = scaffold(body, "Hands")
	local items = table.clone(Config.HandItems)
	table.insert(items, 1, Config.PremiumItem)
	local cells = {}
	local selected: string? = nil

	local function itemBonus(data, item): number
		if item.Pass then
			return Formulas.GetBestUnlockedItem(data).Bonus * (1 + item.BetterBy)
		end
		return item.Bonus
	end

	local function bestItem(data)
		if Formulas.HasPass(data, Config.PremiumItem.Pass) then
			return Config.PremiumItem
		end
		return Formulas.GetBestUnlockedItem(data)
	end

	local refresh: () -> ()
	for order, item in items do
		local tile = cell(ui.Grid, order, Theme.Colors.Blue, item.Pass ~= nil)
		ViewportPreview.Item(tile.Art, item, 1.35)
		tile.Activated:Connect(function()
			selected = item.Id
			refresh()
		end)
		cells[item.Id] = { Item = item, Tile = tile }
	end

	local equipBest = button(ui.Actions, {
		Text = "Equip Best",
		Color = Theme.Colors.Green,
		Size = UDim2.fromOffset(200, 58),
		MaxTextSize = 30,
		LayoutOrder = 1,
	})
	equipBest.Activated:Connect(function()
		local data = ClientData.Data
		if data then
			ctx.Request("EquipItem", bestItem(data).Id)
		end
	end)
	ui.Summary.Size = UDim2.new(1, -224, 0, 40)

	ui.Primary.Activated:Connect(function()
		local data = ClientData.Data
		local entry = selected and cells[selected]
		if not data or not entry then
			return
		end
		local item = entry.Item
		if item.Pass and not Formulas.HasPass(data, item.Pass) then
			ctx.Purchase("pass:" .. item.Pass)
		elseif Formulas.IsItemUnlocked(data, item.Id) then
			ctx.Request("EquipItem", item.Id)
		end
	end)

	refresh = function()
		local data = ClientData.Data
		if not data then
			return
		end
		selected = selected or data.EquippedItem
		local unlockedCount = 0
		for _, entry in cells do
			local item, tile = entry.Item, entry.Tile
			local owned = if item.Pass then Formulas.HasPass(data, item.Pass) else true
			local unlocked = owned and Formulas.IsItemUnlocked(data, item.Id)
			local equipped = unlocked and data.EquippedItem == item.Id
			if unlocked and not item.Pass then
				unlockedCount += 1
			end
			tile.Title.Text = `+{NumberFormat.Abbreviate(itemBonus(data, item))}`
			tile.Corner.Text = if equipped then "✅" elseif not unlocked and not item.Pass then "🔒" else ""
			if not item.Pass then
				tile.Button:SetColor(if unlocked then Theme.Colors.Blue else Theme.Colors.GrayDark)
			end
			tile.Shade.Visible = not unlocked and not item.Pass
			setSelected(tile, item.Id == selected)
		end
		ui.Count.Text = `⚡ +{NumberFormat.Abbreviate(Formulas.GetItemBonus(data))} per chop`
		local nextItem = Formulas.GetNextItem(data)
		ui.Summary.Text = if nextItem
			then `Next: {nextItem.Name}  🏆 {NumberFormat.Abbreviate(nextItem.Wins)}`
			else `{unlockedCount} / {#Config.HandItems} unlocked`

		local entry = selected and cells[selected]
		setInfoVisible(ui, entry ~= nil)
		if not entry then
			return
		end
		local item = entry.Item
		local owned = if item.Pass then Formulas.HasPass(data, item.Pass) else true
		local unlocked = owned and Formulas.IsItemUnlocked(data, item.Id)
		local equipped = unlocked and data.EquippedItem == item.Id
		showArt(ui, item.Id, function()
			ViewportPreview.Item(ui.Art, item, 1.1)
		end)
		ui.Title.Text = item.Name
		ui.Stat.Text = `+{NumberFormat.Abbreviate(itemBonus(data, item))} Strength`
		if item.Pass then
			ui.Sub.Text = `+{NumberFormat.Percent(item.BetterBy)} over your best`
			ui.Sub.TextColor3 = Theme.Colors.Pink
		elseif unlocked then
			ui.Sub.Text = "Unlocked"
			ui.Sub.TextColor3 = Theme.Colors.GreenText
		else
			ui.Sub.Text = `🔒 Reach 🏆 {NumberFormat.Abbreviate(item.Wins)} Wins`
			ui.Sub.TextColor3 = Color3.fromRGB(255, 110, 110)
		end
		if equipped then
			ui.Primary:SetText("Equipped")
			ui.Primary:SetColor(Theme.Colors.GrayDark)
		elseif item.Pass and not owned then
			ui.Primary:SetText(`R$ {Config.Monetization.GamePasses[item.Pass].Price}`)
			ui.Primary:SetColor(Theme.Colors.Green)
		elseif unlocked then
			ui.Primary:SetText("Equip")
			ui.Primary:SetColor(Theme.Colors.Green)
		else
			ui.Primary:SetText("🔒 Locked")
			ui.Primary:SetColor(Theme.Colors.GrayDark)
		end
	end

	return {
		Page = ui.Page,
		Refresh = refresh,
		Keys = { TotalWins = true, EquippedItem = true, Passes = true },
	}
end

--------------------------------------------------------------------------------
-- 🐾 Pets
--------------------------------------------------------------------------------

local function petsTab(body: Instance, ctx: { [string]: any })
	local ui = scaffold(body, "Pets")
	local cells: { [string]: any } = {}
	local selected: string? = nil
	local deleteMode = false
	local dirty = true
	ui.Empty.Text = "No pets yet!\nHatch eggs behind spawn with your Wins."
	ui.Hint.Text = "Click a pet to see it here"

	-- "Equipped: 3 / 3" with a green + for more slots, top right.
	local equippedLabel = label(ui.Page, {
		Text = "",
		TextXAlignment = Enum.TextXAlignment.Right,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -62, 0, 2),
		Size = UDim2.new(0.45, 0, 0, 44),
		StrokeThickness = 4,
		MaxTextSize = 34,
		ZIndex = 3,
	})
	local moreSlots = button(ui.Page, {
		Text = "+",
		Color = Theme.Colors.Green,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -4, 0, 0),
		Size = UDim2.fromOffset(50, 50),
		MaxTextSize = 40,
	})
	moreSlots.Activated:Connect(function()
		ctx.Purchase("pass:" .. Config.PetsConfig.ExtraSlotsPass)
	end)

	-- Delete sits next to Equip in the info panel.
	ui.Primary.Instance.Size = UDim2.new(1, -86, 0, 54)
	local deleteOne = button(ui.Info, {
		Text = "🗑️",
		Color = Theme.Colors.Red,
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -10, 1, -10),
		Size = UDim2.fromOffset(62, 54),
		MaxTextSize = 30,
	})

	local deleteButton = button(ui.Actions, {
		Text = "Delete",
		Icon = "🗑️",
		Color = Theme.Colors.GrayDark,
		Size = UDim2.fromOffset(170, 58),
		MaxTextSize = 28,
		LayoutOrder = 1,
	})
	local equipBest = button(ui.Actions, {
		Text = "Equip Best",
		Color = Theme.Colors.Green,
		Size = UDim2.fromOffset(200, 58),
		MaxTextSize = 30,
		LayoutOrder = 2,
	})
	equipBest.Activated:Connect(function()
		ctx.Request("EquipBestPets")
	end)

	local refreshStates: () -> ()

	local function rebuild()
		dirty = false
		for _, tile in cells do
			tile.Button.Instance:Destroy()
		end
		table.clear(cells)
		local data = ClientData.Data
		if not data then
			return
		end
		for order, uid in Formulas.GetBestPetUids(data, math.huge) do
			local petId = data.Pets[uid]
			local def = Config.Pets[petId]
			local tile = cell(ui.Grid, order, Config.Rarities[def.Rarity].Color, def.Rarity == "Secret", false)
			ViewportPreview.Pet(tile.Art, petId, 1.35)
			tile.Activated:Connect(function()
				if deleteMode then
					ctx.Request("DeletePet", uid)
				else
					selected = uid
					refreshStates()
				end
			end)
			cells[uid] = tile
		end
		if selected and not data.Pets[selected] then
			selected = nil
		end
		-- Show something right away: your best equipped pet.
		selected = selected or data.EquippedPets[1] or Formulas.GetBestPetUids(data, 1)[1]
		refreshStates()
	end

	refreshStates = function()
		local data = ClientData.Data
		if not data then
			return
		end
		local count = 0
		for _ in data.Pets do
			count += 1
		end
		local slots = Formulas.GetPetSlots(data)
		ui.Count.Text = `🎒 {count} / {Config.PetsConfig.MaxInventory}`
		equippedLabel.Text = `Equipped: {#data.EquippedPets} / {slots}`
		moreSlots.Instance.Visible = not Formulas.HasPass(data, Config.PetsConfig.ExtraSlotsPass)
		equippedLabel.Position = UDim2.new(1, if moreSlots.Instance.Visible then -62 else -4, 0, 2)
		ui.Summary.Text = `{NumberFormat.Multiplier(1 + Formulas.GetEquippedPetBonus(data))} Strength`
		ui.Empty.Visible = count == 0
		deleteButton:SetColor(if deleteMode then Theme.Colors.Red else Theme.Colors.GrayDark)
		deleteButton:SetText(if deleteMode then "Done" else "Delete")

		for uid, tile in cells do
			local equipped = table.find(data.EquippedPets, uid) ~= nil
			tile.Title.Text = if deleteMode
				then "DELETE"
				else `+{NumberFormat.Percent(Formulas.GetPetBonus(data, data.Pets[uid]))}`
			tile.Corner.Text = if equipped then "✅" else ""
			tile.Shade.Visible = deleteMode and not equipped
			setSelected(tile, uid == selected)
		end

		local petId = selected and data.Pets[selected]
		setInfoVisible(ui, petId ~= nil)
		deleteOne.Instance.Visible = petId ~= nil
		if not petId then
			showArt(ui, nil)
			return
		end
		local def = Config.Pets[petId]
		local equipped = table.find(data.EquippedPets, selected) ~= nil
		showArt(ui, selected, function()
			ViewportPreview.Pet(ui.Art, petId, 1.1)
		end)
		ui.Title.Text = def.Name
		ui.Sub.Text = def.Rarity
		ui.Sub.TextColor3 = Config.Rarities[def.Rarity].Color
		ui.Stat.Text = `+{NumberFormat.Percent(Formulas.GetPetBonus(data, petId))} Strength`
		ui.Primary:SetText(if equipped then "Unequip" else "Equip")
		ui.Primary:SetColor(if equipped then Theme.Colors.Red else Theme.Colors.Green)
	end

	ui.Primary.Activated:Connect(function()
		local data = ClientData.Data
		if not data or not selected or not data.Pets[selected] then
			return
		end
		ctx.Request(if table.find(data.EquippedPets, selected) then "UnequipPet" else "EquipPet", selected)
	end)
	deleteOne.Activated:Connect(function()
		if selected then
			ctx.Request("DeletePet", selected)
		end
	end)
	deleteButton.Activated:Connect(function()
		deleteMode = not deleteMode
		refreshStates()
	end)

	return {
		Page = ui.Page,
		Refresh = function()
			if dirty then
				rebuild()
			else
				refreshStates()
			end
		end,
		Keys = { Pets = true, EquippedPets = true, Passes = true },
		OnChanged = function(key: string)
			if key == "Pets" then
				dirty = true
			end
		end,
		OnClosed = function()
			deleteMode = false
		end,
	}
end

--------------------------------------------------------------------------------
-- 🧪 Boosts
--------------------------------------------------------------------------------

local function boostsTab(body: Instance, ctx: { [string]: any })
	local ui = scaffold(body, "Boosts")
	local cells = {}
	local selected = BOOSTS[1]
	local products = Config.Monetization.Products

	local refresh: () -> ()
	for order, boost in BOOSTS do
		local def = Config.Boosts[boost.Kind]
		local tile = cell(ui.Grid, order, def.Color)
		tile.Icon.Text = def.Icon
		tile.Art.Position = UDim2.new(0.5, 0, 0, 6)
		tile.Art.Size = UDim2.new(1, -16, 1, -50)
		tile.Bar.Visible = true
		tile.Activated:Connect(function()
			selected = boost
			refresh()
		end)
		cells[boost.Kind] = tile
	end

	local bundle = products.BoostBundle
	local bundleButton = button(ui.Actions, {
		Text = `{bundle.Name}  R$ {bundle.Price}`,
		Rainbow = true,
		Size = UDim2.fromOffset(330, 58),
		MaxTextSize = 28,
		LayoutOrder = 1,
	})
	bundleButton.Activated:Connect(function()
		ctx.Purchase("product:BoostBundle")
	end)
	ui.Summary.Text = "Free boosts in 🎁 Gifts & codes!"
	ui.Summary.TextColor3 = Theme.Colors.Cream
	ui.Summary.Size = UDim2.new(1, -350, 0, 40)

	ui.Primary.Activated:Connect(function()
		ctx.Purchase("product:" .. selected.Product)
	end)

	refresh = function()
		local data = ClientData.Data
		if not data then
			return
		end
		local now = workspace:GetServerTimeNow()
		local active = 0
		for _, boost in BOOSTS do
			local tile = cells[boost.Kind]
			local left = (data.Boosts[boost.Kind] or 0) - now
			if left > 0 then
				active += 1
				tile.BarText.Text = formatTime(left)
				tile.Bar.BackgroundColor3 = Theme.Colors.GreenDark
			else
				tile.BarText.Text = "OFF"
				tile.Bar.BackgroundColor3 = Color3.fromRGB(40, 40, 48)
			end
			setSelected(tile, boost == selected)
		end
		ui.Count.Text = `🧪 {active} / {#BOOSTS} active`

		local def = Config.Boosts[selected.Kind]
		local product = products[selected.Product]
		local left = (data.Boosts[selected.Kind] or 0) - now
		showArt(ui, selected.Kind)
		ui.Icon.Text = def.Icon
		ui.Title.Text = def.Name
		ui.Sub.Text = selected.Text
		ui.Sub.TextColor3 = Theme.Colors.Cream
		ui.Stat.Text = if left > 0 then `⏱️ {formatTime(left)} left` else "Not active"
		ui.Stat.TextColor3 = if left > 0 then Theme.Colors.GreenText else Theme.Colors.Gray
		ui.Primary:SetText(`+{product.Boosts[1].Minutes} min  R$ {product.Price}`)
	end

	return {
		Page = ui.Page,
		Refresh = refresh,
		Keys = { Boosts = true },
		Ticks = true, -- countdowns: refresh every second while shown
	}
end

--------------------------------------------------------------------------------
-- Window
--------------------------------------------------------------------------------

function InventoryMenu.new(parent: Instance, ctx: { [string]: any })
	local window = MenuWindow.new({
		Title = "My Pets",
		Name = "Inventory",
		Icon = "🐾",
		Size = Vector2.new(820, 540),
		Parent = parent,
	})
	window.Content.Visible = false
	window.Tab = "Pets"

	local body = Create("Frame", {
		Name = "Body",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(18, 58),
		Size = UDim2.new(1, -36, 1, -66),
		ZIndex = 2,
		Parent = window.Instance,
	})
	local tabs = {
		Hands = handsTab(body, ctx),
		Pets = petsTab(body, ctx),
		Boosts = boostsTab(body, ctx),
	}

	-- Big square tabs hanging off the left edge (active one teal).
	local tabBar = Create("Frame", {
		Name = "Tabs",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(0, -12, 0, 70),
		Size = UDim2.fromOffset(100, 3 * 110),
		ZIndex = 2,
		Parent = window.Instance,
	}, {
		Create("UIListLayout", {
			Padding = UDim.new(0, 12),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	local tabButtons = {}
	for order, tab in TABS do
		local tabButton = ChunkyButton.new({
			Name = tab.Name .. "Tab",
			Text = "",
			Icon = tab.Icon,
			Caption = tab.Name,
			Color = Theme.Colors.GrayDark,
			Size = UDim2.fromOffset(100, 98),
			MaxTextSize = 24,
			StrokeThickness = 3,
			LayoutOrder = order,
			Parent = tabBar,
		})
		tabButton.Activated:Connect(function()
			window:SetTab(tab.Name)
		end)
		tabButtons[tab.Name] = tabButton
	end

	function window:SetTab(name: string)
		if not tabs[name] then
			return
		end
		window.Tab = name
		for _, tab in TABS do
			tabs[tab.Name].Page.Visible = tab.Name == name
			tabButtons[tab.Name]:SetColor(if tab.Name == name then TEAL else Theme.Colors.GrayDark)
			if tab.Name == name then
				window:SetTitle(tab.Title, tab.Icon)
			end
		end
		tabs[name].Refresh()
	end

	ClientData.Changed:Connect(function(key)
		for _, tab in tabs do
			if tab.OnChanged then
				tab.OnChanged(key)
			end
		end
		local current = tabs[window.Tab]
		if window.IsOpen and current.Keys[key] then
			current.Refresh()
		end
	end)
	window.Opened:Connect(function()
		tabs[window.Tab].Refresh()
	end)
	window.Closed:Connect(function()
		for _, tab in tabs do
			if tab.OnClosed then
				tab.OnClosed()
			end
		end
	end)
	task.spawn(function()
		while true do
			task.wait(1)
			local current = tabs[window.Tab]
			if window.IsOpen and current.Ticks then
				current.Refresh()
			end
		end
	end)

	window:SetTab("Pets")
	return window
end

return InventoryMenu
