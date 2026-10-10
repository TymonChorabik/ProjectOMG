-- tests/spec.luau — appended to the bundle built by tests/run.py (`module(path)` is provided there).

local Config = module("Shared/Config")
local Formulas = module("Shared/Formulas")
local NumberFormat = module("Shared/NumberFormat")
local Shapes = module("Server/Modules/Shapes")
local BreakableLayout = module("Server/Modules/BreakableLayout")

local passed, failed = 0, 0

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

local function freshData()
	return {
		Power = 0,
		Coins = 0,
		Rebirths = 0,
		OwnedBelts = { White = true },
		EquippedBelt = "White",
		OwnedAuras = {},
		EquippedAura = "None",
		Upgrades = { IronPalms = 0, Focus = 0, Greed = 0, Speed = 0 },
	}
end

--------------------------------------------------------------------------------
-- NumberFormat
--------------------------------------------------------------------------------

test("Abbreviate small numbers", function()
	eq(NumberFormat.Abbreviate(0), "0")
	eq(NumberFormat.Abbreviate(7.9), "7")
	eq(NumberFormat.Abbreviate(999), "999")
end)

test("Abbreviate suffixes", function()
	eq(NumberFormat.Abbreviate(1000), "1K")
	eq(NumberFormat.Abbreviate(1234), "1.23K")
	eq(NumberFormat.Abbreviate(12345), "12.3K")
	eq(NumberFormat.Abbreviate(123456), "123K")
	eq(NumberFormat.Abbreviate(5_000_000), "5M")
	eq(NumberFormat.Abbreviate(1.5e9), "1.5B")
	eq(NumberFormat.Abbreviate(15e9), "15B")
	eq(NumberFormat.Abbreviate(2.5e12), "2.5T")
	eq(NumberFormat.Abbreviate(-1234), "-1.23K")
end)

test("Abbreviate rolls over instead of printing 1000K", function()
	eq(NumberFormat.Abbreviate(999_999), "1M")
	eq(NumberFormat.Abbreviate(999_500), "1M")
	eq(NumberFormat.Abbreviate(999_400), "999K")
end)

test("Commas / Multiplier / Percent", function()
	eq(NumberFormat.Commas(1234567), "1,234,567")
	eq(NumberFormat.Commas(123), "123")
	eq(NumberFormat.Commas(-1000), "-1,000")
	eq(NumberFormat.Multiplier(2), "x2")
	eq(NumberFormat.Multiplier(1.5), "x1.5")
	eq(NumberFormat.Percent(0.05), "5%")
	eq(NumberFormat.Percent(0.125), "12.5%")
end)

--------------------------------------------------------------------------------
-- Formulas
--------------------------------------------------------------------------------

test("A fresh player gains exactly +1 per chop", function()
	eq(Formulas.GetChopGain(freshData()), 1)
	eq(Formulas.GetChopGain(freshData(), 1), 1)
end)

test("Belts, auras, rebirths and dojos multiply the chop", function()
	local data = freshData()
	data.OwnedBelts.Yellow = true
	data.EquippedBelt = "Yellow"
	eq(Formulas.GetChopGain(data), 2, "yellow belt")

	data.OwnedAuras.FirePalms = true
	data.EquippedAura = "FirePalms"
	eq(Formulas.GetChopGain(data), 3, "yellow + fire palms (2 * 1.5)")

	data.Rebirths = 1
	eq(Formulas.GetChopGain(data), 6, "+ 1 rebirth (x2)")
	eq(Formulas.GetChopGain(data, 2), 12, "+ Shaolin training x2")

	data.Upgrades.IronPalms = 4
	eq(Formulas.GetBaseChopPower(data), 5, "iron palms base")
	eq(Formulas.GetChopGain(data), 30, "5 base * 6")
end)

