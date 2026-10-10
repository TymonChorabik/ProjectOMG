--[[
	StudPanel.luau
	Semi-transparent rounded panel with a thick ink outline, a bevel and the tiled stud
	background. Children you add render on top of the studs.
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
	StudTint: Color3?,
	StudTransparency: number?,
	CornerRadius: UDim?,
	StrokeThickness: number?,
	Parent: Instance?,
}

function StudPanel.new(props: PanelProps): Frame
	local radius = props.CornerRadius or Theme.CornerRadius
	local panel = Create("Frame", {
		Name = props.Name or "StudPanel",
		Size = props.Size,
		Position = props.Position or UDim2.new(),
		AnchorPoint = props.AnchorPoint or Vector2.zero,
		BackgroundColor3 = props.Color or Theme.Colors.Panel,
		BackgroundTransparency = props.Transparency or 0.12,
		BorderSizePixel = 0,
	}, {
		Create.Corner(radius),
		Create.Stroke(props.StrokeThickness),
		Create.Bevel(0.18),
	})

	StudBackground.Apply(panel, {
		Tint = props.StudTint,
		Transparency = props.StudTransparency,
		CornerRadius = radius,
	})

	-- Glossy top highlight, like light hitting ABS plastic.
	Create("Frame", {
		Name = "Shine",
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.88,
		BorderSizePixel = 0,
		Size = UDim2.new(1, -16, 0, 6),
		Position = UDim2.fromOffset(8, 5),
		ZIndex = 0,
		Parent = panel,
	}, { Create.Corner(UDim.new(1, 0)) })

	if props.Parent then
		panel.Parent = props.Parent
	end
	return panel
end

return StudPanel
