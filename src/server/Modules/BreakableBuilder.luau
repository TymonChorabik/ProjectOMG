--[[
	BreakableBuilder.luau
	Builds a breaking stand: pedestal/supports + a pre-fractured, stud-textured object + sign.

	Model layout (clients rely on these names):
		Stand (Model)  [attributes StandId, ObjectId, DojoId, RequiredPower, ...; tag added by Rig]
		├─ Base (Model)          pedestal / supports, never breaks
		├─ Object (Model)
		│   ├─ Core (Part)       anchored, invisible root every segment is welded to
		│   └─ Segment_N (Part)  stud-textured fracture pieces (attribute BaseTransparency)
		└─ Sign (Part)           invisible anchor holding the BillboardGui

	Build() only creates (anchored) instances, so it can be baked into the map file. Rig() runs
	on the server at startup: it welds segments to the Core, tags the stand and returns the
	StandInfo used for validation.

	Custom Blender meshes: put a Model named after the breakable id (e.g. "IronAnvil") inside
	ServerStorage/BreakableModels. ApplyCustomModel swaps the voxel segments for every BasePart
	in it, scaled to fit the configured Size.
]]

local CollectionService = game:GetService("CollectionService")
local ServerStorage = game:GetService("ServerStorage")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local NumberFormat = require(Shared.NumberFormat)
local StudSurface = require(Shared.StudSurface)

local BreakableLayout = require(script.Parent.BreakableLayout)

local BreakableBuilder = {}

BreakableBuilder.TAG = "BreakableStand"

local SEGMENT_GAP = 0.03

export type StandInfo = {
	Id: string,
	ObjectId: string,
	DojoId: string,
	Def: any,
	Model: Model,
	Core: BasePart,
	Position: Vector3,
	Radius: number,
}

local function stringToSeed(text: string): number
	local seed = 0
	for i = 1, #text do
		seed = (seed * 31 + string.byte(text, i)) % 2_147_483_647
	end
	return seed
end

local function newPart(parent: Instance, props: { [string]: any }): Part
	props.Parent = parent
	return StudSurface.NewPart(props)
end

--------------------------------------------------------------------------------
-- Stand bases
--------------------------------------------------------------------------------

-- Returns the Y (in stand space, relative to the floor) where the object's bottom should sit.
local function buildBase(baseModel: Model, standCFrame: CFrame, def, theme): number
	local size: Vector3 = def.Size
	local trim: Color3 = theme.Trim
	local accent: Color3 = theme.Accent

	if def.Stand == "Supports" then
		-- Two cinder-block supports; the object spans the gap (classic karate board break).
		local supportHeight = 3
		local offsetX = size.X / 2 - 0.9
		for _, side in { -1, 1 } do
			newPart(baseModel, {
				Name = "Support",
				Size = Vector3.new(1.6, supportHeight, size.Z + 0.8),
				CFrame = standCFrame * CFrame.new(side * offsetX, supportHeight / 2, 0),
				Color = Color3.fromRGB(150, 150, 156),
			})
			newPart(baseModel, {
				Name = "SupportCap",
				Size = Vector3.new(2, 0.4, size.Z + 1.2),
				CFrame = standCFrame * CFrame.new(side * offsetX, 0.2, 0),
				Color = trim,
			})
		end
		return supportHeight
	elseif def.Stand == "Float" then
		local radius = math.max(size.X, size.Z) / 2 + 2
		newPart(baseModel, {
			Name = "Plinth",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(1.4, radius * 2, radius * 2),
			CFrame = standCFrame * CFrame.new(0, 0.7, 0) * CFrame.Angles(0, 0, math.rad(90)),
			Color = trim,
		})
		newPart(baseModel, {
			Name = "GlowRing",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.3, radius * 2 - 1.2, radius * 2 - 1.2),
			CFrame = standCFrame * CFrame.new(0, 1.5, 0) * CFrame.Angles(0, 0, math.rad(90)),
			Color = accent,
			Material = Enum.Material.Neon,
			Studs = false,
		})
		return 1.6 + 3 -- hover gap
	end

	-- "Pedestal": two stacked studded slabs.
	newPart(baseModel, {
		Name = "PedestalBottom",
		Size = Vector3.new(size.X + 3, 1, size.Z + 3),
		CFrame = standCFrame * CFrame.new(0, 0.5, 0),
		Color = trim,
	})
	newPart(baseModel, {
		Name = "PedestalTop",
		Size = Vector3.new(size.X + 1.6, 1.2, size.Z + 1.6),
		CFrame = standCFrame * CFrame.new(0, 1.6, 0),
		Color = accent,
	})
	return 2.2
end

--------------------------------------------------------------------------------
-- Object segments
--------------------------------------------------------------------------------

