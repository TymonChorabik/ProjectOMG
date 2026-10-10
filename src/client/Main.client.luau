--[[
	Main.client.luau
	Client entry point: start the data mirror, effects and gameplay controllers, then the UI.
]]

local Client = script.Parent

local ClientData = require(Client.ClientData)
local Sfx = require(Client.Effects.Sfx)
local ChopController = require(Client.Controllers.ChopController)
local LaneController = require(Client.Controllers.LaneController)
local PetController = require(Client.Controllers.PetController)
local UIController = require(Client.Controllers.UIController)

Sfx.Preload()
ClientData.Start()
LaneController.Start()
PetController.Start()
ChopController.Start()
UIController.Start()
