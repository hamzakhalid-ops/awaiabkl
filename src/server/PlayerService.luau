-- Per-player survival state: HP, sanity, stamina, battery, downed/revive, death.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Noise = require(script.Parent.Noise)
local LootService = require(script.Parent.LootService)
local GeneratorService = require(script.Parent.GeneratorService)
local MonsterService = require(script.Parent.MonsterService)

local PlayerService = {}

local ctx = nil
local states = {} -- [Player] = state table (only round participants)
local looks = {} -- [Player] = Vector3

local function getParts(player)
	local char = player.Character
	if not char then
		return nil
	end
	local hum = char:FindFirstChildOfClass("Humanoid")
	local root = char:FindFirstChild("HumanoidRootPart")
	local head = char:FindFirstChild("Head")
	if not hum or not root or not head then
		return nil
	end
	return char, hum, root, head
end

local function alive(s)
	return s and not s.dead and not s.escaped
end

function PlayerService.isActive(player)
	local s = states[player]
	return alive(s) and not s.downed and player.Parent ~= nil
end

function PlayerService.getLook(player)
	return looks[player]
end

function PlayerService.getActivePlayers()
	local list = {}
	for player, s in states do
		if alive(s) and not s.downed then
			local _, _, root, head = getParts(player)
			if root then
				table.insert(list, {
					player = player,
					root = root,
					head = head,
					flashlight = s.flashlight,
					crouching = s.crouch,
					sanity = s.sanity,
				})
			end
		end
	end
	return list
end

-- Everyone still in the facility, including downed players (they can still watch).
function PlayerService.getWatchers()
	local list = {}
	for player, s in states do
		if alive(s) then
			local _, _, root, head = getParts(player)
			if root then
				table.insert(list, { player = player, root = root, head = head, downed = s.downed })
			end
		end
	end
	return list
end

function PlayerService.countAlive()
	local n, standing = 0, 0
	for _, s in states do
		if alive(s) then
			n += 1
			if not s.downed then
				standing += 1
			end
		end
	end
	return n, standing
end

local function sync(player, s)
	player:SetAttribute("HP", math.floor(s.hp + 0.5))
	player:SetAttribute("Sanity", math.floor(s.sanity + 0.5))
	player:SetAttribute("Stamina", math.floor(s.stamina + 0.5))
	player:SetAttribute("Battery", math.floor(s.battery + 0.5))
	player:SetAttribute("Bleedout", if s.downed then math.ceil(s.bleed) else nil)
end

local function setFlashlight(player, s, on)
	s.flashlight = on
	player:SetAttribute("Flashlight", on)
	local _, _, _, head = getParts(player)
	local light = head and head:FindFirstChild("Flashlight")
	if light then
		light.Enabled = on
	end
end

function PlayerService.addBattery(player, amount)
	local s = states[player]
	if s then
		s.battery = math.min(100, s.battery + amount)
		sync(player, s)
	end
end

local function clearRevivePrompt(s)
	if s.revivePrompt then
		s.revivePrompt:Destroy()
		s.revivePrompt = nil
	end
end

function PlayerService.revive(player)
	local s = states[player]
	if not alive(s) or not s.downed then
		return
	end
	s.downed = false
	s.hp = Config.REVIVE_HP
	clearRevivePrompt(s)
	player:SetAttribute("Downed", false)
	local _, hum = getParts(player)
	if hum then
		hum.JumpHeight = 4
	end
	sync(player, s)
	ctx.notify(player.DisplayName .. " is back on their feet.", Color3.fromRGB(140, 220, 255))
end

