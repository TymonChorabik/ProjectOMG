--[[
	ViewportPreview.luau
	Live 3D thumbnails of pets / hand items / eggs inside UI frames (ViewportFrame + camera).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ItemModels = require(Shared.ItemModels)
local PetModels = require(Shared.PetModels)

local Create = require(script.Parent.Create)

local ViewportPreview = {}

local function mount(parent: GuiObject, model: Model, distance: number, height: number): ViewportFrame
	local existing = parent:FindFirstChild("Preview")
	if existing then
		existing:Destroy()
	end
	local viewport = Create("ViewportFrame", {
		Name = "Preview",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Ambient = Color3.fromRGB(200, 200, 200),
		LightColor = Color3.fromRGB(255, 255, 255),
		LightDirection = Vector3.new(-1, -1, 1),
		ZIndex = (parent.ZIndex or 1) + 1,
		Parent = parent,
	})
	model:PivotTo(CFrame.new())
	model.Parent = viewport
	local camera = Instance.new("Camera")
	camera.FieldOfView = 40
	-- Models face -Z; look at them from the front, slightly from the side and above.
	camera.CFrame = CFrame.lookAt(Vector3.new(distance * 0.45, height, -distance), Vector3.new(0, 0, 0))
	camera.Parent = viewport
	viewport.CurrentCamera = camera
	return viewport
end

function ViewportPreview.Pet(parent: GuiObject, petId: string): ViewportFrame
	return mount(parent, PetModels.Build(petId), 6.5, 1.8)
end

function ViewportPreview.Item(parent: GuiObject, item): ViewportFrame
	return mount(parent, ItemModels.Build(item), 9, 2)
end

function ViewportPreview.Egg(parent: GuiObject, color: Color3): ViewportFrame
	local model = Instance.new("Model")
	local egg = Instance.new("Part")
	egg.Shape = Enum.PartType.Ball
	egg.Size = Vector3.new(3, 3.8, 3)
	egg.Color = color
	egg.Material = Enum.Material.SmoothPlastic
	egg.Anchored = true
	egg.Parent = model
	model.PrimaryPart = egg
	return mount(parent, model, 9, 1)
end

return ViewportPreview
