--[[
	GiftsMenu.luau
	Playtime rewards grid: each gift unlocks after N minutes in this session.
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

local ROW_COLORS = { Color3.fromRGB(40, 120, 230), Color3.fromRGB(150, 80, 230), Color3.fromRGB(250, 160, 30) }
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
	local window = MenuWindow.new({ Title = "Gifts", Icon = "🎁", Color = Theme.Colors.Green, Parent = parent })

	local grid = Create("Frame", {
		Name = "Grid",
		LayoutOrder = 1,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -6, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		ZIndex = 2,
		Parent = window.Content,
	}, {
		Create("UIGridLayout", {
			CellSize = UDim2.fromOffset(124, 126),
			CellPadding = UDim2.fromOffset(8, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
		}),
	})

	local tiles = {}
	for index, reward in Config.PlaytimeRewards do
		local tile = Create("Frame", {
			LayoutOrder = index,
			BackgroundColor3 = ROW_COLORS[math.clamp(math.ceil(index / 4), 1, 3)],
			ZIndex = 3,
			Parent = grid,
		}, { Create.Corner(UDim.new(0, 12)), Create.Stroke(3), Create.Bevel(0.25) })
		local title = Create.Label({
			Text = "",
			Position = UDim2.fromOffset(6, 5),
			Size = UDim2.new(1, -12, 0, 18),
			ZIndex = 4,
			Parent = tile,
		})
		local icon = Create.Label({
			Text = ICONS[reward.Kind] or "🎁",
			Stroke = false,
			Position = UDim2.fromScale(0.2, 0.22),
			Size = UDim2.fromScale(0.6, 0.48),
			ZIndex = 4,
			Parent = tile,
		})
		local bar = Create("TextButton", {
			AutoButtonColor = true,
			Text = "",
			BackgroundColor3 = Theme.Colors.Red,
			Position = UDim2.new(0, 7, 1, -29),
			Size = UDim2.new(1, -14, 0, 22),
			ZIndex = 4,
			Parent = tile,
		}, { Create.Corner(UDim.new(0, 8)), Create.Stroke(2) })
		local barText = Create.Label({
			Text = "",
			Size = UDim2.new(1, -8, 1, -4),
			Position = UDim2.fromOffset(4, 2),
			ZIndex = 5,
			Parent = bar,
		})
		bar.Activated:Connect(function()
			ctx.ClaimGift(index)
		end)
		tiles[index] = { Tile = tile, Title = title, Icon = icon, Bar = bar, BarText = barText }
	end

	local function refresh()
		local session = ctx.GetSession()
		local data = ClientData.Data
		local elapsed = if session then workspace:GetServerTimeNow() - session.SessionStart else 0
		for index, reward in Config.PlaytimeRewards do
			local tile = tiles[index]
			tile.Title.Text = rewardTitle(reward, data)
			local claimed = session and session.Claimed[index]
			local remaining = reward.Minutes * 60 - elapsed
			if claimed then
				tile.BarText.Text = "✅ CLAIMED"
				tile.Bar.BackgroundColor3 = Theme.Colors.GrayDark
				tile.Tile.BackgroundTransparency = 0.5
			elseif remaining <= 0 then
				tile.BarText.Text = "CLAIM!"
				tile.Bar.BackgroundColor3 = Theme.Colors.Green
				tile.Tile.BackgroundTransparency = 0
			else
				tile.BarText.Text = formatTime(remaining)
				tile.Bar.BackgroundColor3 = Theme.Colors.Red
				tile.Tile.BackgroundTransparency = 0
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
	return window
end

return GiftsMenu
