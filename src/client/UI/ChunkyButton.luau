--[[
	ChunkyButton.luau
	Plastic brick button: studded face with a top-lit gradient and a thick dark outline, a
	darker "depth" layer underneath and heavy outlined lettering. Hover grows it, pressing
	sinks the face and squashes it, release bounces back (TweenService Back easing) + click.

	Modes:
	• Text  – Text (optionally with an Icon prefix)
	• Tile  – Caption set: big Icon filling the face, Caption overlapping the bottom edge
	          (the HUD menu tiles)
	Options: Studs (default true), Rainbow, StrokeThickness (text outline), Silent.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Signal = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Signal"))
local Sfx = require(script.Parent.Parent.Effects.Sfx)
local Create = require(script.Parent.Create)
local StudBackground = require(script.Parent.StudBackground)
local StudPanel = require(script.Parent.StudPanel)
local Theme = require(script.Parent.Theme)

local ChunkyButton = {}
ChunkyButton.__index = ChunkyButton

export type ButtonProps = {
	Name: string?,
	Text: string,
	Icon: string?,
	Caption: string?, -- tile mode: big Icon, Caption over the bottom edge
	Color: Color3?,
	TextColor: Color3?,
	Size: UDim2,
	Position: UDim2?,
	AnchorPoint: Vector2?,
	LayoutOrder: number?,
	Depth: number?,
	CornerRadius: UDim?,
	MaxTextSize: number?,
	StrokeThickness: number?,
	Font: Enum.Font?,
	Studs: boolean?,
	Rainbow: boolean?,
	Silent: boolean?,
	Parent: Instance?,
}

local HOVER_INFO = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local PRESS_INFO = TweenInfo.new(0.06, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local RELEASE_INFO = TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

local function depthColor(color: Color3): Color3
	return Theme.Shade(color, 0.3)
end

function ChunkyButton.new(props: ButtonProps)
	local self = setmetatable({}, ChunkyButton)

	local depth = props.Depth or Theme.ButtonDepth
	local color = props.Color or Theme.Colors.Yellow
	local radius = props.CornerRadius or Theme.CornerRadius

	self.Activated = Signal.new()
	self._depth = depth
	self._enabled = true
	self._hovered = false
	self._silent = props.Silent == true

	local holder = Create("Frame", {
		Name = props.Name or "ChunkyButton",
		BackgroundTransparency = 1,
		Size = props.Size,
		Position = props.Position or UDim2.new(),
		AnchorPoint = props.AnchorPoint or Vector2.zero,
		LayoutOrder = props.LayoutOrder or 0,
	})
	self.Instance = holder
	self._scale = Create("UIScale", { Parent = holder })

	self._depthFrame = Create("Frame", {
		Name = "Depth",
		BackgroundColor3 = if props.Rainbow then Color3.fromRGB(120, 60, 170) else depthColor(color),
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 1, -depth),
		Position = UDim2.fromOffset(0, depth),
		Parent = holder,
	}, { Create.Corner(radius), Create.Stroke(Theme.StrokeThickness) })

	local face = Create("TextButton", {
		Name = "Face",
		AutoButtonColor = false,
		Text = "",
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 1, -depth),
		ZIndex = 2,
		Parent = holder,
	}, {
		Create.Corner(radius),
		Create.Stroke(Theme.StrokeThickness),
	})
	self.Face = face
	StudPanel.Paint(face, color, props.Rainbow)
	if props.Studs ~= false then
		StudBackground.Apply(face, { CornerRadius = radius })
	end

	local textColor = props.TextColor or Theme.Colors.White
	local font = props.Font or Theme.Fonts.Title
	if props.Caption then
		self.IconLabel = Create.Icon({
			Name = "Icon",
			Text = props.Icon or "",
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0.04, 0),
			Size = UDim2.fromScale(0.74, 0.66),
			ZIndex = 3,
			Parent = face,
		})
		self.Label = Create.Label({
			Name = "Label",
			Text = props.Caption,
			Font = font,
			TextColor3 = textColor,
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, 2),
			Size = UDim2.new(1, 4, 0.36, 0),
			StrokeThickness = props.StrokeThickness or 2.5,
			ZIndex = 4,
			Parent = face,
		})
	else
		local text = if props.Icon then props.Icon .. " " .. props.Text else props.Text
		self.Label = Create.Label({
			Name = "Label",
			Text = text,
			Font = font,
			TextColor3 = textColor,
			Size = UDim2.new(1, -14, 1, -10),
			Position = UDim2.fromOffset(7, 5),
			StrokeThickness = props.StrokeThickness or 2.5,
			ZIndex = 3,
			Parent = face,
		})
	end
	Create("UITextSizeConstraint", { MaxTextSize = props.MaxTextSize or 28, Parent = self.Label })

	face.MouseEnter:Connect(function()
		self._hovered = true
		if self._enabled then
			TweenService:Create(self._scale, HOVER_INFO, { Scale = 1.05 }):Play()
		end
	end)
	face.MouseLeave:Connect(function()
		self._hovered = false
		self:_release(false)
	end)
	face.MouseButton1Down:Connect(function()
		self:_press()
	end)
	face.MouseButton1Up:Connect(function()
		self:_release(true)
	end)
	face.Activated:Connect(function()
		if not self._enabled then
			return
		end
		if not self._silent then
			Sfx.Play("Click", { Volume = 0.3, PitchVariance = 0.05 })
		end
		self:_bounce()
		self.Activated:Fire()
	end)

	if props.Parent then
		holder.Parent = props.Parent
	end
	return self
