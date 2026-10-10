-- tests/spec.luau — appended to the bundle built by tests/run.py (`module(path)` is provided there).

local Config = module("Shared/Config")
local Formulas = module("Shared/Formulas")
local NumberFormat = module("Shared/NumberFormat")

local passed, failed = 0, 0
local NOW = 1_700_000_000

local function test(name: string, fn: () -> ())
	local ok, err = pcall(fn)
	if ok then
		passed += 1
	else
		failed += 1
		print("FAIL  " .. name .. "\n      " .. tostring(err))
	end
end

local function eq(actual, expected, label: string?)
	if actual ~= expected then
		error(`{label or "value"}: expected {tostring(expected)}, got {tostring(actual)}`, 2)
	end
end

local function near(actual: number, expected: number, label: string?)
	if math.abs(actual - expected) > 1e-6 * math.max(1, math.abs(expected)) then
		error(`{label or "value"}: expected {expected}, got {actual}`, 2)
	end
end

local function freshData()
	return {
		Strength = 0,
		Wins = 0,
		TotalWins = 0,
		Rebirths = 0,
		BestDistance = 0,
		EquippedItem = "BareFists",
		Pets = {},
		EquippedPets = {},
		OwnedTrails = {},
		EquippedTrail = "None",
		Boosts = {},
		Passes = {},
	}
end

--------------------------------------------------------------------------------
-- NumberFormat
--------------------------------------------------------------------------------

test("Abbreviate", function()
	eq(NumberFormat.Abbreviate(0), "0")
	eq(NumberFormat.Abbreviate(999), "999")
	eq(NumberFormat.Abbreviate(1000), "1K")
	eq(NumberFormat.Abbreviate(11_230), "11.2K")
	eq(NumberFormat.Abbreviate(999_999), "1M")
	eq(NumberFormat.Abbreviate(1.5e9), "1.5B")
	eq(NumberFormat.Abbreviate(-1234), "-1.23K")
end)

test("Commas / Multiplier / Percent", function()
	eq(NumberFormat.Commas(10546), "10,546")
	eq(NumberFormat.Multiplier(2), "x2")
	eq(NumberFormat.Multiplier(1.5), "x1.5")
	eq(NumberFormat.Percent(1.25), "125%")
end)

--------------------------------------------------------------------------------
-- Training
--------------------------------------------------------------------------------

test("A fresh player gains exactly +1 per chop", function()
	eq(Formulas.GetChopGain(freshData(), 1, NOW), 1)
end)

test("Hand items unlock with lifetime wins", function()
	local data = freshData()
	data.EquippedItem = "ClothWraps"
	eq(Formulas.GetItemBonus(data), 1, "locked item falls back to bare fists")
	data.TotalWins = 2
	eq(Formulas.GetItemBonus(data), 3, "cloth wraps")
	eq(Formulas.GetBestUnlockedItem(data).Id, "ClothWraps")
	eq(Formulas.GetNextItem(data).Id, "LeatherWraps")
	data.Wins = 0 -- spending wins never re-locks items
	eq(Formulas.IsItemUnlocked(data, "ClothWraps"), true)
end)

test("Phoenix Relic is always 125% better than the best unlocked item", function()
	local data = freshData()
	data.TotalWins = 150 -- Iron Knuckles (+30)
	data.EquippedItem = "PhoenixRelic"
	eq(Formulas.GetItemBonus(data), 1, "needs the pass")
	data.Passes.PhoenixRelic = true
	near(Formulas.GetItemBonus(data), 30 * 2.25)
end)

test("Multipliers stack: zone x rebirth x pets x passes x boosts x friends", function()
	local data = freshData()
	eq(Formulas.GetChopGain(data, 4, NOW), 4, "zone x4")
	data.Rebirths = 2
	eq(Formulas.GetChopGain(data, 1, NOW), 2, "2 rebirths = x2")
	data.Pets = { ["1"] = "Puppy", ["2"] = "Panda" }
	data.EquippedPets = { "1", "2" }
	near(Formulas.GetStrengthMultiplier(data, NOW), 2 * 1.45, "pets")
	data.Passes.DoubleStrength = true
	data.Boosts.Strength = NOW + 60
	near(Formulas.GetStrengthMultiplier(data, NOW, 0.2), 2 * 1.45 * 2 * 2 * 1.2, "everything")
	data.Boosts.Strength = NOW - 1
	near(Formulas.GetStrengthMultiplier(data, NOW), 2 * 1.45 * 2, "expired boost")
end)

