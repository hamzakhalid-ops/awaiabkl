-- Local-only horror: sanity post-processing, smooth flashlight, heartbeat,
-- camera shake, hallucinations, spectating.
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)

local player = Players.LocalPlayer
local Effects = {}

local cc, blur
local flashPart, flashLight
local heartbeat, ambience
local HUD
local spectateIndex = 1
local spectating = false
local lastStillPos = nil
local nextCreak = 0
local nextHallucination = 0

local function sound(id, parent, volume, looped)
	if not id or id == "" then
		return nil
	end
	local s = Instance.new("Sound")
	s.SoundId = id
	s.Volume = volume or 0.5
	s.Looped = looped or false
	s.Parent = parent or SoundService
	return s
end

local function playOnce(id, volume)
	local s = sound(id, SoundService, volume)
	if s then
		s.PlayOnRemove = false
		s:Play()
		s.Ended:Once(function()
			s:Destroy()
		end)
	end
end
Effects.playOnce = playOnce

local function isActive()
	return (ReplicatedStorage:GetAttribute("Phase") == "Playing")
		and player:GetAttribute("InRound") == true
		and not player:GetAttribute("Dead")
		and not player:GetAttribute("Escaped")
end

local function spectateTargets()
	local list = {}
	for _, p in Players:GetPlayers() do
		if p ~= player and p:GetAttribute("InRound") and not p:GetAttribute("Dead") and not p:GetAttribute("Escaped") then
			local hum = p.Character and p.Character:FindFirstChildOfClass("Humanoid")
			if hum then
				table.insert(list, { player = p, hum = hum })
			end
		end
	end
	return list
end

function Effects.cycleSpectate(dir)
	spectateIndex += dir
end

local function hallucinate(camera)
	-- a dark figure at the edge of vision that vanishes
	local side = if math.random() < 0.5 then -1 else 1
	local cf = camera.CFrame
	local pos = cf.Position + cf.LookVector * math.random(18, 30) + cf.RightVector * side * math.random(10, 16)
	local figure = Instance.new("Part")
	figure.Anchored = true
	figure.CanCollide = false
	figure.CanQuery = false
	figure.CanTouch = false
	figure.Size = Vector3.new(1.8, 8, 1)
	figure.Color = Color3.new(0, 0, 0)
	figure.Material = Enum.Material.SmoothPlastic
	figure.CFrame = CFrame.lookAt(Vector3.new(pos.X, 4, pos.Z), Vector3.new(cf.Position.X, 4, cf.Position.Z))
	figure.Parent = camera
	for _, x in { -0.35, 0.35 } do
		local eye = Instance.new("Part")
		eye.Anchored = true
		eye.CanCollide = false
		eye.CanQuery = false
		eye.Size = Vector3.new(0.25, 0.15, 0.1)
		eye.Material = Enum.Material.Neon
		eye.Color = Color3.fromRGB(255, 255, 255)
		eye.CFrame = figure.CFrame * CFrame.new(x, 3.2, -0.55)
		eye.Parent = figure
	end
	playOnce(Config.SOUNDS.Whisper, 0.6)
	task.delay(math.random(25, 60) / 100, function()
		figure:Destroy()
	end)
end

function Effects.init(hud)
	HUD = hud
	cc = Instance.new("ColorCorrectionEffect")
	cc.Name = "HS_Sanity"
	cc.Parent = Lighting
	blur = Instance.new("BlurEffect")
	blur.Name = "HS_Blur"
	blur.Size = 0
	blur.Parent = Lighting

	flashPart = Instance.new("Part")
	flashPart.Name = "HS_LocalFlashlight"
	flashPart.Anchored = true
	flashPart.CanCollide = false
	flashPart.CanQuery = false
	flashPart.CanTouch = false
	flashPart.Transparency = 1
	flashPart.Size = Vector3.new(0.2, 0.2, 0.2)
	flashLight = Instance.new("SpotLight")
	flashLight.Angle = 55
	flashLight.Range = 60
	flashLight.Brightness = 2.5
	flashLight.Shadows = true
	flashLight.Color = Color3.fromRGB(255, 245, 225)
	flashLight.Face = Enum.NormalId.Front
	flashLight.Enabled = false
	flashLight.Parent = flashPart
	flashPart.Parent = Workspace.CurrentCamera

	heartbeat = sound(Config.SOUNDS.Heartbeat, SoundService, 0, true)
	if heartbeat then
		heartbeat:Play()
	end
	ambience = sound(Config.SOUNDS.Ambience, SoundService, 0, true)
	if ambience then
		ambience:Play()
	end

	UserInputService.InputBegan:Connect(function(input, processed)
		if processed or not spectating then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.KeyCode == Enum.KeyCode.RightBracket or input.KeyCode == Enum.KeyCode.ButtonR1 then
			Effects.cycleSpectate(1)
		elseif input.KeyCode == Enum.KeyCode.LeftBracket or input.KeyCode == Enum.KeyCode.ButtonL1 then
			Effects.cycleSpectate(-1)
		end
	end)
	UserInputService.TouchTap:Connect(function(_, processed)
		if spectating and not processed then
			Effects.cycleSpectate(1)
		end
	end)

	RunService:BindToRenderStep("HS_Effects", Enum.RenderPriority.Camera.Value + 1, Effects.render)
