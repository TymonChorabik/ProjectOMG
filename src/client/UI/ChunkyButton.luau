--[[
	ChunkyButton.luau
	Big 3D plastic button: darker "depth" layer underneath, bevelled face with thick outline and
	gloss, outlined cartoon text. Hover grows it, pressing sinks the face into the depth layer
	and squashes it, release bounces back (TweenService Back easing) with a click sound.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Signal = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Signal"))
local Sfx = require(script.Parent.Parent.Effects.Sfx)
local Create = require(script.Parent.Create)
local Theme = require(script.Parent.Theme)

local ChunkyButton = {}
ChunkyButton.__index = ChunkyButton

export type ButtonProps = {
	Name: string?,
	Text: string,
	Icon: string?,
	Caption: string?, -- icon-button mode: big Icon on top, small Caption below
	Color: Color3?,
	TextColor: Color3?,
	Size: UDim2,
	Position: UDim2?,
	AnchorPoint: Vector2?,
	LayoutOrder: number?,
	Depth: number?,
	CornerRadius: UDim?,
	MaxTextSize: number?,
	Font: Enum.Font?,
	Silent: boolean?,
	Parent: Instance?,
}

local HOVER_INFO = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local PRESS_INFO = TweenInfo.new(0.06, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local RELEASE_INFO = TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

function ChunkyButton.new(props: ButtonProps)
	local self = setmetatable({}, ChunkyButton)

	local depth = props.Depth or Theme.ButtonDepth
	local color = props.Color or Theme.Colors.Yellow
	local radius = props.CornerRadius or UDim.new(0, 12)

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
		BackgroundColor3 = Theme.Shade(color, 0.3),
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 1, -depth),
		Position = UDim2.fromOffset(0, depth),
		Parent = holder,
	}, { Create.Corner(radius), Create.Stroke(3) })

	local face = Create("TextButton", {
		Name = "Face",
		AutoButtonColor = false,
		Text = "",
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 1, -depth),
		Position = UDim2.fromOffset(0, 0),
		ZIndex = 2,
		Parent = holder,
	}, {
		Create.Corner(radius),
		Create.Stroke(3),
		Create.Bevel(0.2),
	})
	self.Face = face

	Create("Frame", {
		Name = "Gloss",
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.7,
		BorderSizePixel = 0,
		Size = UDim2.new(1, -14, 0.28, 0),
		Position = UDim2.new(0, 7, 0, 4),
		ZIndex = 2,
		Parent = face,
	}, { Create.Corner(UDim.new(1, 0)) })

	if props.Caption then
		self.IconLabel = Create.Label({
			Name = "Icon",
			Text = props.Icon or "",
			Stroke = false,
			Size = UDim2.new(1, -8, 0.62, 0),
			Position = UDim2.fromScale(0, 0.04) + UDim2.fromOffset(4, 0),
			ZIndex = 3,
			Parent = face,
		})
		self.Label = Create.Label({
			Name = "Label",
			Text = props.Caption,
			Font = props.Font or Theme.Fonts.Body,
			TextColor3 = props.TextColor or Theme.Colors.White,
			Size = UDim2.new(1, -8, 0.3, 0),
			Position = UDim2.fromScale(0, 0.66) + UDim2.fromOffset(4, 0),
			ZIndex = 3,
			Parent = face,
		})
	else
		local text = if props.Icon then props.Icon .. " " .. props.Text else props.Text
		self.Label = Create.Label({
			Name = "Label",
			Text = text,
			Font = props.Font or Theme.Fonts.Body,
			TextColor3 = props.TextColor or Theme.Colors.White,
			Size = UDim2.new(1, -16, 1, -10),
			Position = UDim2.fromOffset(8, 5),
			ZIndex = 3,
			Parent = face,
		})
	end
	Create("UITextSizeConstraint", { MaxTextSize = props.MaxTextSize or 30, Parent = self.Label })

	face.MouseEnter:Connect(function()
		self._hovered = true
		if self._enabled then
			TweenService:Create(self._scale, HOVER_INFO, { Scale = 1.06 }):Play()
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
			Sfx.Play("Click", { Volume = 0.35, PitchVariance = 0.05 })
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
	TweenService:Create(self.Face, PRESS_INFO, { Position = UDim2.fromOffset(0, self._depth - 2) }):Play()
	TweenService:Create(self._scale, PRESS_INFO, { Scale = 0.93 }):Play()
end

function ChunkyButton:_release(keepHover: boolean)
	TweenService:Create(self.Face, RELEASE_INFO, { Position = UDim2.fromOffset(0, 0) }):Play()
	local target = if keepHover and self._hovered and self._enabled then 1.06 else 1
	TweenService:Create(self._scale, RELEASE_INFO, { Scale = target }):Play()
end

function ChunkyButton:_bounce()
	self._scale.Scale = 0.9
	TweenService:Create(self._scale, RELEASE_INFO, { Scale = if self._hovered then 1.06 else 1 }):Play()
	self.Face.Position = UDim2.fromOffset(0, self._depth - 2)
	TweenService:Create(self.Face, RELEASE_INFO, { Position = UDim2.fromOffset(0, 0) }):Play()
end

function ChunkyButton:SetText(text: string)
	self.Label.Text = text
end

function ChunkyButton:SetColor(color: Color3)
	self.Face.BackgroundColor3 = color
	self._depthFrame.BackgroundColor3 = Theme.Shade(color, 0.3)
end

function ChunkyButton:SetEnabled(enabled: boolean)
	self._enabled = enabled
	self.Face.AutoButtonColor = false
	self.Label.TextTransparency = if enabled then 0 else 0.35
end

-- Small red notification bubble in the top-right corner (nil hides it).
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
			Position = UDim2.new(1, -4, 0, 4),
			Size = UDim2.fromOffset(28, 28),
			ZIndex = 10,
			Parent = self.Instance,
		})
		Create.Corner(UDim.new(0.5, 0)).Parent = badge
		Create.Stroke(2).Parent = badge
	end
	badge.Text = text
	badge.Visible = true
end

-- Text tag sitting on the top edge (e.g. "100%" on the Rebirth button). nil hides it.
function ChunkyButton:SetTag(text: string?)
	local tag = self.Instance:FindFirstChild("Tag")
	if not tag then
		tag = Create.Label({
			Name = "Tag",
			Font = Theme.Fonts.Title,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, 0, 0, 0),
			Size = UDim2.new(1, 8, 0, 24),
			StrokeThickness = 3,
			ZIndex = 10,
			Parent = self.Instance,
		})
	end
	tag.Text = text or ""
	tag.Visible = text ~= nil
end

-- Visual pulse to draw attention (e.g. rebirth available).
function ChunkyButton:Pulse()
	self._scale.Scale = 1.15
	TweenService:Create(self._scale, RELEASE_INFO, { Scale = 1 }):Play()
end

return ChunkyButton
