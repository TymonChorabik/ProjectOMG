--[[
	StudPanel.luau
	Rounded studded-plastic panel (same studs as the map) with a dark outline. Children you add
	render on top of the studs. Pass Studs = false for a plain coloured panel.
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
	CornerRadius: UDim?,
	StrokeThickness: number?,
	Parent: Instance?,
}

function StudPanel.new(props: PanelProps): Frame
	local radius = props.CornerRadius or Theme.CornerRadius
	local color = props.Color or Theme.Colors.Panel
	local panel = Create("Frame", {
		Name = props.Name or "StudPanel",
		Size = props.Size,
		Position = props.Position or UDim2.new(),
		AnchorPoint = props.AnchorPoint or Vector2.zero,
		BackgroundColor3 = color,
		BackgroundTransparency = props.Transparency or 0,
		BorderSizePixel = 0,
	}, {
		Create.Corner(radius),
		Create.Stroke(props.StrokeThickness or 3),
	})

	if props.Studs ~= false then
		StudBackground.Apply(panel, { Color = color, CornerRadius = radius })
	end

	if props.Parent then
		panel.Parent = props.Parent
	end
	return panel
end

function StudPanel.SetColor(panel: Frame, color: Color3)
	panel.BackgroundColor3 = color
	StudBackground.SetColor(panel, color)
end

return StudPanel
