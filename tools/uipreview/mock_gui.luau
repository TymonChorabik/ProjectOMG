--[[
	mock_gui.luau
	GUI additions to tools/mapgen/mock_roblox.luau so the client UI modules (Hud, MenuWindow,
	menus, popups...) can run in the plain Luau CLI. tools/uipreview/render_ui.py bundles
	mock_roblox + this file + the UI modules + a scene driver, serialises PlayerGui to JSON and
	draws it.

	Time is frozen: task.spawn/defer run immediately, task.delay never fires, task.wait parks the
	calling coroutine forever, and tweens jump straight to their goal.
]]

for class, parent in
	{
		ScreenGui = "LayerCollector",
		PlayerGui = "Instance",
		Player = "Instance",
		GuiButton = "GuiObject",
		TextButton = "GuiButton",
		ImageButton = "GuiButton",
		ImageLabel = "GuiObject",
		ViewportFrame = "GuiObject",
		ScrollingFrame = "GuiObject",
		CanvasGroup = "GuiObject",
		TextBox = "GuiObject",
		Camera = "Instance",
		UIComponent = "Instance",
		UIConstraint = "UIComponent",
		UILayout = "UIComponent",
		UIGridStyleLayout = "UILayout",
		UIListLayout = "UIGridStyleLayout",
		UIGridLayout = "UIGridStyleLayout",
		UIScale = "UIComponent",
		UIPadding = "UIComponent",
		UIGradient = "UIComponent",
		UICorner = "UIComponent",
		UIStroke = "UIComponent",
		UITextSizeConstraint = "UIConstraint",
		UIAspectRatioConstraint = "UIConstraint",
		UISizeConstraint = "UIConstraint",
		Sound = "Instance",
		WorldModel = "Model",
	}
do
	CLASS_PARENT[class] = parent
end

--------------------------------------------------------------------------------
-- Richer datatypes
--------------------------------------------------------------------------------

local C3 = {}
C3.__index = {
	ToHSV = function(c)
		local r, g, b = c.R, c.G, c.B
		local max, min = math.max(r, g, b), math.min(r, g, b)
		local d = max - min
		local h = 0
		if d > 0 then
			if max == r then
				h = ((g - b) / d) % 6
			elseif max == g then
				h = (b - r) / d + 2
			else
				h = (r - g) / d + 4
			end
			h /= 6
		end
		return h, if max == 0 then 0 else d / max, max
	end,
	Lerp = function(a, b, t)
		return Color3.new(a.R + (b.R - a.R) * t, a.G + (b.G - a.G) * t, a.B + (b.B - a.B) * t)
	end,
	ToHex = function(c)
		return string.format("%02x%02x%02x", c.R * 255, c.G * 255, c.B * 255)
	end,
}
C3.__eq = function(a, b)
	return a.R == b.R and a.G == b.G and a.B == b.B
end
function Color3.new(r: number?, g: number?, b: number?)
	return setmetatable({ _t = "Color3", R = r or 0, G = g or 0, B = b or 0 }, C3)
end
function Color3.fromHSV(h: number, s: number, v: number)
	local i = math.floor(h * 6)
	local f = h * 6 - i
	local p, q, t = v * (1 - s), v * (1 - f * s), v * (1 - (1 - f) * s)
	i %= 6
	if i == 0 then
		return Color3.new(v, t, p)
	elseif i == 1 then
		return Color3.new(q, v, p)
	elseif i == 2 then
		return Color3.new(p, v, t)
	elseif i == 3 then
		return Color3.new(p, q, v)
	elseif i == 4 then
		return Color3.new(t, p, v)
	end
	return Color3.new(v, p, q)
end
function Color3.fromHex(hex: string)
	hex = string.gsub(hex, "#", "")
	return Color3.fromRGB(tonumber(hex:sub(1, 2), 16), tonumber(hex:sub(3, 4), 16), tonumber(hex:sub(5, 6), 16))
end

local V2 = {}
local function v2(x, y)
	return setmetatable({ _t = "Vector2", X = x, Y = y }, V2)
end
V2.__index = function(v, key)
	if key == "Magnitude" then
		return math.sqrt(v.X * v.X + v.Y * v.Y)
	elseif key == "Unit" then
		local m = math.sqrt(v.X * v.X + v.Y * v.Y)
		return v2(v.X / m, v.Y / m)
	elseif key == "Lerp" then
		return function(a, b, t)
			return v2(a.X + (b.X - a.X) * t, a.Y + (b.Y - a.Y) * t)
		end
	end
	return nil
