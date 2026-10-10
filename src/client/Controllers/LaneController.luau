--[[
	LaneController.luau
	The Board Wall run, client side.
	• Detects when you stand on the launch pad (the "Smash!" prompt: E / tap).
	• Asks the server for the run result, then plays it: your character flies down the lane in a
	  flying-kick pose, every wall it can break shatters into stud chunks (locally), the camera
	  follows, a distance counter ticks up and biome banners pop as you enter each biome.
	• You stop at the first wall you're too weak for (clang!), get your Wins, and return to the pad.
	• Auto Smash (game pass): while switched on, runs start by themselves from wherever you are,
	  one after another, so you farm Wins hands-free. It switches itself off if you can't break
	  the first wall yet.
]]

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Formulas = require(Shared.Formulas)
local NumberFormat = require(Shared.NumberFormat)
local Remotes = require(Shared.Remotes)
local Signal = require(Shared.Signal)
local StudSurface = require(Shared.StudSurface)

local ClientData = require(script.Parent.Parent.ClientData)
local CameraShake = require(script.Parent.Parent.Effects.CameraShake)
local ChopAnimator = require(script.Parent.Parent.Effects.ChopAnimator)
local Sfx = require(script.Parent.Parent.Effects.Sfx)
local Popups = require(script.Parent.Parent.UI.Popups)

local LaneController = {}

LaneController.PadChanged = Signal.new() -- (onPad: boolean)
LaneController.RunProgress = Signal.new() -- (meters: number?)  nil = run finished
LaneController.AutoSmashChanged = Signal.new() -- (enabled: boolean)

local localPlayer = Players.LocalPlayer

local pad: BasePart? = nil
local walls: { [number]: Model } = {}
local debrisFolder: Folder
local onPad = false
local running = false
local autoSmash = false
local lastRunEnded = 0

type Hidden = { Part: Instance, Transparency: number?, CanCollide: boolean?, Enabled: boolean? }
local hidden: { Hidden } = {}

--------------------------------------------------------------------------------
-- Walls
--------------------------------------------------------------------------------

local function hideInstance(instance: Instance)
	if instance:IsA("BasePart") then
		table.insert(
			hidden,
			{ Part = instance, Transparency = instance.Transparency, CanCollide = instance.CanCollide }
		)
		instance.Transparency = 1
		instance.CanCollide = false
	elseif instance:IsA("Decal") then -- also covers Texture
		table.insert(hidden, { Part = instance, Transparency = instance.Transparency })
		instance.Transparency = 1
	elseif instance:IsA("SurfaceGui") then
		table.insert(hidden, { Part = instance, Enabled = instance.Enabled })
		instance.Enabled = false
	end
end

local function restoreWalls()
	for _, entry in hidden do
		local instance = entry.Part
		if instance.Parent then
			if instance:IsA("BasePart") then
				instance.Transparency = entry.Transparency :: number
				instance.CanCollide = entry.CanCollide :: boolean
			elseif instance:IsA("Decal") then
				instance.Transparency = entry.Transparency :: number
			elseif instance:IsA("SurfaceGui") then
				instance.Enabled = entry.Enabled :: boolean
			end
		end
	end
	table.clear(hidden)
end

local function fling(part: BasePart, velocity: Vector3)
	part.Anchored = false
	part.CanCollide = true
	part.CanQuery = false
	part.CanTouch = false
	part.CollisionGroup = "Debris"
	part.Parent = debrisFolder
	part.AssemblyLinearVelocity = velocity
	part.AssemblyAngularVelocity = Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * 25
	task.delay(1, function()
		if part.Parent then
			TweenService:Create(part, TweenInfo.new(0.6), { Transparency = 1, Size = part.Size * 0.4 }):Play()
		end
	end)
	Debris:AddItem(part, 1.8)
end

local function shatter(index: number, chunksPerBoard: number)
	local wall = walls[index]
	if not wall then
		return
	end
	for _, piece in wall:GetChildren() do
		if piece:IsA("BasePart") then
			local size = piece.Size
			for chunk = 1, chunksPerBoard do
				local width = size.X / chunksPerBoard
				local x = -size.X / 2 + width * (chunk - 0.5)
				local part = StudSurface.NewPart({
					Size = Vector3.new(width * 0.95, size.Y, size.Z),
					CFrame = piece.CFrame * CFrame.new(x, 0, 0),
					Color = piece.Color,
					Material = piece.Material,
					Anchored = false,
					CastShadow = false,
				})
				local side = math.sign(x) + (math.random() - 0.5) * 0.6
				fling(part, Vector3.new(side * math.random(10, 26), math.random(14, 32), math.random(35, 70)))
			end
			hideInstance(piece)
			for _, descendant in piece:GetDescendants() do
				hideInstance(descendant)
			end
		end
	end
