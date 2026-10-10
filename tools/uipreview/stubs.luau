--[[
	stubs.luau
	Stand-ins for the client modules that talk to the server or the 3D world, so the real
	UIController can build the real HUD and windows offline. SAMPLE_DATA / SAMPLE_SESSION are
	what the preview shows; scenes can tweak them before UIController.Start().
]]

withMethods(workspace, {
	GetServerTimeNow = function()
		return os.time()
	end,
})

SAMPLE_DATA = {
	SchemaVersion = 2,
	Strength = 18_450,
	Wins = 2_480,
	TotalWins = 3_120,
	Rebirths = 2,
	BestDistance = 486,
	EquippedItem = "BareFists",
	Pets = { p1 = "Puppy", p2 = "Kitty", p3 = "Bunny", p4 = "Fox", p5 = "Panda", p6 = "Kirin" },
	EquippedPets = { "p6", "p5", "p2" },
	NextPetUid = 7,
	OwnedTrails = {},
	EquippedTrail = "None",
	Boosts = { Strength = os.time() + 541, Wins = 0, Luck = 0 },
	Passes = {},
	Receipts = {},
	StarterPackBought = false,
	LastOnline = 0,
	Stats = { Chops = 1200, Runs = 14, WallsBroken = 95, EggsHatched = 6 },
}

SAMPLE_SESSION = {
	ok = true,
	SessionStart = os.time() - 22 * 60,
	Claimed = { 1, 2, 3 },
	OfflineAmount = 0,
	OfflineSeconds = 0,
}

STUB_MODULES = {}

STUB_MODULES["StarterPlayer/StarterPlayerScripts/Client/ClientData"] = function()
	local Signal = require(game:GetService("ReplicatedStorage").Shared.Signal)
	local ClientData = { Changed = Signal.new(), Loaded = Signal.new() }
	ClientData.Data = SAMPLE_DATA
	function ClientData.Get(key)
		return ClientData.Data and ClientData.Data[key]
	end
	function ClientData.WaitForData()
		return ClientData.Data
	end
	function ClientData.Start() end
	return ClientData
end

STUB_MODULES["ReplicatedStorage/Shared/Remotes"] = function()
	local function remote()
		return {
			OnClientEvent = newSignal(),
			FireServer = function() end,
			InvokeServer = function(_self, action)
				if action == "GetSession" then
					return SAMPLE_SESSION
				end
				return { ok = true }
			end,
		}
	end
	return setmetatable({}, {
		__index = function(t, key)
			local r = remote()
			rawset(t, key, r)
			return r
		end,
	})
end

STUB_MODULES["StarterPlayer/StarterPlayerScripts/Client/Effects/Sfx"] = function()
	return { Play = function() end, Preload = function() end }
end

STUB_MODULES["StarterPlayer/StarterPlayerScripts/Client/Controllers/ChopController"] = function()
	local Signal = require(game:GetService("ReplicatedStorage").Shared.Signal)
	return {
		AutoChopChanged = Signal.new(),
		IsAutoChop = function()
			return false
		end,
		SetAutoChop = function() end,
		Chop = function() end,
	}
end

STUB_MODULES["StarterPlayer/StarterPlayerScripts/Client/Controllers/LaneController"] = function()
	local Signal = require(game:GetService("ReplicatedStorage").Shared.Signal)
	return {
		PadChanged = Signal.new(),
		RunProgress = Signal.new(),
		IsOnPad = function()
			return false
		end,
		TryRun = function() end,
	}
end

STUB_MODULES["StarterPlayer/StarterPlayerScripts/Client/Controllers/WorldController"] = function()
	return { Start = function() end }
end

-- Finds a window by name under the HUD and shows it fully open.
function openWindow(name: string)
	local playerGui = game:GetService("Players").LocalPlayer.PlayerGui
	for _, inst in playerGui:GetDescendants() do
		if inst.Name == name and inst:IsA("GuiObject") then
			inst.Visible = true
			local scale = inst:FindFirstChildOfClass("UIScale")
			if scale then
				scale.Scale = 1
			end
			return inst
		end
	end
	error("no window named " .. name)
end
