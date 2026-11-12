-- Three monsters with different rules:
--   Hollow : roams, chases on sight, camera flash stuns it
--   Still  : only moves while nobody is looking at it, one touch downs you
--   Hum    : blind, hunts noise
local PathfindingService = game:GetService("PathfindingService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Noise = require(script.Parent.Noise)

local MonsterService = {}

local ctx = nil
local folder: Folder? = nil
local monsters = {}
local spawned = {}
local connections = {}
local unsubscribeNoise = nil
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude

---------------------------------------------------------------- bodies
local BODIES = {
	Hollow = {
		height = 9,
		parts = {
			{ "Torso", Vector3.new(2.4, 4, 1.2), Vector3.new(0, 1, 0), Color3.fromRGB(18, 18, 20) },
			{ "Head", Vector3.new(1.6, 2.2, 1.6), Vector3.new(0, 4.1, 0), Color3.fromRGB(14, 14, 14) },
			{ "LeftArm", Vector3.new(0.5, 5.5, 0.5), Vector3.new(-1.5, 0.4, -0.2), Color3.fromRGB(18, 18, 20) },
			{ "RightArm", Vector3.new(0.5, 5.5, 0.5), Vector3.new(1.5, 0.4, -0.2), Color3.fromRGB(18, 18, 20) },
			{ "LeftLeg", Vector3.new(0.7, 3.6, 0.7), Vector3.new(-0.6, -2.7, 0), Color3.fromRGB(14, 14, 16) },
			{ "RightLeg", Vector3.new(0.7, 3.6, 0.7), Vector3.new(0.6, -2.7, 0), Color3.fromRGB(14, 14, 16) },
			{ "LeftEye", Vector3.new(0.3, 0.2, 0.1), Vector3.new(-0.4, 4.4, -0.8), Color3.fromRGB(255, 20, 20), true },
			{ "RightEye", Vector3.new(0.3, 0.2, 0.1), Vector3.new(0.4, 4.4, -0.8), Color3.fromRGB(255, 20, 20), true },
		},
		eyeLight = Color3.fromRGB(255, 30, 30),
	},
	Still = {
		height = 7.5,
		parts = {
			{ "Torso", Vector3.new(2, 2.8, 1), Vector3.new(0, 0.9, 0), Color3.fromRGB(205, 195, 180) },
			{ "Head", Vector3.new(1.3, 1.6, 1.3), Vector3.new(0, 3.1, 0), Color3.fromRGB(215, 205, 190) },
			{ "LeftArm", Vector3.new(0.5, 3, 0.5), Vector3.new(-1.3, 0.8, -0.6), Color3.fromRGB(205, 195, 180) },
			{ "RightArm", Vector3.new(0.5, 3, 0.5), Vector3.new(1.3, 0.8, -0.6), Color3.fromRGB(205, 195, 180) },
			{ "LeftLeg", Vector3.new(0.6, 3.2, 0.6), Vector3.new(-0.5, -2.1, 0), Color3.fromRGB(190, 180, 165) },
			{ "RightLeg", Vector3.new(0.6, 3.2, 0.6), Vector3.new(0.5, -2.1, 0), Color3.fromRGB(190, 180, 165) },
			{ "Mouth", Vector3.new(0.7, 0.15, 0.1), Vector3.new(0, 2.7, -0.66), Color3.fromRGB(20, 0, 0) },
		},
	},
	Hum = {
		height = 5,
		parts = {
			{ "Body", Vector3.new(4.5, 3.2, 4), Vector3.new(0, 0.4, 0), Color3.fromRGB(120, 88, 84) },
			{ "Mouth", Vector3.new(3.2, 1.2, 0.2), Vector3.new(0, 0.6, -2.05), Color3.fromRGB(25, 5, 5) },
			{ "Teeth", Vector3.new(3, 0.25, 0.25), Vector3.new(0, 1.05, -2.1), Color3.fromRGB(230, 225, 200) },
			{ "LegFL", Vector3.new(0.7, 2, 0.7), Vector3.new(-1.8, -1.6, -1.4), Color3.fromRGB(100, 72, 70) },
			{ "LegFR", Vector3.new(0.7, 2, 0.7), Vector3.new(1.8, -1.6, -1.4), Color3.fromRGB(100, 72, 70) },
			{ "LegBL", Vector3.new(0.7, 2, 0.7), Vector3.new(-1.8, -1.6, 1.4), Color3.fromRGB(100, 72, 70) },
			{ "LegBR", Vector3.new(0.7, 2, 0.7), Vector3.new(1.8, -1.6, 1.4), Color3.fromRGB(100, 72, 70) },
		},
	},
}

local function buildBody(kind)
	local def = BODIES[kind]
	local model = Instance.new("Model")
	model.Name = kind
	local root = Instance.new("Part")
	root.Name = "Root"
	root.Size = Vector3.new(2.5, def.height, 2)
	root.Transparency = 1
	root.Anchored = true
	root.CanCollide = false
	root.CanQuery = false
	root.CanTouch = false
	root.CFrame = CFrame.new()
	root.Parent = model
	for _, p in def.parts do
		local part = Instance.new("Part")
		part.Name = p[1]
		part.Size = p[2]
		part.CFrame = CFrame.new(p[3])
		part.Color = p[4]
		part.Material = if p[5] then Enum.Material.Neon else Enum.Material.SmoothPlastic
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.Parent = model
	end
	if def.eyeLight then
		local light = Instance.new("PointLight")
		light.Range = 8
		light.Brightness = 2
		light.Color = def.eyeLight
		light.Parent = model:FindFirstChild("Head")
	end
	model.PrimaryPart = root
	model:SetAttribute("Kind", kind)
	return model, def.height
end

---------------------------------------------------------------- helpers
local function refreshRayFilter()
	local list = { folder }
	local lootFolder = ctx.map.model:FindFirstChild("Loot")
	if lootFolder then
		table.insert(list, lootFolder)
	end
	for _, p in game:GetService("Players"):GetPlayers() do
		if p.Character then
			table.insert(list, p.Character)
		end
	end
	rayParams.FilterDescendantsInstances = list
end

local function hasLOS(from: Vector3, to: Vector3)
	return workspace:Raycast(from, to - from, rayParams) == nil
end

local function groundPos(m)
	local p = m.root.Position
	return Vector3.new(p.X, ctx.map.floorY, p.Z)
end

local function eyePos(m)
	return m.root.Position + Vector3.new(0, m.height * 0.35, 0)
end

local function placeAt(m, ground: Vector3, look: Vector3?)
	local center = Vector3.new(ground.X, ctx.map.floorY + m.height / 2, ground.Z)
	local dir = look or m.root.CFrame.LookVector
	dir = Vector3.new(dir.X, 0, dir.Z)
	if dir.Magnitude < 0.01 then
		dir = Vector3.new(0, 0, -1)
	end
	m.model:PivotTo(CFrame.lookAt(center, center + dir.Unit))
end

local function requestPath(m, goal: Vector3)
	if m.computing then
		return
	end
	m.computing = true
	task.spawn(function()
		local path = PathfindingService:CreatePath({
			AgentRadius = 2,
			AgentHeight = 6,
			AgentCanJump = false,
			WaypointSpacing = 6,
		})
		local lift = Vector3.new(0, 2, 0)
		local target = Vector3.new(goal.X, ctx.map.floorY, goal.Z) + lift
		local ok = pcall(function()
			path:ComputeAsync(groundPos(m) + lift, target)
		end)
		m.computing = false
		if not m.alive then
			return
		end
		if ok and path.Status == Enum.PathStatus.Success then
			m.waypoints = path:GetWaypoints()
			m.wpIndex = 2
		else
			m.waypoints = nil
			m.failedPaths += 1
		end
	end)
end

local function setDirect(m, goal: Vector3)
	m.waypoints = { { Position = goal } }
	m.wpIndex = 1
end

-- Moves along waypoints. Returns false when there is nothing left to walk.
local function step(m, dt, speed)
	if not m.waypoints then
		return false
	end
	local wp = m.waypoints[m.wpIndex]
	if not wp then
		m.waypoints = nil
		return false
	end
	local ground = groundPos(m)
	local delta = Vector3.new(wp.Position.X - ground.X, 0, wp.Position.Z - ground.Z)
	local dist = delta.Magnitude
	local move = speed * dt
	if dist <= move then
		placeAt(m, Vector3.new(wp.Position.X, 0, wp.Position.Z), if dist > 0.01 then delta else nil)
		m.wpIndex += 1
	else
		placeAt(m, ground + delta.Unit * move, delta)
	end
	return true
end

local function speedMult()
	return if ctx.enraged then Config.ENRAGE_MULT else 1
end

local function nearestActive(pos: Vector3)
	local best, bestDist = nil, math.huge
	for _, p in ctx.getActivePlayers() do
		local d = (p.root.Position - pos).Magnitude
		if d < bestDist then
			best, bestDist = p, d
		end
	end
	return best, bestDist
end

local function farRoomFromPlayers()
	local best, bestScore = nil, -1
	local active = ctx.getActivePlayers()
	for _, room in ctx.map.rooms do
		if not room.safe then
			local score = math.huge
			for _, p in active do
				score = math.min(score, (p.root.Position - room.center).Magnitude)
			end
			if #active == 0 then
				score = room.dist
			end
			score += ctx.rng:NextNumber(0, 20)
			if score > bestScore then
				best, bestScore = room, score
			end
		end
	end
	return best
end

local function wander(m)
	if not m.waypoints and not m.computing then
		requestPath(m, ctx.map.randomPointIn(ctx.map.randomRoom(true), 6))
	end
end

local function tryAttack(m, p, now)
	if now < m.attackReady then
		return false
	end
	if (p.root.Position - m.root.Position).Magnitude > m.def.attackRange + m.height * 0.25 then
		return false
	end
	m.attackReady = now + (m.def.cooldown or 4)
	ctx.damage(p.player, m.def.damage, m.kind)
	return true
end

---------------------------------------------------------------- brains
local Brains = {}

function Brains.Hollow(m, dt, now)
	if now < m.stunUntil then
		return
	end
	if now >= m.nextThink then
		m.nextThink = now + 0.2
		local eye = eyePos(m)
		local seen, seenDist, seenLOS = nil, math.huge, false
		for _, p in ctx.getActivePlayers() do
			local range = m.def.sight
			if p.flashlight then
				range *= 1.4
			end
			if p.crouching then
				range *= 0.5
			end
			if p.sanity < Config.LOW_SANITY then
				range *= 1.3
			end
			local d = (p.root.Position - eye).Magnitude
			if d < seenDist and d < range then
				local los = hasLOS(eye, p.root.Position)
				if los or d < 7 then -- very close: it hears you through the wall
					seen, seenDist, seenLOS = p, d, los
				end
			end
		end
		if seen then
			if m.state ~= "Chase" then
				m.waypoints = nil
			end
			m.state = "Chase"
			m.target = seen
			m.lastSeen = now
			m.lastKnown = seen.root.Position
		end
		if m.state == "Chase" then
			if now - m.lastSeen > 4 then
				m.state = "Search"
				m.waypoints = nil
				requestPath(m, m.lastKnown)
			elseif seen and seenLOS and seenDist < 14 then
				setDirect(m, seen.root.Position)
			elseif now >= m.repathAt then
				m.repathAt = now + 0.5
				requestPath(m, m.lastKnown)
			end
		end
	end

	if m.state == "Chase" then
		step(m, dt, m.def.chase * speedMult())
		if m.target and ctx.isActive(m.target.player) and tryAttack(m, m.target, now) then
			m.stunUntil = now + 1.2 -- brief pause after landing a hit
			m.state = "Search"
			m.waypoints = nil
		end
	elseif m.state == "Search" then
		if not step(m, dt, m.def.walk * 1.3 * speedMult()) and not m.computing then
			m.state = "Wander"
		end
	else
		wander(m)
		step(m, dt, m.def.walk * speedMult())
	end
end

function Brains.Still(m, dt, now)
	if now >= m.nextThink then
		m.nextThink = now + 0.1
		local observed = false
		local cosAngle = math.cos(math.rad(m.def.watchAngle))
		local center = m.root.Position
		local top = center + Vector3.new(0, m.height * 0.4, 0)
		for _, w in ctx.getWatchers() do
			local look = ctx.getLook(w.player) or w.head.CFrame.LookVector
			local toM = center - w.head.Position
			local dist = toM.Magnitude
			if dist < m.def.watchRange and dist > 0.1 and look:Dot(toM.Unit) > cosAngle then
				if hasLOS(w.head.Position, center) or hasLOS(w.head.Position, top) then
					observed = true
					break
				end
			end
		end
		m.observed = observed
		m.model:SetAttribute("Observed", observed)
		if not observed and now >= m.repathAt then
			m.repathAt = now + 0.6
			local p, d = nearestActive(center)
			m.target = p
			if p then
				if d < 10 and hasLOS(center, p.root.Position) then
					setDirect(m, p.root.Position)
				else
					requestPath(m, p.root.Position)
				end
			end
		end
	end
	if m.observed then
		return
	end
	local moved = step(m, dt, m.def.speed * speedMult())
	m.model:SetAttribute("Moving", moved)
	if m.target and ctx.isActive(m.target.player) and tryAttack(m, m.target, now) then
		-- vanish and reposition somewhere far away
		local room = farRoomFromPlayers()
		if room then
			placeAt(m, ctx.map.randomPointIn(room, 6))
		end
		m.waypoints = nil
		m.repathAt = now + 3
	end
end

function Brains.Hum(m, dt, now)
	if m.investigate and now - m.investigateAt > 12 then
		m.investigate = nil
	end
	if now >= m.nextThink then
		m.nextThink = now + 0.2
		-- anything bumping right into it gets eaten
		local p = nearestActive(m.root.Position)
		if p then
			tryAttack(m, p, now)
		end
	end
	if m.investigate then
		if not step(m, dt, m.def.investigate * speedMult()) and not m.computing then
			-- reached the sound: linger, then give up
			if not m.lingerUntil then
				m.lingerUntil = now + 3
			elseif now > m.lingerUntil then
				m.investigate = nil
				m.lingerUntil = nil
			end
		end
	else
		wander(m)
		step(m, dt, m.def.walk * speedMult())
	end
end

local function onNoise(position: Vector3, radius: number)
	if not ctx then
		return
	end
	local now = os.clock()
	for _, m in monsters do
		if m.kind == "Hum" and m.alive and (position - m.root.Position).Magnitude <= radius then
			local farFromGoal = not m.investigate or (m.investigate - position).Magnitude > 6
			if farFromGoal or now - m.investigateAt > 1 then
				m.investigate = position
				m.investigateAt = now
				m.lingerUntil = nil
				m.waypoints = nil
				requestPath(m, Vector3.new(position.X, ctx.map.floorY, position.Z))
			end
		end
	end
end

---------------------------------------------------------------- lifecycle
function MonsterService.spawn(kind)
	local model, height = buildBody(kind)
	local m = {
		kind = kind,
		def = Config.MONSTERS[kind],
		model = model,
		root = model.PrimaryPart,
		height = height,
		state = "Wander",
		alive = true,
		computing = false,
		failedPaths = 0,
		nextThink = 0,
		repathAt = 0,
		attackReady = os.clock() + 3,
		stunUntil = 0,
		lastSeen = 0,
		investigateAt = 0,
	}
	model.Parent = folder
	local room = farRoomFromPlayers() or ctx.map.randomRoom(true)
	placeAt(m, ctx.map.randomPointIn(room, 6))
	table.insert(monsters, m)
	return m
end

function MonsterService.schedule(elapsed: number)
	local function due(key, kind, at)
		if not spawned[key] and elapsed >= at then
			spawned[key] = true
			MonsterService.spawn(kind)
			if elapsed > 10 then
				ctx.notify("Something new is moving in the dark...", Color3.fromRGB(200, 80, 80))
			end
		end
	end
	due("Hollow1", "Hollow", Config.MONSTERS.Hollow.spawnAt)
	if #ctx.participants >= Config.SECOND_HOLLOW_PLAYERS then
		due("Hollow2", "Hollow", Config.MONSTERS.Hollow.spawnAt + 60)
	end
	due("Still", "Still", Config.MONSTERS.Still.spawnAt)
	due("Hum", "Hum", Config.MONSTERS.Hum.spawnAt)
end

-- Camera flash: returns the kinds caught in frame. Stuns any Hollow it catches.
function MonsterService.photo(headPos: Vector3, look: Vector3)
	local hits = {}
	if not ctx then
		return hits
	end
	refreshRayFilter()
	local cosAngle = math.cos(math.rad(Config.PHOTO_ANGLE))
	for _, m in monsters do
		local to = m.root.Position - headPos
		if to.Magnitude <= Config.PHOTO_RANGE and look:Dot(to.Unit) > cosAngle and hasLOS(headPos, m.root.Position) then
			table.insert(hits, m.kind)
			if m.kind == "Hollow" then
				m.stunUntil = os.clock() + Config.PHOTO_STUN
				m.state = "Search"
				m.waypoints = nil
			end
		end
	end
	return hits
end

function MonsterService.nearestDistance(pos: Vector3)
	local best = math.huge
	for _, m in monsters do
		best = math.min(best, (m.root.Position - pos).Magnitude)
	end
	return best
end

function MonsterService.start(context)
	ctx = context
	local f = Instance.new("Folder")
	f.Name = "Monsters"
	f.Parent = workspace
	folder = f
	unsubscribeNoise = Noise.subscribe(onNoise)
	local filterTimer = 0
	table.insert(
		connections,
		RunService.Heartbeat:Connect(function(dt)
			filterTimer -= dt
			if filterTimer <= 0 then
				filterTimer = 1
				refreshRayFilter()
			end
			local now = os.clock()
			for _, m in monsters do
				if m.alive then
					local ok, err = pcall(Brains[m.kind], m, dt, now)
					if not ok then
						warn("[Monster]", m.kind, err)
					end
				end
			end
		end)
	)
end

function MonsterService.stop()
	for _, c in connections do
		c:Disconnect()
	end
	table.clear(connections)
	if unsubscribeNoise then
		unsubscribeNoise()
		unsubscribeNoise = nil
	end
	for _, m in monsters do
		m.alive = false
	end
	table.clear(monsters)
	table.clear(spawned)
	if folder then
		folder:Destroy()
		folder = nil
	end
	ctx = nil
end

return MonsterService
