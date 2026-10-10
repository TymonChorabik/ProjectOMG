--[[
	StudPanel.luau
	Rounded plastic panel with a thick dark outline, a colour gradient (lighter top, deeper
	bottom) and blocky square studs that fade out towards the bottom (StudBackground). Children
	you add render on top of the studs.

	Options: Studs = false (plain), Gradient = false (flat colour), Rainbow = true (rainbow
	plastic like the premium buttons).
]]

local Create = require(script.Parent.Create)
local StudBackground = require(script.Parent.StudBackground)
local Theme = require(script.Parent.Theme)

local StudPanel = {}

export type PanelProps = {
	Name: string?,
	Size: UDim2,
	Position: UDim2?,
	AnchorPoint: Vector2?,
	Color: Color3?,
	Transparency: number?,
	Studs: boolean?,
	Gradient: boolean?,
	Rainbow: boolean?,
	CornerRadius: UDim?,
	StrokeThickness: number?,
	LayoutOrder: number?,
	ZIndex: number?,
	Parent: Instance?,
}

-- Applies colour + gradient (or rainbow) to any plastic surface.
function StudPanel.Paint(surface: GuiObject, color: Color3, rainbow: boolean?, gradient: boolean?)
	local existing = surface:FindFirstChild("Plastic")
	if existing then
		existing:Destroy()
	end
	if rainbow then
		surface.BackgroundColor3 = Color3.new(1, 1, 1)
		local rainbowGradient = Create("UIGradient", { Name = "Plastic", Color = Theme.Rainbow, Rotation = 0 })
		rainbowGradient:SetAttribute("Rainbow", true)
		rainbowGradient.Parent = surface
	elseif gradient ~= false then
		-- White surface + coloured gradient: lighter top, deeper bottom.
		surface.BackgroundColor3 = Color3.new(1, 1, 1)
		local plastic = Create("UIGradient", { Name = "Plastic", Color = Theme.Gradient(color), Rotation = 90 })
		plastic:SetAttribute("Tinted", true)
		plastic.Parent = surface
	else
		surface.BackgroundColor3 = color
	end
end

function StudPanel.new(props: PanelProps): Frame
	local radius = props.CornerRadius or Theme.CornerRadius
	local color = props.Color or Theme.Colors.Panel
	local panel = Create("Frame", {
		Name = props.Name or "StudPanel",
		Size = props.Size,
		Position = props.Position or UDim2.new(),
		AnchorPoint = props.AnchorPoint or Vector2.zero,
		BackgroundTransparency = props.Transparency or 0,
		BorderSizePixel = 0,
		LayoutOrder = props.LayoutOrder or 0,
		ZIndex = props.ZIndex or 1,
	}, {
		Create.Corner(radius),
		Create.Stroke(props.StrokeThickness or Theme.StrokeThickness),
	})
	StudPanel.Paint(panel, color, props.Rainbow, props.Gradient)

	if props.Studs ~= false then
		StudBackground.Apply(panel, { CornerRadius = radius })
	end

	if props.Parent then
		panel.Parent = props.Parent
	end
	return panel
end

function StudPanel.SetColor(panel: GuiObject, color: Color3)
	local plastic = panel:FindFirstChild("Plastic")
	if plastic and plastic:GetAttribute("Rainbow") then
		StudPanel.Paint(panel, color, false, true)
	elseif plastic and plastic:IsA("UIGradient") and plastic:GetAttribute("Tinted") then
		plastic.Color = Theme.Gradient(color)
	else
		panel.BackgroundColor3 = color
	end
end

return StudPanel
