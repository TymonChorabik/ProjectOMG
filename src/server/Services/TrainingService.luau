--[[
	TrainingService.luau
	The +1 loop. Clients only ever say "I chopped" (optionally "...at this stand"); every number
	is computed here. A per-player token bucket caps chop rate, so autoclickers and remote spam
	gain nothing beyond the legit maximum.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Formulas = require(Shared.Formulas)
local Remotes = require(Shared.Remotes)

local DataService = require(script.Parent.DataService)
local StandService = require(script.Parent.StandService)

local TrainingService = {}

type Bucket = { Tokens: number, Last: number }

local buckets: { [Player]: Bucket } = {}
local rng = Random.new()

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

-- Dojo training bonus, only if the player is standing in a dojo they've unlocked.
local function getTrainingMultiplier(data, position: Vector3): number
	local dojo = Formulas.GetDojoAtPosition(position.X, position.Y, position.Z)
	if dojo and Formulas.IsDojoUnlocked(data, dojo.Id) then
		return dojo.TrainingMultiplier
	end
	return 1
end

local function onChop(player: Player, standId: any)
	if standId ~= nil and (type(standId) ~= "string" or #standId > 64) then
		return
	end

	local data = DataService:GetData(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not data or not humanoid or not root or humanoid.Health <= 0 then
		return
	end
	if not consumeToken(player) then
		return
	end

	local gain = Formulas.GetChopGain(data, getTrainingMultiplier(data, root.Position))
	local isCrit = rng:NextNumber() < Formulas.GetCritChance(data)
	if isCrit then
		gain *= Config.Training.CritMultiplier
	end

	DataService:Increment(player, "Power", gain)

	local stats = data.Stats
	stats.TotalChops += 1
	stats.TotalPowerEarned += gain
	stats.BestChop = math.max(stats.BestChop, gain)

	Remotes.ChopResult:FireClient(player, gain, isCrit)

	if standId then
		StandService:TrySmash(player, standId)
	end
end

function TrainingService:Init() end

function TrainingService:Start()
	Remotes.Chop.OnServerEvent:Connect(onChop)
	Players.PlayerRemoving:Connect(function(player)
		buckets[player] = nil
	end)
end

return TrainingService
