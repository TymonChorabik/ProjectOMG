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
	Window = Color3.fromRGB(40, 42, 54), -- translucent window body (top of its glass gradient)
	Close = Color3.fromRGB(255, 40, 80), -- window close buttons
	Tile = Color3.fromRGB(64, 64, 72), -- HUD menu tiles
	Navy = Color3.fromRGB(28, 52, 96), -- claimed / disabled tiles
	-- Older names kept for menus that still use them.
	Panel = Color3.fromRGB(46, 46, 54),
	PanelRed = Color3.fromRGB(170, 30, 34),
	PanelYellow = Color3.fromRGB(230, 168, 28),
	Card = Color3.fromRGB(64, 64, 72),
	Slate = Color3.fromRGB(46, 46, 54),

	-- Tabs: muted slate when idle, bright sky blue when selected.
	TabIdle = Color3.fromRGB(91, 100, 130), -- #5B6482
	TabActive = Color3.fromRGB(46, 196, 240), -- #2EC4F0
	-- Timer bars on reward cells: dark so the white countdown reads on any card colour.
	TimerBar = Color3.fromRGB(31, 36, 51), -- #1F2433
	Claim = Color3.fromRGB(61, 220, 90), -- #3DDC5A
	-- Item slots in dark grids: light enough not to melt into the backdrop.
	Slot = Color3.fromRGB(122, 132, 160), -- #7A84A0
	SlotLocked = Color3.fromRGB(104, 112, 138), -- #68708A
	GridBackdrop = Color3.fromRGB(42, 47, 63), -- #2A2F3F
}

-- Soft card backdrops (the colour never fights the icon or text). Rainbow and gold are kept
-- for the rare / premium offers only.
Theme.Pastel = {
	Blue = Color3.fromRGB(110, 193, 250), -- #6EC1FA
	Lavender = Color3.fromRGB(181, 140, 245), -- #B58CF5
	Peach = Color3.fromRGB(255, 154, 133), -- #FF9A85
	Mint = Color3.fromRGB(110, 220, 154), -- #6EDC9A
	Butter = Color3.fromRGB(255, 209, 102), -- #FFD166
	Teal = Color3.fromRGB(95, 214, 207), -- #5FD6CF
	Pink = Color3.fromRGB(255, 159, 203), -- #FF9FCB
	Slate = Color3.fromRGB(128, 138, 170), -- #808AAA
}

-- Roblox renders the Gotham fonts as Montserrat: the heavy geometric lettering of the genre.
Theme.Fonts = {
	Title = Enum.Font.GothamBold,
	Body = Enum.Font.GothamBold,
	Display = Enum.Font.FredokaOne, -- big rounded window titles
}

-- Text outlines are drawn at this fraction of the thickness each label asks for.
Theme.TextStrokeScale = 0.8

-- Roblox renders this private-use character as the Robux icon in its fonts.
Theme.Robux = utf8.char(0xE002)

function Theme.Price(amount: number): string
	return `{Theme.Robux} {amount}`
end

Theme.CornerRadius = UDim.new(0, 6)
Theme.StrokeThickness = 3
Theme.ButtonDepth = 5 -- px of dark 3D bevel below each chunky button
Theme.CardDepth = 5 -- same bevel under cards
Theme.WindowTransparency = 0.4 -- window bodies: dark glass, the world shows through

-- Rainbow used by premium buttons (+1M pack, x3 offline claim, Rainbow Egg).
Theme.Rainbow = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 70, 70)),
	ColorSequenceKeypoint.new(0.2, Color3.fromRGB(255, 160, 40)),
	ColorSequenceKeypoint.new(0.4, Color3.fromRGB(255, 230, 50)),
	ColorSequenceKeypoint.new(0.6, Color3.fromRGB(80, 220, 90)),
	ColorSequenceKeypoint.new(0.8, Color3.fromRGB(60, 150, 255)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(170, 80, 255)),
})

-- Plastic gradient for a colour: lighter and softer at the top, deeper and richer at the
-- bottom (cards, buttons, tiles). Used on a white surface, so the gradient is the colour.
function Theme.Gradient(color: Color3): ColorSequence
	local h, s, v = color:ToHSV()
	local top = Color3.fromHSV(h, math.clamp(s * 0.72, 0, 1), math.clamp(v + 0.14, 0, 1))
	local bottom = Color3.fromHSV(h, math.clamp(s * 1.08 + 0.04, 0, 1), math.clamp(v - 0.14, 0, 1))
	return ColorSequence.new(top, bottom)
end

-- Dark glass windows: multiplies Colors.Window, fading darker towards the bottom.
Theme.GlassGradient = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(170, 170, 185))

-- Darken a colour for bevel/shadow layers.
function Theme.Shade(color: Color3, amount: number): Color3
	local h, s, v = color:ToHSV()
	return Color3.fromHSV(h, math.clamp(s + amount * 0.1, 0, 1), math.clamp(v - amount, 0, 1))
end

return Theme