end

function Effects.render(dt)
	local camera = Workspace.CurrentCamera
	local active = isActive()
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local root = char and char:FindFirstChild("HumanoidRootPart")
	local now = os.clock()

	---------------------------------------------------------------- spectating
	local phase = ReplicatedStorage:GetAttribute("Phase")
	local wantSpectate = phase == "Playing" and player:GetAttribute("InRound") == true and (player:GetAttribute("Dead") or player:GetAttribute("Escaped"))
	if wantSpectate then
		local targets = spectateTargets()
		if #targets > 0 then
			spectateIndex = (spectateIndex - 1) % #targets + 1
			local t = targets[spectateIndex]
			camera.CameraSubject = t.hum
			spectating = true
			HUD.setSpectate("Spectating " .. t.player.DisplayName .. "  —  click / tap to switch")
		else
			HUD.setSpectate(if player:GetAttribute("Escaped") then "You escaped. Waiting for the shift to end..." else "Waiting for the shift to end...")
		end
	elseif spectating then
		spectating = false
		HUD.setSpectate(nil)
		if hum then
			camera.CameraSubject = hum
		end
	end

	---------------------------------------------------------------- flashlight
	flashPart.CFrame = camera.CFrame * CFrame.new(0.6, -0.4, 0)
	flashLight.Enabled = active and player:GetAttribute("Flashlight") == true
	local battery = player:GetAttribute("Battery") or 100
	flashLight.Brightness = if battery < 15 and math.random() < 0.15 then 0.4 else 2.5
	-- hide our own server-side spotlight locally (others still see it)
	local head = char and char:FindFirstChild("Head")
	local serverLight = head and head:FindFirstChild("Flashlight")
	if serverLight and serverLight.Brightness ~= 0 then
		serverLight.Brightness = 0
	end
	-- you can't revive yourself
	local selfPrompt = root and root:FindFirstChild("RevivePrompt")
	if selfPrompt and selfPrompt.Enabled then
		selfPrompt.Enabled = false
	end

	---------------------------------------------------------------- camera offset
	if hum then
		local target = Vector3.zero
		if active and player:GetAttribute("Downed") then
			target = Vector3.new(0, -2.4, 0)
		elseif active and player:GetAttribute("Crouching") then
			target = Vector3.new(0, -1.3, 0)
		end
		hum.CameraOffset = hum.CameraOffset:Lerp(target, math.min(1, dt * 10))
	end

	---------------------------------------------------------------- sanity & HP grading
	local sanity = if active then (player:GetAttribute("Sanity") or 100) / 100 else 1
	local hp = if active then (player:GetAttribute("HP") or 100) / 100 else 1
	local insanity = 1 - sanity
	cc.Saturation = -0.15 - 0.75 * insanity
	cc.Contrast = 0.1 + 0.25 * insanity
	cc.Brightness = -0.02 * insanity
	cc.TintColor = Color3.new(1, 0.75 + 0.25 * hp, 0.75 + 0.25 * hp)
	local blurTarget = 0
	if active and player:GetAttribute("Downed") then
		blurTarget = 10
	elseif sanity < Config.LOW_SANITY / 100 then
		blurTarget = (1 - sanity / (Config.LOW_SANITY / 100)) * 6
	end
	blur.Size += (blurTarget - blur.Size) * math.min(1, dt * 4)
	camera.FieldOfView = 70 + math.sin(now * 1.3) * 4 * insanity

	if active and sanity < Config.LOW_SANITY / 100 and now > nextHallucination then
		nextHallucination = now + math.random(6, 14)
		if math.random() < 0.6 then
			hallucinate(camera)
		end
	end

	---------------------------------------------------------------- monster proximity
	local nearest = math.huge
	local monsters = Workspace:FindFirstChild("Monsters")
	if active and root and monsters then
		for _, m in monsters:GetChildren() do
			local pp = m.PrimaryPart
			if pp then
				local d = (pp.Position - root.Position).Magnitude
				nearest = math.min(nearest, d)
				if m.Name == "Still" then
					if lastStillPos and (pp.Position - lastStillPos).Magnitude > 0.05 and d < 50 and now > nextCreak then
						nextCreak = now + 0.35
						playOnce(Config.SOUNDS.StillCreak, 0.4 + 0.6 * (1 - d / 50))
					end
					lastStillPos = pp.Position
				end
			end
		end
	end
	local fear = math.clamp(1 - nearest / 40, 0, 1)
	if heartbeat then
		heartbeat.Volume = fear * 1.2
		heartbeat.PlaybackSpeed = 1 + fear * 0.6
	end
	if ambience then
		ambience.Volume = if active then 0.35 else 0
	end
	local shake = fear * fear * 0.6 + (if active and player:GetAttribute("Downed") then 0.15 else 0) + insanity * 0.08
	if shake > 0.02 then
		camera.CFrame *= CFrame.Angles(math.rad((math.random() - 0.5) * shake), math.rad((math.random() - 0.5) * shake), 0)
	end
end

return Effects
