--[[
	mock_roblox.luau
	Just enough of the Roblox API (datatypes + an instance tree) to run MapBuilder outside of
	Roblox with the plain Luau CLI. tools/mapgen/build_map.py prepends this to a bundle of the
	game's modules, runs MapBuilder.Build and serialises the resulting instance tree to JSON.

	Datatypes carry a `_t` tag so the serializer knows how to encode them.
]]

--------------------------------------------------------------------------------
-- Vector3 / Vector2
--------------------------------------------------------------------------------

local Vector3 = {}
local V3 = {}

local function v3(x: number, y: number, z: number)
	return setmetatable({ _t = "Vector3", X = x, Y = y, Z = z }, V3)
end

V3.__index = function(v, key)
	if key == "Magnitude" then
		return math.sqrt(v.X * v.X + v.Y * v.Y + v.Z * v.Z)
	elseif key == "Unit" then
		local m = math.sqrt(v.X * v.X + v.Y * v.Y + v.Z * v.Z)
		return v3(v.X / m, v.Y / m, v.Z / m)
	elseif key == "Cross" then
		return function(a, b)
			return v3(a.Y * b.Z - a.Z * b.Y, a.Z * b.X - a.X * b.Z, a.X * b.Y - a.Y * b.X)
		end
	elseif key == "Dot" then
		return function(a, b)
			return a.X * b.X + a.Y * b.Y + a.Z * b.Z
		end
	end
	return nil
end
V3.__add = function(a, b)
	return v3(a.X + b.X, a.Y + b.Y, a.Z + b.Z)
end
V3.__sub = function(a, b)
	return v3(a.X - b.X, a.Y - b.Y, a.Z - b.Z)
end
V3.__mul = function(a, b)
	if type(a) == "number" then
		return v3(a * b.X, a * b.Y, a * b.Z)
	elseif type(b) == "number" then
		return v3(a.X * b, a.Y * b, a.Z * b)
	end
	return v3(a.X * b.X, a.Y * b.Y, a.Z * b.Z)
end
V3.__div = function(a, b)
	if type(b) == "number" then
		return v3(a.X / b, a.Y / b, a.Z / b)
	end
	return v3(a.X / b.X, a.Y / b.Y, a.Z / b.Z)
end
V3.__unm = function(a)
	return v3(-a.X, -a.Y, -a.Z)
end
V3.__eq = function(a, b)
	return a.X == b.X and a.Y == b.Y and a.Z == b.Z
end
V3.__tostring = function(v)
	return `{v.X}, {v.Y}, {v.Z}`
end

function Vector3.new(x: number?, y: number?, z: number?)
	return v3(x or 0, y or 0, z or 0)
end
Vector3.zero = v3(0, 0, 0)
Vector3.one = v3(1, 1, 1)
Vector3.xAxis = v3(1, 0, 0)
Vector3.yAxis = v3(0, 1, 0)
Vector3.zAxis = v3(0, 0, 1)

local Vector2 = {}
function Vector2.new(x: number?, y: number?)
	return { _t = "Vector2", X = x or 0, Y = y or 0 }
end
Vector2.zero = Vector2.new(0, 0)

--------------------------------------------------------------------------------
-- CFrame (row-major rotation + position)
--------------------------------------------------------------------------------

local CFrame = {}
local CF = {}

local function cf(x, y, z, m)
	return setmetatable({ _t = "CFrame", _x = x, _y = y, _z = z, _m = m }, CF)
end

local IDENTITY = { 1, 0, 0, 0, 1, 0, 0, 0, 1 }

local function matmul(a, b)
	local r = {}
	for row = 0, 2 do
		for col = 0, 2 do
			local sum = 0
			for k = 0, 2 do
				sum += a[row * 3 + k + 1] * b[k * 3 + col + 1]
			end
			r[row * 3 + col + 1] = sum
		end
	end
	return r
end

local function rotate(m, x, y, z)
	return m[1] * x + m[2] * y + m[3] * z, m[4] * x + m[5] * y + m[6] * z, m[7] * x + m[8] * y + m[9] * z
end

