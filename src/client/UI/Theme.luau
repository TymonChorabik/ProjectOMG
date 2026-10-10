--[[
	Theme.luau
	+1 simulator look (modelled on +1 Stone Skipping): heavy white lettering with thick black
	outlines, saturated studded plastic buttons, dark translucent windows.
]]

local Theme = {}

Theme.Colors = {
	Yellow = Color3.fromRGB(255, 196, 30),
	YellowDark = Color3.fromRGB(196, 132, 12),
	Gold = Color3.fromRGB(255, 214, 50), -- numbers / currency text
	Orange = Color3.fromRGB(255, 150, 30),
	Red = Color3.fromRGB(232, 52, 52),
	RedDark = Color3.fromRGB(140, 18, 24),
	White = Color3.fromRGB(255, 255, 255),
	Cream = Color3.fromRGB(255, 244, 214),
	Green = Color3.fromRGB(96, 206, 40),
	GreenText = Color3.fromRGB(110, 235, 70), -- Robux prices
	GreenDark = Color3.fromRGB(32, 128, 44),
	Blue = Color3.fromRGB(24, 132, 245),
	BlueDark = Color3.fromRGB(22, 70, 160),
	Purple = Color3.fromRGB(150, 76, 240),
	PurpleDark = Color3.fromRGB(84, 36, 150),
	Pink = Color3.fromRGB(255, 90, 170),
	Gray = Color3.fromRGB(130, 130, 140),
	GrayDark = Color3.fromRGB(78, 78, 88),
	Ink = Color3.fromRGB(18, 14, 22), -- outlines & text strokes
	Window = Color3.fromRGB(46, 46, 54), -- translucent window body
	Tile = Color3.fromRGB(64, 64, 72), -- HUD menu tiles
	Navy = Color3.fromRGB(28, 52, 96), -- claimed / disabled tiles
	-- Older names kept for menus that still use them.
	Panel = Color3.fromRGB(46, 46, 54),
	PanelRed = Color3.fromRGB(170, 30, 34),
	PanelYellow = Color3.fromRGB(230, 168, 28),
	Card = Color3.fromRGB(64, 64, 72),
	Slate = Color3.fromRGB(46, 46, 54),
}

-- Roblox renders the Gotham fonts as Montserrat: the heavy geometric lettering of the genre.
Theme.Fonts = {
	Title = Enum.Font.GothamBlack,
	Body = Enum.Font.GothamBold,
}

Theme.CornerRadius = UDim.new(0, 12)
Theme.StrokeThickness = 3
Theme.ButtonDepth = 4 -- px of "plastic" below each chunky button
Theme.WindowTransparency = 0.12

-- Rainbow used by premium buttons (+1M pack, x3 offline claim, Rainbow Egg).
Theme.Rainbow = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 70, 70)),
	ColorSequenceKeypoint.new(0.2, Color3.fromRGB(255, 160, 40)),
	ColorSequenceKeypoint.new(0.4, Color3.fromRGB(255, 230, 50)),
	ColorSequenceKeypoint.new(0.6, Color3.fromRGB(80, 220, 90)),
	ColorSequenceKeypoint.new(0.8, Color3.fromRGB(60, 150, 255)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(170, 80, 255)),
})

-- Darken a colour for bevel/shadow layers.
function Theme.Shade(color: Color3, amount: number): Color3
	local h, s, v = color:ToHSV()
	return Color3.fromHSV(h, math.clamp(s + amount * 0.1, 0, 1), math.clamp(v - amount, 0, 1))
end

return Theme
