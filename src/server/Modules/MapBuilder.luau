--[[
	MapBuilder.luau
	Builds the single studded hub (laid out like +1 Stone Skipping) from Config:

	                         ┌──────── Board Wall lane (+Z, 150 walls, 6 biomes) ───────►
	                         │
	   Training zones (-X)   │ launch pad        Hand item pedestals (+X)
	   x1 x4 x10 x20 R$ R$ R$│ spawn plaza       (unlocked by Wins)
	                         │
	                 eggs + "best in game" showcase, leaderboards (-Z)

	Used offline by tools/mapgen/build_map.py (baked into src/workspace/Map/*.model.json so it's
	visible and editable in Studio) and at runtime by WorldService if Workspace.Map is missing.
	Gameplay reads names/attributes back from the map: Zone_<Id>/Area,
	Zone_<Id>/Stations/Station_<n> (StationId attribute, Pad, Stand and Target), Item_<Id>, Egg_<Id>,
	Lane/LaunchPad, Lane/Walls/Wall_<n>, Leaderboards/<BoardId>.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Formulas = require(Shared.Formulas)
local ItemModels = require(Shared.ItemModels)
local NumberFormat = require(Shared.NumberFormat)
local PetModels = require(Shared.PetModels)
local StudSurface = require(Shared.StudSurface)

local MapBuilder = {}

MapBuilder.ROOT_NAME = "Map"

-- Hub layout (studs). The lane runs toward +Z from the launch pad.
local HUB = { MinX = -352, MaxX = 256, MinZ = -176, MaxZ = 80 }
local GROUND_TILE = 16
local GRASS = { Color3.fromRGB(120, 220, 60), Color3.fromRGB(100, 200, 48) }
local STONE = { Color3.fromRGB(214, 226, 240), Color3.fromRGB(194, 208, 228) }
local CLIFF = { Color3.fromRGB(176, 120, 70), Color3.fromRGB(150, 98, 56) }
local INK = Color3.fromRGB(25, 20, 30)
local WHITE = Color3.new(1, 1, 1)

local ZONE = { FirstX = -86, Spacing = 38, Width = 30, MinZ = -30, Length = 90 }
local ITEMS = { FirstX = 76, Spacing = 36, FirstZ = -14, RowSpacing = 32, PerRow = 5 }
local SPAWN_POSITION = Vector3.new(0, 0.6, -18)

--------------------------------------------------------------------------------
-- Helpers
--------------------------------------------------------------------------------

local function part(parent: Instance, props: { [string]: any }): Part
	props.Parent = parent
	return StudSurface.NewPart(props)
end

local function box(
	parent: Instance,
	name: string,
	size: Vector3,
	position: Vector3,
	color: Color3,
	extra: { [string]: any }?
)
	local props: { [string]: any } = { Name = name, Size = size, CFrame = CFrame.new(position), Color = color }
	if extra then
		for key, value in extra do
			props[key] = value
		end
	end
	return part(parent, props)
end

local function folder(parent: Instance, name: string, className: string?): Instance
	local instance = Instance.new(className or "Folder")
	instance.Name = name
	instance.Parent = parent
	return instance
end

local function shade(color: Color3, amount: number): Color3
	return Color3.new(color.R * amount, color.G * amount, color.B * amount)
end

local function textLabel(
	parent: Instance,
	name: string,
	text: string,
	color: Color3,
	heightScale: number,
	order: number,
	font: Enum.Font?
)
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, heightScale)
	label.Font = font or Enum.Font.FredokaOne
	label.TextScaled = true
	label.Text = text
	label.TextColor3 = color
	label.LayoutOrder = order
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 3
	stroke.Color = INK
	stroke.Parent = label
	label.Parent = parent
	return label
end

type Line = { Name: string, Text: string, Color: Color3, Height: number, Font: Enum.Font? }

-- Floating sign (BillboardGui on an invisible anchor). Lines are stacked top to bottom.
local function billboard(
	parent: Instance,
	position: Vector3,
	width: number,
	height: number,
	lines: { Line },
	maxDistance: number?
): Part
	local anchor = box(parent, "Sign", Vector3.new(1, 1, 1), position, WHITE, {
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		Studs = false,
	})
	local gui = Instance.new("BillboardGui")
	gui.Name = "Info"
	gui.Size = UDim2.new(width, 0, height, 0)
	gui.MaxDistance = maxDistance or 140
	gui.LightInfluence = 0
	gui.Parent = anchor

	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Bottom
	layout.Parent = gui

	for order, line in lines do
		textLabel(gui, line.Name, line.Text, line.Color, line.Height, order, line.Font)
	end
	return anchor
end

-- Text painted on one face of a part.
local function surfaceText(target: BasePart, face: Enum.NormalId, lines: { Line }, pixelsPerStud: number?)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Text"
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = pixelsPerStud or 30
	gui.LightInfluence = 0
	gui.MaxDistance = 400
	gui.Parent = target

	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Parent = gui

	for order, line in lines do
		textLabel(gui, line.Name, line.Text, line.Color, line.Height, order, line.Font or Enum.Font.LuckiestGuy)
	end
	return gui
end

-- Checkerboard of studded tiles covering [minX, maxX] x [minZ, maxZ] with its top at `top`.
local function checker(
	parent: Instance,
	name: string,
	minX: number,
	maxX: number,
	minZ: number,
	maxZ: number,
	tile: number,
	top: number,
	colors: { Color3 },
	thickness: number?
)
	local depth = thickness or 2
	local ix = 0
	for x = minX, maxX - 0.01, tile do
		local iz = 0
		local width = math.min(tile, maxX - x)
		for z = minZ, maxZ - 0.01, tile do
			local length = math.min(tile, maxZ - z)
			box(
				parent,
				name,
				Vector3.new(width, depth, length),
				Vector3.new(x + width / 2, top - depth / 2, z + length / 2),
				colors[(ix + iz) % 2 + 1]
			)
			iz += 1
		end
		ix += 1
	end
end

-- Chunky stud tree: trunk + two leaf cubes.
local function tree(parent: Instance, position: Vector3, trunkColor: Color3, leafColor: Color3, size: number)
	local trunkHeight = size * 1.1
	box(
		parent,
		"Trunk",
		Vector3.new(size * 0.35, trunkHeight, size * 0.35),
		position + Vector3.new(0, trunkHeight / 2, 0),
		trunkColor
	)
	box(
		parent,
		"Leaves",
		Vector3.new(size, size * 0.8, size),
		position + Vector3.new(0, trunkHeight + size * 0.3, 0),
		leafColor
	)
	box(
		parent,
		"Leaves",
		Vector3.new(size * 0.7, size * 0.6, size * 0.7),
		position + Vector3.new(size * 0.12, trunkHeight + size * 0.95, -size * 0.1),
		shade(leafColor, 1.08)
	)
end

-- Checkered cliff column (2 layers + grass cap) like the stud hills in the reference.
local function cliffColumn(
	parent: Instance,
	position: Vector3,
	size: number,
	layerHeight: number,
	colors: { Color3 },
	cap: Color3,
	parity: number
)
	for layer = 0, 1 do
		box(
			parent,
			"Cliff",
			Vector3.new(size, layerHeight, size),
			position + Vector3.new(0, layerHeight * (layer + 0.5), 0),
			colors[(parity + layer) % 2 + 1]
		)
	end
	box(parent, "CliffTop", Vector3.new(size, 3, size), position + Vector3.new(0, layerHeight * 2 + 1.5, 0), cap)
end

local function arch(
	parent: Instance,
	centerZ: number,
	halfWidth: number,
	height: number,
	postColor: Color3,
	beamColor: Color3,
	lines: { Line },
	x: number?
)
	local cx = x or 0
	for _, side in { -1, 1 } do
		box(
			parent,
			"ArchPost",
			Vector3.new(3, height, 3),
			Vector3.new(cx + side * halfWidth, height / 2, centerZ),
			postColor
		)
	end
	local beam =
		box(parent, "ArchBeam", Vector3.new(halfWidth * 2 + 6, 6, 3), Vector3.new(cx, height + 3, centerZ), beamColor)
	surfaceText(beam, Enum.NormalId.Front, lines, 24)
	surfaceText(beam, Enum.NormalId.Back, lines, 24)
	return beam
end

--------------------------------------------------------------------------------
-- Hub ground, plazas, cliffs, decor
--------------------------------------------------------------------------------

local function buildGround(root: Instance)
	local ground = folder(root, "Ground", "Model")
	checker(ground, "Grass", HUB.MinX, HUB.MaxX, HUB.MinZ, HUB.MaxZ, GROUND_TILE, 0, GRASS)

	local plazas = folder(root, "Plazas", "Model")
	-- Spawn + lane plazas, item plaza, egg plaza.
	checker(plazas, "Stone", -48, 48, -64, 32, 16, 0.4, STONE, 0.6)
	checker(plazas, "Stone", -32, 32, 32, 80, 16, 0.4, STONE, 0.6)
	checker(plazas, "Stone", 56, 232, -32, 64, 16, 0.4, STONE, 0.6)
	checker(plazas, "Stone", -80, 96, -136, -72, 16, 0.4, STONE, 0.6)
	-- Walkways: east-west in front of the zones / items, north-south to the eggs.
	checker(plazas, "Path", -352, -48, -48, -32, 16, 0.4, STONE, 0.6)
	checker(plazas, "Path", 48, 240, -48, -32, 16, 0.4, STONE, 0.6)
	checker(plazas, "Path", -16, 16, -72, -64, 16, 0.4, STONE, 0.6)
end

local function buildCliffs(root: Instance)
	local cliffs = folder(root, "Cliffs", "Model")
	local size, layer = 32, 16
	local parity = 0
	local function column(x: number, z: number)
		parity += 1
		cliffColumn(cliffs, Vector3.new(x, 0, z), size, layer, CLIFF, GRASS[1], parity)
	end
	-- South and north edges (north leaves the lane corridor open).
	for x = HUB.MinX - size / 2, HUB.MaxX + size / 2, size do
		column(x, HUB.MinZ - size / 2)
		if math.abs(x) >= 160 then
			column(x, HUB.MaxZ + size / 2)
		end
	end
	-- West and east edges.
	for z = HUB.MinZ + size / 2, HUB.MaxZ - size / 2, size do
		column(HUB.MinX - size / 2, z)
		column(HUB.MaxX + size / 2, z)
	end
end

local function buildDecor(root: Instance)
	local decor = folder(root, "Decor", "Model")
	local trunk, leaves = Color3.fromRGB(176, 120, 70), Color3.fromRGB(130, 230, 70)
	for _, position in
		{
			Vector3.new(-60, 0, -20),
			Vector3.new(60, 0, 14),
			Vector3.new(-56, 0, 50),
			Vector3.new(44, 0, 60),
			Vector3.new(-100, 0, -120),
			Vector3.new(-180, 0, -100),
			Vector3.new(-260, 0, -130),
			Vector3.new(-330, 0, -60),
			Vector3.new(-330, 0, 50),
			Vector3.new(140, 0, -110),
			Vector3.new(200, 0, -140),
			Vector3.new(236, 0, 74),
			Vector3.new(120, 0, -76),
			Vector3.new(-120, 0, -150),
		}
	do
		tree(decor, position, trunk, leaves, 10)
	end
	-- Light stud boulders.
	local rng = Random.new(7)
	for index = 1, 14 do
		-- Keep clear of the leaderboards in the middle.
		local x = if index % 2 == 0 then rng:NextNumber(HUB.MinX + 20, -120) else rng:NextNumber(120, HUB.MaxX - 20)
		local z = rng:NextNumber(-170, -140)
		local s = rng:NextNumber(4, 9)
		box(decor, "Rock", Vector3.new(s * 1.4, s, s), Vector3.new(x, s / 2, z), STONE[2])
	end
end

--------------------------------------------------------------------------------
-- Spawn
--------------------------------------------------------------------------------

local function buildSpawn(root: Instance)
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "HubSpawn"
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Size = Vector3.new(12, 1, 12)
	-- Rotated so players spawn facing the lane (+Z).
	spawn.CFrame = CFrame.new(SPAWN_POSITION) * CFrame.Angles(0, math.pi, 0)
	spawn.Color = Color3.fromRGB(255, 200, 40)
	spawn.Material = Enum.Material.Plastic
	StudSurface.Apply(spawn)
	spawn.Parent = root
end

--------------------------------------------------------------------------------
-- Training zones (right side)
--------------------------------------------------------------------------------

local function zoneStatus(zone): (string, Color3)
	if zone.Pass then
		local pass = Config.Monetization.GamePasses[zone.Pass]
		return `R$ {pass and pass.Price or "?"}`, Color3.fromRGB(120, 255, 120)
	elseif (zone.RequiredRebirths or 0) > 0 then
		return `🔒 🌀 {zone.RequiredRebirths} Rebirths`, Color3.fromRGB(255, 90, 90)
	end
	return "UNLOCKED", Color3.fromRGB(120, 255, 120)
end

local CINDER = Color3.fromRGB(150, 150, 158)

-- The dojo's breakable item (Config Breakable), lying along Z on top of the cinder blocks.
-- `top` is the centre of the blocks' top face. Every part goes in `target` so the client can
-- shatter and respawn the whole item.
local function breakable(target: Instance, def, top: Vector3, accent: Color3)
	local color = def.Color
	local material = (Enum.Material :: any)[def.Material or "SmoothPlastic"]
	local function piece(size: Vector3, offset: Vector3, extra: { [string]: any }?)
		local props: { [string]: any } = { Material = material, Studs = false }
		if extra then
			for key, value in extra do
				props[key] = value
			end
		end
		return box(target, "Piece", size, top + offset, props.Color or color, props)
	end

	local kind = def.Kind
	if kind == "Planks" then
		piece(Vector3.new(1.8, 0.3, 3.9), Vector3.new(0, 0.15, 0))
		piece(Vector3.new(1.8, 0.3, 3.9), Vector3.new(0, 0.47, 0), { Color = shade(color, 0.9) })
	elseif kind == "Bamboo" then
		for i = -1, 1 do
			local offset = Vector3.new(i * 0.6, 0.3, 0)
			piece(Vector3.new(3.9, 0.56, 0.56), offset, {
				Shape = Enum.PartType.Cylinder,
				CFrame = CFrame.new(top + offset) * CFrame.Angles(0, math.rad(90), 0),
				Color = shade(color, 1 - math.abs(i) * 0.08),
			})
			for _, z in { -1.1, 1.1 } do
				piece(Vector3.new(0.18, 0.64, 0.64), offset + Vector3.new(0, 0, z), {
					Shape = Enum.PartType.Cylinder,
					CFrame = CFrame.new(top + offset + Vector3.new(0, 0, z)) * CFrame.Angles(0, math.rad(90), 0),
					Color = shade(color, 0.7),
				})
			end
		end
	elseif kind == "Ice" then
		piece(Vector3.new(1.9, 1.3, 2.8), Vector3.new(0, 0.65, 0), { Transparency = 0.2 })
		piece(Vector3.new(1.3, 0.2, 2.0), Vector3.new(0, 1.32, 0), { Color = WHITE, Transparency = 0.35 })
	elseif kind == "Bricks" then
		for layer = 0, 1 do
			for _, z in { -0.96, 0.96 } do
				local zz = if layer == 1 then z * 0.55 else z
				piece(
					Vector3.new(1.8, 0.55, if layer == 1 then 1.0 else 1.86),
					Vector3.new(0, 0.28 + layer * 0.57, zz),
					{
						Color = shade(color, 1 - layer * 0.1),
					}
				)
			end
		end
	elseif kind == "GoldBars" then
		for _, x in { -0.47, 0.47 } do
			piece(Vector3.new(0.84, 0.45, 2.8), Vector3.new(x, 0.23, 0), { Reflectance = 0.25 })
		end
		piece(Vector3.new(0.84, 0.45, 2.6), Vector3.new(0, 0.69, 0), { Reflectance = 0.25, Color = shade(color, 1.05) })
	elseif kind == "Obsidian" then
		piece(Vector3.new(1.9, 0.7, 3.7), Vector3.new(0, 0.35, 0))
		-- Glowing seam across the slab.
		piece(
			Vector3.new(0.16, 0.72, 2.9),
			Vector3.new(0.25, 0.37, 0),
			{ Material = Enum.Material.Neon, Color = accent }
		)
		piece(
			Vector3.new(1.0, 0.72, 0.16),
			Vector3.new(-0.2, 0.37, 0.6),
			{ Material = Enum.Material.Neon, Color = accent }
		)
	elseif kind == "Crystal" then
		piece(
			Vector3.new(1.8, 0.3, 3.6),
			Vector3.new(0, 0.15, 0),
			{ Material = Enum.Material.Slate, Color = Color3.fromRGB(30, 30, 44) }
		)
		for i, z in { -1.0, 0, 1.0 } do
			local height = if i == 2 then 1.9 else 1.4
			local offset = Vector3.new(0, 0.3 + height / 2, z)
			piece(Vector3.new(0.7, height, 0.7), offset, {
				CFrame = CFrame.new(top + offset) * CFrame.Angles(math.rad((i - 2) * 14), math.rad(45), 0),
				Transparency = 0.1,
			})
		end
	else
		piece(Vector3.new(1.8, 0.6, 3.6), Vector3.new(0, 0.3, 0))
	end
end

-- A training pad (like the throwing pads at the Stone Skipping ponds) plus the stand with the
-- dojo's breakable. `side` is +1/-1: which side of the pit the station is on. The player stands
-- on the pad facing the pit; broken pieces fly into the pit.
local function station(stations: Instance, zone, index: number, position: Vector3, side: number)
	local model = folder(stations, "Station_" .. index, "Model")
	model:SetAttribute("StationId", zone.Id .. "_" .. index)
	model:SetAttribute("ZoneId", zone.Id)

	-- Stand: two cinder blocks with the breakable across them.
	for _, dz in { -1.35, 1.35 } do
		box(model, "Block", Vector3.new(1.6, 1.6, 1.0), position + Vector3.new(0, 0.8, dz), CINDER, {
			Material = Enum.Material.Concrete,
			Studs = false,
		})
	end
	local target = folder(model, "Target", "Model")
	breakable(target, zone.Breakable, position + Vector3.new(0, 1.6, 0), zone.Accent)

	-- Pad.
	local padPosition = position + Vector3.new(side * 3.7, 0, 0)
	local toTarget = Vector3.new(-side, 0, 0)
	box(model, "Pad", Vector3.new(3.8, 0.3, 3.8), padPosition + Vector3.new(0, 0.15, 0), zone.Trim)
	box(model, "PadInset", Vector3.new(3.0, 0.32, 3.0), padPosition + Vector3.new(0, 0.16, 0), zone.Accent, {
		Material = Enum.Material.SmoothPlastic,
		Studs = false,
	})
	-- Chevron pointing at the breakable.
	local tip = padPosition + toTarget * 0.75 + Vector3.new(0, 0.33, 0)
	for _, s in { -1, 1 } do
		local armDirection = (-toTarget * math.cos(math.rad(45)) + Vector3.new(0, 0, s * math.sin(math.rad(45)))).Unit
		local center = tip + armDirection * 0.55
		box(model, "Arrow", Vector3.new(0.28, 0.06, 1.2), center, WHITE, {
			CFrame = CFrame.lookAt(center, center + armDirection),
			Material = Enum.Material.SmoothPlastic,
			Studs = false,
		})
	end

	box(model, "Stand", Vector3.new(2.5, 0.2, 2.5), padPosition + Vector3.new(0, 0.1, 0), WHITE, {
		CFrame = CFrame.lookAt(padPosition + Vector3.new(0, 0.1, 0), position + Vector3.new(0, 0.1, 0)),
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		Studs = false,
	})
end

-- The "pond": a sunken pit down the middle of the dojo, already littered with broken pieces.
local function pit(model: Instance, zone, index: number, cx: number, cz: number, length: number)
	local width = 10
	local glowing = zone.Id == "Lava" or zone.Id == "Cosmic"
	box(
		model,
		"PitFloor",
		Vector3.new(width, 0.2, length),
		Vector3.new(cx, 0.82, cz),
		if glowing then zone.Accent else shade(zone.Floor, 0.55),
		{
			Material = if glowing then Enum.Material.Neon else Enum.Material.SmoothPlastic,
			Transparency = if glowing then 0.15 else 0,
			Studs = false,
		}
	)
	for _, s in { -1, 1 } do
		box(
			model,
			"PitRim",
			Vector3.new(0.6, 0.7, length + 0.6),
			Vector3.new(cx + s * (width / 2), 1.15, cz),
			zone.Trim
		)
		box(
			model,
			"PitRim",
			Vector3.new(width + 0.6, 0.7, 0.6),
			Vector3.new(cx, 1.15, cz + s * (length / 2)),
			zone.Trim
		)
	end

	local def = zone.Breakable
	local material = (Enum.Material :: any)[def.Material or "SmoothPlastic"]
	local rng = Random.new(index * 97)
	for _ = 1, 34 do
		local size = Vector3.new(rng:NextNumber(0.4, 1.2), rng:NextNumber(0.2, 0.5), rng:NextNumber(0.4, 1.4))
		local position = Vector3.new(
			cx + rng:NextNumber(-width / 2 + 1, width / 2 - 1),
			0.95 + size.Y / 2,
			cz + rng:NextNumber(-length / 2 + 1, length / 2 - 1)
		)
		box(model, "Rubble", size, position, shade(def.Color, rng:NextNumber(0.75, 1.05)), {
			CFrame = CFrame.new(position) * CFrame.Angles(
				math.rad(rng:NextNumber(-20, 20)),
				math.rad(rng:NextNumber(0, 180)),
				math.rad(rng:NextNumber(-20, 20))
			),
			Material = material,
			Transparency = if material == Enum.Material.Ice then 0.2 else 0,
			CanCollide = false,
			Studs = false,
		})
	end
end

local function buildZone(zonesFolder: Instance, zone, index: number)
	local model = folder(zonesFolder, "Zone_" .. zone.Id, "Model")
	model:SetAttribute("ZoneId", zone.Id)

	local cx = ZONE.FirstX - (index - 1) * ZONE.Spacing
	local width, length = ZONE.Width, ZONE.Length
	local cz = ZONE.MinZ + length / 2

	box(model, "Floor", Vector3.new(width, 0.8, length), Vector3.new(cx, 0.4, cz), zone.Floor)
	-- Raised border.
	for _, side in { -1, 1 } do
		box(model, "Border", Vector3.new(2, 1.6, length), Vector3.new(cx + side * (width / 2 - 1), 0.8, cz), zone.Trim)
		box(model, "Border", Vector3.new(width, 1.6, 2), Vector3.new(cx, 0.8, cz + side * (length / 2 - 1)), zone.Trim)
	end
	-- The "pond": a pit down the middle, like the training ponds in Stone Skipping.
	pit(model, zone, index, cx, cz + 1, length - 14)
	-- Training stations along both sides of the pit: pad + stand with the dojo's breakable.
	local stations = folder(model, "Stations")
	local stationIndex = 0
	for _, side in { -1, 1 } do
		for row = 0, 3 do
			stationIndex += 1
			station(stations, zone, stationIndex, Vector3.new(cx + side * 7.2, 0.8, ZONE.MinZ + 16 + row * 20), side)
		end
	end
	-- Entrance arch + sign.
	local status, statusColor = zoneStatus(zone)
	arch(model, ZONE.MinZ - 1, 12, 12, zone.Trim, shade(zone.Floor, 0.9), {
		{ Name = "Title", Text = string.upper(zone.Name), Color = WHITE, Height = 0.9 },
	}, cx)
	billboard(model, Vector3.new(cx, 22, ZONE.MinZ - 1), 14, 5, {
		{
			Name = "Multiplier",
			Text = `{NumberFormat.Multiplier(zone.Multiplier)} STRENGTH`,
			Color = Color3.fromRGB(255, 220, 70),
			Height = 0.5,
			Font = Enum.Font.LuckiestGuy,
		},
		{ Name = "Status", Text = status, Color = statusColor, Height = 0.4 },
	})

	-- Invisible volume used to detect who is training here.
	box(model, "Area", Vector3.new(width, 24, length), Vector3.new(cx, 12, cz), WHITE, {
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		Studs = false,
	})
end

--------------------------------------------------------------------------------
-- Hand item pedestals (left side)
--------------------------------------------------------------------------------

local function buildPedestal(itemsFolder: Instance, item, slot: number, premium: boolean)
	local model = folder(itemsFolder, "Item_" .. item.Id, "Model")
	model:SetAttribute("ItemId", item.Id)

	local column = (slot - 1) % ITEMS.PerRow
	local row = math.floor((slot - 1) / ITEMS.PerRow)
	local position = Vector3.new(ITEMS.FirstX + column * ITEMS.Spacing, 0.4, ITEMS.FirstZ + row * ITEMS.RowSpacing)

	local baseColor = if premium then Color3.fromRGB(200, 40, 40) else STONE[2]
	local topColor = if premium then Color3.fromRGB(255, 190, 40) else STONE[1]
	box(model, "Base", Vector3.new(12, 1.2, 12), position + Vector3.new(0, 0.6, 0), baseColor)
	box(model, "Top", Vector3.new(9, 1, 9), position + Vector3.new(0, 1.7, 0), topColor)
	if premium then
		box(
			model,
			"Glow",
			Vector3.new(9.4, 0.3, 9.4),
			position + Vector3.new(0, 1.3, 0),
			Color3.fromRGB(255, 220, 80),
			{
				Material = Enum.Material.Neon,
				Studs = false,
			}
		)
	end

	local display = ItemModels.Build(item)
	display.Name = "Display"
	display:PivotTo(CFrame.new(position + Vector3.new(0, 6, 0)) * CFrame.Angles(0, 0, math.rad(-12)))
	display.Parent = model

	local lines: { Line } = {}
	if premium then
		table.insert(
			lines,
			{ Name = "Tagline", Text = "ALWAYS 125% BETTER", Color = Color3.fromRGB(255, 120, 230), Height = 0.24 }
		)
		table.insert(lines, {
			Name = "Bonus",
			Text = string.upper(item.Name),
			Color = Color3.fromRGB(255, 210, 60),
			Height = 0.3,
			Font = Enum.Font.LuckiestGuy,
		})
		local pass = Config.Monetization.GamePasses[item.Pass]
		table.insert(lines, {
			Name = "Requirement",
			Text = `R$ {pass and pass.Price or "?"}`,
			Color = Color3.fromRGB(120, 255, 120),
			Height = 0.24,
		})
	else
		table.insert(lines, {
			Name = "Status",
			Text = if item.Wins == 0 then "UNLOCKED" else "LOCKED",
			Color = if item.Wins == 0 then Color3.fromRGB(120, 255, 120) else Color3.fromRGB(255, 90, 90),
			Height = 0.22,
		})
		table.insert(lines, {
			Name = "Bonus",
			Text = `+{NumberFormat.Abbreviate(item.Bonus)} Strength`,
			Color = WHITE,
			Height = 0.36,
			Font = Enum.Font.LuckiestGuy,
		})
		table.insert(lines, {
			Name = "Requirement",
			Text = `{NumberFormat.Abbreviate(item.Wins)} Wins`,
			Color = Color3.fromRGB(255, 210, 60),
			Height = 0.26,
		})
	end
	billboard(model, position + Vector3.new(0, 12.5, 0), 11, 4.5, lines, 90)
end

--------------------------------------------------------------------------------
-- Eggs, showcase pet, leaderboards
--------------------------------------------------------------------------------

local EGG_POSITIONS = {
	Common = Vector3.new(-60, 0.4, -94),
	Uncommon = Vector3.new(-32, 0.4, -106),
	Rare = Vector3.new(32, 0.4, -106),
	Legendary = Vector3.new(60, 0.4, -94),
	Rainbow = Vector3.new(84, 0.4, -118),
}

local function buildEgg(eggsFolder: Instance, egg)
	local position = EGG_POSITIONS[egg.Id] or Vector3.new(0, 0.4, -100)
	local model = folder(eggsFolder, "Egg_" .. egg.Id, "Model")
	model:SetAttribute("EggId", egg.Id)

	local padColor = if egg.Rainbow then Color3.fromRGB(255, 90, 170) else Color3.fromRGB(40, 120, 200)
	box(model, "Pad", Vector3.new(11, 1.2, 11), position + Vector3.new(0, 0.6, 0), padColor)
	box(
		model,
		"PadGlow",
		Vector3.new(11.6, 0.4, 11.6),
		position + Vector3.new(0, 0.3, 0),
		if egg.Rainbow then Color3.fromRGB(255, 120, 230) else Color3.fromRGB(60, 220, 255),
		{
			Material = Enum.Material.Neon,
			Studs = false,
		}
	)
	box(model, "Egg", Vector3.new(6, 7.5, 6), position + Vector3.new(0, 5.2, 0), egg.Color, {
		Shape = Enum.PartType.Ball,
		Material = Enum.Material.SmoothPlastic,
		Studs = false,
	})
	if egg.Rainbow then
		local colors = {
			Color3.fromRGB(255, 80, 80),
			Color3.fromRGB(255, 220, 60),
			Color3.fromRGB(80, 220, 120),
			Color3.fromRGB(80, 160, 255),
		}
		for index, color in colors do
			box(model, "Band", Vector3.new(6.15, 0.7, 6.15), position + Vector3.new(0, 2.6 + index * 1.15, 0), color, {
				Shape = Enum.PartType.Cylinder,
				Material = Enum.Material.Neon,
				Studs = false,
				CFrame = CFrame.new(position + Vector3.new(0, 2.6 + index * 1.15, 0))
					* CFrame.Angles(0, 0, math.rad(90)),
				Size = Vector3.new(0.7, 5.6 - math.abs(index - 2.5) * 0.6, 5.6 - math.abs(index - 2.5) * 0.6),
			})
		end
	end

	local price = if egg.Cost
		then `🏆 {NumberFormat.Abbreviate(egg.Cost)} Wins`
		else `R$ {Config.Monetization.Products[egg.Product].Price}`
	billboard(model, position + Vector3.new(0, 12.5, 0), 10, 3.4, {
		{
			Name = "Title",
			Text = string.upper(egg.Name),
			Color = egg.Color,
			Height = 0.55,
			Font = Enum.Font.LuckiestGuy,
		},
		{ Name = "Price", Text = price, Color = Color3.fromRGB(255, 220, 90), Height = 0.4 },
	})
end

local function buildShowcase(root: Instance)
	local model = folder(root, "Showcase", "Model")
	local position = Vector3.new(0, 0.4, -118)
	box(model, "Base", Vector3.new(16, 1.6, 12), position + Vector3.new(0, 0.8, 0), Color3.fromRGB(200, 40, 40))
	box(model, "Top", Vector3.new(13, 1.2, 9), position + Vector3.new(0, 2.2, 0), Color3.fromRGB(255, 190, 40))
	box(model, "Glow", Vector3.new(16.4, 0.4, 12.4), position + Vector3.new(0, 1.7, 0), Color3.fromRGB(255, 230, 90), {
		Material = Enum.Material.Neon,
		Studs = false,
	})
	local pet = PetModels.Build("LionKing", 2.2)
	pet.Name = "Pet"
	pet:PivotTo(CFrame.new(position + Vector3.new(0, 6.3, 0)) * CFrame.Angles(0, math.pi, 0))
	pet.Parent = model

	local pass = Config.Monetization.GamePasses.LionKing
	billboard(model, position + Vector3.new(0, 15, 0), 12, 5, {
		{
			Name = "Best",
			Text = "BEST IN GAME",
			Color = Color3.fromRGB(255, 70, 90),
			Height = 0.3,
			Font = Enum.Font.LuckiestGuy,
		},
		{ Name = "Tagline", Text = "Always 1000% Better", Color = Color3.fromRGB(255, 220, 60), Height = 0.28 },
		{
			Name = "Price",
			Text = `{pass.Name} • R$ {pass.Price}`,
			Color = Color3.fromRGB(120, 255, 120),
			Height = 0.24,
		},
	})
end

local function buildLeaderboards(root: Instance)
	local boards = folder(root, "Leaderboards")
	local frameColor = Color3.fromRGB(230, 150, 60)
	for index, def in Config.Leaderboards.Boards do
		local x = (index - 2) * 80
		local center = Vector3.new(x, 18, -156)
		local model = folder(boards, def.Id, "Model")
		box(model, "Panel", Vector3.new(40, 28, 1.5), center, Color3.fromRGB(40, 140, 70))
		box(model, "FrameTop", Vector3.new(44, 3, 3), center + Vector3.new(0, 15.5, 0), frameColor)
		box(model, "FrameBottom", Vector3.new(44, 3, 3), center + Vector3.new(0, -15.5, 0), frameColor)
		for _, side in { -1, 1 } do
			box(model, "FrameSide", Vector3.new(3, 34, 3), center + Vector3.new(side * 21.5, 0, 0), frameColor)
			box(model, "Leg", Vector3.new(3, 4, 3), Vector3.new(x + side * 16, 0.4 + 2, -156), shade(frameColor, 0.8))
		end
		local panel = model:FindFirstChild("Panel") :: BasePart
		panel:SetAttribute("BoardId", def.Id)
		surfaceText(panel, Enum.NormalId.Back, {
			{ Name = "Title", Text = `{def.Icon} {def.Title}`, Color = Color3.fromRGB(255, 220, 60), Height = 0.14 },
			{ Name = "Hint", Text = "Global top 10 • updates every few minutes", Color = WHITE, Height = 0.06 },
		}, 20)
	end
end

--------------------------------------------------------------------------------
-- The Board Wall lane
--------------------------------------------------------------------------------

local function buildLane(root: Instance)
	local lane = folder(root, "Lane", "Model")
	local laneConfig = Config.Lane
	local pad = laneConfig.PadPosition
	local halfWidth = laneConfig.Width / 2
	local wallCount = Formulas.GetWallCount()
	local laneEndZ = Formulas.GetWallZ(wallCount) + laneConfig.FinishOvershoot + 26

	-- Launch pad.
	local launchPad = box(
		lane,
		"LaunchPad",
		Vector3.new(1.2, laneConfig.PadRadius * 2, laneConfig.PadRadius * 2),
		pad,
		Color3.fromRGB(255, 200, 40),
		{
			Shape = Enum.PartType.Cylinder,
			CFrame = CFrame.new(pad + Vector3.new(0, 0.6, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		}
	)
	launchPad:SetAttribute("Radius", laneConfig.PadRadius)
	box(
		lane,
		"PadRing",
		Vector3.new(0.4, laneConfig.PadRadius * 2 + 1.5, laneConfig.PadRadius * 2 + 1.5),
		pad,
		Color3.fromRGB(255, 80, 60),
		{
			Shape = Enum.PartType.Cylinder,
			Material = Enum.Material.Neon,
			Studs = false,
			CFrame = CFrame.new(pad + Vector3.new(0, 0.3, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		}
	)
	billboard(lane, pad + Vector3.new(0, 9, 0), 16, 4, {
		{
			Name = "Title",
			Text = "🥋 SMASH THE WALL!",
			Color = Color3.fromRGB(255, 220, 60),
			Height = 0.55,
			Font = Enum.Font.LuckiestGuy,
		},
		{ Name = "Hint", Text = "Stand here and press SMASH", Color = WHITE, Height = 0.35 },
	})

	local walls = folder(lane, "Walls")
	local decor = folder(lane, "Decor", "Model")
	for biomeIndex, biome in Config.Biomes do
		local startZ = if biomeIndex == 1
			then HUB.MaxZ
			else Formulas.GetWallZ((biomeIndex - 1) * laneConfig.WallsPerBiome + 1) - laneConfig.WallSpacing / 2
		local endZ = if biomeIndex == #Config.Biomes
			then laneEndZ
			else Formulas.GetWallZ(biomeIndex * laneConfig.WallsPerBiome + 1) - laneConfig.WallSpacing / 2

		-- Lane floor stripes, rails, side ground and cliffs.
		local stripe = 0
		for z = startZ, endZ - 0.01, laneConfig.WallSpacing do
			local length = math.min(laneConfig.WallSpacing, endZ - z)
			box(
				decor,
				"LaneFloor",
				Vector3.new(laneConfig.Width, 1, length),
				Vector3.new(0, -0.5, z + length / 2),
				shade(biome.Ground[stripe % 2 + 1], 0.92)
			)
			stripe += 1
		end
		local railIndex = 0
		for z = startZ, endZ - 0.01, 32 do
			local length = math.min(32, endZ - z)
			for _, side in { -1, 1 } do
				box(
					decor,
					"Rail",
					Vector3.new(4, 3, length),
					Vector3.new(side * (halfWidth + 2), 1.5, z + length / 2),
					biome.Rail[(railIndex + (side + 1) / 2) % 2 + 1]
				)
			end
			railIndex += 1
		end
		for _, side in { -1, 1 } do
			checker(
				decor,
				"SideGround",
				if side < 0 then -120 else 24,
				if side < 0 then -24 else 120,
				startZ,
				endZ,
				32,
				0,
				biome.Ground
			)
			local parity = biomeIndex
			for z = startZ + 16, endZ - 16, 32 do
				parity += 1
				cliffColumn(
					decor,
					Vector3.new(side * 136, 0, z),
					32,
					14,
					{ shade(biome.Rail[1], 0.85), shade(biome.Rail[2], 0.85) },
					biome.Ground[1],
					parity
				)
			end
			for z = startZ + 24, endZ - 24, 64 do
				local offset = if (z // 64) % 2 == 0 then 48 else 82
				tree(decor, Vector3.new(side * offset, 0, z + side * 12), biome.Tree.Trunk, biome.Tree.Leaves, 9)
			end
		end

		-- Biome entrance arch with its name (faces the runner).
		arch(decor, startZ + 4, halfWidth + 4, 22, biome.Rail[1], shade(biome.Rail[2], 0.9), {
			{ Name = "Title", Text = string.upper(biome.Name), Color = biome.Title, Height = 0.6 },
			{ Name = "Wins", Text = `🏆 {biome.WinsPerWall} per wall`, Color = WHITE, Height = 0.3 },
		})
	end

	-- The walls: three stacked boards each, with the Strength needed painted on the front.
	local plankHeight = laneConfig.WallHeight / 3
	for index = 1, wallCount do
		local biome = Formulas.GetBiome(Formulas.GetWallBiomeIndex(index))
		local z = Formulas.GetWallZ(index)
		local wall = folder(walls, "Wall_" .. index, "Model")
		wall:SetAttribute("Index", index)
		wall:SetAttribute("Toughness", Formulas.GetWallToughness(index))
		for plank = 1, 3 do
			local board = box(
				wall,
				"Board",
				Vector3.new(laneConfig.Width - 0.4, plankHeight - 0.15, 1.6),
				Vector3.new(0, plankHeight * (plank - 0.5), z),
				biome.Wall[(plank + index) % 2 + 1],
				{
					Material = biome.WallMaterial,
					Transparency = if biome.WallMaterial == Enum.Material.Glass then 0.15 else 0,
				}
			)
			if plank == 2 then
				surfaceText(board, Enum.NormalId.Front, {
					{
						Name = "Toughness",
						Text = `⚡ {NumberFormat.Abbreviate(Formulas.GetWallToughness(index))}`,
						Color = WHITE,
						Height = 0.9,
					},
				}, 12)
			end
		end
		if biome.WallAccent then
			box(
				wall,
				"Accent",
				Vector3.new(laneConfig.Width - 0.4, 0.4, 1.7),
				Vector3.new(0, plankHeight * 1.5 + plankHeight / 2 - 0.1, z),
				biome.WallAccent,
				{
					Material = Enum.Material.Neon,
					Studs = false,
				}
			)
		end
	end

	-- Distance markers on the left rail every 200 studs.
	for distance = 200, laneEndZ - pad.Z - 40, 200 do
		local z = pad.Z + distance
		local post = box(
			decor,
			"Marker",
			Vector3.new(1, 8, 6),
			Vector3.new(-(halfWidth + 2), 7, z),
			Color3.fromRGB(255, 255, 255)
		)
		surfaceText(post, Enum.NormalId.Right, {
			{ Name = "Distance", Text = `{distance} m`, Color = Color3.fromRGB(40, 40, 50), Height = 0.8 },
		}, 20)
	end

	-- Finish platform.
	local finishZ = Formulas.GetWallZ(wallCount) + laneConfig.FinishOvershoot + 10
	box(
		lane,
		"Finish",
		Vector3.new(laneConfig.Width, 1.2, 14),
		Vector3.new(0, 0.6, finishZ),
		Color3.fromRGB(255, 200, 40)
	)
	box(
		lane,
		"Trophy",
		Vector3.new(4, 6, 4),
		Vector3.new(0, 4.2, finishZ + 4),
		Color3.fromRGB(255, 220, 60),
		{ Material = Enum.Material.Neon, Studs = false }
	)
	arch(lane, finishZ + 8, halfWidth + 4, 22, Color3.fromRGB(255, 200, 40), Color3.fromRGB(200, 40, 40), {
		{ Name = "Title", Text = "YOU BROKE THEM ALL!", Color = Color3.fromRGB(255, 220, 60), Height = 0.9 },
	})
end

--------------------------------------------------------------------------------
-- Public
--------------------------------------------------------------------------------

-- Builds the whole hub into a new "Map" folder under `parent` and returns it.
function MapBuilder.Build(parent: Instance): Folder
	local root = Instance.new("Folder")
	root.Name = MapBuilder.ROOT_NAME

	buildGround(root)
	buildCliffs(root)
	buildDecor(root)
	buildSpawn(root)

	local zones = folder(root, "TrainingZones")
	for index, zone in Config.TrainingZones do
		buildZone(zones, zone, index)
	end

	local items = folder(root, "Items")
	for slot, item in Config.HandItems do
		buildPedestal(items, item, slot, false)
	end
	buildPedestal(items, Config.PremiumItem, #Config.HandItems + 1, true)

	local eggs = folder(root, "Eggs")
	for _, egg in Config.Eggs do
		buildEgg(eggs, egg)
	end
	buildShowcase(root)
	buildLeaderboards(root)
	buildLane(root)

	root.Parent = parent
	return root :: Folder
end

--[[
	Upgrades a map baked with the classic-stud fallback to the uploaded square-stud texture.
	Runs automatically at server start; you can also run it in edit mode from the Command Bar:
		require(game.ServerScriptService.Server.Modules.MapBuilder).ApplyStudTextures(workspace.Map)
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
