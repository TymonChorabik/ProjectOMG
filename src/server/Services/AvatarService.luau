--[[
	AvatarService.luau
	Dresses each character from their profile (built on the server so everyone sees it):
	• hand wraps / gauntlets in the equipped item's colour on both hands (glowing for top items)
	• the equipped trail (Trail between two waist attachments) and its walk-speed bonus
	• collision groups so local wall debris never pushes players around
]]

local PhysicsService = game:GetService("PhysicsService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Formulas = require(Shared.Formulas)

local DataService = require(script.Parent.DataService)

local AvatarService = {}

AvatarService.CHARACTER_GROUP = "Characters"
AvatarService.DEBRIS_GROUP = "Debris"

local WRAP_NAME = "KungFuWrap"
local TRAIL_NAME = "KungFuTrail"
local HANDS = { "RightHand", "LeftHand", "Right Arm", "Left Arm" }

local function clearNamed(character: Model, name: string)
	for _, descendant in character:GetDescendants() do
		if descendant.Name == name then
			descendant:Destroy()
		end
	end
end

local function applyWraps(character: Model, data)
	clearNamed(character, WRAP_NAME)
	local item = Formulas.GetItem(data.EquippedItem)
	if not item or item.Id == Config.HandItems[1].Id then
		return -- bare fists
	end
	for _, handName in HANDS do
		local hand = character:FindFirstChild(handName)
		if hand and hand:IsA("BasePart") then
			local isArm = string.find(handName, "Arm") ~= nil
			local wrap = Instance.new("Part")
			wrap.Name = WRAP_NAME
			wrap.Size = if isArm then Vector3.new(1.1, 0.7, 1.1) else hand.Size + Vector3.new(0.12, 0.12, 0.12)
			wrap.Color = item.Color
			wrap.Material = if item.Glow then Enum.Material.Neon else Enum.Material.SmoothPlastic
			wrap.CanCollide = false
			wrap.CanQuery = false
			wrap.CanTouch = false
			wrap.Massless = true
			wrap.CastShadow = false
			wrap.CFrame = hand.CFrame * (if isArm then CFrame.new(0, -0.7, 0) else CFrame.new())
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = hand
			weld.Part1 = wrap
			weld.Parent = wrap
			wrap.Parent = hand
		end
	end
end

local function applyTrail(character: Model, data)
	clearNamed(character, TRAIL_NAME)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.WalkSpeed = Formulas.GetWalkSpeed(data)
	end

	local trailDef = Formulas.GetTrail(data.EquippedTrail)
	local root = character:FindFirstChild("HumanoidRootPart")
	if not trailDef or not data.OwnedTrails[trailDef.Id] or not root then
		return
	end

	local top = Instance.new("Attachment")
	top.Name = TRAIL_NAME
	top.Position = Vector3.new(0, 0.8, 0.5)
	top.Parent = root
	local bottom = Instance.new("Attachment")
	bottom.Name = TRAIL_NAME
	bottom.Position = Vector3.new(0, -1.2, 0.5)
	bottom.Parent = root

	local trail = Instance.new("Trail")
	trail.Name = TRAIL_NAME
	trail.Attachment0 = top
	trail.Attachment1 = bottom
	trail.Lifetime = 0.5
	trail.LightEmission = 0.8
	trail.FaceCamera = true
	trail.Transparency = NumberSequence.new(0.1, 1)
	if trailDef.Rainbow then
		trail.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 60, 60)),
			ColorSequenceKeypoint.new(0.25, Color3.fromRGB(255, 220, 60)),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(80, 230, 100)),
			ColorSequenceKeypoint.new(0.75, Color3.fromRGB(60, 140, 255)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(200, 80, 255)),
		})
	else
		trail.Color = ColorSequence.new(trailDef.Colors[1], trailDef.Colors[2])
	end
	trail.Parent = root
end

local function refresh(player: Player)
	local character = player.Character
	local data = DataService:GetData(player)
	if character and data then
		applyWraps(character, data)
		applyTrail(character, data)
	end
end

local function setCollisionGroup(instance: Instance)
	if instance:IsA("BasePart") then
		instance.CollisionGroup = AvatarService.CHARACTER_GROUP
	end
end

local function onCharacterAdded(player: Player, character: Model)
	for _, descendant in character:GetDescendants() do
		setCollisionGroup(descendant)
	end
	character.DescendantAdded:Connect(setCollisionGroup)
	character:WaitForChild("HumanoidRootPart", 10)
	character:WaitForChild("Humanoid", 10)
	DataService:WaitForData(player, 30)
	if player.Character == character then
		refresh(player)
	end
end

local function onPlayerAdded(player: Player)
	player.CharacterAdded:Connect(function(character)
		onCharacterAdded(player, character)
	end)
	if player.Character then
		task.spawn(onCharacterAdded, player, player.Character)
	end
end

function AvatarService:Init()
	PhysicsService:RegisterCollisionGroup(AvatarService.CHARACTER_GROUP)
	PhysicsService:RegisterCollisionGroup(AvatarService.DEBRIS_GROUP)
	PhysicsService:CollisionGroupSetCollidable(AvatarService.DEBRIS_GROUP, AvatarService.CHARACTER_GROUP, false)
	PhysicsService:CollisionGroupSetCollidable(AvatarService.DEBRIS_GROUP, AvatarService.DEBRIS_GROUP, false)
end

function AvatarService:Start()
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end
	DataService.ProfileLoaded:Connect(refresh)
	DataService.Changed:Connect(function(player, key)
		if key == "EquippedItem" or key == "EquippedTrail" or key == "OwnedTrails" then
			refresh(player)
		end
	end)
end

return AvatarService
