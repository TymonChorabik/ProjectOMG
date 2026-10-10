--[[
	DataService.luau
	Session-locked DataStore profiles.

	• UpdateAsync everywhere (never SetAsync) so concurrent writes can't clobber each other.
	• A session lock (JobId + timestamp) stops two servers editing the same profile; stale locks
	  from crashed servers expire after Config.Data.SessionLockExpiry seconds.
	• Profiles are reconciled against DEFAULT_DATA so new fields appear for old players.
	• Changes are batched and replicated to the owning client ~10x per second.
	• Autosave every Config.Data.AutosaveInterval seconds, on leave, and on shutdown.
	• In Studio without "Enable Studio Access to API Services", data runs in memory only.
]]

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local NumberFormat = require(Shared.NumberFormat)
local Remotes = require(Shared.Remotes)
local Signal = require(Shared.Signal)

local KEY_PREFIX = "Player_"
local SYNC_INTERVAL = 0.1

local DEFAULT_DATA = {
	SchemaVersion = Config.Data.SchemaVersion,
	Power = 0,
	Coins = 0,
	Rebirths = 0,
	OwnedBelts = { White = true },
	EquippedBelt = "White",
	OwnedAuras = {},
	EquippedAura = "None",
	Upgrades = { IronPalms = 0, Focus = 0, Greed = 0, Speed = 0 },
	Stats = { TotalChops = 0, ObjectsSmashed = 0, TotalPowerEarned = 0, BestChop = 0 },
}

type Profile = {
	Data: { [string]: any },
	Persistent: boolean,
	Dirty: { [string]: boolean },
	Leaderstats: Folder?,
}

local DataService = {}

DataService.ProfileLoaded = Signal.new() -- (player, data)
DataService.Changed = Signal.new() -- (player, key, value)

local profiles: { [Player]: Profile } = {}
local store: DataStore? = nil

--------------------------------------------------------------------------------
-- Helpers
--------------------------------------------------------------------------------

local function deepCopy(value)
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for k, v in value do
		copy[k] = deepCopy(v)
	end
	return copy
end

-- Fill in missing keys and repair wrong types from the template (recursively).
local function reconcile(data, template)
	for key, defaultValue in template do
		local current = data[key]
		if current == nil or type(current) ~= type(defaultValue) then
			data[key] = deepCopy(defaultValue)
		elseif type(defaultValue) == "table" then
			reconcile(current, defaultValue)
		end
	end
	return data
end

local function sanitize(data)
	reconcile(data, DEFAULT_DATA)
	data.OwnedBelts.White = true
	if not data.OwnedBelts[data.EquippedBelt] then
		data.EquippedBelt = "White"
	end
	if data.EquippedAura ~= "None" and not data.OwnedAuras[data.EquippedAura] then
		data.EquippedAura = "None"
	end
	for _, key in { "Power", "Coins", "Rebirths" } do
		local n = data[key]
		if n ~= n or n < 0 or n == math.huge then
			data[key] = 0
		end
	end
	data.SchemaVersion = Config.Data.SchemaVersion
	return data
end

local function retry<T...>(attempts: number, callback: () -> T...): (boolean, ...any)
	local lastError
	for attempt = 1, attempts do
		local result = table.pack(pcall(callback))
		if result[1] then
			return table.unpack(result, 1, result.n)
		end
		lastError = result[2]
		if attempt < attempts then
			task.wait(2 ^ attempt)
		end
	end
	return false, lastError
end

local function notify(player: Player, message: string, kind: string)
	Remotes.Notify:FireClient(player, message, kind)
end

--------------------------------------------------------------------------------
-- Leaderstats
--------------------------------------------------------------------------------

local function createLeaderstats(player: Player): Folder
	local folder = Instance.new("Folder")
	folder.Name = "leaderstats"

	local power = Instance.new("StringValue")
	power.Name = "⚡ Power"
	power.Parent = folder

	local coins = Instance.new("StringValue")
	coins.Name = "🪙 Coins"
	coins.Parent = folder

	local rebirths = Instance.new("IntValue")
	rebirths.Name = "Rebirths"
	rebirths.Parent = folder

	folder.Parent = player
	return folder
end

