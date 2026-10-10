--[[
	PetController.luau
	Renders every player's equipped pets (from the "PetIds" player attribute) as blocky models
	that float behind their owner with a little bob. Purely visual and client-side.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local PetModels = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("PetModels"))

local PetController = {}

type Follower = { Model: Model, Current: CFrame }

local folder: Folder
local followers: { [Player]: { Ids: string, Pets: { Follower } } } = {}
local hidden: { [Player]: boolean } = {}

local function clear(player: Player)
	local entry = followers[player]
	if entry then
		for _, pet in entry.Pets do
			pet.Model:Destroy()
		end
	end
	followers[player] = nil
end

local function rebuild(player: Player)
	local ids = player:GetAttribute("PetIds")
	ids = if type(ids) == "string" then ids else ""
	local entry = followers[player]
	if entry and entry.Ids == ids then
		return
	end
	clear(player)
	local pets = {}
	for petId in string.gmatch(ids, "[^,]+") do
		local model = PetModels.Build(petId)
		model.Parent = if hidden[player] then nil else folder
		table.insert(pets, { Model = model, Current = CFrame.new() })
	end
	followers[player] = { Ids = ids, Pets = pets }
end

local function watch(player: Player)
	rebuild(player)
	player:GetAttributeChangedSignal("PetIds"):Connect(function()
		rebuild(player)
	end)
end

-- Hides a player's pets on this client (players training on your pad are hidden).
function PetController.SetHidden(player: Player, isHidden: boolean)
	if (hidden[player] == true) == isHidden then
		return
	end
	if isHidden then
		hidden[player] = true
	else
		hidden[player] = nil
	end
	local entry = followers[player]
	if entry then
		for _, pet in entry.Pets do
			pet.Model.Parent = if isHidden then nil else folder
		end
	end
end

-- Slots behind the owner: a row of up to 3, then a second row.
local function slotOffset(index: number, count: number): Vector3
	local row = math.floor((index - 1) / 3)
	local inRow = math.min(3, count - row * 3)
	local column = (index - 1) % 3
	local x = (column - (inRow - 1) / 2) * 4
	return Vector3.new(x, 0, 6 + row * 4)
end

local function step(dt: number)
	local t = os.clock()
	local alpha = 1 - math.exp(-dt * 8)
	for player, entry in followers do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") then
			local base = CFrame.new(root.Position) * CFrame.Angles(0, select(2, root.CFrame:ToEulerAnglesYXZ()), 0)
			for index, pet in entry.Pets do
				local offset = slotOffset(index, #entry.Pets)
				local bob = math.sin(t * 3 + index) * 0.4
				local target = base * CFrame.new(offset.X, -0.6 + bob, offset.Z)
				if (pet.Current.Position - target.Position).Magnitude > 60 then
					pet.Current = target
				else
					pet.Current = pet.Current:Lerp(target, alpha)
				end
				pet.Model:PivotTo(pet.Current)
			end
		end
	end
end

function PetController.Start()
	folder = Instance.new("Folder")
	folder.Name = "Pets"
	folder.Parent = workspace

	Players.PlayerAdded:Connect(watch)
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		clear(player)
		hidden[player] = nil
	end)
	RunService.RenderStepped:Connect(step)
end

return PetController
