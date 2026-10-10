--[[
	Shapes.luau
	Pure voxel shape functions used to pre-fracture breakable objects into stud segments.

	Each shape receives the centre of one grid cell (x, y, z, in studs, relative to the object
	centre) and the half-extents of the object's bounding box (hx, hy, hz). It returns the
	segment category ("Base", "Alt", "Accent") or nil when the cell is empty.

	Objects face -Z (towards the players), +Y is up.
	No Roblox APIs are used here so the module can be unit tested with the plain Luau CLI.
]]

export type ShapeFn = (x: number, y: number, z: number, hx: number, hy: number, hz: number) -> string?

local Shapes: { [string]: ShapeFn } = {}

Shapes.Box = function()
	return "Base"
end

-- Classic blacksmith anvil: wide foot, narrow waist, flat face and a tapering horn on +X.
Shapes.Anvil = function(x, y, z, hx, hy, hz)
	local u, v, w = x / hx, y / hy, z / hz
	if v < -0.6 then
		return if math.abs(u) <= 0.75 then "Base" else nil
	elseif v < 0.1 then
		return if math.abs(u) <= 0.4 and math.abs(w) <= 0.6 then "Base" else nil
	end
	if u <= 0.5 then
		return if v > 0.6 then "Accent" else "Base"
	end
	-- Horn: thinner the further out it reaches.
	local hornReach = (u - 0.5) / 0.5 -- 0..1
	if v >= 0.2 + hornReach * 0.6 and math.abs(w) <= 1 - hornReach * 0.5 then
		return if v > 0.6 then "Accent" else "Base"
	end
	return nil
end

-- Round shaft with square gold caps.
Shapes.Pillar = function(x, y, z, hx, hy, hz)
	local v = y / hy
	if math.abs(v) > 0.72 then
		return "Accent"
	end
	local u, w = x / hx, z / hz
	return if u * u + w * w <= 1 then "Base" else nil
end

-- Steel I-beam lying along X: two flanges joined by a web.
Shapes.IBeam = function(_x, y, z, _hx, hy, hz)
	local v, w = y / hy, z / hz
	if math.abs(v) > 0.6 or math.abs(w) < 0.34 then
		return "Base"
	end
	return nil
end

-- Server rack: solid box with glowing status strips on the front face.
Shapes.Rack = function(_x, y, z, _hx, hy, _hz)
	local v = y / hy
	if z < 0 and math.floor((v + 1) * 3) % 2 == 0 then
		return "Accent"
	end
	return "Base"
end

-- Elongated double pyramid.
Shapes.Crystal = function(x, y, z, hx, hy, hz)
	local u, v, w = x / hx, y / hy, z / hz
	local radius = math.sqrt(u * u + w * w)
	if radius <= (1 - math.abs(v)) * 1.25 + 0.1 then
		return "Base"
	end
	return nil
end

local function sphere(
	x: number,
	y: number,
	z: number,
	hx: number,
	hy: number,
	hz: number
): (boolean, number, number, number)
	local u, v, w = x / hx, y / hy, z / hz
	return u * u + v * v + w * w <= 1, u, v, w
end

-- Armoured reactor sphere with a glowing equator band.
Shapes.MechCore = function(x, y, z, hx, hy, hz)
	local inside, _, v = sphere(x, y, z, hx, hy, hz)
	if not inside then
		return nil
	end
	return if math.abs(v) < 0.2 then "Accent" else "Base"
end

-- Lumpy space rock with molten veins.
Shapes.Meteorite = function(x, y, z, hx, hy, hz)
	local u, v, w = x / hx, y / hy, z / hz
	local n = math.noise(u * 1.7 + 0.37, v * 1.7 + 0.11, w * 1.7 + 0.73)
	if math.sqrt(u * u + v * v + w * w) > 0.9 + n * 0.35 then
		return nil
	end
	return if n > 0.12 then "Accent" else "Base"
end

-- Grey moon with darker craters.
Shapes.Moon = function(x, y, z, hx, hy, hz)
	local inside, u, v, w = sphere(x, y, z, hx, hy, hz)
	if not inside then
		return nil
	end
	return if math.noise(u * 2.3 + 0.5, v * 2.3 + 10.2, w * 2.3 + 0.9) > 0.15 then "Accent" else "Base"
end

-- Ringed planet: ocean ("Base"), continents ("Alt"), ring ("Accent").
-- The sphere radius is hy so the ring can extend out to hx/hz.
Shapes.Planet = function(x, y, z, hx, hy, hz)
	local radius = hy
	local distance = math.sqrt(x * x + y * y + z * z)
	if distance <= radius then
		local n = math.noise(x / radius * 1.6 + 3.1, y / radius * 1.6 + 0.4, z / radius * 1.6 + 7.7)
		return if n > 0.05 then "Alt" else "Base"
	end
	local ringRadius = math.sqrt((x / hx) ^ 2 + (z / hz) ^ 2)
	if math.abs(y) < hy * 0.15 and ringRadius >= 0.62 and ringRadius <= 1 then
		return "Accent"
	end
	return nil
end

return Shapes
