--[[
	RewardsService.luau
	• Playtime gifts: claimable after N minutes in the current session (Config.PlaytimeRewards).
	• Offline training: "Welcome back! You trained while you were offline" (Config.Offline).
	• Timed 2x boosts (Strength / Wins / Luck) stored as expiry timestamps in the profile.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Formulas = require(Shared.Formulas)
local NumberFormat = require(Shared.NumberFormat)

local ActionService = require(script.Parent.ActionService)
local DataService = require(script.Parent.DataService)
local PetService = require(script.Parent.PetService)
local ProgressService = require(script.Parent.ProgressService)

local RewardsService = {}

type Session = {
	Start: number,
	Claimed: { [number]: boolean },
	OfflineAmount: number,
	OfflineSeconds: number,
}

local sessions: { [Player]: Session } = {}

local Fail, Success = ActionService.Fail, ActionService.Success

local function getSession(player: Player): Session
	local session = sessions[player]
	if not session then
		session = { Start = os.time(), Claimed = {}, OfflineAmount = 0, OfflineSeconds = 0 }
		sessions[player] = session
	end
	return session
end

function RewardsService:GrantBoost(player: Player, kind: string, duration: number)
	local data = DataService:GetData(player)
	if not data or not Config.Boosts[kind] then
		return
	end
	local now = os.time()
	data.Boosts[kind] = math.max(data.Boosts[kind] or 0, now) + duration
	DataService:MarkDirty(player, "Boosts")
end

-- Claim pending offline Strength, optionally multiplied (x3 Robux product). Returns success.
function RewardsService:ClaimOffline(player: Player, multiplier: number): boolean
	local session = sessions[player]
	if not session or session.OfflineAmount <= 0 then
		return false
	end
	local amount = session.OfflineAmount * multiplier
	session.OfflineAmount = 0
	DataService:Increment(player, "Strength", amount)
	ActionService:Notify(player, `⚡ +{NumberFormat.Abbreviate(amount)} Strength from offline training!`, "Success")
	return true
end

function RewardsService:HasPendingOffline(player: Player): boolean
	local session = sessions[player]
	return session ~= nil and session.OfflineAmount > 0
end

local function grantReward(player: Player, data, reward): string
	local now = os.time()
	if reward.Kind == "Strength" then
		local amount = Formulas.GetPlaytimeRewardAmount(reward, data, now)
		DataService:Increment(player, "Strength", amount)
		return `+{NumberFormat.Abbreviate(amount)} Strength`
	elseif reward.Kind == "Wins" then
		local amount = Formulas.GetPlaytimeRewardAmount(reward, data, now)
		ProgressService:GrantWins(player, amount)
		return `+{NumberFormat.Abbreviate(amount)} Wins`
	elseif reward.Kind == "Egg" then
		local ok, message = PetService:HatchEgg(player, reward.Egg, true)
		return if ok then message else "Egg (inventory full!)"
	elseif reward.Kind == "Boost" then
		RewardsService:GrantBoost(player, reward.Boost, reward.Duration)
		return `{Config.Boosts[reward.Boost].Name} for {math.floor(reward.Duration / 60)} min`
	end
	return "Reward"
end

--------------------------------------------------------------------------------
-- Actions
--------------------------------------------------------------------------------

local function sessionInfo(player: Player)
	local session = getSession(player)
	local claimed = {}
	for index in session.Claimed do
		table.insert(claimed, index)
	end
	return Success(nil, {
		SessionStart = session.Start,
		Claimed = claimed,
		OfflineAmount = session.OfflineAmount,
		OfflineSeconds = session.OfflineSeconds,
	})
end

local function claimPlaytime(player: Player, data, arg: string?)
	local index = tonumber(arg)
	local reward = index and Config.PlaytimeRewards[index]
	if not index or not reward then
		return Fail("Unknown gift.")
	end
	local session = getSession(player)
	if session.Claimed[index] then
		return Fail("Already claimed!")
	end
	if os.time() - session.Start < reward.Minutes * 60 then
		return Fail("Not ready yet — keep playing!")
	end
	session.Claimed[index] = true
	local description = grantReward(player, data, reward)
	return Success(`🎁 {description}!`, { Index = index })
end

local function claimOffline(player: Player)
	if RewardsService:ClaimOffline(player, 1) then
		return Success()
	end
	return Fail("Nothing to claim.")
end

--------------------------------------------------------------------------------
-- Lifecycle
--------------------------------------------------------------------------------

local function onProfileLoaded(player: Player, data)
	local session = getSession(player)
	if data.LastOnline > 0 then
		local away = os.time() - data.LastOnline
		local amount = Formulas.GetOfflineGain(data, away)
		if amount > 0 then
			session.OfflineAmount = amount
			session.OfflineSeconds = math.min(away, Config.Offline.MaxHours * 3600)
		end
	end
	-- Count from now, so a crash/rejoin can't double-dip on offline time.
	data.LastOnline = os.time()
end

function RewardsService:Init()
	ActionService:Register("GetSession", sessionInfo)
	ActionService:Register("ClaimPlaytime", claimPlaytime)
	ActionService:Register("ClaimOffline", claimOffline)
end

function RewardsService:Start()
	Players.PlayerAdded:Connect(getSession)
	for _, player in Players:GetPlayers() do
		getSession(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		sessions[player] = nil
	end)
	DataService.ProfileLoaded:Connect(onProfileLoaded)
	for _, player in Players:GetPlayers() do
		local data = DataService:GetData(player)
		if data then
			onProfileLoaded(player, data)
		end
	end
end

return RewardsService