CF.__index = function(c, key)
	if key == "Position" or key == "p" then
		return v3(c._x, c._y, c._z)
	elseif key == "X" then
		return c._x
	elseif key == "Y" then
		return c._y
	elseif key == "Z" then
		return c._z
	elseif key == "LookVector" then
		return v3(-c._m[3], -c._m[6], -c._m[9])
	elseif key == "RightVector" then
		return v3(c._m[1], c._m[4], c._m[7])
	elseif key == "UpVector" then
		return v3(c._m[2], c._m[5], c._m[8])
	elseif key == "Rotation" then
		return cf(0, 0, 0, c._m)
	elseif key == "Inverse" then
		return function(self)
			local m = self._m
			local t = { m[1], m[4], m[7], m[2], m[5], m[8], m[3], m[6], m[9] }
			local x, y, z = rotate(t, self._x, self._y, self._z)
			return cf(-x, -y, -z, t)
		end
	elseif key == "GetComponents" then
		return function(self)
			local m = self._m
			return self._x, self._y, self._z, m[1], m[2], m[3], m[4], m[5], m[6], m[7], m[8], m[9]
		end
	end
	return nil
end
CF.__mul = function(a, b)
	if getmetatable(b) == CF then
		local x, y, z = rotate(a._m, b._x, b._y, b._z)
		return cf(a._x + x, a._y + y, a._z + z, matmul(a._m, b._m))
	end
	local x, y, z = rotate(a._m, b.X, b.Y, b.Z)
	return v3(a._x + x, a._y + y, a._z + z)
end
CF.__add = function(a, v)
	return cf(a._x + v.X, a._y + v.Y, a._z + v.Z, a._m)
end
CF.__sub = function(a, v)
	return cf(a._x - v.X, a._y - v.Y, a._z - v.Z, a._m)
end

function CFrame.new(a, b, c, ...)
	if a == nil then
		return cf(0, 0, 0, IDENTITY)
	elseif type(a) == "table" then
		return cf(a.X, a.Y, a.Z, IDENTITY)
	end
	local rest = { ... }
	if #rest == 9 then
		return cf(a, b, c, rest)
	end
	return cf(a, b, c, IDENTITY)
end

function CFrame.Angles(rx: number, ry: number, rz: number)
	local cx, sx = math.cos(rx), math.sin(rx)
	local cy, sy = math.cos(ry), math.sin(ry)
	local cz, sz = math.cos(rz), math.sin(rz)
	local mx = { 1, 0, 0, 0, cx, -sx, 0, sx, cx }
	local my = { cy, 0, sy, 0, 1, 0, -sy, 0, cy }
	local mz = { cz, -sz, 0, sz, cz, 0, 0, 0, 1 }
	return cf(0, 0, 0, matmul(matmul(mx, my), mz))
end
CFrame.fromEulerAnglesXYZ = CFrame.Angles

function CFrame.lookAt(at, target, up)
	up = up or Vector3.yAxis
	local forward = (target - at).Unit
	local right = forward:Cross(up).Unit
	local upVector = right:Cross(forward)
	return cf(at.X, at.Y, at.Z, {
		right.X,
		upVector.X,
		-forward.X,
		right.Y,
		upVector.Y,
		-forward.Y,
		right.Z,
		upVector.Z,
		-forward.Z,
	})
end

--------------------------------------------------------------------------------
-- Other datatypes
--------------------------------------------------------------------------------

local Color3 = {}
function Color3.new(r: number?, g: number?, b: number?)
	return { _t = "Color3", R = r or 0, G = g or 0, B = b or 0 }
end
function Color3.fromRGB(r: number?, g: number?, b: number?)
	return Color3.new((r or 0) / 255, (g or 0) / 255, (b or 0) / 255)
end

local UDim = {}
function UDim.new(scale: number?, offset: number?)
	return { _t = "UDim", Scale = scale or 0, Offset = offset or 0 }
end

local UDim2 = {}
local UD2 = {}
local function udim2(xs, xo, ys, yo)
	return setmetatable({ _t = "UDim2", X = UDim.new(xs, xo), Y = UDim.new(ys, yo) }, UD2)
end
UD2.__add = function(a, b)
	return udim2(a.X.Scale + b.X.Scale, a.X.Offset + b.X.Offset, a.Y.Scale + b.Y.Scale, a.Y.Offset + b.Y.Offset)
end
function UDim2.new(xs, xo, ys, yo)
	return udim2(xs or 0, xo or 0, ys or 0, yo or 0)
end
function UDim2.fromScale(x, y)
	return udim2(x, 0, y, 0)
end
function UDim2.fromOffset(x, y)
	return udim2(0, x, 0, y)
end

local NumberRange = {}
function NumberRange.new(min: number, max: number?)
	return { _t = "NumberRange", Min = min, Max = max or min }
end

local NumberSequenceKeypoint = {}
function NumberSequenceKeypoint.new(time: number, value: number, envelope: number?)
	return { Time = time, Value = value, Envelope = envelope or 0 }
