--[[
	EggPanel.luau
	The panel that pops up beside an egg when you walk up to it (as in +1 Stone Skipping): the
	egg's name and price, a tile for every pet with its hatch chance (the Luck boost included)
	and Hatch 1 / Hatch 3 / Hatch 8 buttons, also on the keys E / R / T.

	WorldController decides which egg you're at and where it is on screen (SetEgg /
	SetScreenPosition); UIController hides the panel while a window is open (SetHidden).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Formulas = require(Shared.Formulas)
local NumberFormat = require(Shared.NumberFormat)

local ClientData = require(script.Parent.Parent.ClientData)
local ChunkyButton = require(script.Parent.ChunkyButton)
local Create = require(script.Parent.Create)
local Popups = require(script.Parent.Popups)
local StudPanel = require(script.Parent.StudPanel)
local Theme = require(script.Parent.Theme)
local ViewportPreview = require(script.Parent.ViewportPreview)

local EggPanel = {}
EggPanel.__index = EggPanel

local WIDTH, HEIGHT = 440, 286
local TILE = Vector2.new(92, 112)
local COOLDOWN = 0.5
local KEYS = { [Enum.KeyCode.E] = 1, [Enum.KeyCode.R] = 3, [Enum.KeyCode.T] = 8 }
local KEY_NAMES = { [1] = "E", [3] = "R", [8] = "T" }

local function formatChance(chance: number): string
	local percent = chance * 100
	if percent >= 10 then
		return `{math.floor(percent + 0.5)}%`
	elseif percent >= 1 then
		return `{math.floor(percent * 10 + 0.5) / 10}%`
	end
	return `{math.floor(percent * 100 + 0.5) / 100}%`
end

local function countPets(data): number
	local count = 0
	for _ in data.Pets do
		count += 1
	end
	return count
end

function EggPanel.new(parent: Instance, ctx: { [string]: any })
	local self = setmetatable({}, EggPanel)
	self.EggId = nil :: string?
	self._ctx = ctx
	self._hidden = false
	self._lastHatch = 0

	local panel = Create("Frame", {
		Name = "EggPanel",
		AnchorPoint = Vector2.new(0, 0.5),
		Size = UDim2.fromOffset(WIDTH, HEIGHT),
		BackgroundColor3 = Theme.Colors.Window,
		BackgroundTransparency = Theme.WindowTransparency,
		BorderSizePixel = 0,
		Visible = false,
		ZIndex = 5,
		Parent = parent,
	}, { Create.Corner(UDim.new(0, 16)), Create.Glass(), Create.Stroke(4) })
	self.Instance = panel
	self.Scale = Create("UIScale", { Parent = panel })

	self._title = Create.Label({
		Name = "Title",
		Text = "",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0, -2),
		Size = UDim2.new(1, -30, 0, 58),
		StrokeThickness = 5,
		MaxTextSize = 50,
		ZIndex = 8,
		Parent = panel,
	})
	self._price = Create.Label({
		Name = "Price",
		Text = "",
		TextColor3 = Theme.Colors.Gold,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 28),
		Size = UDim2.new(1, -30, 0, 30),
		StrokeThickness = 3.5,
		MaxTextSize = 28,
		ZIndex = 8,
		Parent = panel,
	})
	self._tiles = Create("Frame", {
		Name = "Chances",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 66),
		Size = UDim2.new(1, 0, 0, TILE.Y),
		ZIndex = 6,
		Parent = panel,
	}, {
		Create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	self._luck = Create.Label({
		Name = "Luck",
		Text = "🍀 2x Luck active!",
		TextColor3 = Theme.Colors.GreenText,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 66 + TILE.Y + 2),
		Size = UDim2.new(1, -30, 0, 22),
		StrokeThickness = 3,
		ZIndex = 8,
		Visible = false,
		Parent = panel,
	})

	local buttons = Create("Frame", {
		Name = "Buttons",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 0, 1, -12),
		Size = UDim2.new(1, 0, 0, 66),
		ZIndex = 6,
		Parent = panel,
	}, {
		Create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0, 12),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	self._buttons = {}
	for order, count in Config.PetsConfig.HatchCounts do
		local button = ChunkyButton.new({
			Name = `Hatch{count}`,
			Text = `Hatch {count}`,
			Color = if count == 1
				then Theme.Colors.Green
				elseif count == 3 then Theme.Colors.Blue
				else Theme.Colors.Purple,
			Size = UDim2.fromOffset(128, 64),
			MaxTextSize = 30,
			StrokeThickness = 3.5,
			LayoutOrder = order,
			Parent = buttons,
		})
		button.Instance.ZIndex = 7
		-- Key hint in the top-left corner, price in the top-right (Robux eggs).
		local keyLabel = Create.Label({
			Text = KEY_NAMES[count] or "",
			BackgroundTransparency = 0.2,
			BackgroundColor3 = Theme.Colors.Ink,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(6, 4),
			Size = UDim2.fromOffset(30, 30),
			StrokeThickness = 2,
			MaxTextSize = 22,
			ZIndex = 12,
			Parent = button.Instance,
		})
		Create.Corner(UDim.new(0, 8)).Parent = keyLabel
		local priceTag = Create.Label({
			Text = "",
			TextColor3 = Theme.Colors.GreenText,
			TextXAlignment = Enum.TextXAlignment.Right,
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, 8, 0, 2),
			Size = UDim2.fromOffset(90, 30),
			StrokeThickness = 3.5,
			ZIndex = 12,
			Parent = button.Instance,
		})
		button.Activated:Connect(function()
			self:Hatch(count)
		end)
		self._buttons[count] = { Button = button, Price = priceTag }
	end
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		local count = KEYS[input.KeyCode]
		if count and not gameProcessed and panel.Visible then
			self:Hatch(count)
		end
	end)
	ClientData.Changed:Connect(function(key)
		if key == "Boosts" and self.EggId then
			self:_rebuild()
		end
	end)
	return self
