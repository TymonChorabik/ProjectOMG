--[[
	Config.luau
	Every tunable number, color and asset reference for "Kung Fu Chop!" lives here.
	Shared by server (authoritative math) and client (display / prediction).
]]

local Config = {}

Config.GameName = "Kung Fu Chop!"
Config.DataStoreName = "KungFuChop_PlayerData_v1"

--------------------------------------------------------------------------------
-- Assets
--------------------------------------------------------------------------------

Config.Assets = {
	-- Square stud tile (assets/textures/stud_overlay.png): the raised rounded-square studs with a
	-- dark "L" bevel seen in Steal an Egg / Steal a Brainrot. Upload it with Studio's Asset Manager
	-- (Bulk Import), right-click → Copy Asset ID, and paste "rbxassetid://<id>" here (see README:
	-- a *decal* id from the website is not the image id). The same
	-- asset drives the UI panels and every 3D surface. Empty string = fallback (procedural square
	-- studs in the UI, classic SurfaceType.Studs on parts) so the place still runs before uploading.
	StudTexture = "",

	-- Optional (assets/textures/checker_overlay.png): darkens alternating 4x4-stud squares on
	-- floors, like the checkerboard ground in the reference games.
	CheckerTexture = "",
	CheckerStudsPerTile = 8, -- the 2x2 checker image covers 8x8 studs → 4x4-stud squares

	-- Exact tile size used for the "Steal an Egg" studded UI background.
	StudTileSize = UDim2.new(0, 32, 0, 32),
	-- How visible the stud overlay is on UI panels (0 = full strength, 1 = invisible).
	StudImageTransparency = 0.15,
	-- How visible the stud overlay Texture is on 3D parts (0 = full strength).
	StudPartTransparency = 0,

	-- Optional uploaded karate-chop Animation (R15/R6). Empty = procedural Motor6D chop.
	ChopAnimation = "",

	-- Built-in client sounds so the game is audible out of the box. Swap for uploaded SFX ids.
	Sounds = {
		Chop = "rbxasset://sounds/swordslash.wav",
		Crit = "rbxasset://sounds/swordlunge.wav",
		Smash = "rbxasset://sounds/collide.wav",
		Denied = "rbxasset://sounds/unsheath.wav",
		Click = "rbxasset://sounds/electronicpingshort.wav",
		Purchase = "rbxasset://sounds/electronicpingshort.wav",
	},

	Particles = {
		Sparkle = "rbxasset://textures/particles/sparkles_main.dds",
		Fire = "rbxasset://textures/particles/fire_main.dds",
		Smoke = "rbxasset://textures/particles/smoke_main.dds",
	},
}

--------------------------------------------------------------------------------
-- Training (+1 loop)
--------------------------------------------------------------------------------

Config.Training = {
	BasePower = 1, -- the "+1"
	CritMultiplier = 3,
	MaxCritChance = 0.75,

	-- Client never sends chops faster than this (seconds).
	ClientMinInterval = 0.1,
	-- Server token bucket: excess chops are silently dropped.
	ServerBucketCapacity = 14,
	ServerBucketRefillPerSecond = 11,

	AutoChopBaseInterval = 0.6,
	AutoChopMinInterval = 0.2,
}

--------------------------------------------------------------------------------
-- Smashing
--------------------------------------------------------------------------------

Config.Smash = {
	-- Horizontal studs from the player to the edge of a breakable object.
	Range = 9,
	-- Extra leeway the server allows on top of Range (latency / movement).
	RangeTolerance = 6,
	DefaultRespawn = 3,
}

--------------------------------------------------------------------------------
-- Belts & martial ranks (ordered; must be bought in sequence)
--------------------------------------------------------------------------------

