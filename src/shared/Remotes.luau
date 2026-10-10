--[[
	Remotes.luau
	Single source of truth for networking. The server creates the instances; clients wait for them.

	Client -> Server
		Chop (RemoteEvent)            ()  -- one manual chop (server finds your training zone)
		StartRun (RemoteFunction)     () -> { ok, message?, Walls, Distance, Wins, Duration }
		Action (RemoteFunction)       (action: string, arg: string?) -> { ok: boolean, message: string?, ... }
		RequestData (RemoteFunction)  () -> profile snapshot

	Server -> Client
		DataSync (RemoteEvent)        (changes: { [string]: any })
		ChopResult (RemoteEvent)      (gain: number, idle: boolean)
		Hatched (RemoteEvent)         (eggId: string, petId: string, uid: string)
		Notify (RemoteEvent)          (message: string, kind: "Info" | "Success" | "Error")
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local FOLDER_NAME = "Remotes"

local DEFINITIONS = {
	Chop = "RemoteEvent",
	StartRun = "RemoteFunction",
	Action = "RemoteFunction",
	RequestData = "RemoteFunction",
	DataSync = "RemoteEvent",
	ChopResult = "RemoteEvent",
	Hatched = "RemoteEvent",
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
	StartRun = folder:WaitForChild("StartRun") :: RemoteFunction,
	Action = folder:WaitForChild("Action") :: RemoteFunction,
	RequestData = folder:WaitForChild("RequestData") :: RemoteFunction,
	DataSync = folder:WaitForChild("DataSync") :: RemoteEvent,
	ChopResult = folder:WaitForChild("ChopResult") :: RemoteEvent,
	Hatched = folder:WaitForChild("Hatched") :: RemoteEvent,
	Notify = folder:WaitForChild("Notify") :: RemoteEvent,
}

return Remotes