test("Crit chance stacks and clamps", function()
	local data = freshData()
	eq(Formulas.GetCritChance(data), 0)
	data.EquippedAura = "GalaxyPalms"
	data.OwnedAuras.GalaxyPalms = true
	data.Upgrades.Focus = 25
	local expected = math.min(0.2 + 0.25, Config.Training.MaxCritChance)
	assert(math.abs(Formulas.GetCritChance(data) - expected) < 1e-9, "crit stack")
	data.Upgrades.Focus = 1000
	eq(Formulas.GetCritChance(data), Config.Training.MaxCritChance, "clamped")
end)

test("Costs scale geometrically", function()
	eq(Formulas.GetRebirthCost(0), Config.Rebirth.BaseCost)
	eq(Formulas.GetRebirthCost(1), Config.Rebirth.BaseCost * Config.Rebirth.CostGrowth)
	eq(Formulas.GetUpgradeCost("IronPalms", 0), 20)
	assert(Formulas.GetUpgradeCost("IronPalms", 10) > Formulas.GetUpgradeCost("IronPalms", 9))
	eq(Formulas.GetUpgradeCost("Nope", 0), math.huge)
end)

test("Smash rewards include coin multipliers", function()
	local data = freshData()
	eq(Formulas.GetSmashReward(data, "WoodenBoard"), Config.Breakables.WoodenBoard.Coins)
	data.Upgrades.Greed = 10 -- +100%
	eq(Formulas.GetSmashReward(data, "WoodenBoard"), Config.Breakables.WoodenBoard.Coins * 2)
	eq(Formulas.GetSmashReward(data, "Unknown"), 0)
end)

test("Auto-chop interval improves and respects the floor", function()
	local data = freshData()
	eq(Formulas.GetAutoChopInterval(data), Config.Training.AutoChopBaseInterval)
	data.Upgrades.Speed = 100
	eq(Formulas.GetAutoChopInterval(data), Config.Training.AutoChopMinInterval)
	-- Auto-chop must never outrun the server's refill rate.
	assert(1 / Config.Training.AutoChopMinInterval <= Config.Training.ServerBucketRefillPerSecond)
	assert(1 / Config.Training.ClientMinInterval <= Config.Training.ServerBucketRefillPerSecond)
end)

test("Belt helpers", function()
	local data = freshData()
	eq(Formulas.GetHighestBeltIndex(data), 1)
	eq(Formulas.GetNextBelt(data).Id, "Yellow")
	data.OwnedBelts.Yellow = true
	eq(Formulas.GetNextBelt(data).Id, "Orange")
	eq(Formulas.GetBestOwnedAura(data), "None")
	data.OwnedAuras.FirePalms = true
	data.OwnedAuras.FrostFists = true
	eq(Formulas.GetBestOwnedAura(data), "FrostFists")
end)

test("Dojo lookup by position and unlocks", function()
	for _, dojo in Config.Dojos do
		local found = Formulas.GetDojoAtPosition(dojo.Origin.X, dojo.Origin.Y + 3, dojo.Origin.Z)
		eq(found and found.Id, dojo.Id, "dojo at origin")
	end
	eq(Formulas.GetDojoAtPosition(500, 0, 0), nil, "between dojos")
	local data = freshData()
	assert(Formulas.IsDojoUnlocked(data, "Starter"))
	assert(not Formulas.IsDojoUnlocked(data, "Shaolin"))
	data.Rebirths = 1
	assert(Formulas.IsDojoUnlocked(data, "Shaolin"))
	assert(not Formulas.IsDojoUnlocked(data, "Nowhere"))
end)

--------------------------------------------------------------------------------
-- Config sanity
--------------------------------------------------------------------------------