Config.Belts = {
	{
		Id = "White",
		Name = "White Belt",
		Multiplier = 1,
		RequiredPower = 0,
		Cost = 0,
		Color = Color3.fromRGB(245, 245, 245),
	},
	{
		Id = "Yellow",
		Name = "Yellow Belt",
		Multiplier = 2,
		RequiredPower = 100,
		Cost = 50,
		Color = Color3.fromRGB(255, 214, 51),
	},
	{
		Id = "Orange",
		Name = "Orange Belt",
		Multiplier = 3,
		RequiredPower = 1_000,
		Cost = 400,
		Color = Color3.fromRGB(255, 140, 26),
	},
	{
		Id = "Green",
		Name = "Green Belt",
		Multiplier = 5,
		RequiredPower = 10_000,
		Cost = 3_000,
		Color = Color3.fromRGB(60, 200, 80),
	},
	{
		Id = "Blue",
		Name = "Blue Belt",
		Multiplier = 7,
		RequiredPower = 100_000,
		Cost = 25_000,
		Color = Color3.fromRGB(40, 120, 255),
	},
	{
		Id = "Black",
		Name = "Black Belt",
		Multiplier = 10,
		RequiredPower = 1_000_000,
		Cost = 250_000,
		Color = Color3.fromRGB(25, 25, 30),
		Stripe = Color3.fromRGB(255, 200, 40),
	},
	{
		Id = "DragonMaster",
		Name = "Dragon Master",
		Multiplier = 25,
		RequiredPower = 50_000_000,
		Cost = 5_000_000,
		Color = Color3.fromRGB(255, 190, 30),
		Stripe = Color3.fromRGB(220, 30, 30),
		Glow = true,
	},
}

--------------------------------------------------------------------------------
-- Hand auras & gloves
--------------------------------------------------------------------------------

local P = Config.Assets.Particles

Config.Auras = {
	{
		Id = "FirePalms",
		Name = "Fire Palms",
		Description = "Blazing palms that scorch anything they touch.",
		Cost = 1_000,
		RequiredRebirths = 0,
		PowerMultiplier = 1.5,
		CritChance = 0.05,
		Color = Color3.fromRGB(255, 110, 30),
		Particle = {
			Texture = P.Fire,
			Colors = { Color3.fromRGB(255, 220, 80), Color3.fromRGB(255, 70, 20) },
			Size = 0.9,
			Rate = 35,
			Speed = 2,
			Lifetime = 0.6,
		},
	},
	{
		Id = "FrostFists",
		Name = "Frost Fists",
		Description = "Icy knuckles that freeze before they shatter.",
		Cost = 12_000,
		RequiredRebirths = 0,
		PowerMultiplier = 2,
		CritChance = 0.07,
		Color = Color3.fromRGB(120, 220, 255),
		Particle = {
			Texture = P.Sparkle,
			Colors = { Color3.fromRGB(230, 250, 255), Color3.fromRGB(90, 190, 255) },
			Size = 0.6,
			Rate = 30,
			Speed = 1.5,
			Lifetime = 0.8,
		},
	},
	{
		Id = "LightningHands",
		Name = "Lightning Hands",
		Description = "Crackling voltage for lightning-fast crits.",
		Cost = 90_000,
		RequiredRebirths = 1,
		PowerMultiplier = 3,
		CritChance = 0.1,
		Color = Color3.fromRGB(255, 240, 70),
		Particle = {
			Texture = P.Sparkle,
			Colors = { Color3.fromRGB(255, 255, 200), Color3.fromRGB(80, 160, 255) },
			Size = 0.8,
			Rate = 60,
			Speed = 6,
			Lifetime = 0.25,
		},
	},
	{
		Id = "JadeChi",
		Name = "Jade Chi",
		Description = "Ancient temple energy flows through your palms.",
		Cost = 750_000,
		RequiredRebirths = 2,
		PowerMultiplier = 4,
		CritChance = 0.12,
		Color = Color3.fromRGB(60, 230, 140),
		Particle = {
			Texture = P.Smoke,
			Colors = { Color3.fromRGB(180, 255, 210), Color3.fromRGB(30, 200, 110) },
			Size = 1,
			Rate = 25,
			Speed = 1,
			Lifetime = 1,
		},
	},
	{
		Id = "VoidBlades",
		Name = "Void Blades",
		Description = "Hands sharpened by the emptiness between stars.",
		Cost = 8_000_000,
		RequiredRebirths = 3,
		PowerMultiplier = 6,
		CritChance = 0.15,
		Color = Color3.fromRGB(150, 60, 255),
		Particle = {
			Texture = P.Smoke,
			Colors = { Color3.fromRGB(200, 120, 255), Color3.fromRGB(40, 0, 80) },
			Size = 1.1,
			Rate = 40,
			Speed = 2.5,
			Lifetime = 0.7,
		},
	},
	{
		Id = "GalaxyPalms",
		Name = "Galaxy Palms",
		Description = "Every chop carries the weight of a galaxy.",
		Cost = 150_000_000,
		RequiredRebirths = 6,
		PowerMultiplier = 10,
		CritChance = 0.2,
		Color = Color3.fromRGB(255, 100, 220),
		Particle = {
			Texture = P.Sparkle,
			Colors = { Color3.fromRGB(255, 140, 240), Color3.fromRGB(80, 120, 255) },
			Size = 1,
			Rate = 70,
			Speed = 3,
			Lifetime = 0.9,
		},
	},
}

