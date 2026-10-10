--[[
	Config.luau
	Every tunable number, colour, layout coordinate and asset id for "+1 Kung Fu Chop!".
	Shared by the server (authoritative math), the client (display) and the map baker.

	Game loop (one big studded hub, like +1 Stone Skipping):
	  1. Train  – stand on the pad of a training floor (right side): your character chops that
	              floor's item (boards, bamboo, ice, bricks...) over and over for +Strength. This
	              is the only way to gain Strength. Better floors unlock with rebirths or Robux.
	  2. Smash  – step on the launch pad and charge down the Board Wall lane. You break every wall
	              your Strength can handle; each broken wall pays Wins.
	  3. Equip  – Wins unlock better hand wraps / gauntlets (left side) that add more per chop.
	  4. Hatch  – spend Wins on eggs for pets that multiply your Strength.
	  5. Rebirth – at max level, reset Strength for a permanent multiplier and new zones.
]]

local Config = {}

Config.GameName = "+1 Kung Fu Chop!"
Config.DataStoreName = "KungFuChop_PlayerData_v2"

--------------------------------------------------------------------------------
-- Assets
--------------------------------------------------------------------------------

Config.Assets = {
	-- Square stud tile (assets/textures/stud_overlay.png): the raised rounded-square studs with a
	-- dark "L" bevel seen in Steal an Egg / Stone Skipping. Upload it with Studio's Asset Manager
	-- (Bulk Import), right-click → Copy Asset ID, and paste "rbxassetid://<id>" here (see README:
	-- a *decal* id from the website is not the image id). The same asset drives the UI panels and
	-- every 3D surface. Empty string = fallback (procedural square studs in the UI, classic
	-- SurfaceType.Studs on parts) so the place still runs before uploading.
	StudTexture = "",

	-- Optional (assets/textures/checker_overlay.png): darkens alternating 4x4-stud squares on
	-- large floors. The hub ground is already built from checkered tiles, so this is a bonus.
	CheckerTexture = "",
	CheckerStudsPerTile = 8,

	-- Exact tile size used for the "Steal an Egg" studded UI background.
	StudTileSize = UDim2.new(0, 32, 0, 32),
	StudImageTransparency = 0.15, -- UI stud overlay strength (0 = full)
	StudPartTransparency = 0, -- 3D stud overlay strength (0 = full)

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
-- Training
--------------------------------------------------------------------------------

Config.Training = {
	-- Strength only comes from the training floors: stand on a floor's pad and every
	-- IdleInterval seconds you chop that floor's item for one chop's Strength.
	IdleInterval = 0.6,
}

-- Auto Smash game pass: while it's switched on you farm the Board Wall lane hands-free. From
-- wherever you are, you launch from the pad, smash as far as your Strength goes, land back on
-- the pad, and the next run starts this many seconds later.
Config.AutoSmash = {
	Delay = 1.5,
}

-- Training floors, side by side on the right of the hub (see MapBuilder), like the ponds in
-- Stone Skipping: a small pool with one pad at the near end. Stand on the pad to train; other
-- players on the same pad are hidden for you, so it feels like your own floor. Better floors
-- unlock with rebirths (RequiredRebirths) or a game pass (Pass). Your chop breaks the floor's
-- Breakable on the pillar in front of the pad (Kind picks the model in MapBuilder, Material is
-- an Enum.Material name).
Config.TrainingZones = {
	{
		Id = "Wooden",
		Name = "Wooden Dojo",
		Multiplier = 1,
		RequiredRebirths = 0,
		Floor = Color3.fromRGB(226, 170, 96),
		Trim = Color3.fromRGB(150, 98, 52),
		Accent = Color3.fromRGB(110, 210, 255),
		Breakable = {
			Name = "Wooden Boards",
			Kind = "Planks",
			Color = Color3.fromRGB(240, 206, 150),
			Material = "Wood",
		},
	},
	{
		Id = "Bamboo",
		Name = "Bamboo Garden",
		Multiplier = 4,
		RequiredRebirths = 2,
		Floor = Color3.fromRGB(70, 200, 150),
		Trim = Color3.fromRGB(30, 140, 100),
		Accent = Color3.fromRGB(170, 255, 140),
		Breakable = {
			Name = "Bamboo",
			Kind = "Bamboo",
			Color = Color3.fromRGB(140, 205, 80),
			Material = "SmoothPlastic",
		},
	},
	{
		Id = "Waterfall",
		Name = "Waterfall Shrine",
		Multiplier = 10,
		RequiredRebirths = 4,
		Floor = Color3.fromRGB(150, 110, 255),
		Trim = Color3.fromRGB(100, 70, 200),
		Accent = Color3.fromRGB(110, 230, 255),
		Breakable = { Name = "Ice Blocks", Kind = "Ice", Color = Color3.fromRGB(170, 222, 255), Material = "Ice" },
	},
	{
		Id = "Lava",
		Name = "Lava Pit",
		Multiplier = 20,
		RequiredRebirths = 6,
		Floor = Color3.fromRGB(240, 240, 250),
		Trim = Color3.fromRGB(200, 200, 215),
		Accent = Color3.fromRGB(255, 110, 40),
		Breakable = { Name = "Bricks", Kind = "Bricks", Color = Color3.fromRGB(196, 72, 52), Material = "Brick" },
	},
	{
		Id = "Golden",
		Name = "Golden Temple",
		Multiplier = 30,
		Pass = "GoldenZone",
		Floor = Color3.fromRGB(70, 110, 220),
		Trim = Color3.fromRGB(200, 70, 60),
		Accent = Color3.fromRGB(255, 200, 60),
		Breakable = { Name = "Gold Bars", Kind = "GoldBars", Color = Color3.fromRGB(255, 196, 40), Material = "Foil" },
	},
	{
		Id = "Dragon",
		Name = "Dragon Sanctum",
		Multiplier = 75,
		Pass = "DragonZone",
		Floor = Color3.fromRGB(255, 200, 40),
		Trim = Color3.fromRGB(200, 140, 20),
		Accent = Color3.fromRGB(255, 80, 60),
		Breakable = { Name = "Obsidian", Kind = "Obsidian", Color = Color3.fromRGB(42, 32, 50), Material = "Slate" },
	},
	{
		Id = "Cosmic",
		Name = "Cosmic Dojo",
		Multiplier = 200,
		Pass = "CosmicZone",
		Floor = Color3.fromRGB(24, 26, 34),
		Trim = Color3.fromRGB(40, 255, 120),
		Accent = Color3.fromRGB(40, 255, 120),
		Breakable = {
			Name = "Star Crystals",
			Kind = "Crystal",
			Color = Color3.fromRGB(60, 255, 150),
			Material = "Neon",
		},
	},
}

--------------------------------------------------------------------------------
-- Hand items (the "shells" of Stone Skipping): unlocked by lifetime Wins, equip one.
-- Bonus = Strength per chop before multipliers.
--------------------------------------------------------------------------------

Config.HandItems = {
	{ Id = "BareFists", Name = "Bare Fists", Bonus = 1, Wins = 0, Color = Color3.fromRGB(234, 184, 146) },
	{ Id = "ClothWraps", Name = "Cloth Wraps", Bonus = 3, Wins = 2, Color = Color3.fromRGB(245, 245, 240) },
	{ Id = "LeatherWraps", Name = "Leather Wraps", Bonus = 5, Wins = 10, Color = Color3.fromRGB(150, 96, 60) },
	{ Id = "TrainingGloves", Name = "Training Gloves", Bonus = 12, Wins = 40, Color = Color3.fromRGB(220, 50, 50) },
	{ Id = "IronKnuckles", Name = "Iron Knuckles", Bonus = 30, Wins = 150, Color = Color3.fromRGB(140, 146, 160) },
	{ Id = "BambooBracers", Name = "Bamboo Bracers", Bonus = 75, Wins = 500, Color = Color3.fromRGB(120, 200, 80) },
	{ Id = "JadeGauntlets", Name = "Jade Gauntlets", Bonus = 200, Wins = 1_500, Color = Color3.fromRGB(40, 190, 130) },
	{
		Id = "GoldenGauntlets",
		Name = "Golden Gauntlets",
		Bonus = 500,
		Wins = 4_500,
		Color = Color3.fromRGB(255, 200, 40),
	},
	{
		Id = "LavaFists",
		Name = "Lava Fists",
		Bonus = 1_250,
		Wins = 14_000,
		Color = Color3.fromRGB(255, 90, 30),
		Glow = true,
	},
	{
		Id = "FrostClaws",
		Name = "Frost Claws",
		Bonus = 3_500,
		Wins = 40_000,
		Color = Color3.fromRGB(120, 220, 255),
		Glow = true,
	},
	{
		Id = "ThunderFists",
		Name = "Thunder Fists",
		Bonus = 10_000,
		Wins = 125_000,
		Color = Color3.fromRGB(255, 240, 80),
		Glow = true,
	},
	{
		Id = "DragonClaws",
		Name = "Dragon Claws",
		Bonus = 30_000,
		Wins = 400_000,
		Color = Color3.fromRGB(220, 40, 60),
		Glow = true,
	},
	{
		Id = "VoidGauntlets",
		Name = "Void Gauntlets",
		Bonus = 100_000,
		Wins = 1_250_000,
		Color = Color3.fromRGB(140, 60, 255),
		Glow = true,
	},
	{
		Id = "CelestialPalms",
		Name = "Celestial Palms",
		Bonus = 300_000,
		Wins = 4_000_000,
		Color = Color3.fromRGB(255, 120, 230),
		Glow = true,
	},
}

-- Game-pass item: always better than your best unlocked item.
Config.PremiumItem = {
	Id = "PhoenixRelic",
	Name = "Phoenix Relic",
	Pass = "PhoenixRelic",
	BetterBy = 1.25, -- +125% over your best unlocked item
	Color = Color3.fromRGB(255, 120, 30),
	Glow = true,
}

--------------------------------------------------------------------------------
-- The Board Wall lane (runs from the launch pad toward +Z)
--------------------------------------------------------------------------------

Config.Lane = {
	PadPosition = Vector3.new(0, 0, 70),
	PadRadius = 12,
	FirstWallZ = 110,
	WallSpacing = 16,
	WallsPerBiome = 25,
	Width = 40,
	WallHeight = 12,
	FinishOvershoot = 30, -- studs past the last wall when everything is broken

	-- Wall n needs BaseToughness * ToughnessGrowth^(n-1) Strength to break.
	BaseToughness = 10,
	ToughnessGrowth = 1.15,

	-- Run timing (client animation length; the server blocks new runs until it ends).
	MinDuration = 2.5,
	MaxDuration = 11,
	StudsPerSecond = 320,
	Cooldown = 1.5,
}

Config.Biomes = {
	{
		Id = "Bamboo",
		Name = "Bamboo Grove",
		WinsPerWall = 1,
		Wall = { Color3.fromRGB(214, 152, 92), Color3.fromRGB(196, 136, 78) },
		WallMaterial = Enum.Material.Plastic,
		Ground = { Color3.fromRGB(96, 200, 70), Color3.fromRGB(80, 184, 60) },
		Rail = { Color3.fromRGB(150, 98, 52), Color3.fromRGB(176, 118, 66) },
		Tree = { Trunk = Color3.fromRGB(130, 90, 50), Leaves = Color3.fromRGB(110, 220, 70) },
		Title = Color3.fromRGB(140, 255, 110),
	},
	{
		Id = "Autumn",
		Name = "Autumn Temple",
		WinsPerWall = 3,
		Wall = { Color3.fromRGB(196, 72, 56), Color3.fromRGB(176, 60, 46) },
		WallMaterial = Enum.Material.Plastic,
		Ground = { Color3.fromRGB(240, 170, 70), Color3.fromRGB(226, 150, 56) },
		Rail = { Color3.fromRGB(220, 120, 50), Color3.fromRGB(240, 150, 70) },
		Tree = { Trunk = Color3.fromRGB(120, 76, 44), Leaves = Color3.fromRGB(255, 140, 40) },
		Title = Color3.fromRGB(255, 170, 60),
	},
	{
		Id = "Frost",
		Name = "Frost Peak",
		WinsPerWall = 10,
		Wall = { Color3.fromRGB(150, 220, 255), Color3.fromRGB(180, 235, 255) },
		WallMaterial = Enum.Material.Glass,
		Ground = { Color3.fromRGB(235, 245, 255), Color3.fromRGB(215, 232, 250) },
		Rail = { Color3.fromRGB(150, 200, 240), Color3.fromRGB(190, 225, 250) },
		Tree = { Trunk = Color3.fromRGB(110, 90, 80), Leaves = Color3.fromRGB(230, 245, 255) },
		Title = Color3.fromRGB(150, 230, 255),
	},
	{
		Id = "Lava",
		Name = "Lava Fortress",
		WinsPerWall = 30,
		Wall = { Color3.fromRGB(46, 40, 44), Color3.fromRGB(60, 50, 54) },
		WallMaterial = Enum.Material.Plastic,
		WallAccent = Color3.fromRGB(255, 100, 30),
		Ground = { Color3.fromRGB(70, 56, 56), Color3.fromRGB(56, 44, 46) },
		Rail = { Color3.fromRGB(255, 90, 30), Color3.fromRGB(200, 60, 20) },
		Tree = { Trunk = Color3.fromRGB(40, 30, 30), Leaves = Color3.fromRGB(255, 90, 30) },
		Title = Color3.fromRGB(255, 110, 50),
	},
	{
		Id = "Sky",
		Name = "Sky Palace",
		WinsPerWall = 100,
		Wall = { Color3.fromRGB(250, 250, 255), Color3.fromRGB(235, 235, 245) },
		WallMaterial = Enum.Material.Plastic,
		WallAccent = Color3.fromRGB(255, 205, 60),
		Ground = { Color3.fromRGB(200, 230, 255), Color3.fromRGB(180, 215, 250) },
		Rail = { Color3.fromRGB(255, 210, 70), Color3.fromRGB(255, 235, 140) },
		Tree = { Trunk = Color3.fromRGB(230, 220, 200), Leaves = Color3.fromRGB(255, 190, 230) },
		Title = Color3.fromRGB(255, 220, 90),
	},
	{
		Id = "Cosmic",
		Name = "Cosmic Rift",
		WinsPerWall = 300,
		Wall = { Color3.fromRGB(150, 70, 255), Color3.fromRGB(110, 40, 220) },
		WallMaterial = Enum.Material.Glass,
		WallAccent = Color3.fromRGB(255, 120, 240),
		Ground = { Color3.fromRGB(40, 26, 70), Color3.fromRGB(30, 20, 56) },
		Rail = { Color3.fromRGB(180, 120, 255), Color3.fromRGB(110, 60, 220) },
		Tree = { Trunk = Color3.fromRGB(60, 40, 90), Leaves = Color3.fromRGB(120, 255, 230) },
		Title = Color3.fromRGB(200, 140, 255),
	},
}

--------------------------------------------------------------------------------
-- Eggs & pets
--------------------------------------------------------------------------------

Config.Rarities = {
	Common = { Order = 1, Color = Color3.fromRGB(210, 210, 220) },
	Uncommon = { Order = 2, Color = Color3.fromRGB(90, 220, 90) },
	Rare = { Order = 3, Color = Color3.fromRGB(70, 160, 255) },
	Epic = { Order = 4, Color = Color3.fromRGB(180, 90, 255) },
	Legendary = { Order = 5, Color = Color3.fromRGB(255, 190, 40) },
	Mythic = { Order = 6, Color = Color3.fromRGB(255, 70, 110) },
	Secret = { Order = 7, Color = Color3.fromRGB(255, 255, 255) },
}

local function pet(
	name: string,
	rarity: string,
	bonus: number,
	shape: string,
	body: Color3,
	accent: Color3,
	extra: { [string]: any }?
): { [string]: any }
	local def = { Name = name, Rarity = rarity, Bonus = bonus, Shape = shape, Body = body, Accent = accent }
	if extra then
		for key, value in extra do
			def[key] = value
		end
	end
	return def
end

-- Pet Bonus adds to the Strength multiplier: equipped pets give x(1 + sum of bonuses).
-- Shape: Dog | Cat | Bunny | Bear | Bird | Dragon | Unicorn | Lion (see shared/PetModels.luau)
Config.Pets = {
	Puppy = pet("Puppy", "Common", 0.1, "Dog", Color3.fromRGB(210, 160, 110), Color3.fromRGB(150, 100, 60)),
	Kitty = pet("Kitty", "Common", 0.12, "Cat", Color3.fromRGB(240, 240, 240), Color3.fromRGB(255, 170, 190)),
	Bunny = pet("Bunny", "Uncommon", 0.2, "Bunny", Color3.fromRGB(255, 220, 230), Color3.fromRGB(255, 150, 180)),
	Panda = pet("Panda", "Rare", 0.35, "Bear", Color3.fromRGB(245, 245, 245), Color3.fromRGB(30, 30, 30)),

	Fox = pet("Fox", "Uncommon", 0.3, "Cat", Color3.fromRGB(240, 130, 40), Color3.fromRGB(255, 245, 235)),
	Monkey = pet("Monkey", "Uncommon", 0.4, "Bear", Color3.fromRGB(150, 100, 60), Color3.fromRGB(240, 200, 160)),
	Tiger = pet("Tiger", "Rare", 0.7, "Cat", Color3.fromRGB(255, 150, 30), Color3.fromRGB(30, 30, 30)),
	GoldenPanda = pet(
		"Golden Panda",
		"Epic",
		1.2,
		"Bear",
		Color3.fromRGB(255, 210, 60),
		Color3.fromRGB(150, 100, 20),
		{ Glow = true }
	),

	Owl = pet("Owl", "Rare", 0.9, "Bird", Color3.fromRGB(150, 110, 80), Color3.fromRGB(255, 220, 120)),
	Crane = pet("Crane", "Rare", 1.3, "Bird", Color3.fromRGB(250, 250, 250), Color3.fromRGB(230, 40, 40)),
	SnowLeopard = pet("Snow Leopard", "Epic", 2, "Cat", Color3.fromRGB(235, 240, 250), Color3.fromRGB(110, 120, 140)),
	JadeDragon = pet(
		"Jade Dragon",
		"Legendary",
		4,
		"Dragon",
		Color3.fromRGB(40, 200, 120),
		Color3.fromRGB(255, 220, 80),
		{ Glow = true }
	),

	RedPanda = pet("Red Panda", "Epic", 3, "Bear", Color3.fromRGB(200, 70, 40), Color3.fromRGB(250, 240, 230)),
	Kirin = pet("Kirin", "Epic", 5, "Unicorn", Color3.fromRGB(255, 230, 150), Color3.fromRGB(80, 200, 255)),
	ThunderTiger = pet(
		"Thunder Tiger",
		"Legendary",
		9,
		"Cat",
		Color3.fromRGB(60, 80, 200),
		Color3.fromRGB(255, 240, 80),
		{ Glow = true }
	),
	ShadowDragon = pet(
		"Shadow Dragon",
		"Mythic",
		20,
		"Dragon",
		Color3.fromRGB(40, 30, 60),
		Color3.fromRGB(180, 70, 255),
		{ Glow = true }
	),

	RainbowUnicorn = pet(
		"Rainbow Unicorn",
		"Legendary",
		6,
		"Unicorn",
		Color3.fromRGB(255, 255, 255),
		Color3.fromRGB(255, 120, 220),
		{ Glow = true }
	),
	GalaxyCat = pet(
		"Galaxy Cat",
		"Mythic",
		15,
		"Cat",
		Color3.fromRGB(70, 40, 160),
		Color3.fromRGB(120, 255, 255),
		{ Glow = true }
	),
	DragonKing = pet(
		"Dragon King",
		"Secret",
		50,
		"Dragon",
		Color3.fromRGB(255, 200, 40),
		Color3.fromRGB(230, 30, 40),
		{ Glow = true }
	),

	-- Game-pass pet ("Best in game"): always 1000% better than your best other pet.
	LionKing = pet(
		"Lion King",
		"Secret",
		10,
		"Lion",
		Color3.fromRGB(240, 180, 70),
		Color3.fromRGB(200, 60, 50),
		{ Glow = true, Pass = "LionKing", AlwaysBetterBy = 10 }
	),
}

-- Eggs sit on pads behind spawn. Cost is in Wins, or a Robux developer product (Product).
Config.Eggs = {
	{
		Id = "Common",
		Name = "Common Egg",
		Cost = 50,
		Color = Color3.fromRGB(240, 240, 245),
		Pool = { Puppy = 45, Kitty = 35, Bunny = 16, Panda = 4 },
	},
	{
		Id = "Uncommon",
		Name = "Uncommon Egg",
		Cost = 500,
		Color = Color3.fromRGB(80, 220, 90),
		Pool = { Fox = 42, Monkey = 33, Tiger = 20, GoldenPanda = 5 },
	},
	{
		Id = "Rare",
		Name = "Rare Egg",
		Cost = 4_000,
		Color = Color3.fromRGB(90, 200, 255),
		Pool = { Owl = 45, Crane = 35, SnowLeopard = 17, JadeDragon = 3 },
	},
	{
		Id = "Legendary",
		Name = "Legendary Egg",
		Cost = 30_000,
		Color = Color3.fromRGB(255, 190, 40),
		Pool = { RedPanda = 50, Kirin = 35, ThunderTiger = 13, ShadowDragon = 2 },
	},
	{
		Id = "Rainbow",
		Name = "Rainbow Egg",
		Product = "RainbowEgg",
		Color = Color3.fromRGB(255, 120, 220),
		Rainbow = true,
		Pool = { RainbowUnicorn = 60, GalaxyCat = 35, DragonKing = 5 },
	},
}

Config.PetsConfig = {
	BaseSlots = 3,
	ExtraSlotsPass = "PetSlots",
	ExtraSlots = 2,
	MaxInventory = 60,
	LuckBoostMultiplier = 2, -- the 2x Luck boost multiplies the weight of every non-Common pet
}

--------------------------------------------------------------------------------
-- Trails (bought with Wins): cosmetic + walk speed
--------------------------------------------------------------------------------

Config.Trails = {
	{
		Id = "Breeze",
		Name = "Breeze",
		Cost = 100,
		Speed = 2,
		Colors = { Color3.fromRGB(255, 255, 255), Color3.fromRGB(150, 220, 255) },
	},
	{
		Id = "Flame",
		Name = "Flame",
		Cost = 1_000,
		Speed = 4,
		Colors = { Color3.fromRGB(255, 220, 60), Color3.fromRGB(255, 60, 20) },
	},
	{
		Id = "Frost",
		Name = "Frost",
		Cost = 7_500,
		Speed = 6,
		Colors = { Color3.fromRGB(220, 250, 255), Color3.fromRGB(60, 160, 255) },
	},
	{
		Id = "Thunder",
		Name = "Thunder",
		Cost = 40_000,
		Speed = 8,
		Colors = { Color3.fromRGB(255, 255, 150), Color3.fromRGB(120, 80, 255) },
	},
	{
		Id = "Rainbow",
		Name = "Rainbow",
		Cost = 200_000,
		Speed = 10,
		Rainbow = true,
		Colors = { Color3.fromRGB(255, 60, 60), Color3.fromRGB(60, 120, 255) },
	},
	{
		Id = "Galaxy",
		Name = "Galaxy",
		Cost = 1_000_000,
		Speed = 12,
		Colors = { Color3.fromRGB(255, 120, 240), Color3.fromRGB(40, 20, 120) },
	},
}

Config.BaseWalkSpeed = 20

--------------------------------------------------------------------------------
-- Rebirth & levels
--------------------------------------------------------------------------------

Config.Rebirth = {
	BaseCost = 2_500, -- Strength needed (= reaching max level) for the first rebirth
	CostGrowth = 3.5,
	StrengthPerRebirth = 0.5, -- permanent Strength multiplier: 1 + rebirths * this
	WinsPerRebirth = 0.1, -- permanent Wins multiplier: 1 + rebirths * this
	MaxLevel = 40,
}

--------------------------------------------------------------------------------
-- Rewards, boosts, social
--------------------------------------------------------------------------------

Config.Boosts = {
	Strength = { Name = "2x Strength", Icon = "⚡", Color = Color3.fromRGB(80, 170, 255) },
	Wins = { Name = "2x Wins", Icon = "🏆", Color = Color3.fromRGB(255, 200, 40) },
	Luck = { Name = "2x Luck", Icon = "🍀", Color = Color3.fromRGB(90, 220, 90) },
}

-- Gifts: claimable after X minutes in the current session. Strength rewards are worth
-- `Chops` chops at your current gain, so they stay useful at every stage.
Config.PlaytimeRewards = {
	{ Minutes = 1, Kind = "Strength", Chops = 400 },
	{ Minutes = 3, Kind = "Wins", Amount = 10 },
	{ Minutes = 5, Kind = "Egg", Egg = "Common" },
	{ Minutes = 8, Kind = "Boost", Boost = "Strength", Duration = 600 },
	{ Minutes = 12, Kind = "Wins", Amount = 250 },
	{ Minutes = 17, Kind = "Strength", Chops = 3_000 },
	{ Minutes = 23, Kind = "Boost", Boost = "Wins", Duration = 600 },
	{ Minutes = 30, Kind = "Egg", Egg = "Uncommon" },
	{ Minutes = 40, Kind = "Boost", Boost = "Luck", Duration = 900 },
	{ Minutes = 55, Kind = "Wins", Amount = 2_500 },
	{ Minutes = 70, Kind = "Strength", Chops = 20_000 },
	{ Minutes = 90, Kind = "Egg", Egg = "Rare" },
}

Config.Offline = {
	MinSeconds = 120,
	MaxHours = 8,
	Efficiency = 0.35, -- fraction of idle training earned while away
	ProductMultiplier = 3, -- the "x3" Robux claim
}

Config.Social = {
	FriendBoostPerFriend = 0.1,
	MaxFriendBoost = 0.5,
}

Config.Leaderboards = {
	UpdateInterval = 90,
	Size = 10,
	Boards = {
		{ Id = "TotalWins", Title = "MOST WINS", Store = "LB_TotalWins_v1", Stat = "TotalWins", Icon = "🏆" },
		{ Id = "Rebirths", Title = "MOST REBIRTHS", Store = "LB_Rebirths_v1", Stat = "Rebirths", Icon = "🌀" },
		{
			Id = "BestDistance",
			Title = "LONGEST SMASH",
			Store = "LB_BestDistance_v1",
			Stat = "BestDistance",
			Icon = "📏",
			Suffix = " m",
		},
	},
}

--------------------------------------------------------------------------------
-- Robux (placeholders). Create the passes/products on the Creator Hub, then paste the ids.
-- Id = 0 → shown in the shop but not purchasable in a live game. In Studio, with
-- StudioTestPurchases on, buying grants the item instantly so you can test everything.
--------------------------------------------------------------------------------

Config.Monetization = {
	StudioTestPurchases = true,

	GamePasses = {
		AutoSmash = {
			Id = 0,
			Price = 25,
			Name = "Auto Smash",
			Icon = "🤖",
			Description = "Smashes the wall for you nonstop",
		},
		DoubleStrength = {
			Id = 0,
			Price = 49,
			Name = "2x Strength",
			Icon = "⚡",
			Description = "Double Strength forever",
		},
		DoubleWins = { Id = 0, Price = 59, Name = "2x Wins", Icon = "🏆", Description = "Double Wins forever" },
		PetSlots = { Id = 0, Price = 99, Name = "+2 Pet Slots", Icon = "🐾", Description = "Equip 2 more pets" },
		GoldenZone = { Id = 0, Price = 99, Name = "Golden Temple", Icon = "⛩️", Description = "x30 training zone" },
		DragonZone = { Id = 0, Price = 249, Name = "Dragon Sanctum", Icon = "🐉", Description = "x75 training zone" },
		CosmicZone = { Id = 0, Price = 599, Name = "Cosmic Dojo", Icon = "🌌", Description = "x200 training zone" },
		PhoenixRelic = {
			Id = 0,
			Price = 499,
			Name = "Phoenix Relic",
			Icon = "🔥",
			Description = "Always 125% better hands",
		},
		LionKing = { Id = 0, Price = 799, Name = "Lion King", Icon = "🦁", Description = "Pet: always 1000% better" },
	},

	Products = {
		Strength10K = { Id = 0, Price = 11, Name = "+10K Strength", Strength = 10_000 },
		Strength100K = { Id = 0, Price = 45, Name = "+100K Strength", Strength = 100_000 },
		Strength1M = { Id = 0, Price = 95, Name = "+1M Strength", Strength = 1_000_000 },
		RainbowEgg = { Id = 0, Price = 45, Name = "Rainbow Egg" },
		OfflineTriple = { Id = 0, Price = 9, Name = "x3 Offline Strength" },
		StarterPack = {
			Id = 0,
			Price = 49,
			Name = "Starter Pack",
			Strength = 25_000,
			Wins = 1_000,
			Pet = "GalaxyCat",
			OneTime = true,
		},
	},
}

--------------------------------------------------------------------------------
-- Data
--------------------------------------------------------------------------------

Config.Data = {
	SchemaVersion = 2,
	AutosaveInterval = 60,
	SessionLockExpiry = 300,
	LoadRetries = 6,
	LoadRetryDelay = 4,
	MaxReceipts = 50,
}

return Config
