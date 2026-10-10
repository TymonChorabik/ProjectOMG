--[[
	WorldService.luau
	Loads the dojo map, the breaking stands and the lighting/post-processing stack.

	The map lives in Workspace.Dojos (baked from src/workspace/Dojos/*.model.json, so you can see
	and edit it in Studio). If it's missing, MapBuilder generates it from Config at startup.
	Gameplay only reads stand attributes and each dojo's ArrivalPad, so decorate freely.
]]

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)

local BreakableBuilder = require(script.Parent.Parent.Modules.BreakableBuilder)
local MapBuilder = require(script.Parent.Parent.Modules.MapBuilder)
local StandService = require(script.Parent.StandService)

local WorldService = {}

local arrivals: { [string]: CFrame } = {}

function WorldService:GetArrivalCFrame(dojoId: string): CFrame?
	return arrivals[dojoId]
end

local function cleanupTemplate()
	-- The default Baseplate template would z-fight with the Starter Dojo floor.
	local baseplate = workspace:FindFirstChild("Baseplate")
	if baseplate and baseplate:IsA("BasePart") then
		baseplate:Destroy()
	end
	for _, child in workspace:GetChildren() do
		if child:IsA("SpawnLocation") and child.Name ~= "DojoSpawn" then
			child:Destroy()
		end
	end
end

--------------------------------------------------------------------------------
-- Lighting & post-processing
--------------------------------------------------------------------------------

local function ensure(className: string, name: string): Instance
	local existing = Lighting:FindFirstChildOfClass(className)
	if existing then
		return existing
	end
	local instance = Instance.new(className)
	instance.Name = name
	instance.Parent = Lighting
	return instance
end

local function setupLighting()
	local look = Config.Dojos[1].Lighting
	Lighting.ClockTime = look.ClockTime
	Lighting.Ambient = look.Ambient
	Lighting.OutdoorAmbient = look.OutdoorAmbient
	Lighting.Brightness = 2.4
	Lighting.EnvironmentDiffuseScale = 0.6
	Lighting.EnvironmentSpecularScale = 0.6
	Lighting.GlobalShadows = true
	Lighting.ShadowSoftness = 0.25

	local atmosphere = ensure("Atmosphere", "Atmosphere") :: Atmosphere
	atmosphere.Density = look.AtmosphereDensity
	atmosphere.Offset = 0.1
	atmosphere.Color = look.AtmosphereColor
	atmosphere.Decay = look.AtmosphereDecay
	atmosphere.Glare = 0.2
	atmosphere.Haze = 1.2

	local bloom = ensure("BloomEffect", "Bloom") :: BloomEffect
	bloom.Intensity = 0.7
	bloom.Size = 28
	bloom.Threshold = 1.6

	local color = ensure("ColorCorrectionEffect", "ColorCorrection") :: ColorCorrectionEffect
	color.Saturation = 0.18
	color.Contrast = 0.08
	color.Brightness = 0.02
	color.TintColor = look.Tint

	local rays = ensure("SunRaysEffect", "SunRays") :: SunRaysEffect
	rays.Intensity = 0.06
	rays.Spread = 0.6
end

--------------------------------------------------------------------------------
-- Map
--------------------------------------------------------------------------------

local function loadMap()
	local root = workspace:FindFirstChild(MapBuilder.ROOT_NAME)
	if not root then
		root = MapBuilder.Build(workspace)
	end

	local upgraded = MapBuilder.ApplyStudTextures(root)
	if upgraded > 0 then
		print(`[Kung Fu Chop!] Applied square stud texture to {upgraded} parts`)
	end

	for _, dojoModel in root:GetChildren() do
		local dojoId = dojoModel:GetAttribute("DojoId") or dojoModel.Name
		local arrival = MapBuilder.GetArrivalCFrame(dojoModel)
		if arrival then
			arrivals[dojoId] = arrival
		end
	end

	for _, descendant in root:GetDescendants() do
		if descendant:IsA("Model") and descendant:GetAttribute("StandId") ~= nil then
			BreakableBuilder.ApplyCustomModel(descendant)
			local info = BreakableBuilder.Rig(descendant)
			if info then
				StandService:Register(info)
			end
		end
	end

	for _, dojo in Config.Dojos do
		if not arrivals[dojo.Id] then
			warn(`[Kung Fu Chop!] Dojo "{dojo.Id}" has no {MapBuilder.ARRIVAL_PAD} in Workspace.{MapBuilder.ROOT_NAME}`)
		end
	end
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
	loadMap()
	assert(next(StandService:GetAll()) ~= nil, "No breaking stands found in the map")
end

function WorldService:Start() end

return WorldService
