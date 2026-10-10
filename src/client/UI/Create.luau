--[[
	Create.luau
	Tiny declarative instance helper + common UI decorators.

		Create("Frame", { Size = ..., Parent = gui }, { Create.Corner(), Create.Stroke() })
]]

local Theme = require(script.Parent.Theme)

local Create = {}

local function create(className: string, props: { [string]: any }?, children: { Instance }?): any
	local instance = Instance.new(className)
	local parent = nil
	if props then
		for key, value in props do
			if key == "Parent" then
				parent = value
			else
				(instance :: any)[key] = value
			end
		end
	end
	if children then
		for _, child in children do
			child.Parent = instance
		end
	end
	if parent then
		instance.Parent = parent
	end
	return instance
end

setmetatable(Create, {
	__call = function(_, className: string, props: { [string]: any }?, children: { Instance }?)
		return create(className, props, children)
	end,
})

function Create.Corner(radius: UDim?): UICorner
	return create("UICorner", { CornerRadius = radius or Theme.CornerRadius })
end

function Create.Stroke(thickness: number?, color: Color3?, transparency: number?): UIStroke
	return create("UIStroke", {
		Thickness = thickness or Theme.StrokeThickness,
		Color = color or Theme.Colors.Ink,
		Transparency = transparency or 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		LineJoinMode = Enum.LineJoinMode.Round,
	})
end

-- Outline for text (chunky cartoon lettering).
function Create.TextStroke(thickness: number?, color: Color3?): UIStroke
	return create("UIStroke", {
		Thickness = (thickness or 2.5) * Theme.TextStrokeScale,
		Color = color or Theme.Colors.Ink,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
		LineJoinMode = Enum.LineJoinMode.Round,
	})
end

function Create.Padding(all: number): UIPadding
	local udim = UDim.new(0, all)
	return create("UIPadding", { PaddingTop = udim, PaddingBottom = udim, PaddingLeft = udim, PaddingRight = udim })
end

-- Top-lit bevel: multiplies the background from full colour (top) to darker (bottom).
function Create.Bevel(strength: number?): UIGradient
	local bottom = 1 - (strength or 0.22)
	return create("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.new(bottom, bottom, bottom)),
	})
end

-- Dark glass gradient for window bodies (Theme.Colors.Window background).
function Create.Glass(): UIGradient
	return create("UIGradient", { Name = "Glass", Rotation = 90, Color = Theme.GlassGradient })
end

-- Soft drop shadow under a label: a dark copy of it one step behind and a few pixels lower,
-- kept in sync with its text and visibility. Only for freely positioned labels (not in a
-- layout), since the copy is a sibling.
function Create.DropShadow(label: TextLabel, offset: number?): TextLabel
	local shadow = create("TextLabel", {
		Name = label.Name .. "Shadow",
		BackgroundTransparency = 1,
		Text = label.Text,
		Font = label.Font,
		TextScaled = label.TextScaled,
		TextSize = label.TextSize,
		TextWrapped = label.TextWrapped,
		RichText = label.RichText,
		TextXAlignment = label.TextXAlignment,
		TextYAlignment = label.TextYAlignment,
		TextColor3 = Theme.Colors.Ink,
		TextTransparency = 0.55,
		AnchorPoint = label.AnchorPoint,
		Position = label.Position + UDim2.fromOffset(0, offset or 3),
		Size = label.Size,
		Rotation = label.Rotation,
		Visible = label.Visible,
		ZIndex = math.max(1, label.ZIndex - 1),
	})
	local constraint = label:FindFirstChildOfClass("UITextSizeConstraint")
	if constraint then
		create("UITextSizeConstraint", { MaxTextSize = constraint.MaxTextSize, Parent = shadow })
	end
	local stroke = label:FindFirstChildOfClass("UIStroke")
	if stroke then
		create("UIStroke", {
			Thickness = stroke.Thickness,
			Color = Theme.Colors.Ink,
			Transparency = 0.55,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
			LineJoinMode = Enum.LineJoinMode.Round,
			Parent = shadow,
		})
	end
	shadow.Parent = label.Parent

	-- The shadow is one flat dark colour: rich-text colour tags are stripped.
	local function syncText()
		shadow.RichText = false
		shadow.Text = if label.RichText then (string.gsub(label.Text, "<[^>]+>", "")) else label.Text
	end
	local function syncBox()
		shadow.AnchorPoint = label.AnchorPoint
		shadow.Position = label.Position + UDim2.fromOffset(0, offset or 3)
		shadow.Size = label.Size
		shadow.Rotation = label.Rotation
	end
	syncText()
	label:GetPropertyChangedSignal("Text"):Connect(syncText)
	label:GetPropertyChangedSignal("RichText"):Connect(syncText)
	for _, property in { "Position", "Size", "AnchorPoint", "Rotation" } do
		label:GetPropertyChangedSignal(property):Connect(syncBox)
	end
	label:GetPropertyChangedSignal("Visible"):Connect(function()
		shadow.Visible = label.Visible
	end)
	return shadow
end

-- Outlined cartoon text (white, heavy font, thick black outline). Extra props:
-- Stroke = false (no outline), StrokeThickness, MaxTextSize, Shadow = true (drop shadow).
function Create.Label(props: { [string]: any }): TextLabel
	local defaults = {
		BackgroundTransparency = 1,
		Font = Theme.Fonts.Title,
		TextColor3 = Theme.Colors.White,
		TextScaled = true,
	}
	for key, value in props do
		if key ~= "Stroke" and key ~= "StrokeThickness" and key ~= "MaxTextSize" and key ~= "Shadow" then
			defaults[key] = value
		end
	end
	local label = create("TextLabel", defaults)
	if props.Stroke ~= false then
		Create.TextStroke(props.StrokeThickness).Parent = label
	end
	if props.MaxTextSize then
		create("UITextSizeConstraint", { MaxTextSize = props.MaxTextSize, Parent = label })
	end
	if props.Shadow and label.Parent then
		Create.DropShadow(label)
	end
	return label
end

-- Big emoji "icon", centred in its box, with a soft dark outline so it pops off coloured
-- plastic (thicker for bigger icons).
function Create.Icon(props: { [string]: any }): TextLabel
	props.Stroke = false
	props.Font = props.Font or Theme.Fonts.Body
	local label = Create.Label(props)
	local size = props.Size
	local px = if typeof(size) == "UDim2" and size.Y.Offset > 0 then size.Y.Offset else 60
	create("UIStroke", {
		Name = "IconOutline",
		Thickness = math.clamp(px / 34, 1.5, 3.5),
		Color = Theme.Colors.Ink,
		Transparency = 0.3,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
		LineJoinMode = Enum.LineJoinMode.Round,
		Parent = label,
	})
	return label
end

return Create
