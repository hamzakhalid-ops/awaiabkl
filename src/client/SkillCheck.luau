-- Timing minigame while repairing. Hit [Space] (or tap) when the needle is in the zone.
local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local SkillCheck = {}

local frame, zone, great, needle, title
local active = nil

local function make(class, props)
	local inst = Instance.new(class)
	local parent = props.Parent
	props.Parent = nil
	for k, v in props do
		inst[k] = v
	end
	inst.Parent = parent
	return inst
end

local function playPing()
	if Config.SOUNDS.SkillCheck ~= "" then
		local s = Instance.new("Sound")
		s.SoundId = Config.SOUNDS.SkillCheck
		s.Volume = 0.8
		SoundService:PlayLocalSound(s)
	end
end

local function finish(fraction)
	if not active then
		return
	end
	local id = active.id
	active = nil
	ContextActionService:UnbindAction("HS_SkillCheck")
	Remotes.SkillCheck:FireServer(id, fraction)
	title.Text = if fraction < 0 then "MISSED" else "..."
	task.delay(0.25, function()
		if not active then
			frame.Visible = false
		end
	end)
end

local function press()
	if active and active.live then
		finish(active.fraction)
	end
end

function SkillCheck.init(gui)
	frame = make("TextButton", {
		Parent = gui,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.64),
		Size = UDim2.new(0, 380, 0, 70),
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false,
		Visible = false,
		ZIndex = 20,
	})
	title = make("TextLabel", {
		Parent = frame,
		Size = UDim2.new(1, 0, 0, 30),
		BackgroundTransparency = 1,
		Font = Enum.Font.SpecialElite,
		TextSize = 24,
		TextColor3 = Color3.fromRGB(255, 230, 140),
		TextStrokeTransparency = 0.3,
		Text = "SKILL CHECK",
		ZIndex = 21,
	})
	local back = make("Frame", {
		Parent = frame,
		Position = UDim2.new(0, 0, 0, 36),
		Size = UDim2.new(1, 0, 0, 24),
		BackgroundColor3 = Color3.fromRGB(20, 20, 20),
		BorderSizePixel = 0,
		ZIndex = 21,
	})
	make("UIStroke", { Parent = back, Color = Color3.fromRGB(200, 200, 200), Thickness = 2 })
	zone = make("Frame", { Parent = back, BackgroundColor3 = Color3.fromRGB(230, 230, 230), BorderSizePixel = 0, Size = UDim2.fromScale(0.1, 1), ZIndex = 22 })
	great = make("Frame", { Parent = back, BackgroundColor3 = Color3.fromRGB(255, 200, 60), BorderSizePixel = 0, Size = UDim2.fromScale(0.03, 1), ZIndex = 23 })
	needle = make("Frame", { Parent = back, AnchorPoint = Vector2.new(0.5, 0), BackgroundColor3 = Color3.fromRGB(230, 30, 30), BorderSizePixel = 0, Size = UDim2.new(0, 4, 1, 10), Position = UDim2.new(0, 0, 0, -5), ZIndex = 24 })
	frame.Activated:Connect(press)

	Remotes.SkillCheck.OnClientEvent:Connect(function(id, zoneStart, zoneSize, greatSize, duration)
		active = { id = id, fraction = 0, live = false }
		local mine = active
		zone.Position = UDim2.fromScale(zoneStart, 0)
		zone.Size = UDim2.fromScale(zoneSize, 1)
		great.Position = UDim2.fromScale(zoneStart, 0)
		great.Size = UDim2.fromScale(greatSize, 1)
		needle.Position = UDim2.new(0, 0, 0, -5)
		title.Text = "SKILL CHECK"
		frame.Visible = true
		playPing()
		ContextActionService:BindActionAtPriority("HS_SkillCheck", function(_, state)
			if state == Enum.UserInputState.Begin then
				press()
			end
			return Enum.ContextActionResult.Sink
		end, false, Enum.ContextActionPriority.High.Value, Enum.KeyCode.Space, Enum.KeyCode.ButtonA)

		task.wait(0.6) -- warning beat
		if active ~= mine then
			return
		end
		mine.live = true
		local start = os.clock()
		while active == mine do
			local f = (os.clock() - start) / duration
			if f >= 1 then
				finish(-1)
				break
			end
			mine.fraction = f
			needle.Position = UDim2.new(f, 0, 0, -5)
			RunService.RenderStepped:Wait()
		end
	end)
end

return SkillCheck