end

function ChunkyButton:_press()
	if not self._enabled then
		return
	end
	TweenService:Create(self.Face, PRESS_INFO, { Position = UDim2.fromOffset(0, self._depth - 1) }):Play()
	TweenService:Create(self._scale, PRESS_INFO, { Scale = 0.94 }):Play()
end

function ChunkyButton:_release(keepHover: boolean)
	TweenService:Create(self.Face, RELEASE_INFO, { Position = UDim2.fromOffset(0, 0) }):Play()
	local target = if keepHover and self._hovered and self._enabled then 1.05 else 1
	TweenService:Create(self._scale, RELEASE_INFO, { Scale = target }):Play()
end

function ChunkyButton:_bounce()
	self._scale.Scale = 0.92
	TweenService:Create(self._scale, RELEASE_INFO, { Scale = if self._hovered then 1.05 else 1 }):Play()
	self.Face.Position = UDim2.fromOffset(0, self._depth - 1)
	TweenService:Create(self.Face, RELEASE_INFO, { Position = UDim2.fromOffset(0, 0) }):Play()
end

function ChunkyButton:SetText(text: string)
	self.Label.Text = text
end

function ChunkyButton:SetColor(color: Color3)
	StudPanel.Paint(self.Face, color)
	self._depthFrame.BackgroundColor3 = depthColor(color)
end

function ChunkyButton:SetEnabled(enabled: boolean)
	self._enabled = enabled
	self.Label.TextTransparency = if enabled then 0 else 0.25
end

-- Red notification bubble on the top-right corner (nil hides it).
function ChunkyButton:SetBadge(text: string?)
	local badge = self.Instance:FindFirstChild("Badge")
	if not text then
		if badge then
			badge.Visible = false
		end
		return
	end
	if not badge then
		badge = Create.Label({
			Name = "Badge",
			BackgroundTransparency = 0,
			BackgroundColor3 = Theme.Colors.Red,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(1, -6, 0, 6),
			Size = UDim2.fromOffset(26, 26),
			StrokeThickness = 2,
			ZIndex = 10,
			Parent = self.Instance,
		})
		Create.Corner(UDim.new(0.5, 0)).Parent = badge
		Create.Stroke(2.5).Parent = badge
		Create.Padding(3).Parent = badge
	end
	badge.Text = text
	badge.Visible = true
end

-- Outlined text sitting on the top edge (e.g. "100%" over the Rebirth tile). nil hides it.
function ChunkyButton:SetTag(text: string?)
	local tag = self.Instance:FindFirstChild("Tag")
	if not tag then
		tag = Create.Label({
			Name = "Tag",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, 0, 0, 2),
			Size = UDim2.new(1, 8, 0, 26),
			StrokeThickness = 2.5,
			ZIndex = 10,
			Parent = self.Instance,
		})
	end
	tag.Text = text or ""
	tag.Visible = text ~= nil
end

-- Visual pulse to draw attention.
function ChunkyButton:Pulse()
	self._scale.Scale = 1.12
	TweenService:Create(self._scale, RELEASE_INFO, { Scale = 1 }):Play()
end

return ChunkyButton