test("Zones unlock by rebirths or passes", function()
	local data = freshData()
	assert(Formulas.IsZoneUnlocked(data, "Wooden"))
	assert(not Formulas.IsZoneUnlocked(data, "Bamboo"))
	data.Rebirths = 2
	assert(Formulas.IsZoneUnlocked(data, "Bamboo"))
	assert(not Formulas.IsZoneUnlocked(data, "Golden"))
	data.Passes.GoldenZone = true
	assert(Formulas.IsZoneUnlocked(data, "Golden"))
	eq(Formulas.GetBestZoneMultiplier(data), 30)
	assert(not Formulas.IsZoneUnlocked(data, "Nope"))
end)

--------------------------------------------------------------------------------
-- Pets
--------------------------------------------------------------------------------

test("Pet slots cap the equipped bonus", function()
	local data = freshData()
	data.Pets = { a = "Puppy", b = "Puppy", c = "Puppy", d = "Puppy", e = "Puppy" }
	data.EquippedPets = { "a", "b", "c", "d", "e" }
	near(Formulas.GetEquippedPetBonus(data), 0.3, "3 slots")
	data.Passes.PetSlots = true
	near(Formulas.GetEquippedPetBonus(data), 0.5, "5 slots")
	data.EquippedPets = { "a", "missing" }
	near(Formulas.GetEquippedPetBonus(data), 0.1, "unknown uid ignored")
end)

test("Lion King is always 1000% better than the best other pet", function()
	local data = freshData()
	data.Pets = { a = "LionKing" }
	eq(Formulas.GetPetBonus(data, "LionKing"), 10, "floor")
	data.Pets.b = "ShadowDragon" -- +20
	eq(Formulas.GetPetBonus(data, "LionKing"), 20 * 11)
	local best = Formulas.GetBestPetUids(data, 1)
	eq(best[1], "a")
end)

test("Egg odds sum to 1 and luck favours rarer pets", function()
	for _, egg in Config.Eggs do
		local total = 0
		for _, entry in Formulas.GetEggOdds(egg.Id) do
			total += entry.Chance
		end
		near(total, 1, egg.Id)
	end
	local function chance(eggId, petId, luck)
		for _, entry in Formulas.GetEggOdds(eggId, luck) do
			if entry.PetId == petId then
				return entry.Chance
			end
		end
		return 0
	end
	assert(chance("Common", "Panda", true) > chance("Common", "Panda", false), "luck")
	assert(chance("Common", "Puppy", true) < chance("Common", "Puppy", false), "commons drop")
	eq(Formulas.RollEgg("Common", 0), "Puppy", "lowest roll = most common")
	eq(Formulas.RollEgg("Common", 0.99999), "Panda", "highest roll = rarest")
	eq(Formulas.RollEgg("Nope", 0.5), nil)
end)

--------------------------------------------------------------------------------
-- Lane
--------------------------------------------------------------------------------

test("Runs break every wall your Strength can handle", function()
	local walls, distance = Formulas.GetRunResult(0)
	eq(walls, 0)
	assert(distance > 0 and distance < Config.Lane.FirstWallZ - Config.Lane.PadPosition.Z, "stops before wall 1")
	walls = Formulas.GetRunResult(Config.Lane.BaseToughness)
	eq(walls, 1)
	local count = Formulas.GetWallCount()
	walls, distance = Formulas.GetRunResult(1e300)
	eq(walls, count)
	near(distance, Formulas.GetWallZ(count) + Config.Lane.FinishOvershoot - Config.Lane.PadPosition.Z)
	local last = -1
	for exponent = 0, 12 do
		local w, d = Formulas.GetRunResult(10 ^ exponent)
		assert(d >= last, "distance grows with strength")
		last = d
		assert(w >= 0 and w <= count)
	end
end)

test("Wins per run follow the biomes", function()
	local per = Config.Lane.WallsPerBiome
	eq(Formulas.GetRunWins(0), 0)
	eq(Formulas.GetRunWins(per), per * Config.Biomes[1].WinsPerWall)
	eq(Formulas.GetRunWins(per + 1), per * Config.Biomes[1].WinsPerWall + Config.Biomes[2].WinsPerWall)
	eq(Formulas.GetWallBiomeIndex(1), 1)
	eq(Formulas.GetWallBiomeIndex(per + 1), 2)
	local data = freshData()
	data.Rebirths = 10
	data.Passes.DoubleWins = true
	near(Formulas.GetWinsMultiplier(data, NOW), 2 * 2)
end)

test("Run duration is clamped", function()
	eq(Formulas.GetRunDuration(0), Config.Lane.MinDuration)
	eq(Formulas.GetRunDuration(1e9), Config.Lane.MaxDuration)
end)

--------------------------------------------------------------------------------
-- Levels, rebirth, rewards
--------------------------------------------------------------------------------

