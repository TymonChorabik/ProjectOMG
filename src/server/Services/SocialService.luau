--[[
	SocialService.luau
	Friend Boost: +10% Strength per friend in the server (max +50%), stored in the player
	attribute "FriendBoost" (read by TrainingService and shown in the HUD).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local SocialService = {}

local friendCache: { [string]: boolean } = {}

local function areFriends(a: Player, b: Player): boolean
	local low, high = math.min(a.UserId, b.UserId), math.max(a.UserId, b.UserId)
	local key = low .. ":" .. high
	local cached = friendCache[key]
	if cached == nil then
		local ok, result = pcall(a.IsFriendsWith, a, b.UserId)
		cached = ok and result == true
		friendCache[key] = cached
	end
	return cached
end

local function refreshAll()
	local players = Players:GetPlayers()
	for _, player in players do
		local friends = 0
		for _, other in players do
			if other ~= player and areFriends(player, other) then
				friends += 1
			end
		end
		local social = Config.Social
		player:SetAttribute("FriendBoost", math.min(social.MaxFriendBoost, friends * social.FriendBoostPerFriend))
	end
end

function SocialService:Init() end

function SocialService:Start()
	Players.PlayerAdded:Connect(function()
		task.spawn(refreshAll)
	end)
	Players.PlayerRemoving:Connect(function()
		task.defer(refreshAll)
	end)
	task.spawn(refreshAll)
end

return SocialService
