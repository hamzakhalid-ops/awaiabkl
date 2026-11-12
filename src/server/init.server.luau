-- HOLLOW SHIFT — round manager.
-- Lobby (wait for up to 5) -> generate facility -> night shift -> results -> repeat.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Lobby = require(script.Lobby)
local MapGenerator = require(script.MapGenerator)
local LootService = require(script.LootService)
local GeneratorService = require(script.GeneratorService)
local MonsterService = require(script.MonsterService)
local PlayerService = require(script.PlayerService)
local Stats = require(script.Stats)

Players.RespawnTime = 4

local function setState(key, value)
	ReplicatedStorage:SetAttribute(key, value)
end

local function status(text)
	setState("Status", text)
end

local function notify(text, color, player)
	if player then
		Remotes.Notify:FireClient(player, text, color)
	else
		Remotes.Notify:FireAllClients(text, color)
	end
end

---------------------------------------------------------------- lobby
local function lobbyPhase()
	setState("Phase", "Lobby")
	setState("TimeLeft", 0)
	local countdown = nil
	while true do
		local n = #Players:GetPlayers()
		if n < Config.MIN_PLAYERS then
			countdown = nil
			status(string.format("Waiting for crew... (%d/%d)", n, Config.MAX_PLAYERS))
		else
			local target = if n >= Config.MAX_PLAYERS then Config.FULL_LOBBY_COUNTDOWN else Config.LOBBY_COUNTDOWN
			countdown = math.min(countdown or target, target)
			status(string.format("Shift starts in %d  (%d/%d crew)", math.ceil(countdown), n, Config.MAX_PLAYERS))
			setState("TimeLeft", math.ceil(countdown))
			if countdown <= 0 then
				return
			end
			countdown -= 1
		end
		task.wait(1)
	end
end

