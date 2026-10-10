--[[
	ProgressService.luau
	Wins, hand items, trails and rebirths.
	• GrantWins adds spendable + lifetime Wins and auto-equips any better item it unlocks.
	• Hand items are unlocked by lifetime Wins (never spent); equip any unlocked one.
	• Trails are bought with Wins and add walk speed.
	• Rebirth at max level resets Strength for a permanent multiplier and new zones.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Formulas = require(Shared.Formulas)
local NumberFormat = require(Shared.NumberFormat)

local ActionService = require(script.Parent.ActionService)
local DataService = require(script.Parent.DataService)

local ProgressService = {}

local Fail, Success = ActionService.Fail, ActionService.Success

-- Adds Wins (and lifetime Wins) and announces/equips newly unlocked items.
function ProgressService:GrantWins(player: Player, amount: number)
	local data = DataService:GetData(player)
	if not data or amount <= 0 then
		return
	end
	local before = Formulas.GetBestUnlockedItem(data)
	DataService:Set(player, "Wins", data.Wins + amount)
	DataService:Set(player, "TotalWins", data.TotalWins + amount)

	local best = Formulas.GetBestUnlockedItem(data)
	if best.Id ~= before.Id then
		ActionService:Notify(
			player,
			`🔓 Unlocked {best.Name} (+{NumberFormat.Abbreviate(best.Bonus)} Strength)!`,
			"Success"
		)
		if data.EquippedItem ~= Config.PremiumItem.Id then
			DataService:Set(player, "EquippedItem", best.Id)
		end
	end
end

--------------------------------------------------------------------------------
-- Actions
--------------------------------------------------------------------------------

local function equipItem(player: Player, data, arg: string?)
	if type(arg) ~= "string" then
		return Fail("Unknown item.")
	end
	local itemId = arg :: string
	local item = Formulas.GetItem(itemId)
	if not item then
		return Fail("Unknown item.")
	end
	if not Formulas.IsItemUnlocked(data, itemId) then
		if item.Pass then
			return Fail(`Get the {item.Name} in the shop!`)
		end
		return Fail(`Reach {NumberFormat.Abbreviate(item.Wins)} Wins to unlock {item.Name}!`)
	end
	DataService:Set(player, "EquippedItem", itemId)
	return Success(`Equipped {item.Name}!`)
end

local function buyTrail(player: Player, data, trailId: string?)
	local trail = Formulas.GetTrail(trailId)
	if not trail then
		return Fail("Unknown trail.")
	end
	if data.OwnedTrails[trail.Id] then
		DataService:Set(player, "EquippedTrail", trail.Id)
		return Success(`Equipped {trail.Name}!`)
	end
	if data.Wins < trail.Cost then
		return Fail(`You need {NumberFormat.Abbreviate(trail.Cost)} Wins!`)
	end
	DataService:Set(player, "Wins", data.Wins - trail.Cost)
	data.OwnedTrails[trail.Id] = true
	DataService:MarkDirty(player, "OwnedTrails")
	DataService:Set(player, "EquippedTrail", trail.Id)
	return Success(`Bought the {trail.Name} trail!`)
end

local function equipTrail(player: Player, data, trailId: string?)
	if trailId == "None" then
		DataService:Set(player, "EquippedTrail", "None")
		return Success("Trail unequipped.")
	end
	local trail = Formulas.GetTrail(trailId)
	if not trail or not data.OwnedTrails[trail.Id] then
		return Fail("You don't own that trail.")
	end
	DataService:Set(player, "EquippedTrail", trail.Id)
	return Success(`Equipped {trail.Name}!`)
end

-- Performs a rebirth. `skip` (the Skip Rebirth product) ignores the level requirement.
function ProgressService:Rebirth(player: Player, skip: boolean?): (boolean, string)
	local data = DataService:GetData(player)
	if not data then
		return false, "Your data is still loading..."
	end
	local cost = Formulas.GetRebirthCost(data.Rebirths)
	if data.Strength < cost and not skip then
		return false, `Reach Level {Config.Rebirth.MaxLevel} ({NumberFormat.Abbreviate(cost)} Strength) to rebirth!`
	end
	local newRebirths = data.Rebirths + 1
	DataService:Set(player, "Strength", 0)
	DataService:Set(player, "Rebirths", newRebirths)

	local message = `🌀 Rebirth {newRebirths}! Strength is now {NumberFormat.Multiplier(
		Formulas.GetRebirthMultiplier(newRebirths)
	)}.`
	for _, zone in Config.TrainingZones do
		if zone.RequiredRebirths == newRebirths then
			message ..= ` {zone.Name} unlocked!`
		end
	end
	return true, message
end

local function rebirth(player: Player)
	local ok, message = ProgressService:Rebirth(player)
	return if ok then Success(message) else Fail(message)
end

function ProgressService:Init()
	ActionService:Register("EquipItem", equipItem)
	ActionService:Register("BuyTrail", buyTrail)
	ActionService:Register("EquipTrail", equipTrail)
	ActionService:Register("Rebirth", rebirth)
end

function ProgressService:Start() end

return ProgressService
