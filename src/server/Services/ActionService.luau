--[[
	ActionService.luau
	One validated RemoteFunction for every player request (equip, hatch, buy, claim, ...).
	Other services register handlers in their Init:

		ActionService:Register("EquipPet", function(player, data, arg) ... return { ok = true } end)

	Every handler re-checks ownership, prices and requirements against server data; the client's
	numbers are never trusted. Handlers run inside pcall and requests are rate limited.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)

local DataService = require(script.Parent.DataService)

local ActionService = {}

export type Result = { ok: boolean, message: string?, [string]: any }
type Handler = (player: Player, data: { [string]: any }, arg: string?) -> Result

local MAX_ACTIONS_PER_SECOND = 10

local handlers: { [string]: Handler } = {}
local actionLog: { [Player]: { number } } = {}

function ActionService.Fail(message: string): Result
	return { ok = false, message = message }
end

function ActionService.Success(message: string?, extra: { [string]: any }?): Result
	local result: Result = { ok = true, message = message }
	if extra then
		for key, value in extra do
			result[key] = value
		end
	end
	return result
end

function ActionService:Register(action: string, handler: Handler)
	assert(handlers[action] == nil, "Duplicate action " .. action)
	handlers[action] = handler
end

local function isRateLimited(player: Player): boolean
	local now = os.clock()
	local log = actionLog[player]
	if not log then
		log = {}
		actionLog[player] = log
	end
	while log[1] and now - log[1] > 1 do
		table.remove(log, 1)
	end
	if #log >= MAX_ACTIONS_PER_SECOND then
		return true
	end
	table.insert(log, now)
	return false
end

local function onAction(player: Player, action: any, arg: any): Result
	if type(action) ~= "string" or (arg ~= nil and (type(arg) ~= "string" or #arg > 64)) then
		return ActionService.Fail("Bad request.")
	end
	local handler = handlers[action]
	if not handler then
		return ActionService.Fail("Bad request.")
	end
	if isRateLimited(player) then
		return ActionService.Fail("Slow down!")
	end
	local data = DataService:GetData(player)
	if not data then
		return ActionService.Fail("Your data is still loading...")
	end

	local ok, result = pcall(handler, player, data, arg)
	if not ok then
		warn(`[ActionService] {action} failed for {player.Name}: {result}`)
		return ActionService.Fail("Something went wrong. Try again!")
	end
	return result
end

function ActionService:Notify(player: Player, message: string, kind: string?)
	Remotes.Notify:FireClient(player, message, kind or "Info")
end

function ActionService:Init()
	Remotes.Action.OnServerInvoke = onAction
end

function ActionService:Start()
	Players.PlayerRemoving:Connect(function(player)
		actionLog[player] = nil
	end)
end

return ActionService
