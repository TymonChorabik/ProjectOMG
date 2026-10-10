--[[
	LaneService.luau
	The Board Wall smash. A player on the launch pad asks to start a run; the server decides how
	many walls their Strength breaks (Formulas.GetRunResult), blocks new runs and training while
	the client plays the charge animation, then pays the Wins when the run ends.
	Auto Smash (game pass) runs can start from anywhere: the run always launches from the pad
	and ends back on it, so owners farm Wins hands-free.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Formulas = require(Shared.Formulas)
local NumberFormat = require(Shared.NumberFormat)
local Remotes = require(Shared.Remotes)

local DataService = require(script.Parent.DataService)
local ProgressService = require(script.Parent.ProgressService)
local WorldService = require(script.Parent.WorldService)

local LaneService = {}

local readyAt: { [Player]: number } = {}

local function fail(message: string)
	return { ok = false, message = message }
end

local function startRun(player: Player, auto: any)
	local data = DataService:GetData(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not data or not humanoid or humanoid.Health <= 0 or not root or not root:IsA("BasePart") then
		return fail("You can't smash right now.")
	end
	if player:GetAttribute("Running") or os.clock() < (readyAt[player] or 0) then
		return fail("Catch your breath first!")
	end

	local autoRun = auto == true and Formulas.HasPass(data, "AutoSmash")
	local pad = WorldService:GetPadPosition()
	local offset = root.Position - pad
	local onPad = Vector3.new(offset.X, 0, offset.Z).Magnitude <= WorldService:GetPadRadius() + 4
		and math.abs(offset.Y) <= 12
	if not onPad and not autoRun then
		return fail("Stand on the launch pad first!")
	end

	local strength = data.Strength
	local walls, distance = Formulas.GetRunResult(strength)
	local wins = math.floor(Formulas.GetRunWins(walls) * Formulas.GetWinsMultiplier(data, os.time()))
	local duration = Formulas.GetRunDuration(distance)

	player:SetAttribute("Running", true)
	readyAt[player] = os.clock() + duration + Config.Lane.Cooldown

	task.delay(duration, function()
		if player.Parent ~= Players then
			return
		end
		player:SetAttribute("Running", nil)
		local current = DataService:GetData(player)
		if not current then
			return
		end
		current.Stats.Runs += 1
		current.Stats.WallsBroken += walls
		if distance > current.BestDistance then
			DataService:Set(player, "BestDistance", math.floor(distance))
		end
		if wins > 0 then
			ProgressService:GrantWins(player, wins)
		end
	end)

	return {
		ok = true,
		Walls = walls,
		Distance = math.floor(distance),
		Wins = wins,
		Duration = duration,
		message = if walls == 0
			then `You need ⚡{NumberFormat.Abbreviate(Formulas.GetWallToughness(1))} Strength to break the first wall — go train!`
			else nil,
	}
end

function LaneService:Init()
	Remotes.StartRun.OnServerInvoke = startRun
end

function LaneService:Start()
	Players.PlayerRemoving:Connect(function(player)
		readyAt[player] = nil
	end)
end

return LaneService
