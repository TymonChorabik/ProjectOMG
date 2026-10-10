--[[
	CameraShake.luau
	Trauma-based camera shake (shake = trauma²) layered on top of the default camera each frame.
]]

local RunService = game:GetService("RunService")

local CameraShake = {}

local MAX_PITCH_YAW = 2.2 -- degrees
local MAX_ROLL = 3.5 -- degrees
local MAX_OFFSET = 0.35 -- studs
local DECAY_PER_SECOND = 1.6
local FREQUENCY = 22

local trauma = 0
local bound = false

local function step(dt: number)
	if trauma <= 0 then
		return
	end
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end

	local shake = trauma * trauma
	local t = os.clock() * FREQUENCY
	local pitch = math.rad(MAX_PITCH_YAW) * shake * math.noise(t, 0.1, 0)
	local yaw = math.rad(MAX_PITCH_YAW) * shake * math.noise(0.2, t, 0)
	local roll = math.rad(MAX_ROLL) * shake * math.noise(0.3, 0, t)
	local offset = Vector3.new(math.noise(t, 7.1, 0), math.noise(0, t, 7.3), 0) * MAX_OFFSET * shake

	camera.CFrame = camera.CFrame * CFrame.new(offset) * CFrame.Angles(pitch, yaw, roll)
	trauma = math.max(0, trauma - dt * DECAY_PER_SECOND)
end

-- amount: 0..1 (0.3 = light bump, 1 = earthquake)
function CameraShake.Shake(amount: number)
	trauma = math.clamp(trauma + amount, 0, 1)
	if not bound then
		bound = true
		RunService:BindToRenderStep("KungFuCameraShake", Enum.RenderPriority.Camera.Value + 1, step)
	end
end

return CameraShake
