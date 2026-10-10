--[[
	MenuWindow.luau
	Centered studded modal with a chunky title tab, a big red close button, a scrolling list
	and pop-in / pop-out animations. Also provides the shared item Card used by every menu.
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

local OPEN_INFO = TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local CLOSE_INFO = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.In)

function MenuWindow.new(props: WindowProps)
	local self = setmetatable({}, MenuWindow)
	self.IsOpen = false
	self.Closed = Signal.new()

	local color = props.Color or Theme.Colors.Yellow

	local panel = StudPanel.new({
		Name = props.Title .. "Menu",
		Size = UDim2.fromOffset(660, 460),
		Position = UDim2.fromScale(0.5, 0.52),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Color = Theme.Colors.Panel,
		Transparency = 0.06,
		StudTint = color,
		StrokeThickness = 5,
	})
	panel.Visible = false
	self.Instance = panel
	self._scale = Create("UIScale", { Parent = panel })

	-- Title tab sticking out of the top edge.
	local tab = Create("Frame", {
		Name = "TitleTab",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0, 0),
		Size = UDim2.fromOffset(300, 56),
		BackgroundColor3 = color,
		ZIndex = 5,
		Parent = panel,
	}, { Create.Corner(UDim.new(0, 14)), Create.Stroke(4), Create.Bevel(0.25) })
	Create.Label({
		Text = if props.Icon then props.Icon .. " " .. string.upper(props.Title) else string.upper(props.Title),
		Font = Theme.Fonts.Title,
		Size = UDim2.new(1, -20, 1, -10),
		Position = UDim2.fromOffset(10, 6),
		StrokeThickness = 3,
		ZIndex = 6,
		Parent = tab,
	})

	local close = ChunkyButton.new({
		Name = "Close",
		Text = "X",
		Color = Theme.Colors.Red,
		Font = Theme.Fonts.Title,
		Size = UDim2.fromOffset(58, 58),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(1, -6, 0, 6),
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
		Position = UDim2.fromOffset(16, 44),
		Size = UDim2.new(1, -32, 1, -60),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 8,
		ScrollBarImageColor3 = color,
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
			PaddingBottom = UDim.new(0, 12),
			PaddingLeft = UDim.new(0, 4),
			PaddingRight = UDim.new(0, 14),
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
	self._scale.Scale = 0.6
	TweenService:Create(self._scale, OPEN_INFO, { Scale = 1 }):Play()
end

function MenuWindow:Close()
	if not self.IsOpen then
		return
	end
	self.IsOpen = false
	local tween = TweenService:Create(self._scale, CLOSE_INFO, { Scale = 0.6 })
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
	local cardHeight = height or 96
	local frame = Create("Frame", {
		Name = "Card",
		LayoutOrder = order,
		Size = UDim2.new(1, -6, 0, cardHeight),
		BackgroundColor3 = Theme.Colors.Card,
		BackgroundTransparency = 0.08,
		ZIndex = 2,
		Parent = parent,
	}, { Create.Corner(UDim.new(0, 12)), Create.Stroke(3), Create.Bevel(0.15) })

	local swatch = Create("Frame", {
		Name = "Swatch",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 12, 0.5, 0),
		Size = UDim2.fromOffset(cardHeight - 24, cardHeight - 24),
		BackgroundColor3 = Theme.Colors.Panel,
		ZIndex = 3,
		Parent = frame,
	}, { Create.Corner(UDim.new(0, 10)), Create.Stroke(3) })

	local textLeft = cardHeight - 4
	local textWidth = UDim2.new(1, -(textLeft + 180), 0, 0)

	local title = Create.Label({
		Name = "Title",
		Font = Theme.Fonts.Title,
		TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.fromOffset(textLeft, 8),
		Size = textWidth + UDim2.fromOffset(0, 30),
		ZIndex = 3,
		Parent = frame,
	})
	local subtitle = Create.Label({
		Name = "Subtitle",
		TextColor3 = Theme.Colors.Cream,
		TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.fromOffset(textLeft, 40),
		Size = textWidth + UDim2.fromOffset(0, 22),
		StrokeThickness = 2,
		ZIndex = 3,
		Parent = frame,
	})
	local info = Create.Label({
		Name = "Info",
		TextColor3 = Theme.Colors.Yellow,
		TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.fromOffset(textLeft, 64),
		Size = textWidth + UDim2.fromOffset(0, 22),
		StrokeThickness = 2,
		ZIndex = 3,
		Parent = frame,
	})

	local button = ChunkyButton.new({
		Name = "Action",
		Text = "",
		Size = UDim2.fromOffset(160, 58),
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0.5, 0),
		MaxTextSize = 24,
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
	return Create.Label({
		Name = "Header",
		LayoutOrder = order,
		Text = text,
		Font = Theme.Fonts.Title,
		TextColor3 = Theme.Colors.Yellow,
		Size = UDim2.new(1, -6, 0, 34),
		ZIndex = 2,
		Parent = parent,
	})
end

return MenuWindow
