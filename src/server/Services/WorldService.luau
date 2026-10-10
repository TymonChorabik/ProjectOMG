--[[
	WorldService.luau
	Loads the hub map and lighting, and answers "where is this player?" for other services.

	The map lives in Workspace.Map (baked from src/workspace/Map/*.model.json, so you can see and
	edit it in Studio). If it's missing, MapBuilder generates it from Config at startup.
	Gameplay only reads: TrainingZones/Zone_<Id>/Area, TrainingZones/Zone_<Id>/Stations,
	Lane/LaunchPad and Lane/Walls.
]]

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Formulas = require(Shared.Formulas)

local MapBuilder = require(script.Parent.Parent.Modules.MapBuilder)

local WorldService = {}

type ZoneArea = { Zone: any, Area: BasePart }
-- A wooden dummy players "Hold E" at; they train standing on Stand, facing the dummy.
export type Station = { Id: string, Zone: any, Model: Model, Stand: BasePart }

local zones: { ZoneArea } = {}
local stations: { [string]: Station } = {}
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

local function pointInPart(part: BasePart, position: Vector3): boolean
	local localPoint = part.CFrame:PointToObjectSpace(position)
	local half = part.Size / 2
	return math.abs(localPoint.X) <= half.X and math.abs(localPoint.Y) <= half.Y and math.abs(localPoint.Z) <= half.Z
end

-- The training zone containing `position`, or nil.
function WorldService:GetZoneAt(position: Vector3)
	for _, entry in zones do
		if entry.Area.Parent and pointInPart(entry.Area, position) then
			return entry.Zone
		end
	end
	return nil
end

-- Zone multiplier for a player standing at `position` (1 outside zones or in locked ones).
function WorldService:GetZoneMultiplier(data, position: Vector3): (number, any)
	local zone = self:GetZoneAt(position)
	if zone and Formulas.IsZoneUnlocked(data, zone.Id) then
		return zone.Multiplier, zone
	end
	return 1, zone
end

function WorldService:GetStation(stationId: string): Station?
	return stations[stationId]
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

	local zonesFolder = root:FindFirstChild("TrainingZones")
	for _, zone in Config.TrainingZones do
		local model = zonesFolder and zonesFolder:FindFirstChild("Zone_" .. zone.Id)
		local area = model and model:FindFirstChild("Area")
		if area and area:IsA("BasePart") then
			table.insert(zones, { Zone = zone, Area = area })
		else
			warn(`[Kung Fu Chop!] Training zone "{zone.Id}" is missing from Workspace.Map`)
		end
		local stationFolder = model and model:FindFirstChild("Stations")
		if stationFolder then
			for _, station in stationFolder:GetChildren() do
				local stationId = station:GetAttribute("StationId")
				local stand = station:FindFirstChild("Stand")
				if station:IsA("Model") and type(stationId) == "string" and stand and stand:IsA("BasePart") then
					stations[stationId] = { Id = stationId, Zone = zone, Model = station, Stand = stand }
				end
			end
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