function PlayerService.down(player)
	local s = states[player]
	if not alive(s) or s.downed then
		return
	end
	s.downed = true
	s.hp = 0
	s.bleed = Config.BLEEDOUT_TIME
	s.sprint = false
	player:SetAttribute("Downed", true)
	LootService.drop(player, true)
	GeneratorService.stopRepair(player)
	local _, hum, root = getParts(player)
	if hum then
		hum.JumpHeight = 0
	end
	if root then
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "RevivePrompt"
		prompt.ActionText = "Revive"
		prompt.ObjectText = player.DisplayName
		prompt.HoldDuration = Config.REVIVE_TIME
		prompt.MaxActivationDistance = 7
		prompt.RequiresLineOfSight = false
		prompt.Parent = root
		prompt.Triggered:Connect(function(by)
			if by ~= player and PlayerService.isActive(by) then
				PlayerService.revive(player)
			end
		end)
		s.revivePrompt = prompt
	end
	sync(player, s)
	ctx.notify(player.DisplayName .. " is DOWN! Hold [E] on them to revive.", Color3.fromRGB(255, 80, 80))
end

function PlayerService.kill(player, reason)
	local s = states[player]
	if not alive(s) then
		return
	end
	s.dead = true
	s.downed = false
	clearRevivePrompt(s)
	LootService.drop(player, true)
	GeneratorService.stopRepair(player)
	player:SetAttribute("Downed", false)
	player:SetAttribute("Dead", true)
	player:SetAttribute("Bleedout", nil)
	player:SetAttribute("Flashlight", false)
	player.CameraMode = Enum.CameraMode.Classic
	local _, hum = getParts(player)
	if hum and hum.Health > 0 then
		hum.Health = 0 -- respawns in the lobby and spectates
	end
	if ctx then
		ctx.notify(player.DisplayName .. " " .. (reason or "was taken by the dark."), Color3.fromRGB(200, 60, 60))
	end
end

function PlayerService.escape(player)
	local s = states[player]
	if not alive(s) then
		return
	end
	local value = LootService.consume(player)
	if value > 0 then
		ctx.addCollected(value)
	end
	s.escaped = true
	clearRevivePrompt(s)
	GeneratorService.stopRepair(player)
	player:SetAttribute("Escaped", true)
	player:SetAttribute("Flashlight", false)
	player.CameraMode = Enum.CameraMode.Classic
	task.defer(function()
		if player.Parent then
			player:LoadCharacter()
		end
	end)
end

function PlayerService.damage(player, amount, kind)
	local s = states[player]
	if not alive(s) or s.downed then
		return
	end
	s.hp -= amount
	s.sanity = math.max(0, s.sanity - Config.SANITY_HIT_LOSS)
	local downed = s.hp <= 0
	Remotes.Jumpscare:FireClient(player, kind, downed)
	if downed then
		PlayerService.down(player)
	else
		sync(player, s)
	end
end

---------------------------------------------------------------- input handlers
local function onMovement(player, kind, value)
	local s = states[player]
	if not s or type(value) ~= "boolean" then
		return
	end
	if kind == "Sprint" then
		s.sprint = value
	elseif kind == "Crouch" then
		s.crouch = value
		player:SetAttribute("Crouching", value)
	end
end

local function onFlashlight(player)
	local s = states[player]
	if not alive(s) then
		return
	end
	if s.flashlight then
		setFlashlight(player, s, false)
	elseif s.battery > 0 then
		setFlashlight(player, s, true)
	end
end

local function onPhoto(player)
	local s = states[player]
	if not PlayerService.isActive(player) then
		return
	end
	local now = os.clock()
	if now < s.photoReady then
		Remotes.PhotoResult:FireClient(player, false, {}, 0, string.format("Camera recharging (%ds)", math.ceil(s.photoReady - now)))
		return
	end
	if s.battery < Config.PHOTO_BATTERY_COST then
		Remotes.PhotoResult:FireClient(player, false, {}, 0, "Not enough battery for the flash")
		return
	end
	local _, _, _, head = getParts(player)
	if not head then
		return
	end
	s.battery -= Config.PHOTO_BATTERY_COST
	s.photoReady = now + Config.PHOTO_COOLDOWN
	local look = looks[player] or head.CFrame.LookVector
	-- flash everyone can see
	local flash = Instance.new("PointLight")
	flash.Range = 40
	flash.Brightness = 6
	flash.Color = Color3.fromRGB(230, 240, 255)
	flash.Parent = head
	task.delay(0.15, function()
		flash:Destroy()
	end)
	Noise.emit(head.Position, Config.NOISE_PHOTO, player)

	local hits = MonsterService.photo(head.Position, look)
	local bonus = 0
	for _, kind in hits do
		if not s.photographed[kind] then
			s.photographed[kind] = true
			bonus += Config.MONSTERS[kind].photoBonus
		end
	end
	if bonus > 0 then
		ctx.addCollected(bonus)
		ctx.notify(string.format("%s captured footage of the %s (+$%d)", player.DisplayName, table.concat(hits, " & "), bonus), Color3.fromRGB(255, 230, 120))
	end
	sync(player, s)
	Remotes.PhotoResult:FireClient(player, true, hits, bonus, nil)