end
V2.__add = function(a, b)
	return v2(a.X + b.X, a.Y + b.Y)
end
V2.__sub = function(a, b)
	return v2(a.X - b.X, a.Y - b.Y)
end
V2.__mul = function(a, b)
	if type(a) == "number" then
		return v2(a * b.X, a * b.Y)
	elseif type(b) == "number" then
		return v2(a.X * b, a.Y * b)
	end
	return v2(a.X * b.X, a.Y * b.Y)
end
V2.__div = function(a, b)
	if type(b) == "number" then
		return v2(a.X / b, a.Y / b)
	end
	return v2(a.X / b.X, a.Y / b.Y)
end
function Vector2.new(x: number?, y: number?)
	return v2(x or 0, y or 0)
end
Vector2.zero = v2(0, 0)
Vector2.one = v2(1, 1)
Vector2.xAxis = v2(1, 0)
Vector2.yAxis = v2(0, 1)

UD2.__sub = function(a, b)
	return UDim2.new(a.X.Scale - b.X.Scale, a.X.Offset - b.X.Offset, a.Y.Scale - b.Y.Scale, a.Y.Offset - b.Y.Offset)
end
UD2.__index = {
	Lerp = function(a, b, t)
		return UDim2.new(
			a.X.Scale + (b.X.Scale - a.X.Scale) * t,
			a.X.Offset + (b.X.Offset - a.X.Offset) * t,
			a.Y.Scale + (b.Y.Scale - a.Y.Scale) * t,
			a.Y.Offset + (b.Y.Offset - a.Y.Offset) * t
		)
	end,
}

local TweenInfo = {}
function TweenInfo.new(...)
	return { _t = "TweenInfo", Time = select(1, ...) or 1 }
end

--------------------------------------------------------------------------------
-- Signals, events, task
--------------------------------------------------------------------------------

local MockSignal = {}
MockSignal.__index = MockSignal
local function newSignal()
	return setmetatable({}, MockSignal)
end
function MockSignal:Connect(_handler)
	local connection = { Connected = true }
	function connection.Disconnect(conn)
		conn.Connected = false
	end
	return connection
end
MockSignal.Once = MockSignal.Connect
function MockSignal:Wait()
	return nil
end

local EVENTS = {
	Activated = true,
	MouseEnter = true,
	MouseLeave = true,
	MouseButton1Down = true,
	MouseButton1Up = true,
	MouseButton1Click = true,
	InputBegan = true,
	InputEnded = true,
	InputChanged = true,
	Changed = true,
	ChildAdded = true,
	ChildRemoved = true,
	DescendantAdded = true,
	Destroying = true,
	AncestryChanged = true,
	Triggered = true,
	Completed = true,
	Ended = true,
	Heartbeat = true,
	RenderStepped = true,
	Stepped = true,
	PlayerAdded = true,
	PlayerRemoving = true,
	CharacterAdded = true,
	CharacterRemoving = true,
	OnClientEvent = true,
	TouchTap = true,
}

local GUI_DEFAULTS = {
	Visible = true,
	Enabled = true,
	Text = "",
	ZIndex = 1,
	LayoutOrder = 0,
	Rotation = 0,
	BackgroundTransparency = 0,
	TextTransparency = 0,
	AbsoluteSize = Vector2.new(0, 0),
	AbsolutePosition = Vector2.new(0, 0),
	Size = UDim2.new(0, 100, 0, 100),
	Position = UDim2.new(),
	AnchorPoint = Vector2.new(0, 0),
	Scale = 1,
}

local baseIndex = IM.__index
IM.__index = function(self, key)
	local own = rawget(self, "_methods")
	if own and own[key] then
		return own[key]
	end
	local value = baseIndex(self, key)
	if value ~= nil then
		return value
	end
	if EVENTS[key] then
		local signals = rawget(self, "_signals")
		if not signals then
			signals = {}
			rawset(self, "_signals", signals)
		end
		signals[key] = signals[key] or newSignal()
		return signals[key]
	end
	return GUI_DEFAULTS[key]
end

-- Property-changed signals really fire (synchronously) so menus refresh when opened.
local FiringSignal = {}
FiringSignal.__index = FiringSignal
function FiringSignal:Connect(handler)
	table.insert(self._handlers, handler)
	local connection = { Connected = true }
	function connection.Disconnect(conn)
		conn.Connected = false
		local index = table.find(self._handlers, handler)
		if index then
			table.remove(self._handlers, index)
		end
	end
	return connection
