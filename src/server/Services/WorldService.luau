--[[
	WorldService.luau
	Loads the hub map and lighting, and answers "where is this player?" for other services.

	The map lives in Workspace.Map (baked from src/workspace/Map/*.model.json, so you can see and
	edit it in Studio). If it's missing, MapBuilder generates it from Config at startup.
	Gameplay only reads: TrainingZones/Zone_<Id>/TrainPad, Lane/LaunchPad and Lane/Walls.
]]

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local TrainingPads = require(Shared.TrainingPads)

local MapBuilder = require(script.Parent.Parent.Modules.MapBuilder)

local WorldService = {}

local trainingPads: { TrainingPads.Pad } = {}
local padPart: BasePart? = nil

local function cleanupTemplate()
	-- The default Baseplate template would z-fight with the hub ground.
	local baseplate = workspace:FindFirstChild("Baseplate")
	if baseplate and baseplate:IsA("BasePart") then
		baseplate:Destroy()
	end
	for _, child in workspace:GetChildren() do
		if child:IsA("SpawnLocation") then
			child:Destroy()
		end
	end
end

local function ensure(className: string): Instance
	local existing = Lighting:FindFirstChildOfClass(className)
	if existing then
		return existing
	end
	local instance = Instance.new(className)
	instance.Parent = Lighting
	return instance
end

local function setupLighting()
	-- Bright, saturated simulator daylight.
	Lighting.ClockTime = 14
	Lighting.Brightness = 2.6
	Lighting.Ambient = Color3.fromRGB(120, 120, 130)
	Lighting.OutdoorAmbient = Color3.fromRGB(160, 160, 170)
	Lighting.EnvironmentDiffuseScale = 0.7
	Lighting.EnvironmentSpecularScale = 0.5
	Lighting.GlobalShadows = true
	Lighting.ShadowSoftness = 0.3

	local atmosphere = ensure("Atmosphere") :: Atmosphere
	atmosphere.Density = 0.25
	atmosphere.Offset = 0.15
	atmosphere.Color = Color3.fromRGB(200, 225, 255)
	atmosphere.Decay = Color3.fromRGB(150, 190, 240)
	atmosphere.Glare = 0
	atmosphere.Haze = 0.6

	local bloom = ensure("BloomEffect") :: BloomEffect
	bloom.Intensity = 0.5
	bloom.Size = 24
	bloom.Threshold = 1.8

	local color = ensure("ColorCorrectionEffect") :: ColorCorrectionEffect
	color.Saturation = 0.2
	color.Contrast = 0.06
	color.Brightness = 0.02
	color.TintColor = Color3.fromRGB(255, 252, 245)
end

-- The training pad someone at `position` is standing on, if any.
function WorldService:GetTrainingPadAt(position: Vector3): TrainingPads.Pad?
	return TrainingPads.At(trainingPads, position)
end

function WorldService:GetPadPosition(): Vector3
	return if padPart then padPart.Position else Config.Lane.PadPosition
end

function WorldService:GetPadRadius(): number
	local radius = padPart and padPart:GetAttribute("Radius")
	return if type(radius) == "number" then radius else Config.Lane.PadRadius
end

function WorldService:Init()
	if Config.Assets.StudTexture == "" then
		warn(
			"[Kung Fu Chop!] Using classic round-stud fallback. Upload assets/textures/stud_overlay.png and set "
				.. "Config.Assets.StudTexture for the square stud look (see README → Stud textures)."
		)
	end
	cleanupTemplate()
	setupLighting()

	local root = workspace:FindFirstChild(MapBuilder.ROOT_NAME) or MapBuilder.Build(workspace)
	local upgraded = MapBuilder.ApplyStudTextures(root)
	if upgraded > 0 then
		print(`[Kung Fu Chop!] Applied square stud texture to {upgraded} parts`)
	end

	trainingPads = TrainingPads.Collect(root)
	for _, zone in Config.TrainingZones do
		local found = false
		for _, pad in trainingPads do
			found = found or pad.ZoneId == zone.Id
		end
		if not found then
			warn(`[Kung Fu Chop!] Training floor "{zone.Id}" has no TrainPad in Workspace.Map`)
		end
	end

	local lane = root:FindFirstChild("Lane")
	local pad = lane and lane:FindFirstChild("LaunchPad")
	if pad and pad:IsA("BasePart") then
		padPart = pad
	else
		warn("[Kung Fu Chop!] Workspace.Map.Lane.LaunchPad is missing; using Config.Lane.PadPosition")
	end
end

function WorldService:Start() end

return WorldService
