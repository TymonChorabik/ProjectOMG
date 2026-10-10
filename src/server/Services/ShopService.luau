--[[
	ShopService.luau
	Every purchase / equip / rebirth / teleport goes through one validated RemoteFunction.
	Handlers re-check ownership, prices and requirements against server data; the client's
	numbers are never trusted.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Formulas = require(Shared.Formulas)
local NumberFormat = require(Shared.NumberFormat)
local Remotes = require(Shared.Remotes)

local DataService = require(script.Parent.DataService)
local WorldService = require(script.Parent.WorldService)

local ShopService = {}

type Result = { ok: boolean, message: string? }

local MAX_ACTIONS_PER_SECOND = 8
local TELEPORT_COOLDOWN = 1.5

local actionLog: { [Player]: { number } } = {}
local lastTeleport: { [Player]: number } = {}
local currentDojo: { [Player]: string } = {}

local function fail(message: string): Result
	return { ok = false, message = message }
end

local function success(message: string?): Result
	return { ok = true, message = message }
end

local function isRateLimited(player: Player): boolean
	local now = os.clock()
	local log = actionLog[player]
	if not log then
		log = {}
		actionLog[player] = log
	end
	while log[1] and now - log[1] > 1 do
		table.remove(log, 1)
	end
	if #log >= MAX_ACTIONS_PER_SECOND then
		return true
	end
	table.insert(log, now)
	return false
end

local function spendCoins(player: Player, data, cost: number): boolean
	if data.Coins < cost then
		return false
	end
	DataService:Set(player, "Coins", data.Coins - cost)
	return true
end

function ShopService:GetCurrentDojo(player: Player): string
	return currentDojo[player] or Config.Dojos[1].Id
end

--------------------------------------------------------------------------------
-- Actions
--------------------------------------------------------------------------------

local Actions: { [string]: (Player, { [string]: any }, any) -> Result } = {}

function Actions.BuyBelt(player, data, beltId)
	local belt = Formulas.GetBelt(beltId)
	if not belt then
		return fail("Unknown belt.")
	end
	if data.OwnedBelts[belt.Id] then
		return fail("You already earned this belt!")
	end
	local nextBelt = Formulas.GetNextBelt(data)
	if not nextBelt or nextBelt.Id ~= belt.Id then
		return fail("Earn the previous belt first!")
	end
	if data.Power < belt.RequiredPower then
		return fail(`You need {NumberFormat.Abbreviate(belt.RequiredPower)} Power to test for the {belt.Name}!`)
	end
	if not spendCoins(player, data, belt.Cost) then
		return fail("Not enough coins!")
	end

	data.OwnedBelts[belt.Id] = true
	DataService:MarkDirty(player, "OwnedBelts")
	DataService:Set(player, "EquippedBelt", belt.Id)
	return success(`Ranked up! You earned the {belt.Name} ({NumberFormat.Multiplier(belt.Multiplier)} power)!`)
end

function Actions.EquipBelt(player, data, beltId)
	local belt = Formulas.GetBelt(beltId)
	if not belt or not data.OwnedBelts[belt.Id] then
		return fail("You don't own that belt.")
	end
	DataService:Set(player, "EquippedBelt", belt.Id)
	return success(`Equipped {belt.Name}.`)
end

function Actions.BuyAura(player, data, auraId)
	local aura = Formulas.GetAura(auraId)
	if not aura then
		return fail("Unknown aura.")
	end
	if data.OwnedAuras[aura.Id] then
		return fail("You already own this aura!")
	end
	if data.Rebirths < aura.RequiredRebirths then
		return fail(`Requires {aura.RequiredRebirths} rebirth(s).`)
	end
	if not spendCoins(player, data, aura.Cost) then
		return fail("Not enough coins!")
	end

	data.OwnedAuras[aura.Id] = true
	DataService:MarkDirty(player, "OwnedAuras")
	DataService:Set(player, "EquippedAura", aura.Id)
	return success(`Unlocked {aura.Name}!`)
end

function Actions.EquipAura(player, data, auraId)
	if auraId == "None" then
		DataService:Set(player, "EquippedAura", "None")
		return success("Aura unequipped.")
	end
	local aura = Formulas.GetAura(auraId)
	if not aura or not data.OwnedAuras[aura.Id] then
		return fail("You don't own that aura.")
	end
	DataService:Set(player, "EquippedAura", aura.Id)
	return success(`Equipped {aura.Name}.`)
end

function Actions.BuyUpgrade(player, data, upgradeId)
	local upgrade = Formulas.GetUpgrade(upgradeId)
	if not upgrade then
		return fail("Unknown upgrade.")
	end
	local level = Formulas.GetUpgradeLevel(data, upgrade.Id)
	if level >= upgrade.MaxLevel then
		return fail("Already maxed out!")
	end
	if not spendCoins(player, data, Formulas.GetUpgradeCost(upgrade.Id, level)) then
		return fail("Not enough coins!")
	end

	data.Upgrades[upgrade.Id] = level + 1
	DataService:MarkDirty(player, "Upgrades")
	return success(`{upgrade.Name} upgraded to level {level + 1}!`)
end

function Actions.Rebirth(player, data)
	local cost = Formulas.GetRebirthCost(data.Rebirths)
	if data.Power < cost then
		return fail(`You need {NumberFormat.Abbreviate(cost)} Power to rebirth.`)
	end

	local newRebirths = data.Rebirths + 1
	DataService:Set(player, "Power", 0)
	DataService:Set(player, "Rebirths", newRebirths)

	local message =
		`Reborn! Permanent power is now {NumberFormat.Multiplier(Formulas.GetRebirthMultiplier(newRebirths))}.`
	for _, dojo in Config.Dojos do
		if dojo.RequiredRebirths == newRebirths then
			message ..= ` {dojo.Name} unlocked!`
		end
	end
	return success(message)
end

function Actions.Teleport(player, data, dojoId)
	local dojo = Formulas.GetDojo(dojoId)
	if not dojo then
		return fail("Unknown dojo.")
	end
	if not Formulas.IsDojoUnlocked(data, dojo.Id) then
		return fail(`Requires {dojo.RequiredRebirths} rebirth(s).`)
	end
	local now = os.clock()
	if now - (lastTeleport[player] or 0) < TELEPORT_COOLDOWN then
		return fail("Catch your breath first!")
	end

	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local arrival = WorldService:GetArrivalCFrame(dojo.Id)
	if not character or not humanoid or humanoid.Health <= 0 or not arrival then
		return fail("You can't travel right now.")
	end

	lastTeleport[player] = now
	currentDojo[player] = dojo.Id
	pcall(function()
		player:RequestStreamAroundAsync(arrival.Position)
	end)
	character:PivotTo(arrival)
	return success(`Welcome to the {dojo.Name}!`)
end

function Actions.EquipBest(player, data)
	local bestBelt = Config.Belts[Formulas.GetHighestBeltIndex(data)]
	DataService:Set(player, "EquippedBelt", bestBelt.Id)
	DataService:Set(player, "EquippedAura", Formulas.GetBestOwnedAura(data))
	return success("Equipped your best gear!")
end

--------------------------------------------------------------------------------
-- Remote handler
--------------------------------------------------------------------------------

local function onAction(player: Player, action: any, arg: any): Result
	if type(action) ~= "string" then
		return fail("Bad request.")
	end
	local handler = Actions[action]
	if not handler then
		return fail("Bad request.")
	end
	if arg ~= nil and (type(arg) ~= "string" or #arg > 64) then
		return fail("Bad request.")
	end
	if isRateLimited(player) then
		return fail("Slow down!")
	end

	local data = DataService:GetData(player)
	if not data then
		return fail("Your data is still loading...")
	end

	local ok, result = pcall(handler, player, data, arg)
	if not ok then
		warn(`[ShopService] {action} failed for {player.Name}: {result}`)
		return fail("Something went wrong. Try again!")
	end
	return result
end

function ShopService:Init()
	Remotes.Action.OnServerInvoke = onAction
end

function ShopService:Start()
	Players.PlayerRemoving:Connect(function(player)
		actionLog[player] = nil
		lastTeleport[player] = nil
		currentDojo[player] = nil
	end)
end

return ShopService
