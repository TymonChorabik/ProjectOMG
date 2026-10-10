--[[
	BreakableLayout.luau
	Turns a breakable definition into a list of pre-fractured segments (pure math, no instances).

	The bounding box is divided into a Grid of cells; each cell the shape keeps becomes one
	stud-textured segment. With `hollow`, cells completely enclosed by other cells are dropped:
	they can never be seen while the object is intact and only cost parts.
]]

local Shapes = require(script.Parent.Shapes)

export type Cell = {
	X: number,
	Y: number,
	Z: number,
	SizeX: number,
	SizeY: number,
	SizeZ: number,
	Category: string,
	Index: number,
}

local BreakableLayout = {}

function BreakableLayout.Compute(
	shapeName: string,
	sizeX: number,
	sizeY: number,
	sizeZ: number,
	gridX: number,
	gridY: number,
	gridZ: number,
	hollow: boolean?
): { Cell }
	local shape = Shapes[shapeName]
	assert(shape, `Unknown breakable shape "{shapeName}"`)

	local hx, hy, hz = sizeX / 2, sizeY / 2, sizeZ / 2
	local cx, cy, cz = sizeX / gridX, sizeY / gridY, sizeZ / gridZ

	-- First pass: occupancy grid.
	local occupied: { [number]: string } = {}
	local function key(i: number, j: number, k: number): number
		return (i * (gridY + 2) + j) * (gridZ + 2) + k
	end

	for i = 1, gridX do
		for j = 1, gridY do
			for k = 1, gridZ do
				local x = -hx + (i - 0.5) * cx
				local y = -hy + (j - 0.5) * cy
				local z = -hz + (k - 0.5) * cz
				local category = shape(x, y, z, hx, hy, hz)
				if category then
					occupied[key(i, j, k)] = category
				end
			end
		end
	end

	-- Second pass: emit cells, optionally skipping fully enclosed ones.
	local cells: { Cell } = {}
	for i = 1, gridX do
		for j = 1, gridY do
			for k = 1, gridZ do
				local category = occupied[key(i, j, k)]
				if category then
					local enclosed = hollow
						and occupied[key(i - 1, j, k)] ~= nil
						and occupied[key(i + 1, j, k)] ~= nil
						and occupied[key(i, j - 1, k)] ~= nil
						and occupied[key(i, j + 1, k)] ~= nil
						and occupied[key(i, j, k - 1)] ~= nil
						and occupied[key(i, j, k + 1)] ~= nil
					if not enclosed then
						table.insert(cells, {
							X = -hx + (i - 0.5) * cx,
							Y = -hy + (j - 0.5) * cy,
							Z = -hz + (k - 0.5) * cz,
							SizeX = cx,
							SizeY = cy,
							SizeZ = cz,
							Category = category,
							Index = #cells + 1,
						})
					end
				end
			end
		end
	end

	return cells
end

return BreakableLayout