---------------------------------------------------------------- round
local function runRound()
	local participants = {}
	for _, p in Players:GetPlayers() do
		if #participants < Config.MAX_PLAYERS then
			table.insert(participants, p)
		end
	end
	if #participants == 0 then
		return
	end

	setState("Phase", "Starting")
	status("Clocking in...")
	local rng = Random.new()
	local map = MapGenerator.generate(rng)

	local ctx = {
		rng = rng,
		map = map,
		participants = participants,
		enraged = false,
		collected = 0,
		quota = Config.QUOTA_BASE + Config.QUOTA_PER_PLAYER * #participants,
		gensDone = 0,
		gensTotal = 0,
		elevatorOpen = false,
		notify = notify,
	}
	local function checkObjectives()
		if not ctx.elevatorOpen and ctx.collected >= ctx.quota and ctx.gensDone >= ctx.gensTotal then
			ctx.elevatorOpen = true
			setState("ElevatorOpen", true)
			map.openElevator()
			notify("QUOTA MET. POWER RESTORED. The service elevator is OPEN — get everyone in!", Color3.fromRGB(90, 255, 140))
		end
	end
	function ctx.addCollected(value)
		ctx.collected += value
		setState("Collected", ctx.collected)
		if ctx.collected >= ctx.quota and ctx.collected - value < ctx.quota then
			notify("Quota reached!", Color3.fromRGB(120, 230, 140))
		end
		checkObjectives()
	end
	function ctx.onGeneratorDone()
		ctx.gensDone += 1
		setState("GensDone", ctx.gensDone)
		notify(string.format("Generator restored (%d/%d). The lights hum back to life nearby.", ctx.gensDone, ctx.gensTotal), Color3.fromRGB(120, 200, 255))
		checkObjectives()
	end
	ctx.isActive = PlayerService.isActive
	ctx.getActivePlayers = PlayerService.getActivePlayers
	ctx.getWatchers = PlayerService.getWatchers
	ctx.getLook = PlayerService.getLook
	ctx.damage = PlayerService.damage
	ctx.addBattery = PlayerService.addBattery

	setState("Quota", ctx.quota)
	setState("Collected", 0)
	setState("GensDone", 0)
	setState("ElevatorOpen", false)
	setState("ElevatorCountdown", -1)
	setState("Enraged", false)

	LootService.start(ctx)
	ctx.gensTotal = GeneratorService.start(ctx)
	setState("GensTotal", ctx.gensTotal)
	PlayerService.startRound(ctx, participants)
	MonsterService.start(ctx)

	setState("Phase", "Playing")
	status("Night shift")
	notify(string.format("Haul $%d of valuables to the chute and restore %d generators. Then reach the elevator.", ctx.quota, ctx.gensTotal), Color3.fromRGB(230, 220, 200))

	local timeLeft = Config.ROUND_TIME
	local elapsed = 0
	local departAt = nil
	local last = os.clock()
	local reason = nil

	while not reason do
		task.wait(0.25)
		local now = os.clock()
		local dt = now - last
		last = now
		timeLeft -= dt
		elapsed += dt
		setState("TimeLeft", math.max(0, math.ceil(timeLeft)))

		MonsterService.schedule(elapsed)

		if not ctx.enraged and timeLeft <= Config.ENRAGE_TIME then
			ctx.enraged = true
			setState("Enraged", true)
			map.setFlickerBoost(true)
			notify("The facility is waking up. GET OUT.", Color3.fromRGB(255, 50, 50))
		end

		if ctx.elevatorOpen then
			local watchers = PlayerService.getWatchers()
			local inside = {}
			for _, w in watchers do
				if map.inElevator(w.root.Position) then
					table.insert(inside, w.player)
				end
			end
			if #inside > 0 and not departAt then
				departAt = now + Config.ELEVATOR_COUNTDOWN
				notify(string.format("Elevator departs in %d seconds!", Config.ELEVATOR_COUNTDOWN), Color3.fromRGB(255, 220, 90))
			end
			if departAt then
				if #inside == #watchers and #inside > 0 and departAt - now > 3 then
					departAt = now + 3 -- everyone is in, go now
				end
				setState("ElevatorCountdown", math.max(0, math.ceil(departAt - now)))
				if now >= departAt then
					for _, p in inside do
						PlayerService.escape(p)
					end
					for _, w in PlayerService.getWatchers() do
						PlayerService.kill(w.player, "was left behind.")
					end
					reason = "elevator"
				end
			end
		end

		if not reason then
			local aliveCount, standing = PlayerService.countAlive()
			if timeLeft <= 0 then
				for _, w in PlayerService.getWatchers() do
					PlayerService.kill(w.player, "never clocked out.")
				end
				reason = "time"
			elseif aliveCount == 0 then
				reason = "wiped"
			elseif standing == 0 then
				for _, w in PlayerService.getWatchers() do
					PlayerService.kill(w.player, "was dragged into the dark.")
				end
				reason = "wiped"
			end
		end
	end

	---------------------------------------------------------------- results
	local escaped = {}
	for _, p in participants do
		if p.Parent and p:GetAttribute("Escaped") then
			table.insert(escaped, p.DisplayName)
			Stats.add(p, "Escapes", 1)
		end
		if p.Parent then
			Stats.add(p, "Nights", 1)
			if p:GetAttribute("Escaped") then
				Stats.add(p, "Earned", math.floor(ctx.collected / math.max(1, #participants)))
			end
		end
	end
	local won = #escaped > 0
	setState("Phase", "Ending")
	status(if won then "SHIFT SURVIVED" else "NO ONE CLOCKED OUT")
	Remotes.RoundEnd:FireAllClients({
		won = won,
		reason = reason,
		escaped = escaped,
		crew = #participants,
		collected = ctx.collected,
		quota = ctx.quota,
		gensDone = ctx.gensDone,
		gensTotal = ctx.gensTotal,
		survivedSeconds = math.floor(elapsed),
	})

	MonsterService.stop()
	GeneratorService.stop()
	LootService.stop()
	PlayerService.endRound()
	map.destroy()
	Stats.saveAll()

	task.wait(Config.POST_ROUND_TIME)
	PlayerService.resetAll()
	for _, p in Players:GetPlayers() do
		p.CameraMode = Enum.CameraMode.Classic
		task.spawn(function()
			p:LoadCharacter()
		end)
	end
end

---------------------------------------------------------------- boot
Lobby.cleanupDefaults()
Lobby.setupLighting()
Lobby.build()
Stats.init()
PlayerService.init()
setState("Phase", "Lobby")

while true do
	lobbyPhase()
	local ok, err = pcall(runRound)
	if not ok then
		warn("[HollowShift] round crashed:", err)
		pcall(MonsterService.stop)
		pcall(GeneratorService.stop)
		pcall(LootService.stop)
		pcall(PlayerService.endRound)
		local facility = workspace:FindFirstChild("Facility")
		if facility then
			facility:Destroy()
		end
		PlayerService.resetAll()
		for _, p in Players:GetPlayers() do
			task.spawn(function()
				p:LoadCharacter()
			end)
		end
		task.wait(3)
	end
end
