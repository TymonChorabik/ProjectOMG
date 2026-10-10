--[[
	ZoneController.luau
	Detects which dojo the player is standing in, tweens that dojo's lighting mood locally
	(time of day, ambient, atmosphere, colour grade) and shows a big entrance banner.
]]

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Formulas = require(Shared.Formulas)
local NumberFormat = require(Shared.NumberFormat)
local Signal = require(Shared.Signal)

local Popups = require(script.Parent.Parent.UI.Popups)

local ZoneController = {}

ZoneController.ZoneChanged = Signal.new() -- (dojoId)

local LIGHTING_INFO = TweenInfo.new(2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
local CHECK_INTERVAL = 0.4

local localPlayer = Players.LocalPlayer
local currentDojoId: string? = nil

function ZoneController.GetCurrentDojo(): string?
	return currentDojoId
end

local function applyLighting(dojo)
	local look = dojo.Lighting
	TweenService:Create(Lighting, LIGHTING_INFO, {
		ClockTime = look.ClockTime,
		Ambient = look.Ambient,
		OutdoorAmbient = look.OutdoorAmbient,
	}):Play()

	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
	if atmosphere then
		TweenService:Create(atmosphere, LIGHTING_INFO, {
			Color = look.AtmosphereColor,
			Decay = look.AtmosphereDecay,
			Density = look.AtmosphereDensity,
		}):Play()
	end

	local colorCorrection = Lighting:FindFirstChildOfClass("ColorCorrectionEffect")
	if colorCorrection then
		TweenService:Create(colorCorrection, LIGHTING_INFO, { TintColor = look.Tint }):Play()
	end
end

local function check()
	local character = localPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return
	end
	local position = root.Position
	local dojo = Formulas.GetDojoAtPosition(position.X, position.Y, position.Z)
	if not dojo or dojo.Id == currentDojoId then
		return
	end

	currentDojoId = dojo.Id
	applyLighting(dojo)
	Popups.Banner(
		string.upper(dojo.Name),
		`Training {NumberFormat.Multiplier(dojo.TrainingMultiplier)} power`,
		dojo.Colors.Accent
	)
	ZoneController.ZoneChanged:Fire(dojo.Id)
end

function ZoneController.Start()
	task.spawn(function()
		while true do
			check()
			task.wait(CHECK_INTERVAL)
		end
	end)
end

return ZoneController
