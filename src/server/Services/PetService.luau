--[[
	PetService.luau
	Eggs, hatching and the pet inventory. Pets multiply Strength (see Formulas.GetEquippedPetBonus).
	Equipped pet ids are mirrored to the player attribute "PetIds" so every client can render
	everyone's pets following them.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Formulas = require(Shared.Formulas)
local NumberFormat = require(Shared.NumberFormat)
local Remotes = require(Shared.Remotes)

local ActionService = require(script.Parent.ActionService)
local DataService = require(script.Parent.DataService)

local PetService = {}

local rng = Random.new()

local function countPets(data): number
	local count = 0
	for _ in data.Pets do
		count += 1
	end
	return count
end

local function syncPetAttribute(player: Player, data)
	local ids = {}
	for _, uid in data.EquippedPets do
		local petId = data.Pets[uid]
		if petId then
			table.insert(ids, petId)
		end
	end
	player:SetAttribute("PetIds", table.concat(ids, ","))
end

local function petsChanged(player: Player, data)
	DataService:MarkDirty(player, "Pets")
	DataService:MarkDirty(player, "EquippedPets")
	DataService:MarkDirty(player, "NextPetUid")
	syncPetAttribute(player, data)
end

function PetService:SyncAttribute(player: Player)
	local data = DataService:GetData(player)
	if data then
		syncPetAttribute(player, data)
	end
end

function PetService:HasRoom(data): boolean
	return countPets(data) < Config.PetsConfig.MaxInventory
end

-- Adds a pet to the inventory (auto-equips into a free slot). Returns its uid.
function PetService:GivePet(player: Player, petId: string): string?
	local data = DataService:GetData(player)
	if not data or not Config.Pets[petId] or not self:HasRoom(data) then
		return nil
	end
	local uid = "p" .. data.NextPetUid
	data.NextPetUid += 1
	data.Pets[uid] = petId
	if #data.EquippedPets < Formulas.GetPetSlots(data) then
		table.insert(data.EquippedPets, uid)
	end
	petsChanged(player, data)
	return uid
end

-- Rolls an egg and gives the pet. `paid` = true when the cost was already handled (Robux, gifts).
function PetService:HatchEgg(player: Player, eggId: string, paid: boolean): (boolean, string)
	local data = DataService:GetData(player)
	local egg = Formulas.GetEgg(eggId)
	if not data or not egg then
		return false, "Unknown egg."
	end
	if not self:HasRoom(data) then
		return false, "Your pet inventory is full! Delete some pets first."
	end
	if not paid then
		if not egg.Cost then
			return false, "This egg is bought with Robux."
		end
		if data.Wins < egg.Cost then
			return false, `You need {NumberFormat.Abbreviate(egg.Cost)} Wins!`
		end
		DataService:Set(player, "Wins", data.Wins - egg.Cost)
	end

	local luck = Formulas.IsBoostActive(data, "Luck", os.time())
	local petId = Formulas.RollEgg(egg.Id, rng:NextNumber(), luck) or "Puppy"
	local uid = self:GivePet(player, petId)
	if not uid then
		return false, "Your pet inventory is full!"
	end
	data.Stats.EggsHatched += 1
	Remotes.Hatched:FireClient(player, egg.Id, petId, uid)
	return true, `You hatched a {Config.Pets[petId].Name}!`
end

--------------------------------------------------------------------------------
-- Actions
--------------------------------------------------------------------------------

local Fail, Success = ActionService.Fail, ActionService.Success

local function hatch(player: Player, _data, eggId: string?)
	local ok, message = PetService:HatchEgg(player, eggId or "", false)
	return if ok then Success(nil) else Fail(message)
end

local function equip(player: Player, data, uid: string?)
	if not uid or not data.Pets[uid] then
		return Fail("You don't own that pet.")
	end
	if table.find(data.EquippedPets, uid) then
		return Fail("Already equipped.")
	end
	if #data.EquippedPets >= Formulas.GetPetSlots(data) then
		return Fail("All pet slots are full! Unequip one first.")
	end
	table.insert(data.EquippedPets, uid)
	petsChanged(player, data)
	return Success()
end

local function unequip(player: Player, data, uid: string?)
	local index = uid and table.find(data.EquippedPets, uid)
	if not index then
		return Fail("That pet isn't equipped.")
	end
	table.remove(data.EquippedPets, index)
	petsChanged(player, data)
	return Success()
end

local function equipBest(player: Player, data)
	data.EquippedPets = Formulas.GetBestPetUids(data, Formulas.GetPetSlots(data))
	petsChanged(player, data)
	return Success("Equipped your best pets!")
end

local function delete(player: Player, data, uid: string?)
	if not uid or not data.Pets[uid] then
		return Fail("You don't own that pet.")
	end
	local name = Config.Pets[data.Pets[uid]].Name
	local index = table.find(data.EquippedPets, uid)
	if index then
		table.remove(data.EquippedPets, index)
	end
	data.Pets[uid] = nil
	petsChanged(player, data)
	return Success(`Deleted {name}.`)
end

function PetService:Init()
	ActionService:Register("HatchEgg", hatch)
	ActionService:Register("EquipPet", equip)
	ActionService:Register("UnequipPet", unequip)
	ActionService:Register("EquipBestPets", equipBest)
	ActionService:Register("DeletePet", delete)
end

function PetService:Start()
	DataService.ProfileLoaded:Connect(syncPetAttribute)
	for _, player in Players:GetPlayers() do
		local data = DataService:GetData(player)
		if data then
			syncPetAttribute(player, data)
		end
	end
end

return PetService
