--[[
	ChopController.luau
	Keeps the karate-chop animation (ChopAnimator) bound to your character and its slash trail
	in your hand item's colour. Wall runs use it (LaneController). There is no click-to-train:
	Strength only comes from the dojo pads (TrainingController).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Formulas = require(Shared.Formulas)

local ClientData = require(script.Parent.Parent.ClientData)
local ChopAnimator = require(script.Parent.Parent.Effects.ChopAnimator)

local ChopController = {}

local localPlayer = Players.LocalPlayer

local function trailColor(itemId: string?): Color3
	local item = Formulas.GetItem(itemId)
	return if item then item.Color else Color3.fromRGB(255, 230, 150)
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
	ChopAnimator.SetTrailColor(trailColor(ClientData.Get("EquippedItem")))
end

function ChopController.Start()
	localPlayer.CharacterAdded:Connect(bindCharacter)
	if localPlayer.Character then
		task.spawn(bindCharacter, localPlayer.Character)
	end
	localPlayer.CharacterRemoving:Connect(function()
		ChopAnimator.Unbind()
	end)

	ClientData.Changed:Connect(function(key, value)
		if key == "EquippedItem" then
			ChopAnimator.SetTrailColor(trailColor(value))
		end
	end)
end

return ChopController
