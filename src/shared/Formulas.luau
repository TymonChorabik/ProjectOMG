--[[
	Formulas.luau
	Pure progression math. The server uses these as the source of truth; the client uses the
	same functions for previews so numbers on screen always match rewards.

	`data` is a player profile (see server/Services/DataService.luau DEFAULT_DATA).
	`now` is Unix time (server: os.time(), client: workspace:GetServerTimeNow()).
]]

local Config = require(script.Parent.Config)

local Formulas = {}

--------------------------------------------------------------------------------
-- Catalog lookups
--------------------------------------------------------------------------------

local itemsById, itemIndexById = {}, {}
for index, item in Config.HandItems do
	itemsById[item.Id] = item
	itemIndexById[item.Id] = index
end

local zonesById = {}
for _, zone in Config.TrainingZones do
	zonesById[zone.Id] = zone
end

local eggsById = {}
for _, egg in Config.Eggs do
	eggsById[egg.Id] = egg
end

local trailsById = {}
for _, trail in Config.Trails do
	trailsById[trail.Id] = trail
end

function Formulas.GetItem(id: string?)
	if id == Config.PremiumItem.Id then
		return Config.PremiumItem
	end
	return if id then itemsById[id] else nil
end

function Formulas.GetItemIndex(id: string?): number?
	return if id then itemIndexById[id] else nil
end

function Formulas.GetZone(id: string?)
	return if id then zonesById[id] else nil
end

function Formulas.GetEgg(id: string?)
	return if id then eggsById[id] else nil
end

function Formulas.GetPet(id: string?)
	return if id then Config.Pets[id] else nil
end

function Formulas.GetTrail(id: string?)
	return if id then trailsById[id] else nil
end

