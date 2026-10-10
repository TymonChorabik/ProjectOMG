--[[
	Main.client.luau
	Client entry point: start data mirror, effects, gameplay controllers, then the UI.
]]

local Client = script.Parent

local ClientData = require(Client.ClientData)
local Sfx = require(Client.Effects.Sfx)
local ChopController = require(Client.Controllers.ChopController)
local SmashController = require(Client.Controllers.SmashController)
local UIController = require(Client.Controllers.UIController)
local ZoneController = require(Client.Controllers.ZoneController)

Sfx.Preload()
ClientData.Start()
SmashController.Start()
ZoneController.Start()
ChopController.Start()
UIController.Start()