test("Levels climb to MAX exactly at the rebirth cost", function()
	local cost = Formulas.GetRebirthCost(0)
	eq(cost, Config.Rebirth.BaseCost)
	eq((Formulas.GetLevel(0, 0)), 1)
	eq((Formulas.GetLevel(cost, 0)), Config.Rebirth.MaxLevel)
	eq((Formulas.GetLevel(cost - 1, 0)), Config.Rebirth.MaxLevel - 1)
	local last = 0
	for strength = 0, cost, cost / 200 do
		local level, progress = Formulas.GetLevel(strength, 0)
		assert(level >= last, "monotonic")
		assert(progress >= 0 and progress <= 1, "progress range")
		last = level
	end
	eq(Formulas.GetRebirthCost(1), math.floor(Config.Rebirth.BaseCost * Config.Rebirth.CostGrowth))
end)

test("Offline earnings need a minimum time and are capped", function()
	local data = freshData()
	eq(Formulas.GetOfflineGain(data, 10), 0)
	local hour = Formulas.GetOfflineGain(data, 3600)
	assert(hour > 0)
	eq(Formulas.GetOfflineGain(data, 1e9), Formulas.GetOfflineGain(data, Config.Offline.MaxHours * 3600))
end)

test("Playtime reward amounts scale with the player", function()
	local data = freshData()
	local reward = Config.PlaytimeRewards[1]
	eq(Formulas.GetPlaytimeRewardAmount(reward, data, NOW), reward.Chops)
	data.Rebirths = 2
	eq(Formulas.GetPlaytimeRewardAmount(reward, data, NOW), reward.Chops * 2)
end)

test("Walk speed comes from an owned trail", function()
	local data = freshData()
	eq(Formulas.GetWalkSpeed(data), Config.BaseWalkSpeed)
	data.EquippedTrail = "Flame"
	eq(Formulas.GetWalkSpeed(data), Config.BaseWalkSpeed, "not owned")
	data.OwnedTrails.Flame = true
	eq(Formulas.GetWalkSpeed(data), Config.BaseWalkSpeed + 4)
end)

--------------------------------------------------------------------------------
-- Config sanity
--------------------------------------------------------------------------------

test("Hand items get strictly better and cost more wins", function()
	for index = 2, #Config.HandItems do
		local prev, item = Config.HandItems[index - 1], Config.HandItems[index]
		assert(item.Bonus > prev.Bonus and item.Wins > prev.Wins, item.Id)
	end
	eq(Config.HandItems[1].Wins, 0, "first item is free")
end)

test("Every referenced pet, pass and product exists", function()
	local passes, products = Config.Monetization.GamePasses, Config.Monetization.Products
	for _, egg in Config.Eggs do
		for petId in egg.Pool do
			assert(Config.Pets[petId], egg.Id .. " pool has unknown pet " .. petId)
		end
		assert(egg.Cost or products[egg.Product], egg.Id .. " needs Cost or a valid Product")
	end
	for _, zone in Config.TrainingZones do
		assert(zone.Pass == nil or passes[zone.Pass], zone.Id .. " pass")
		assert(zone.Pass ~= nil or zone.RequiredRebirths ~= nil, zone.Id .. " unlock rule")
	end
	for petId, def in Config.Pets do
		assert(Config.Rarities[def.Rarity], petId .. " rarity")
		assert(def.Pass == nil or passes[def.Pass], petId .. " pass")
	end
	assert(passes[Config.PremiumItem.Pass], "premium item pass")
	assert(passes[Config.PetsConfig.ExtraSlotsPass], "pet slot pass")
	assert(Config.Pets[products.StarterPack.Pet], "starter pack pet")
	for _, reward in Config.PlaytimeRewards do
		assert(reward.Kind ~= "Egg" or Formulas.GetEgg(reward.Egg), "reward egg")
		assert(reward.Kind ~= "Boost" or Config.Boosts[reward.Boost], "reward boost")
	end
end)

test("Training zones, eggs and trails are ordered", function()
	for index = 2, #Config.Trails do
		assert(Config.Trails[index].Cost > Config.Trails[index - 1].Cost)
	end
	local lastCost = 0
	for _, egg in Config.Eggs do
		if egg.Cost then
			assert(egg.Cost > lastCost, egg.Id)
			lastCost = egg.Cost
		end
	end
	local lastFree = 0
	for _, zone in Config.TrainingZones do
		if not zone.Pass then
			assert(zone.Multiplier > lastFree, zone.Id)
			lastFree = zone.Multiplier
		end
	end
end)

test("Late walls are reachable but demanding", function()
	local lastWall = Formulas.GetWallToughness(Formulas.GetWallCount())
	assert(lastWall > 1e9 and lastWall < 1e13, "last wall toughness " .. lastWall)
end)

print(`\n{passed} passed, {failed} failed`)
if failed > 0 then
	error("tests failed", 0)
end