end
FiringSignal.Once = FiringSignal.Connect
function FiringSignal:Wait()
	return nil
end

function Methods.GetPropertyChangedSignal(self, name)
	local signals = rawget(self, "_propSignals")
	if not signals then
		signals = {}
		rawset(self, "_propSignals", signals)
	end
	signals[name] = signals[name] or setmetatable({ _handlers = {} }, FiringSignal)
	return signals[name]
end

local baseNewIndex = IM.__newindex
IM.__newindex = function(self, key, value)
	local old = self._props[key]
	baseNewIndex(self, key, value)
	local signals = rawget(self, "_propSignals")
	local signal = signals and signals[key]
	if signal and old ~= value then
		for _, handler in table.clone(signal._handlers) do
			local ok, err = coroutine.resume(coroutine.create(handler))
			if not ok then
				error(err, 0)
			end
		end
	end
end
function Methods.GetAttributeChangedSignal(_self, _name)
	return newSignal()
end
function Methods.IsDescendantOf(self, ancestor)
	local current = rawget(self, "_parent")
	while current do
		if current == ancestor then
			return true
		end
		current = rawget(current, "_parent")
	end
	return false
end
function Methods.FindFirstAncestorOfClass(self, className)
	local current = rawget(self, "_parent")
	while current do
		if current._class == className then
			return current
		end
		current = rawget(current, "_parent")
	end
	return nil
end
function Methods.FindFirstChildWhichIsA(self, className)
	for _, child in self._children do
		if child:IsA(className) then
			return child
		end
	end
	return nil
end
function Methods.Clone(self)
	local copy = Instance.new(self._class)
	for key, value in self._props do
		copy._props[key] = value
	end
	for _, child in self._children do
		child:Clone().Parent = copy
	end
	return copy
end

-- Parked coroutines (task.wait) never resume: the preview is a single frozen frame.
local task = {}
function task.spawn(fn, ...)
	local thread = if type(fn) == "thread" then fn else coroutine.create(fn)
	local ok, err = coroutine.resume(thread, ...)
	if not ok then
		error(err, 0)
	end
	return thread
end
task.defer = task.spawn
function task.delay(_seconds, _fn, ...)
	return nil
end
function task.wait(_seconds)
	if coroutine.isyieldable() then
		coroutine.yield()
	end
	return 0
end
function task.cancel(_thread) end

--------------------------------------------------------------------------------
-- Services
--------------------------------------------------------------------------------

local function withMethods(inst, methods)
	rawset(inst, "_methods", methods)
	return inst
end

withMethods(service("TweenService"), {
	Create = function(_self, inst, _info, goals)
		local tween = { Completed = newSignal(), PlaybackState = Enum.PlaybackState.Completed }
		function tween.Play()
			for key, value in goals do
				inst[key] = value
			end
		end
		function tween.Cancel() end
		function tween.Pause() end
		function tween.Destroy() end
		return tween
	end,
})

local VIEWPORT = Vector2.new(1920, 1080)
local camera = Instance.new("Camera")
camera.Name = "Camera"
camera.ViewportSize = VIEWPORT
camera.Parent = workspace
workspace.CurrentCamera = camera

local localPlayer = Instance.new("Player")
localPlayer.Name = "KungFuKid"
localPlayer.DisplayName = "KungFuKid"
localPlayer.UserId = 1
local playerGui = Instance.new("PlayerGui")
playerGui.Name = "PlayerGui"
playerGui.Parent = localPlayer
withMethods(service("Players"), {
	GetPlayers = function()
		return { localPlayer }
	end,
	GetUserThumbnailAsync = function()
		return "", true
	end,
})
service("Players").LocalPlayer = localPlayer
localPlayer.Parent = service("Players")

withMethods(service("RunService"), {
	IsStudio = function()
		return true
	end,
	IsClient = function()
		return true
	end,
	IsServer = function()
		return false
	end,
})
service("UserInputService").TouchEnabled = false
service("UserInputService").KeyboardEnabled = true
withMethods(service("ContentProvider"), {
	PreloadAsync = function() end,
})
withMethods(service("StarterGui"), {
	SetCore = function() end,
	SetCoreGuiEnabled = function() end,
})
withMethods(service("GuiService"), {
	GetGuiInset = function()
		return Vector2.new(0, 58), Vector2.new(0, 0)
	end,
})
