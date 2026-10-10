--[[
	StudSurface.luau
	Gives any BasePart the classic Roblox stud look.

	• If Config.Assets.StudTexture is set, the square-stud Texture is tiled on all six faces
	  (1 stud per tile) so it works on Parts *and* imported MeshParts. Floors can also get the
	  4x4-stud checker (Config.Assets.CheckerTexture) on their top face.
	• Otherwise Parts fall back to the engine's built-in SurfaceType.Studs / Inlet surfaces
	  (classic round studs) until the texture is uploaded.
]]

local Config = require(script.Parent.Config)

local StudSurface = {}

local FACES = Enum.NormalId:GetEnumItems()
local TEXTURE_NAME = "StudTexture"

function StudSurface.HasTexture(): boolean
	return Config.Assets.StudTexture ~= ""
end

export type Options = { Transparency: number?, Color: Color3?, Checker: boolean? }

function StudSurface.Apply(part: BasePart, options: Options?)
	local textureId = Config.Assets.StudTexture

	if options and options.Checker and Config.Assets.CheckerTexture ~= "" then
		local checker = Instance.new("Texture")
		checker.Name = "CheckerTexture"
		checker.Texture = Config.Assets.CheckerTexture
		checker.Face = Enum.NormalId.Top
		checker.StudsPerTileU = Config.Assets.CheckerStudsPerTile
		checker.StudsPerTileV = Config.Assets.CheckerStudsPerTile
		checker.ZIndex = 0
		checker.Parent = part
	end

	if textureId ~= "" then
		if part:IsA("Part") then
			-- Hide the classic round studs under the square-stud overlay.
			part.TopSurface = Enum.SurfaceType.Smooth
			part.BottomSurface = Enum.SurfaceType.Smooth
			part.FrontSurface = Enum.SurfaceType.Smooth
			part.BackSurface = Enum.SurfaceType.Smooth
			part.LeftSurface = Enum.SurfaceType.Smooth
			part.RightSurface = Enum.SurfaceType.Smooth
		end
		for _, face in FACES do
			local texture = Instance.new("Texture")
			texture.Name = TEXTURE_NAME
			texture.Texture = textureId
			texture.Face = face
			texture.StudsPerTileU = 1
			texture.StudsPerTileV = 1
			texture.Transparency = (options and options.Transparency) or Config.Assets.StudPartTransparency
			texture.Color3 = (options and options.Color) or Color3.new(1, 1, 1)
			texture.ZIndex = 1
			texture.Parent = part
		end
	elseif part:IsA("Part") then
		part.TopSurface = Enum.SurfaceType.Studs
		part.BottomSurface = Enum.SurfaceType.Inlet
		part.FrontSurface = Enum.SurfaceType.Studs
		part.BackSurface = Enum.SurfaceType.Studs
		part.LeftSurface = Enum.SurfaceType.Studs
		part.RightSurface = Enum.SurfaceType.Studs
	end
end

-- Convenience constructor used by the world builder and debris FX.
function StudSurface.NewPart(props: { [string]: any }): Part
	local part = Instance.new("Part")
	part.Anchored = true
	part.Material = Enum.Material.Plastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in props do
		if key ~= "Parent" and key ~= "Studs" and key ~= "Checker" then
			(part :: any)[key] = value
		end
	end
	if props.Studs ~= false then
		StudSurface.Apply(part, { Checker = props.Checker })
	end
	if props.Parent then
		part.Parent = props.Parent
	end
	return part
end

return StudSurface
