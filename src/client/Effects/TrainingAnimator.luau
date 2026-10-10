--[[
	TrainingAnimator.luau
	Dojo training motion: a ready stance, then karate chops straight down onto the item on the
	stand, alternating hands (wind up high → chop down → recover). Driven procedurally on the
	arm/waist Motor6D C0s every frame, and works on any character, so every client animates
	everyone who is training (C0 changes don't replicate on their own).

		-- Loop: chops every `Period` seconds (other players).
		local handle = TrainingAnimator.Start(character, { Period = 0.6, OnHit = function(side) end })
		-- Manual: one chop per Strike() (the local player, in step with the server's gains).
		local handle = TrainingAnimator.Start(character, { OnHit = ... })
		handle.Strike(onImpact)  -- onImpact runs when the hand lands
		handle.Stop()
]]

local RunService = game:GetService("RunService")

local TrainingAnimator = {}

local CHOP_TIME = 0.5 -- manual chop length
local WINDUP_END = 0.48 -- fraction of a chop spent winding up...
local STRIKE_END = 0.66 -- ...then chopping down: the hit lands here
local HOLD_END = 0.76 -- ...a short hold, then back to the ready stance
local BLEND_IN = 0.2 -- seconds to raise the guard

type Joint = {
	Motor: Motor6D,
	Rest: CFrame,
	Guard: CFrame,
	Windup: CFrame,
	Strike: CFrame,
	Side: number, -- 1 right arm, -1 left arm, 0 waist
}

type Rig = {
	Character: Model,
	Joints: { Joint },
	Started: number,
	Period: number?,
	OnHit: ((side: number) -> ())?,
	-- loop mode
	LastHitCycle: number,
	-- manual mode
	ChopStart: number?,
	ChopSide: number,
	ChopHit: boolean,
	Impact: (() -> ())?,
}

export type Handle = {
	Stop: () -> (),
	Strike: (onImpact: (() -> ())?) -> (),
}
export type Options = { Period: number?, OnHit: ((side: number) -> ())? }

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
	local function add(motor: Motor6D?, guard: CFrame, windup: CFrame, strike: CFrame, side: number)
		if motor then
			table.insert(joints, {
				Motor = motor,
				Rest = restC0(motor),
				Guard = guard,
				Windup = windup,
				Strike = strike,
				Side = side,
			})
		end
	end

	if isR6 then
		-- R6 shoulder frames are rotated 90° about Y: Z swings the arm forward (mirrored on the left).
		local right = findMotor(character, "Torso", "Right Shoulder")
		local left = findMotor(character, "Torso", "Left Shoulder")
		add(right, angles(0, 0, 45), angles(0, 0, 170), angles(0, 0, 70), 1)
		add(left, angles(0, 0, -45), angles(0, 0, -170), angles(0, 0, -70), -1)
	else
		-- Ready: hands up in front of the chest. Wind-up: arm high above the head.
		-- Chop: arm straight down onto the item on the stand.
		add(
			findMotor(character, "RightUpperArm", "RightShoulder"),
			angles(40, 0, -8),
			angles(165, 0, 12),
			angles(58, 0, -6),
			1
		)
		add(findMotor(character, "RightLowerArm", "RightElbow"), angles(75, 0, 0), angles(45, 0, 0), angles(4, 0, 0), 1)
		add(
			findMotor(character, "LeftUpperArm", "LeftShoulder"),
			angles(40, 0, 8),
			angles(165, 0, -12),
			angles(58, 0, 6),
			-1
		)
		add(findMotor(character, "LeftLowerArm", "LeftElbow"), angles(75, 0, 0), angles(45, 0, 0), angles(4, 0, 0), -1)
		-- Waist leans back on the wind-up and forward into the chop (twist mirrored per hand).
		add(findMotor(character, "UpperTorso", "Waist"), CFrame.identity, angles(6, -12, 0), angles(-16, 10, 0), 0)
	end
	return joints
end

local function easeOut(t: number): number
	return 1 - (1 - t) * (1 - t)
end

local function easeIn(t: number): number
	return t * t
end

local function smooth(t: number): number
	return t * t * (3 - 2 * t)
end

-- Pose of one joint `phase` (0..1) into a chop with the `side` hand (nil = just the stance).
local function pose(joint: Joint, phase: number?, side: number): CFrame
	local guard, windup, strike = joint.Guard, joint.Windup, joint.Strike
	if joint.Side == 0 and side == -1 then
		-- Mirror the waist twist for the left hand.
		windup = angles(6, 12, 0)
		strike = angles(-16, -10, 0)
	end
	if phase == nil or (joint.Side ~= 0 and joint.Side ~= side) then
		return guard
	end
	if phase < WINDUP_END then
		return guard:Lerp(windup, easeOut(phase / WINDUP_END))
	elseif phase < STRIKE_END then
		return windup:Lerp(strike, easeIn((phase - WINDUP_END) / (STRIKE_END - WINDUP_END)))
	elseif phase < HOLD_END then
		return strike
	end
	return strike:Lerp(guard, smooth((phase - HOLD_END) / (1 - HOLD_END)))
end

local function hit(rig: Rig, side: number)
	if rig.OnHit then
		task.spawn(rig.OnHit, side)
	end
	local impact = rig.Impact
	rig.Impact = nil
	if impact then
		task.spawn(impact)
	end
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
		local phase: number? = nil
		local side = 1

		if rig.Period then
			local cycle = math.floor(elapsed / rig.Period)
			phase = (elapsed % rig.Period) / rig.Period
			side = if cycle % 2 == 0 then 1 else -1
			if (phase :: number) >= STRIKE_END and cycle ~= rig.LastHitCycle then
				rig.LastHitCycle = cycle
				hit(rig, side)
			end
		elseif rig.ChopStart then
			side = rig.ChopSide
			phase = (now - rig.ChopStart) / CHOP_TIME
			if (phase :: number) >= STRIKE_END and not rig.ChopHit then
				rig.ChopHit = true
				hit(rig, side)
			end
			if (phase :: number) >= 1 then
				rig.ChopStart = nil
				phase = nil
			end
		end

		for _, joint in rig.Joints do
			joint.Motor.C0 = joint.Rest:Lerp(joint.Rest * pose(joint, phase, side), blend)
		end
	end

	if #rigs == 0 and connection then
		connection:Disconnect()
		connection = nil
	end
end

function TrainingAnimator.Start(character: Model, options: Options?): Handle
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local rig: Rig = {
		Character = character,
		Joints = buildJoints(character, humanoid ~= nil and humanoid.RigType == Enum.HumanoidRigType.R6),
		Started = os.clock(),
		Period = options and options.Period,
		OnHit = options and options.OnHit,
		LastHitCycle = -1,
		ChopStart = nil,
		ChopSide = -1,
		ChopHit = false,
		Impact = nil,
	}
	table.insert(rigs, rig)
	if not connection then
		connection = RunService.RenderStepped:Connect(update)
	end

	local stopped = false
	local function stop()
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
		local impact = rig.Impact
		rig.Impact = nil
		if impact then
			task.spawn(impact)
		end
	end

	local function strike(onImpact: (() -> ())?)
		if stopped then
			if onImpact then
				task.spawn(onImpact)
			end
			return
		end
		-- A chop still in the air lands now so its popup isn't lost.
		if rig.ChopStart and not rig.ChopHit then
			hit(rig, rig.ChopSide)
		end
		rig.ChopStart = os.clock()
		rig.ChopSide = -rig.ChopSide
		rig.ChopHit = false
		rig.Impact = onImpact
	end

	return { Stop = stop, Strike = strike }
end

return TrainingAnimator
