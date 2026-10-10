--[[
	TrainingService.luau
	The +1 loop.
	• Manual chops: clients only say "I chopped"; the server finds the player's training zone and
	  computes the gain. A token bucket caps the rate, so autoclickers gain nothing extra.
	• Idle training: anyone standing in an unlocked training zone trains every IdleInterval.
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

type Bucket = { Tokens: number, Last: number }

local buckets: { [Player]: Bucket } = {}

local function consumeToken(player: Player): boolean
	local training = Config.Training
	local now = os.clock()
	local bucket = buckets[player]
	if not bucket then
		bucket = { Tokens = training.ServerBucketCapacity, Last = now }
		buckets[player] = bucket
	end
	bucket.Tokens = math.min(
		training.ServerBucketCapacity,
		bucket.Tokens + (now - bucket.Last) * training.ServerBucketRefillPerSecond
	)
	bucket.Last = now
	if bucket.Tokens < 1 then
		return false
	end
	bucket.Tokens -= 1
	return true
end

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

-- Grants one chop's Strength. Returns the gain (0 if nothing happened).
local function train(player: Player, idle: boolean): number
	local data = DataService:GetData(player)
	local root = getTrainingRoot(player)
	if not data or not root then
		return 0
	end
	local zoneMultiplier, zone = WorldService:GetZoneMultiplier(data, root.Position)
	if idle and (not zone or not Formulas.IsZoneUnlocked(data, zone.Id)) then
		return 0
	end
	local friendBoost = player:GetAttribute("FriendBoost")
	local gain =
		Formulas.GetChopGain(data, zoneMultiplier, os.time(), if type(friendBoost) == "number" then friendBoost else 0)
	DataService:Increment(player, "Strength", gain)
	data.Stats.Chops += 1
	Remotes.ChopResult:FireClient(player, gain, idle)
	return gain
end

function TrainingService:Init() end

function TrainingService:Start()
	Remotes.Chop.OnServerEvent:Connect(function(player)
		if consumeToken(player) then
			train(player, false)
		end
	end)

	task.spawn(function()
		while true do
			task.wait(Config.Training.IdleInterval)
			for _, player in Players:GetPlayers() do
				train(player, true)
			end
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		buckets[player] = nil
	end)
end

return TrainingService
