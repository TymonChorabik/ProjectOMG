--[[
	Main.server.luau
	Boots every server service in dependency order: Init (register remotes/actions, build the
	world), then Start (connect player events, begin loops).
]]

local Services = script.Parent:WaitForChild("Services")

local ORDER = {
	"DataService",
	"WorldService",
	"ActionService",
	"PetService",
	"ProgressService",
	"RewardsService",
	"MonetizationService",
	"TrainingService",
	"LaneService",
	"SocialService",
	"AvatarService",
	"LeaderboardService",
}

local loaded = {}
for _, name in ORDER do
	local service = require(Services:WaitForChild(name))
	loaded[name] = service
	service:Init()
end

for _, name in ORDER do
	task.spawn(function()
		loaded[name]:Start()
	end)
end

print("[+1 Kung Fu Chop!] Server ready")
