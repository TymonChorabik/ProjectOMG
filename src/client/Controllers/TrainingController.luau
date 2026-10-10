--[[
	TrainingController.luau
	Training floors, the only way to gain Strength (like the ponds in +1 Stone Skipping).
	• Step onto a floor's pad and you train automatically: your character faces the pool and
	  karate-chops, sending a slash at the floor's item (boards, bamboo, ice...), which shatters
	  into the water and drops back in. Each chop is in step with the server's Strength gain.
	• Everyone else standing on YOUR pad is hidden for you (body, name and pets), so it looks
	  like you're training alone. Players on other pads stay visible and chop too.
	• Stepping on a locked floor tells you what unlocks it.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Formulas = require(Shared.Formulas)
local NumberFormat = require(Shared.NumberFormat)
local Remotes = require(Shared.Remotes)
local TrainingPads = require(Shared.TrainingPads)

local ClientData = require(script.Parent.Parent.ClientData)
local Sfx = require(script.Parent.Parent.Effects.Sfx)
local TrainingAnimator = require(script.Parent.Parent.Effects.TrainingAnimator)
local Popups = require(script.Parent.Parent.UI.Popups)
local PetController = require(script.Parent.PetController)

local TrainingController = {}

local CHECK_INTERVAL = 0.1
local RESPAWN_DELAY = 0.28 -- a new item drops in this long after the old one shatters
local SLASH_TIME = 0.12
local SHARD_LIFETIME = 1.3
local MAX_SHARDS = 90 -- across all floors, so busy servers stay smooth

type TargetPart = { Part: BasePart, Transparency: number, CFrame: CFrame }
type Floor = {
	Pad: TrainingPads.Pad,
	Zone: any,
	Target: { TargetPart },
	TargetCenter: Vector3,
	Forward: Vector3, -- from the pad toward the pool
	Broken: boolean,
}

local localPlayer = Players.LocalPlayer
local rng = Random.new()
local pads: { TrainingPads.Pad } = {}
local floors: { [string]: Floor } = {} -- by zone id
local animations: { [Player]: { Handle: TrainingAnimator.Handle, Character: Model, ZoneId: string } } = {}
local hiddenPlayers: { [Player]: boolean } = {}
local disabledEffects: { [Instance]: boolean } = {}
local debrisFolder: Instance? = nil
local liveShards = 0

local currentPad: TrainingPads.Pad? = nil
local facedPool = false

--------------------------------------------------------------------------------
-- Breaking the item
--------------------------------------------------------------------------------

local function getDebrisFolder(): Instance
	if debrisFolder and debrisFolder.Parent then
		return debrisFolder
	end
	local existing = workspace:FindFirstChild("LocalDebris")
	if not existing then
		existing = Instance.new("Folder")
		existing.Name = "LocalDebris"
		existing.Parent = workspace
	end
	debrisFolder = existing
	return existing
end

local function spawnShard(source: BasePart, transparency: number, direction: Vector3)
	if liveShards >= MAX_SHARDS then
		return
	end
	local size = source.Size
	local shard = Instance.new("Part")
	shard.Size = Vector3.new(
		math.max(0.2, size.X * rng:NextNumber(0.2, 0.45)),
		math.max(0.2, size.Y * rng:NextNumber(0.5, 0.9)),
		math.max(0.2, size.Z * rng:NextNumber(0.25, 0.55))
	)
	shard.CFrame = source.CFrame
		* CFrame.new(
			rng:NextNumber(-0.35, 0.35) * size.X,
			rng:NextNumber(-0.2, 0.2) * size.Y,
			rng:NextNumber(-0.35, 0.35) * size.Z
		)
		* CFrame.Angles(rng:NextNumber(0, 6.28), rng:NextNumber(0, 6.28), rng:NextNumber(0, 6.28))
	shard.Color = source.Color
	shard.Material = source.Material
	shard.Transparency = transparency
	shard.Reflectance = source.Reflectance
	shard.TopSurface = Enum.SurfaceType.Smooth
	shard.BottomSurface = Enum.SurfaceType.Smooth
	shard.CastShadow = false
	shard.CanCollide = true
	shard.CanQuery = false
	shard.CanTouch = false
	shard.Massless = true
	shard.CollisionGroup = "Debris"
	shard.Parent = getDebrisFolder()
	local sideways = Vector3.new(-direction.Z, 0, direction.X)
	shard.AssemblyLinearVelocity = direction * rng:NextNumber(8, 16)
		+ sideways * rng:NextNumber(-7, 7)
		+ Vector3.new(0, rng:NextNumber(10, 18), 0)
	shard.AssemblyAngularVelocity = Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(-1, 1), rng:NextNumber(-1, 1))
		* 14
	liveShards += 1

	task.delay(SHARD_LIFETIME - 0.35, function()
		if shard.Parent then
			TweenService:Create(shard, TweenInfo.new(0.35), { Transparency = 1, Size = shard.Size * 0.4 }):Play()
		end
		task.wait(0.35)
		shard:Destroy()
		liveShards -= 1
	end)
end

-- Shatters the floor's item into the pool and drops a fresh one back in after a moment.
local function breakTarget(floor: Floor, piecesPerPart: number)
	if floor.Broken or #floor.Target == 0 then
		return
	end
	floor.Broken = true
	for _, entry in floor.Target do
		for _ = 1, piecesPerPart do
			spawnShard(entry.Part, entry.Transparency, floor.Forward)
		end
		entry.Part.Transparency = 1
	end

	task.delay(RESPAWN_DELAY, function()
		for _, entry in floor.Target do
			entry.Part.Transparency = entry.Transparency
			entry.Part.CFrame = entry.CFrame + Vector3.new(0, 0.8, 0)
			TweenService:Create(
				entry.Part,
				TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
				{ CFrame = entry.CFrame }
			):Play()
		end
		floor.Broken = false
	end)
end

-- A glowing crescent that flies from the chopping hand to the item, then breaks it.
local function slash(character: Model, floor: Floor, piecesPerPart: number)
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		breakTarget(floor, piecesPerPart)
		return
	end
	local from = root.Position + root.CFrame.LookVector * 1.5 - Vector3.new(0, 0.5, 0)
	local to = floor.TargetCenter
	local wave = Instance.new("Part")
	wave.Anchored = true
	wave.CanCollide = false
	wave.CanQuery = false
	wave.CanTouch = false
	wave.CastShadow = false
	wave.Material = Enum.Material.Neon
	wave.Color = Color3.fromRGB(255, 250, 220)
	wave.Transparency = 0.15
	wave.Size = Vector3.new(2.8, 0.15, 0.6)
	local tilt = CFrame.Angles(0, 0, math.rad(rng:NextNumber(-30, 30)))
	wave.CFrame = CFrame.lookAt(from, to) * tilt
	wave.Parent = getDebrisFolder()
	TweenService:Create(wave, TweenInfo.new(SLASH_TIME, Enum.EasingStyle.Linear), {
		CFrame = CFrame.lookAt(to, to + (to - from)) * tilt,
		Size = Vector3.new(3.6, 0.15, 0.6),
	}):Play()
	task.delay(SLASH_TIME, function()
		wave:Destroy()
		breakTarget(floor, piecesPerPart)
	end)
end

--------------------------------------------------------------------------------
-- Strength popups
--------------------------------------------------------------------------------

local function popupPosition(): Vector2
	local camera = workspace.CurrentCamera
	local character = localPlayer.Character
	local head = character and character:FindFirstChild("Head")
	if camera and head and head:IsA("BasePart") then
		local point, visible = camera:WorldToViewportPoint(head.Position + Vector3.new(0, 2, 0))
		if visible then
			return Vector2.new(point.X, point.Y)
		end
	end
	local size = if camera then camera.ViewportSize else Vector2.new(1280, 720)
	return Vector2.new(size.X / 2, size.Y * 0.4)
end

local function showGain(gain: number)
	Popups.ScreenText(popupPosition(), "⚡ +" .. NumberFormat.Abbreviate(gain), Color3.fromRGB(255, 220, 70), 26)
end

-- Server granted one training chop: chop now and show the gain when the hand lands.
local function onChopResult(gain: number)
	local animation = animations[localPlayer]
	if animation then
		animation.Handle.Strike(function()
			showGain(gain)
		end)
	else
		showGain(gain)
	end
end

--------------------------------------------------------------------------------
-- Hiding the players who share your pad
--------------------------------------------------------------------------------

local function applyHidden(player: Player, isHidden: boolean)
	local character = player.Character
	if character then
		for _, descendant in character:GetDescendants() do
			if descendant:IsA("BasePart") or descendant:IsA("Decal") then
				descendant.LocalTransparencyModifier = if isHidden then 1 else 0
			elseif
				descendant:IsA("Trail")
				or descendant:IsA("ParticleEmitter")
				or descendant:IsA("Beam")
				or descendant:IsA("BillboardGui")
			then
				if isHidden and descendant.Enabled then
					descendant.Enabled = false
					disabledEffects[descendant] = true
				elseif not isHidden and disabledEffects[descendant] then
					descendant.Enabled = true
					disabledEffects[descendant] = nil
				end
			end
		end
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.DisplayDistanceType = if isHidden
				then Enum.HumanoidDisplayDistanceType.None
				else Enum.HumanoidDisplayDistanceType.Viewer
		end
	end
	PetController.SetHidden(player, isHidden)
end

local function rootOf(player: Player): BasePart?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

local function updateHidden()
	for _, player in Players:GetPlayers() do
		if player ~= localPlayer then
			local root = rootOf(player)
			local shouldHide = currentPad ~= nil
				and root ~= nil
				and TrainingPads.Contains(currentPad.Part, root.Position)
			if shouldHide then
				-- Re-applied every check so accessories that load late are hidden too.
				hiddenPlayers[player] = true
				applyHidden(player, true)
			elseif hiddenPlayers[player] then
				hiddenPlayers[player] = nil
				applyHidden(player, false)
			end
		end
	end
end

--------------------------------------------------------------------------------
-- Chop animations (you, and everyone visible who is training)
--------------------------------------------------------------------------------

local function updateAnimations()
	for _, player in Players:GetPlayers() do
		local zoneId = player:GetAttribute("Training")
		local floor = if type(zoneId) == "string" then floors[zoneId] else nil
		local character = player.Character
		local isLocal = player == localPlayer
		local wanted = floor ~= nil and character ~= nil and (isLocal or not hiddenPlayers[player])
		local current = animations[player]

		if current and (not wanted or current.Character ~= character or current.ZoneId ~= zoneId) then
			current.Handle.Stop()
			animations[player] = nil
			current = nil
		end
		if wanted and not current and floor and character then
			local handle = TrainingAnimator.Start(character, {
				-- Your chops follow the server's gains (ChopResult); other players loop.
				Period = if isLocal then nil else Config.Training.IdleInterval,
				OnHit = function()
					slash(character, floor, if isLocal then 3 else 2)
					if isLocal then
						Sfx.Play("Smash", { Volume = 0.25, PitchVariance = 0.15 })
					end
				end,
			})
			animations[player] = { Handle = handle, Character = character, ZoneId = floor.Pad.ZoneId }
		end
	end
end

--------------------------------------------------------------------------------
-- The local player's pad
--------------------------------------------------------------------------------

local function onPadChanged(newPad: TrainingPads.Pad?)
	facedPool = false
	if newPad == nil then
		return
	end
	local pad = newPad :: TrainingPads.Pad
	local data = ClientData.Data
	local zone = Formulas.GetZone(pad.ZoneId)
	if data and zone and not Formulas.IsZoneUnlocked(data, zone.Id) then
		Sfx.Play("Denied", { Volume = 0.4 })
		if zone.Pass then
			Popups.Toast(`🔒 Get the {zone.Name} pass to train here!`, "Error")
		else
			Popups.Toast(`🔒 Rebirth {zone.RequiredRebirths} times to train here!`, "Error")
		end
	end
end

local function updateLocal()
	local character = localPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = rootOf(localPlayer)
	local pad: TrainingPads.Pad? = nil
	if humanoid and humanoid.Health > 0 and root and not localPlayer:GetAttribute("Running") then
		pad = TrainingPads.At(pads, root.Position)
	end
	if pad ~= currentPad then
		currentPad = pad
		onPadChanged(pad)
	end

	-- Standing still on a pad: turn to face the pool.
	if pad and humanoid and root then
		if humanoid.MoveDirection.Magnitude > 0.05 then
			facedPool = false
		elseif not facedPool then
			facedPool = true
			local forward = floors[pad.ZoneId] and floors[pad.ZoneId].Forward or pad.Part.CFrame.LookVector
			root.CFrame = CFrame.lookAt(root.Position, root.Position + forward)
		end
	end
end

--------------------------------------------------------------------------------
-- Setup
--------------------------------------------------------------------------------

local function setupFloor(pad: TrainingPads.Pad)
	local zone = Formulas.GetZone(pad.ZoneId)
	if not zone then
		return
	end
	local target: { TargetPart } = {}
	local center = Vector3.zero
	if pad.Target then
		for _, child in pad.Target:GetChildren() do
			if child:IsA("BasePart") then
				table.insert(target, { Part = child, Transparency = child.Transparency, CFrame = child.CFrame })
				center += child.Position
			end
		end
	end
	local look = pad.Part.CFrame.LookVector
	local forward = Vector3.new(look.X, 0, look.Z)
	floors[pad.ZoneId] = {
		Pad = pad,
		Zone = zone,
		Target = target,
		TargetCenter = if #target > 0 then center / #target else pad.Part.Position + forward * 8,
		Forward = if forward.Magnitude > 0.01 then forward.Unit else Vector3.zAxis,
		Broken = false,
	}
end

function TrainingController.IsTraining(): boolean
	return localPlayer:GetAttribute("Training") ~= nil
end

function TrainingController.Start()
	Remotes.ChopResult.OnClientEvent:Connect(onChopResult)

	task.spawn(function()
		local map = workspace:WaitForChild("Map")
		local zones = map:WaitForChild("TrainingZones")
		for _, zone in Config.TrainingZones do
			zones:WaitForChild("Zone_" .. zone.Id, 10)
		end
		pads = TrainingPads.Collect(map)
		for _, pad in pads do
			setupFloor(pad)
		end

		local elapsed = 0
		RunService.Heartbeat:Connect(function(dt)
			elapsed += dt
			if elapsed < CHECK_INTERVAL then
				return
			end
			elapsed = 0
			updateLocal()
			updateHidden()
			updateAnimations()
		end)
	end)

	Players.PlayerRemoving:Connect(function(player)
		local current = animations[player]
		if current then
			current.Handle.Stop()
			animations[player] = nil
		end
		hiddenPlayers[player] = nil
	end)
end

return TrainingController