function Formulas.GetBiome(index: number)
	return Config.Biomes[math.clamp(index, 1, #Config.Biomes)]
end

--------------------------------------------------------------------------------
-- Ownership
--------------------------------------------------------------------------------

function Formulas.HasPass(data, passName: string?): boolean
	return passName ~= nil and data.Passes ~= nil and data.Passes[passName] == true
end

function Formulas.IsBoostActive(data, kind: string, now: number): boolean
	return data.Boosts ~= nil and (data.Boosts[kind] or 0) > now
end

function Formulas.IsItemUnlocked(data, itemId: string): boolean
	if itemId == Config.PremiumItem.Id then
		return Formulas.HasPass(data, Config.PremiumItem.Pass)
	end
	local item = itemsById[itemId]
	return item ~= nil and (data.TotalWins or 0) >= item.Wins
end

-- Best regular item the player's lifetime Wins have unlocked.
function Formulas.GetBestUnlockedItem(data)
	local best = Config.HandItems[1]
	for _, item in Config.HandItems do
		if (data.TotalWins or 0) >= item.Wins and item.Bonus > best.Bonus then
			best = item
		end
	end
	return best
end

-- Next item to unlock (or nil when everything is unlocked).
function Formulas.GetNextItem(data)
	for _, item in Config.HandItems do
		if (data.TotalWins or 0) < item.Wins then
			return item
		end
	end
	return nil
end

-- Strength per chop from the equipped hand item (before multipliers).
function Formulas.GetItemBonus(data): number
	local equipped = data.EquippedItem
	if equipped == Config.PremiumItem.Id and Formulas.HasPass(data, Config.PremiumItem.Pass) then
		return Formulas.GetBestUnlockedItem(data).Bonus * (1 + Config.PremiumItem.BetterBy)
	end
	local item = itemsById[equipped]
	if item and Formulas.IsItemUnlocked(data, item.Id) then
		return item.Bonus
	end
	return Config.HandItems[1].Bonus
end

function Formulas.IsZoneUnlocked(data, zoneId: string): boolean
	local zone = zonesById[zoneId]
	if not zone then
		return false
	end
	if zone.Pass then
		return Formulas.HasPass(data, zone.Pass)
	end
	return (data.Rebirths or 0) >= (zone.RequiredRebirths or 0)
end

-- Highest multiplier among zones the player can use (for offline earnings).
function Formulas.GetBestZoneMultiplier(data): number
	local best = 1
	for _, zone in Config.TrainingZones do
		if Formulas.IsZoneUnlocked(data, zone.Id) and zone.Multiplier > best then
			best = zone.Multiplier
		end
	end
	return best
end

--------------------------------------------------------------------------------
-- Pets
--------------------------------------------------------------------------------

function Formulas.GetPetSlots(data): number
	local petsConfig = Config.PetsConfig
	return petsConfig.BaseSlots
		+ (if Formulas.HasPass(data, petsConfig.ExtraSlotsPass) then petsConfig.ExtraSlots else 0)
end

-- Bonus of one pet the player owns ("Always better" pets scale with the best other pet).
function Formulas.GetPetBonus(data, petId: string): number
	local def = Config.Pets[petId]
	if not def then
		return 0
	end
	if def.AlwaysBetterBy then
		local bestOther = 0
		for _, ownedId in data.Pets or {} do
			local other = Config.Pets[ownedId]
			if other and not other.AlwaysBetterBy and other.Bonus > bestOther then
				bestOther = other.Bonus
			end
		end
		return math.max(def.Bonus, bestOther * (1 + def.AlwaysBetterBy))
	end
	return def.Bonus
end

-- Sum of equipped pet bonuses (only pets actually owned, capped at the slot count).
function Formulas.GetEquippedPetBonus(data): number
	local total, counted = 0, 0
	local slots = Formulas.GetPetSlots(data)
	for _, uid in data.EquippedPets or {} do
		local petId = data.Pets and data.Pets[uid]
		if petId and counted < slots then
			counted += 1
			total += Formulas.GetPetBonus(data, petId)
		end
	end
	return total
end

-- Best pets first: returns uids sorted by bonus (descending).
function Formulas.GetBestPetUids(data, count: number): { string }
	local uids = {}
	for uid in data.Pets or {} do
		table.insert(uids, uid)
	end
	table.sort(uids, function(a, b)
		local bonusA, bonusB = Formulas.GetPetBonus(data, data.Pets[a]), Formulas.GetPetBonus(data, data.Pets[b])
		if bonusA == bonusB then
			return a < b
		end
		return bonusA > bonusB
	end)
	local best = {}
	for index = 1, math.min(count, #uids) do
		best[index] = uids[index]
	end
	return best
end

-- Pick a pet from an egg. `roll` is a number in [0, 1).
function Formulas.RollEgg(eggId: string, roll: number, luck: boolean?): string?
	local odds = Formulas.GetEggOdds(eggId, luck)
	local cumulative = 0
	for _, entry in odds do
		cumulative += entry.Chance
		if roll < cumulative then
			return entry.PetId
		end
	end
	return if #odds > 0 then odds[#odds].PetId else nil
end

-- Hatch chances for an egg, rarest last. Luck multiplies every non-Common weight.
function Formulas.GetEggOdds(eggId: string, luck: boolean?): { { PetId: string, Chance: number } }
	local egg = eggsById[eggId]
	if not egg then
		return {}
	end
	local entries, total = {}, 0
	for petId, weight in egg.Pool do
		local def = Config.Pets[petId]
		local w = weight
		if luck and def and def.Rarity ~= "Common" then
			w *= Config.PetsConfig.LuckBoostMultiplier
		end
		total += w
		table.insert(entries, { PetId = petId, Chance = w })
	end
	for _, entry in entries do
		entry.Chance /= total
	end
	table.sort(entries, function(a, b)
		if a.Chance == b.Chance then
			return a.PetId < b.PetId
		end
		return a.Chance > b.Chance
	end)
	return entries
end

--------------------------------------------------------------------------------
-- Multipliers & gains
--------------------------------------------------------------------------------

function Formulas.GetRebirthMultiplier(rebirths: number): number
	return 1 + rebirths * Config.Rebirth.StrengthPerRebirth
end

-- Everything that multiplies Strength gain except the training zone (shown as "xN Multiplier").
function Formulas.GetStrengthMultiplier(data, now: number, friendBoost: number?): number
	local multiplier = Formulas.GetRebirthMultiplier(data.Rebirths or 0) * (1 + Formulas.GetEquippedPetBonus(data))
	if Formulas.HasPass(data, "DoubleStrength") then
		multiplier *= 2
	end
	if Formulas.IsBoostActive(data, "Strength", now) then
		multiplier *= 2
	end
	return multiplier * (1 + (friendBoost or 0))
end

function Formulas.GetChopGain(data, zoneMultiplier: number, now: number, friendBoost: number?): number
	local gain = Formulas.GetItemBonus(data) * zoneMultiplier * Formulas.GetStrengthMultiplier(data, now, friendBoost)
	return math.max(1, math.floor(gain))
end

function Formulas.GetWinsMultiplier(data, now: number): number
	local multiplier = 1 + (data.Rebirths or 0) * Config.Rebirth.WinsPerRebirth
	if Formulas.HasPass(data, "DoubleWins") then
		multiplier *= 2
	end
	if Formulas.IsBoostActive(data, "Wins", now) then
		multiplier *= 2
	end
	return multiplier
end

function Formulas.GetWalkSpeed(data): number
	local trail = trailsById[data.EquippedTrail]
	local owned = trail and data.OwnedTrails and data.OwnedTrails[trail.Id]
	return Config.BaseWalkSpeed + (if owned then trail.Speed else 0)
end

--------------------------------------------------------------------------------
-- Rebirth & level
--------------------------------------------------------------------------------

function Formulas.GetRebirthCost(rebirths: number): number
	return math.floor(Config.Rebirth.BaseCost * Config.Rebirth.CostGrowth ^ rebirths)
end

-- 0..1 progress toward the next rebirth.
function Formulas.GetRebirthProgress(data): number
	return math.clamp((data.Strength or 0) / Formulas.GetRebirthCost(data.Rebirths or 0), 0, 1)
end

-- Level 1..MaxLevel from Strength within the current rebirth; MaxLevel = rebirth ready.
-- Returns level, progress (0..1) inside that level, and Strength needed for the next level.
function Formulas.GetLevel(strength: number, rebirths: number): (number, number, number)
	local maxLevel = Config.Rebirth.MaxLevel
	local cost = Formulas.GetRebirthCost(rebirths)
	if strength >= cost then
		return maxLevel, 1, cost
	end
	-- Level n starts at cost * (n / maxLevel)^2 (fast early levels, slower later).
	local ratio = math.sqrt(math.max(0, strength) / cost) * maxLevel
	local level = math.clamp(math.floor(ratio), 1, maxLevel - 1)
	local nextThreshold = cost * ((level + 1) / maxLevel) ^ 2
	local thisThreshold = if level <= 1 then 0 else cost * (level / maxLevel) ^ 2
	local progress = math.clamp((strength - thisThreshold) / (nextThreshold - thisThreshold), 0, 1)
	return level, progress, math.ceil(nextThreshold)
end

--------------------------------------------------------------------------------
-- The Board Wall lane
--------------------------------------------------------------------------------

function Formulas.GetWallCount(): number
	return #Config.Biomes * Config.Lane.WallsPerBiome
end

function Formulas.GetWallToughness(index: number): number
	local lane = Config.Lane
	return math.floor(lane.BaseToughness * lane.ToughnessGrowth ^ (index - 1))
end

function Formulas.GetWallBiomeIndex(index: number): number
	return math.clamp(math.ceil(index / Config.Lane.WallsPerBiome), 1, #Config.Biomes)
end

function Formulas.GetWallZ(index: number): number
	local lane = Config.Lane
	return lane.FirstWallZ + (index - 1) * lane.WallSpacing
end

-- How many walls a run breaks, and how far (studs from the pad) the player gets.
function Formulas.GetRunResult(strength: number): (number, number)
	local lane = Config.Lane
	local count = Formulas.GetWallCount()
	local broken = 0
	for index = 1, count do
		if strength >= Formulas.GetWallToughness(index) then
			broken = index
		else
			break
		end
	end
	local stopZ
	if broken >= count then
		stopZ = Formulas.GetWallZ(count) + lane.FinishOvershoot
	else
		stopZ = Formulas.GetWallZ(broken + 1) - 3
	end
	return broken, math.max(0, stopZ - lane.PadPosition.Z)
end

-- Wins for breaking the first `walls` walls (before multipliers).
function Formulas.GetRunWins(walls: number): number
	local total = 0
	for index = 1, walls do
		total += Formulas.GetBiome(Formulas.GetWallBiomeIndex(index)).WinsPerWall
	end
	return total
end

function Formulas.GetRunDuration(distance: number): number
	local lane = Config.Lane
	return math.clamp(1.2 + distance / lane.StudsPerSecond, lane.MinDuration, lane.MaxDuration)
end

--------------------------------------------------------------------------------
-- Rewards
--------------------------------------------------------------------------------

-- Strength per second while idling in the best zone (no boosts/friends) — used offline.
function Formulas.GetIdleStrengthPerSecond(data): number
	local gain = Formulas.GetItemBonus(data)
		* Formulas.GetBestZoneMultiplier(data)
		* Formulas.GetRebirthMultiplier(data.Rebirths or 0)
		* (1 + Formulas.GetEquippedPetBonus(data))
		* (if Formulas.HasPass(data, "DoubleStrength") then 2 else 1)
	return gain / Config.Training.IdleInterval
end

function Formulas.GetOfflineGain(data, secondsAway: number): number
	local offline = Config.Offline
	if secondsAway < offline.MinSeconds then
		return 0
	end
	local seconds = math.min(secondsAway, offline.MaxHours * 3600)
	return math.floor(Formulas.GetIdleStrengthPerSecond(data) * seconds * offline.Efficiency)
end

-- Concrete amount of a Strength/Wins playtime reward for this player.
function Formulas.GetPlaytimeRewardAmount(reward, data, now: number): number
	if reward.Kind == "Strength" then
		return reward.Chops * Formulas.GetChopGain(data, 1, now)
	elseif reward.Kind == "Wins" then
		return math.floor(reward.Amount * Formulas.GetWinsMultiplier(data, now))
	end
	return 0
end

return Formulas
