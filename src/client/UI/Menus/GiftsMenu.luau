--[[
	GiftsMenu.luau
	Playtime rewards: a 4x3 grid of big studded tiles (blue, purple, orange rows, rainbow last
	gift). Each shows the reward and a red countdown bar; ready gifts say CLAIM! and claimed
	ones dim down with a big green tick over the icon (like +1 Stone Skipping).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Formulas = require(Shared.Formulas)
local NumberFormat = require(Shared.NumberFormat)

local ClientData = require(script.Parent.Parent.Parent.ClientData)
local Create = require(script.Parent.Parent.Create)
local MenuWindow = require(script.Parent.Parent.MenuWindow)
local Theme = require(script.Parent.Parent.Theme)

local GiftsMenu = {}

local ROW_COLORS = { Color3.fromRGB(40, 140, 245), Color3.fromRGB(160, 90, 240), Color3.fromRGB(255, 170, 30) }
local ICONS = { Strength = "⚡", Wins = "🏆", Egg = "🥚", Boost = "🧪" }

local function rewardTitle(reward, data): string
	if reward.Kind == "Strength" or reward.Kind == "Wins" then
		local amount = if data then Formulas.GetPlaytimeRewardAmount(reward, data, workspace:GetServerTimeNow()) else 0
		return `+{NumberFormat.Abbreviate(amount)} {string.upper(reward.Kind)}`
	elseif reward.Kind == "Egg" then
		return string.upper(Formulas.GetEgg(reward.Egg).Name)
	end
	return string.upper(Config.Boosts[reward.Boost].Name) .. " BOOST"
end

local function formatTime(seconds: number): string
	seconds = math.max(0, math.ceil(seconds))
	return string.format("%02d:%02d:%02d", seconds // 3600, (seconds // 60) % 60, seconds % 60)
end

-- Number of gifts ready to claim (for the HUD badge).
function GiftsMenu.CountClaimable(session): number
	if not session then
		return 0
	end
	local elapsed = workspace:GetServerTimeNow() - session.SessionStart
	local count = 0
	for index, reward in Config.PlaytimeRewards do
		if not session.Claimed[index] and elapsed >= reward.Minutes * 60 then
			count += 1
		end
	end
	return count
end

-- Seconds until the next unclaimed gift (nil when all are ready/claimed).
function GiftsMenu.NextGiftIn(session): number?
	if not session then
		return nil
	end
	local elapsed = workspace:GetServerTimeNow() - session.SessionStart
	for index, reward in Config.PlaytimeRewards do
		if not session.Claimed[index] and elapsed < reward.Minutes * 60 then
			return reward.Minutes * 60 - elapsed
		end
	end
	return nil
end

function GiftsMenu.new(parent: Instance, ctx: { [string]: any })
	local window = MenuWindow.new({
		Title = "Playtime Rewards",
		Name = "Gifts",
		Icon = "🎁",
		Size = Vector2.new(780, 552),
		Parent = parent,
	})
	local grid = MenuWindow.Grid(window.Content, 1, Vector2.new(0, 150), nil, 4)

	local tiles = {}
	local count = #Config.PlaytimeRewards
	for index, reward in Config.PlaytimeRewards do
		local rainbow = index == count
		local tile = MenuWindow.Tile({
			Parent = grid,
			Order = index,
			Color = ROW_COLORS[math.clamp(math.ceil(index / 4), 1, #ROW_COLORS)],
			Rainbow = rainbow,
			Title = "",
			Icon = ICONS[reward.Kind] or "🎁",
			Bar = "",
		})
		tile.Title.Size = UDim2.new(1, -12, 0, 30)
		local constraint = tile.Title:FindFirstChildOfClass("UITextSizeConstraint")
		if constraint then
			constraint.MaxTextSize = 26
		end
		tile.Bar.Size = UDim2.new(1, -18, 0, 36)
		tile.Art.Position = UDim2.new(0.5, 0, 0, 36)
		tile.Art.Size = UDim2.new(1, -40, 1, -84)
		local check = Create.Icon({
			Name = "Check",
			Text = "✅",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(84, 84),
			Rotation = -8,
			Visible = false,
			ZIndex = 9,
			Parent = tile.Face,
		})
		tile.Activated:Connect(function()
			ctx.ClaimGift(index)
		end)
		tiles[index] = {
			Check = check,
			Tile = tile,
		}
	end

	local function refresh()
		local session = ctx.GetSession()
		local data = ClientData.Data
		local elapsed = if session then workspace:GetServerTimeNow() - session.SessionStart else 0
		for index, reward in Config.PlaytimeRewards do
			local entry = tiles[index]
			local tile = entry.Tile
			tile.Title.Text = rewardTitle(reward, data)
			local claimed = session ~= nil and session.Claimed[index] == true
			local remaining = reward.Minutes * 60 - elapsed
			-- Claimed: the tile dims and a big tick sits over the icon.
			tile.Shade.Visible = claimed
			entry.Check.Visible = claimed
			if claimed then
				tile.Bar.Visible = false
			else
				tile.Bar.Visible = true
				if remaining <= 0 then
					tile.BarText.Text = "CLAIM!"
					tile.Bar.BackgroundColor3 = Theme.Colors.Green
				else
					tile.BarText.Text = formatTime(remaining)
					tile.Bar.BackgroundColor3 = Theme.Colors.Red
				end
			end
		end
	end

	task.spawn(function()
		while true do
			if window.IsOpen then
				refresh()
			end
			task.wait(1)
		end
	end)
	window.Instance:GetPropertyChangedSignal("Visible"):Connect(refresh)
	window.Refresh = refresh
	refresh()
	return window
end

return GiftsMenu
