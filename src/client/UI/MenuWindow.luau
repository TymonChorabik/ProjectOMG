--[[
	MenuWindow.luau
	Window in the +1 Stone Skipping style: dark translucent body with a thick outline, big
	outlined title sitting on the top edge, a large icon over the top-left corner, a red studded
	close button over the top-right corner, and a scrolling content area.

	Opening pops the window in (and UIController blurs the world and hides the HUD).

	Content helpers:
	• MenuWindow.Header(parent, order, text)        "~ Section ~" title
	• MenuWindow.Grid(parent, order, cellSize)     grid that grows with its content
	• MenuWindow.Card({...})                        big studded plastic card (offers, stats)
	• MenuWindow.PriceButton({...}) / WasPrice()    green price button / slashed old price
	• MenuWindow.Tile({...})                        studded coloured tile: title on top, icon /
	                                                3D preview in the middle, status bar at the
	                                                bottom; the whole tile is a button
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Signal = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Signal"))
local ChunkyButton = require(script.Parent.ChunkyButton)
local Create = require(script.Parent.Create)
local StudPanel = require(script.Parent.StudPanel)
local Theme = require(script.Parent.Theme)

local MenuWindow = {}
MenuWindow.__index = MenuWindow

export type WindowProps = {
	Title: string,
	Name: string?, -- instance name prefix (defaults to Title)
	Icon: string?,
	Color: Color3?, -- scroll bar accent
	Size: Vector2?,
	Parent: Instance,
}

local DEFAULT_SIZE = Vector2.new(720, 500)
local OPEN_INFO = TweenInfo.new(0.38, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local CLOSE_INFO = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
local ICON_INFO = TweenInfo.new(0.5, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out)

function MenuWindow.new(props: WindowProps)
	local self = setmetatable({}, MenuWindow)
	self.IsOpen = false
	self.Opened = Signal.new()
	self.Closed = Signal.new()

	local size = props.Size or DEFAULT_SIZE
	local panel = Create("Frame", {
		Name = (props.Name or props.Title) .. "Menu",
		Size = UDim2.fromOffset(size.X, size.Y),
		Position = UDim2.fromScale(0.5, 0.52),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Theme.Colors.Window,
		BackgroundTransparency = Theme.WindowTransparency,
		BorderSizePixel = 0,
		Visible = false,
	}, {
		Create.Corner(UDim.new(0, 10)),
		Create.Stroke(3.5),
		Create.Glass(),
	})
	self.Instance = panel
	self._scale = Create("UIScale", { Parent = panel })

	self.TitleLabel = Create.Label({
		Name = "Title",
		Text = props.Title,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0, -6),
		Size = UDim2.new(1, -230, 0, 90),
		Font = Theme.Fonts.Display,
		StrokeThickness = 6.5,
		MaxTextSize = 80,
		ZIndex = 6,
		Parent = panel,
	})
	if props.Icon then
		self._icon = Create.Icon({
			Name = "Icon",
			Text = props.Icon,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(34, 6),
			Size = UDim2.fromOffset(124, 124),
			Rotation = -10,
			ZIndex = 6,
			Parent = panel,
		})
	end

	local close = ChunkyButton.new({
		Name = "Close",
		Text = "X",
		Color = Theme.Colors.Close,
		Studs = false,
		Font = Theme.Fonts.Display,
		Size = UDim2.fromOffset(68, 70),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(1, -10, 0, 4),
		MaxTextSize = 44,
		StrokeThickness = 3.5,
		Parent = panel,
	})
	close.Instance.ZIndex = 6
	close.Activated:Connect(function()
		self:Close()
	end)

	local scroll = Create("ScrollingFrame", {
		Name = "Content",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(16, 60),
		Size = UDim2.new(1, -32, 1, -76),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 8,
		ScrollBarImageColor3 = props.Color or Theme.Colors.White,
		ScrollBarImageTransparency = 0.25,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ZIndex = 2,
		Parent = panel,
	}, {
		Create("UIListLayout", {
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 12),
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
		}),
		Create("UIPadding", {
			PaddingTop = UDim.new(0, 8),
			PaddingBottom = UDim.new(0, 14),
			PaddingLeft = UDim.new(0, 4),
			PaddingRight = UDim.new(0, 12),
		}),
	})
	self.Content = scroll

	panel.Parent = props.Parent
	return self
end

function MenuWindow:Open()
	if self.IsOpen then
		return
	end
	self.IsOpen = true
	self.Instance.Visible = true
	self._scale.Scale = 0.5
	TweenService:Create(self._scale, OPEN_INFO, { Scale = 1 }):Play()
	if self._icon then
		self._icon.Rotation = -40
		TweenService:Create(self._icon, ICON_INFO, { Rotation = -10 }):Play()
	end
	self.Opened:Fire()
end

function MenuWindow:Close()
	if not self.IsOpen then
		return
	end
	self.IsOpen = false
	local tween = TweenService:Create(self._scale, CLOSE_INFO, { Scale = 0.7 })
	tween:Play()
	tween.Completed:Once(function()
		if not self.IsOpen then
			self.Instance.Visible = false
		end
	end)
	self.Closed:Fire()
end

-- Changes the title (and icon) on the top edge, e.g. when switching tabs.
function MenuWindow:SetTitle(title: string, icon: string?)
	self.TitleLabel.Text = title
	if icon and self._icon then
		self._icon.Text = icon
	end
end

function MenuWindow:Toggle()
	if self.IsOpen then
		self:Close()
	else
		self:Open()
	end
end

--------------------------------------------------------------------------------
-- Content helpers
--------------------------------------------------------------------------------

-- Section title inside a window's scroll list, e.g. "~ Gamepasses ~".
function MenuWindow.Header(parent: Instance, order: number, text: string): TextLabel
	return Create.Label({
		Name = "Header",
		LayoutOrder = order,
		Text = `~ {text} ~`,
		Size = UDim2.new(1, -8, 0, 46),
		StrokeThickness = 4,
		MaxTextSize = 40,
		ZIndex = 2,
		Parent = parent,
	})
end

-- A grid of tiles that grows with its content.
function MenuWindow.Grid(parent: Instance, order: number, cellSize: Vector2, padding: number?): Frame
	return Create("Frame", {
		Name = "Grid",
		LayoutOrder = order,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -4, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		ZIndex = 2,
		Parent = parent,
	}, {
		Create("UIGridLayout", {
			CellSize = UDim2.fromOffset(cellSize.X, cellSize.Y),
			CellPadding = UDim2.fromOffset(padding or 10, padding or 10),
			SortOrder = Enum.SortOrder.LayoutOrder,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
		}),
	})
end

export type CardProps = {
	Parent: Instance,
	Order: number?,
	Size: UDim2,
	Position: UDim2?,
	AnchorPoint: Vector2?,
	Color: Color3?,
	Rainbow: boolean?,
	Gradient: ColorSequence?, -- custom plastic colours (e.g. green → blue)
	Studs: boolean?,
}

-- Big studded plastic card with a thick outline (shop offers, rebirth stats, trails).
function MenuWindow.Card(props: CardProps): Frame
	local card = StudPanel.new({
		Name = "Card",
		Size = props.Size,
		Position = props.Position,
		AnchorPoint = props.AnchorPoint,
		Color = props.Color or Theme.Colors.Blue,
		Rainbow = props.Rainbow,
		Studs = props.Studs,
		StrokeThickness = 4,
		LayoutOrder = props.Order,
		ZIndex = 3,
		Parent = props.Parent,
	})
	if props.Gradient then
		StudPanel.Paint(card, Color3.new(1, 1, 1), false, false)
		Create("UIGradient", { Name = "Plastic", Color = props.Gradient, Rotation = 0, Parent = card })
	end
	return card
end

export type PriceProps = {
	Parent: Instance,
	Text: string,
	Size: UDim2?,
	Position: UDim2?,
	AnchorPoint: Vector2?,
	Color: Color3?,
	MaxTextSize: number?,
}

-- The green studded price / action button used on every offer.
function MenuWindow.PriceButton(props: PriceProps)
	local button = ChunkyButton.new({
		Name = "Price",
		Text = props.Text,
		Color = props.Color or Theme.Colors.Green,
		Size = props.Size or UDim2.fromOffset(150, 58),
		Position = props.Position,
		AnchorPoint = props.AnchorPoint,
		MaxTextSize = props.MaxTextSize or 32,
		StrokeThickness = 3.5,
		Parent = props.Parent,
	})
	button.Instance.ZIndex = 6
	return button
end

-- An old price with a red slash through it ("~~R$ 199~~"), shown next to a deal's price.
function MenuWindow.WasPrice(parent: Instance, text: string, props: { [string]: any }): TextLabel
	local label = Create.Label({
		Name = "WasPrice",
		Text = text,
		TextColor3 = Color3.fromRGB(255, 70, 70),
		Size = props.Size or UDim2.fromOffset(110, 36),
		Position = props.Position,
		AnchorPoint = props.AnchorPoint,
		StrokeThickness = 3,
		ZIndex = 7,
		Parent = parent,
	})
	Create("Frame", {
		Name = "Slash",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(0.85, 0, 0, 4),
		Rotation = -12,
		BackgroundColor3 = Color3.fromRGB(200, 30, 30),
		BorderSizePixel = 0,
		ZIndex = 8,
		Parent = label,
	})
	return label
end

export type TileProps = {
	Parent: Instance,
	Order: number,
	Color: Color3,
	Title: string?,
	Icon: string?,
	Bar: string?,
	BarColor: Color3?,
	Rainbow: boolean?,
	Studs: boolean?,
	Size: UDim2?, -- only needed outside a Grid
}

export type Tile = {
	Button: any, -- ChunkyButton
	Activated: any,
	Face: GuiButton,
	Title: TextLabel,
	Icon: TextLabel,
	Art: Frame, -- holder for 3D previews
	Bar: Frame,
	BarText: TextLabel,
	Corner: TextLabel, -- small label in the top-right corner (equipped tick, bonus...)
	Shade: Frame, -- darkening overlay for locked / claimed tiles
}

function MenuWindow.Tile(props: TileProps): Tile
	local button = ChunkyButton.new({
		Name = "Tile",
		Text = "",
		Color = props.Color,
		Rainbow = props.Rainbow,
		Studs = props.Studs,
		Size = props.Size or UDim2.fromOffset(140, 150),
		LayoutOrder = props.Order,
		Parent = props.Parent,
	})
	local face = button.Face

	local title = Create.Label({
		Name = "Title",
		Text = props.Title or "",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 6),
		Size = UDim2.new(1, -12, 0, 26),
		StrokeThickness = 2.5,
		MaxTextSize = 22,
		ZIndex = 5,
		Parent = face,
	})
	local art = Create("Frame", {
		Name = "Art",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 31),
		Size = UDim2.new(1, -16, 1, -72),
		ZIndex = 3,
		Parent = face,
	})
	local icon = Create.Icon({
		Name = "Icon",
		Text = props.Icon or "",
		Size = UDim2.fromScale(1, 1),
		ZIndex = 4,
		Parent = art,
	})
	local bar = Create("Frame", {
		Name = "Bar",
		BackgroundColor3 = props.BarColor or Theme.Colors.Red,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -7),
		Size = UDim2.new(1, -16, 0, 32),
		Visible = props.Bar ~= nil,
		ZIndex = 5,
	}, { Create.Corner(UDim.new(0, 8)), Create.Stroke(2.5), Create.Bevel(0.2) })
	bar.Parent = face
	local barText = Create.Label({
		Name = "Text",
		Text = props.Bar or "",
		Position = UDim2.fromOffset(4, 3),
		Size = UDim2.new(1, -8, 1, -6),
		StrokeThickness = 2.5,
		MaxTextSize = 22,
		ZIndex = 6,
		Parent = bar,
	})
	local corner = Create.Label({
		Name = "Corner",
		Text = "",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -3, 0, 27),
		Size = UDim2.fromOffset(30, 30),
		Stroke = false,
		ZIndex = 8,
		Parent = face,
	})
	local shade = Create("Frame", {
		Name = "Shade",
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.45,
		Size = UDim2.fromScale(1, 1),
		Visible = false,
		ZIndex = 4,
	}, { Create.Corner(Theme.CornerRadius) })
	shade.Parent = face

	return {
		Button = button,
		Activated = button.Activated,
		Face = face,
		Title = title,
		Icon = icon,
		Art = art,
		Bar = bar,
		BarText = barText,
		Corner = corner,
		Shade = shade,
	}
end

return MenuWindow
