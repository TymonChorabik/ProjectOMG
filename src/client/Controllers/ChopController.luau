--[[
	ChopController.luau
	Training input. Click / tap the world, press F or R2, or hit the CHOP! button. Each chop plays
	the karate-chop animation, slash trail and sound immediately and asks the server to credit it.
	Idle training at a dummy (TrainingController) arrives here as idle ChopResults.
	The Auto Chop game pass chops for you while it's toggled on.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Formulas = require(Shared.Formulas)
local NumberFormat = require(Shared.NumberFormat)
local Remotes = require(Shared.Remotes)
local Signal = require(Shared.Signal)

local ClientData = require(script.Parent.Parent.ClientData)
local ChopAnimator = require(script.Parent.Parent.Effects.ChopAnimator)
local Sfx = require(script.Parent.Parent.Effects.Sfx)
local Popups = require(script.Parent.Parent.UI.Popups)

local ChopController = {}

ChopController.AutoChopChanged = Signal.new() -- (enabled)

local localPlayer = Players.LocalPlayer
local lastChop = 0
local autoChop = false
local autoToken = 0

local function canChop(): boolean
	if localPlayer:GetAttribute("Running") then
		return false
	end
	local character = localPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	return humanoid ~= nil and humanoid.Health > 0
end

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

function ChopController.Chop()
	local now = os.clock()
	if now - lastChop < Config.Training.ClientMinInterval or not canChop() then
		return
	end
	lastChop = now
	Remotes.Chop:FireServer()
	Sfx.Play("Chop", { Volume = 0.35, PitchVariance = 0.12 })
	if not localPlayer:GetAttribute("Training") then
		-- At a dummy the training loop is already animating the arms.
		ChopAnimator.Play(false)
	end
end

function ChopController.IsAutoChop(): boolean
	return autoChop
end

function ChopController.SetAutoChop(enabled: boolean)
	if autoChop == enabled then
		return
	end
	autoChop = enabled
	autoToken += 1
	ChopController.AutoChopChanged:Fire(enabled)
	if enabled then
		local token = autoToken
		task.spawn(function()
			while autoChop and autoToken == token do
				local data = ClientData.Data
				if data and Formulas.HasPass(data, "AutoChop") then
					ChopController.Chop()
				end
				task.wait(Config.Training.AutoChopInterval)
			end
		end)
	end
end

local function onChopResult(gain: number, idle: boolean)
	Popups.ScreenText(
		popupPosition(),
		"⚡ +" .. NumberFormat.Abbreviate(gain),
		Color3.fromRGB(255, 220, 70),
		if idle then 22 else 26
	)
end

local function bindCharacter(character: Model)
	local humanoid = character:WaitForChild("Humanoid", 10)
	if not humanoid or not humanoid:IsA("Humanoid") then
		return
	end
	character:WaitForChild(if humanoid.RigType == Enum.HumanoidRigType.R6 then "Right Arm" else "RightHand", 5)
	if localPlayer.Character ~= character then
		return
	end
	ChopAnimator.Bind(character)
	local item = Formulas.GetItem(ClientData.Get("EquippedItem"))
	ChopAnimator.SetTrailColor(if item then item.Color else Color3.fromRGB(255, 230, 150))
end

-- The world input decides whether a click is a chop (LaneController may claim it first).
ChopController.ShouldChopOnClick = function(): boolean
	return true
end

function ChopController.Start()
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then
			return
		end
		local inputType, keyCode = input.UserInputType, input.KeyCode
		local isClick = inputType == Enum.UserInputType.MouseButton1 or inputType == Enum.UserInputType.Touch
		local isKey = keyCode == Enum.KeyCode.F or keyCode == Enum.KeyCode.ButtonR2
		if (isClick or isKey) and ChopController.ShouldChopOnClick() then
			ChopController.Chop()
		end
	end)

	Remotes.ChopResult.OnClientEvent:Connect(onChopResult)

	localPlayer.CharacterAdded:Connect(bindCharacter)
	if localPlayer.Character then
		task.spawn(bindCharacter, localPlayer.Character)
	end
	localPlayer.CharacterRemoving:Connect(function()
		ChopAnimator.Unbind()
	end)

	ClientData.Changed:Connect(function(key, value)
		if key == "EquippedItem" then
			local item = Formulas.GetItem(value)
			ChopAnimator.SetTrailColor(if item then item.Color else Color3.fromRGB(255, 230, 150))
		end
	end)
end

return ChopController
