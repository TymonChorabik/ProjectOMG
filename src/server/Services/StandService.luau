--[[
	StandService.luau
	Registry of breaking stands + authoritative smash validation.

	Objects break per player: the server validates power, range, dojo access and a per-player
	cooldown, awards coins, and tells every client. The breaker's client shatters its local copy
	(hidden until respawn); everyone else just sees an impact burst.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Formulas = require(Shared.Formulas)
local Remotes = require(Shared.Remotes)

local DataService = require(script.Parent.DataService)

local StandService = {}

local stands: { [string]: any } = {}
local cooldowns: { [Player]: { [string]: number } } = {}

-- Server leeway so a client respawn timer that finishes a few frames early isn't rejected.
local COOLDOWN_LEEWAY = 0.2

function StandService:Register(info)
	assert(stands[info.Id] == nil, "Duplicate stand id " .. info.Id)
	stands[info.Id] = info
end

function StandService:GetStand(standId: string)
	return stands[standId]
end

function StandService:GetAll()
	return stands
end

-- Returns true if the stand was smashed.
function StandService:TrySmash(player: Player, standId: string): boolean
	local stand = stands[standId]
	if not stand then
		return false
	end

	local data = DataService:GetData(player)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not data or not root then
		return false
	end

	if not Formulas.IsDojoUnlocked(data, stand.DojoId) then
		return false
	end

	-- Range check (horizontal distance to the object's edge, plus vertical sanity check).
	local offset = root.Position - stand.Position
	local horizontal = Vector3.new(offset.X, 0, offset.Z).Magnitude - stand.Radius
	if horizontal > Config.Smash.Range + Config.Smash.RangeTolerance or math.abs(offset.Y) > 25 then
		return false
	end

	local now = os.clock()
	local playerCooldowns = cooldowns[player]
	if not playerCooldowns then
		playerCooldowns = {}
		cooldowns[player] = playerCooldowns
	end
	if (playerCooldowns[standId] or 0) > now then
		return false
	end

	if data.Power < stand.Def.RequiredPower then
		return false
	end

	playerCooldowns[standId] = now + (stand.Def.Respawn or Config.Smash.DefaultRespawn) - COOLDOWN_LEEWAY

	local coins = Formulas.GetSmashReward(data, stand.ObjectId)
	DataService:Increment(player, "Coins", coins)
	data.Stats.ObjectsSmashed += 1

	Remotes.ObjectSmashed:FireAllClients(player, standId, coins)
	return true
end

function StandService:Init() end

function StandService:Start()
	Players.PlayerRemoving:Connect(function(player)
		cooldowns[player] = nil
	end)
end

return StandService
