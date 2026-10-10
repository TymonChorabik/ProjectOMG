--[[
	MenuWindow.luau
	Window in the +1 Stone Skipping style: dark translucent body with a thick outline, big
	outlined title sitting on the top edge, a large icon over the top-left corner, a red studded
	close button over the top-right corner, and a scrolling content area.

	Content helpers:
	• MenuWindow.Grid(parent, order, cellSize)     grid of tiles (auto height)
	• MenuWindow.Tile({...})                        studded coloured tile: title on top, icon /
	                                                3D preview in the middle, status bar at the
	                                                bottom; the whole tile is a button
	• MenuWindow.Header(parent, order, text)        section title
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Signal = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Signal"))
local ChunkyButton = require(script.Parent.ChunkyButton)
local Create = require(script.Parent.Create)
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

local DEFAULT_SIZE = Vector2.new(660, 470)
local OPEN_INFO = TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local CLOSE_INFO = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.In)

function MenuWindow.new(props: WindowProps)
	local self = setmetatable({}, MenuWindow)
	self.IsOpen = false
	self.Closed = Signal.new()

	local size = props.Size or DEFAULT_SIZE
	local panel = Create("Frame", {
		Name = (props.Name or props.Title) .. "Menu",
		Size = UDim2.fromOffset(size.X, size.Y),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Theme.Colors.Window,
		BackgroundTransparency = Theme.WindowTransparency,
		BorderSizePixel = 0,
		Visible = false,
	}, {
		Create.Corner(UDim.new(0, 18)),
		Create.Stroke(3.5),
	})
	self.Instance = panel
	self._scale = Create("UIScale", { Parent = panel })

	Create.Label({
		Name = "Title",
		Text = props.Title,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0, 2),
		Size = UDim2.new(1, -190, 0, 62),
		StrokeThickness = 4.5,
		MaxTextSize = 52,
		ZIndex = 6,
		Parent = panel,
	})
	if props.Icon then
		Create.Icon({
			Name = "Icon",
			Text = props.Icon,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(26, 10),
			Size = UDim2.fromOffset(88, 88),
			Rotation = -10,
			ZIndex = 6,
			Parent = panel,
		})
	end

	local close = ChunkyButton.new({
		Name = "Close",
		Text = "X",
		Color = Theme.Colors.Red,
		Size = UDim2.fromOffset(58, 60),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(1, -12, 0, 10),
		MaxTextSize = 36,
		StrokeThickness = 3,
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
		Position = UDim2.fromOffset(16, 50),
		Size = UDim2.new(1, -32, 1, -64),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = props.Color or Theme.Colors.White,
		ScrollBarImageTransparency = 0.2,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ZIndex = 2,
		Parent = panel,
	}, {
		Create("UIListLayout", {
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 10),
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
		}),
		Create("UIPadding", {
			PaddingTop = UDim.new(0, 8),
			PaddingBottom = UDim.new(0, 10),
			PaddingLeft = UDim.new(0, 2),
			PaddingRight = UDim.new(0, 8),
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
	self._scale.Scale = 0.7
	TweenService:Create(self._scale, OPEN_INFO, { Scale = 1 }):Play()
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

-- Section title inside a window's scroll list.
function MenuWindow.Header(parent: Instance, order: number, text: string): TextLabel
	return Create.Label({
		Name = "Header",
		LayoutOrder = order,
		Text = text,
		TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.new(1, -8, 0, 30),
		StrokeThickness = 3,
		MaxTextSize = 26,
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
		Size = UDim2.new(1, -12, 0, 22),
		StrokeThickness = 2.5,
		MaxTextSize = 18,
		ZIndex = 5,
		Parent = face,
	})
	local art = Create("Frame", {
		Name = "Art",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 27),
		Size = UDim2.new(1, -16, 1, -64),
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
		Size = UDim2.new(1, -16, 0, 28),
		Visible = props.Bar ~= nil,
		ZIndex = 5,
	}, { Create.Corner(UDim.new(0, 8)), Create.Stroke(2.5), Create.Bevel(0.2) })
	bar.Parent = face
	local barText = Create.Label({
		Name = "Text",
		Text = props.Bar or "",
		Position = UDim2.fromOffset(4, 3),
		Size = UDim2.new(1, -8, 1, -6),
		StrokeThickness = 2,
		MaxTextSize = 18,
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
