--[[
	UIController.luau
	Builds the HUD + menus and wires them to player data, the chop controller and the
	server's Action remote. Only one menu is open at a time.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Formulas = require(Shared.Formulas)
local NumberFormat = require(Shared.NumberFormat)
local Remotes = require(Shared.Remotes)

local ClientData = require(script.Parent.Parent.ClientData)
local Sfx = require(script.Parent.Parent.Effects.Sfx)
local Create = require(script.Parent.Parent.UI.Create)
local Hud = require(script.Parent.Parent.UI.Hud)
local Popups = require(script.Parent.Parent.UI.Popups)
local Theme = require(script.Parent.Parent.UI.Theme)
local AurasMenu = require(script.Parent.Parent.UI.Menus.AurasMenu)
local BeltsMenu = require(script.Parent.Parent.UI.Menus.BeltsMenu)
local RebirthMenu = require(script.Parent.Parent.UI.Menus.RebirthMenu)
local UpgradesMenu = require(script.Parent.Parent.UI.Menus.UpgradesMenu)
local ChopController = require(script.Parent.ChopController)
local ZoneController = require(script.Parent.ZoneController)

local UIController = {}

local localPlayer = Players.LocalPlayer

-- Ask the server to do something; show its answer as a toast.
local function request(action: string, arg: string?)
	task.spawn(function()
		local ok, result = pcall(function()
			return Remotes.Action:InvokeServer(action, arg)
		end)
		if not ok or type(result) ~= "table" then
			Popups.Toast("Connection hiccup — try again!", "Error")
			return
		end
		if result.ok then
			Sfx.Play("Purchase", { Volume = 0.5, Pitch = 1.3 })
		end
		if result.message then
			Popups.Toast(result.message, if result.ok then "Success" else "Error")
		end
	end)
end

local function currentTrainingMultiplier(data): number
	local dojo = Formulas.GetDojo(ZoneController.GetCurrentDojo())
	if dojo and Formulas.IsDojoUnlocked(data, dojo.Id) then
		return dojo.TrainingMultiplier
	end
	return 1
end

function UIController.Start()
	pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
	end)

	local playerGui = localPlayer:WaitForChild("PlayerGui")
	local gui = Create("ScreenGui", {
		Name = "KungFuHUD",
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 5,
		Parent = playerGui,
	})

	local hud = Hud.new(gui)

	local menuLayer = Create("Frame", {
		Name = "Menus",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 1),
		ZIndex = 10,
		Parent = gui,
	})
	local menuScale = Create("UIScale", { Parent = menuLayer })

	local menus = {
		Belts = BeltsMenu.new(menuLayer, request),
		Auras = AurasMenu.new(menuLayer, request),
		Upgrades = UpgradesMenu.new(menuLayer, request),
		Rebirth = RebirthMenu.new(menuLayer, request, ZoneController.GetCurrentDojo),
	}

	hud.MenuPressed:Connect(function(name: string)
		for otherName, window in menus do
			if otherName ~= name then
				window:Close()
			end
		end
		menus[name]:Toggle()
	end)

	ZoneController.ZoneChanged:Connect(function()
		menus.Rebirth.Refresh()
	end)

	----------------------------------------------------------------------------
	-- Bottom bar
	----------------------------------------------------------------------------
	hud.AutoChopPressed:Connect(function()
		ChopController.SetAutoChop(not ChopController.IsAutoChop())
	end)
	ChopController.AutoChopChanged:Connect(function(enabled: boolean)
		hud.AutoChopButton:SetText(if enabled then "AUTO-CHOP: ON" else "AUTO-CHOP: OFF")
		hud.AutoChopButton:SetColor(if enabled then Theme.Colors.Green else Theme.Colors.GrayDark)
	end)

	hud.EquipBestPressed:Connect(function()
		request("EquipBest")
	end)

	hud.BeltSlotPressed:Connect(function()
		local data = ClientData.Data
		if not data then
			return
		end
		local owned = {}
		for _, belt in Config.Belts do
			if data.OwnedBelts[belt.Id] then
				table.insert(owned, belt.Id)
			end
		end
		local index = table.find(owned, data.EquippedBelt) or 0
		local nextId = owned[index % #owned + 1]
		if nextId and nextId ~= data.EquippedBelt then
			request("EquipBelt", nextId)
		end
	end)

	hud.AuraSlotPressed:Connect(function()
		local data = ClientData.Data
		if not data then
			return
		end
		local options = { "None" }
		for _, aura in Config.Auras do
			if data.OwnedAuras[aura.Id] then
				table.insert(options, aura.Id)
			end
		end
		if #options == 1 then
			Popups.Toast("Buy an aura in the Auras menu first!", "Info")
			return
		end
		local index = table.find(options, data.EquippedAura) or 1
		request("EquipAura", options[index % #options + 1])
	end)

	hud.ChopPressed:Connect(ChopController.Chop)

	Remotes.Notify.OnClientEvent:Connect(function(message: string, kind: string?)
		Popups.Toast(message, kind)
	end)

	----------------------------------------------------------------------------
	-- Live stats
	----------------------------------------------------------------------------
	local lastPower, lastCoins = 0, 0

	local function refreshStats()
		local data = ClientData.Data
		if not data then
			return
		end

		hud.PowerChip.Value.Text = NumberFormat.Abbreviate(data.Power)
		hud.PowerChip.Caption.Text = "+"
			.. NumberFormat.Abbreviate(Formulas.GetChopGain(data, currentTrainingMultiplier(data)))
			.. " / chop"
		if data.Power > lastPower then
			hud.PowerChip.Pulse()
		end
		lastPower = data.Power

		hud.CoinsChip.Value.Text = NumberFormat.Abbreviate(data.Coins)
		if data.Coins > lastCoins then
			hud.CoinsChip.Pulse()
		end
		lastCoins = data.Coins

		local belt = Formulas.GetBelt(data.EquippedBelt) or Config.Belts[1]
		hud.BeltChip.Value.Text = string.upper(belt.Name)
		hud.BeltChip.Value.TextColor3 = if belt.Id == "Black" then Theme.Colors.Yellow else belt.Color
		hud.BeltChip.Caption.Text = NumberFormat.Multiplier(Formulas.GetPowerMultiplier(data)) .. " total power"
		hud.BeltSlot:SetColor(belt.Color)

		local aura = Formulas.GetAura(data.EquippedAura)
		hud.AuraSlot:SetColor(if aura then aura.Color else Theme.Colors.GrayDark)

		local canRebirth = data.Power >= Formulas.GetRebirthCost(data.Rebirths)
		if canRebirth and not hud.RebirthBadge.Visible then
			hud.MenuButtons.Rebirth:Pulse()
		end
		hud.RebirthBadge.Visible = canRebirth
	end

	ClientData.Changed:Connect(refreshStats)
	ZoneController.ZoneChanged:Connect(refreshStats)
	if ClientData.Data then
		refreshStats()
	end

	----------------------------------------------------------------------------
	-- Responsive scaling (phones → big monitors)
	----------------------------------------------------------------------------
	local function rescale()
		local camera = workspace.CurrentCamera
		if not camera then
			return
		end
		local viewport = camera.ViewportSize
		local scale = math.clamp(math.min(viewport.X / 1280, viewport.Y / 760), 0.5, 1.15)
		for _, uiScale in hud.Scales do
			uiScale.Scale = scale
		end
		menuScale.Scale = scale
	end
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)
	rescale()
end

return UIController
