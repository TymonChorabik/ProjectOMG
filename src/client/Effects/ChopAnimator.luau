--[[
	ChopAnimator.luau
	The karate chop. Uses Config.Assets.ChopAnimation when you've uploaded one (replicates to
	everyone through the Animator); otherwise drives a procedural knife-hand strike by tweening
	the arm/waist Motor6D C0s (wind-up → strike → recover). Also owns the hand slash trail.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local ChopAnimator = {}

local WINDUP_TIME = 0.07
local STRIKE_TIME = 0.08
local RECOVER_TIME = 0.2

type Rig = {
	Character: Model,
	Joints: { { Motor: Motor6D, Original: CFrame, Windup: CFrame, Strike: CFrame } },
	Hand: BasePart?,
	Trail: Trail?,
	Burst: ParticleEmitter?,
	Track: AnimationTrack?,
	Tweens: { Tween },
	Sequence: number,
}

local rig: Rig? = nil

local function angles(x: number, y: number, z: number): CFrame
	return CFrame.Angles(math.rad(x), math.rad(y), math.rad(z))
end

local function findMotor(character: Model, partName: string, motorName: string): Motor6D?
	local part = character:FindFirstChild(partName)
	local motor = part and part:FindFirstChild(motorName)
	return if motor and motor:IsA("Motor6D") then motor else nil
end

local function buildTrail(hand: BasePart, isR6: boolean): (Trail, ParticleEmitter)
	local tipY = if isR6 then -1.3 else -0.6
	local baseY = if isR6 then -0.4 else 0.35

	local a0 = Instance.new("Attachment")
	a0.Name = "SlashTop"
	a0.Position = Vector3.new(0, baseY, 0)
	a0.Parent = hand
	local a1 = Instance.new("Attachment")
	a1.Name = "SlashTip"
	a1.Position = Vector3.new(0, tipY, 0)
	a1.Parent = hand

	local trail = Instance.new("Trail")
	trail.Name = "ChopSlash"
	trail.Attachment0 = a0
	trail.Attachment1 = a1
	trail.Lifetime = 0.16
	trail.MinLength = 0.05
	trail.FaceCamera = true
	trail.LightEmission = 1
	trail.LightInfluence = 0
	trail.Color = ColorSequence.new(Color3.new(1, 1, 1))
	trail.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.05),
		NumberSequenceKeypoint.new(1, 1),
	})
	trail.WidthScale = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(1, 0.1),
	})
	trail.Enabled = false
	trail.Parent = hand

	local burst = Instance.new("ParticleEmitter")
	burst.Name = "ChopSparks"
	burst.Texture = Config.Assets.Particles.Sparkle
	burst.LightEmission = 1
	burst.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.6),
		NumberSequenceKeypoint.new(1, 0),
	})
	burst.Lifetime = NumberRange.new(0.15, 0.3)
	burst.Speed = NumberRange.new(8, 16)
	burst.SpreadAngle = Vector2.new(60, 60)
	burst.Rate = 0
	burst.EmissionDirection = Enum.NormalId.Bottom
	burst.Parent = a1

	return trail, burst
end

