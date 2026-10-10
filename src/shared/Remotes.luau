--[[
	Remotes.luau
	Single source of truth for networking. The server creates the instances; clients wait for them.

	Client -> Server
		Chop (RemoteEvent)            (standId: string?)  -- one training chop, optionally aimed at a stand
		Action (RemoteFunction)       (action: string, arg: any) -> { ok: boolean, message: string? }
		RequestData (RemoteFunction)  () -> snapshot table

	Server -> Client
		DataSync (RemoteEvent)        (changes: { [string]: any })
		ChopResult (RemoteEvent)      (gain: number, isCrit: boolean)
		ObjectSmashed (RemoteEvent)   (player: Player, standId: string, coins: number)  -- fired to all
		Notify (RemoteEvent)          (message: string, kind: "Info" | "Success" | "Error")
]]

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FOLDER_NAME = "Remotes"

local DEFINITIONS = {
	Chop = "RemoteEvent",
	Action = "RemoteFunction",
	RequestData = "RemoteFunction",
	DataSync = "RemoteEvent",
	ChopResult = "RemoteEvent",
	ObjectSmashed = "RemoteEvent",
	Notify = "RemoteEvent",
}

local folder: Instance
if RunService:IsServer() then
	local existing = ReplicatedStorage:FindFirstChild(FOLDER_NAME)
	if existing then
		folder = existing
	else
		local created = Instance.new("Folder")
		created.Name = FOLDER_NAME
		created.Parent = ReplicatedStorage
		folder = created
	end
	for name, className in DEFINITIONS do
		if not folder:FindFirstChild(name) then
			local remote = Instance.new(className)
			remote.Name = name
			remote.Parent = folder
		end
	end
else
	folder = ReplicatedStorage:WaitForChild(FOLDER_NAME)
end

local Remotes = {
	Chop = folder:WaitForChild("Chop") :: RemoteEvent,
	Action = folder:WaitForChild("Action") :: RemoteFunction,
	RequestData = folder:WaitForChild("RequestData") :: RemoteFunction,
	DataSync = folder:WaitForChild("DataSync") :: RemoteEvent,
	ChopResult = folder:WaitForChild("ChopResult") :: RemoteEvent,
	ObjectSmashed = folder:WaitForChild("ObjectSmashed") :: RemoteEvent,
	Notify = folder:WaitForChild("Notify") :: RemoteEvent,
}

return Remotes