end
local NumberSequence = {}
function NumberSequence.new(a, b)
	if type(a) == "table" then
		return { _t = "NumberSequence", Keypoints = a }
	end
	return {
		_t = "NumberSequence",
		Keypoints = { NumberSequenceKeypoint.new(0, a), NumberSequenceKeypoint.new(1, b or a) },
	}
end

local ColorSequenceKeypoint = {}
function ColorSequenceKeypoint.new(time: number, color)
	return { Time = time, Value = color }
end
local ColorSequence = {}
function ColorSequence.new(a, b)
	if a._t == nil then
		return { _t = "ColorSequence", Keypoints = a }
	end
	return {
		_t = "ColorSequence",
		Keypoints = { ColorSequenceKeypoint.new(0, a), ColorSequenceKeypoint.new(1, b or a) },
	}
end

local enumCache = {}
local ENUM_ITEMS = {
	NormalId = { "Right", "Top", "Back", "Left", "Bottom", "Front" },
}
local Enum = setmetatable({}, {
	__index = function(_, enumType: string)
		local items = enumCache[enumType]
		if not items then
			items = setmetatable({}, {
				__index = function(t, name: string)
					if name == "GetEnumItems" then
						return function()
							local list = {}
							for _, itemName in ENUM_ITEMS[enumType] or {} do
								table.insert(list, t[itemName])
							end
							return list
						end
					end
					local item = { _t = "EnumItem", EnumType = enumType, Name = name }
					rawset(t, name, item)
					return item
				end,
			})
			enumCache[enumType] = items
		end
		return items
	end,
})

local Random = {}
Random.__index = Random
function Random.new(seed: number?)
	return setmetatable({ _state = math.floor(seed or 1) % 2147483646 + 1 }, Random)
end
function Random:_next(): number
	self._state = (self._state * 48271) % 2147483647
	return self._state / 2147483647
end
function Random:NextNumber(min: number?, max: number?): number
	local lo, hi = min or 0, max or 1
	return lo + (hi - lo) * self:_next()
end
function Random:NextInteger(min: number, max: number): number
	return min + math.floor(self:_next() * (max - min + 1))
end

--------------------------------------------------------------------------------
-- Instances
--------------------------------------------------------------------------------

local CLASS_PARENT = {
	Part = "FormFactorPart",
	FormFactorPart = "BasePart",
	SpawnLocation = "Part",
	WedgePart = "FormFactorPart",
	MeshPart = "TriangleMeshPart",
	TriangleMeshPart = "BasePart",
	BasePart = "PVInstance",
	Model = "PVInstance",
	PVInstance = "Instance",
	Folder = "Instance",
	TextLabel = "GuiObject",
	Frame = "GuiObject",
	GuiObject = "GuiBase2d",
	BillboardGui = "LayerCollector",
	SurfaceGui = "LayerCollector",
	LayerCollector = "GuiBase2d",
	GuiBase2d = "Instance",
	Texture = "Decal",
	Decal = "FaceInstance",
	FaceInstance = "Instance",
	PointLight = "Light",
	Light = "Instance",
	ParticleEmitter = "Instance",
	UIStroke = "Instance",
	UIListLayout = "Instance",
	UICorner = "Instance",
	Attachment = "Instance",
	ModuleScript = "Instance",
}

local DEFAULTS = {
	Transparency = 0,
	Anchored = false,
	TopSurface = Enum.SurfaceType.Smooth,
	BottomSurface = Enum.SurfaceType.Smooth,
}

local Instance = {}
local Methods = {}
local IM = {}

local function isBasePart(inst)
	local class = inst._class
	while class do
		if class == "BasePart" then
			return true
		end
		class = CLASS_PARENT[class]
	end
	return false
end

IM.__index = function(self, key)
	local method = Methods[key]
	if method then
		return method
	end
	if key == "ClassName" then
		return self._class
	elseif key == "Name" then
		return self._props.Name or self._class
	elseif key == "Parent" then
		return rawget(self, "_parent")
	elseif key == "CFrame" then
		return self._props.CFrame or CFrame.new()
	elseif key == "Position" and isBasePart(self) then
		return self.CFrame.Position
	end
	local value = self._props[key]
	if value ~= nil then
		return value
	end
	for _, child in self._children do
		if child.Name == key then
			return child
		end
	end
	return DEFAULTS[key]
end