local function setup(character: Model): Rig?
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return nil
	end

	local newRig: Rig = {
		Character = character,
		Joints = {},
		Hand = nil,
		Trail = nil,
		Burst = nil,
		Track = nil,
		Tweens = {},
		Sequence = 0,
	}

	local isR6 = humanoid.RigType == Enum.HumanoidRigType.R6
	local function addJoint(motor: Motor6D?, windup: CFrame, strike: CFrame)
		if motor then
			table.insert(newRig.Joints, { Motor = motor, Original = motor.C0, Windup = windup, Strike = strike })
		end
	end

	if isR6 then
		-- R6 joint frames are rotated 90° about Y; Z is the forward swing axis.
		addJoint(findMotor(character, "Torso", "Right Shoulder"), angles(0, 0, 165), angles(0, 0, 70))
		newRig.Hand = character:FindFirstChild("Right Arm") :: BasePart?
	else
		addJoint(findMotor(character, "RightUpperArm", "RightShoulder"), angles(150, 0, 20), angles(75, 0, -30))
		addJoint(findMotor(character, "RightLowerArm", "RightElbow"), angles(65, 0, 0), angles(5, 0, 0))
		addJoint(findMotor(character, "UpperTorso", "Waist"), angles(0, -18, 0), angles(4, 22, 0))
		newRig.Hand = character:FindFirstChild("RightHand") :: BasePart?
	end

	if newRig.Hand then
		newRig.Trail, newRig.Burst = buildTrail(newRig.Hand, isR6)
	end

	if Config.Assets.ChopAnimation ~= "" then
		local animator = humanoid:FindFirstChildOfClass("Animator")
		if animator then
			local animation = Instance.new("Animation")
			animation.AnimationId = Config.Assets.ChopAnimation
			local ok, track = pcall(function()
				return animator:LoadAnimation(animation)
			end)
			if ok and track then
				track.Priority = Enum.AnimationPriority.Action
				newRig.Track = track
			end
		end
	end

	return newRig
end

local function cancelTweens(current: Rig)
	for _, tween in current.Tweens do
		tween:Cancel()
	end
	table.clear(current.Tweens)
end

local function tweenJoints(
	current: Rig,
	field: string,
	duration: number,
	style: Enum.EasingStyle,
	direction: Enum.EasingDirection
)
	cancelTweens(current)
	local info = TweenInfo.new(duration, style, direction)
	for _, joint in current.Joints do
		local goal = if field == "Original" then joint.Original else joint.Original * (joint :: any)[field]
		local tween = TweenService:Create(joint.Motor, info, { C0 = goal })
		tween:Play()
		table.insert(current.Tweens, tween)
	end
end

function ChopAnimator.Bind(character: Model)
	ChopAnimator.Unbind()
	rig = setup(character)
end

function ChopAnimator.Unbind()
	if rig then
		cancelTweens(rig)
		for _, joint in rig.Joints do
			if joint.Motor.Parent then
				joint.Motor.C0 = joint.Original
			end
		end
	end
	rig = nil
end

function ChopAnimator.SetTrailColor(color: Color3)
	if rig and rig.Trail then
		rig.Trail.Color = ColorSequence.new(Color3.new(1, 1, 1), color)
	end
	if rig and rig.Burst then
		rig.Burst.Color = ColorSequence.new(Color3.new(1, 1, 1), color)
	end
end

-- Plays one chop. onImpact fires at the moment the hand lands.
function ChopAnimator.Play(isCritical: boolean?, onImpact: (() -> ())?)
	local current = rig
	if not current or not current.Character.Parent then
		if onImpact then
			onImpact()
		end
		return
	end

	current.Sequence += 1
	local sequence = current.Sequence

	if current.Track then
		current.Track:Play(0.05, 1, 1.4)
		task.delay(0.12, function()
			if onImpact then
				onImpact()
			end
		end)
		return
	end

	tweenJoints(current, "Windup", WINDUP_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	task.delay(WINDUP_TIME, function()
		if current.Sequence ~= sequence then
			return
		end
		if current.Trail then
			current.Trail.Enabled = true
		end
		tweenJoints(current, "Strike", STRIKE_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.In)

		task.delay(STRIKE_TIME, function()
			if current.Burst then
				current.Burst:Emit(if isCritical then 18 else 8)
			end
			if onImpact then
				onImpact()
			end
			if current.Sequence ~= sequence then
				return
			end
			if current.Trail then
				task.delay(0.05, function()
					if current.Sequence == sequence and current.Trail then
						current.Trail.Enabled = false
					end
				end)
			end
			tweenJoints(current, "Original", RECOVER_TIME, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
		end)
	end)
end

return ChopAnimator
