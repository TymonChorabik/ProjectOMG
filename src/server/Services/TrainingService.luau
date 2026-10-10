--[[
	TrainingService.luau
	The +1 loop. Strength only comes from the training floors: stand on a floor's pad (like the
	throwing pads at the Stone Skipping ponds) and every IdleInterval you earn one chop's
	Strength times that floor's multiplier. Better floors unlock with rebirths or game passes.
	There's nothing to click, so there is nothing to autoclick: the server simply checks where
	each character is standing.

	The "Training" player attribute holds the floor id while someone is training; clients use it
	to play the chop animation.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Formulas = require(Shared.Formulas)
local Remotes = require(Shared.Remotes)

local DataService = require(script.Parent.DataService)
local WorldService = require(script.Parent.WorldService)

local TrainingService = {}

local function getTrainingRoot(player: Player): BasePart?
	if player:GetAttribute("Running") then
		return nil
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if humanoid and humanoid.Health > 0 and root and root:IsA("BasePart") then
		return root
	end
	return nil
end

local function grant(player: Player, data, zoneMultiplier: number)
	local friendBoost = player:GetAttribute("FriendBoost")
	local gain =
		Formulas.GetChopGain(data, zoneMultiplier, os.time(), if type(friendBoost) == "number" then friendBoost else 0)
	DataService:Increment(player, "Strength", gain)
	data.Stats.Chops += 1
	Remotes.ChopResult:FireClient(player, gain)
end

local function trainTick()
	for _, player in Players:GetPlayers() do
		local trainingZone: string? = nil
		local data = DataService:GetData(player)
		local root = getTrainingRoot(player)
		local pad = root and WorldService:GetTrainingPadAt(root.Position)
		if data and pad then
			local zone = Formulas.GetZone(pad.ZoneId)
			if zone and Formulas.IsZoneUnlocked(data, zone.Id) then
				trainingZone = zone.Id
				grant(player, data, zone.Multiplier)
			end
		end
		if player:GetAttribute("Training") ~= trainingZone then
			player:SetAttribute("Training", trainingZone)
		end
	end
end

function TrainingService:Init() end

function TrainingService:Start()
	task.spawn(function()
		while true do
			task.wait(Config.Training.IdleInterval)
			trainTick()
		end
	end)
end

return TrainingService
