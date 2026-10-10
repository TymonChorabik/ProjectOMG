--[[
	MonetizationService.luau
	Game passes and developer products from Config.Monetization.

	• Live game: passes are checked with UserOwnsGamePassAsync on join and when bought;
	  products are granted in ProcessReceipt (idempotent: processed PurchaseIds are remembered).
	• Id = 0 → not set up yet: the shop shows the item but buying it explains what to configure.
	• Studio + StudioTestPurchases → buying grants instantly so every feature can be tested.
]]

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Formulas = require(Shared.Formulas)

local ActionService = require(script.Parent.ActionService)
local DataService = require(script.Parent.DataService)
local PetService = require(script.Parent.PetService)
local ProgressService = require(script.Parent.ProgressService)
local RewardsService = require(script.Parent.RewardsService)

local MonetizationService = {}

local Passes = Config.Monetization.GamePasses
local Products = Config.Monetization.Products

local Fail, Success = ActionService.Fail, ActionService.Success

local passNameById: { [number]: string } = {}
local productNameById: { [number]: string } = {}
for name, pass in Passes do
	if pass.Id ~= 0 then
		passNameById[pass.Id] = name
	end
end
for name, product in Products do
	if product.Id ~= 0 then
		productNameById[product.Id] = name
	end
end

local function testMode(): boolean
	return RunService:IsStudio() and Config.Monetization.StudioTestPurchases
end

--------------------------------------------------------------------------------
-- Granting
--------------------------------------------------------------------------------

-- Marks a pass as owned and applies its one-time effects.
function MonetizationService:GrantPass(player: Player, passName: string)
	local data = DataService:GetData(player)
	if not data or not Passes[passName] or data.Passes[passName] then
		return
	end
	data.Passes[passName] = true
	DataService:MarkDirty(player, "Passes")

	if passName == Config.PremiumItem.Pass then
		DataService:Set(player, "EquippedItem", Config.PremiumItem.Id)
	end
	for petId, def in Config.Pets do
		if def.Pass == passName then
			local owned = false
			for _, ownedId in data.Pets do
				if ownedId == petId then
					owned = true
				end
			end
			if not owned then
				local uid = PetService:GivePet(player, petId)
				if uid and not table.find(data.EquippedPets, uid) then
					-- Make room for the pass pet by replacing the weakest equipped pet.
					local weakestIndex, weakestBonus = 1, math.huge
					for index, equippedUid in data.EquippedPets do
						local bonus = Formulas.GetPetBonus(data, data.Pets[equippedUid])
						if bonus < weakestBonus then
							weakestIndex, weakestBonus = index, bonus
						end
					end
					data.EquippedPets[weakestIndex] = uid
					DataService:MarkDirty(player, "EquippedPets")
					PetService:SyncAttribute(player)
				end
			end
		end
	end
	if passName == Config.PetsConfig.ExtraSlotsPass then
		DataService:MarkDirty(player, "EquippedPets")
	end
	ActionService:Notify(player, `Thanks for buying {Passes[passName].Name}! 🎉`, "Success")
end

-- Applies a developer product. Returns false if it couldn't be granted right now.
function MonetizationService:GrantProduct(player: Player, productName: string): boolean
	local data = DataService:GetData(player)
	local product = Products[productName]
	if not data or not product then
		return false
	end

	if productName == "RainbowEgg" then
		local ok, message = PetService:HatchEgg(player, "Rainbow", true)
		if not ok then
			ActionService:Notify(player, message, "Error")
		end
		return ok
	elseif productName == "OfflineTriple" then
		return RewardsService:ClaimOffline(player, Config.Offline.ProductMultiplier)
	end

	if product.OneTime then
		if data.StarterPackBought then
			return true -- already granted; never charge twice for nothing
		end
		DataService:Set(player, "StarterPackBought", true)
	end
	if product.Strength then
		DataService:Increment(player, "Strength", product.Strength)
	end
	if product.Wins then
		ProgressService:GrantWins(player, product.Wins)
	end
	if product.Pet then
		PetService:GivePet(player, product.Pet)
	end
	ActionService:Notify(player, `🎉 {product.Name} delivered!`, "Success")
	return true
end

--------------------------------------------------------------------------------
-- Purchase requests
--------------------------------------------------------------------------------

local function purchase(player: Player, data, arg: string?)
	local kind, name = string.match(arg or "", "^(%a+):(%w+)$")
	if kind == "pass" and name and Passes[name] then
		local pass = Passes[name]
		if data.Passes[name] then
			return Fail(`You already own {pass.Name}!`)
		end
		if testMode() then
			MonetizationService:GrantPass(player, name)
			return Success("(Studio test purchase)")
		end
		if pass.Id == 0 then
			return Fail(`{pass.Name} isn't on sale yet (set its id in Config.Monetization).`)
		end
		MarketplaceService:PromptGamePassPurchase(player, pass.Id)
		return Success()
	elseif kind == "product" and name and Products[name] then
		local product = Products[name]
		if product.OneTime and data.StarterPackBought then
			return Fail("You already bought this!")
		end
		if name == "OfflineTriple" and not RewardsService:HasPendingOffline(player) then
			return Fail("Nothing to claim.")
		end
		if testMode() then
			if MonetizationService:GrantProduct(player, name) then
				return Success("(Studio test purchase)")
			end
			return Fail("Couldn't deliver that right now.")
		end
		if product.Id == 0 then
			return Fail(`{product.Name} isn't on sale yet (set its id in Config.Monetization).`)
		end
		MarketplaceService:PromptProductPurchase(player, product.Id)
		return Success()
	end
	return Fail("Unknown item.")
end

local function processReceipt(receipt): Enum.ProductPurchaseDecision
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	local productName = productNameById[receipt.ProductId]
	local data = player and DataService:GetData(player)
	if not player or not productName or not data then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	if table.find(data.Receipts, receipt.PurchaseId) then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	if not MonetizationService:GrantProduct(player, productName) then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	table.insert(data.Receipts, receipt.PurchaseId)
	while #data.Receipts > Config.Data.MaxReceipts do
		table.remove(data.Receipts, 1)
	end
	DataService:MarkDirty(player, "Receipts")
	task.spawn(DataService.SaveNow, DataService, player)
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

local function checkOwnedPasses(player: Player)
	for name, pass in Passes do
		if pass.Id ~= 0 then
			local ok, owns = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, pass.Id)
			if ok and owns then
				MonetizationService:GrantPass(player, name)
			end
		end
	end
end

function MonetizationService:Init()
	ActionService:Register("Purchase", purchase)
	MarketplaceService.ProcessReceipt = processReceipt
end

function MonetizationService:Start()
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		local name = passNameById[passId]
		if purchased and name then
			MonetizationService:GrantPass(player, name)
		end
	end)
	DataService.ProfileLoaded:Connect(function(player)
		task.spawn(checkOwnedPasses, player)
	end)
	for _, player in Players:GetPlayers() do
		if DataService:GetData(player) then
			task.spawn(checkOwnedPasses, player)
		end
	end
end

return MonetizationService
