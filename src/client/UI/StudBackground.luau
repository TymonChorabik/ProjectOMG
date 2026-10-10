--[[
	StudBackground.luau
	The "Steal an Egg" studded panel background.

	With Config.Assets.StudTexture set this is exactly the spec:
		1. an ImageLabel inside the panel
		2. Image = the seamless stud texture asset
		3. ScaleType = Enum.ScaleType.Tile
		4. TileSize = UDim2.new(0, 32, 0, 32)

	Before the texture is uploaded, a lightweight procedural grid of round studs (same 32px
	pitch) is drawn instead so the UI never looks flat.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Create = require(script.Parent.Create)

local StudBackground = {}

local MAX_FALLBACK_STUDS = 420
local BACKGROUND_NAME = "StudBackground"

export type Options = {
	Tint: Color3?, -- ImageColor3 / stud highlight colour
	Transparency: number?, -- ImageTransparency
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
		ImageTransparency = (options and options.Transparency) or Config.Assets.StudImageTransparency,
		ZIndex = 0,
		Parent = parent,
	}, {
		Create.Corner(options and options.CornerRadius),
	})
end

local function buildFallback(parent: GuiObject, options: Options?): Frame
	local tile = Config.Assets.StudTileSize.X.Offset
	local studSize = math.floor(tile * 0.6)
	local tint = (options and options.Tint) or Color3.new(1, 1, 1)
	local transparency = 0.35 + ((options and options.Transparency) or Config.Assets.StudImageTransparency) * 0.6

	local holder = Create("Frame", {
		Name = BACKGROUND_NAME,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -8, 1, -8),
		Position = UDim2.fromOffset(4, 4),
		ClipsDescendants = true,
		ZIndex = 0,
		Parent = parent,
	})
	Create("UIGridLayout", {
		CellSize = UDim2.fromOffset(studSize, studSize),
		CellPadding = UDim2.fromOffset(tile - studSize, tile - studSize),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = holder,
	})
	Create("UIPadding", {
		PaddingLeft = UDim.new(0, (tile - studSize) / 2),
		PaddingTop = UDim.new(0, (tile - studSize) / 2),
		Parent = holder,
	})

	local count = 0
	local function rebuild()
		local size = holder.AbsoluteSize
		local needed = math.min(MAX_FALLBACK_STUDS, math.ceil(size.X / tile + 1) * math.ceil(size.Y / tile + 1))
		while count < needed do
			count += 1
			Create("Frame", {
				Name = "Stud",
				BackgroundColor3 = tint,
				BackgroundTransparency = transparency,
				BorderSizePixel = 0,
				ZIndex = 0,
				Parent = holder,
			}, {
				Create.Corner(UDim.new(0.5, 0)),
				Create.Stroke(2, Color3.new(0, 0, 0), 0.75),
			})
		end
	end
	holder:GetPropertyChangedSignal("AbsoluteSize"):Connect(rebuild)
	task.defer(rebuild)

	return holder
end

-- Adds the studded background as the bottom-most child of `parent`.
function StudBackground.Apply(parent: GuiObject, options: Options?): GuiObject
	local existing = parent:FindFirstChild(BACKGROUND_NAME)
	if existing then
		existing:Destroy()
	end
	if Config.Assets.StudTexture ~= "" then
		return buildImage(parent, options)
	end
	return buildFallback(parent, options)
end

return StudBackground
