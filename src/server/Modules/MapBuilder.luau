--[[
	MapBuilder.luau
	Builds the four stud-themed training dojos (floors, walls, decor, breaking stands) from
	Config. Used in two ways:

	• Offline by tools/mapgen/build_map.py, which bakes the result into
	  src/workspace/Dojos/*.model.json so the whole map is visible and editable in Studio.
	• At runtime by WorldService, only if Workspace.Dojos is missing.

	Everything gameplay needs is read back from the map (stand attributes, ArrivalPad parts),
	so you can move, restyle or redecorate dojos freely in Studio.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local StudSurface = require(Shared.StudSurface)

local BreakableBuilder = require(script.Parent.BreakableBuilder)

local MapBuilder = {}

MapBuilder.ROOT_NAME = "Dojos"
MapBuilder.ARRIVAL_PAD = "ArrivalPad"

local STAND_SPACING = 38
local STAND_ROW_Z = 28
local ARRIVAL_Z = -40
local WALL_HEIGHT = 26

--------------------------------------------------------------------------------
-- Helpers
--------------------------------------------------------------------------------

local function part(parent: Instance, props: { [string]: any }): Part
	props.Parent = parent
	return StudSurface.NewPart(props)
end

local function cylinder(
	parent: Instance,
	props: { [string]: any },
	height: number,
	diameter: number,
	cframe: CFrame
): Part
	props.Shape = Enum.PartType.Cylinder
	props.Size = Vector3.new(height, diameter, diameter)
	props.CFrame = cframe * CFrame.Angles(0, 0, math.rad(90))
	return part(parent, props)
end

local function addLight(target: BasePart, color: Color3, range: number, brightness: number)
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = range
	light.Brightness = brightness
	light.Shadows = false
	light.Parent = target
end

local function addSurfaceText(
	target: BasePart,
	face: Enum.NormalId,
	title: string,
	subtitle: string,
	titleColor: Color3
)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0
	gui.Parent = target

	local function label(text: string, yScale: number, heightScale: number, color: Color3)
		local textLabel = Instance.new("TextLabel")
		textLabel.BackgroundTransparency = 1
		textLabel.Position = UDim2.fromScale(0.05, yScale)
		textLabel.Size = UDim2.fromScale(0.9, heightScale)
		textLabel.Font = Enum.Font.LuckiestGuy
		textLabel.TextScaled = true
		textLabel.Text = text
		textLabel.TextColor3 = color
		local stroke = Instance.new("UIStroke")
		stroke.Thickness = 6
		stroke.Color = Color3.fromRGB(25, 20, 20)
		stroke.Parent = textLabel
		textLabel.Parent = gui
	end

	label(title, 0.06, 0.58, titleColor)
	label(subtitle, 0.66, 0.28, Color3.new(1, 1, 1))
end

--------------------------------------------------------------------------------
-- Shared dojo pieces
--------------------------------------------------------------------------------

local function buildFloor(model: Model, dojo)
	local origin, size, colors = dojo.Origin, dojo.Size, dojo.Colors
	part(model, {
		Name = "Floor",
		Size = Vector3.new(size.X, 2, size.Z),
		CFrame = CFrame.new(origin + Vector3.new(0, -1, 0)),
		Color = colors.Floor,
		Checker = true,
	})

	-- Studded training mats (checkerboard) in front of the stands.
	local tile = 12
	for ix = -3, 2 do
		for iz = -2, 0 do
			local alt = (ix + iz) % 2 == 0
			part(model, {
				Name = "Mat",
				Size = Vector3.new(tile - 0.2, 0.3, tile - 0.2),
				CFrame = CFrame.new(origin + Vector3.new((ix + 0.5) * tile, 0.15, iz * tile - 4)),
				Color = if alt then colors.Mat else colors.MatAlt,
			})
		end
	end

	-- Arrival pad.
	part(model, {
		Name = "ArrivalPad",
		Size = Vector3.new(10, 0.4, 10),
		CFrame = CFrame.new(origin + Vector3.new(0, 0.2, ARRIVAL_Z)),
		Color = colors.Accent,
	})
end

local function buildWalls(model: Model, dojo, invisible: boolean?)
	local origin, size, colors = dojo.Origin, dojo.Size, dojo.Colors
	local transparency = if invisible then 1 else 0
	local halfX, halfZ = size.X / 2, size.Z / 2

	-- Back wall (behind the stands), side walls and a low front fence.
	part(model, {
		Name = "BackWall",
		Size = Vector3.new(size.X, WALL_HEIGHT, 2),
		CFrame = CFrame.new(origin + Vector3.new(0, WALL_HEIGHT / 2, halfZ - 1)),
		Color = colors.Wall,
		Transparency = transparency,
	})
	for _, side in { -1, 1 } do
		part(model, {
			Name = "SideWall",
			Size = Vector3.new(2, if invisible then WALL_HEIGHT else 12, size.Z),
			CFrame = CFrame.new(
				origin + Vector3.new(side * (halfX - 1), (if invisible then WALL_HEIGHT else 12) / 2, 0)
			),
			Color = colors.Wall,
			Transparency = transparency,
		})
	end
	part(model, {
		Name = "FrontWall",
		Size = Vector3.new(size.X, if invisible then WALL_HEIGHT else 4, 2),
		CFrame = CFrame.new(origin + Vector3.new(0, (if invisible then WALL_HEIGHT else 4) / 2, -halfZ + 1)),
		Color = colors.Trim,
		Transparency = transparency,
	})

	-- Big dojo sign on the back wall, between the centre pillars.
	local sign = part(model, {
		Name = "DojoSign",
		Size = Vector3.new(42, 10, 1),
		CFrame = CFrame.new(origin + Vector3.new(0, WALL_HEIGHT - 7, halfZ - 2.5)),
		Color = colors.Trim,
	})
	addSurfaceText(
		sign,
		Enum.NormalId.Front,
		string.upper(dojo.Name),
		`TRAINING x{dojo.TrainingMultiplier}`,
		colors.Accent
	)
end

local PILLAR_X = { -72, -48, -24, 24, 48, 72 }
local LANTERN_X = { -60, -36, 36, 60 }

local function buildPillars(model: Model, dojo, color: Color3, capColor: Color3)
	local origin, size = dojo.Origin, dojo.Size
	local z = size.Z / 2 - 4
	for _, x in PILLAR_X do
		part(model, {
			Name = "Pillar",
			Size = Vector3.new(3, WALL_HEIGHT, 3),
			CFrame = CFrame.new(origin + Vector3.new(x, WALL_HEIGHT / 2, z)),
			Color = color,
		})
		part(model, {
			Name = "PillarCap",
			Size = Vector3.new(4, 1.5, 4),
			CFrame = CFrame.new(origin + Vector3.new(x, WALL_HEIGHT - 0.75, z)),
			Color = capColor,
		})
	end
end

local function buildLanterns(model: Model, dojo, color: Color3)
	local origin, size = dojo.Origin, dojo.Size
	local z = size.Z / 2 - 6
	for _, x in LANTERN_X do
		part(model, {
			Name = "LanternRope",
			Size = Vector3.new(0.2, 4, 0.2),
			CFrame = CFrame.new(origin + Vector3.new(x, WALL_HEIGHT - 3, z)),
			Color = Color3.fromRGB(40, 30, 25),
			Studs = false,
		})
		local lantern = part(model, {
			Name = "Lantern",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(2.6, 2.6, 2.6),
			CFrame = CFrame.new(origin + Vector3.new(x, WALL_HEIGHT - 6, z)),
			Color = color,
			Material = Enum.Material.Neon,
			Studs = false,
		})
		addLight(lantern, color, 18, 1.4)
	end
end

--------------------------------------------------------------------------------
-- Themes
--------------------------------------------------------------------------------

local Themes = {}

function Themes.Starter(model: Model, dojo)
	local origin, colors = dojo.Origin, dojo.Colors
	buildWalls(model, dojo)
	buildPillars(model, dojo, Color3.fromRGB(120, 76, 44), colors.Trim)
	buildLanterns(model, dojo, Color3.fromRGB(255, 80, 60))

	-- Bonsai trees in the corners.
	for _, corner in
		{ Vector3.new(-70, 0, -50), Vector3.new(70, 0, -50), Vector3.new(-70, 0, 45), Vector3.new(70, 0, 45) }
	do
		local base = origin + corner
		cylinder(
			model,
			{ Name = "Trunk", Color = Color3.fromRGB(110, 70, 40) },
			6,
			1.6,
			CFrame.new(base + Vector3.new(0, 3, 0))
		)
		part(model, {
			Name = "Leaves",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(7, 7, 7),
			CFrame = CFrame.new(base + Vector3.new(0, 7.5, 0)),
			Color = Color3.fromRGB(70, 160, 70),
		})
		part(model, {
			Name = "Leaves",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(4.5, 4.5, 4.5),
			CFrame = CFrame.new(base + Vector3.new(2.5, 9.5, 1)),
			Color = Color3.fromRGB(90, 185, 80),
		})
	end

	-- Wooden training dummies along the side walls.
	for _, x in { -60, 60 } do
		local base = origin + Vector3.new(x, 0, 5)
		cylinder(
			model,
			{ Name = "DummyPost", Color = Color3.fromRGB(150, 100, 60) },
			7,
			1.6,
			CFrame.new(base + Vector3.new(0, 3.5, 0))
		)
		for _, y in { 4.5, 2.8 } do
			part(model, {
				Name = "DummyArm",
				Size = Vector3.new(0.6, 0.6, 4),
				CFrame = CFrame.new(base + Vector3.new(0, y, 0)),
				Color = Color3.fromRGB(170, 116, 70),
			})
		end
	end
end

function Themes.Shaolin(model: Model, dojo)
	local origin, size, colors = dojo.Origin, dojo.Size, dojo.Colors
	buildWalls(model, dojo)
	buildPillars(model, dojo, colors.Wall, colors.Trim)
	buildLanterns(model, dojo, Color3.fromRGB(255, 170, 60))

	-- Sloped tile roof along the back wall.
	for _, side in { -1, 1 } do
		part(model, {
			Name = "Roof",
			Size = Vector3.new(size.X + 6, 1.2, 9),
			CFrame = CFrame.new(origin + Vector3.new(0, WALL_HEIGHT + 0.5, size.Z / 2 - 1 + side * 3.5))
				* CFrame.Angles(math.rad(side * 22), 0, 0),
			Color = Color3.fromRGB(40, 50, 45),
		})
	end

	-- Torii gate over the entrance.
	local gateZ = -size.Z / 2 + 12
	for _, x in { -14, 14 } do
		cylinder(
			model,
			{ Name = "ToriiPost", Color = colors.Wall },
			20,
			2.4,
			CFrame.new(origin + Vector3.new(x, 10, gateZ))
		)
	end
	part(model, {
		Name = "ToriiKasagi",
		Size = Vector3.new(38, 2, 3),
		CFrame = CFrame.new(origin + Vector3.new(0, 20.5, gateZ)),
		Color = Color3.fromRGB(30, 30, 30),
	})
	part(model, {
		Name = "ToriiNuki",
		Size = Vector3.new(32, 1.4, 2),
		CFrame = CFrame.new(origin + Vector3.new(0, 16.5, gateZ)),
		Color = colors.Wall,
	})

	-- Stone lanterns.
	for _, x in { -40, 40 } do
		local base = origin + Vector3.new(x, 0, -30)
		part(model, {
			Name = "ToroBase",
			Size = Vector3.new(3, 1, 3),
			CFrame = CFrame.new(base + Vector3.new(0, 0.5, 0)),
			Color = Color3.fromRGB(150, 146, 136),
		})
		part(model, {
			Name = "ToroPost",
			Size = Vector3.new(1.4, 4, 1.4),
			CFrame = CFrame.new(base + Vector3.new(0, 3, 0)),
			Color = Color3.fromRGB(160, 156, 146),
		})
		local light = part(model, {
			Name = "ToroLight",
			Size = Vector3.new(2.4, 2, 2.4),
			CFrame = CFrame.new(base + Vector3.new(0, 6, 0)),
			Color = Color3.fromRGB(255, 200, 110),
			Material = Enum.Material.Neon,
			Studs = false,
		})
		addLight(light, Color3.fromRGB(255, 190, 100), 16, 1.2)
		part(model, {
			Name = "ToroRoof",
			Size = Vector3.new(4, 0.8, 4),
			CFrame = CFrame.new(base + Vector3.new(0, 7.4, 0)),
			Color = Color3.fromRGB(120, 116, 108),
		})
	end
end

function Themes.Cyber(model: Model, dojo)
	local origin, size, colors = dojo.Origin, dojo.Size, dojo.Colors
	buildWalls(model, dojo)
	buildPillars(model, dojo, Color3.fromRGB(60, 64, 84), colors.Trim)

	-- Neon strips along the back wall.
	for _, y in { 5, 11 } do
		part(model, {
			Name = "NeonStrip",
			Size = Vector3.new(size.X - 4, 0.6, 0.4),
			CFrame = CFrame.new(origin + Vector3.new(0, y, size.Z / 2 - 2.2)),
			Color = if y == 5 then colors.Trim else colors.Accent,
			Material = Enum.Material.Neon,
			Studs = false,
		})
	end

	-- Glowing floor grid.
	for x = -size.X / 2 + 16, size.X / 2 - 16, 16 do
		part(model, {
			Name = "GridLine",
			Size = Vector3.new(0.3, 0.12, size.Z - 6),
			CFrame = CFrame.new(origin + Vector3.new(x, 0.06, 0)),
			Color = colors.Trim,
			Material = Enum.Material.Neon,
			Transparency = 0.4,
			Studs = false,
		})
	end

	-- Hologram pylons.
	for _, corner in
		{ Vector3.new(-65, 0, -45), Vector3.new(65, 0, -45), Vector3.new(-65, 0, 45), Vector3.new(65, 0, 45) }
	do
		local base = origin + corner
		cylinder(
			model,
			{ Name = "PylonBase", Color = Color3.fromRGB(50, 54, 70) },
			1.5,
			6,
			CFrame.new(base + Vector3.new(0, 0.75, 0))
		)
		local holo = cylinder(model, {
			Name = "Hologram",
			Color = colors.Accent,
			Material = Enum.Material.Neon,
			Transparency = 0.55,
			CanCollide = false,
			Studs = false,
		}, 16, 3, CFrame.new(base + Vector3.new(0, 9.5, 0)))
		addLight(holo, colors.Accent, 20, 2)
	end
end

function Themes.Cosmic(model: Model, dojo)
	local origin, size, colors = dojo.Origin, dojo.Size, dojo.Colors
	buildWalls(model, dojo, true)

	-- Neon trim around the floating platform.
	local halfX, halfZ = size.X / 2, size.Z / 2
	for _, edge in
		{
			{ Vector3.new(0, 0, -halfZ), Vector3.new(size.X, 0.6, 0.6) },
			{ Vector3.new(0, 0, halfZ), Vector3.new(size.X, 0.6, 0.6) },
			{ Vector3.new(-halfX, 0, 0), Vector3.new(0.6, 0.6, size.Z) },
			{ Vector3.new(halfX, 0, 0), Vector3.new(0.6, 0.6, size.Z) },
		}
	do
		part(model, {
			Name = "EdgeGlow",
			Size = edge[2],
			CFrame = CFrame.new(origin + edge[1] + Vector3.new(0, 0.3, 0)),
			Color = colors.Trim,
			Material = Enum.Material.Neon,
			Studs = false,
		})
	end

	-- Stepped rock underside so the platform reads as floating.
	for depth = 1, 3 do
		part(model, {
			Name = "Underside",
			Size = Vector3.new(size.X - depth * 24, 6, size.Z - depth * 20),
			CFrame = CFrame.new(origin + Vector3.new(0, -2 - depth * 6 + 3, 0)),
			Color = Color3.fromRGB(46 - depth * 6, 34 - depth * 4, 70 - depth * 8),
		})
	end

	-- Floating stud asteroids.
	local rng = Random.new(42)
	for _ = 1, 26 do
		local angle = rng:NextNumber(0, math.pi * 2)
		local distance = rng:NextNumber(120, 220)
		local s = rng:NextNumber(3, 12)
		part(model, {
			Name = "Asteroid",
			Size = Vector3.new(s, s * rng:NextNumber(0.6, 1), s * rng:NextNumber(0.6, 1)),
			CFrame = CFrame.new(
				origin + Vector3.new(math.cos(angle) * distance, rng:NextNumber(-40, 60), math.sin(angle) * distance)
			) * CFrame.Angles(rng:NextNumber(0, 6), rng:NextNumber(0, 6), rng:NextNumber(0, 6)),
			Color = Color3.fromRGB(rng:NextInteger(60, 100), rng:NextInteger(50, 80), rng:NextInteger(90, 140)),
		})
	end

	-- Giant ringed planet on the horizon.
	part(model, {
		Name = "HorizonPlanet",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(150, 150, 150),
		CFrame = CFrame.new(origin + Vector3.new(-120, 70, 420)),
		Color = Color3.fromRGB(150, 80, 220),
		CanCollide = false,
	})
	cylinder(model, {
		Name = "HorizonRing",
		Color = colors.Accent,
		Material = Enum.Material.Neon,
		Transparency = 0.35,
		CanCollide = false,
		Studs = false,
	}, 1, 260, CFrame.new(origin + Vector3.new(-120, 70, 420)) * CFrame.Angles(math.rad(18), 0, math.rad(12)))

	-- Drifting star field.
	local starEmitterPart = part(model, {
		Name = "StarField",
		Size = Vector3.new(500, 1, 500),
		CFrame = CFrame.new(origin + Vector3.new(0, 140, 0)),
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		Studs = false,
	})
	local stars = Instance.new("ParticleEmitter")
	stars.Texture = Config.Assets.Particles.Sparkle
	stars.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(200, 170, 255))
	stars.LightEmission = 1
	stars.Size = NumberSequence.new(1.2)
	stars.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.3, 0.1),
		NumberSequenceKeypoint.new(1, 1),
	})
	stars.Lifetime = NumberRange.new(8, 14)
	stars.Rate = 40
	stars.Speed = NumberRange.new(2, 6)
	stars.EmissionDirection = Enum.NormalId.Bottom
	stars.Parent = starEmitterPart
end

--------------------------------------------------------------------------------
-- Build
--------------------------------------------------------------------------------

local function buildDojo(root: Instance, dojo)
	local model = Instance.new("Model")
	model.Name = dojo.Id
	model:SetAttribute("DojoId", dojo.Id)

	buildFloor(model, dojo)
	local theme = Themes[dojo.Id] or Themes.Starter
	theme(model, dojo)

	local standsFolder = Instance.new("Folder")
	standsFolder.Name = "Stands"
	standsFolder.Parent = model

	local count = #dojo.Objects
	for index, objectId in dojo.Objects do
		local x = (index - (count + 1) / 2) * STAND_SPACING
		local standCFrame = CFrame.new(dojo.Origin + Vector3.new(x, 0, STAND_ROW_Z))
		BreakableBuilder.Build(`{dojo.Id}_{objectId}`, objectId, dojo.Id, standCFrame, dojo.Colors, standsFolder)
	end

	if dojo.Id == Config.Dojos[1].Id then
		local spawn = Instance.new("SpawnLocation")
		spawn.Name = "DojoSpawn"
		spawn.Anchored = true
		spawn.Neutral = true
		spawn.Duration = 0
		spawn.Size = Vector3.new(8, 0.6, 8)
		spawn.CFrame = CFrame.new(dojo.Origin + Vector3.new(0, 0.5, ARRIVAL_Z))
		spawn.Color = dojo.Colors.Trim
		spawn.Material = Enum.Material.Plastic
		StudSurface.Apply(spawn)
		spawn.Parent = model
	end

	model.Parent = root
	return model
end

-- Builds every dojo into a new "Dojos" folder under `parent` and returns it.
function MapBuilder.Build(parent: Instance): Folder
	local root = Instance.new("Folder")
	root.Name = MapBuilder.ROOT_NAME
	for _, dojo in Config.Dojos do
		buildDojo(root, dojo)
	end
	root.Parent = parent
	return root
end

-- Where players appear when travelling to a dojo: above its ArrivalPad, facing the stands (+Z).
function MapBuilder.GetArrivalCFrame(dojoModel: Instance): CFrame?
	local pad = dojoModel:FindFirstChild(MapBuilder.ARRIVAL_PAD, true)
	if not pad or not pad:IsA("BasePart") then
		return nil
	end
	local position = pad.Position + Vector3.new(0, 3.3, 0)
	return CFrame.lookAt(position, position + Vector3.zAxis)
end

--[[
	Upgrades a map baked with the classic-stud fallback to the uploaded square-stud texture.
	Runs automatically at server start; you can also run it in edit mode from the Command Bar:
		require(game.ServerScriptService.Server.Modules.MapBuilder).ApplyStudTextures(workspace.Dojos)
]]
function MapBuilder.ApplyStudTextures(root: Instance): number
	if not StudSurface.HasTexture() then
		return 0
	end
	local upgraded = 0
	for _, descendant in root:GetDescendants() do
		if
			descendant:IsA("Part")
			and descendant.TopSurface == Enum.SurfaceType.Studs
			and not descendant:FindFirstChild("StudTexture")
		then
			StudSurface.Apply(descendant, { Checker = descendant.Name == "Floor" })
			upgraded += 1
		end
	end
	return upgraded
end

return MapBuilder