end

--------------------------------------------------------------------------------
-- The run
--------------------------------------------------------------------------------

local function getCharacter(): (Model?, Humanoid?, BasePart?)
	local character = localPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if character and humanoid and humanoid.Health > 0 and root and root:IsA("BasePart") then
		return character, humanoid, root
	end
	return nil, nil, nil
end

local function playRun(result)
	local _, humanoid, root = getCharacter()
	local padPart = pad
	if not humanoid or not root or not padPart then
		return
	end

	local camera = workspace.CurrentCamera
	local padPosition = padPart.Position
	local startZ = padPosition.Z
	local stopZ = startZ + result.Distance
	local baseY = padPosition.Y + 5
	local wallCount = Formulas.GetWallCount()
	local brokenTarget = result.Walls
	local chunks = if brokenTarget > 100 then 1 elseif brokenTarget > 40 then 2 else 4

	humanoid.PlatformStand = true
	camera.CameraType = Enum.CameraType.Scriptable

	local nextWall = 1
	local biome = 0
	local lastSound, lastChop = 0, 0
	local elapsed = 0
	local duration = result.Duration

	while elapsed < duration do
		local dt = RunService.RenderStepped:Wait()
		elapsed += dt
		if humanoid.Health <= 0 or not root.Parent then
			break
		end
		local alpha = math.clamp(elapsed / duration, 0, 1)
		local eased = 1 - (1 - alpha) ^ 1.8
		local z = startZ + (stopZ - startZ) * eased
		local position = Vector3.new(padPosition.X, baseY + math.sin(elapsed * 9) * 0.4, z)
		root.CFrame = CFrame.lookAt(position, position + Vector3.zAxis) * CFrame.Angles(math.rad(-70), 0, 0)
		root.AssemblyLinearVelocity = Vector3.zero

		while nextWall <= brokenTarget and z >= Formulas.GetWallZ(nextWall) - 3 do
			shatter(nextWall, chunks)
			local now = os.clock()
			if now - lastSound > 0.07 then
				lastSound = now
				Sfx.Play("Smash", { Volume = 0.5, Pitch = 1.1 + math.random() * 0.3 })
				CameraShake.Shake(0.08)
			end
			if now - lastChop > 0.15 then
				lastChop = now
				ChopAnimator.Play(true)
			end
			local wallBiome = Formulas.GetWallBiomeIndex(nextWall)
			if wallBiome ~= biome then
				biome = wallBiome
				local def = Formulas.GetBiome(wallBiome)
				Popups.Banner(string.upper(def.Name), `🏆 {def.WinsPerWall} per wall`, def.Title)
			end
			nextWall += 1
		end

		LaneController.RunProgress:Fire(math.floor(z - startZ))
		local cameraPosition = position + Vector3.new(0, 9, -22)
		camera.CFrame = CFrame.lookAt(cameraPosition, position + Vector3.new(0, 1, 14))
	end

	-- Bonk on the first wall you couldn't break.
	if brokenTarget < wallCount and humanoid.Health > 0 then
		Sfx.Play("Denied", { Volume = 0.7, Pitch = 0.8 })
		CameraShake.Shake(0.35)
		local nextToughness = Formulas.GetWallToughness(brokenTarget + 1)
		Popups.WorldText(
			root.Position + Vector3.new(0, 3, 6),
			`Need ⚡{NumberFormat.Abbreviate(nextToughness)}`,
			Color3.fromRGB(255, 90, 90),
			1.4
		)
	end

	if result.Wins > 0 then
		Popups.Banner(
			`+{NumberFormat.Abbreviate(result.Wins)} 🏆 WINS`,
			`{NumberFormat.Commas(result.Distance)} m  •  {brokenTarget} walls`,
			Color3.fromRGB(255, 215, 60)
		)
		Sfx.Play("Purchase", { Volume = 0.6, Pitch = 1.2 })
	end
	task.wait(1.6)

	-- Back to the pad.
	if root.Parent then
		local back = padPosition + Vector3.new(0, 4, 0)
		root.CFrame = CFrame.lookAt(back, back + Vector3.zAxis)
		root.AssemblyLinearVelocity = Vector3.zero
	end
	humanoid.PlatformStand = false
	camera.CameraType = Enum.CameraType.Custom
	camera.CameraSubject = humanoid
	LaneController.RunProgress:Fire(nil)
	restoreWalls()
