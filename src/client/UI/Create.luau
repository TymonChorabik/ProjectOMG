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
		Thickness = thickness or 2.5,
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

-- Outlined cartoon text (white, heavy font, thick black outline). Extra props:
-- Stroke = false (no outline), StrokeThickness, MaxTextSize.
function Create.Label(props: { [string]: any }): TextLabel
	local defaults = {
		BackgroundTransparency = 1,
		Font = Theme.Fonts.Title,
		TextColor3 = Theme.Colors.White,
		TextScaled = true,
	}
	for key, value in props do
		if key ~= "Stroke" and key ~= "StrokeThickness" and key ~= "MaxTextSize" then
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
	return label
end

-- Big emoji "icon" (no outline), centred in its box.
function Create.Icon(props: { [string]: any }): TextLabel
	props.Stroke = false
	props.Font = props.Font or Theme.Fonts.Body
	return Create.Label(props)
end

return Create
