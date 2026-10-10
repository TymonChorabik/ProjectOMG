--[[
	HatchOverlay.luau
	Egg hatch cinematic: the egg wobbles harder and harder, flashes, and reveals the pet with its
	rarity and bonus. Hatches queue up so several in a row play one after another.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Formulas = require(Shared.Formulas)
local NumberFormat = require(Shared.NumberFormat)

local Sfx = require(script.Parent.Parent.Effects.Sfx)
local Create = require(script.Parent.Create)
local Theme = require(script.Parent.Theme)
local ViewportPreview = require(script.Parent.ViewportPreview)

local HatchOverlay = {}

local queue: { { EggId: string, PetId: string } } = {}
local playing = false
local overlayParent: Instance? = nil

local function playOne(eggId: string, petId: string)
	local parent = overlayParent :: Instance
	local egg = Formulas.GetEgg(eggId)
	local def = Config.Pets[petId]

	local backdrop = Create("Frame", {
		Name = "Hatch",
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 50,
		Parent = parent,
	})
	TweenService:Create(backdrop, TweenInfo.new(0.25), { BackgroundTransparency = 0.45 }):Play()

	local stage = Create("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.45),
		Size = UDim2.fromOffset(340, 340),
		ZIndex = 51,
		Parent = backdrop,
	})
	local eggView = ViewportPreview.Egg(stage, if egg then egg.Color else Color3.new(1, 1, 1))

	-- Wobble, faster each time.
	for step = 1, 6 do
		local angle = (if step % 2 == 0 then -1 else 1) * (6 + step * 3)
		local tween = TweenService:Create(eggView, TweenInfo.new(0.22 - step * 0.025), { Rotation = angle })
		tween:Play()
		tween.Completed:Wait()
	end

	local flash = Create(
		"Frame",
		{ BackgroundColor3 = Color3.new(1, 1, 1), Size = UDim2.fromScale(1, 1), ZIndex = 60, Parent = backdrop }
	)
	TweenService:Create(flash, TweenInfo.new(0.5), { BackgroundTransparency = 1 }):Play()
	Sfx.Play("Smash", { Volume = 0.6, Pitch = 1.4 })

	ViewportPreview.Pet(stage, petId)
	local rarity = Config.Rarities[def.Rarity]
	local scale = Create("UIScale", { Scale = 0.3, Parent = stage })
	TweenService:Create(scale, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
		:Play()

	Create.Label({
		Text = def.Name,
		Font = Theme.Fonts.Title,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0.45, 180),
		Size = UDim2.fromOffset(600, 60),
		StrokeThickness = 5,
		ZIndex = 52,
		Parent = backdrop,
	})
	Create.Label({
		Text = `{string.upper(def.Rarity)}  •  +{NumberFormat.Percent(def.Bonus)} Strength`,
		TextColor3 = rarity.Color,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0.45, 240),
		Size = UDim2.fromOffset(600, 36),
		StrokeThickness = 3,
		ZIndex = 52,
		Parent = backdrop,
	})

	task.wait(2.2)
	TweenService:Create(backdrop, TweenInfo.new(0.25), { BackgroundTransparency = 1 }):Play()
	TweenService:Create(scale, TweenInfo.new(0.2), { Scale = 0 }):Play()
	task.wait(0.25)
	backdrop:Destroy()
end

function HatchOverlay.Init(parent: Instance)
	overlayParent = parent
end

function HatchOverlay.Play(eggId: string, petId: string)
	table.insert(queue, { EggId = eggId, PetId = petId })
	if playing or not overlayParent then
		return
	end
	playing = true
	task.spawn(function()
		while #queue > 0 do
			local entry = table.remove(queue, 1) :: { EggId: string, PetId: string }
			local ok, err = pcall(playOne, entry.EggId, entry.PetId)
			if not ok then
				warn("[HatchOverlay] " .. tostring(err))
			end
		end
		playing = false
	end)
end

return HatchOverlay
