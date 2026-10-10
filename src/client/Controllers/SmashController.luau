--[[
	SmashController.luau
	Client side of breaking stands:
	• tracks every stand (CollectionService tag) and its pre-fractured segments
	• finds the stand in front of the player for ChopController
	• on a confirmed smash: shatters the segments into stud debris, impact flash + shockwave,
	  stud chunk burst, screen shake, 3D sound and a coin popup; respawns after the cooldown
	• idle bob/spin for floating objects, "need more power" feedback, live sign colours
]]

local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local NumberFormat = require(Shared.NumberFormat)
local Remotes = require(Shared.Remotes)
local StudSurface = require(Shared.StudSurface)

local ClientData = require(script.Parent.Parent.ClientData)
local CameraShake = require(script.Parent.Parent.Effects.CameraShake)
local Sfx = require(script.Parent.Parent.Effects.Sfx)
local Popups = require(script.Parent.Parent.UI.Popups)

local SmashController = {}

local TAG = "BreakableStand"
local DEBRIS_GROUP = "Debris"
local FLOAT_RANGE = 220
local DENY_COOLDOWN = 0.6

local localPlayer = Players.LocalPlayer

type StandState = {
	Id: string,
	Model: Model,
	Core: BasePart,
	Segments: { BasePart },
	BaseCFrame: CFrame,
	RequiredPower: number,
	Respawn: number,
	Tier: number,
	Radius: number,
	Float: boolean,
	Broken: boolean,
	BrokenToken: number,
	RequirementLabel: TextLabel?,
	Phase: number,
}

local stands: { [string]: StandState } = {}
local debrisFolder: Folder
local lastDeny = 0

--------------------------------------------------------------------------------
-- Stand tracking
--------------------------------------------------------------------------------

local function collectSegments(objectModel: Instance): { BasePart }
	local segments = {}
	for _, child in objectModel:GetChildren() do
		if child:IsA("BasePart") and child.Name ~= "Core" then
			table.insert(segments, child)
		end
	end
	return segments
end

local function refreshSign(state: StandState)
	local label = state.RequirementLabel
	if not label then
		return
	end
	local power = ClientData.Get("Power") or 0
	if power >= state.RequiredPower then
		label.TextColor3 = Color3.fromRGB(110, 255, 120)
		label.Text = "✅ " .. NumberFormat.Abbreviate(state.RequiredPower) .. " Power"
	else
		label.TextColor3 = Color3.fromRGB(255, 90, 90)
		label.Text = "🔒 " .. NumberFormat.Abbreviate(state.RequiredPower) .. " Power"
	end
end

local function addStand(model: Instance)
	if not model:IsA("Model") then
		return
	end
	local id = model:GetAttribute("StandId")
	local objectModel = model:WaitForChild("Object", 10)
	local core = objectModel and objectModel:WaitForChild("Core", 10)
	if type(id) ~= "string" or not core or not core:IsA("BasePart") then
		return
	end

	local sign = model:FindFirstChild("Sign")
	local info = sign and sign:FindFirstChild("Info")
	local requirement = info and info:FindFirstChild("Requirement")

	local state: StandState = {
		Id = id,
		Model = model,
		Core = core,
		Segments = collectSegments(objectModel),
		BaseCFrame = core.CFrame,
		RequiredPower = model:GetAttribute("RequiredPower") or 0,
		Respawn = model:GetAttribute("Respawn") or Config.Smash.DefaultRespawn,
		Tier = model:GetAttribute("Tier") or 1,
		Radius = model:GetAttribute("Radius") or 2,
		Float = model:GetAttribute("Float") == true,
		Broken = false,
		BrokenToken = 0,
		RequirementLabel = if requirement and requirement:IsA("TextLabel") then requirement else nil,
		Phase = (#id % 7) * 0.9,
	}
	stands[id] = state
	refreshSign(state)
end

local function removeStand(model: Instance)
	local id = model:GetAttribute("StandId")
	if type(id) == "string" then
		stands[id] = nil
	end
end

--------------------------------------------------------------------------------
-- Visibility
--------------------------------------------------------------------------------

local function setTexturesTransparency(part: BasePart, hidden: boolean)
	for _, child in part:GetChildren() do
		if child:IsA("Texture") or child:IsA("Decal") then
			if hidden then
				if child:GetAttribute("BaseTransparency") == nil then
					child:SetAttribute("BaseTransparency", child.Transparency)
				end
				child.Transparency = 1
			else
				child.Transparency = child:GetAttribute("BaseTransparency") or child.Transparency
			end
		end
	end
end

local function hideSegments(state: StandState)
	for _, segment in state.Segments do
		segment.Transparency = 1
		segment.CanCollide = false
		setTexturesTransparency(segment, true)
	end
end

local function restoreSegments(state: StandState)
	local info = TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	for _, segment in state.Segments do
		segment.CanCollide = true
		setTexturesTransparency(segment, false)
		local target = segment:GetAttribute("BaseTransparency") or 0
		TweenService:Create(segment, info, { Transparency = target }):Play()
	end
end

--------------------------------------------------------------------------------
-- FX helpers
--------------------------------------------------------------------------------

local function fxPart(props: { [string]: any }): Part
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in props do
		(part :: any)[key] = value
	end
	part.Parent = debrisFolder
	return part
end

local function impactFlash(position: Vector3, size: number, color: Color3)
	local flash = fxPart({
		Shape = Enum.PartType.Ball,
		Material = Enum.Material.Neon,
		Color = color,
		Transparency = 0.15,
		Size = Vector3.one * 1,
		CFrame = CFrame.new(position),
	})
	TweenService:Create(flash, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.one * size,
		Transparency = 1,
	}):Play()
	Debris:AddItem(flash, 0.3)
