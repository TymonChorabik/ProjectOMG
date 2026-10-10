--[[
	AvatarService.luau
	Physically dresses each character: a stud-plastic martial-arts belt welded around the waist
	(R15 and R6) and the equipped hand aura (particles + light on both hands). Built on the
	server so every player sees everyone's rank and aura.
]]

local PhysicsService = game:GetService("PhysicsService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Formulas = require(Shared.Formulas)

local DataService = require(script.Parent.DataService)
local ShopService = require(script.Parent.ShopService)
local WorldService = require(script.Parent.WorldService)

local AvatarService = {}

local BELT_NAME = "KungFuBelt"
local AURA_NAME = "KungFuAura"
local HAND_NAMES = { "RightHand", "LeftHand", "Right Arm", "Left Arm" }

AvatarService.CHARACTER_GROUP = "Characters"
AvatarService.DEBRIS_GROUP = "Debris"

--------------------------------------------------------------------------------
-- Belt
--------------------------------------------------------------------------------

local function weldedPart(
	parent: Instance,
	torso: BasePart,
	name: string,
	size: Vector3,
	offset: CFrame,
	color: Color3,
	material: Enum.Material
): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Color = color
	part.Material = material
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Massless = true
	part.CFrame = torso.CFrame * offset

	local weld = Instance.new("WeldConstraint")
	weld.Part0 = torso
	weld.Part1 = part
	weld.Parent = part

	part.Parent = parent
	return part
end

local function applyBelt(character: Model, beltId: string)
	local existing = character:FindFirstChild(BELT_NAME)
	if existing then
		existing:Destroy()
	end

	local belt = Formulas.GetBelt(beltId) or Config.Belts[1]
	local torso = character:FindFirstChild("LowerTorso") or character:FindFirstChild("Torso")
	if not torso or not torso:IsA("BasePart") then
		return
	end

	local isR15 = torso.Name == "LowerTorso"
	local size = torso.Size
	local bandHeight = if isR15 then math.min(0.32, size.Y * 0.8) else 0.36
	local bandY = if isR15 then size.Y * 0.2 else -size.Y * 0.28
	local front = -(size.Z / 2 + 0.1)
	local material = if belt.Glow then Enum.Material.Neon else Enum.Material.SmoothPlastic

	local model = Instance.new("Model")
	model.Name = BELT_NAME

	weldedPart(
		model,
		torso,
		"Band",
		Vector3.new(size.X + 0.12, bandHeight, size.Z + 0.12),
		CFrame.new(0, bandY, 0),
		belt.Color,
		material
	)
	weldedPart(
		model,
		torso,
		"Knot",
		Vector3.new(0.5, bandHeight + 0.14, 0.24),
		CFrame.new(0, bandY, front),
		belt.Color,
		material
	)

	for _, side in { -1, 1 } do
		local tailOffset = CFrame.new(side * 0.17, bandY - 0.38, front - 0.04)
			* CFrame.Angles(0, 0, math.rad(side * 14))
		weldedPart(model, torso, "Tail", Vector3.new(0.2, 0.72, 0.08), tailOffset, belt.Color, material)
		if belt.Stripe then
			weldedPart(
				model,
				torso,
				"Stripe",
				Vector3.new(0.22, 0.12, 0.1),
				tailOffset * CFrame.new(0, -0.24, 0),
				belt.Stripe,
				Enum.Material.SmoothPlastic
			)
		end
	end

	if belt.Glow then
		local knot = model:FindFirstChild("Knot") :: BasePart
		local sparkles = Instance.new("ParticleEmitter")
		sparkles.Texture = Config.Assets.Particles.Sparkle
		sparkles.Color = ColorSequence.new(belt.Color, Color3.fromRGB(255, 120, 40))
		sparkles.LightEmission = 1
		sparkles.Size = NumberSequence.new(0.5, 0)
		sparkles.Lifetime = NumberRange.new(0.6, 1)
		sparkles.Rate = 12
		sparkles.Speed = NumberRange.new(1, 2)
		sparkles.SpreadAngle = Vector2.new(180, 180)
		sparkles.Parent = knot
		local light = Instance.new("PointLight")
		light.Color = belt.Color
		light.Range = 8
		light.Brightness = 1.5
		light.Parent = knot
	end

	model.Parent = character
end

--------------------------------------------------------------------------------
-- Aura
--------------------------------------------------------------------------------

local function applyAura(character: Model, auraId: string)
	for _, descendant in character:GetDescendants() do
		if descendant.Name == AURA_NAME and descendant:IsA("Attachment") then
			descendant:Destroy()
		end
	end

	local aura = Formulas.GetAura(auraId)
	if not aura then
		return
	end

	local particle = aura.Particle
	for _, handName in HAND_NAMES do
		local hand = character:FindFirstChild(handName)
		if hand and hand:IsA("BasePart") then
			local attachment = Instance.new("Attachment")
			attachment.Name = AURA_NAME
			-- R6 arms are 2 studs long: put the effect at the fist.
			attachment.Position = if string.find(handName, "Arm") then Vector3.new(0, -0.9, 0) else Vector3.zero

			local emitter = Instance.new("ParticleEmitter")
			emitter.Texture = particle.Texture
			emitter.Color = ColorSequence.new(particle.Colors[1], particle.Colors[2])
			emitter.LightEmission = 1
			emitter.LightInfluence = 0
			emitter.Size = NumberSequence.new({
				NumberSequenceKeypoint.new(0, particle.Size),
				NumberSequenceKeypoint.new(1, 0),
			})
			emitter.Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.15),
				NumberSequenceKeypoint.new(1, 1),
			})
			emitter.Lifetime = NumberRange.new(particle.Lifetime * 0.6, particle.Lifetime)
			emitter.Rate = particle.Rate
			emitter.Speed = NumberRange.new(particle.Speed * 0.4, particle.Speed)
			emitter.SpreadAngle = Vector2.new(180, 180)
			emitter.Rotation = NumberRange.new(0, 360)
			emitter.RotSpeed = NumberRange.new(-180, 180)
			emitter.Acceleration = Vector3.new(0, 2, 0)
			emitter.Parent = attachment

			local light = Instance.new("PointLight")
			light.Color = aura.Color
			light.Range = 7
			light.Brightness = 1.6
			light.Parent = attachment

			attachment.Parent = hand
		end
	end