--------------------------------------------------------------------------------
-- Coin upgrades
--------------------------------------------------------------------------------

Config.Upgrades = {
	{
		Id = "IronPalms",
		Name = "Iron Palms",
		Icon = "✋",
		Description = "+1 base power per chop",
		BaseCost = 20,
		CostGrowth = 1.45,
		MaxLevel = 100,
		PerLevel = 1,
	},
	{
		Id = "Focus",
		Name = "Inner Focus",
		Icon = "🎯",
		Description = "+1% critical chop chance",
		BaseCost = 150,
		CostGrowth = 1.6,
		MaxLevel = 25,
		PerLevel = 0.01,
	},
	{
		Id = "Greed",
		Name = "Golden Touch",
		Icon = "🪙",
		Description = "+10% coins from smashing",
		BaseCost = 100,
		CostGrowth = 1.55,
		MaxLevel = 50,
		PerLevel = 0.1,
	},
	{
		Id = "Speed",
		Name = "Swift Strikes",
		Icon = "⚡",
		Description = "Auto-Chop swings faster",
		BaseCost = 250,
		CostGrowth = 2.1,
		MaxLevel = 10,
		PerLevel = 0.04,
	},
}

--------------------------------------------------------------------------------
-- Rebirths
--------------------------------------------------------------------------------

Config.Rebirth = {
	BaseCost = 10_000, -- Power needed for the first rebirth
	CostGrowth = 5, -- each rebirth costs 5x more
	MultiplierPerRebirth = 1, -- permanent power multiplier: 1 + rebirths * this
	CoinBonusPerRebirth = 0.25, -- permanent coin multiplier: 1 + rebirths * this
}

--------------------------------------------------------------------------------
-- Breakable objects
--	Shape: see server/Modules/Shapes.luau
--	Size: bounding box in studs; Grid: number of fracture segments along X/Y/Z
--	Stand: "Supports" | "Pedestal" | "Float"
--	Tier: drives camera shake / debris speed (1..5)
--------------------------------------------------------------------------------

