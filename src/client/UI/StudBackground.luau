--[[
	StudBackground.luau
	Blocky square studs for UI surfaces, like +1 Stone Skipping: a grid of small square studs,
	each drawn as a soft dark "L" (left + bottom edge) over the surface's own colour, so the
	studs pick up whatever colour/gradient the button or panel has.

	The grid is continuous like a real plate: it starts under the top-left edge, runs off every
	side and is trimmed to the rounded outline, so the border cuts studs on all four sides.
	Like the reference, the studs are clearest at the top and fade out towards the bottom.
	Built from plain Frames: nothing to upload. Studs keep a fixed size (STUD px at 1080p,
	scaled with the rest of the UI) and the grid is only rebuilt when the surface's unscaled
	size changes (not during open/close scale tweens).

	With Config.Assets.StudTexture set (an uploaded tile), it instead follows the classic spec:
		ImageLabel inside the panel, Image = the stud texture, ScaleType = Enum.ScaleType.Tile,
		TileSize = UDim2.new(0, 32, 0, 32)  (Config.Assets.StudTileSize)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Create = require(script.Parent.Create)

local StudBackground = {}

local BACKGROUND_NAME = "StudBackground"
local STUD = 11 -- stud size
local GAP = 5 -- space between studs
local EDGE = 2 -- thickness of the dark "L"
local PHASE = -4 -- the grid starts under the top-left edge, so edge studs are cut
local PITCH = STUD + GAP
local FADE = 0.92 -- how far the studs fade by the bottom edge (0 = no fade, 1 = gone)
local FADE_START = 0.12 -- fraction of the height that keeps full-strength studs

export type Options = {
	Tint: Color3?, -- ImageColor3 (texture mode)
	Transparency: number?, -- strength of the stud edges (0 = black, 1 = invisible)
	CornerRadius: UDim?,
}

local function buildImage(parent: GuiObject, options: Options?): ImageLabel
	return Create("ImageLabel", {
		Name = BACKGROUND_NAME,
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Image = Config.Assets.StudTexture,
		ScaleType = Enum.ScaleType.Tile,
		TileSize = Config.Assets.StudTileSize, -- UDim2.new(0, 32, 0, 32)
		ImageColor3 = (options and options.Tint) or Color3.new(1, 1, 1),
		ImageTransparency = Config.Assets.StudImageTransparency,
		ZIndex = 0,
		Parent = parent,
	}, {
		Create.Corner(options and options.CornerRadius),
		Create("UIGradient", { -- fade out towards the bottom
			Rotation = 90,
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0),
				NumberSequenceKeypoint.new(FADE_START, 0),
				NumberSequenceKeypoint.new(1, FADE),
			}),
		}),
	})
end

-- Transparency of a stud bar at `y` (its centre) on a surface `height` tall: full strength
-- near the top, fading towards the bottom.
function StudBackground.EdgeTransparency(base: number, y: number, height: number): number
	local t = math.clamp((y / math.max(height, 1) - FADE_START) / (1 - FADE_START), 0, 1)
	return base + (1 - base) * FADE * t ^ 1.3
end

-- Product of every UIScale from `gui` up to its ScreenGui: AbsoluteSize / this = design size.
local function cumulativeScale(gui: Instance): number
	local scale = 1
	local current: Instance? = gui
	while current and not current:IsA("LayerCollector") do
		local uiScale = current:FindFirstChildOfClass("UIScale")
		if uiScale and uiScale.Scale > 0 then
			scale *= uiScale.Scale
		end
		current = current.Parent
	end
	return scale
end

