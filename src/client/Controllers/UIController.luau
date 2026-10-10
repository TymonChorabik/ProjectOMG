--[[
	UIController.luau
	Builds the HUD + windows and wires them to player data, the chop/lane controllers and the
	server. Only one window is open at a time.
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
local HatchOverlay = require(script.Parent.Parent.UI.HatchOverlay)
local Hud = require(script.Parent.Parent.UI.Hud)
local Popups = require(script.Parent.Parent.UI.Popups)
local Theme = require(script.Parent.Parent.UI.Theme)
local WelcomeBack = require(script.Parent.Parent.UI.WelcomeBack)
local GiftsMenu = require(script.Parent.Parent.UI.Menus.GiftsMenu)
local InventoryMenu = require(script.Parent.Parent.UI.Menus.InventoryMenu)
local PetsMenu = require(script.Parent.Parent.UI.Menus.PetsMenu)
local RebirthMenu = require(script.Parent.Parent.UI.Menus.RebirthMenu)
local ShopMenu = require(script.Parent.Parent.UI.Menus.ShopMenu)
local TrailsMenu = require(script.Parent.Parent.UI.Menus.TrailsMenu)
local ChopController = require(script.Parent.ChopController)
local LaneController = require(script.Parent.LaneController)
local WorldController = require(script.Parent.WorldController)

local UIController = {}

local localPlayer = Players.LocalPlayer

type Session = { SessionStart: number, Claimed: { [number]: boolean }, OfflineAmount: number, OfflineSeconds: number }
local session: Session? = nil

--------------------------------------------------------------------------------
-- Server requests
--------------------------------------------------------------------------------

-- Yields; shows the server's message as a toast and returns the result table (or nil).
local function requestAsync(action: string, arg: string?): { [string]: any }?
	local ok, result = pcall(function()
		return Remotes.Action:InvokeServer(action, arg)
	end)
	if not ok or type(result) ~= "table" then
		Popups.Toast("Connection hiccup — try again!", "Error")
		return nil
	end
	if result.ok and action ~= "GetSession" then
		Sfx.Play("Purchase", { Volume = 0.45, Pitch = 1.3 })
	end
	if result.message then
		Popups.Toast(result.message, if result.ok then "Success" else "Error")
	end
	return result
end

local function request(action: string, arg: string?)
	task.spawn(requestAsync, action, arg)
end

local function purchase(key: string)
	request("Purchase", key)
end

local function fetchSession(): Session?
	local result = requestAsync("GetSession")
	if not result or not result.ok then
		return nil
	end
	local claimed = {}
	for _, index in result.Claimed or {} do
		claimed[index] = true
	end
	return {
		SessionStart = result.SessionStart,
		Claimed = claimed,
		OfflineAmount = result.OfflineAmount or 0,
		OfflineSeconds = result.OfflineSeconds or 0,
	}
end

--------------------------------------------------------------------------------
-- Start
--------------------------------------------------------------------------------

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

	local overlay = Create("ScreenGui", {
		Name = "KungFuOverlay",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 30,
		Parent = playerGui,
	})
	HatchOverlay.Init(overlay)

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

	local ctx = {
		Request = request,
		Purchase = purchase,
		GetSession = function()
			return session
		end,
		ClaimGift = nil :: ((number) -> ())?,
	}

	local menus = {
		Shop = ShopMenu.new(menuLayer, ctx),
		Rebirth = RebirthMenu.new(menuLayer, ctx),
		Pets = PetsMenu.new(menuLayer, ctx),
		Trails = TrailsMenu.new(menuLayer, ctx),
		Inventory = InventoryMenu.new(menuLayer, ctx),
		Gifts = GiftsMenu.new(menuLayer, ctx),
	}

	ctx.ClaimGift = function(index: number)
		task.spawn(function()
			local result = requestAsync("ClaimPlaytime", tostring(index))
			if result and result.ok and session then
				session.Claimed[index] = true
				menus.Gifts.Refresh()
			end
		end)
	end

	hud.MenuPressed:Connect(function(name: string)
		for otherName, window in menus do
			if otherName ~= name then
				window:Close()
			end
		end
		menus[name]:Toggle()
	end)

	WorldController.Start(ctx)

	----------------------------------------------------------------------------
	-- HUD actions
	----------------------------------------------------------------------------
	hud.PackPressed:Connect(function(productName: string)
		purchase("product:" .. productName)
	end)
	hud.OfferPressed:Connect(purchase)
	hud.AutoChopPressed:Connect(function()
		local data = ClientData.Data
		if data and Formulas.HasPass(data, "AutoChop") then
			ChopController.SetAutoChop(not ChopController.IsAutoChop())
		else
			purchase("pass:AutoChop")
		end
	end)
	hud.ActionPressed:Connect(function()
		if LaneController.IsOnPad() then
			LaneController.TryRun()
		else
			ChopController.Chop()
		end
	end)

	local function refreshAutoChop()
		local data = ClientData.Data
		local owned = data ~= nil and Formulas.HasPass(data, "AutoChop")
		if owned then
			local on = ChopController.IsAutoChop()
			hud.AutoChopButton:SetText(if on then "🤖 AUTO CHOP: ON" else "🤖 AUTO CHOP: OFF")
			hud.AutoChopButton:SetColor(if on then Theme.Colors.Green else Theme.Colors.GrayDark)
		else
			hud.AutoChopButton:SetText(`🤖 AUTO CHOP\nONLY R${Config.Monetization.GamePasses.AutoChop.Price}`)
			hud.AutoChopButton:SetColor(Theme.Colors.Red)
		end
	end
	ChopController.AutoChopChanged:Connect(refreshAutoChop)

	LaneController.PadChanged:Connect(function(onPad: boolean)
		hud.ActionButton:SetText(if onPad then "SMASH!" else "CHOP!")
		hud.ActionButton:SetColor(if onPad then Theme.Colors.Yellow else Theme.Colors.Red)
		if onPad then
			hud.ActionButton:Pulse()
		end
	end)
	LaneController.RunProgress:Connect(function(meters: number?)
		hud.DistanceLabel.Visible = meters ~= nil
		if meters then
			hud.DistanceLabel.Text = `{NumberFormat.Commas(meters)} m`
		end
	end)

	----------------------------------------------------------------------------
	-- Live stats
	----------------------------------------------------------------------------
	local lastStrength, lastWins = 0, 0

	local function refreshStats()
		local data = ClientData.Data
		if not data then
			return
		end
		local now = workspace:GetServerTimeNow()
		local friendBoost = localPlayer:GetAttribute("FriendBoost")
		friendBoost = if type(friendBoost) == "number" then friendBoost else 0

		hud.StrengthLabel.Text = `⚡ {NumberFormat.Abbreviate(data.Strength)} STRENGTH`
		if data.Strength > lastStrength then
			Hud.Pulse(hud.StrengthLabel)
		end
		lastStrength = data.Strength
		hud.MultiplierLabel.Text =
			`{NumberFormat.Multiplier(Formulas.GetStrengthMultiplier(data, now, friendBoost))} Multiplier`

		local level, _, nextAt = Formulas.GetLevel(data.Strength, data.Rebirths)
		local maxed = level >= Config.Rebirth.MaxLevel
		hud.LevelLabel.Text = `Level {level}`
		hud.LevelRightLabel.Text = if maxed then "MAX LEVEL" else `Next: ⚡{NumberFormat.Abbreviate(nextAt)}`
		hud.LevelFill.Size = UDim2.fromScale(Formulas.GetRebirthProgress(data), 1)
		hud.LevelFill.BackgroundColor3 = if maxed then Color3.fromRGB(80, 230, 110) else Color3.fromRGB(60, 200, 255)

		local percent = math.floor(Formulas.GetRebirthProgress(data) * 100)
		hud.Buttons.Rebirth:SetTag(`{percent}%`)
		hud.Buttons.Rebirth:SetBadge(if maxed then "!" else nil)

		hud.RebirthsLabel.Text = NumberFormat.Abbreviate(data.Rebirths)
		hud.WinsLabel.Text = NumberFormat.Abbreviate(data.Wins)
		if data.Wins > lastWins then
			Hud.Pulse(hud.WinsLabel)
		end
		lastWins = data.Wins
		hud.FriendLabel.Text = `Friend Boost +{math.floor(friendBoost * 100)}%`

		hud.Offers["product:StarterPack"].Instance.Visible = not data.StarterPackBought
		hud.Offers["pass:DoubleStrength"].Instance.Visible = not Formulas.HasPass(data, "DoubleStrength")
		hud.Offers["pass:DoubleWins"].Instance.Visible = not Formulas.HasPass(data, "DoubleWins")
		refreshAutoChop()
	end

	ClientData.Changed:Connect(refreshStats)
	localPlayer:GetAttributeChangedSignal("FriendBoost"):Connect(refreshStats)
	if ClientData.Data then
		refreshStats()
	end

	-- Once-a-second: gifts badge/timer and boost pills.
	task.spawn(function()
		while true do
			local claimable = GiftsMenu.CountClaimable(session)
			hud.Buttons.Gifts:SetBadge(if claimable > 0 then tostring(claimable) else nil)
			local nextIn = GiftsMenu.NextGiftIn(session)
			hud.Buttons.Gifts:SetText(
				if claimable > 0
					then "CLAIM!"
					elseif nextIn then string.format("%d:%02d", nextIn // 60, nextIn % 60)
					else "Gifts"
			)

			local data = ClientData.Data
			local active = {}
			if data then
				local now = workspace:GetServerTimeNow()
				for kind, def in Config.Boosts do
					local expiry = data.Boosts and data.Boosts[kind] or 0
					if expiry > now then
						table.insert(
							active,
							{ Icon = def.Icon, Name = def.Name, Seconds = expiry - now, Color = def.Color }
						)
					end
				end
			end
			Hud.SetBoosts(hud, active)
			task.wait(1)
		end
	end)

	----------------------------------------------------------------------------
	-- Server events, session, offline popup
	----------------------------------------------------------------------------
	Remotes.Notify.OnClientEvent:Connect(function(message: string, kind: string?)
		Popups.Toast(message, kind)
	end)
	Remotes.Hatched.OnClientEvent:Connect(function(eggId: string, petId: string)
		HatchOverlay.Play(eggId, petId)
	end)

	task.spawn(function()
		ClientData.WaitForData()
		session = fetchSession()
		local function showOffline()
			local current = session
			if not current or current.OfflineAmount <= 0 then
				return
			end
			WelcomeBack.Show(overlay, current.OfflineAmount, current.OfflineSeconds, function(multiplied: boolean)
				if multiplied then
					purchase("product:OfflineTriple")
					-- If the purchase was cancelled the Strength is still waiting: offer it again.
					task.delay(6, function()
						session = fetchSession() or session
						showOffline()
					end)
				else
					request("ClaimOffline")
					if session then
						session.OfflineAmount = 0
					end
				end
			end)
		end
		showOffline()
	end)

	----------------------------------------------------------------------------
	-- Responsive scaling (phones → big monitors)
	----------------------------------------------------------------------------
	local function rescale()
		local camera = workspace.CurrentCamera
		if not camera then
			return
		end
		local viewport = camera.ViewportSize
		local scale = math.clamp(math.min(viewport.X / 1400, viewport.Y / 820), 0.5, 1.15)
		for _, uiScale in hud.Scales do
			uiScale.Scale = scale
		end
		menuScale.Scale = scale
	end
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)
	rescale()
end

return UIController
