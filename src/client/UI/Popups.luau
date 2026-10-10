--[[
	Popups.luau
	Floating feedback: "+12 ⚡" chop numbers, world-space reward text, toast notifications and
	the big zone banner.
]]

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local Create = require(script.Parent.Create)
local Theme = require(script.Parent.Theme)

local Popups = {}

local MAX_TOASTS = 4

local gui: ScreenGui? = nil
local toastHolder: Frame? = nil
local bannerHolder: Frame? = nil
local rng = Random.new()

local function getGui(): ScreenGui
	if gui and gui.Parent then
		return gui
	end
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	gui = Create("ScreenGui", {
		Name = "KungFuPopups",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 20,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = playerGui,
	})

	toastHolder = Create("Frame", {
		Name = "Toasts",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 200),
		Size = UDim2.fromOffset(470, 240),
		Parent = gui,
	}, {
		Create("UIListLayout", {
			SortOrder = Enum.SortOrder.LayoutOrder,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0, 8),
		}),
	})

	bannerHolder = Create("Frame", {
		Name = "Banner",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.4),
		Size = UDim2.fromOffset(760, 150),
		Parent = gui,
	})

	return gui :: ScreenGui
end

-- Chop gain number that pops at a screen position and floats upward.
function Popups.ScreenText(screenPosition: Vector2, text: string, color: Color3, size: number?)
	local screenGui = getGui()
	local height = size or 26
	local label = Create.Label({
		Text = text,
		TextColor3 = color,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(height * 6, height),
		Position = UDim2.fromOffset(
			screenPosition.X + rng:NextNumber(-40, 40),
			screenPosition.Y + rng:NextNumber(-10, 10)
		),
		Rotation = rng:NextNumber(-8, 8),
		StrokeThickness = 3,
		Parent = screenGui,
	})
	local scale = Create("UIScale", { Scale = 0.4, Parent = label })

	TweenService:Create(scale, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
		:Play()
	TweenService:Create(label, TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = label.Position - UDim2.fromOffset(0, 70),
	}):Play()
	task.delay(0.45, function()
		TweenService:Create(label, TweenInfo.new(0.35), { TextTransparency = 1 }):Play()
		local stroke = label:FindFirstChildOfClass("UIStroke")
		if stroke then
			TweenService:Create(stroke, TweenInfo.new(0.35), { Transparency = 1 }):Play()
		end
	end)
	Debris:AddItem(label, 0.9)
end

-- Text that pops at a 3D position (coins from a smash, "Need X Power").
function Popups.WorldText(position: Vector3, text: string, color: Color3, scale: number?)
	local screenGui = getGui()
	local anchor = Instance.new("Attachment")
	anchor.WorldPosition = position
	anchor.Parent = workspace.Terrain

	local billboard = Create("BillboardGui", {
		Adornee = anchor,
		Size = UDim2.fromScale(7 * (scale or 1), 2 * (scale or 1)),
		AlwaysOnTop = true,
		LightInfluence = 0,
		StudsOffsetWorldSpace = Vector3.zero,
		Parent = screenGui,
	})
	local label = Create.Label({
		Text = text,
		Font = Theme.Fonts.Title,
		TextColor3 = color,
		Size = UDim2.fromScale(1, 1),
		StrokeThickness = 3,
		Parent = billboard,
	})
	local uiScale = Create("UIScale", { Scale = 0.3, Parent = label })

	TweenService:Create(uiScale, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
		:Play()
	TweenService:Create(billboard, TweenInfo.new(1.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		StudsOffsetWorldSpace = Vector3.new(0, 4, 0),
	}):Play()
	task.delay(0.7, function()
		TweenService:Create(label, TweenInfo.new(0.4), { TextTransparency = 1 }):Play()
		local stroke = label:FindFirstChildOfClass("UIStroke")
		if stroke then
			TweenService:Create(stroke, TweenInfo.new(0.4), { Transparency = 1 }):Play()
		end
	end)
	Debris:AddItem(billboard, 1.2)
	Debris:AddItem(anchor, 1.2)
end

local TOAST_TEXT = {
	Info = Theme.Colors.White,
	Success = Theme.Colors.GreenText,
	Error = Color3.fromRGB(255, 110, 110),
}

function Popups.Toast(message: string, kind: string?)
	getGui()
	local holder = toastHolder :: Frame

	local toasts = {}
	for _, child in holder:GetChildren() do
		if child:IsA("Frame") then
			table.insert(toasts, child)
		end
	end
	if #toasts >= MAX_TOASTS then
		table.sort(toasts, function(a, b)
			return a.LayoutOrder < b.LayoutOrder
		end)
		toasts[1]:Destroy()
	end

	local panel = Create("Frame", {
		Name = "Toast",
		Size = UDim2.fromOffset(460, 46),
		BackgroundColor3 = Theme.Colors.Window,
		BackgroundTransparency = Theme.WindowTransparency,
		BorderSizePixel = 0,
	}, { Create.Corner(UDim.new(0, 12)), Create.Glass(), Create.Stroke(3) })
	panel.LayoutOrder = math.floor(os.clock() * 1000) % 1_000_000_000
	Create.Label({
		Text = message,
		TextColor3 = TOAST_TEXT[kind or "Info"] or Theme.Colors.White,
		Size = UDim2.new(1, -24, 1, -14),
		Position = UDim2.fromOffset(12, 7),
		StrokeThickness = 2.5,
		MaxTextSize = 24,
		ZIndex = 2,
		Parent = panel,
	})
	local scale = Create("UIScale", { Scale = 0.6, Parent = panel })
	panel.Parent = holder

	TweenService:Create(scale, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
		:Play()
	task.delay(2.6, function()
		if panel.Parent then
			local tween = TweenService:Create(
				scale,
				TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
				{ Scale = 0 }
			)
			tween:Play()
			tween.Completed:Wait()
			panel:Destroy()
		end
	end)
end

-- Large title card, e.g. when entering a new dojo.
function Popups.Banner(title: string, subtitle: string, color: Color3?)
	getGui()
	local holder = bannerHolder :: Frame
	holder:ClearAllChildren()

	local titleLabel = Create.Label({
		Text = title,
		Font = Enum.Font.FredokaOne,
		TextColor3 = color or Theme.Colors.Gold,
		Size = UDim2.fromScale(1, 0.68),
		StrokeThickness = 5,
		Parent = holder,
	})
	local subtitleLabel = Create.Label({
		Text = subtitle,
		Size = UDim2.fromScale(0.8, 0.26),
		Position = UDim2.fromScale(0.1, 0.72),
		StrokeThickness = 3,
		Parent = holder,
	})
	local scale = Create("UIScale", { Scale = 1.6, Parent = holder })
	TweenService:Create(scale, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
		:Play()

	task.delay(2.2, function()
		if not titleLabel.Parent then
			return
		end
		for _, label in { titleLabel, subtitleLabel } do
			TweenService:Create(label, TweenInfo.new(0.5), { TextTransparency = 1 }):Play()
			local stroke = label:FindFirstChildOfClass("UIStroke")
			if stroke then
				TweenService:Create(stroke, TweenInfo.new(0.5), { Transparency = 1 }):Play()
			end
		end
		task.delay(0.55, function()
			if titleLabel.Parent then
				scale:Destroy()
				titleLabel:Destroy()
				subtitleLabel:Destroy()
			end
		end)
	end)
end

return Popups