-- The dark "L" bars of every stud on a `width` x `height` surface with rounded corners of
-- `radius`, as rectangles {X, Y, W, H}. The grid is one continuous plate: it starts under the
-- top-left edge and runs off every side, and each bar is trimmed to the rounded outline, so
-- studs are cut by the border exactly like a window onto a studded sheet.
function StudBackground.Layout(width: number, height: number, radius: number): { { number } }
	local reach = radius + 1 -- the outline covers a pixel past the curve

	-- Allowed range across the surface at position `u` along an axis of `length`.
	local function span(u: number, length: number, across: number): (number, number)
		local d = if u < radius then radius - u elseif u > length - radius then u - (length - radius) else 0
		if d <= 0 then
			return 0, across
		end
		local inset = radius - math.sqrt(math.max(0, reach * reach - d * d))
		return inset, across - inset
	end

	local bars = {}
	local function vertical(x0: number, x1: number, y0: number, y1: number)
		x0, x1 = math.max(x0, 0), math.min(x1, width)
		if x1 - x0 < 1 then
			return
		end
		local lo, hi = span((x0 + x1) / 2, width, height)
		y0, y1 = math.max(y0, lo), math.min(y1, hi)
		if y1 - y0 >= 1 then
			table.insert(bars, { x0, y0, x1 - x0, y1 - y0 })
		end
	end
	local function horizontal(x0: number, x1: number, y0: number, y1: number)
		y0, y1 = math.max(y0, 0), math.min(y1, height)
		if y1 - y0 < 1 then
			return
		end
		local lo, hi = span((y0 + y1) / 2, height, width)
		x0, x1 = math.max(x0, lo), math.min(x1, hi)
		if x1 - x0 >= 1 then
			table.insert(bars, { x0, y0, x1 - x0, y1 - y0 })
		end
	end

	local cols = math.ceil((width - PHASE) / PITCH)
	local rows = math.ceil((height - PHASE) / PITCH)
	for row = 0, rows - 1 do
		for col = 0, cols - 1 do
			local x, y = PHASE + col * PITCH, PHASE + row * PITCH
			vertical(x, x + EDGE, y, y + STUD)
			horizontal(x + EDGE, x + STUD, y + STUD - EDGE, y + STUD)
		end
	end
	return bars
end

local function buildStuds(parent: GuiObject, options: Options?): Frame
	local holder = Create("Frame", {
		Name = BACKGROUND_NAME,
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 0,
		Parent = parent,
	})
	local edgeTransparency = (options and options.Transparency) or 0.84
	local cornerRadius = (options and options.CornerRadius) or UDim.new(0, 12)
	-- Read by tools/uipreview (which has no AbsoluteSize) to draw the same grid.
	holder:SetAttribute("StudPitch", PITCH)
	holder:SetAttribute("StudSize", STUD)
	holder:SetAttribute("StudEdge", EDGE)
	holder:SetAttribute("StudPhase", PHASE)
	holder:SetAttribute("StudTransparency", edgeTransparency)
	holder:SetAttribute("StudFade", FADE)
	holder:SetAttribute("StudFadeStart", FADE_START)
	holder:SetAttribute("StudRadiusScale", cornerRadius.Scale)
	holder:SetAttribute("StudRadiusOffset", cornerRadius.Offset)
	local builtWidth, builtHeight = -1, -1

	local function rebuild()
		local size = holder.AbsoluteSize / cumulativeScale(holder)
		local width, height = math.round(size.X), math.round(size.Y)
		if width == builtWidth and height == builtHeight then
			return
		end
		builtWidth, builtHeight = width, height
		holder:ClearAllChildren()

		local radius =
			math.min(cornerRadius.Scale * math.min(width, height) + cornerRadius.Offset, math.min(width, height) / 2)
		for _, bar in StudBackground.Layout(width, height, radius) do
			Create("Frame", {
				BackgroundColor3 = Color3.new(0, 0, 0),
				BackgroundTransparency = StudBackground.EdgeTransparency(edgeTransparency, bar[2] + bar[4] / 2, height),
				BorderSizePixel = 0,
				Position = UDim2.fromOffset(bar[1], bar[2]),
				Size = UDim2.fromOffset(bar[3], bar[4]),
				Parent = holder,
			})
		end
	end

	holder:GetPropertyChangedSignal("AbsoluteSize"):Connect(rebuild)
	task.defer(rebuild)
	return holder
end

-- Adds the studs as the bottom-most child of `parent`.
function StudBackground.Apply(parent: GuiObject, options: Options?): GuiObject
	local existing = parent:FindFirstChild(BACKGROUND_NAME)
	if existing then
		existing:Destroy()
	end
	if Config.Assets.StudTexture ~= "" then
		return buildImage(parent, options)
	end
	return buildStuds(parent, options)
end

-- Kept for callers from the plastic-viewport era: the studs now take the surface colour
-- automatically, so there is nothing to recolour.
function StudBackground.SetColor(_parent: GuiObject, _color: Color3) end

return StudBackground