local function styleSegment(part: BasePart, def, category: string, rng: Random)
	local material = def.Material or Enum.Material.Plastic
	local color = def.Colors[rng:NextInteger(1, #def.Colors)]

	if category == "Base" and def.AccentChance and rng:NextNumber() < def.AccentChance then
		category = "Accent"
	end
	if category == "Accent" and def.AccentColor then
		color = def.AccentColor
		material = def.AccentMaterial or material
	elseif category == "Alt" and def.AltColor then
		color = def.AltColor
		material = def.AltMaterial or material
	end

	part.Color = color
	part.Material = material
	part.Transparency = if material == Enum.Material.Neon then 0 else (def.Transparency or 0)
	part:SetAttribute("BaseTransparency", part.Transparency)
end

local function prepareSegment(part: BasePart, objectModel: Model, index: number)
	part.Name = "Segment_" .. index
	part.Anchored = true -- Rig() unanchors and welds at runtime
	part.CanCollide = true
	part.CanTouch = false
	part.CanQuery = false
	if part:GetAttribute("BaseTransparency") == nil then
		part:SetAttribute("BaseTransparency", part.Transparency)
	end
	part.Parent = objectModel
end

local function buildVoxelSegments(objectModel: Model, objectCFrame: CFrame, def, seed: number)
	local size: Vector3, grid: Vector3 = def.Size, def.Grid
	local rng = Random.new(seed)
	local cells = BreakableLayout.Compute(def.Shape, size.X, size.Y, size.Z, grid.X, grid.Y, grid.Z, def.Hollow)

	for _, cell in cells do
		local part = Instance.new("Part")
		part.Size = Vector3.new(
			math.max(0.2, cell.SizeX - SEGMENT_GAP),
			math.max(0.2, cell.SizeY - SEGMENT_GAP),
			math.max(0.2, cell.SizeZ - SEGMENT_GAP)
		)
		part.CFrame = objectCFrame * CFrame.new(cell.X, cell.Y, cell.Z)
		styleSegment(part, def, cell.Category, rng)
		StudSurface.Apply(part)
		prepareSegment(part, objectModel, cell.Index)
	end
end

local function buildCustomSegments(objectModel: Model, objectCFrame: CFrame, def, template: Model)
	local model = template:Clone()
	local _, boundsSize = model:GetBoundingBox()
	local fit = math.min(def.Size.X / boundsSize.X, def.Size.Y / boundsSize.Y, def.Size.Z / boundsSize.Z)
	if fit > 0 and math.abs(fit - 1) > 0.01 then
		model:ScaleTo(model:GetScale() * fit)
	end
	model:PivotTo(objectCFrame)

	local rng = Random.new(#def.Name)
	local index = 0
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			index += 1
			-- Imported pieces get the object's palette and the square-stud overlay.
			if descendant:GetAttribute("KeepColor") ~= true then
				styleSegment(descendant, def, "Base", rng)
			end
			StudSurface.Apply(descendant)
			prepareSegment(descendant, objectModel, index)
		end
	end
	model:Destroy()
end

--------------------------------------------------------------------------------
-- Sign
--------------------------------------------------------------------------------

local function buildSign(stand: Model, position: Vector3, def)
	local anchor = Instance.new("Part")
	anchor.Name = "Sign"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(1, 1, 1)
	anchor.Position = position
	anchor.Parent = stand

	local gui = Instance.new("BillboardGui")
	gui.Name = "Info"
	gui.Size = UDim2.new(10, 0, 3.6, 0)
	gui.MaxDistance = 90
	gui.LightInfluence = 0
	gui.AlwaysOnTop = false
	gui.Parent = anchor

	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Parent = gui

	local function label(name: string, text: string, color: Color3, heightScale: number, order: number)
		local textLabel = Instance.new("TextLabel")
		textLabel.Name = name
		textLabel.BackgroundTransparency = 1
		textLabel.Size = UDim2.fromScale(1, heightScale)
		textLabel.Font = Enum.Font.FredokaOne
		textLabel.TextScaled = true
		textLabel.Text = text
		textLabel.TextColor3 = color
		textLabel.LayoutOrder = order
		local stroke = Instance.new("UIStroke")
		stroke.Thickness = 2.5
		stroke.Color = Color3.fromRGB(20, 20, 24)
		stroke.Parent = textLabel
		textLabel.Parent = gui
		return textLabel
	end

	label("ObjectName", def.Name, Color3.new(1, 1, 1), 0.4, 1)
	label(
		"Requirement",
		"⚡ " .. NumberFormat.Abbreviate(def.RequiredPower) .. " Power",
		Color3.fromRGB(255, 220, 70),
		0.32,
		2
	)
	label("Reward", "🪙 +" .. NumberFormat.Abbreviate(def.Coins), Color3.fromRGB(255, 240, 150), 0.28, 3)
end

--------------------------------------------------------------------------------
-- Public
--------------------------------------------------------------------------------

local function getCustomTemplate(objectId: string): Model?
	local folder = ServerStorage:FindFirstChild("BreakableModels")
	local template = folder and folder:FindFirstChild(objectId)
	return if template and template:IsA("Model") then template else nil
end

-- Creates the stand model (all parts anchored, no welds) and returns it.
function BreakableBuilder.Build(
	standId: string,
	objectId: string,
	dojoId: string,
	standCFrame: CFrame,
	theme,
	parent: Instance
): Model
	local def = assert(Config.Breakables[objectId], "Unknown breakable " .. objectId)

	local stand = Instance.new("Model")
	stand.Name = standId

	local baseModel = Instance.new("Model")
	baseModel.Name = "Base"
	baseModel.Parent = stand
	local objectBottom = buildBase(baseModel, standCFrame, def, theme)

	local objectModel = Instance.new("Model")
	objectModel.Name = "Object"
	objectModel.Parent = stand

	local objectCFrame = standCFrame * CFrame.new(0, objectBottom + def.Size.Y / 2, 0)

	local core = Instance.new("Part")
	core.Name = "Core"
	core.Anchored = true
	core.CanCollide = false
	core.CanQuery = false
	core.CanTouch = false
	core.Transparency = 1
	core.Size = Vector3.new(1, 1, 1)
	core.CFrame = objectCFrame
	core.Parent = objectModel

	buildVoxelSegments(objectModel, objectCFrame, def, stringToSeed(standId))
	buildSign(stand, objectCFrame.Position + Vector3.new(0, def.Size.Y / 2 + 3, 0), def)

	stand:SetAttribute("StandId", standId)
	stand:SetAttribute("ObjectId", objectId)
	stand:SetAttribute("DojoId", dojoId)
	stand:SetAttribute("RequiredPower", def.RequiredPower)
	stand:SetAttribute("Coins", def.Coins)
	stand:SetAttribute("Respawn", def.Respawn or 3)
	stand:SetAttribute("Tier", def.Tier or 1)
	stand:SetAttribute("Float", def.Stand == "Float")
	stand:SetAttribute("Radius", math.max(def.Size.X, def.Size.Z) / 2)
	stand.Parent = parent
	return stand
end

-- Swap the voxel segments for a custom (e.g. Blender) model from ServerStorage/BreakableModels.
function BreakableBuilder.ApplyCustomModel(stand: Model): boolean
	local objectId = stand:GetAttribute("ObjectId")
	local def = type(objectId) == "string" and Config.Breakables[objectId]
	local template = type(objectId) == "string" and getCustomTemplate(objectId)
	local objectModel = stand:FindFirstChild("Object")
	local core = objectModel and objectModel:FindFirstChild("Core")
	if not def or not template or not objectModel or not core or not core:IsA("BasePart") then
		return false
	end

	for _, child in objectModel:GetChildren() do
		if child:IsA("BasePart") and child ~= core then
			child:Destroy()
		end
	end
	buildCustomSegments(objectModel :: Model, core.CFrame, def, template)
	return true
end

-- Weld segments to the Core, tag the stand and describe it for the server. Call once per stand.
function BreakableBuilder.Rig(stand: Model): StandInfo?
	local standId = stand:GetAttribute("StandId")
	local objectId = stand:GetAttribute("ObjectId")
	local dojoId = stand:GetAttribute("DojoId")
	local def = type(objectId) == "string" and Config.Breakables[objectId]
	local objectModel = stand:FindFirstChild("Object")
	local core = objectModel and objectModel:FindFirstChild("Core")

	if type(standId) ~= "string" or type(dojoId) ~= "string" or not def then
		warn(`[BreakableBuilder] {stand:GetFullName()} has missing/invalid attributes`)
		return nil
	end
	if not objectModel or not objectModel:IsA("Model") or not core or not core:IsA("BasePart") then
		warn(`[BreakableBuilder] {stand:GetFullName()} needs Object/Core`)
		return nil
	end

	core.Anchored = true
	objectModel.PrimaryPart = core
	stand.PrimaryPart = core

	for _, child in objectModel:GetChildren() do
		if child:IsA("BasePart") and child ~= core then
			if child:GetAttribute("BaseTransparency") == nil then
				child:SetAttribute("BaseTransparency", child.Transparency)
			end
			local weld = Instance.new("WeldConstraint")
			weld.Name = "Weld_" .. child.Name
			weld.Part0 = core
			weld.Part1 = child
			weld.Parent = core -- kept on the core so cloned debris doesn't carry welds
			child.Massless = true
			child.Anchored = false
		end
	end

	local radius = stand:GetAttribute("Radius")
	stand.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	CollectionService:AddTag(stand, BreakableBuilder.TAG)

	return {
		Id = standId,
		ObjectId = objectId,
		DojoId = dojoId,
		Def = def,
		Model = stand,
		Core = core,
		Position = core.Position,
		Radius = if type(radius) == "number" then radius else math.max(def.Size.X, def.Size.Z) / 2,
	}
end

return BreakableBuilder
