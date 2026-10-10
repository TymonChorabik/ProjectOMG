--[[
	TrainingController.luau
	Dojo training, the only way to gain Strength. "Hold E" on a training pad: the character
	steps onto it, faces the stand and karate-chops the dojo's item (boards, bamboo, ice...)
	over and over until you move or jump. Each chop is in step with the server's Strength gain:
	the item shatters into the pit, "+X ⚡" pops up, and a fresh item appears.
	Everyone who is training is animated on every client, and their items break too.
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

local ClientData = require(script.Parent.Parent.ClientData)
local Sfx = require(script.Parent.Parent.Effects.Sfx)
local TrainingAnimator = require(script.Parent.Parent.Effects.TrainingAnimator)
local Popups = require(script.Parent.Parent.UI.Popups)

local TrainingController = {}

local RESPAWN_DELAY = 0.28 -- a new item appears this long after the old one shatters
local SHARD_LIFETIME = 1.3
local MAX_SHARDS = 90 -- across all stations, so busy servers stay smooth

type TargetPart = { Part: BasePart, Transparency: number, CFrame: CFrame }
type Station = {
	Id: string,
	Zone: any,
	Model: Model,
	Stand: BasePart,
	Pad: BasePart,
	Prompt: ProximityPrompt,
	Target: { TargetPart },
	Direction: Vector3, -- pad → item, flattened (pieces fly this way, into the pit)
	Broken: boolean,
}

local localPlayer = Players.LocalPlayer
local rng = Random.new()
local stations: { [string]: Station } = {}
local animations: { [Player]: { Handle: TrainingAnimator.Handle, Character: Model, StationId: string } } = {}
local debrisFolder: Instance? = nil
local liveShards = 0

local currentStation: Station? = nil
local moveConnection: RBXScriptConnection? = nil
local requesting = false
local hinted = false

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
		math.max(0.2, size.X * rng:NextNumber(0.25, 0.55)),
		math.max(0.2, size.Y * rng:NextNumber(0.5, 0.9)),
		math.max(0.2, size.Z * rng:NextNumber(0.2, 0.45))
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
	shard.AssemblyLinearVelocity = direction * rng:NextNumber(9, 17)
		+ sideways * rng:NextNumber(-5, 5)
		+ Vector3.new(0, rng:NextNumber(9, 16), 0)
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

-- Shatters the station's item into the pit and pops a fresh one back after a moment.
local function breakTarget(station: Station, piecesPerPart: number)
	if station.Broken then
		return
	end
	station.Broken = true
	for _, entry in station.Target do
		for _ = 1, piecesPerPart do
			spawnShard(entry.Part, entry.Transparency, station.Direction)
		end
		entry.Part.Transparency = 1
	end

	task.delay(RESPAWN_DELAY, function()
		for _, entry in station.Target do
			-- Drop the new item in from just above the stand.
			entry.Part.Transparency = entry.Transparency
			entry.Part.CFrame = entry.CFrame + Vector3.new(0, 0.7, 0)
			TweenService:Create(
				entry.Part,
				TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
				{ CFrame = entry.CFrame }
			):Play()
		end
		station.Broken = false
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

--------------------------------------------------------------------------------
-- Animating everyone who trains
--------------------------------------------------------------------------------

local function refreshAnimation(player: Player)
	local stationId = player:GetAttribute("Training")
	local station = if type(stationId) == "string" then stations[stationId] else nil
	local character = player.Character
	local current = animations[player]

	if current and (not station or current.Character ~= character or current.StationId ~= stationId) then
		current.Handle.Stop()
		animations[player] = nil
		current = nil
	end
	if current or not station or not character then
		return
	end

	local isLocal = player == localPlayer
	local handle = TrainingAnimator.Start(character, {
		-- The local player's chops follow the server's gains (ChopResult); others loop.
		Period = if isLocal then nil else Config.Training.IdleInterval,
		OnHit = function()
			breakTarget(station, if isLocal then 3 else 2)
			if isLocal then
				Sfx.Play("Smash", { Volume = 0.25, PitchVariance = 0.15 })
			end
		end,
	})
	animations[player] = { Handle = handle, Character = character, StationId = station.Id }
end

local function watchPlayer(player: Player)
	player:GetAttributeChangedSignal("Training"):Connect(function()
		refreshAnimation(player)
	end)
	player.CharacterAdded:Connect(function()
		refreshAnimation(player)
	end)
	refreshAnimation(player)
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
-- Local player
--------------------------------------------------------------------------------

local function refreshPrompts()
	local data = ClientData.Data
	for _, station in stations do
		local occupant = station.Model:GetAttribute("Occupant")
		local takenByOther = occupant ~= nil and occupant ~= localPlayer.UserId
		station.Prompt.Enabled = not takenByOther and currentStation ~= station
		local unlocked = data == nil or Formulas.IsZoneUnlocked(data, station.Zone.Id)
		local name = station.Zone.Breakable.Name
		station.Prompt.ObjectText = if unlocked then name else "🔒 " .. name
	end
end

local function stopTraining(tellServer: boolean)
	local station = currentStation
	if not station then
		return
	end
	currentStation = nil
	if moveConnection then
		moveConnection:Disconnect()
		moveConnection = nil
	end
	local character = localPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.AutoRotate = true
	end
	refreshPrompts()
	if tellServer then
		task.spawn(function()
			pcall(function()
				Remotes.Action:InvokeServer("StopTraining")
			end)
		end)
	end
end

-- Puts the character on the pad, facing the item, and watches for movement to stop.
local function beginTraining(station: Station)
	local character = localPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not character or not humanoid or not root or not root:IsA("BasePart") then
		return
	end

	local stand = station.Stand
	local floorY = stand.Position.Y - stand.Size.Y / 2
	local height = if humanoid.RigType == Enum.HumanoidRigType.R6 then 3 else humanoid.HipHeight + root.Size.Y / 2
	local target = CFrame.new(stand.Position.X, floorY + height, stand.Position.Z) * stand.CFrame.Rotation
	character:PivotTo(target)
	root.AssemblyLinearVelocity = Vector3.zero
	humanoid.AutoRotate = false

	currentStation = station
	refreshPrompts()
	if not hinted then
		hinted = true
		Popups.Toast(`🥋 Breaking {station.Zone.Breakable.Name}! Move or jump to stop.`, "Info")
	end

	moveConnection = RunService.Heartbeat:Connect(function()
		if humanoid.Health <= 0 or humanoid.MoveDirection.Magnitude > 0.1 or humanoid.Jump then
			stopTraining(true)
		end
	end)
end

local function requestTraining(station: Station)
	if requesting or currentStation == station then
		return
	end
	requesting = true
	local ok, result = pcall(function()
		return Remotes.Action:InvokeServer("StartTraining", station.Id)
	end)
	requesting = false

	if not ok or type(result) ~= "table" then
		Popups.Toast("Connection hiccup — try again!", "Error")
		return
	end
	if not result.ok then
		Sfx.Play("Denied", { Volume = 0.4 })
		Popups.Toast(result.message or "You can't train here.", "Error")
		return
	end
	stopTraining(false)
	beginTraining(station)
end

--------------------------------------------------------------------------------
-- Setup
--------------------------------------------------------------------------------

local function setupStation(model: Instance, zone)
	local stationId = model:GetAttribute("StationId")
	local stand = model:FindFirstChild("Stand")
	local pad = model:FindFirstChild("Pad")
	local targetModel = model:FindFirstChild("Target")
	if
		not model:IsA("Model")
		or type(stationId) ~= "string"
		or not (stand and stand:IsA("BasePart"))
		or not (pad and pad:IsA("BasePart"))
		or not targetModel
	then
		return
	end

	local target: { TargetPart } = {}
	local center = Vector3.zero
	for _, child in targetModel:GetChildren() do
		if child:IsA("BasePart") then
			table.insert(target, { Part = child, Transparency = child.Transparency, CFrame = child.CFrame })
			center += child.Position
		end
	end
	if #target == 0 then
		return
	end
	center /= #target

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "TrainPrompt"
	prompt.ActionText = "Train"
	prompt.ObjectText = zone.Breakable.Name
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0.5
	prompt.MaxActivationDistance = 9
	prompt.RequiresLineOfSight = false
	prompt.Parent = pad

	local toTarget = Vector3.new(center.X - pad.Position.X, 0, center.Z - pad.Position.Z)
	local station: Station = {
		Id = stationId,
		Zone = zone,
		Model = model,
		Stand = stand,
		Pad = pad,
		Prompt = prompt,
		Target = target,
		Direction = if toTarget.Magnitude > 0.01 then toTarget.Unit else Vector3.xAxis,
		Broken = false,
	}
	stations[stationId] = station

	prompt.Triggered:Connect(function()
		task.spawn(requestTraining, station)
	end)
	model:GetAttributeChangedSignal("Occupant"):Connect(refreshPrompts)
end

function TrainingController.IsTraining(): boolean
	return currentStation ~= nil
end

function TrainingController.Start()
	Remotes.ChopResult.OnClientEvent:Connect(onChopResult)

	task.spawn(function()
		local map = workspace:WaitForChild("Map")
		local zones = map:WaitForChild("TrainingZones")
		for _, zoneModel in zones:GetChildren() do
			local zone = Formulas.GetZone(zoneModel:GetAttribute("ZoneId"))
			local folder = zoneModel:FindFirstChild("Stations")
			if zone and folder then
				for _, model in folder:GetChildren() do
					setupStation(model, zone)
				end
			end
		end
		refreshPrompts()

		Players.PlayerAdded:Connect(watchPlayer)
		for _, player in Players:GetPlayers() do
			watchPlayer(player)
		end
		Players.PlayerRemoving:Connect(function(player)
			local current = animations[player]
			if current then
				current.Handle.Stop()
				animations[player] = nil
			end
		end)
	end)

	-- The server ended our session (walked away, died, started a run...).
	localPlayer:GetAttributeChangedSignal("Training"):Connect(function()
		if localPlayer:GetAttribute("Training") == nil then
			stopTraining(false)
		end
	end)
	localPlayer.CharacterRemoving:Connect(function()
		stopTraining(false)
	end)

	ClientData.Changed:Connect(function(key)
		if key == "Rebirths" or key == "Passes" then
			refreshPrompts()
		end
	end)
end

return TrainingController
