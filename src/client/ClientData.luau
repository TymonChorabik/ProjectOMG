--[[
	ClientData.luau
	Read-only mirror of the local player's profile. Fetches a snapshot, then merges the
	server's batched DataSync deltas. UI subscribes with ClientData.Changed:Connect(key, value).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)
local Signal = require(Shared.Signal)

local ClientData = {}

ClientData.Data = nil :: { [string]: any }?
ClientData.Changed = Signal.new() -- (key, value)
ClientData.Loaded = Signal.new() -- (data)

function ClientData.Get(key: string): any
	return ClientData.Data and ClientData.Data[key]
end

function ClientData.WaitForData(): { [string]: any }
	if ClientData.Data then
		return ClientData.Data
	end
	return ClientData.Loaded:Wait()
end

function ClientData.Start()
	Remotes.DataSync.OnClientEvent:Connect(function(changes)
		if not ClientData.Data then
			-- Remotes are delivered in order, so anything arriving before the snapshot
			-- is already included in it.
			return
		end
		for key, value in changes do
			ClientData.Data[key] = value
			ClientData.Changed:Fire(key, value)
		end
	end)

	task.spawn(function()
		local snapshot
		repeat
			local ok, result = pcall(function()
				return Remotes.RequestData:InvokeServer()
			end)
			if ok and type(result) == "table" then
				snapshot = result
			else
				task.wait(2)
			end
		until snapshot

		ClientData.Data = snapshot
		ClientData.Loaded:Fire(snapshot)
		for key, value in snapshot do
			ClientData.Changed:Fire(key, value)
		end
	end)
end

return ClientData