end

--------------------------------------------------------------------------------
-- Character lifecycle
--------------------------------------------------------------------------------

local function setCollisionGroup(instance: Instance)
	if instance:IsA("BasePart") then
		instance.CollisionGroup = AvatarService.CHARACTER_GROUP
	end
end

local function refresh(player: Player)
	local character = player.Character
	local data = DataService:GetData(player)
	if not character or not data then
		return
	end
	applyBelt(character, data.EquippedBelt)
	applyAura(character, data.EquippedAura)
end

local function onCharacterAdded(player: Player, character: Model)
	for _, descendant in character:GetDescendants() do
		setCollisionGroup(descendant)
	end
	character.DescendantAdded:Connect(setCollisionGroup)

	-- Wait for the body parts the belt and aura attach to.
	character:WaitForChild("HumanoidRootPart", 10)
	local torso = character:FindFirstChild("LowerTorso")
		or character:FindFirstChild("Torso")
		or character:WaitForChild("LowerTorso", 5)
	if not torso then
		return
	end
	if player.Character ~= character then
		return
	end

	-- Respawn in the dojo the player was last training in.
	local data = DataService:WaitForData(player, 30)
	local dojoId = ShopService:GetCurrentDojo(player)
	if data and dojoId ~= Config.Dojos[1].Id and Formulas.IsDojoUnlocked(data, dojoId) then
		local arrival = WorldService:GetArrivalCFrame(dojoId)
		if arrival then
			task.defer(function()
				if player.Character == character then
					character:PivotTo(arrival)
				end
			end)
		end
	end

	refresh(player)
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
		if key == "EquippedBelt" or key == "EquippedAura" then
			refresh(player)
		end
	end)
end

return AvatarService
