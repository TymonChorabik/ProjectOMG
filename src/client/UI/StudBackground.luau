--[[
	StudBackground.luau
	Studded plastic backgrounds for UI panels and buttons — the same studs as the map.

	Default: a ViewportFrame looking straight down at a real Plastic part with SurfaceType.Studs,
	coloured like the panel. It renders through the same engine path as the map, so the UI studs
	match the world exactly and no image upload is needed. The part is resized to the panel so
	every stud stays STUD_PIXELS wide on screen.

	With Config.Assets.StudTexture set (uploaded tile), it instead follows the classic spec:
		ImageLabel inside the panel, Image = the stud texture, ScaleType = Enum.ScaleType.Tile,
		TileSize = UDim2.new(0, 32, 0, 32)  (Config.Assets.StudTileSize)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Create = require(script.Parent.Create)

local StudBackground = {}

local BACKGROUND_NAME = "StudBackground"
local STUD_PIXELS = 18 -- on-screen width of one stud
local CAMERA_FOV = 5 -- narrow FOV ≈ orthographic, so studs stay square across the panel

export type Options = {
	Color: Color3?, -- plastic colour (viewport mode)
	Tint: Color3?, -- ImageColor3 (texture mode)
	Transparency: number?, -- ImageTransparency (texture mode)
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

local function buildViewport(parent: GuiObject, options: Options?): ViewportFrame
	local viewport = Create("ViewportFrame", {
		Name = BACKGROUND_NAME,
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		-- Tuned so a lit top face renders close to the part's own colour.
		Ambient = Color3.fromRGB(125, 125, 125),
		LightColor = Color3.fromRGB(150, 150, 150),
		LightDirection = Vector3.new(-0.35, -1, -0.25),
		ZIndex = 0,
		Parent = parent,
	}, {
		Create.Corner(options and options.CornerRadius),
	})

	local plate = Instance.new("Part")
	plate.Name = "Plate"
	plate.Anchored = true
	plate.Material = Enum.Material.Plastic
	plate.Color = (options and options.Color) or Color3.fromRGB(200, 200, 200)
	plate.TopSurface = Enum.SurfaceType.Studs
	plate.BottomSurface = Enum.SurfaceType.Smooth
	plate.Size = Vector3.new(4, 1, 4)
	plate.CFrame = CFrame.new(0, -0.5, 0)
	plate.Parent = viewport

	local camera = Instance.new("Camera")
	camera.FieldOfView = CAMERA_FOV
	camera.Parent = viewport
	viewport.CurrentCamera = camera

	local function fit()
		local size = viewport.AbsoluteSize
		if size.X < 1 or size.Y < 1 then
			return
		end
		local studsX, studsZ = size.X / STUD_PIXELS, size.Y / STUD_PIXELS
		-- One spare stud on every side so the plate edge never shows.
		plate.Size = Vector3.new(math.ceil(studsX) + 2, 1, math.ceil(studsZ) + 2)
		local distance = (studsZ / 2) / math.tan(math.rad(CAMERA_FOV / 2))
		camera.CFrame = CFrame.lookAt(Vector3.new(0, distance, 0), Vector3.zero, Vector3.new(0, 0, -1))
	end
	viewport:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
	task.defer(fit)

	return viewport
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
	return buildViewport(parent, options)
end

-- Recolours the plastic of a background created by Apply (no-op in texture mode).
function StudBackground.SetColor(parent: GuiObject, color: Color3)
	local background = parent:FindFirstChild(BACKGROUND_NAME)
	local plate = background and background:FindFirstChild("Plate")
	if plate and plate:IsA("BasePart") then
		plate.Color = color
	end
end

return StudBackground