end

function EggPanel:_rebuild()
	local egg = Formulas.GetEgg(self.EggId)
	for _, child in self._tiles:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	if not egg then
		return
	end
	local data = ClientData.Data
	local luck = data ~= nil and Formulas.IsBoostActive(data, "Luck", workspace:GetServerTimeNow())
	self._title.Text = egg.Name
	self._title.TextColor3 = if egg.Rainbow then Theme.Colors.Pink else Theme.Colors.White
	self._price.Text = if egg.Cost
		then `🏆 {NumberFormat.Abbreviate(egg.Cost)} Wins each`
		else `R$ {Config.Monetization.Products[egg.Product].Price} each`
	self._luck.Visible = luck

	for order, entry in Formulas.GetEggOdds(egg.Id, luck) do
		local def = Config.Pets[entry.PetId]
		local tile = StudPanel.new({
			Name = "Chance",
			Size = UDim2.fromOffset(TILE.X, TILE.Y),
			Color = Config.Rarities[def.Rarity].Color,
			Rainbow = def.Rarity == "Secret",
			StrokeThickness = 3,
			LayoutOrder = order,
			ZIndex = 6,
			Parent = self._tiles,
		})
		local art = Create("Frame", {
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(4, 2),
			Size = UDim2.new(1, -8, 1, -30),
			ZIndex = 7,
			Parent = tile,
		})
		ViewportPreview.Pet(art, entry.PetId, 1.3)
		Create.Label({
			Text = formatChance(entry.Chance),
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -4),
			Size = UDim2.new(1, -8, 0, 26),
			StrokeThickness = 3,
			MaxTextSize = 24,
			ZIndex = 8,
			Parent = tile,
		})
	end

	for count, entry in self._buttons do
		local product = if count == 1 then egg.Product else egg.MultiProducts and egg.MultiProducts[count]
		entry.Price.Text = if product then `R${Config.Monetization.Products[product].Price}` else ""
		entry.Button.Instance.Visible = egg.Cost ~= nil or product ~= nil
	end
end

-- Shows the panel for an egg (nil hides it).
function EggPanel:SetEgg(eggId: string?)
	if eggId ~= self.EggId then
		self.EggId = eggId
		if eggId then
			self:_rebuild()
		end
	end
	self.Instance.Visible = eggId ~= nil and not self._hidden
end

-- Where the egg's right edge is on screen (GUI pixels); the panel sits beside it.
function EggPanel:SetScreenPosition(x: number, y: number, screen: Vector2)
	local scale = self.Scale.Scale
	local width, height = WIDTH * scale, HEIGHT * scale
	x = math.clamp(x + 16, 10, math.max(10, screen.X - width - 10))
	y = math.clamp(y, height / 2 + 30, math.max(height / 2 + 30, screen.Y - height / 2 - 10))
	self.Instance.Position = UDim2.fromOffset(x, y)
end

function EggPanel:SetHidden(hidden: boolean)
	self._hidden = hidden
	self.Instance.Visible = self.EggId ~= nil and not hidden
end

function EggPanel:Hatch(count: number)
	local egg = Formulas.GetEgg(self.EggId)
	local data = ClientData.Data
	local now = os.clock()
	if not egg or not data or now - self._lastHatch < COOLDOWN then
		return
	end
	self._lastHatch = now
	local room = Config.PetsConfig.MaxInventory - countPets(data)
	if room < count then
		Popups.Toast(
			if room <= 0
				then "Your pet inventory is full! Delete some pets first."
				else `Only room for {room} more pets! Delete some first.`,
			"Error"
		)
		return
	end
	if egg.Cost then
		self._ctx.Request("HatchEgg", `{egg.Id}:{count}`)
		return
	end
	local product = if count == 1 then egg.Product else egg.MultiProducts and egg.MultiProducts[count]
	if product then
		self._ctx.Purchase("product:" .. product)
	end
end

return EggPanel