end

---------------------------------------------------------------- update loop
local function update(dt)
	if not ctx then
		return
	end
	local now = os.clock()
	for player, s in states do
		if not alive(s) then
			continue
		end
		local _, hum, root = getParts(player)
		if not hum then
			continue
		end
		local moving = hum.MoveDirection.Magnitude > 0.1

		-- movement & stamina
		local speed
		if s.downed then
			speed = Config.DOWNED_SPEED
			s.sprinting = false
		else
			local wantSprint = s.sprint and moving and not s.crouch
			if wantSprint and s.stamina > 0 and (s.sprinting or s.stamina >= Config.STAMINA_MIN_TO_SPRINT) then
				s.sprinting = true
			else
				s.sprinting = false
			end
			if s.sprinting then
				s.stamina = math.max(0, s.stamina - Config.STAMINA_DRAIN * dt)
				speed = Config.SPRINT_SPEED
			else
				s.stamina = math.min(100, s.stamina + Config.STAMINA_REGEN * dt * (if moving then 1 else 1.5))
				speed = if s.crouch then Config.CROUCH_SPEED else Config.WALK_SPEED
			end
			speed = math.max(4, speed - (player:GetAttribute("CarryWeight") or 0) * Config.WEIGHT_SLOW)
		end
		hum.WalkSpeed = speed

		-- footsteps the Hum can hear
		if moving and not s.downed and now >= s.nextNoise then
			s.nextNoise = now + 0.5
			if s.sprinting then
				Noise.emit(root.Position, Config.NOISE_SPRINT, player)
			elseif not s.crouch then
				Noise.emit(root.Position, Config.NOISE_WALK, player)
			end
		end

		-- flashlight battery
		if s.flashlight then
			s.battery = math.max(0, s.battery - Config.FLASHLIGHT_DRAIN * dt)
			if s.battery <= 0 then
				setFlashlight(player, s, false)
			end
		end

		-- sanity
		local room = ctx.map.roomAt(root.Position)
		local delta
		if (room and room.safe) or ctx.map.inElevator(root.Position) then
			delta = Config.SANITY_SAFE_REGEN
		elseif room and room.lit then
			delta = Config.SANITY_LIGHT_REGEN
		elseif s.flashlight then
			delta = -Config.SANITY_DARK_DRAIN * 0.25
		else
			delta = -Config.SANITY_DARK_DRAIN
		end
		if delta < 0 then
			for other, os2 in states do
				if other ~= player and alive(os2) then
					local _, _, oroot = getParts(other)
					if oroot and (oroot.Position - root.Position).Magnitude < 15 then
						delta *= 0.5 -- company keeps you sane
						break
					end
				end
			end
		end
		if MonsterService.nearestDistance(root.Position) < 30 then
			delta -= Config.SANITY_MONSTER_DRAIN
		end
		s.sanity = math.clamp(s.sanity + delta * dt, 0, 100)

		-- bleeding out
		if s.downed then
			s.bleed -= dt
			if s.bleed <= 0 then
				PlayerService.kill(player, "bled out in the dark.")
				continue
			end
		end

		s.syncTimer -= dt
		if s.syncTimer <= 0 then
			s.syncTimer = 0.1
			sync(player, s)
		end
	end
end