end

local function shockwave(position: Vector3, diameter: number, color: Color3)
	local ring = fxPart({
		Shape = Enum.PartType.Cylinder,
		Material = Enum.Material.Neon,
		Color = color,
		Transparency = 0.25,
		Size = Vector3.new(0.3, 2, 2),
		CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90)),
	})
	TweenService:Create(ring, TweenInfo.new(0.45, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
		Size = Vector3.new(0.1, diameter, diameter),
		Transparency = 1,
	}):Play()
	Debris:AddItem(ring, 0.5)
end

local function sparkBurst(position: Vector3, color: Color3, count: number)
	local attachment = Instance.new("Attachment")
	attachment.WorldPosition = position
	attachment.Parent = workspace.Terrain

	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = Config.Assets.Particles.Sparkle
	emitter.Color = ColorSequence.new(Color3.new(1, 1, 1), color)
	emitter.LightEmission = 1
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1.2),
		NumberSequenceKeypoint.new(1, 0),
	})
	emitter.Lifetime = NumberRange.new(0.3, 0.6)
	emitter.Speed = NumberRange.new(15, 35)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Drag = 4
	emitter.Rate = 0
	emitter.Parent = attachment
	emitter:Emit(count)
	Debris:AddItem(attachment, 1)
end

-- Throw a part outward from a centre, then shrink + fade it away.
local function fling(part: BasePart, center: Vector3, power: number, lifetime: number)
	part.Anchored = false
	part.CanCollide = true
	part.CanQuery = false
	part.CanTouch = false
	part.Massless = false
	part.CollisionGroup = DEBRIS_GROUP
	part.Parent = debrisFolder

	local direction = part.Position - center
	if direction.Magnitude < 0.05 then
		direction = Vector3.new(math.random() - 0.5, 0.5, math.random() - 0.5)
	end
	direction = (direction.Unit + Vector3.new(0, 0.9, 0)).Unit
	part.AssemblyLinearVelocity = direction * power * (0.7 + math.random() * 0.6)
	part.AssemblyAngularVelocity = Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * 30

	task.delay(lifetime * 0.55, function()
		if part.Parent then
			TweenService:Create(part, TweenInfo.new(lifetime * 0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				Transparency = 1,
				Size = part.Size * 0.3,
			}):Play()
		end
	end)
	Debris:AddItem(part, lifetime + 0.1)
end

