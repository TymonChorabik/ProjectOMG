--[[
	Hud.luau
	Core HUD layout:
	• Top centre  – studded stats header: Power (+per chop), Coins, current Belt rank
	• Left side   – stacked chunky buttons: Belts, Auras, Upgrades, Rebirth
	• Bottom bar  – Auto-Chop toggle + quick equip (Equip Best, belt & aura quick slots)
	• Bottom right – big round CHOP button (touch friendly; mouse/tap anywhere also chops)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Signal = require(Shared.Signal)

local ChunkyButton = require(script.Parent.ChunkyButton)
local Create = require(script.Parent.Create)
local StudPanel = require(script.Parent.StudPanel)
local Theme = require(script.Parent.Theme)

local Hud = {}

local PULSE_INFO = TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

-- A container frame whose UIScale follows screen size (registered with the controller).
local function container(props: { [string]: any }): (Frame, UIScale)
	props.BackgroundTransparency = 1
	local frame = Create("Frame", props)
	local scale = Create("UIScale", { Parent = frame })
	return frame, scale
end

local function statChip(parent: Instance, order: number, color: Color3, icon: string, caption: string)
	local chip = Create("Frame", {
		Name = "Chip",
		LayoutOrder = order,
		Size = UDim2.fromOffset(186, 62),
		BackgroundColor3 = color,
		ZIndex = 2,
		Parent = parent,
	}, { Create.Corner(UDim.new(0, 12)), Create.Stroke(3), Create.Bevel(0.25) })
	local scale = Create("UIScale", { Parent = chip })

	local iconLabel = Create.Label({
		Name = "Icon",
		Text = icon,
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 6, 0.5, 0),
		Size = UDim2.fromOffset(46, 46),
		ZIndex = 3,
		Parent = chip,
	})
	local value = Create.Label({
		Name = "Value",
		Text = "0",
		Font = Theme.Fonts.Title,
		TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.fromOffset(56, 6),
		Size = UDim2.new(1, -62, 0, 30),
		StrokeThickness = 3,
		ZIndex = 3,
		Parent = chip,
	})
	local captionLabel = Create.Label({
		Name = "Caption",
		Text = caption,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Theme.Colors.Cream,
		Position = UDim2.fromOffset(56, 36),
		Size = UDim2.new(1, -62, 0, 20),
		StrokeThickness = 2,
		ZIndex = 3,
		Parent = chip,
	})

	return {
		Frame = chip,
		Icon = iconLabel,
		Value = value,
		Caption = captionLabel,
		Pulse = function()
			scale.Scale = 1.12
			TweenService:Create(scale, PULSE_INFO, { Scale = 1 }):Play()
		end,
	}
end

function Hud.new(gui: ScreenGui)
	local hud = {
		Scales = {} :: { UIScale },
		MenuPressed = Signal.new(), -- (menuName)
		AutoChopPressed = Signal.new(),
		EquipBestPressed = Signal.new(),
		BeltSlotPressed = Signal.new(),
		AuraSlotPressed = Signal.new(),
		ChopPressed = Signal.new(),
	}

	----------------------------------------------------------------------------
	-- Top centre: stats header
	----------------------------------------------------------------------------
	local headerHolder, headerScale = container({
		Name = "HeaderHolder",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 6),
		Size = UDim2.fromOffset(624, 84),
		Parent = gui,
	})
	table.insert(hud.Scales, headerScale)

	local header = StudPanel.new({
		Name = "StatsHeader",
		Size = UDim2.fromScale(1, 1),
		Color = Theme.Colors.PanelRed,
		StudTint = Theme.Colors.Yellow,
		Parent = headerHolder,
	})
	local chips = Create("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -20, 1, -20),
		Position = UDim2.fromOffset(10, 10),
		ZIndex = 2,
		Parent = header,
	}, {
		Create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, 12),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	hud.PowerChip = statChip(chips, 1, Theme.Colors.PanelYellow, "⚡", "+1 / chop")
	hud.CoinsChip = statChip(chips, 2, Color3.fromRGB(220, 140, 30), "🪙", "Coins")
	hud.BeltChip = statChip(chips, 3, Theme.Colors.Panel, "🥋", "x1 Power")

	----------------------------------------------------------------------------
	-- Left: menu buttons
	----------------------------------------------------------------------------
	local leftHolder, leftScale = container({
		Name = "MenuButtons",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 14, 0.5, 0),
		Size = UDim2.fromOffset(184, 4 * 74),
		Parent = gui,
	})
	table.insert(hud.Scales, leftScale)
	Create("UIListLayout", {
		Padding = UDim.new(0, 10),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = leftHolder,
	})

	hud.MenuButtons = {}
	for order, entry in
		{
			{ Name = "Belts", Icon = "🥋", Color = Theme.Colors.Yellow },
			{ Name = "Auras", Icon = "🔥", Color = Theme.Colors.Purple },
			{ Name = "Upgrades", Icon = "⬆️", Color = Theme.Colors.Green },
			{ Name = "Rebirth", Icon = "🌀", Color = Theme.Colors.Red },
		}
	do
		local button = ChunkyButton.new({
			Name = entry.Name,
			Text = string.upper(entry.Name),
			Icon = entry.Icon,
			Color = entry.Color,
			Font = Theme.Fonts.Title,
			Size = UDim2.fromOffset(184, 64),
			LayoutOrder = order,
			MaxTextSize = 26,
			Parent = leftHolder,
		})
		button.Activated:Connect(function()
			hud.MenuPressed:Fire(entry.Name)
		end)
		hud.MenuButtons[entry.Name] = button
	end

	-- "!" badge on the rebirth button when a rebirth is affordable.
	hud.RebirthBadge = Create.Label({
		Name = "Badge",
		Text = "!",
		Font = Theme.Fonts.Title,
		BackgroundTransparency = 0,
		BackgroundColor3 = Theme.Colors.Yellow,
		TextColor3 = Theme.Colors.White,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(1, -4, 0, 4),
		Size = UDim2.fromOffset(30, 30),
		ZIndex = 10,
		Visible = false,
		Parent = hud.MenuButtons.Rebirth.Instance,
	})
	Create.Corner(UDim.new(0.5, 0)).Parent = hud.RebirthBadge

	----------------------------------------------------------------------------
	-- Bottom: auto-chop + quick equip
	----------------------------------------------------------------------------
	local bottomHolder, bottomScale = container({
		Name = "BottomBarHolder",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -10),
		Size = UDim2.fromOffset(572, 88),
		Parent = gui,
	})
	table.insert(hud.Scales, bottomScale)

	local bottom = StudPanel.new({
		Name = "BottomBar",
		Size = UDim2.fromScale(1, 1),
		Color = Theme.Colors.Panel,
		StudTint = Theme.Colors.Red,
		Parent = bottomHolder,
	})
	local row = Create("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -20, 1, -16),
		Position = UDim2.fromOffset(10, 8),
		ZIndex = 2,
		Parent = bottom,
	}, {
		Create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, 10),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})

	hud.AutoChopButton = ChunkyButton.new({
		Name = "AutoChop",
		Text = "AUTO-CHOP: OFF",
		Color = Theme.Colors.GrayDark,
		Font = Theme.Fonts.Title,
		Size = UDim2.fromOffset(220, 66),
		LayoutOrder = 1,
		MaxTextSize = 24,
		Parent = row,
	})
	hud.AutoChopButton.Activated:Connect(function()
		hud.AutoChopPressed:Fire()
	end)

	hud.EquipBestButton = ChunkyButton.new({
		Name = "EquipBest",
		Text = "EQUIP BEST",
		Color = Theme.Colors.Blue,
		Font = Theme.Fonts.Title,
		Size = UDim2.fromOffset(150, 66),
		LayoutOrder = 2,
		MaxTextSize = 22,
		Parent = row,
	})
	hud.EquipBestButton.Activated:Connect(function()
		hud.EquipBestPressed:Fire()
	end)

	hud.BeltSlot = ChunkyButton.new({
		Name = "BeltSlot",
		Text = "🥋",
		Color = Theme.Colors.White,
		Size = UDim2.fromOffset(66, 66),
		LayoutOrder = 3,
		Parent = row,
	})
	hud.BeltSlot.Activated:Connect(function()
		hud.BeltSlotPressed:Fire()
	end)

	hud.AuraSlot = ChunkyButton.new({
		Name = "AuraSlot",
		Text = "✋",
		Color = Theme.Colors.GrayDark,
		Size = UDim2.fromOffset(66, 66),
		LayoutOrder = 4,
		Parent = row,
	})
	hud.AuraSlot.Activated:Connect(function()
		hud.AuraSlotPressed:Fire()
	end)

	----------------------------------------------------------------------------
	-- Bottom right: CHOP button
	----------------------------------------------------------------------------
	local chopHolder, chopScale = container({
		Name = "ChopHolder",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -20, 1, -20),
		Size = UDim2.fromOffset(132, 138),
		Parent = gui,
	})
	table.insert(hud.Scales, chopScale)

	hud.ChopButton = ChunkyButton.new({
		Name = "ChopButton",
		Text = "CHOP!",
		Color = Theme.Colors.Red,
		Font = Theme.Fonts.Title,
		Size = UDim2.fromScale(1, 1),
		CornerRadius = UDim.new(0.5, 0),
		Depth = 8,
		MaxTextSize = 34,
		Silent = true,
		Parent = chopHolder,
	})
	hud.ChopButton.Activated:Connect(function()
		hud.ChopPressed:Fire()
	end)

	return hud
end

return Hud
