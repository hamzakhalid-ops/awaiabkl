-- Generators: stand still and repair; random skill checks; failures make noise.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Noise = require(script.Parent.Noise)

local GeneratorService = {}

local ctx = nil
local gens = {}
local repairing = {} -- [Player] = gen
local pending = {} -- [Player] = { id, gen, expires, zoneStart }
local connections = {}
local nextId = 0

local OFF = Color3.fromRGB(220, 40, 40)
local ON = Color3.fromRGB(60, 255, 110)

local function buildGenerator(room, index)
	local model = Instance.new("Model")
	model.Name = "Generator" .. index
	local base = room.center
	local body = Instance.new("Part")
	body.Name = "Body"
	body.Anchored = true
	body.Size = Vector3.new(6, 4, 4)
	body.CFrame = CFrame.new(base + Vector3.new(0, 2, 0))
	body.Material = Enum.Material.Metal
	body.Color = Color3.fromRGB(60, 70, 55)
	body.Parent = model
	local top = Instance.new("Part")
	top.Name = "Exhaust"
	top.Anchored = true
	top.Size = Vector3.new(1, 2, 1)
	top.CFrame = CFrame.new(base + Vector3.new(2, 5, 1))
	top.Material = Enum.Material.Metal
	top.Color = Color3.fromRGB(40, 40, 40)
	top.Parent = model
	local indicator = Instance.new("Part")
	indicator.Name = "Indicator"
	indicator.Anchored = true
	indicator.CanCollide = false
	indicator.Size = Vector3.new(1, 1, 0.3)
	indicator.CFrame = CFrame.new(base + Vector3.new(-1.5, 3, -2.1))
	indicator.Material = Enum.Material.Neon
	indicator.Color = OFF
	indicator.Parent = model
	local light = Instance.new("PointLight")
	light.Range = 12
	light.Brightness = 1.5
	light.Color = OFF
	light.Parent = indicator

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Repair"
	prompt.ObjectText = "Generator"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = Config.GEN_RANGE - 1
	prompt.RequiresLineOfSight = false
	prompt.Parent = body

	body:SetAttribute("Progress", 0)
	model.Parent = ctx.map.model

	local gen = {
		index = index,
		room = room,
		model = model,
		body = body,
		indicator = indicator,
		light = light,
		prompt = prompt,
		progress = 0,
		done = false,
	}
	prompt.Triggered:Connect(function(player)
		GeneratorService.beginRepair(player, gen)
	end)
	return gen
end

function GeneratorService.beginRepair(player, gen)
	if not ctx or gen.done or not ctx.isActive(player) then
		return
	end
	if player:GetAttribute("Carrying") ~= "" and player:GetAttribute("Carrying") ~= nil then
		ctx.notify("Drop what you're carrying [Q] before repairing.", Color3.fromRGB(255, 200, 120), player)
		return
	end
	repairing[player] = gen
	player:SetAttribute("Repairing", gen.index)
	player:SetAttribute("RepairProgress", gen.progress)
end

function GeneratorService.stopRepair(player)
	repairing[player] = nil
	pending[player] = nil
	if player.Parent then
		player:SetAttribute("Repairing", nil)
		player:SetAttribute("RepairProgress", nil)
	end
end

local function setProgress(gen, value)
	gen.progress = math.clamp(value, 0, 1)
	gen.body:SetAttribute("Progress", gen.progress)
end

local function complete(gen)
	gen.done = true
	setProgress(gen, 1)
	gen.indicator.Color = ON
	gen.light.Color = ON
	gen.prompt.Enabled = false
	for player, g in repairing do
		if g == gen then
			GeneratorService.stopRepair(player)
		end
	end
	ctx.map.lightAround(gen.room)
	ctx.onGeneratorDone()
end

local function failCheck(player, gen)
	setProgress(gen, gen.progress - Config.SKILLCHECK_FAIL_PENALTY)
	Noise.emit(gen.body.Position, Config.SKILLCHECK_NOISE, player)
	ctx.map.flash(gen.room)
	ctx.notify("The generator bangs loudly... something heard that.", Color3.fromRGB(255, 120, 90), player)
	-- sparks
	local sparks = Instance.new("Sparkles")
	sparks.SparkleColor = Color3.fromRGB(255, 200, 80)
	sparks.Parent = gen.indicator
	task.delay(1, function()
		sparks:Destroy()
	end)
end

local function sendSkillCheck(player, gen)
	nextId += 1
	local zoneStart = ctx.rng:NextNumber(0.45, 0.8)
	pending[player] = {
		id = nextId,
		gen = gen,
		zoneStart = zoneStart,
		expires = os.clock() + 0.6 + Config.SKILLCHECK_DURATION + 1.0,
	}
	Remotes.SkillCheck:FireClient(player, nextId, zoneStart, Config.SKILLCHECK_ZONE, Config.SKILLCHECK_GREAT, Config.SKILLCHECK_DURATION)
end

local function onResult(player, id, fraction)
	local p = pending[player]
	if not p or p.id ~= id or type(fraction) ~= "number" then
		return
	end
	pending[player] = nil
	if p.gen.done then
		return
	end
	if fraction >= p.zoneStart and fraction <= p.zoneStart + Config.SKILLCHECK_GREAT then
		setProgress(p.gen, p.gen.progress + Config.SKILLCHECK_GREAT_BONUS)
		if p.gen.progress >= 1 then
			complete(p.gen)
		end
	elseif fraction >= p.zoneStart and fraction <= p.zoneStart + Config.SKILLCHECK_ZONE then
		-- good: no change
	else
		failCheck(player, p.gen)
	end
end

local function update(dt)
	local now = os.clock()
	local helpers = {}
	for player, gen in repairing do
		local char = player.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		local root = char and char:FindFirstChild("HumanoidRootPart")
		local valid = not gen.done
			and ctx.isActive(player)
			and hum ~= nil
			and root ~= nil
			and (root.Position - gen.body.Position).Magnitude <= Config.GEN_RANGE + 1
			and hum.MoveDirection.Magnitude < 0.1
		if not valid then
			GeneratorService.stopRepair(player)
		else
			helpers[gen] = (helpers[gen] or 0) + 1
			if not pending[player] and ctx.rng:NextNumber() < Config.SKILLCHECK_CHANCE * dt then
				sendSkillCheck(player, gen)
			end
		end
	end
	for gen, n in helpers do
		local rate = (1 + Config.GEN_HELPER_BONUS * (n - 1)) / Config.GEN_REPAIR_TIME
		setProgress(gen, gen.progress + rate * dt)
		if gen.progress >= 1 then
			complete(gen)
		end
	end
	for player, gen in repairing do
		player:SetAttribute("RepairProgress", math.floor(gen.progress * 100) / 100)
	end
	for player, p in pending do
		if now > p.expires then
			pending[player] = nil
			if not p.gen.done then
				failCheck(player, p.gen)
			end
		end
	end
end

function GeneratorService.start(context)
	ctx = context
	for i, room in ctx.map.generatorRooms do
		table.insert(gens, buildGenerator(room, i))
	end
	table.insert(connections, RunService.Heartbeat:Connect(update))
	table.insert(connections, Remotes.SkillCheck.OnServerEvent:Connect(onResult))
	return #gens
end

function GeneratorService.stop()
	for _, c in connections do
		c:Disconnect()
	end
	table.clear(connections)
	for player in repairing do
		GeneratorService.stopRepair(player)
	end
	table.clear(pending)
	table.clear(gens)
	ctx = nil
end

return GeneratorService
