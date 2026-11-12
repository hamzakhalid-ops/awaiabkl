-- Valuables to haul back to the loading dock, plus flashlight batteries.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Noise = require(script.Parent.Noise)

local LootService = {}

local ctx = nil
local folder: Folder? = nil
local carrying = {} -- [Player] = Part

local function makePrompt(parent, action, object, hold)
	local p = Instance.new("ProximityPrompt")
	p.ActionText = action
	p.ObjectText = object
	p.HoldDuration = hold or 0
	p.MaxActivationDistance = 8
	p.RequiresLineOfSight = false
	p.KeyboardKeyCode = Enum.KeyCode.E
	p.Parent = parent
	return p
end

local function setCarryAttributes(player, part)
	player:SetAttribute("Carrying", if part then part.Name else "")
	player:SetAttribute("CarryValue", if part then part:GetAttribute("Value") else 0)
	player:SetAttribute("CarryWeight", if part then part:GetAttribute("Weight") else 0)
end

function LootService.pickUp(player: Player, part: BasePart)
	if not ctx or not ctx.isActive(player) or carrying[player] or part.Parent ~= folder then
		return
	end
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	part.Anchored = false
	part.CanCollide = false
	part.CanQuery = false
	part.Massless = true
	part.CFrame = root.CFrame * CFrame.new(0.9, -0.3, -2)
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = part
	weld.Parent = part
	local prompt = part:FindFirstChildOfClass("ProximityPrompt")
	if prompt then
		prompt.Enabled = false
	end
	carrying[player] = part
	setCarryAttributes(player, part)
end

function LootService.drop(player: Player, silent: boolean?)
	local part = carrying[player]
	if not part then
		return
	end
	carrying[player] = nil
	setCarryAttributes(player, nil)
	if not part.Parent then
		return
	end
	local weld = part:FindFirstChildOfClass("WeldConstraint")
	if weld then
		weld:Destroy()
	end
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local base = if root then root.Position else part.Position
	local floorY = if ctx then ctx.map.floorY else 0
	part.Anchored = true
	part.CanCollide = true
	part.CanQuery = true
	part.Massless = false
	part.CFrame = CFrame.new(base.X, floorY + part.Size.Y / 2, base.Z)
	local prompt = part:FindFirstChildOfClass("ProximityPrompt")
	if prompt then
		prompt.Enabled = true
	end
	if not silent then
		Noise.emit(part.Position, Config.NOISE_DROP, player)
	end
end

-- Returns the value of whatever the player held (and removes it), or 0.
function LootService.consume(player: Player)
	local part = carrying[player]
	if not part then
		return 0
	end
	carrying[player] = nil
	setCarryAttributes(player, nil)
	local value = part:GetAttribute("Value") or 0
	part:Destroy()
	return value
end

-- Random floor point in a room that avoids the generator in the middle.
local function lootPoint(map, room)
	local pos = map.randomPointIn(room, 6)
	if room.generator then
		local off = pos - room.center
		if math.abs(off.X) < 5 and math.abs(off.Z) < 5 then
			pos = room.center + Vector3.new(if off.X < 0 then -7 else 7, 0, off.Z)
		end
	end
	return pos
end

local function spawnLoot(def, pos: Vector3)
	local value = ctx.rng:NextInteger(def.min, def.max)
	local part = Instance.new("Part")
	part.Name = def.name
	part.Size = def.size
	part.Color = def.color
	part.Material = def.material
	part.Anchored = true
	part.CFrame = CFrame.new(pos + Vector3.new(0, def.size.Y / 2, 0)) * CFrame.Angles(0, ctx.rng:NextNumber(0, math.pi * 2), 0)
	part:SetAttribute("Value", value)
	part:SetAttribute("Weight", def.weight)
	part:SetAttribute("IsLoot", true)
	local glint = Instance.new("PointLight")
	glint.Range = 5
	glint.Brightness = 0.5
	glint.Color = Color3.fromRGB(255, 230, 170)
	glint.Parent = part
	local prompt = makePrompt(part, "Pick up", string.format("%s ($%d)", def.name, value), 0.25)
	prompt.Triggered:Connect(function(player)
		LootService.pickUp(player, part)
	end)
	part.Parent = folder
end

local function spawnBattery(pos: Vector3)
	local part = Instance.new("Part")
	part.Name = "Battery"
	part.Shape = Enum.PartType.Cylinder
	part.Size = Vector3.new(1.2, 0.6, 0.6)
	part.Color = Color3.fromRGB(80, 200, 255)
	part.Material = Enum.Material.Neon
	part.Anchored = true
	part.CFrame = CFrame.new(pos + Vector3.new(0, 0.3, 0))
	local prompt = makePrompt(part, "Take", "Battery (+" .. Config.BATTERY_REFILL .. "%)", 0)
	prompt.Triggered:Connect(function(player)
		if ctx and ctx.isActive(player) and part.Parent then
			ctx.addBattery(player, Config.BATTERY_REFILL)
			part:Destroy()
		end
	end)
	part.Parent = folder
end

function LootService.start(context)
	ctx = context
	local map = ctx.map
	local f = Instance.new("Folder")
	f.Name = "Loot"
	f.Parent = map.model
	folder = f

	local count = Config.LOOT_BASE + Config.LOOT_PER_PLAYER * #ctx.participants
	for _ = 1, count do
		local def = Config.LOOT[ctx.rng:NextInteger(1, #Config.LOOT)]
		spawnLoot(def, lootPoint(map, map.randomRoom(true)))
	end
	for _ = 1, Config.BATTERY_COUNT do
		spawnBattery(lootPoint(map, map.randomRoom(true)))
	end

	local depositPrompt = makePrompt(map.deposit, "Deposit", "Loading Chute", 0)
	depositPrompt.MaxActivationDistance = 10
	depositPrompt.Triggered:Connect(function(player)
		if not ctx or not ctx.isActive(player) then
			return
		end
		local name = player:GetAttribute("Carrying")
		local value = LootService.consume(player)
		if value > 0 then
			ctx.addCollected(value)
			ctx.notify(string.format("%s deposited %s (+$%d)", player.DisplayName, name, value), Color3.fromRGB(120, 230, 140))
		end
	end)
end

function LootService.getFolder()
	return folder
end

function LootService.stop()
	for player in carrying do
		setCarryAttributes(player, nil)
	end
	table.clear(carrying)
	folder = nil
	ctx = nil
end

return LootService
