--[[
	WelcomeBack.luau
	"Welcome Back! You trained while you were offline" popup with Claim and x3 (Robux) options.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local NumberFormat = require(Shared.NumberFormat)

local ChunkyButton = require(script.Parent.ChunkyButton)
local Create = require(script.Parent.Create)
local StudPanel = require(script.Parent.StudPanel)
local Theme = require(script.Parent.Theme)

local WelcomeBack = {}

-- onClaim(multiplied: boolean) is called when a button is pressed; the popup closes itself.
function WelcomeBack.Show(parent: Instance, amount: number, seconds: number, onClaim: (boolean) -> ())
	local panel = StudPanel.new({
		Name = "WelcomeBack",
		Size = UDim2.fromOffset(430, 300),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Color = Color3.fromRGB(70, 70, 80),
		Transparency = 0.1,
		StrokeThickness = 4,
		Parent = parent,
	})
	panel.ZIndex = 20
	local scale = Create("UIScale", { Scale = 0.5, Parent = panel })

	Create.Label({
		Text = "⏰ Welcome Back!",
		Font = Theme.Fonts.Title,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0, 0),
		Size = UDim2.new(1, 0, 0, 52),
		StrokeThickness = 5,
		ZIndex = 21,
		Parent = panel,
	})
	local hours = math.floor(seconds / 3600)
	local minutes = math.floor(seconds / 60) % 60
	Create.Label({
		Text = `You trained while you were offline ({hours}h {minutes}m):`,
		Position = UDim2.fromOffset(16, 34),
		Size = UDim2.new(1, -32, 0, 22),
		ZIndex = 21,
		Parent = panel,
	})
	Create.Label({
		Text = "⚡",
		Stroke = false,
		Position = UDim2.new(0.5, -42, 0, 62),
		Size = UDim2.fromOffset(84, 84),
		ZIndex = 21,
		Parent = panel,
	})
	Create.Label({
		Text = `+{NumberFormat.Commas(amount)} STRENGTH`,
		Font = Theme.Fonts.Title,
		TextColor3 = Theme.Colors.Yellow,
		Position = UDim2.fromOffset(16, 152),
		Size = UDim2.new(1, -32, 0, 38),
		StrokeThickness = 4,
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
		Text = `x{multiplier} +{NumberFormat.Abbreviate(amount * multiplier)}  R${Config.Monetization.Products.OfflineTriple.Price}`,
		Color = Color3.fromRGB(170, 70, 255),
		Font = Theme.Fonts.Title,
		Size = UDim2.fromOffset(230, 56),
		Position = UDim2.new(0, 16, 1, -76),
		MaxTextSize = 20,
		Parent = panel,
	})
	Create("UIGradient", {
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 90, 90)),
			ColorSequenceKeypoint.new(0.35, Color3.fromRGB(255, 220, 60)),
			ColorSequenceKeypoint.new(0.7, Color3.fromRGB(80, 220, 120)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(80, 140, 255)),
		}),
		Parent = triple.Face,
	})
	triple.Activated:Connect(function()
		onClaim(true)
		close()
	end)

	local claim = ChunkyButton.new({
		Text = "Claim!",
		Color = Theme.Colors.Green,
		Font = Theme.Fonts.Title,
		Size = UDim2.fromOffset(150, 56),
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -16, 1, -76),
		MaxTextSize = 24,
		Parent = panel,
	})
	claim.Activated:Connect(function()
		onClaim(false)
		close()
	end)

	TweenService:Create(scale, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
		:Play()
	return panel
end

return WelcomeBack
