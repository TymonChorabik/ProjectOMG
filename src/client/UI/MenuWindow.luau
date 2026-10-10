--[[
	MenuWindow.luau
	Centred window: studded slate body (same studs as the map), big outlined title on the top
	edge (like "Playtime Rewards" in the reference), red close button, scrolling content and
	pop-in / pop-out animations. Also provides the shared item Card and section Header.
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
	Icon: string?,
	Color: Color3?,
	Parent: Instance,
}

local WIDTH, HEIGHT = 580, 400
local OPEN_INFO = TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local CLOSE_INFO = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.In)

function MenuWindow.new(props: WindowProps)
	local self = setmetatable({}, MenuWindow)
	self.IsOpen = false
	self.Closed = Signal.new()

	local accent = props.Color or Theme.Colors.Yellow

	local panel = StudPanel.new({
		Name = props.Title .. "Menu",
		Size = UDim2.fromOffset(WIDTH, HEIGHT),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Color = Theme.Colors.Slate,
		StrokeThickness = 4,
	})
	panel.Visible = false
	self.Instance = panel
	self._scale = Create("UIScale", { Parent = panel })

	-- Accent strip along the top edge.
	Create("Frame", {
		Name = "Accent",
		BackgroundColor3 = accent,
		Size = UDim2.new(1, 0, 0, 6),
		ZIndex = 2,
		Parent = panel,
	}, { Create.Corner(UDim.new(0, 4)) })

	Create.Label({
		Name = "Title",
		Text = (if props.Icon then props.Icon .. " " else "") .. props.Title,
		Font = Theme.Fonts.Title,
		TextXAlignment = Enum.TextXAlignment.Left,
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 16, 0, 2),
		Size = UDim2.new(1, -100, 0, 44),
		StrokeThickness = 3,
		ZIndex = 6,
		Parent = panel,
	})

	local close = ChunkyButton.new({
		Name = "Close",
		Text = "X",
		Color = Theme.Colors.Red,
		Size = UDim2.fromOffset(42, 44),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(1, -8, 0, 6),
		MaxTextSize = 24,
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
		Position = UDim2.fromOffset(12, 30),
		Size = UDim2.new(1, -24, 1, -42),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = accent,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ZIndex = 2,
		Parent = panel,
	}, {
		Create("UIListLayout", {
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 8),
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
		}),
		Create("UIPadding", {
			PaddingTop = UDim.new(0, 6),
			PaddingBottom = UDim.new(0, 10),
			PaddingLeft = UDim.new(0, 2),
			PaddingRight = UDim.new(0, 10),
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
-- Item card
--------------------------------------------------------------------------------

export type Card = {
	Frame: Frame,
	Swatch: Frame,
	Title: TextLabel,
	Subtitle: TextLabel,
	Info: TextLabel,
	Button: any,
}

function MenuWindow.Card(parent: Instance, order: number, height: number?): Card
	local cardHeight = height or 76
	local frame = Create("Frame", {
		Name = "Card",
		LayoutOrder = order,
		Size = UDim2.new(1, -4, 0, cardHeight),
		BackgroundColor3 = Theme.Colors.Card,
		ZIndex = 2,
		Parent = parent,
	}, { Create.Corner(UDim.new(0, 8)), Create.Stroke(2.5) })

	local swatchSize = cardHeight - 16
	local swatch = Create("Frame", {
		Name = "Swatch",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 8, 0.5, 0),
		Size = UDim2.fromOffset(swatchSize, swatchSize),
		BackgroundColor3 = Theme.Colors.Panel,
		ZIndex = 3,
		Parent = frame,
	}, { Create.Corner(UDim.new(0, 8)), Create.Stroke(2) })

	local textLeft = swatchSize + 18
	local textWidth = UDim2.new(1, -(textLeft + 140), 0, 0)

	local title = Create.Label({
		Name = "Title",
		Font = Theme.Fonts.Title,
		TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.fromOffset(textLeft, 7),
		Size = textWidth + UDim2.fromOffset(0, 22),
		StrokeThickness = 2,
		ZIndex = 3,
		Parent = frame,
	})
	local subtitle = Create.Label({
		Name = "Subtitle",
		TextColor3 = Theme.Colors.Cream,
		TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.fromOffset(textLeft, 31),
		Size = textWidth + UDim2.fromOffset(0, 17),
		StrokeThickness = 1.5,
		ZIndex = 3,
		Parent = frame,
	})
	local info = Create.Label({
		Name = "Info",
		TextColor3 = Theme.Colors.Yellow,
		TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.fromOffset(textLeft, 50),
		Size = textWidth + UDim2.fromOffset(0, 17),
		StrokeThickness = 1.5,
		ZIndex = 3,
		Parent = frame,
	})
	Create("UITextSizeConstraint", { MaxTextSize = 20, Parent = title })
	Create("UITextSizeConstraint", { MaxTextSize = 15, Parent = subtitle })
	Create("UITextSizeConstraint", { MaxTextSize = 15, Parent = info })

	local button = ChunkyButton.new({
		Name = "Action",
		Text = "",
		Size = UDim2.fromOffset(124, 44),
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -10, 0.5, 0),
		MaxTextSize = 17,
		Parent = frame,
	})
	button.Instance.ZIndex = 3

	return {
		Frame = frame,
		Swatch = swatch,
		Title = title,
		Subtitle = subtitle,
		Info = info,
		Button = button,
	}
end

-- Section header inside a window's scroll list.
function MenuWindow.Header(parent: Instance, order: number, text: string)
	local label = Create.Label({
		Name = "Header",
		LayoutOrder = order,
		Text = text,
		Font = Theme.Fonts.Title,
		TextColor3 = Theme.Colors.Yellow,
		TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.new(1, -4, 0, 24),
		StrokeThickness = 2,
		ZIndex = 2,
		Parent = parent,
	})
	return label
end

return MenuWindow
