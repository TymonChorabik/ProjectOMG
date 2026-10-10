--[[
	LeaderboardService.luau
	Global top-10 boards (OrderedDataStores) painted on the leaderboard panels in Workspace.Map.
	Each player's stats are written and the boards refreshed every Config.Leaderboards.UpdateInterval.
	In Studio without API access the boards explain that the game needs to be published.
]]

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local NumberFormat = require(Shared.NumberFormat)

local DataService = require(script.Parent.DataService)

local LeaderboardService = {}

local INK = Color3.fromRGB(25, 20, 30)
local RANK_COLORS = { Color3.fromRGB(255, 210, 60), Color3.fromRGB(210, 220, 235), Color3.fromRGB(230, 150, 80) }

local nameCache: { [number]: string } = {}

local function getName(userId: number): string
	local cached = nameCache[userId]
	if cached then
		return cached
	end
	local ok, name = pcall(Players.GetNameFromUserIdAsync, Players, userId)
	cached = if ok and name then name else "Player"
	nameCache[userId] = cached
	return cached
end

local function findPanel(boardId: string): BasePart?
	local map = workspace:FindFirstChild("Map")
	local boards = map and map:FindFirstChild("Leaderboards")
	local model = boards and boards:FindFirstChild(boardId)
	local panel = model and model:FindFirstChild("Panel")
	return if panel and panel:IsA("BasePart") then panel else nil
end

local function getRowsFrame(panel: BasePart): Frame
	local gui = panel:FindFirstChild("Rows")
	if gui and gui:IsA("SurfaceGui") then
		return gui:FindFirstChild("List") :: Frame
	end
	local surface = Instance.new("SurfaceGui")
	surface.Name = "Rows"
	surface.Face = Enum.NormalId.Back
	surface.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	surface.PixelsPerStud = 20
	surface.LightInfluence = 0
	surface.Parent = panel

	local list = Instance.new("Frame")
	list.Name = "List"
	list.BackgroundTransparency = 1
	list.Position = UDim2.fromScale(0.05, 0.22)
	list.Size = UDim2.fromScale(0.9, 0.76)
	list.Parent = surface
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0.01, 0)
	layout.Parent = list
	return list
end

local function label(
	parent: Instance,
	text: string,
	color: Color3,
	x: number,
	width: number,
	align: Enum.TextXAlignment
)
	local textLabel = Instance.new("TextLabel")
	textLabel.BackgroundTransparency = 1
	textLabel.Position = UDim2.fromScale(x, 0)
	textLabel.Size = UDim2.fromScale(width, 1)
	textLabel.Font = Enum.Font.FredokaOne
	textLabel.TextScaled = true
	textLabel.TextXAlignment = align
	textLabel.Text = text
	textLabel.TextColor3 = color
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.Color = INK
	stroke.Parent = textLabel
	textLabel.Parent = parent
end

local function render(def, entries: { { Name: string, Value: number } }?, message: string?)
	local panel = findPanel(def.Id)
	if not panel then
		return
	end
	local list = getRowsFrame(panel)
	list:ClearAllChildren()
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0.01, 0)
	layout.Parent = list

	if message then
		local row = Instance.new("Frame")
		row.BackgroundTransparency = 1
		row.Size = UDim2.fromScale(1, 0.15)
		row.Parent = list
		label(row, message, Color3.new(1, 1, 1), 0, 1, Enum.TextXAlignment.Center)
		return
	end

	for rank, entry in (entries or {}) :: { { Name: string, Value: number } } do
		local row = Instance.new("Frame")
		row.Name = "Row" .. rank
		row.LayoutOrder = rank
		row.BackgroundTransparency = 1
		row.Size = UDim2.fromScale(1, 0.09)
		row.Parent = list
		local color = RANK_COLORS[rank] or Color3.new(1, 1, 1)
		label(row, `#{rank}`, color, 0, 0.14, Enum.TextXAlignment.Left)
		label(row, entry.Name, color, 0.15, 0.55, Enum.TextXAlignment.Left)
		label(
			row,
			NumberFormat.Abbreviate(entry.Value) .. (def.Suffix or ""),
			Color3.fromRGB(255, 220, 90),
			0.7,
			0.3,
			Enum.TextXAlignment.Right
		)
	end
end

local function update(stores: { [string]: OrderedDataStore })
	for _, def in Config.Leaderboards.Boards do
		local store = stores[def.Id]
		for _, player in Players:GetPlayers() do
			local data = DataService:GetData(player)
			local value = data and math.floor(data[def.Stat] or 0)
			if value and value > 0 then
				pcall(store.SetAsync, store, tostring(player.UserId), value)
			end
		end

		local ok, pages = pcall(store.GetSortedAsync, store, false, Config.Leaderboards.Size)
		if ok and pages then
			local entries = {}
			for _, item in pages:GetCurrentPage() do
				table.insert(entries, { Name = getName(tonumber(item.key) or 0), Value = item.value })
			end
			render(def, entries, if #entries == 0 then "Be the first on the board!" else nil)
		else
			render(def, nil, "Publish the game to enable global leaderboards")
		end
	end
end

function LeaderboardService:Init() end

function LeaderboardService:Start()
	local stores: { [string]: OrderedDataStore } = {}
	local ok = pcall(function()
		for _, def in Config.Leaderboards.Boards do
			stores[def.Id] = DataStoreService:GetOrderedDataStore(def.Store)
		end
	end)
	if not ok then
		for _, def in Config.Leaderboards.Boards do
			render(def, nil, "Publish the game to enable global leaderboards")
		end
		return
	end

	task.spawn(function()
		task.wait(10) -- let the first profiles load
		while true do
			update(stores)
			task.wait(Config.Leaderboards.UpdateInterval)
		end
	end)
end

return LeaderboardService