local function refreshLeaderstats(profile: Profile)
	local folder = profile.Leaderstats
	if not folder then
		return
	end
	local data = profile.Data
	local power = folder:FindFirstChild("⚡ Power") :: StringValue?
	local coins = folder:FindFirstChild("🪙 Coins") :: StringValue?
	local rebirths = folder:FindFirstChild("Rebirths") :: IntValue?
	if power then
		power.Value = NumberFormat.Abbreviate(data.Power)
	end
	if coins then
		coins.Value = NumberFormat.Abbreviate(data.Coins)
	end
	if rebirths then
		rebirths.Value = data.Rebirths
	end
end

--------------------------------------------------------------------------------
-- Persistence
--------------------------------------------------------------------------------

local function isLockActive(lock): boolean
	return type(lock) == "table"
		and lock.JobId ~= game.JobId
		and os.time() - (tonumber(lock.Time) or 0) < Config.Data.SessionLockExpiry
end

-- Returns (data, persistent). data is nil only if the player left while loading.
local function loadProfileData(player: Player): ({ [string]: any }?, boolean)
	local dataStore = store
	if not dataStore then
		return deepCopy(DEFAULT_DATA), false
	end

	local key = KEY_PREFIX .. player.UserId
	local attempts = Config.Data.LoadRetries

	for attempt = 1, attempts do
		local forceSteal = attempt == attempts
		local lockedElsewhere = false
		local loaded = nil

		local ok, err = pcall(function()
			dataStore:UpdateAsync(key, function(record)
				record = if type(record) == "table" then record else {}
				lockedElsewhere = false
				loaded = nil

				if isLockActive(record.SessionLock) and not forceSteal then
					lockedElsewhere = true
					return nil -- cancel the write, try again shortly
				end

				record.Data = if type(record.Data) == "table" then record.Data else deepCopy(DEFAULT_DATA)
				record.SessionLock = { JobId = game.JobId, Time = os.time() }
				loaded = record.Data
				return record
			end)
		end)

		if ok and loaded then
			return loaded, true
		elseif not ok then
			warn(`[DataService] Load attempt {attempt} failed for {player.Name}: {err}`)
		elseif lockedElsewhere then
			warn(`[DataService] {player.Name}'s data is locked by another server (attempt {attempt})`)
		end

		if not player:IsDescendantOf(Players) then
			return nil, false
		end
		task.wait(Config.Data.LoadRetryDelay)
	end

	-- DataStores are down: let them play, but never overwrite their real save.
	return deepCopy(DEFAULT_DATA), false
end

local function saveProfile(player: Player, profile: Profile, release: boolean)
	local dataStore = store
	if not dataStore or not profile.Persistent then
		return
	end

	local key = KEY_PREFIX .. player.UserId
	local lostLock = false

	local ok, err = retry(3, function()
		dataStore:UpdateAsync(key, function(record)
			record = if type(record) == "table" then record else {}
			lostLock = false
			local lock = record.SessionLock
			if type(lock) == "table" and lock.JobId ~= game.JobId then
				lostLock = true
				return nil
			end
			record.Data = profile.Data
			record.SessionLock = if release then nil else { JobId = game.JobId, Time = os.time() }
			record.SavedAt = os.time()
			return record
		end)
	end)

	if not ok then
		warn(`[DataService] Save failed for {player.Name}: {err}`)
	elseif lostLock then
		profile.Persistent = false
		warn(`[DataService] {player.Name}'s session was taken over by another server`)
		if player:IsDescendantOf(Players) then
			player:Kick("Your data was loaded on another server. Please rejoin!")
		end
	end
end

-- Release a lock we acquired for a player who left before their profile finished loading.
local function releaseLock(userId: number)
	local dataStore = store
	if not dataStore then
		return
	end
	pcall(function()
		dataStore:UpdateAsync(KEY_PREFIX .. userId, function(record)
			if
				type(record) ~= "table"
				or type(record.SessionLock) ~= "table"
				or record.SessionLock.JobId ~= game.JobId
			then
				return nil
			end
			record.SessionLock = nil
			return record
		end)
	end)
end

--------------------------------------------------------------------------------
-- Public API
--------------------------------------------------------------------------------

function DataService:GetData(player: Player): { [string]: any }?
	local profile = profiles[player]
	return profile and profile.Data
end

function DataService:IsPersistent(player: Player): boolean
	local profile = profiles[player]
	return profile ~= nil and profile.Persistent
end

-- Yields until the player's profile is loaded (or they leave / timeout).
function DataService:WaitForData(player: Player, timeout: number?): { [string]: any }?
	local profile = profiles[player]
	if profile then
		return profile.Data
	end
	local deadline = os.clock() + (timeout or 30)
	while not profiles[player] and player:IsDescendantOf(Players) and os.clock() < deadline do
		task.wait(0.1)
	end
	profile = profiles[player]
	return profile and profile.Data
