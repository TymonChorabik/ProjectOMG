--[[
	Formulas.luau
	Pure progression math. The server uses these as the source of truth; the client uses the
	exact same functions to render previews, so numbers on screen always match rewards.

	`data` is a player profile table (see server/Services/DataService.luau DEFAULT_DATA).
]]

local Config = require(script.Parent.Config)

local Formulas = {}

--------------------------------------------------------------------------------
-- Catalog lookups
--------------------------------------------------------------------------------

local beltsById, beltIndexById = {}, {}
for index, belt in Config.Belts do
	beltsById[belt.Id] = belt
	beltIndexById[belt.Id] = index
end

local aurasById = {}
for _, aura in Config.Auras do
	aurasById[aura.Id] = aura
end

local upgradesById = {}
for _, upgrade in Config.Upgrades do
	upgradesById[upgrade.Id] = upgrade
end

local dojosById = {}
for _, dojo in Config.Dojos do
	dojosById[dojo.Id] = dojo
end

function Formulas.GetBelt(id: string?)
	return if id then beltsById[id] else nil
end

function Formulas.GetBeltIndex(id: string?): number
	return (id and beltIndexById[id]) or 1
end

function Formulas.GetAura(id: string?)
	return if id then aurasById[id] else nil
end

function Formulas.GetUpgrade(id: string?)
	return if id then upgradesById[id] else nil
end

function Formulas.GetDojo(id: string?)
	return if id then dojosById[id] else nil
end

function Formulas.GetBreakable(id: string?)
	return if id then Config.Breakables[id] else nil
end

--------------------------------------------------------------------------------
-- Multipliers
--------------------------------------------------------------------------------

function Formulas.GetUpgradeLevel(data, upgradeId: string): number
	return (data.Upgrades and data.Upgrades[upgradeId]) or 0
end

function Formulas.GetBeltMultiplier(data): number
	local belt = beltsById[data.EquippedBelt]
	return if belt then belt.Multiplier else 1
end

function Formulas.GetAuraMultiplier(data): number
	local aura = aurasById[data.EquippedAura]
	return if aura then aura.PowerMultiplier else 1
end

function Formulas.GetRebirthMultiplier(rebirths: number): number
	return 1 + rebirths * Config.Rebirth.MultiplierPerRebirth
end

-- Total multiplier applied to every chop (excluding dojo training bonus and crits).
function Formulas.GetPowerMultiplier(data): number
	return Formulas.GetBeltMultiplier(data)
		* Formulas.GetAuraMultiplier(data)
		* Formulas.GetRebirthMultiplier(data.Rebirths or 0)
end

function Formulas.GetBaseChopPower(data): number
	local ironPalms = upgradesById.IronPalms
	return Config.Training.BasePower + Formulas.GetUpgradeLevel(data, "IronPalms") * ironPalms.PerLevel
end

-- Power gained from one non-critical chop.
function Formulas.GetChopGain(data, trainingMultiplier: number?): number
	local gain = Formulas.GetBaseChopPower(data) * Formulas.GetPowerMultiplier(data) * (trainingMultiplier or 1)
	return math.max(1, math.floor(gain))
end

function Formulas.GetCritChance(data): number
	local aura = aurasById[data.EquippedAura]
	local chance = (if aura then aura.CritChance else 0)
		+ Formulas.GetUpgradeLevel(data, "Focus") * upgradesById.Focus.PerLevel
	return math.clamp(chance, 0, Config.Training.MaxCritChance)
end

function Formulas.GetCoinMultiplier(data): number
	local greed = 1 + Formulas.GetUpgradeLevel(data, "Greed") * upgradesById.Greed.PerLevel
	local rebirth = 1 + (data.Rebirths or 0) * Config.Rebirth.CoinBonusPerRebirth
	return greed * rebirth
end

function Formulas.GetSmashReward(data, breakableId: string): number
	local def = Config.Breakables[breakableId]
	if not def then
		return 0
	end
	return math.floor(def.Coins * Formulas.GetCoinMultiplier(data))
end

function Formulas.GetAutoChopInterval(data): number
	local training = Config.Training
	local interval = training.AutoChopBaseInterval
		- Formulas.GetUpgradeLevel(data, "Speed") * upgradesById.Speed.PerLevel
	return math.max(training.AutoChopMinInterval, interval)
end

--------------------------------------------------------------------------------
-- Costs
--------------------------------------------------------------------------------

function Formulas.GetUpgradeCost(upgradeId: string, level: number): number
	local upgrade = upgradesById[upgradeId]
	if not upgrade then
		return math.huge
	end
	return math.floor(upgrade.BaseCost * upgrade.CostGrowth ^ level)
end

function Formulas.GetRebirthCost(rebirths: number): number
	return math.floor(Config.Rebirth.BaseCost * Config.Rebirth.CostGrowth ^ rebirths)
end

--------------------------------------------------------------------------------
-- Ownership helpers
--------------------------------------------------------------------------------

-- Index of the highest belt the player owns (belts are bought in order).
function Formulas.GetHighestBeltIndex(data): number
	local highest = 1
	for index, belt in Config.Belts do
		if data.OwnedBelts and data.OwnedBelts[belt.Id] then
			highest = index
		end
	end
	return highest
end

function Formulas.GetNextBelt(data)
	return Config.Belts[Formulas.GetHighestBeltIndex(data) + 1]
end

function Formulas.GetBestOwnedAura(data): string
	local bestId, bestMultiplier = "None", 1
	for _, aura in Config.Auras do
		if data.OwnedAuras and data.OwnedAuras[aura.Id] and aura.PowerMultiplier > bestMultiplier then
			bestId, bestMultiplier = aura.Id, aura.PowerMultiplier
		end
	end
	return bestId
end

function Formulas.IsDojoUnlocked(data, dojoId: string): boolean
	local dojo = dojosById[dojoId]
	return dojo ~= nil and (data.Rebirths or 0) >= dojo.RequiredRebirths
end

-- Which dojo (if any) contains a world position. Dojos are axis-aligned rectangles.
function Formulas.GetDojoAtPosition(x: number, y: number, z: number)
	for _, dojo in Config.Dojos do
		local origin, size = dojo.Origin, dojo.Size
		if
			math.abs(x - origin.X) <= size.X / 2
			and math.abs(z - origin.Z) <= size.Z / 2
			and y > origin.Y - 40
			and y < origin.Y + 120
		then
			return dojo
		end
	end
	return nil
end

return Formulas