Config.Breakables = {
	-- Starter Dojo -------------------------------------------------------------
	WoodenBoard = {
		Name = "Wooden Board",
		RequiredPower = 50,
		Coins = 5,
		Respawn = 2.5,
		Tier = 1,
		Shape = "Box",
		Size = Vector3.new(7, 0.8, 3),
		Grid = Vector3.new(5, 1, 2),
		Material = Enum.Material.Plastic,
		Colors = { Color3.fromRGB(214, 152, 92), Color3.fromRGB(196, 136, 78), Color3.fromRGB(226, 168, 108) },
		Stand = "Supports",
	},
	BrickStack = {
		Name = "Brick Stack",
		RequiredPower = 500,
		Coins = 30,
		Respawn = 3,
		Tier = 1,
		Shape = "Box",
		Size = Vector3.new(5, 3.6, 2.4),
		Grid = Vector3.new(2, 3, 1),
		Material = Enum.Material.Plastic,
		Colors = { Color3.fromRGB(196, 72, 56), Color3.fromRGB(176, 60, 46), Color3.fromRGB(214, 90, 70) },
		Stand = "Pedestal",
	},
	IronAnvil = {
		Name = "Iron Anvil",
		RequiredPower = 5_000,
		Coins = 150,
		Respawn = 3,
		Tier = 2,
		Shape = "Anvil",
		Size = Vector3.new(6.4, 4.2, 3.2),
		Grid = Vector3.new(8, 6, 4),
		Hollow = true,
		Material = Enum.Material.Plastic,
		Colors = { Color3.fromRGB(88, 92, 104), Color3.fromRGB(78, 82, 94) },
		AccentColor = Color3.fromRGB(190, 196, 210),
		Stand = "Pedestal",
	},

	-- Shaolin Temple -----------------------------------------------------------
	StonePillar = {
		Name = "Stone Pillar",
		RequiredPower = 25_000,
		Coins = 600,
		Respawn = 3,
		Tier = 2,
		Shape = "Pillar",
		Size = Vector3.new(4, 7, 4),
		Grid = Vector3.new(4, 7, 4),
		Hollow = true,
		Material = Enum.Material.Plastic,
		Colors = { Color3.fromRGB(170, 166, 150), Color3.fromRGB(150, 146, 132) },
		AccentColor = Color3.fromRGB(230, 180, 50),
		Stand = "Pedestal",
	},
	SteelBeam = {
		Name = "Steel Beam",
		RequiredPower = 100_000,
		Coins = 2_000,
		Respawn = 3,
		Tier = 3,
		Shape = "IBeam",
		Size = Vector3.new(11, 3, 2.4),
		Grid = Vector3.new(6, 5, 3),
		Material = Enum.Material.Plastic,
		Colors = { Color3.fromRGB(110, 120, 134), Color3.fromRGB(96, 106, 120) },
		Stand = "Supports",
	},
	DiamondBlock = {
		Name = "Diamond Block",
		RequiredPower = 500_000,
		Coins = 8_000,
		Respawn = 3.5,
		Tier = 3,
		Shape = "Box",
		Size = Vector3.new(4.5, 4.5, 4.5),
		Grid = Vector3.new(3, 3, 3),
		Hollow = true,
		Material = Enum.Material.Glass,
		Transparency = 0.15,
		Colors = { Color3.fromRGB(120, 230, 255), Color3.fromRGB(150, 240, 255), Color3.fromRGB(100, 210, 245) },
		AccentColor = Color3.fromRGB(255, 255, 255),
		AccentMaterial = Enum.Material.Neon,
		AccentChance = 0.12,
		Stand = "Pedestal",
	},

	-- Cyber Dojo ---------------------------------------------------------------
	ServerRack = {
		Name = "Titanium Server Rack",
		RequiredPower = 2_500_000,
		Coins = 30_000,
		Respawn = 3.5,
		Tier = 3,
		Shape = "Rack",
		Size = Vector3.new(4, 7.2, 3),
		Grid = Vector3.new(3, 6, 2),
		Material = Enum.Material.Plastic,
		Colors = { Color3.fromRGB(40, 44, 56), Color3.fromRGB(32, 36, 46) },
		AccentColor = Color3.fromRGB(40, 255, 160),
		AccentMaterial = Enum.Material.Neon,
		Stand = "Pedestal",
	},
	NeonCrystal = {
		Name = "Neon Crystal",
		RequiredPower = 12_000_000,
		Coins = 120_000,
		Respawn = 4,
		Tier = 4,
		Shape = "Crystal",
		Size = Vector3.new(5, 9, 5),
		Grid = Vector3.new(5, 9, 5),
		Hollow = true,
		Material = Enum.Material.Glass,
		Transparency = 0.1,
		Colors = { Color3.fromRGB(255, 60, 200), Color3.fromRGB(220, 40, 255) },
		AccentColor = Color3.fromRGB(255, 180, 250),
		AccentMaterial = Enum.Material.Neon,
		AccentChance = 0.2,
		Stand = "Float",
	},
	MechCore = {
		Name = "Mech Reactor Core",
		RequiredPower = 60_000_000,
		Coins = 500_000,
		Respawn = 4,
		Tier = 4,
		Shape = "MechCore",
		Size = Vector3.new(7, 7, 7),
		Grid = Vector3.new(6, 6, 6),
		Hollow = true,
		Material = Enum.Material.Plastic,
		Colors = { Color3.fromRGB(70, 76, 90), Color3.fromRGB(56, 60, 72) },
		AccentColor = Color3.fromRGB(255, 50, 60),
		AccentMaterial = Enum.Material.Neon,
		Stand = "Float",
	},

	-- Cosmic Void --------------------------------------------------------------
	Meteorite = {
		Name = "Meteorite",
		RequiredPower = 300_000_000,
		Coins = 2_500_000,
		Respawn = 4,
		Tier = 4,
		Shape = "Meteorite",
		Size = Vector3.new(7, 7, 7),
		Grid = Vector3.new(6, 6, 6),
		Hollow = true,
		Material = Enum.Material.Plastic,
		Colors = { Color3.fromRGB(60, 52, 50), Color3.fromRGB(78, 66, 60), Color3.fromRGB(48, 42, 42) },
		AccentColor = Color3.fromRGB(255, 120, 30),
		AccentMaterial = Enum.Material.Neon,
		Stand = "Float",
	},
	Moon = {
		Name = "Moon",
		RequiredPower = 2_000_000_000,
		Coins = 15_000_000,
		Respawn = 5,
		Tier = 5,
		Shape = "Moon",
		Size = Vector3.new(9, 9, 9),
		Grid = Vector3.new(7, 7, 7),
		Hollow = true,
		Material = Enum.Material.Plastic,
		Colors = { Color3.fromRGB(200, 200, 196), Color3.fromRGB(184, 184, 180) },
		AccentColor = Color3.fromRGB(130, 130, 128),
		Stand = "Float",
	},
	Planet = {
		Name = "Planet",
		RequiredPower = 15_000_000_000,
		Coins = 100_000_000,
		Respawn = 6,
		Tier = 5,
		Shape = "Planet",
		Size = Vector3.new(16, 8, 16),
		Grid = Vector3.new(11, 7, 11),
		Hollow = true,
		Material = Enum.Material.Plastic,
		Colors = { Color3.fromRGB(60, 130, 255), Color3.fromRGB(70, 145, 255) },
		AltColor = Color3.fromRGB(70, 190, 90),
		AccentColor = Color3.fromRGB(240, 200, 120),
		Stand = "Float",
	},
}

