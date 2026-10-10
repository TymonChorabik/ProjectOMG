--[[
	ItemModels.luau
	Blocky display models for the hand items (wraps, gloves, gauntlets...) shown on the
	pedestals and in the inventory. Built from parts: a chunky fist plus a wrist band.

	ItemModels.Build(itemDef) → Model with an invisible "Root" PrimaryPart at its centre.
]]

local Config = require(script.Parent.Config)

local ItemModels = {}

local function shade(color: Color3, amount: number): Color3
	return Color3.new(color.R * amount, color.G * amount, color.B * amount)
end

function ItemModels.Build(item): Model
	local model = Instance.new("Model")
	model.Name = item.Id

	local function part(name: string, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material?)
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size
		p.CFrame = cframe
		p.Color = color
		p.Material = material or Enum.Material.SmoothPlastic
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.Parent = model
		return p
	end

	local root = part("Root", Vector3.new(1, 1, 1), CFrame.new(), item.Color)
	root.Transparency = 1
	model.PrimaryPart = root

	local main = item.Color
	local dark = shade(main, 0.75)
	local accentMaterial = if item.Glow then Enum.Material.Neon else Enum.Material.SmoothPlastic

	-- Fist (knuckles face -Z).
	part("Palm", Vector3.new(2.2, 2.0, 1.8), CFrame.new(0, 0.2, 0), main)
	for index = 0, 3 do
		part("Finger", Vector3.new(0.5, 0.55, 0.5), CFrame.new(-0.78 + index * 0.52, 0.75, -1.0), dark)
	end
	part("Thumb", Vector3.new(0.5, 1.1, 0.55), CFrame.new(-1.2, 0.1, -0.55), dark)
	part("Cuff", Vector3.new(2.3, 0.7, 1.9), CFrame.new(0, -1.05, 0), shade(main, 0.6), accentMaterial)
	part("Wrist", Vector3.new(1.7, 1.0, 1.4), CFrame.new(0, -1.85, 0), shade(main, 0.9))

	if item.Glow then
		local light = Instance.new("PointLight")
		light.Color = main
		light.Range = 10
		light.Brightness = 1.5
		light.Parent = root

		local sparkles = Instance.new("ParticleEmitter")
		sparkles.Name = "Sparkles"
		sparkles.Texture = Config.Assets.Particles.Sparkle
		sparkles.Color = ColorSequence.new(Color3.new(1, 1, 1), main)
		sparkles.LightEmission = 1
		sparkles.Size = NumberSequence.new(0.5, 0)
		sparkles.Lifetime = NumberRange.new(0.5, 1)
		sparkles.Rate = 8
		sparkles.Speed = NumberRange.new(1, 2)
		sparkles.SpreadAngle = Vector2.new(180, 180)
		sparkles.Parent = root
	end

	model:SetAttribute("ItemId", item.Id)
	return model
end

return ItemModels
