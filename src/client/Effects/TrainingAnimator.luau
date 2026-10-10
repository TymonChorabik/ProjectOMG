--[[
	TrainingAnimator.luau
	Idle training loop: a guard stance with alternating left/right punches, driven
	procedurally on the arm/waist Motor6D C0s every frame. Works on any character, so every
	client animates everyone who is training (C0 changes don't replicate on their own).

		local handle = TrainingAnimator.Start(character, function(side) ... end) -- side 1 = right
		handle.Stop()
]]

local RunService = game:GetService("RunService")

local TrainingAnimator = {}

local PUNCH_PERIOD = 0.5 -- seconds per punch; hands alternate
local EXTEND = 0.3 -- fraction of the period spent throwing the punch (the hit lands here)
local HOLD = 0.45 -- ...then hold until this fraction, then pull back to guard
local BLEND_IN = 0.2 -- seconds to raise the guard

type Joint = { Motor: Motor6D, Rest: CFrame, Guard: CFrame, Punch: CFrame, Side: number }
type Rig = {
	Character: Model,
	Joints: { Joint },
	Started: number,
	LastHitCycle: number,
	OnHit: ((side: number) -> ())?,
}

export type Handle = { Stop: () -> () }

local rigs: { Rig } = {}
local connection: RBXScriptConnection? = nil

local function angles(x: number, y: number, z: number): CFrame
	return CFrame.Angles(math.rad(x), math.rad(y), math.rad(z))
end

-- R15 joints sit exactly on Part0's rig attachment, so reading it gives the true rest pose
-- even if another effect is halfway through tweening the joint.
local function restC0(motor: Motor6D): CFrame
	local part0 = motor.Part0
	local attachment = part0 and part0:FindFirstChild(motor.Name .. "RigAttachment")
	if attachment and attachment:IsA("Attachment") then
		return attachment.CFrame
	end
	return motor.C0
end

local function findMotor(character: Model, partName: string, motorName: string): Motor6D?
	local part = character:FindFirstChild(partName)
	local motor = part and part:FindFirstChild(motorName)
	return if motor and motor:IsA("Motor6D") then motor else nil
end

local function buildJoints(character: Model, isR6: boolean): { Joint }
	local joints: { Joint } = {}
	local function add(motor: Motor6D?, guard: CFrame, punch: CFrame, side: number)
		if motor then
			table.insert(joints, { Motor = motor, Rest = restC0(motor), Guard = guard, Punch = punch, Side = side })
		end
	end

	if isR6 then
		-- R6 shoulder frames are rotated 90° about Y: Z swings the arm forward (mirrored on the left).
		add(findMotor(character, "Torso", "Right Shoulder"), angles(0, 0, 75), angles(0, 0, 95), 1)
		add(findMotor(character, "Torso", "Left Shoulder"), angles(0, 0, -75), angles(0, 0, -95), -1)
	else
		-- Guard: upper arms forward-down, forearms up by the chin. Punch: arm straight out.
		add(findMotor(character, "RightUpperArm", "RightShoulder"), angles(55, 0, -10), angles(88, 0, -12), 1)
		add(findMotor(character, "RightLowerArm", "RightElbow"), angles(95, 0, 0), angles(8, 0, 0), 1)
		add(findMotor(character, "LeftUpperArm", "LeftShoulder"), angles(55, 0, 10), angles(88, 0, 12), -1)
		add(findMotor(character, "LeftLowerArm", "LeftElbow"), angles(95, 0, 0), angles(8, 0, 0), -1)
		-- Waist twists into each punch.
		add(findMotor(character, "UpperTorso", "Waist"), CFrame.identity, angles(0, 20, 0), 0)
	end
	return joints
end

local function punchAlpha(phase: number): number
	if phase < EXTEND then
		local t = phase / EXTEND
		return 1 - (1 - t) * (1 - t) -- ease out
	elseif phase < HOLD then
		return 1
	end
	local t = (phase - HOLD) / (1 - HOLD)
	return 1 - t * t * (3 - 2 * t) -- smoothstep back to guard
end

local function update()
	local now = os.clock()
	for index = #rigs, 1, -1 do
		local rig = rigs[index]
		if not rig.Character.Parent then
			table.remove(rigs, index)
			continue
		end

		local elapsed = now - rig.Started
		local blend = math.min(1, elapsed / BLEND_IN)
		local cycle = math.floor(elapsed / PUNCH_PERIOD)
		local phase = (elapsed % PUNCH_PERIOD) / PUNCH_PERIOD
		local side = if cycle % 2 == 0 then 1 else -1
		local alpha = punchAlpha(phase)

		for _, joint in rig.Joints do
			local pose
			if joint.Side == 0 then
				pose = CFrame.identity:Lerp(if side == 1 then joint.Punch else joint.Punch:Inverse(), alpha)
			elseif joint.Side == side then
				pose = joint.Guard:Lerp(joint.Punch, alpha)
			else
				pose = joint.Guard
			end
			joint.Motor.C0 = joint.Rest:Lerp(joint.Rest * pose, blend)
		end

		if phase >= EXTEND and cycle ~= rig.LastHitCycle then
			rig.LastHitCycle = cycle
			if rig.OnHit then
				task.spawn(rig.OnHit, side)
			end
		end
	end

	if #rigs == 0 and connection then
		connection:Disconnect()
		connection = nil
	end
end

function TrainingAnimator.Start(character: Model, onHit: ((side: number) -> ())?): Handle
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local rig: Rig = {
		Character = character,
		Joints = buildJoints(character, humanoid ~= nil and humanoid.RigType == Enum.HumanoidRigType.R6),
		Started = os.clock(),
		LastHitCycle = -1,
		OnHit = onHit,
	}
	table.insert(rigs, rig)
	if not connection then
		connection = RunService.RenderStepped:Connect(update)
	end

	local stopped = false
	return {
		Stop = function()
			if stopped then
				return
			end
			stopped = true
			local index = table.find(rigs, rig)
			if index then
				table.remove(rigs, index)
			end
			for _, joint in rig.Joints do
				if joint.Motor.Parent then
					joint.Motor.C0 = joint.Rest
				end
			end
		end,
	}
end

return TrainingAnimator
