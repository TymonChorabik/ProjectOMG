--[[
	TrainingService.luau
	The +1 loop. Strength only comes from the dojos: "Hold E" on a training pad (StartTraining).
	While the player stays on that pad they earn one chop's Strength every IdleInterval with the
	zone's multiplier. One player per pad; walking off, dying, starting a run or losing access to
	the zone stops it. There is no click-to-train, so there is nothing to autoclick.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Formulas = require(Shared.Formulas)
local Remotes = require(Shared.Remotes)

local ActionService = require(script.Parent.ActionService)
local DataService = require(script.Parent.DataService)
local WorldService = require(script.Parent.WorldService)

local TrainingService = {}

local occupants: { [string]: Player } = {} -- stationId -> player training there
local playerStations: { [Player]: string } = {} -- player -> stationId

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

local function flatDistance(a: Vector3, b: Vector3): number
	return Vector3.new(a.X - b.X, 0, a.Z - b.Z).Magnitude
end

-- keepAttribute: the player is switching pads, so don't flash "Training" to nil.
local function stopTraining(player: Player, keepAttribute: boolean?)
	local stationId = playerStations[player]
	if not stationId then
		return
	end
	playerStations[player] = nil
	if occupants[stationId] == player then
		occupants[stationId] = nil
		local station = WorldService:GetStation(stationId)
		if station then
			station.Model:SetAttribute("Occupant", nil)
		end
	end
	if not keepAttribute then
		player:SetAttribute("Training", nil)
	end
end

-- The station the player is actively training at, or nil if they've left it.
local function getActiveStation(player: Player, data): WorldService.Station?
	local stationId = playerStations[player]
	local station = stationId and WorldService:GetStation(stationId)
	local root = getTrainingRoot(player)
	if
		not station
		or not root
		or not Formulas.IsZoneUnlocked(data, station.Zone.Id)
		or flatDistance(root.Position, station.Stand.Position) > Config.Training.StationRange
	then
		return nil
	end
	return station
end

local function grant(player: Player, data, zoneMultiplier: number)
	local friendBoost = player:GetAttribute("FriendBoost")
	local gain =
		Formulas.GetChopGain(data, zoneMultiplier, os.time(), if type(friendBoost) == "number" then friendBoost else 0)
	DataService:Increment(player, "Strength", gain)
	data.Stats.Chops += 1
	Remotes.ChopResult:FireClient(player, gain)
end

local function idleTick()
	local training = {}
	for player in playerStations do
		table.insert(training, player)
	end
	for _, player in training do
		local data = DataService:GetData(player)
		local station = data and getActiveStation(player, data)
		if data and station then
			grant(player, data, station.Zone.Multiplier)
		else
			stopTraining(player)
		end
	end
end

function TrainingService:Init()
	ActionService:Register("StartTraining", function(player, data, stationId)
		local station = stationId and WorldService:GetStation(stationId)
		if not station then
			return ActionService.Fail("That training pad doesn't exist.")
		end
		local zone = station.Zone
		if not Formulas.IsZoneUnlocked(data, zone.Id) then
			if zone.Pass then
				return ActionService.Fail(`Get the {zone.Name} pass to train here!`)
			end
			return ActionService.Fail(`Rebirth {zone.RequiredRebirths} times to train in the {zone.Name}!`)
		end
		local root = getTrainingRoot(player)
		if not root then
			return ActionService.Fail("You can't train right now.")
		end
		if flatDistance(root.Position, station.Stand.Position) > Config.Training.StationStartRange then
			return ActionService.Fail("Get closer to the training pad!")
		end
		local occupant = occupants[station.Id]
		if occupant and occupant ~= player and occupant.Parent then
			return ActionService.Fail("Someone is already training on this pad!")
		end

		stopTraining(player, true)
		occupants[station.Id] = player
		playerStations[player] = station.Id
		station.Model:SetAttribute("Occupant", player.UserId)
		player:SetAttribute("Training", station.Id)
		return ActionService.Success()
	end)

	ActionService:Register("StopTraining", function(player)
		stopTraining(player)
		return ActionService.Success()
	end)
end

function TrainingService:Start()
	task.spawn(function()
		while true do
			task.wait(Config.Training.IdleInterval)
			idleTick()
		end
	end)

	local function watch(player: Player)
		player.CharacterRemoving:Connect(function()
			stopTraining(player)
		end)
	end
	Players.PlayerAdded:Connect(watch)
	for _, player in Players:GetPlayers() do
		watch(player)
	end

	Players.PlayerRemoving:Connect(function(player)
		stopTraining(player)
	end)
end

return TrainingService
