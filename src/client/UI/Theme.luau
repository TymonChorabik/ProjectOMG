--[[
	Theme.luau
	Retro stud UI palette: warm yellow, bold red and crisp white on dark studded panels.
]]

local Theme = {}

Theme.Colors = {
	Yellow = Color3.fromRGB(255, 200, 40),
	YellowDark = Color3.fromRGB(196, 132, 12),
	Red = Color3.fromRGB(228, 44, 44),
	RedDark = Color3.fromRGB(140, 18, 24),
	White = Color3.fromRGB(255, 255, 255),
	Cream = Color3.fromRGB(255, 244, 214),
	Green = Color3.fromRGB(76, 208, 84),
	GreenDark = Color3.fromRGB(32, 128, 44),
	Blue = Color3.fromRGB(52, 150, 255),
	BlueDark = Color3.fromRGB(22, 82, 176),
	Purple = Color3.fromRGB(150, 80, 240),
	PurpleDark = Color3.fromRGB(84, 36, 150),
	Gray = Color3.fromRGB(130, 128, 140),
	GrayDark = Color3.fromRGB(72, 70, 82),
	Ink = Color3.fromRGB(26, 18, 28), -- outlines & text strokes
	Panel = Color3.fromRGB(46, 30, 52), -- dark plum panel
	PanelRed = Color3.fromRGB(170, 30, 34),
	PanelYellow = Color3.fromRGB(230, 168, 28),
	Card = Color3.fromRGB(70, 48, 78),
}

Theme.Fonts = {
	Title = Enum.Font.LuckiestGuy,
	Body = Enum.Font.FredokaOne,
}

Theme.CornerRadius = UDim.new(0, 14)
Theme.StrokeThickness = 4
Theme.ButtonDepth = 6 -- px of "plastic" below each chunky button

-- Darken a colour for bevel/shadow layers.
function Theme.Shade(color: Color3, amount: number): Color3
	local h, s, v = color:ToHSV()
	return Color3.fromHSV(h, math.clamp(s + amount * 0.1, 0, 1), math.clamp(v - amount, 0, 1))
end

return Theme
