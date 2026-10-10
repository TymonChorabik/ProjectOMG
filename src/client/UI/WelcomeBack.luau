--[[
	WelcomeBack.luau
	"Welcome Back! You trained while you were offline" popup (as in +1 Stone Skipping): dark
	translucent card, outlined title with a clock icon, the offline Strength in gold, a rainbow
	x3 (Robux) button and a green Claim! button. Shown on the (scaled) menu layer so it is as
	big as the windows.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local NumberFormat = require(Shared.NumberFormat)

local ChunkyButton = require(script.Parent.ChunkyButton)
local Create = require(script.Parent.Create)
local Theme = require(script.Parent.Theme)

local WelcomeBack = {}

-- onClaim(multiplied: boolean) is called when a button is pressed; the popup closes itself.
function WelcomeBack.Show(parent: Instance, amount: number, seconds: number, onClaim: (boolean) -> ())
	local panel = Create("Frame", {
		Name = "WelcomeBack",
		Size = UDim2.fromOffset(640, 450),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Theme.Colors.Window,
		BackgroundTransparency = Theme.WindowTransparency,
		BorderSizePixel = 0,
		ZIndex = 20,
		Parent = parent,
	}, { Create.Corner(UDim.new(0, 18)), Create.Glass(), Create.Stroke(3.5) })
	local scale = Create("UIScale", { Scale = 0.5, Parent = panel })

	Create.Icon({
		Text = "⏰",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(34, 4),
		Size = UDim2.fromOffset(116, 116),
		Rotation = -10,
		ZIndex = 22,
		Parent = panel,
	})
	Create.Label({
		Text = "Welcome Back!",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 20, 0, -6),
		Size = UDim2.new(1, -150, 0, 86),
		StrokeThickness = 5.5,
		MaxTextSize = 70,
		ZIndex = 21,
		Parent = panel,
	})
	local hours = math.floor(seconds / 3600)
	local minutes = math.floor(seconds / 60) % 60
	Create.Label({
		Text = `You trained while you were offline ({hours}h {minutes}m):`,
		Position = UDim2.fromOffset(24, 50),
		Size = UDim2.new(1, -48, 0, 32),
		StrokeThickness = 3.5,
		MaxTextSize = 30,
		ZIndex = 21,
		Parent = panel,
	})

	-- Sunburst behind the bolt: thin rays that fade out towards their tips.
	local rayFade = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.5, 0.35),
		NumberSequenceKeypoint.new(1, 1),
	})
	for index = 0, 9 do
		Create("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, 0, 0, 172),
			Size = UDim2.fromOffset(14, 230),
			Rotation = index * 18,
			BackgroundColor3 = Color3.fromRGB(255, 240, 190),
			BorderSizePixel = 0,
			ZIndex = 21,
			Parent = panel,
		}, { Create("UIGradient", { Transparency = rayFade, Rotation = 90 }) })
	end
	Create.Icon({
		Text = "⚡",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0, 170),
		Size = UDim2.fromOffset(140, 140),
		Rotation = 12,
		ZIndex = 22,
		Parent = panel,
	})
	Create.Label({
		Text = `+{NumberFormat.Commas(amount)} STRENGTH`,
		TextColor3 = Theme.Colors.Gold,
		Position = UDim2.fromOffset(24, 250),
		Size = UDim2.new(1, -48, 0, 60),
		StrokeThickness = 5,
		MaxTextSize = 56,
		ZIndex = 21,
		Parent = panel,
	})

	local function close()
		local tween = TweenService:Create(scale, TweenInfo.new(0.15), { Scale = 0 })
		tween:Play()
		tween.Completed:Once(function()
			panel:Destroy()
		end)
	end

	local multiplier = Config.Offline.ProductMultiplier
	local triple = ChunkyButton.new({
		Text = `+{NumberFormat.Commas(amount * multiplier)}`,
		Rainbow = true,
		Size = UDim2.fromOffset(290, 86),
		Position = UDim2.new(0, 34, 1, -110),
		MaxTextSize = 40,
		StrokeThickness = 4,
		Parent = panel,
	})
	triple.Instance.ZIndex = 21
	Create.Label({
		Text = `{Theme.Robux}{Config.Monetization.Products.OfflineTriple.Price}`,
		TextColor3 = Theme.Colors.GreenText,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, 10, 0, 2),
		Size = UDim2.fromOffset(90, 32),
		TextXAlignment = Enum.TextXAlignment.Right,
		StrokeThickness = 3,
		ZIndex = 30,
		Parent = triple.Instance,
	})
	Create.Label({
		Text = `x{multiplier}`,
		TextColor3 = Theme.Colors.Gold,
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, -10, 0, 2),
		Size = UDim2.fromOffset(60, 34),
		TextXAlignment = Enum.TextXAlignment.Left,
		StrokeThickness = 3,
		ZIndex = 30,
		Parent = triple.Instance,
	})
	triple.Activated:Connect(function()
		onClaim(true)
		close()
	end)

	local claim = ChunkyButton.new({
		Text = "Claim!",
		Color = Theme.Colors.Green,
		Size = UDim2.fromOffset(220, 86),
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -34, 1, -110),
		MaxTextSize = 42,
		StrokeThickness = 4,
		Parent = panel,
	})
	claim.Instance.ZIndex = 21
	claim.Activated:Connect(function()
		onClaim(false)
		close()
	end)

	TweenService:Create(scale, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
		:Play()
	return panel
end

return WelcomeBack