end

-- Mark a key as changed (use after mutating nested tables in place).
function DataService:MarkDirty(player: Player, key: string)
	local profile = profiles[player]
	if not profile then
		return
	end
	profile.Dirty[key] = true
	DataService.Changed:Fire(player, key, profile.Data[key])
end

function DataService:Set(player: Player, key: string, value: any)
	local profile = profiles[player]
	if not profile then
		return
	end
	profile.Data[key] = value
	self:MarkDirty(player, key)
end

function DataService:Increment(player: Player, key: string, amount: number): number?
	local profile = profiles[player]
	if not profile then
		return nil
	end
	local newValue = (profile.Data[key] or 0) + amount
	profile.Data[key] = newValue
	self:MarkDirty(player, key)
	return newValue
end

--------------------------------------------------------------------------------
-- Lifecycle
--------------------------------------------------------------------------------

local function onPlayerAdded(player: Player)
	local data, persistent = loadProfileData(player)
	if not data then
		releaseLock(player.UserId)
		return
	end
	if not player:IsDescendantOf(Players) then
		-- Left during load: free the lock without touching their data.
		if persistent then
			releaseLock(player.UserId)
		end
		return
	end

	local profile: Profile = {
		Data = sanitize(data),
		Persistent = persistent,
		Dirty = {},
		Leaderstats = nil,
	}
	profile.Leaderstats = createLeaderstats(player)
	profiles[player] = profile
	refreshLeaderstats(profile)

	DataService.ProfileLoaded:Fire(player, profile.Data)

	if not persistent then
		task.delay(3, function()
			if player:IsDescendantOf(Players) then
				notify(player, "Data saving is offline for this session — progress won't be saved.", "Error")
			end
		end)
	end
end

local function onPlayerRemoving(player: Player)
	local profile = profiles[player]
	if not profile then
		return
	end
	profiles[player] = nil
	saveProfile(player, profile, true)
end

local function flushDirty()
	for player, profile in profiles do
		if next(profile.Dirty) then
			local changes = {}
			for key in profile.Dirty do
				changes[key] = profile.Data[key]
			end
			table.clear(profile.Dirty)
			Remotes.DataSync:FireClient(player, changes)
			refreshLeaderstats(profile)
		end
	end
end

local function detectStore()
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(Config.DataStoreName)
	end)
	if not ok then
		warn("[DataService] DataStores unavailable, running in memory: " .. tostring(result))
		return
	end

	if RunService:IsStudio() then
		-- Probe once so Studio sessions without API access don't stall on retries.
		local probeOk, probeErr = pcall(function()
			result:GetAsync("__probe")
		end)
		if not probeOk then
			warn("[DataService] Studio API access disabled; data will not save. (" .. tostring(probeErr) .. ")")
			return
		end
	end

	store = result
end

function DataService:Init()
	detectStore()

	Remotes.RequestData.OnServerInvoke = function(player: Player)
		return DataService:WaitForData(player, 30)
	end
end

function DataService:Start()
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end
	Players.PlayerRemoving:Connect(onPlayerRemoving)

	-- Batched replication.
	local accumulator = 0
	RunService.Heartbeat:Connect(function(dt)
		accumulator += dt
		if accumulator >= SYNC_INTERVAL then
			accumulator = 0
			flushDirty()
		end
	end)

	-- Autosave, spread across the interval to respect DataStore budgets.
	task.spawn(function()
		while true do
			task.wait(Config.Data.AutosaveInterval)
			local players = {}
			for player in profiles do
				table.insert(players, player)
			end
			local spacing = math.min(1, Config.Data.AutosaveInterval / math.max(1, #players) / 2)
			for _, player in players do
				local profile = profiles[player]
				if profile then
					task.spawn(saveProfile, player, profile, false)
				end
				task.wait(spacing)
			end
		end
	end)

	game:BindToClose(function()
		local pending = 0
		for player, profile in profiles do
			pending += 1
			task.spawn(function()
				saveProfile(player, profile, true)
				pending -= 1
			end)
		end
		local deadline = os.clock() + 25
		while pending > 0 and os.clock() < deadline do
			task.wait(0.1)
		end
	end)
end

DataService.DEFAULT_DATA = DEFAULT_DATA

return DataService
