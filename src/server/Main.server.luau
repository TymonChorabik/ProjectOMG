--[[
	Main.server.luau
	Boots every server service in dependency order: Init (set up, no yielding on players),
	then Start (connect events, begin loops).
]]

local Services = script.Parent:WaitForChild("Services")

local ORDER = {
	"DataService",
	"StandService",
	"WorldService",
	"TrainingService",
	"ShopService",
	"AvatarService",
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

print("[Kung Fu Chop!] Server ready")