local function shatter(state: StandState)
	local center = state.Core.Position
	local tier = state.Tier
	local power = 18 + tier * 8
	local accent = Color3.new(1, 1, 1)

	-- Pre-fractured segments become debris.
	for _, segment in state.Segments do
		local debris = segment:Clone()
		for _, child in debris:GetChildren() do
			if not (child:IsA("Texture") or child:IsA("Decal")) then
				child:Destroy()
			end
		end
		debris.Transparency = segment:GetAttribute("BaseTransparency") or 0
		fling(debris, center, power, 2.2)
		accent = segment.Color
	end
	hideSegments(state)

	-- Extra little stud chunks for the "Roblox brick" feel.
	for _ = 1, 10 + tier * 3 do
		local source = state.Segments[math.random(1, math.max(1, #state.Segments))]
		local chunk = StudSurface.NewPart({
			Size = Vector3.one * (0.5 + math.random() * 0.4),
			CFrame = CFrame.new(
				center + Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * 2
			),
			Color = if source then source.Color else accent,
			Material = if source then source.Material else Enum.Material.Plastic,
			Anchored = false,
		})
		fling(chunk, center - Vector3.new(0, 1, 0), power * 1.3, 1.6)
	end

	impactFlash(center, 6 + tier * 3, Color3.new(1, 1, 1))
	shockwave(state.BaseCFrame.Position - Vector3.new(0, 1.5, 0), 18 + tier * 8, Color3.fromRGB(255, 220, 90))
	sparkBurst(center, accent, 25 + tier * 10)
end

--------------------------------------------------------------------------------
-- Events
--------------------------------------------------------------------------------

local function onObjectSmashed(player: Player, standId: string, coins: number)
	local state = stands[standId]
	if not state then
		return
	end

	if player ~= localPlayer then
		-- Someone else broke their own copy: just a small burst so the dojo feels alive.
		if not state.Broken then
			sparkBurst(state.Core.Position, Color3.fromRGB(255, 230, 120), 12)
			Sfx.PlayAt("Smash", state.Core.Position, { Volume = 0.25, Pitch = 1.2 })
		end
		return
	end

	state.Broken = true
	state.BrokenToken += 1
	local token = state.BrokenToken

	shatter(state)
	CameraShake.Shake(0.28 + state.Tier * 0.12)
	Sfx.PlayAt("Smash", state.Core.Position, { Volume = 0.9, Pitch = 1.15 - state.Tier * 0.08 })
	Popups.WorldText(
		state.Core.Position + Vector3.new(0, 2, 0),
		"+" .. NumberFormat.Abbreviate(coins) .. " 🪙",
		Color3.fromRGB(255, 215, 60),
		1.2
	)

	task.delay(state.Respawn, function()
		if state.BrokenToken ~= token or stands[standId] ~= state then
			return
		end
		state.Broken = false
		restoreSegments(state)
		sparkBurst(state.Core.Position, Color3.new(1, 1, 1), 10)
	end)
end

local function animateFloaters()
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	local cameraPosition = camera.CFrame.Position
	local t = os.clock()
	for _, state in stands do
		if state.Float and (state.BaseCFrame.Position - cameraPosition).Magnitude < FLOAT_RANGE then
			local bob = math.sin(t * 1.6 + state.Phase) * 0.6
			state.Core.CFrame = state.BaseCFrame * CFrame.new(0, bob, 0) * CFrame.Angles(0, (t + state.Phase) * 0.35, 0)
		end
	end
end

--------------------------------------------------------------------------------
-- Public
--------------------------------------------------------------------------------

-- Nearest intact stand within chopping range of a position (horizontal distance to its edge).
function SmashController.GetStandInRange(position: Vector3): StandState?
	local best, bestDistance = nil, math.huge
	for _, state in stands do
		if not state.Broken then
			local offset = state.BaseCFrame.Position - position
			local distance = Vector3.new(offset.X, 0, offset.Z).Magnitude - state.Radius
			if distance <= Config.Smash.Range and math.abs(offset.Y) < 20 and distance < bestDistance then
				best, bestDistance = state, distance
			end
		end
	end
	return best
end

-- "You're not strong enough yet" feedback (wobble + popup + clank).
function SmashController.Deny(state: StandState)
	local now = os.clock()
	if now - lastDeny < DENY_COOLDOWN then
		return
	end
	lastDeny = now

	Sfx.PlayAt("Denied", state.Core.Position, { Volume = 0.5, Pitch = 1.4 })
	Popups.WorldText(
		state.Core.Position + Vector3.new(0, 1, 0),
		"Need " .. NumberFormat.Abbreviate(state.RequiredPower) .. " ⚡",
		Color3.fromRGB(255, 80, 80),
		0.9
	)
	sparkBurst(state.Core.Position, Color3.fromRGB(255, 120, 80), 6)

	if not state.Float then
		local base = state.BaseCFrame
		local info = TweenInfo.new(0.05, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, 3, true)
		local tween = TweenService:Create(state.Core, info, { CFrame = base * CFrame.Angles(0, 0, math.rad(4)) })
		tween:Play()
		tween.Completed:Once(function()
			state.Core.CFrame = base
		end)
	end
end

function SmashController.Start()
	debrisFolder = Instance.new("Folder")
	debrisFolder.Name = "LocalDebris"
	debrisFolder.Parent = workspace

	CollectionService:GetInstanceAddedSignal(TAG):Connect(function(model)
		task.spawn(addStand, model)
	end)
	CollectionService:GetInstanceRemovedSignal(TAG):Connect(removeStand)
	for _, model in CollectionService:GetTagged(TAG) do
		task.spawn(addStand, model)
	end

	Remotes.ObjectSmashed.OnClientEvent:Connect(onObjectSmashed)

	-- Sign colours follow Power, refreshed at most 4x per second.
	local signsDirty = false
	ClientData.Changed:Connect(function(key)
		if key == "Power" then
			signsDirty = true
		end
	end)
	task.spawn(function()
		while true do
			task.wait(0.25)
			if signsDirty then
				signsDirty = false
				for _, state in stands do
					refreshSign(state)
				end
			end
		end
	end)

	RunService.RenderStepped:Connect(animateFloaters)
end

return SmashController