test("Belts are ordered by requirement and multiplier", function()
	for index = 2, #Config.Belts do
		local prev, belt = Config.Belts[index - 1], Config.Belts[index]
		assert(belt.RequiredPower > prev.RequiredPower, belt.Id .. " power order")
		assert(belt.Multiplier > prev.Multiplier, belt.Id .. " multiplier order")
		assert(belt.Cost > prev.Cost, belt.Id .. " cost order")
	end
	eq(Config.Belts[1].Id, "White")
	eq(Config.Belts[#Config.Belts].Id, "DragonMaster")
end)

test("Every dojo object exists, uses a known shape, and gets harder", function()
	local lastRequirement = 0
	for _, dojo in Config.Dojos do
		for _, objectId in dojo.Objects do
			local def = Config.Breakables[objectId]
			assert(def, "missing breakable " .. objectId)
			assert(Shapes[def.Shape], objectId .. " unknown shape " .. tostring(def.Shape))
			assert(def.RequiredPower > lastRequirement, objectId .. " should need more power than the previous object")
			assert(def.Coins > 0 and def.Respawn > 0, objectId .. " reward/respawn")
			lastRequirement = def.RequiredPower
		end
	end
end)

test("Prompt reference thresholds", function()
	eq(Config.Breakables.WoodenBoard.RequiredPower, 50)
	eq(Config.Breakables.IronAnvil.RequiredPower, 5_000)
	eq(Config.Breakables.DiamondBlock.RequiredPower, 500_000)
end)

test("Dojo footprints don't overlap", function()
	for i, a in Config.Dojos do
		for j, b in Config.Dojos do
			if i < j then
				local apartX = math.abs(a.Origin.X - b.Origin.X) > (a.Size.X + b.Size.X) / 2
				local apartZ = math.abs(a.Origin.Z - b.Origin.Z) > (a.Size.Z + b.Size.Z) / 2
				assert(apartX or apartZ, a.Id .. " overlaps " .. b.Id)
			end
		end
	end
end)

--------------------------------------------------------------------------------
-- Fracture layouts
--------------------------------------------------------------------------------

local MAX_SEGMENTS = 160 -- per object; keeps debris + replication cheap

test("Every breakable fractures into a sane number of stud segments", function()
	local report = {}
	for id, def in Config.Breakables do
		local cells = BreakableLayout.Compute(
			def.Shape,
			def.Size.X,
			def.Size.Y,
			def.Size.Z,
			def.Grid.X,
			def.Grid.Y,
			def.Grid.Z,
			def.Hollow
		)
		assert(#cells >= 2, id .. " needs at least two segments to shatter")
		assert(#cells <= MAX_SEGMENTS, `{id} has {#cells} segments (max {MAX_SEGMENTS})`)
		for _, cell in cells do
			assert(math.abs(cell.X) <= def.Size.X / 2 + 1e-6, id .. " cell outside X bounds")
			assert(math.abs(cell.Y) <= def.Size.Y / 2 + 1e-6, id .. " cell outside Y bounds")
			assert(math.abs(cell.Z) <= def.Size.Z / 2 + 1e-6, id .. " cell outside Z bounds")
		end
		table.insert(report, `{id}={#cells}`)
	end
	table.sort(report)
	print("      segments: " .. table.concat(report, ", "))
end)

test("Hollowing removes hidden interior cells only", function()
	local solid = BreakableLayout.Compute("Box", 4, 4, 4, 4, 4, 4, false)
	local hollow = BreakableLayout.Compute("Box", 4, 4, 4, 4, 4, 4, true)
	eq(#solid, 64)
	eq(#hollow, 64 - 8) -- the 2x2x2 core is invisible
end)

test("Accent / Alt categories appear where expected", function()
	local function categories(shape, def)
		local seen = {}
		for _, cell in
			BreakableLayout.Compute(
				shape,
				def.Size.X,
				def.Size.Y,
				def.Size.Z,
				def.Grid.X,
				def.Grid.Y,
				def.Grid.Z,
				def.Hollow
			)
		do
			seen[cell.Category] = true
		end
		return seen
	end
	assert(categories("Anvil", Config.Breakables.IronAnvil).Accent, "anvil face")
	assert(categories("Rack", Config.Breakables.ServerRack).Accent, "rack lights")
	local planet = categories("Planet", Config.Breakables.Planet)
	assert(planet.Base and planet.Alt and planet.Accent, "planet ocean/land/ring")
end)

print(`\n{passed} passed, {failed} failed`)
if failed > 0 then
	error("tests failed", 0)
end
