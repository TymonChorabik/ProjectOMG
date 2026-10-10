--[[
	PetModels.luau
	Builds cute blocky pet models from parts (no meshes or uploads needed). Used by the map
	(showcase pet), pets following players and the hatch / inventory previews.

	PetModels.Build(petId) → Model with an invisible "Root" PrimaryPart at the pet's centre.
	All parts are anchored and non-colliding; move the pet with Model:PivotTo().
	Pets face -Z (Roblox's forward).
]]

local Config = require(script.Parent.Config)

local PetModels = {}

local BLACK = Color3.fromRGB(25, 25, 30)
local WHITE = Color3.fromRGB(255, 255, 255)
local PINK = Color3.fromRGB(255, 150, 170)
local GOLD = Color3.fromRGB(255, 205, 50)

type Builder = {
	model: Model,
	add: (
		name: string,
		size: Vector3,
		offset: CFrame,
		color: Color3,
		shape: Enum.PartType?,
		material: Enum.Material?
	) -> BasePart,
	wedge: (name: string, size: Vector3, offset: CFrame, color: Color3) -> BasePart,
}

local function newBuilder(name: string, scale: number): Builder
	local model = Instance.new("Model")
	model.Name = name

	local root = Instance.new("Part")
	root.Name = "Root"
	root.Size = Vector3.new(1, 1, 1)
	root.Transparency = 1
	root.Anchored = true
	root.CanCollide = false
	root.CanQuery = false
	root.CanTouch = false
	root.Parent = model
	model.PrimaryPart = root

	local function finish(part: BasePart, name: string, size: Vector3, offset: CFrame, color: Color3)
		part.Name = name
		part.Size = size * scale
		part.CFrame = CFrame.new(offset.Position * scale) * offset.Rotation
		part.Color = color
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.CastShadow = false
		part.TopSurface = Enum.SurfaceType.Smooth
		part.BottomSurface = Enum.SurfaceType.Smooth
		part.Parent = model
		return part
	end

	return {
		model = model,
		add = function(name, size, offset, color, shape, material)
			local part = Instance.new("Part")
			part.Shape = shape or Enum.PartType.Block
			part.Material = material or Enum.Material.SmoothPlastic
			return finish(part, name, size, offset, color)
		end,
		wedge = function(name, size, offset, color)
			local part = Instance.new("WedgePart")
			part.Material = Enum.Material.SmoothPlastic
			return finish(part, name, size, offset, color)
		end,
	}
end

local function face(b: Builder, headCenter: Vector3, headSize: Vector3)
	local front = headCenter.Z - headSize.Z / 2 - 0.02
	for _, side in { -1, 1 } do
		b.add(
			"Eye",
			Vector3.new(0.28, 0.38, 0.05),
			CFrame.new(side * headSize.X * 0.22, headCenter.Y + 0.1, front),
			BLACK
		)
		b.add(
			"EyeShine",
			Vector3.new(0.1, 0.1, 0.05),
			CFrame.new(side * headSize.X * 0.22 + 0.06, headCenter.Y + 0.2, front - 0.02),
			WHITE
		)
		b.add(
			"Blush",
			Vector3.new(0.22, 0.1, 0.05),
			CFrame.new(side * headSize.X * 0.34, headCenter.Y - 0.18, front),
			PINK
		)
	end
end

local function legs(b: Builder, body: Vector3, bodyY: number, color: Color3)
	for _, x in { -1, 1 } do
		for _, z in { -1, 1 } do
			b.add(
				"Leg",
				Vector3.new(0.4, 0.5, 0.4),
				CFrame.new(x * (body.X / 2 - 0.25), bodyY - body.Y / 2 - 0.2, z * (body.Z / 2 - 0.3)),
				color
			)
		end
	end
end

local Shapes = {}

-- Generic four-legged animal: body + big head; extras add ears/tails per species.
local function quadruped(b: Builder, def, ears: (Builder, Vector3, Vector3) -> ())
	local body = Vector3.new(1.5, 1.1, 1.7)
	local head = Vector3.new(1.5, 1.35, 1.3)
	local headCenter = Vector3.new(0, 0.75, -0.75)
	b.add("Body", body, CFrame.new(0, -0.15, 0.25), def.Body)
	b.add("Belly", Vector3.new(1.0, 0.7, 1.2), CFrame.new(0, -0.35, 0.2) * CFrame.new(0, 0, 0), def.Accent)
	b.add("Head", head, CFrame.new(headCenter), def.Body)
	b.add(
		"Snout",
		Vector3.new(0.6, 0.35, 0.2),
		CFrame.new(0, headCenter.Y - 0.3, headCenter.Z - head.Z / 2 - 0.08),
		def.Accent
	)
	face(b, headCenter, head)
	legs(b, body, -0.15, def.Body)
	ears(b, headCenter, head)
end

Shapes.Dog = function(b: Builder, def)
	quadruped(b, def, function(builder, headCenter, head)
		for _, side in { -1, 1 } do
			builder.add(
				"Ear",
				Vector3.new(0.35, 0.8, 0.3),
				CFrame.new(side * (head.X / 2 + 0.1), headCenter.Y + 0.15, headCenter.Z)
					* CFrame.Angles(0, 0, math.rad(side * 15)),
				def.Accent
			)
		end
		builder.add(
			"Tail",
			Vector3.new(0.25, 0.25, 0.7),
			CFrame.new(0, 0.15, 1.25) * CFrame.Angles(math.rad(35), 0, 0),
			def.Body
		)
	end)
end

Shapes.Cat = function(b: Builder, def)
	quadruped(b, def, function(builder, headCenter, head)
		for _, side in { -1, 1 } do
			builder.wedge(
				"Ear",
				Vector3.new(0.35, 0.5, 0.4),
				CFrame.new(side * head.X * 0.3, headCenter.Y + head.Y / 2 + 0.25, headCenter.Z),
				def.Body
			)
		end
		builder.add(
			"Tail",
			Vector3.new(0.22, 0.22, 1.1),
			CFrame.new(0.2, 0.35, 1.4) * CFrame.Angles(math.rad(50), 0, 0),
			def.Accent
		)
	end)
end

Shapes.Bunny = function(b: Builder, def)
	quadruped(b, def, function(builder, headCenter, head)
		for _, side in { -1, 1 } do
			builder.add(
				"Ear",
				Vector3.new(0.3, 1.1, 0.2),
				CFrame.new(side * head.X * 0.22, headCenter.Y + head.Y / 2 + 0.5, headCenter.Z + 0.1)
					* CFrame.Angles(0, 0, math.rad(side * -8)),
				def.Body
			)
			builder.add(
				"EarInner",
				Vector3.new(0.16, 0.8, 0.05),
				CFrame.new(side * head.X * 0.22, headCenter.Y + head.Y / 2 + 0.5, headCenter.Z - 0.01)
					* CFrame.Angles(0, 0, math.rad(side * -8)),
				def.Accent
			)
		end
		builder.add("Tail", Vector3.new(0.5, 0.5, 0.5), CFrame.new(0, 0, 1.15), WHITE, Enum.PartType.Ball)
	end)
end

Shapes.Bear = function(b: Builder, def)
	quadruped(b, def, function(builder, headCenter, head)
		for _, side in { -1, 1 } do
			builder.add(
				"Ear",
				Vector3.new(0.5, 0.5, 0.5),
				CFrame.new(side * head.X * 0.4, headCenter.Y + head.Y / 2, headCenter.Z),
				def.Accent,
				Enum.PartType.Ball
			)
			builder.add(
				"EyePatch",
				Vector3.new(0.42, 0.5, 0.04),
				CFrame.new(side * head.X * 0.22, headCenter.Y + 0.08, headCenter.Z - head.Z / 2 + 0.005),
				def.Accent
			)
		end
	end)
end

Shapes.Lion = function(b: Builder, def)
	b.add("Mane", Vector3.new(2.1, 2.0, 0.6), CFrame.new(0, 0.75, -0.25), def.Accent)
	quadruped(b, def, function(builder, headCenter, head)
		for _, side in { -1, 1 } do
			builder.add(
				"Ear",
				Vector3.new(0.4, 0.4, 0.3),
				CFrame.new(side * head.X * 0.4, headCenter.Y + head.Y / 2, headCenter.Z),
				def.Body,
				Enum.PartType.Ball
			)
		end
		builder.add(
			"Crown",
			Vector3.new(1.0, 0.35, 0.8),
			CFrame.new(0, headCenter.Y + head.Y / 2 + 0.2, headCenter.Z),
			GOLD,
			nil,
			Enum.Material.Neon
		)
		builder.add(
			"Tail",
			Vector3.new(0.2, 0.2, 1.0),
			CFrame.new(0, 0.2, 1.3) * CFrame.Angles(math.rad(40), 0, 0),
			def.Body
		)
	end)
end

Shapes.Unicorn = function(b: Builder, def)
	quadruped(b, def, function(builder, headCenter, head)
		builder.wedge(
			"Horn",
			Vector3.new(0.25, 0.9, 0.3),
			CFrame.new(0, headCenter.Y + head.Y / 2 + 0.4, headCenter.Z - 0.2),
			GOLD
		)
		builder.add(
			"Mane",
			Vector3.new(0.3, 1.2, 1.4),
			CFrame.new(0, headCenter.Y + 0.2, headCenter.Z + 0.7),
			def.Accent
		)
		for _, side in { -1, 1 } do
			builder.wedge(
				"Ear",
				Vector3.new(0.25, 0.4, 0.3),
				CFrame.new(side * head.X * 0.32, headCenter.Y + head.Y / 2 + 0.15, headCenter.Z + 0.2),
				def.Body
			)
		end
		builder.add(
			"Tail",
			Vector3.new(0.3, 0.3, 1.0),
			CFrame.new(0, 0.1, 1.3) * CFrame.Angles(math.rad(30), 0, 0),
			def.Accent
		)
	end)
end

Shapes.Bird = function(b: Builder, def)
	local bodyCenter = Vector3.new(0, 0, 0)
	b.add("Body", Vector3.new(1.7, 1.9, 1.6), CFrame.new(bodyCenter), def.Body, Enum.PartType.Ball)
	b.add("Belly", Vector3.new(1.1, 1.3, 0.4), CFrame.new(0, -0.15, -0.65), def.Accent)
	b.wedge("Beak", Vector3.new(0.3, 0.3, 0.4), CFrame.new(0, 0.15, -0.95) * CFrame.Angles(math.rad(-90), 0, 0), GOLD)
	for _, side in { -1, 1 } do
		b.add("Eye", Vector3.new(0.3, 0.35, 0.05), CFrame.new(side * 0.35, 0.45, -0.8), BLACK)
		b.add(
			"Wing",
			Vector3.new(0.2, 1.0, 1.0),
			CFrame.new(side * 0.9, 0, 0.1) * CFrame.Angles(0, 0, math.rad(side * 20)),
			def.Accent
		)
		b.add("Foot", Vector3.new(0.3, 0.2, 0.4), CFrame.new(side * 0.35, -1.0, -0.1), GOLD)
	end
end

Shapes.Dragon = function(b: Builder, def)
	quadruped(b, def, function(builder, headCenter, head)
		for _, side in { -1, 1 } do
			builder.wedge(
				"Horn",
				Vector3.new(0.22, 0.6, 0.3),
				CFrame.new(side * head.X * 0.3, headCenter.Y + head.Y / 2 + 0.25, headCenter.Z + 0.2),
				def.Accent
			)
			builder.add(
				"Wing",
				Vector3.new(1.4, 0.15, 1.0),
				CFrame.new(side * 1.3, 0.55, 0.3) * CFrame.Angles(0, 0, math.rad(side * 25)),
				def.Accent
			)
		end
		for index = 0, 2 do
			builder.wedge("Spike", Vector3.new(0.15, 0.35, 0.35), CFrame.new(0, 0.55, -0.1 + index * 0.45), def.Accent)
		end
		builder.add(
			"Tail",
			Vector3.new(0.35, 0.35, 1.2),
			CFrame.new(0, -0.1, 1.5) * CFrame.Angles(math.rad(20), 0, 0),
			def.Body
		)
	end)
end

local function addGlow(model: Model, color: Color3)
	local root = model.PrimaryPart :: BasePart
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = 8
	light.Brightness = 1.2
	light.Parent = root

	local sparkles = Instance.new("ParticleEmitter")
	sparkles.Name = "Sparkles"
	sparkles.Texture = Config.Assets.Particles.Sparkle
	sparkles.Color = ColorSequence.new(WHITE, color)
	sparkles.LightEmission = 1
	sparkles.Size = NumberSequence.new(0.4, 0)
	sparkles.Lifetime = NumberRange.new(0.6, 1.2)
	sparkles.Rate = 6
	sparkles.Speed = NumberRange.new(0.5, 1.5)
	sparkles.SpreadAngle = Vector2.new(180, 180)
	sparkles.Parent = root
end

-- Builds the pet at the origin (feet ~1.4 studs below Root, times scale). Unknown ids build a Puppy.
function PetModels.Build(petId: string, scale: number?): Model
	local def = Config.Pets[petId] or Config.Pets.Puppy
	local builder = newBuilder(petId, scale or 1)
	local shape = Shapes[def.Shape] or Shapes.Dog
	shape(builder, def)
	if def.Glow then
		addGlow(builder.model, def.Accent)
	end
	builder.model:SetAttribute("PetId", petId)
	return builder.model
end

-- Size helper for cameras / ViewportFrames.
PetModels.Height = 2.8

return PetModels