---------------------------------------------------------------- lifecycle
local function resetAttributes(player)
	for _, name in { "HP", "Sanity", "Stamina", "Battery", "Bleedout", "Repairing", "RepairProgress" } do
		player:SetAttribute(name, nil)
	end
	player:SetAttribute("InRound", false)
	player:SetAttribute("Downed", false)
	player:SetAttribute("Dead", false)
	player:SetAttribute("Escaped", false)
	player:SetAttribute("Flashlight", false)
	player:SetAttribute("Crouching", false)
	player:SetAttribute("Carrying", "")
	player:SetAttribute("CarryValue", 0)
	player:SetAttribute("CarryWeight", 0)
end

local function prepareCharacter(player, s, spawnPos)
	local char, hum, _, head = getParts(player)
	if not char then
		-- character still loading: finish setup once it arrives
		task.spawn(function()
			player.CharacterAdded:Wait()
			task.wait(0.5)
			if states[player] == s and alive(s) then
				prepareCharacter(player, s, spawnPos)
			end
		end)
		return
	end
	hum.UseJumpPower = false
	hum.JumpHeight = 4
	hum.WalkSpeed = Config.WALK_SPEED
	local light = Instance.new("SpotLight")
	light.Name = "Flashlight"
	light.Angle = 55
	light.Range = 60
	light.Brightness = 2.5
	light.Shadows = true
	light.Color = Color3.fromRGB(255, 245, 225)
	light.Face = Enum.NormalId.Front
	light.Enabled = false
	light.Parent = head
	char:PivotTo(CFrame.new(spawnPos))
	s.diedConn = hum.Died:Connect(function()
		if states[player] == s and alive(s) then
			PlayerService.kill(player, "was torn apart.")
		end
	end)
end

function PlayerService.init()
	Remotes.SetMovement.OnServerEvent:Connect(onMovement)
	Remotes.Flashlight.OnServerEvent:Connect(onFlashlight)
	Remotes.TakePhoto.OnServerEvent:Connect(onPhoto)
	Remotes.DropItem.OnServerEvent:Connect(function(player)
		if PlayerService.isActive(player) then
			LootService.drop(player)
		end
	end)
	Remotes.LookDir.OnServerEvent:Connect(function(player, dir)
		if typeof(dir) == "Vector3" and dir.Magnitude > 0.5 and dir.Magnitude < 1.5 then
			looks[player] = dir.Unit
		end
	end)
	RunService.Heartbeat:Connect(update)
	Players.PlayerAdded:Connect(resetAttributes)
	for _, p in Players:GetPlayers() do
		resetAttributes(p)
	end
	Players.PlayerRemoving:Connect(function(player)
		local s = states[player]
		if s then
			LootService.drop(player, true)
			GeneratorService.stopRepair(player)
			clearRevivePrompt(s)
			if s.diedConn then
				s.diedConn:Disconnect()
			end
		end
		states[player] = nil
		looks[player] = nil
	end)
end

function PlayerService.startRound(context, participants)
	ctx = context
	for i, player in participants do
		resetAttributes(player)
		local s = {
			hp = Config.MAX_HP,
			sanity = 100,
			stamina = 100,
			battery = 100,
			bleed = 0,
			downed = false,
			dead = false,
			escaped = false,
			flashlight = false,
			sprint = false,
			sprinting = false,
			crouch = false,
			nextNoise = 0,
			photoReady = 0,
			photographed = {},
			syncTimer = 0,
		}
		states[player] = s
		player:SetAttribute("InRound", true)
		player.CameraMode = Enum.CameraMode.LockFirstPerson
		sync(player, s)
		prepareCharacter(player, s, ctx.map.spawnPoints[(i - 1) % #ctx.map.spawnPoints + 1])
	end
end

function PlayerService.endRound()
	for player, s in states do
		clearRevivePrompt(s)
		if s.diedConn then
			s.diedConn:Disconnect()
		end
		if player.Parent then
			player.CameraMode = Enum.CameraMode.Classic
		end
	end
	table.clear(states)
	ctx = nil
end

function PlayerService.resetAll()
	for _, p in Players:GetPlayers() do
		resetAttributes(p)
	end
end

return PlayerService
