-- Builds the lobby room and the global horror lighting.
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local Lobby = {}

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

function Lobby.cleanupDefaults()
	-- Template places ship with a baseplate/spawn that would overlap the facility.
	local baseplate = workspace:FindFirstChild("Baseplate")
	if baseplate then
		baseplate:Destroy()
	end
	for _, d in workspace:GetDescendants() do
		if d:IsA("SpawnLocation") then
			d:Destroy()
		end
	end
end

function Lobby.setupLighting()
	Lighting.ClockTime = 0
	Lighting.Brightness = 0.3
	Lighting.Ambient = Color3.fromRGB(10, 10, 14)
	Lighting.OutdoorAmbient = Color3.fromRGB(14, 14, 20)
	Lighting.GlobalShadows = true
	Lighting.EnvironmentDiffuseScale = 0
	Lighting.EnvironmentSpecularScale = 0
	for _, child in Lighting:GetChildren() do
		if child:IsA("Atmosphere") or child:IsA("Sky") or child:IsA("PostEffect") then
			child:Destroy()
		end
	end
	local atmosphere = Instance.new("Atmosphere")
	atmosphere.Density = 0.5
	atmosphere.Offset = 0
	atmosphere.Color = Color3.fromRGB(18, 18, 24)
	atmosphere.Decay = Color3.fromRGB(8, 8, 12)
	atmosphere.Glare = 0
	atmosphere.Haze = 1.5
	atmosphere.Parent = Lighting
end

function Lobby.build()
	local o = Config.LOBBY_ORIGIN
	local folder = Instance.new("Model")
	folder.Name = "Lobby"

	newPart(folder, {
		Name = "Floor",
		Size = Vector3.new(80, 1, 80),
		Position = o - Vector3.new(0, 0.5, 0),
		Material = Enum.Material.WoodPlanks,
		Color = Color3.fromRGB(60, 45, 35),
	})
	newPart(folder, {
		Name = "Ceiling",
		Size = Vector3.new(80, 1, 80),
		Position = o + Vector3.new(0, 20.5, 0),
		Material = Enum.Material.Concrete,
		Color = Color3.fromRGB(30, 30, 30),
	})
	for _, w in {
		{ Vector3.new(0, 10, 40), Vector3.new(80, 20, 1) },
		{ Vector3.new(0, 10, -40), Vector3.new(80, 20, 1) },
		{ Vector3.new(40, 10, 0), Vector3.new(1, 20, 80) },
		{ Vector3.new(-40, 10, 0), Vector3.new(1, 20, 80) },
	} do
		newPart(folder, {
			Name = "Wall",
			Size = w[2],
			Position = o + w[1],
			Material = Enum.Material.Brick,
			Color = Color3.fromRGB(70, 40, 35),
		})
	end

	for _, offset in { Vector3.new(-20, 19.5, -20), Vector3.new(20, 19.5, -20), Vector3.new(-20, 19.5, 20), Vector3.new(20, 19.5, 20) } do
		local lamp = newPart(folder, {
			Name = "Lamp",
			Size = Vector3.new(3, 0.5, 3),
			Position = o + offset,
			Material = Enum.Material.Neon,
			Color = Color3.fromRGB(255, 200, 140),
			CanCollide = false,
		})
		local light = Instance.new("PointLight")
		light.Range = 40
		light.Brightness = 1.2
		light.Color = Color3.fromRGB(255, 190, 130)
		light.Shadows = true
		light.Parent = lamp
	end

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "LobbySpawn"
	spawn.Anchored = true
	spawn.Size = Vector3.new(12, 1, 12)
	spawn.Position = o + Vector3.new(0, 0.01, 10)
	spawn.Material = Enum.Material.Slate
	spawn.Color = Color3.fromRGB(50, 50, 55)
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Transparency = 0
	spawn.CanCollide = true
	spawn.Parent = folder

	-- Title board
	local board = newPart(folder, {
		Name = "TitleBoard",
		Size = Vector3.new(34, 12, 1),
		Position = o + Vector3.new(0, 10, -39),
		Material = Enum.Material.SmoothPlastic,
		Color = Color3.fromRGB(10, 10, 10),
	})
	local sg = Instance.new("SurfaceGui")
	sg.Face = Enum.NormalId.Back
	sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	sg.PixelsPerStud = 30
	sg.LightInfluence = 0
	sg.Parent = board
	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Size = UDim2.fromScale(1, 0.55)
	title.Font = Enum.Font.SpecialElite
	title.TextScaled = true
	title.TextColor3 = Color3.fromRGB(200, 30, 30)
	title.Text = Config.GAME_NAME
	title.Parent = sg
	local sub = Instance.new("TextLabel")
	sub.BackgroundTransparency = 1
	sub.Position = UDim2.fromScale(0.05, 0.55)
	sub.Size = UDim2.fromScale(0.9, 0.4)
	sub.Font = Enum.Font.SpecialElite
	sub.TextScaled = true
	sub.TextWrapped = true
	sub.TextColor3 = Color3.fromRGB(220, 210, 190)
	sub.Text = Config.TAGLINE .. "\nCrew of up to " .. Config.MAX_PLAYERS .. " players"
	sub.Parent = sg

	folder.Parent = workspace
	return spawn
end

return Lobby
