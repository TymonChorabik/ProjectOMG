--[[
	ChopController.luau
	Player input → karate chop. Click / tap the world, press F or R2, or hit the CHOP button.
	Each chop plays the animation, slash trail and sound immediately (no waiting on the
	network), aims at the stand in front of you if you're strong enough, and asks the server
	to credit the +1. Auto-Chop repeats this on a timer improved by the Swift Strikes upgrade.
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
local CameraShake = require(script.Parent.Parent.Effects.CameraShake)
local ChopAnimator = require(script.Parent.Parent.Effects.ChopAnimator)
local Sfx = require(script.Parent.Parent.Effects.Sfx)
local Popups = require(script.Parent.Parent.UI.Popups)
local SmashController = require(script.Parent.SmashController)

local ChopController = {}

ChopController.AutoChopChanged = Signal.new() -- (enabled)

local localPlayer = Players.LocalPlayer
local lastChop = 0
local autoChop = false
local autoToken = 0

local function getAliveRoot(): BasePart?
	local character = localPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if humanoid and humanoid.Health > 0 and root and root:IsA("BasePart") then
		return root
	end
	return nil
end

local function popupPosition(): Vector2
	local camera = workspace.CurrentCamera
	local character = localPlayer.Character
	local hand = character and (character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm"))
	if camera and hand and hand:IsA("BasePart") then
		local point, visible = camera:WorldToViewportPoint(hand.Position)
		if visible then
			return Vector2.new(point.X, point.Y - 40)
		end
	end
	local size = if camera then camera.ViewportSize else Vector2.new(1280, 720)
	return Vector2.new(size.X / 2, size.Y * 0.45)
end

function ChopController.Chop()
	local now = os.clock()
	if now - lastChop < Config.Training.ClientMinInterval then
		return
	end
	local root = getAliveRoot()
	if not root then
		return
	end
	lastChop = now

	local standId = nil
	local stand = SmashController.GetStandInRange(root.Position)
	if stand then
		if (ClientData.Get("Power") or 0) >= stand.RequiredPower then
			standId = stand.Id
		else
			SmashController.Deny(stand)
		end
	end

	Remotes.Chop:FireServer(standId)
	Sfx.Play("Chop", { Volume = 0.4, PitchVariance = 0.12 })
	ChopAnimator.Play(false)
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
				ChopController.Chop()
				task.wait(Formulas.GetAutoChopInterval(ClientData.Data or {}))
			end
		end)
	end
end

local function onChopResult(gain: number, isCrit: boolean)
	if isCrit then
		Popups.ScreenText(
			popupPosition(),
			"CRIT! +" .. NumberFormat.Abbreviate(gain) .. " ⚡",
			Color3.fromRGB(255, 120, 40),
			46
		)
		Sfx.Play("Crit", { Volume = 0.5 })
		CameraShake.Shake(0.12)
	else
		Popups.ScreenText(
			popupPosition(),
			"+" .. NumberFormat.Abbreviate(gain) .. " ⚡",
			Color3.fromRGB(255, 225, 70),
			32
		)
	end
end

local function bindCharacter(character: Model)
	local humanoid = character:WaitForChild("Humanoid", 10)
	if not humanoid or not humanoid:IsA("Humanoid") then
		return
	end
	-- Give the rig a moment to assemble its arm and Motor6Ds.
	character:WaitForChild(if humanoid.RigType == Enum.HumanoidRigType.R6 then "Right Arm" else "RightHand", 5)
	if localPlayer.Character ~= character then
		return
	end
	ChopAnimator.Bind(character)

	local aura = Formulas.GetAura(ClientData.Get("EquippedAura"))
	ChopAnimator.SetTrailColor(if aura then aura.Color else Color3.fromRGB(255, 230, 150))
end

function ChopController.Start()
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then
			return
		end
		local inputType, keyCode = input.UserInputType, input.KeyCode
		if
			inputType == Enum.UserInputType.MouseButton1
			or inputType == Enum.UserInputType.Touch
			or keyCode == Enum.KeyCode.F
			or keyCode == Enum.KeyCode.ButtonR2
		then
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
		if key == "EquippedAura" then
			local aura = Formulas.GetAura(value)
			ChopAnimator.SetTrailColor(if aura then aura.Color else Color3.fromRGB(255, 230, 150))
		end
	end)
end

return ChopController