IM.__newindex = function(self, key, value)
	if key == "Parent" then
		local oldParent = rawget(self, "_parent")
		if oldParent then
			local siblings = oldParent._children
			local index = table.find(siblings, self)
			if index then
				table.remove(siblings, index)
			end
		end
		rawset(self, "_parent", value)
		if value then
			table.insert(value._children, self)
		end
	elseif key == "Position" and isBasePart(self) then
		local current = self.CFrame
		self._props.CFrame = CFrame.new(value) * current.Rotation
	else
		self._props[key] = value
	end
end

function Instance.new(className: string)
	local inst = {
		_class = className,
		_props = {},
		_children = {},
		_attrs = {},
		_attrOrder = {},
		_tags = {},
	}
	return setmetatable(inst, IM)
end

function Methods.IsA(self, className: string): boolean
	local class = self._class
	while class do
		if class == className then
			return true
		end
		class = CLASS_PARENT[class]
	end
	return className == "Instance"
end

function Methods.GetChildren(self)
	return table.clone(self._children)
end

function Methods.GetDescendants(self)
	local out = {}
	local function walk(inst)
		for _, child in inst._children do
			table.insert(out, child)
			walk(child)
		end
	end
	walk(self)
	return out
end

function Methods.FindFirstChild(self, name: string, recursive: boolean?)
	for _, child in self._children do
		if child.Name == name then
			return child
		end
	end
	if recursive then
		for _, child in self._children do
			local found = child:FindFirstChild(name, true)
			if found then
				return found
			end
		end
	end
	return nil
end

function Methods.WaitForChild(self, name: string)
	return assert(self:FindFirstChild(name), "WaitForChild: no child named " .. name)
end

function Methods.FindFirstChildOfClass(self, className: string)
	for _, child in self._children do
		if child._class == className then
			return child
		end
	end
	return nil
end

function Methods.GetPivot(self)
	local primary = self._props.PrimaryPart
	if primary then
		return primary.CFrame
	end
	if isBasePart(self) then
		return self.CFrame
	end
	return CFrame.new()
end

function Methods.PivotTo(self, target)
	local delta = target * self:GetPivot():Inverse()
	if isBasePart(self) then
		self.CFrame = delta * self.CFrame
	end
	for _, descendant in self:GetDescendants() do
		if isBasePart(descendant) then
			descendant.CFrame = delta * descendant.CFrame
		end
	end
end

function Methods.SetAttribute(self, name: string, value: any)
	if self._attrs[name] == nil then
		table.insert(self._attrOrder, name)
	end
	self._attrs[name] = value
end

function Methods.GetAttribute(self, name: string)
	return self._attrs[name]
end

function Methods.Destroy(self)
	self.Parent = nil
end

function Methods.ClearAllChildren(self)
	for _, child in table.clone(self._children) do
		child.Parent = nil
	end
end

function Methods.GetFullName(self)
	local names = {}
	local inst = self
	while inst do
		table.insert(names, 1, inst.Name)
		inst = rawget(inst, "_parent")
	end
	return table.concat(names, ".")
end

--------------------------------------------------------------------------------
-- Services, game, require
--------------------------------------------------------------------------------

local services = {}
local game = Instance.new("DataModel")

local function service(name: string)
	local svc = services[name]
	if not svc then
		svc = Instance.new(name)
		svc.Name = name
		svc.Parent = game
		services[name] = svc
	end
	return svc
end

function Methods.GetService(_self, name: string)
	return service(name)
end

local CollectionServiceMock = service("CollectionService")
function Methods.AddTag(_self, inst, tag: string)
	if not table.find(inst._tags, tag) then
		table.insert(inst._tags, tag)
	end
end
local _ = CollectionServiceMock

local workspace = service("Workspace")

local moduleLoaders = {}
local moduleCache = {}

