-- Procedurally builds the facility: a grid of rooms carved into a maze with
-- extra loops, a safe loading dock, a service elevator, and lights that die.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local MapGenerator = {}

local DIRS = { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }
local LIT_COLOR = Color3.fromRGB(255, 214, 160)
local DEAD_COLOR = Color3.fromRGB(40, 40, 40)
local WALL_COLORS = {
	Color3.fromRGB(88, 92, 84),
	Color3.fromRGB(96, 88, 78),
	Color3.fromRGB(70, 78, 82),
	Color3.fromRGB(84, 72, 70),
}

local function newPart(parent, props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in props do
		p[k] = v
	end
	p.Parent = parent
	return p
end

function MapGenerator.generate(rng: Random)
	local W, H, S = Config.GRID_W, Config.GRID_H, Config.ROOM_SIZE
	local T, WH = Config.WALL_THICKNESS, Config.WALL_HEIGHT
	local DW, DH = Config.DOOR_WIDTH, Config.DOOR_HEIGHT
	local origin = Config.MAP_ORIGIN
	local floorY = origin.Y

	local model = Instance.new("Model")
	model.Name = "Facility"
	local geo = Instance.new("Folder")
	geo.Name = "Geometry"
	geo.Parent = model

	---------------------------------------------------------------- maze
	local hLink, vLink = {}, {} -- hLink[x][y]: (x,y)<->(x+1,y); vLink[x][y]: (x,y)<->(x,y+1)
	for x = 1, W do
		hLink[x], vLink[x] = {}, {}
	end
	local function link(ax, ay, bx, by)
		if ax == bx then
			vLink[ax][math.min(ay, by)] = true
		else
			hLink[math.min(ax, bx)][ay] = true
		end
	end
	local function inBounds(x, y)
		return x >= 1 and x <= W and y >= 1 and y <= H
	end

	local visited = {}
	local stack = { { 1, 1 } }
	visited[1] = true
	while #stack > 0 do
		local cur = stack[#stack]
		local options = {}
		for _, d in DIRS do
			local nx, ny = cur[1] + d[1], cur[2] + d[2]
			if inBounds(nx, ny) and not visited[nx + (ny - 1) * W] then
				table.insert(options, { nx, ny })
			end
		end
		if #options == 0 then
			table.remove(stack)
		else
			local n = options[rng:NextInteger(1, #options)]
			link(cur[1], cur[2], n[1], n[2])
			visited[n[1] + (n[2] - 1) * W] = true
			table.insert(stack, n)
		end
	end
	for _ = 1, Config.EXTRA_LINKS do
		local x, y = rng:NextInteger(1, W), rng:NextInteger(1, H)
		local d = DIRS[rng:NextInteger(1, 4)]
		if inBounds(x + d[1], y + d[2]) then
			link(x, y, x + d[1], y + d[2])
		end
	end

	local function cellCenter(x, y)
		return origin + Vector3.new((x - 1) * S, 0, (y - 1) * S)
	end

	---------------------------------------------------------------- shell
	local mid = origin + Vector3.new((W - 1) * S / 2, 0, (H - 1) * S / 2)
	newPart(geo, {
		Name = "Floor",
		Size = Vector3.new(W * S + 4, 1, H * S + 4),
		Position = mid - Vector3.new(0, 0.5, 0),
		Material = Enum.Material.Concrete,
		Color = Color3.fromRGB(45, 43, 40),
	})
	newPart(geo, {
		Name = "Ceiling",
		Size = Vector3.new(W * S + 4, 1, H * S + 4),
		Position = mid + Vector3.new(0, WH + 0.5, 0),
		Material = Enum.Material.Concrete,
		Color = Color3.fromRGB(28, 28, 28),
	})

	local function wall(cx, cz, alongX, length, height, yBase, color)
		local size = if alongX then Vector3.new(length, height, T) else Vector3.new(T, height, length)
		newPart(geo, {
			Name = "Wall",
			Size = size,
			Position = Vector3.new(cx, yBase + height / 2, cz),
			Material = Enum.Material.Concrete,
			Color = color,
		})
	end

	local function wallLine(cx, cz, alongX, hasDoor, color)
		if not hasDoor then
			wall(cx, cz, alongX, S, WH, floorY, color)
			return
		end
		local segLen = (S - DW) / 2
		local off = DW / 2 + segLen / 2
		if alongX then
			wall(cx - off, cz, true, segLen, WH, floorY, color)
			wall(cx + off, cz, true, segLen, WH, floorY, color)
		else
			wall(cx, cz - off, false, segLen, WH, floorY, color)
			wall(cx, cz + off, false, segLen, WH, floorY, color)
		end
		wall(cx, cz, alongX, DW, WH - DH, floorY + DH, color) -- lintel
	end

	-- walls running along Z (between columns)
	for x = 0, W do
		for y = 1, H do
			local cx = origin.X + (x - 1) * S + S / 2
			local cz = origin.Z + (y - 1) * S
			local door = (x >= 1 and x < W and hLink[x][y] == true) or (x == 0 and y == 1) -- (0,1) = elevator
			wallLine(cx, cz, false, door, WALL_COLORS[rng:NextInteger(1, #WALL_COLORS)])
		end
	end
	-- walls running along X (between rows)
	for y = 0, H do
		for x = 1, W do
			local cx = origin.X + (x - 1) * S
			local cz = origin.Z + (y - 1) * S + S / 2
			local door = y >= 1 and y < H and vLink[x][y] == true
			wallLine(cx, cz, true, door, WALL_COLORS[rng:NextInteger(1, #WALL_COLORS)])
		end
	end
	-- corner pillars hide seams
	for x = 0, W do
		for y = 0, H do
			newPart(geo, {
				Name = "Pillar",
				Size = Vector3.new(2, WH, 2),
				Position = Vector3.new(origin.X + (x - 1) * S + S / 2, floorY + WH / 2, origin.Z + (y - 1) * S + S / 2),
				Material = Enum.Material.Concrete,
				Color = Color3.fromRGB(55, 55, 55),
			})
		end
	end

	---------------------------------------------------------------- rooms
	local rooms, grid = {}, {}
	for x = 1, W do
		grid[x] = {}
		for y = 1, H do
			local safe = x == 1 and y == 1
			local center = cellCenter(x, y)
			local lit = safe or rng:NextNumber() > Config.DARK_ROOM_CHANCE
			local lamp = newPart(geo, {
				Name = "Lamp",
				Size = Vector3.new(4, 0.4, 4),
				Position = center + Vector3.new(0, WH - 0.2, 0),
				Material = if lit then Enum.Material.Neon else Enum.Material.SmoothPlastic,
				Color = if lit then LIT_COLOR else DEAD_COLOR,
				CanCollide = false,
			})
			local light = Instance.new("PointLight")
			light.Range = 30
			light.Brightness = 1.3
			light.Color = LIT_COLOR
			light.Shadows = true
			light.Enabled = lit
			light.Parent = lamp

			local room = {
				x = x,
				y = y,
				center = center,
				lit = lit,
				safe = safe,
				lamp = lamp,
				light = light,
				flicker = not safe and lit and rng:NextNumber() < Config.FLICKER_CHANCE,
				dist = (x - 1) + (y - 1),
			}
			grid[x][y] = room
			table.insert(rooms, room)

			-- clutter in the corners (never blocks doorways or the center)
			if not safe then
				local corners = {
					Vector3.new(1, 0, 1),
					Vector3.new(-1, 0, 1),
					Vector3.new(1, 0, -1),
					Vector3.new(-1, 0, -1),
				}
				for _ = 1, rng:NextInteger(0, 3) do
					local c = table.remove(corners, rng:NextInteger(1, #corners))
					local size = rng:NextNumber(3, 5)
					local pos = center + c * (S / 2 - 3.5) + Vector3.new(0, size / 2, 0)
					newPart(geo, {
						Name = "Crate",
						Size = Vector3.new(size, size, size),
						CFrame = CFrame.new(pos) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0),
						Material = Enum.Material.WoodPlanks,
						Color = Color3.fromRGB(110, 80, 50),
					})
				end
				if rng:NextNumber() < 0.35 then
					newPart(geo, {
						Name = "Stain",
						Size = Vector3.new(rng:NextNumber(2, 5), 0.05, rng:NextNumber(2, 4)),
						CFrame = CFrame.new(center + Vector3.new(rng:NextNumber(-10, 10), 0.03, rng:NextNumber(-10, 10)))
							* CFrame.Angles(0, rng:NextNumber(0, math.pi), 0),
						Material = Enum.Material.SmoothPlastic,
						Color = Color3.fromRGB(70, 8, 8),
						CanCollide = false,
						CanQuery = false,
					})
				end
			end
		end
	end

	---------------------------------------------------------------- loading dock
	local start = grid[1][1]
	local deposit = newPart(geo, {
		Name = "DepositChute",
		Size = Vector3.new(7, 5, 2),
		Position = start.center + Vector3.new(4, 2.5, -S / 2 + 1.5),
		Material = Enum.Material.DiamondPlate,
		Color = Color3.fromRGB(90, 90, 95),
	})
	newPart(geo, {
		Name = "ChuteSign",
		Size = Vector3.new(7, 0.6, 0.2),
		Position = deposit.Position + Vector3.new(0, 3, 1),
		Material = Enum.Material.Neon,
		Color = Color3.fromRGB(80, 220, 120),
		CanCollide = false,
	})

	-- Service elevator cab outside the west wall of the dock
	local cabSize = 14
	local cabCenter = start.center + Vector3.new(-S / 2 - cabSize / 2, 0, 0)
	newPart(geo, { Name = "CabFloor", Size = Vector3.new(cabSize, 1, cabSize), Position = cabCenter - Vector3.new(0, 0.5, 0), Material = Enum.Material.DiamondPlate, Color = Color3.fromRGB(70, 70, 75) })
	newPart(geo, { Name = "CabCeiling", Size = Vector3.new(cabSize, 1, cabSize), Position = cabCenter + Vector3.new(0, DH + 1.5, 0), Material = Enum.Material.Metal, Color = Color3.fromRGB(50, 50, 55) })
	newPart(geo, { Name = "CabWall", Size = Vector3.new(1, DH + 2, cabSize), Position = cabCenter + Vector3.new(-cabSize / 2, (DH + 2) / 2, 0), Material = Enum.Material.Metal, Color = Color3.fromRGB(60, 60, 65) })
	newPart(geo, { Name = "CabWall", Size = Vector3.new(cabSize, DH + 2, 1), Position = cabCenter + Vector3.new(0, (DH + 2) / 2, cabSize / 2), Material = Enum.Material.Metal, Color = Color3.fromRGB(60, 60, 65) })
	newPart(geo, { Name = "CabWall", Size = Vector3.new(cabSize, DH + 2, 1), Position = cabCenter + Vector3.new(0, (DH + 2) / 2, -cabSize / 2), Material = Enum.Material.Metal, Color = Color3.fromRGB(60, 60, 65) })
	local cabLamp = newPart(geo, { Name = "CabLamp", Size = Vector3.new(2, 0.3, 2), Position = cabCenter + Vector3.new(0, DH + 0.85, 0), Material = Enum.Material.Neon, Color = Color3.fromRGB(200, 30, 30), CanCollide = false })
	local cabLight = Instance.new("PointLight")
	cabLight.Range = 16
	cabLight.Brightness = 1.5
	cabLight.Color = Color3.fromRGB(255, 40, 40)
	cabLight.Parent = cabLamp
	local elevatorDoor = newPart(geo, {
		Name = "ElevatorDoor",
		Size = Vector3.new(T + 0.4, DH, DW),
		Position = Vector3.new(origin.X - S / 2, floorY + DH / 2, start.center.Z),
		Material = Enum.Material.Metal,
		Color = Color3.fromRGB(120, 120, 125),
	})

	-- Spawn points around the dock
	local spawnPoints = {}
	for i = 1, Config.MAX_PLAYERS do
		local a = (i / Config.MAX_PLAYERS) * math.pi * 2
		table.insert(spawnPoints, start.center + Vector3.new(math.cos(a) * 6, 3, math.sin(a) * 6))
	end

	---------------------------------------------------------------- generator rooms
	local candidates = {}
	for _, r in rooms do
		if r.dist >= 4 then
			table.insert(candidates, r)
		end
	end
	for i = #candidates, 2, -1 do
		local j = rng:NextInteger(1, i)
		candidates[i], candidates[j] = candidates[j], candidates[i]
	end
	local generatorRooms = {}
	local function farFromChosen(r)
		for _, g in generatorRooms do
			if math.abs(g.x - r.x) + math.abs(g.y - r.y) < 3 then
				return false
			end
		end
		return true
	end
	for _, r in candidates do
		if #generatorRooms >= Config.GENERATOR_COUNT then
			break
		end
		if farFromChosen(r) then
			table.insert(generatorRooms, r)
		end
	end
	for _, r in candidates do
		if #generatorRooms >= Config.GENERATOR_COUNT then
			break
		end
		if not table.find(generatorRooms, r) then
			table.insert(generatorRooms, r)
		end
	end
	for _, r in generatorRooms do
		r.generator = true
	end

	model.Parent = workspace

	---------------------------------------------------------------- API
	local map = {
		model = model,
		rooms = rooms,
		grid = grid,
		origin = origin,
		floorY = floorY,
		roomSize = S,
		startRoom = start,
		deposit = deposit,
		spawnPoints = spawnPoints,
		generatorRooms = generatorRooms,
		elevatorDoor = elevatorDoor,
		alive = true,
		flickerBoost = false,
	}

	function map.roomAt(pos: Vector3)
		local x = math.floor((pos.X - origin.X + S / 2) / S) + 1
		local y = math.floor((pos.Z - origin.Z + S / 2) / S) + 1
		return grid[x] and grid[x][y]
	end

	function map.setLit(room, lit)
		room.lit = lit
		room.light.Enabled = lit
		room.lamp.Material = if lit then Enum.Material.Neon else Enum.Material.SmoothPlastic
		room.lamp.Color = if lit then LIT_COLOR else DEAD_COLOR
	end

	-- Restore power to a room and its neighbours (generator finished)
	function map.lightAround(room)
		map.setLit(room, true)
		room.flicker = false
		for _, d in DIRS do
			local n = grid[room.x + d[1]] and grid[room.x + d[1]][room.y + d[2]]
			if n then
				map.setLit(n, true)
			end
		end
	end

	function map.randomRoom(excludeStart: boolean?)
		while true do
			local r = rooms[rng:NextInteger(1, #rooms)]
			if not (excludeStart and r.safe) then
				return r
			end
		end
	end

	function map.randomPointIn(room, margin: number?)
		local m = S / 2 - (margin or 5)
		return room.center + Vector3.new(rng:NextNumber(-m, m), 0, rng:NextNumber(-m, m))
	end

	function map.inElevator(pos: Vector3)
		local half = cabSize / 2 - 0.5
		return pos.X < origin.X - S / 2 - 0.5
			and math.abs(pos.X - cabCenter.X) <= half
			and math.abs(pos.Z - cabCenter.Z) <= half
			and pos.Y < floorY + DH + 2
	end

	function map.openElevator()
		elevatorDoor.CanCollide = false
		elevatorDoor.Transparency = 0.85
		cabLamp.Color = Color3.fromRGB(60, 255, 100)
		cabLight.Color = Color3.fromRGB(60, 255, 100)
	end

	function map.setFlickerBoost(on)
		map.flickerBoost = on
	end

	function map.flash(room)
		task.spawn(function()
			for _ = 1, 4 do
				room.light.Enabled = false
				task.wait(0.06)
				room.light.Enabled = room.lit
				task.wait(0.06)
			end
		end)
	end

	function map.destroy()
		map.alive = false
		model:Destroy()
	end

	-- flicker thread
	task.spawn(function()
		while map.alive do
			for _, room in rooms do
				local chance = if map.flickerBoost then 0.25 else 0.08
				if room.lit and (room.flicker or (map.flickerBoost and not room.safe)) and rng:NextNumber() < chance then
					task.spawn(function()
						room.light.Enabled = false
						room.lamp.Color = DEAD_COLOR
						task.wait(rng:NextNumber(0.05, 0.35))
						if map.alive then
							room.light.Enabled = room.lit
							room.lamp.Color = if room.lit then LIT_COLOR else DEAD_COLOR
						end
					end)
				end
			end
			task.wait(0.25)
		end
	end)

	return map
end

return MapGenerator