end

function LaneController.IsOnPad(): boolean
	return onPad
end

function LaneController.IsRunning(): boolean
	return running
end

-- auto: started by Auto Smash (may start away from the launch pad; failures retry quietly).
function LaneController.TryRun(auto: boolean?)
	if running then
		return
	end
	running = true
	task.spawn(function()
		local ok, result = pcall(function()
			return Remotes.StartRun:InvokeServer(auto == true)
		end)
		if not ok or type(result) ~= "table" then
			if not auto then
				Popups.Toast("Connection hiccup — try again!", "Error")
			end
		elseif not result.ok then
			if not auto then
				Popups.Toast(result.message or "You can't smash right now.", "Error")
			end
		else
			if auto and result.Walls == 0 then
				-- Nothing to farm yet: stop instead of bonking the first wall forever.
				LaneController.SetAutoSmash(false)
			end
			if result.message then
				Popups.Toast(result.message, "Info")
			end
			local played, err = pcall(playRun, result)
			if not played then
				warn("[LaneController] " .. tostring(err))
				restoreWalls()
				local camera = workspace.CurrentCamera
				camera.CameraType = Enum.CameraType.Custom
				LaneController.RunProgress:Fire(nil)
			end
		end
		lastRunEnded = os.clock()
		running = false
	end)
end

function LaneController.IsAutoSmash(): boolean
	return autoSmash
end

function LaneController.SetAutoSmash(enabled: boolean)
	if autoSmash == enabled then
		return
	end
	autoSmash = enabled
	LaneController.AutoSmashChanged:Fire(enabled)
	if enabled then
		Popups.Toast("🤖 Auto Smash ON: farming Wins!", "Success")
	end
end

local function autoSmashReady(): boolean
	local data = ClientData.Data
	local _, humanoid = getCharacter()
	return autoSmash
		and not running
		and humanoid ~= nil
		and humanoid.Health > 0
		and os.clock() - lastRunEnded >= Config.AutoSmash.Delay
		and data ~= nil
		and Formulas.HasPass(data, "AutoSmash")
end

--------------------------------------------------------------------------------
-- Setup
--------------------------------------------------------------------------------

function LaneController.Start()
	debrisFolder = Instance.new("Folder")
	debrisFolder.Name = "LocalDebris"
	debrisFolder.Parent = workspace

	task.spawn(function()
		local map = workspace:WaitForChild("Map")
		local lane = map:WaitForChild("Lane")
		local padInstance = lane:WaitForChild("LaunchPad")
		if padInstance:IsA("BasePart") then
			pad = padInstance
			local prompt = Instance.new("ProximityPrompt")
			prompt.ActionText = "Smash!"
			prompt.ObjectText = "Board Wall"
			prompt.HoldDuration = 0
			prompt.MaxActivationDistance = Config.Lane.PadRadius + 4
			prompt.RequiresLineOfSight = false
			prompt.Triggered:Connect(function()
				LaneController.TryRun()
			end)
			prompt.Parent = padInstance
		end
		local wallsFolder = lane:WaitForChild("Walls")
		local function register(child: Instance)
			local index = child:GetAttribute("Index")
			if child:IsA("Model") and type(index) == "number" then
				walls[index] = child
			end
		end
		for _, child in wallsFolder:GetChildren() do
			register(child)
		end
		wallsFolder.ChildAdded:Connect(register)
	end)

	-- Pad detection.
	task.spawn(function()
		while true do
			task.wait(0.2)
			local _, _, root = getCharacter()
			local now = false
			if root and pad and not running then
				local offset = root.Position - pad.Position
				now = Vector3.new(offset.X, 0, offset.Z).Magnitude <= Config.Lane.PadRadius and math.abs(offset.Y) < 10
			end
			if now ~= onPad then
				onPad = now
				LaneController.PadChanged:Fire(onPad)
			end
			if autoSmashReady() then
				LaneController.TryRun(true)
			end
		end
	end)
end

return LaneController
