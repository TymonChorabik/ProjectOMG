--[[
	TrainingController.luau
	"Hold E" at a wooden dummy to train there. The character steps onto the dummy's stand,
	faces it and punches on a loop (idle training) until you move or jump. Everyone who is
	training is animated on every client, and the dummies wobble when they get hit.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Formulas = require(Shared.Formulas)
local Remotes = require(Shared.Remotes)

local ClientData = require(script.Parent.Parent.ClientData)
local Sfx = require(script.Parent.Parent.Effects.Sfx)
local TrainingAnimator = require(script.Parent.Parent.Effects.TrainingAnimator)
local Popups = require(script.Parent.Parent.UI.Popups)

local TrainingController = {}

local WOBBLE_ANGLE = math.rad(7)
local WOBBLE_TIME = 0.7

type WobblePart = { Part: BasePart, Offset: CFrame }
type Station = {
	Id: string,
	Zone: any,
	Model: Model,
	Stand: BasePart,
	Prompt: ProximityPrompt,
	Pivot: Vector3,
	Axis: Vector3,
	Parts: { WobblePart },
	HitAt: number,
}

local localPlayer = Players.LocalPlayer
local stations: { [string]: Station } = {}
local animations: { [Player]: { Handle: TrainingAnimator.Handle, Character: Model, StationId: string } } = {}
local wobbling: { [Station]: boolean } = {}
local wobbleConnection: RBXScriptConnection? = nil

local currentStation: Station? = nil
local moveConnection: RBXScriptConnection? = nil
local requesting = false
local hinted = false

--------------------------------------------------------------------------------
-- Dummy wobble
--------------------------------------------------------------------------------

local function updateWobble()
	local now = os.clock()
	for station in wobbling do
		local t = now - station.HitAt
		local angle = 0
		if t < WOBBLE_TIME then
			angle = WOBBLE_ANGLE * math.exp(-6 * t) * math.sin(t * 22)
		else
			wobbling[station] = nil
		end
		local pivot = CFrame.new(station.Pivot) * CFrame.fromAxisAngle(station.Axis, angle)
		for _, entry in station.Parts do
			entry.Part.CFrame = pivot * entry.Offset
		end
	end
	if next(wobbling) == nil and wobbleConnection then
		wobbleConnection:Disconnect()
		wobbleConnection = nil
	end
end

local function hitDummy(station: Station)
	station.HitAt = os.clock()
	wobbling[station] = true
	if not wobbleConnection then
		wobbleConnection = RunService.RenderStepped:Connect(updateWobble)
	end
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
	local handle = TrainingAnimator.Start(character, function()
		hitDummy(station)
		if isLocal then
			Sfx.Play("Smash", { Volume = 0.12, PitchVariance = 0.15 })
		end
	end)
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
		station.Prompt.ObjectText = if unlocked then station.Zone.Name else "🔒 " .. station.Zone.Name
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

-- Puts the character on the stand, facing the dummy, and watches for movement to stop.
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
		Popups.Toast("🥋 Training! Move or jump to stop.", "Info")
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
	local post = model:FindFirstChild("DummyPost")
	local base = model:FindFirstChild("DummyBase")
	if
		not model:IsA("Model")
		or type(stationId) ~= "string"
		or not (stand and stand:IsA("BasePart"))
		or not (post and post:IsA("BasePart"))
		or not (base and base:IsA("BasePart"))
	then
		return
	end

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "TrainPrompt"
	prompt.ActionText = "Train"
	prompt.ObjectText = zone.Name
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0.5
	prompt.MaxActivationDistance = 9
	prompt.RequiresLineOfSight = false
	prompt.Parent = post

	-- The dummy rocks around the top of its base, away from whoever hits it.
	local pivot = base.Position + Vector3.new(0, base.Size.Y / 2, 0)
	local away = Vector3.new(post.Position.X - stand.Position.X, 0, post.Position.Z - stand.Position.Z)
	local direction = if away.Magnitude > 0.01 then away.Unit else Vector3.xAxis
	local parts: { WobblePart } = {}
	for _, child in model:GetChildren() do
		if child:IsA("BasePart") and child ~= base and child ~= stand then
			table.insert(parts, { Part = child, Offset = CFrame.new(-pivot) * child.CFrame })
		end
	end

	local station: Station = {
		Id = stationId,
		Zone = zone,
		Model = model,
		Stand = stand,
		Prompt = prompt,
		Pivot = pivot,
		Axis = Vector3.yAxis:Cross(direction),
		Parts = parts,
		HitAt = 0,
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