--------------------------------------------------------------------------------
-- Training dojos (unlocked by rebirths)
--------------------------------------------------------------------------------

Config.Dojos = {
	{
		Id = "Starter",
		Name = "Starter Dojo",
		RequiredRebirths = 0,
		TrainingMultiplier = 1,
		Origin = Vector3.new(0, 0, 0),
		Size = Vector3.new(170, 0, 130),
		Objects = { "WoodenBoard", "BrickStack", "IronAnvil" },
		Colors = {
			Floor = Color3.fromRGB(226, 196, 140),
			Mat = Color3.fromRGB(110, 170, 90),
			MatAlt = Color3.fromRGB(150, 200, 110),
			Wall = Color3.fromRGB(150, 98, 60),
			Trim = Color3.fromRGB(196, 40, 40),
			Accent = Color3.fromRGB(255, 205, 60),
		},
		Lighting = {
			ClockTime = 14,
			Ambient = Color3.fromRGB(110, 100, 90),
			OutdoorAmbient = Color3.fromRGB(150, 140, 125),
			AtmosphereColor = Color3.fromRGB(200, 215, 230),
			AtmosphereDecay = Color3.fromRGB(120, 140, 170),
			AtmosphereDensity = 0.3,
			Tint = Color3.fromRGB(255, 250, 240),
		},
	},
	{
		Id = "Shaolin",
		Name = "Shaolin Temple",
		RequiredRebirths = 1,
		TrainingMultiplier = 2,
		Origin = Vector3.new(1000, 0, 0),
		Size = Vector3.new(170, 0, 130),
		Objects = { "StonePillar", "SteelBeam", "DiamondBlock" },
		Colors = {
			Floor = Color3.fromRGB(150, 140, 128),
			Mat = Color3.fromRGB(190, 50, 40),
			MatAlt = Color3.fromRGB(220, 170, 60),
			Wall = Color3.fromRGB(180, 36, 30),
			Trim = Color3.fromRGB(240, 190, 50),
			Accent = Color3.fromRGB(40, 140, 80),
		},
		Lighting = {
			ClockTime = 17.2,
			Ambient = Color3.fromRGB(120, 90, 70),
			OutdoorAmbient = Color3.fromRGB(170, 130, 100),
			AtmosphereColor = Color3.fromRGB(255, 200, 150),
			AtmosphereDecay = Color3.fromRGB(200, 120, 90),
			AtmosphereDensity = 0.35,
			Tint = Color3.fromRGB(255, 235, 210),
		},
	},
	{
		Id = "Cyber",
		Name = "Cyber Dojo",
		RequiredRebirths = 3,
		TrainingMultiplier = 5,
		Origin = Vector3.new(2000, 0, 0),
		Size = Vector3.new(170, 0, 130),
		Objects = { "ServerRack", "NeonCrystal", "MechCore" },
		Colors = {
			Floor = Color3.fromRGB(30, 32, 44),
			Mat = Color3.fromRGB(20, 210, 255),
			MatAlt = Color3.fromRGB(255, 40, 200),
			Wall = Color3.fromRGB(44, 48, 64),
			Trim = Color3.fromRGB(20, 230, 255),
			Accent = Color3.fromRGB(255, 50, 200),
		},
		Lighting = {
			ClockTime = 20.5,
			Ambient = Color3.fromRGB(70, 60, 110),
			OutdoorAmbient = Color3.fromRGB(80, 70, 130),
			AtmosphereColor = Color3.fromRGB(120, 80, 200),
			AtmosphereDecay = Color3.fromRGB(40, 20, 90),
			AtmosphereDensity = 0.4,
			Tint = Color3.fromRGB(230, 225, 255),
		},
	},
	{
		Id = "Cosmic",
		Name = "Cosmic Void",
		RequiredRebirths = 6,
		TrainingMultiplier = 15,
		Origin = Vector3.new(3000, 120, 0),
		Size = Vector3.new(170, 0, 130),
		Objects = { "Meteorite", "Moon", "Planet" },
		Colors = {
			Floor = Color3.fromRGB(36, 24, 64),
			Mat = Color3.fromRGB(120, 60, 255),
			MatAlt = Color3.fromRGB(60, 30, 140),
			Wall = Color3.fromRGB(24, 16, 44),
			Trim = Color3.fromRGB(180, 120, 255),
			Accent = Color3.fromRGB(255, 120, 230),
		},
		Lighting = {
			ClockTime = 0,
			Ambient = Color3.fromRGB(70, 50, 110),
			OutdoorAmbient = Color3.fromRGB(60, 40, 100),
			AtmosphereColor = Color3.fromRGB(60, 30, 120),
			AtmosphereDecay = Color3.fromRGB(10, 0, 30),
			AtmosphereDensity = 0.25,
			Tint = Color3.fromRGB(235, 225, 255),
		},
	},
}

--------------------------------------------------------------------------------
-- Data
--------------------------------------------------------------------------------

Config.Data = {
	SchemaVersion = 1,
	AutosaveInterval = 60,
	-- A session lock older than this (seconds) is considered abandoned by a crashed server.
	SessionLockExpiry = 300,
	LoadRetries = 6,
	LoadRetryDelay = 4,
}

return Config
