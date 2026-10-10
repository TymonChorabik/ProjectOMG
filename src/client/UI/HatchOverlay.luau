--[[
	HatchOverlay.luau
	Egg hatch cinematic: the egg wobbles harder and harder, flashes, and reveals the pet with its
	rarity and bonus. Hatch 3 / Hatch 8 play all eggs at once in a grid. Hatches queue up so
	several in a row play one after another.
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

local queue: { { EggId: string, PetIds: { string } } } = {}
local playing = false
local overlayParent: Instance? = nil

-- Stage size and grid for 1, 3 or 8 eggs at once.
local function layout(count: number): (number, number)
	if count <= 1 then
		return 260, 1
	elseif count <= 4 then
		return 210, count
	end
	return 170, 4
end

local function playMany(eggId: string, petIds: { string })
	local parent = overlayParent :: Instance
	local egg = Formulas.GetEgg(eggId)
	local count = #petIds
	local size, columns = layout(count)
	local rows = math.ceil(count / columns)
	local single = count == 1

	local backdrop = Create("Frame", {
		Name = "Hatch",
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 50,
		Parent = parent,
	})
	TweenService:Create(backdrop, TweenInfo.new(0.25), { BackgroundTransparency = 0.45 }):Play()

	-- One stage per egg, centred as a grid (rows of up to 4).
	local cellHeight = size + (if single then 0 else 56)
	local stages, eggViews = {}, {}
	for index = 1, count do
		local column = (index - 1) % columns
		local row = (index - 1) // columns
		local inRow = math.min(columns, count - row * columns)
		local x = (column - (inRow - 1) / 2) * (size + 16)
		local y = (row - (rows - 1) / 2) * (cellHeight + 10)
		local stage = Create("Frame", {
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, x, 0.45, y),
			Size = UDim2.fromOffset(size, size),
			ZIndex = 51,
			Parent = backdrop,
		})
		stages[index] = stage
		eggViews[index] = ViewportPreview.Egg(stage, if egg then egg.Color else Color3.new(1, 1, 1))
	end

	-- Wobble, faster each time (all eggs together).
	for step = 1, 6 do
		local angle = (if step % 2 == 0 then -1 else 1) * (6 + step * 3)
		local info = TweenInfo.new(0.22 - step * 0.025)
		local last
		for _, view in eggViews do
			last = TweenService:Create(view, info, { Rotation = angle })
			last:Play()
		end
		last.Completed:Wait()
	end

	local flash = Create(
		"Frame",
		{ BackgroundColor3 = Color3.new(1, 1, 1), Size = UDim2.fromScale(1, 1), ZIndex = 60, Parent = backdrop }
	)
	TweenService:Create(flash, TweenInfo.new(0.5), { BackgroundTransparency = 1 }):Play()
	Sfx.Play("Smash", { Volume = 0.6, Pitch = 1.4 })

	local scales = {}
	for index, petId in petIds do
		local stage = stages[index]
		local def = Config.Pets[petId]
		local rarity = Config.Rarities[def.Rarity]
		eggViews[index]:Destroy()
		ViewportPreview.Pet(stage, petId)
		local scale = Create("UIScale", { Scale = 0.3, Parent = stage })
		TweenService:Create(scale, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
			:Play()
		scales[index] = scale

		if single then
			Create.Label({
				Text = def.Name,
				Font = Theme.Fonts.Title,
				AnchorPoint = Vector2.new(0.5, 0),
				Position = UDim2.new(0.5, 0, 0.45, 140),
				Size = UDim2.fromOffset(480, 42),
				StrokeThickness = 4,
				ZIndex = 52,
				Parent = backdrop,
			})
			Create.Label({
				Text = `{string.upper(def.Rarity)}  •  +{NumberFormat.Percent(def.Bonus)} Strength`,
				TextColor3 = rarity.Color,
				AnchorPoint = Vector2.new(0.5, 0),
				Position = UDim2.new(0.5, 0, 0.45, 186),
				Size = UDim2.fromOffset(480, 26),
				StrokeThickness = 3,
				ZIndex = 52,
				Parent = backdrop,
			})
		else
			Create.Label({
				Text = def.Name,
				AnchorPoint = Vector2.new(0.5, 0),
				Position = UDim2.new(0.5, 0, 1, 0),
				Size = UDim2.new(1, 20, 0, 30),
				StrokeThickness = 3.5,
				ZIndex = 52,
				Parent = stage,
			})
			Create.Label({
				Text = string.upper(def.Rarity),
				TextColor3 = rarity.Color,
				AnchorPoint = Vector2.new(0.5, 0),
				Position = UDim2.new(0.5, 0, 1, 30),
				Size = UDim2.new(1, 0, 0, 22),
				StrokeThickness = 3,
				ZIndex = 52,
				Parent = stage,
			})
		end
	end

	task.wait(if single then 2.2 else 2.8)
	TweenService:Create(backdrop, TweenInfo.new(0.25), { BackgroundTransparency = 1 }):Play()
	for _, scale in scales do
		TweenService:Create(scale, TweenInfo.new(0.2), { Scale = 0 }):Play()
	end
	task.wait(0.25)
	backdrop:Destroy()
end

function HatchOverlay.Init(parent: Instance)
	overlayParent = parent
end

-- Plays a hatch of one or more pets from the same egg (Hatch 1 / 3 / 8).
function HatchOverlay.Play(eggId: string, petIds: { string })
	if #petIds == 0 then
		return
	end
	table.insert(queue, { EggId = eggId, PetIds = petIds })
	if playing or not overlayParent then
		return
	end
	playing = true
	task.spawn(function()
		while #queue > 0 do
			local entry = table.remove(queue, 1) :: { EggId: string, PetIds: { string } }
			local ok, err = pcall(playMany, entry.EggId, entry.PetIds)
			if not ok then
				warn("[HatchOverlay] " .. tostring(err))
			end
		end
		playing = false
	end)
end

return HatchOverlay
