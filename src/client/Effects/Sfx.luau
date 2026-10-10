--[[
	Sfx.luau
	Fire-and-forget sound playback with pitch variation. 2D (UI / own chops) or 3D at a position.
]]

local ContentProvider = game:GetService("ContentProvider")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local Sfx = {}

type PlayOptions = {
	Volume: number?,
	Pitch: number?,
	PitchVariance: number?,
}

local rng = Random.new()

local function makeSound(name: string, options: PlayOptions?): Sound?
	local id = Config.Assets.Sounds[name]
	if not id or id == "" then
		return nil
	end
	local sound = Instance.new("Sound")
	sound.Name = name
	sound.SoundId = id
	sound.Volume = (options and options.Volume) or 0.6
	local variance = (options and options.PitchVariance) or 0.08
	sound.PlaybackSpeed = ((options and options.Pitch) or 1) * (1 + rng:NextNumber(-variance, variance))
	return sound
end

local function playAndClean(sound: Sound)
	sound:Play()
	sound.Ended:Once(function()
		sound:Destroy()
	end)
	Debris:AddItem(sound, 8)
end

function Sfx.Play(name: string, options: PlayOptions?)
	local sound = makeSound(name, options)
	if sound then
		sound.Parent = SoundService
		playAndClean(sound)
	end
end

function Sfx.PlayAt(name: string, position: Vector3, options: PlayOptions?)
	local sound = makeSound(name, options)
	if not sound then
		return
	end
	local attachment = Instance.new("Attachment")
	attachment.WorldPosition = position
	attachment.Parent = workspace.Terrain
	sound.RollOffMaxDistance = 140
	sound.RollOffMinDistance = 10
	sound.Parent = attachment
	playAndClean(sound)
	Debris:AddItem(attachment, 8)
end

function Sfx.Preload()
	local sounds = {}
	for name, id in Config.Assets.Sounds do
		if id ~= "" then
			local sound = Instance.new("Sound")
			sound.Name = name
			sound.SoundId = id
			table.insert(sounds, sound)
		end
	end
	task.spawn(function()
		pcall(function()
			ContentProvider:PreloadAsync(sounds)
		end)
	end)
end

return Sfx