-- path like "ReplicatedStorage/Shared/Config"
local function defineModule(path: string, loader)
	local parts = string.split(path, "/")
	local current = service(parts[1])
	for index = 2, #parts do
		local name = parts[index]
		local child = current:FindFirstChild(name)
		if not child then
			child = Instance.new(if index == #parts then "ModuleScript" else "Folder")
			child.Name = name
			child.Parent = current
		end
		current = child
	end
	moduleLoaders[current] = loader
end

local function require(moduleScript)
	local cached = moduleCache[moduleScript]
	if cached == nil then
		local loader = assert(
			moduleLoaders[moduleScript],
			"require: not a module " .. tostring(moduleScript and moduleScript.Name)
		)
		cached = loader(moduleScript)
		moduleCache[moduleScript] = cached
	end
	return cached
end

--------------------------------------------------------------------------------
-- Serialisation (instance tree → JSON)
--------------------------------------------------------------------------------

local function jsonString(s: string): string
	s = string.gsub(s, '[%c"\\]', function(c)
		local map = { ['"'] = '\\"', ["\\"] = "\\\\", ["\n"] = "\\n", ["\r"] = "\\r", ["\t"] = "\\t" }
		return map[c] or string.format("\\u%04x", string.byte(c))
	end)
	return '"' .. s .. '"'
end

local function jsonNumber(n: number): string
	if n ~= n or n == math.huge or n == -math.huge then
		error("cannot encode non-finite number")
	end
	if n == math.floor(n) and math.abs(n) < 1e15 then
		return string.format("%d", n)
	end
	return string.format("%.6g", n)
end

local encodeValue

local function encodeArray(list): string
	local out = {}
	for _, item in list do
		table.insert(out, encodeValue(item))
	end
	return "[" .. table.concat(out, ",") .. "]"
end

function encodeValue(value): string
	local kind = type(value)
	if kind == "string" then
		return jsonString(value)
	elseif kind == "number" then
		return jsonNumber(value)
	elseif kind == "boolean" then
		return tostring(value)
	elseif kind ~= "table" then
		error("cannot encode " .. kind)
	end

	local t = value._t
	if t == "Vector3" then
		return `\{"$t":"Vector3","v":[{jsonNumber(value.X)},{jsonNumber(value.Y)},{jsonNumber(value.Z)}]}`
	elseif t == "Vector2" then
		return `\{"$t":"Vector2","v":[{jsonNumber(value.X)},{jsonNumber(value.Y)}]}`
	elseif t == "CFrame" then
		local c = { value:GetComponents() }
		return `\{"$t":"CFrame","v":{encodeArray(c)}}`
	elseif t == "Color3" then
		return `\{"$t":"Color3","v":[{jsonNumber(value.R)},{jsonNumber(value.G)},{jsonNumber(value.B)}]}`
	elseif t == "UDim" then
		return `\{"$t":"UDim","v":[{jsonNumber(value.Scale)},{jsonNumber(value.Offset)}]}`
	elseif t == "UDim2" then
		return `\{"$t":"UDim2","v":[{jsonNumber(value.X.Scale)},{jsonNumber(value.X.Offset)},{jsonNumber(value.Y.Scale)},{jsonNumber(
			value.Y.Offset
		)}]}`
	elseif t == "NumberRange" then
		return `\{"$t":"NumberRange","v":[{jsonNumber(value.Min)},{jsonNumber(value.Max)}]}`
	elseif t == "NumberSequence" then
		local points = {}
		for _, k in value.Keypoints do
			table.insert(points, `[{jsonNumber(k.Time)},{jsonNumber(k.Value)},{jsonNumber(k.Envelope)}]`)
		end
		return `\{"$t":"NumberSequence","v":[{table.concat(points, ",")}]}`
	elseif t == "ColorSequence" then
		local points = {}
		for _, k in value.Keypoints do
			local c = k.Value
			table.insert(points, `[{jsonNumber(k.Time)},{jsonNumber(c.R)},{jsonNumber(c.G)},{jsonNumber(c.B)}]`)
		end
		return `\{"$t":"ColorSequence","v":[{table.concat(points, ",")}]}`
	elseif t == "EnumItem" then
		return `\{"$t":"Enum","v":{jsonString(value.Name)}}`
	elseif value._class then
		error("Ref properties are not supported in baked maps (" .. value._class .. ")")
	end
	return encodeArray(value)
end

local function serialize(inst): string
	local props = {}
	local keys = {}
	for key, value in inst._props do
		local isRef = type(value) == "table" and rawget(value, "_class") ~= nil
		if key ~= "Name" and not isRef then
			table.insert(keys, key)
		end
	end
	table.sort(keys)
	for _, key in keys do
		table.insert(props, jsonString(key) .. ":" .. encodeValue(inst._props[key]))
	end

	local attrs = {}
	for _, name in inst._attrOrder do
		table.insert(attrs, jsonString(name) .. ":" .. encodeValue(inst._attrs[name]))
	end

	local children = {}
	for _, child in inst._children do
		table.insert(children, serialize(child))
	end

	return string.format(
		'{"ClassName":%s,"Name":%s,"Properties":{%s},"Attributes":{%s},"Tags":%s,"Children":[%s]}',
		jsonString(inst._class),
		jsonString(inst.Name),
		table.concat(props, ","),
		table.concat(attrs, ","),
		encodeArray(inst._tags),
		table.concat(children, ",")
	)
end
