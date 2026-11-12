-- Central tuning for HOLLOW SHIFT. Change numbers here, not in the services.
local Config = {}

Config.GAME_NAME = "HOLLOW SHIFT"
Config.TAGLINE = "Make quota. Restore power. Don't look away."

-- Players ------------------------------------------------------------------
Config.MAX_PLAYERS = 5 -- crew size per round (also set the place's server size to 5)
Config.MIN_PLAYERS = 1 -- raise to 2+ for public servers; 1 lets you test solo
Config.LOBBY_COUNTDOWN = 30 -- seconds once MIN_PLAYERS are in
Config.FULL_LOBBY_COUNTDOWN = 5 -- seconds once the crew is full (5/5)
Config.POST_ROUND_TIME = 12

-- Round --------------------------------------------------------------------
Config.ROUND_TIME = 600 -- 10 minute night
Config.ENRAGE_TIME = 120 -- final seconds where monsters speed up
Config.QUOTA_BASE = 100
Config.QUOTA_PER_PLAYER = 70
Config.LOOT_BASE = 14
Config.LOOT_PER_PLAYER = 6
Config.BATTERY_COUNT = 7
Config.GENERATOR_COUNT = 3

-- Map ----------------------------------------------------------------------
Config.MAP_ORIGIN = Vector3.new(0, 0, 0)
Config.LOBBY_ORIGIN = Vector3.new(0, 0, -400)
Config.GRID_W = 7
Config.GRID_H = 7
Config.ROOM_SIZE = 36
Config.WALL_HEIGHT = 16
Config.WALL_THICKNESS = 1
Config.DOOR_WIDTH = 10
Config.DOOR_HEIGHT = 11
Config.EXTRA_LINKS = 10 -- extra doorways so the maze has loops to escape through
Config.DARK_ROOM_CHANCE = 0.5
Config.FLICKER_CHANCE = 0.35

-- Player stats -------------------------------------------------------------
Config.WALK_SPEED = 12
Config.SPRINT_SPEED = 21
Config.CROUCH_SPEED = 6
Config.DOWNED_SPEED = 2.5
Config.WEIGHT_SLOW = 1.3 -- walk speed lost per weight point of carried loot
Config.STAMINA_DRAIN = 20
Config.STAMINA_REGEN = 12
Config.STAMINA_MIN_TO_SPRINT = 15
Config.MAX_HP = 100
Config.BLEEDOUT_TIME = 45
Config.REVIVE_TIME = 4
Config.REVIVE_HP = 40

Config.SANITY_DARK_DRAIN = 1.0 -- per second alone in the dark
Config.SANITY_MONSTER_DRAIN = 4 -- per second with a monster within 30 studs
Config.SANITY_LIGHT_REGEN = 0.6
Config.SANITY_SAFE_REGEN = 4 -- loading dock (start room)
Config.SANITY_HIT_LOSS = 15
Config.LOW_SANITY = 30 -- below this: hallucinations, monsters notice you sooner

Config.FLASHLIGHT_DRAIN = 0.8 -- battery % per second
Config.BATTERY_REFILL = 60
Config.PHOTO_COOLDOWN = 12
Config.PHOTO_BATTERY_COST = 8
Config.PHOTO_RANGE = 70
Config.PHOTO_ANGLE = 30
Config.PHOTO_STUN = 3 -- seconds the camera flash freezes the Hollow

-- Generators ---------------------------------------------------------------
Config.GEN_REPAIR_TIME = 45 -- seconds for one player; extra helpers speed it up
Config.GEN_HELPER_BONUS = 0.6
Config.GEN_RANGE = 9
Config.SKILLCHECK_CHANCE = 0.12 -- per second per repairer
Config.SKILLCHECK_DURATION = 1.2
Config.SKILLCHECK_ZONE = 0.14
Config.SKILLCHECK_GREAT = 0.04
Config.SKILLCHECK_FAIL_PENALTY = 0.08
Config.SKILLCHECK_GREAT_BONUS = 0.02
Config.SKILLCHECK_NOISE = 90

-- Noise radii (the Hum hunts by sound) -------------------------------------
Config.NOISE_SPRINT = 45
Config.NOISE_WALK = 14
Config.NOISE_DROP = 35
Config.NOISE_PHOTO = 30

-- Elevator -----------------------------------------------------------------
Config.ELEVATOR_COUNTDOWN = 15

-- Monsters -----------------------------------------------------------------
Config.ENRAGE_MULT = 1.25
Config.SECOND_HOLLOW_PLAYERS = 4 -- with this many players a second Hollow joins
Config.MONSTERS = {
	-- Roams, chases on sight. Camera flash stuns it.
	Hollow = { spawnAt = 5, walk = 9, chase = 17, sight = 65, damage = 45, attackRange = 5, cooldown = 1.6, photoBonus = 25 },
	-- Only moves while nobody is looking at it. One touch puts you down.
	Still = { spawnAt = 120, speed = 28, watchAngle = 40, watchRange = 150, damage = 100, attackRange = 4.5, photoBonus = 40 },
	-- Blind. Hunts noise: sprinting, dropped loot, failed skill checks.
	Hum = { spawnAt = 240, walk = 6, investigate = 17, damage = 60, attackRange = 5, cooldown = 2, photoBonus = 30 },
}

-- Loot ---------------------------------------------------------------------
Config.LOOT = {
	{ name = "Brass Bell", min = 12, max = 24, weight = 1, size = Vector3.new(1.4, 1.6, 1.4), color = Color3.fromRGB(196, 156, 62), material = Enum.Material.Metal },
	{ name = "Porcelain Doll", min = 20, max = 40, weight = 1, size = Vector3.new(1, 2, 0.8), color = Color3.fromRGB(235, 225, 215), material = Enum.Material.SmoothPlastic },
	{ name = "Old Radio", min = 25, max = 45, weight = 2, size = Vector3.new(2.4, 1.6, 1.2), color = Color3.fromRGB(90, 60, 40), material = Enum.Material.Wood },
	{ name = "Gold Pocket Watch", min = 35, max = 60, weight = 0, size = Vector3.new(0.8, 0.8, 0.3), color = Color3.fromRGB(230, 190, 60), material = Enum.Material.Foil },
	{ name = "Cash Register", min = 55, max = 85, weight = 4, size = Vector3.new(3, 2.4, 2.4), color = Color3.fromRGB(70, 70, 75), material = Enum.Material.Metal },
	{ name = "Film Reel", min = 15, max = 30, weight = 1, size = Vector3.new(2, 2, 0.4), color = Color3.fromRGB(40, 40, 40), material = Enum.Material.Metal },
	{ name = "Ritual Mask", min = 40, max = 70, weight = 1, size = Vector3.new(1.6, 2, 0.6), color = Color3.fromRGB(150, 30, 30), material = Enum.Material.Wood },
	{ name = "Car Battery", min = 30, max = 50, weight = 3, size = Vector3.new(2, 1.6, 1.4), color = Color3.fromRGB(30, 30, 30), material = Enum.Material.Plastic },
	{ name = "Music Box", min = 25, max = 40, weight = 1, size = Vector3.new(1.4, 1, 1), color = Color3.fromRGB(120, 70, 100), material = Enum.Material.Wood },
	{ name = "Jar of Teeth", min = 10, max = 20, weight = 1, size = Vector3.new(1, 1.4, 1), color = Color3.fromRGB(200, 220, 210), material = Enum.Material.Glass },
}

-- Sounds -------------------------------------------------------------------
-- Paste Creator Store audio IDs ("rbxassetid://123") to add horror audio.
-- Empty strings are skipped silently.
Config.SOUNDS = {
	SkillCheck = "rbxasset://sounds/electronicpingshort.wav",
	Heartbeat = "",
	Jumpscare = "",
	Whisper = "",
	StillCreak = "",
	Ambience = "",
	CameraFlash = "",
	GeneratorDone = "",
	ElevatorOpen = "",
}

return Config
