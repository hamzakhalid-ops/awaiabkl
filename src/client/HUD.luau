-- All on-screen UI, built in code.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)

local player = Players.LocalPlayer
local HUD = {}

local FONT = Enum.Font.SpecialElite
local BODY_FONT = Enum.Font.GothamMedium
local refs = {}

local function make(class, props, children)
	local inst = Instance.new(class)
	local parent = props.Parent
	props.Parent = nil
	for k, v in props do
		inst[k] = v
	end
	for _, c in children or {} do
		c.Parent = inst
	end
	inst.Parent = parent
	return inst
end

local function label(props)
	props.BackgroundTransparency = props.BackgroundTransparency or 1
	props.Font = props.Font or BODY_FONT
	props.TextColor3 = props.TextColor3 or Color3.fromRGB(230, 220, 200)
	props.TextStrokeTransparency = props.TextStrokeTransparency or 0.6
	return make("TextLabel", props)
end

local function corner(r)
	return make("UICorner", { CornerRadius = UDim.new(0, r or 6) })
end

local function panel(props)
	props.BackgroundColor3 = props.BackgroundColor3 or Color3.fromRGB(8, 8, 10)
	props.BackgroundTransparency = props.BackgroundTransparency or 0.35
	props.BorderSizePixel = 0
	return make("Frame", props, { corner(8) })
end

local function bar(parent, order, name, color)
	local holder = make("Frame", { Parent = parent, Size = UDim2.new(1, 0, 0, 20), BackgroundTransparency = 1, LayoutOrder = order })
	label({ Parent = holder, Size = UDim2.new(0, 70, 1, 0), Text = name, TextXAlignment = Enum.TextXAlignment.Left, TextSize = 14, Font = FONT })
	local back = make("Frame", { Parent = holder, Position = UDim2.new(0, 72, 0.5, -6), Size = UDim2.new(1, -112, 0, 12), BackgroundColor3 = Color3.fromRGB(30, 30, 30), BorderSizePixel = 0 }, { corner(4) })
	local fill = make("Frame", { Parent = back, Size = UDim2.fromScale(1, 1), BackgroundColor3 = color, BorderSizePixel = 0 }, { corner(4) })
	local value = label({ Parent = holder, Position = UDim2.new(1, -36, 0, 0), Size = UDim2.new(0, 36, 1, 0), Text = "100", TextSize = 13, TextXAlignment = Enum.TextXAlignment.Right })
	return { fill = fill, value = value, holder = holder }
end

local function setBar(b, v)
	v = math.clamp(v or 0, 0, 100)
	b.fill.Size = UDim2.fromScale(v / 100, 1)
	b.value.Text = tostring(math.floor(v))
end

local function fmtTime(s)
	s = math.max(0, s or 0)
	return string.format("%d:%02d", s // 60, s % 60)
end

function HUD.init()
	local gui = make("ScreenGui", {
		Name = "HollowShiftHUD",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = player:WaitForChild("PlayerGui"),
	})
	refs.gui = gui
	local scale = make("UIScale", { Parent = gui })
	local function rescale()
		local vp = Workspace.CurrentCamera.ViewportSize
		scale.Scale = math.clamp(math.min(vp.X / 1100, vp.Y / 700), 0.55, 1)
	end
	rescale()
	Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)

	-- Downed / vignette overlay (behind everything)
	refs.vignette = make("Frame", { Parent = gui, Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(120, 0, 0), BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 0 })
	refs.downed = label({ Parent = gui, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.42), Size = UDim2.new(0, 700, 0, 90), Font = FONT, TextSize = 30, TextColor3 = Color3.fromRGB(255, 80, 80), Visible = false, TextWrapped = true })

	-- Top timer/status
	local top = panel({ Parent = gui, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 10), Size = UDim2.new(0, 360, 0, 62) })
	refs.timer = label({ Parent = top, Size = UDim2.new(1, 0, 0, 38), Font = FONT, TextSize = 34, Text = "" })
	refs.status = label({ Parent = top, Position = UDim2.new(0, 0, 0, 36), Size = UDim2.new(1, 0, 0, 22), TextSize = 15, Text = "" })

	-- Objectives
	local obj = panel({ Parent = gui, Position = UDim2.new(0, 14, 0, 14), Size = UDim2.new(0, 290, 0, 116) })
	make("UIPadding", { Parent = obj, PaddingLeft = UDim.new(0, 10), PaddingTop = UDim.new(0, 6), PaddingRight = UDim.new(0, 10) })
	make("UIListLayout", { Parent = obj, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 2) })
	label({ Parent = obj, LayoutOrder = 0, Size = UDim2.new(1, 0, 0, 24), Text = "OBJECTIVES", Font = FONT, TextSize = 20, TextColor3 = Color3.fromRGB(200, 40, 40), TextXAlignment = Enum.TextXAlignment.Left })
	refs.quota = label({ Parent = obj, LayoutOrder = 1, Size = UDim2.new(1, 0, 0, 26), TextSize = 16, TextXAlignment = Enum.TextXAlignment.Left })
	refs.gens = label({ Parent = obj, LayoutOrder = 2, Size = UDim2.new(1, 0, 0, 26), TextSize = 16, TextXAlignment = Enum.TextXAlignment.Left })
	refs.elevator = label({ Parent = obj, LayoutOrder = 3, Size = UDim2.new(1, 0, 0, 26), TextSize = 16, TextXAlignment = Enum.TextXAlignment.Left })
	refs.objPanel = obj

	-- Vitals
	local vitals = panel({ Parent = gui, AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 14, 1, -14), Size = UDim2.new(0, 290, 0, 108) })
	make("UIPadding", { Parent = vitals, PaddingLeft = UDim.new(0, 10), PaddingTop = UDim.new(0, 8), PaddingRight = UDim.new(0, 10) })
	make("UIListLayout", { Parent = vitals, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 4) })
	refs.hp = bar(vitals, 1, "HEALTH", Color3.fromRGB(200, 40, 40))
	refs.sanity = bar(vitals, 2, "SANITY", Color3.fromRGB(150, 90, 220))
	refs.stamina = bar(vitals, 3, "STAMINA", Color3.fromRGB(230, 220, 160))
	refs.battery = bar(vitals, 4, "BATTERY", Color3.fromRGB(80, 200, 255))
	refs.vitals = vitals

	-- Carry + repair
	refs.carry = label({ Parent = gui, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -18), Size = UDim2.new(0, 520, 0, 28), TextSize = 18, Font = FONT, Text = "", TextColor3 = Color3.fromRGB(255, 225, 140) })
	local repair = panel({ Parent = gui, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -56), Size = UDim2.new(0, 320, 0, 44), Visible = false })
	label({ Parent = repair, Size = UDim2.new(1, 0, 0, 20), Text = "REPAIRING — move to stop", TextSize = 13, Font = FONT })
	local rback = make("Frame", { Parent = repair, Position = UDim2.new(0, 10, 0, 24), Size = UDim2.new(1, -20, 0, 12), BackgroundColor3 = Color3.fromRGB(30, 30, 30), BorderSizePixel = 0 }, { corner(4) })
	refs.repairFill = make("Frame", { Parent = rback, Size = UDim2.fromScale(0, 1), BackgroundColor3 = Color3.fromRGB(90, 220, 120), BorderSizePixel = 0 }, { corner(4) })
	refs.repair = repair

	-- Hints
	refs.hints = label({
		Parent = gui,
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -14, 1, -14),
		Size = UDim2.new(0, 260, 0, 120),
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Right,
		TextYAlignment = Enum.TextYAlignment.Bottom,
		TextTransparency = 0.25,
		Text = "[E] Interact   [Q] Drop\n[Shift] Sprint   [C/Ctrl] Crouch\n[F] Flashlight   [R] Camera flash\n[Space] Skill check",
	})

	-- Notification feed
	local feed = make("Frame", { Parent = gui, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 84), Size = UDim2.new(0, 640, 0, 200), BackgroundTransparency = 1 })
	make("UIListLayout", { Parent = feed, SortOrder = Enum.SortOrder.LayoutOrder, HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0, 4) })
	refs.feed = feed
	refs.feedOrder = 0

	-- Spectate label
	refs.spectate = label({ Parent = gui, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -90), Size = UDim2.new(0, 600, 0, 30), Font = FONT, TextSize = 20, Visible = false })

	-- Lobby splash
	local lobby = make("Frame", { Parent = gui, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.3), Size = UDim2.new(0, 700, 0, 160), BackgroundTransparency = 1 })
	label({ Parent = lobby, Size = UDim2.new(1, 0, 0, 90), Font = FONT, TextSize = 78, Text = Config.GAME_NAME, TextColor3 = Color3.fromRGB(200, 25, 25), TextStrokeTransparency = 0.2 })
	refs.lobbyStatus = label({ Parent = lobby, Position = UDim2.new(0, 0, 0, 92), Size = UDim2.new(1, 0, 0, 30), Font = FONT, TextSize = 24 })
	label({ Parent = lobby, Position = UDim2.new(0, 0, 0, 124), Size = UDim2.new(1, 0, 0, 24), TextSize = 16, Text = Config.TAGLINE, TextTransparency = 0.2 })
	refs.lobby = lobby

	-- Round end card
	local endCard = panel({ Parent = gui, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(0, 520, 0, 300), Visible = false, BackgroundTransparency = 0.1, ZIndex = 10 })
	refs.endTitle = label({ Parent = endCard, Size = UDim2.new(1, 0, 0, 70), Font = FONT, TextSize = 46, ZIndex = 11 })
	refs.endBody = label({ Parent = endCard, Position = UDim2.new(0, 20, 0, 76), Size = UDim2.new(1, -40, 1, -90), TextSize = 18, TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top, ZIndex = 11 })
	refs.endCard = endCard

	-- Jumpscare + flash layers (top-most)
	refs.flash = make("Frame", { Parent = gui, Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 50 })
	local scare = make("Frame", { Parent = gui, Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0, Visible = false, ZIndex = 60 })
	refs.scareFace = make("Frame", { Parent = scare, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.55, 0.8), BackgroundColor3 = Color3.fromRGB(16, 16, 18), BorderSizePixel = 0, ZIndex = 61 }, { make("UICorner", { CornerRadius = UDim.new(0.45, 0) }) })
	refs.scareEyes = {}
	for i, x in { 0.3, 0.7 } do
		refs.scareEyes[i] = make("Frame", { Parent = refs.scareFace, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(x, 0.38), Size = UDim2.fromScale(0.16, 0.07), BackgroundColor3 = Color3.fromRGB(255, 20, 20), BorderSizePixel = 0, ZIndex = 62 }, { make("UICorner", { CornerRadius = UDim.new(0.5, 0) }) })
	end
	refs.scareMouth = make("Frame", { Parent = refs.scareFace, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.72), Size = UDim2.fromScale(0.6, 0.18), BackgroundColor3 = Color3.fromRGB(40, 0, 0), BorderSizePixel = 0, ZIndex = 62 }, { make("UICorner", { CornerRadius = UDim.new(0.3, 0) }) })
	refs.scare = scare

	return gui
end

function HUD.notify(text, color)
	refs.feedOrder += 1
	local l = label({
		Parent = refs.feed,
		LayoutOrder = refs.feedOrder,
		Size = UDim2.new(1, 0, 0, 24),
		Text = text,
		TextSize = 18,
		Font = FONT,
		TextColor3 = color or Color3.fromRGB(230, 220, 200),
		TextStrokeTransparency = 0.3,
		TextWrapped = true,
	})
	local children = {}
	for _, c in refs.feed:GetChildren() do
		if c:IsA("TextLabel") then
			table.insert(children, c)
		end
	end
	if #children > 6 then
		table.sort(children, function(a, b)
			return a.LayoutOrder < b.LayoutOrder
		end)
		children[1]:Destroy()
	end
	task.delay(5, function()
		if l.Parent then
			local t = TweenService:Create(l, TweenInfo.new(1), { TextTransparency = 1, TextStrokeTransparency = 1 })
			t:Play()
			t.Completed:Wait()
			l:Destroy()
		end
	end)
end

function HUD.flash(intensity)
	refs.flash.BackgroundTransparency = 1 - (intensity or 0.85)
	TweenService:Create(refs.flash, TweenInfo.new(0.5), { BackgroundTransparency = 1 }):Play()
end

function HUD.jumpscare(kind)
	local face, eyes, mouth = refs.scareFace, refs.scareEyes, refs.scareMouth
	if kind == "Still" then
		face.BackgroundColor3 = Color3.fromRGB(215, 205, 190)
		for _, e in eyes do
			e.BackgroundColor3 = Color3.fromRGB(20, 10, 10)
		end
		mouth.Size = UDim2.fromScale(0.3, 0.05)
	elseif kind == "Hum" then
		face.BackgroundColor3 = Color3.fromRGB(120, 88, 84)
		for _, e in eyes do
			e.BackgroundTransparency = 1
		end
		mouth.Size = UDim2.fromScale(0.85, 0.45)
		mouth.Position = UDim2.fromScale(0.5, 0.55)
	else
		face.BackgroundColor3 = Color3.fromRGB(16, 16, 18)
		for _, e in eyes do
			e.BackgroundColor3 = Color3.fromRGB(255, 20, 20)
		end
		mouth.Size = UDim2.fromScale(0.6, 0.18)
	end
	refs.scare.Visible = true
	local start = os.clock()
	task.spawn(function()
		while os.clock() - start < 0.7 do
			face.Position = UDim2.new(0.5, math.random(-25, 25), 0.5, math.random(-25, 25))
			face.Size = UDim2.fromScale(0.55 + (os.clock() - start) * 0.5, 0.8 + (os.clock() - start) * 0.5)
			task.wait()
		end
		refs.scare.Visible = false
		face.Size = UDim2.fromScale(0.55, 0.8)
		mouth.Position = UDim2.fromScale(0.5, 0.72)
		for _, e in eyes do
			e.BackgroundTransparency = 0
		end
		refs.vignette.BackgroundTransparency = 0.4
		TweenService:Create(refs.vignette, TweenInfo.new(1.2), { BackgroundTransparency = 1 }):Play()
	end)
end

function HUD.showEnd(data)
	refs.endTitle.Text = if data.won then "SHIFT SURVIVED" else "NO ONE CLOCKED OUT"
	refs.endTitle.TextColor3 = if data.won then Color3.fromRGB(110, 230, 140) else Color3.fromRGB(220, 40, 40)
	local escaped = if #data.escaped > 0 then table.concat(data.escaped, ", ") else "nobody"
	local reasons = { elevator = "The elevator left.", time = "The night ran out.", wiped = "The whole crew went down." }
	refs.endBody.Text = string.format(
		"%s\n\nEscaped (%d/%d): %s\n\nHaul: $%d / $%d\nGenerators: %d / %d\nTime survived: %s\n\nBack to the lobby shortly...",
		reasons[data.reason] or "",
		#data.escaped,
		data.crew,
		escaped,
		data.collected,
		data.quota,
		data.gensDone,
		data.gensTotal,
		fmtTime(data.survivedSeconds)
	)
	refs.endCard.Visible = true
	task.delay(Config.POST_ROUND_TIME, function()
		refs.endCard.Visible = false
	end)
end

function HUD.setSpectate(text)
	refs.spectate.Visible = text ~= nil
	refs.spectate.Text = text or ""
end

-- Called ~10x a second.
function HUD.update()
	local phase = ReplicatedStorage:GetAttribute("Phase") or "Lobby"
	local inRound = player:GetAttribute("InRound") == true
	local playing = phase == "Playing" or phase == "Starting"
	local activeHere = playing and inRound and not player:GetAttribute("Dead") and not player:GetAttribute("Escaped")

	refs.lobby.Visible = phase == "Lobby"
	refs.lobbyStatus.Text = ReplicatedStorage:GetAttribute("Status") or ""

	refs.status.Text = ReplicatedStorage:GetAttribute("Status") or ""
	if phase == "Playing" then
		local t = ReplicatedStorage:GetAttribute("TimeLeft") or 0
		refs.timer.Text = fmtTime(t)
		refs.timer.TextColor3 = if ReplicatedStorage:GetAttribute("Enraged") then Color3.fromRGB(255, 60, 60) else Color3.fromRGB(230, 220, 200)
	elseif phase == "Lobby" then
		refs.timer.Text = "LOBBY"
		refs.timer.TextColor3 = Color3.fromRGB(230, 220, 200)
	else
		refs.timer.Text = string.upper(phase)
	end

	refs.objPanel.Visible = playing
	local collected = ReplicatedStorage:GetAttribute("Collected") or 0
	local quota = ReplicatedStorage:GetAttribute("Quota") or 0
	local gd, gt = ReplicatedStorage:GetAttribute("GensDone") or 0, ReplicatedStorage:GetAttribute("GensTotal") or 0
	refs.quota.Text = string.format("%s Quota: $%d / $%d", if collected >= quota then "✔" else "•", collected, quota)
	refs.quota.TextColor3 = if collected >= quota then Color3.fromRGB(120, 230, 140) else Color3.fromRGB(230, 220, 200)
	refs.gens.Text = string.format("%s Generators: %d / %d", if gd >= gt and gt > 0 then "✔" else "•", gd, gt)
	refs.gens.TextColor3 = if gd >= gt and gt > 0 then Color3.fromRGB(120, 230, 140) else Color3.fromRGB(230, 220, 200)
	if ReplicatedStorage:GetAttribute("ElevatorOpen") then
		local cd = ReplicatedStorage:GetAttribute("ElevatorCountdown") or -1
		refs.elevator.Text = if cd >= 0 then string.format("• ELEVATOR DEPARTS IN %d", cd) else "• Elevator OPEN — get in!"
		refs.elevator.TextColor3 = Color3.fromRGB(255, 220, 90)
	else
		refs.elevator.Text = "• Elevator: locked"
		refs.elevator.TextColor3 = Color3.fromRGB(150, 140, 130)
	end

	refs.vitals.Visible = activeHere
	refs.hints.Visible = activeHere
	if activeHere then
		setBar(refs.hp, player:GetAttribute("HP"))
		setBar(refs.sanity, player:GetAttribute("Sanity"))
		setBar(refs.stamina, player:GetAttribute("Stamina"))
		setBar(refs.battery, player:GetAttribute("Battery"))
	end

	local carrying = player:GetAttribute("Carrying")
	if activeHere and carrying and carrying ~= "" then
		refs.carry.Text = string.format("Carrying: %s ($%d)  —  [Q] drop, deposit at the chute", carrying, player:GetAttribute("CarryValue") or 0)
	else
		refs.carry.Text = ""
	end

	local repairing = player:GetAttribute("Repairing")
	refs.repair.Visible = activeHere and repairing ~= nil
	if repairing then
		refs.repairFill.Size = UDim2.fromScale(player:GetAttribute("RepairProgress") or 0, 1)
	end

	local downed = activeHere and player:GetAttribute("Downed") == true
	refs.downed.Visible = downed
	if downed then
		refs.downed.Text = string.format("YOU ARE DOWN\nCrawl to a teammate — bleeding out in %d", player:GetAttribute("Bleedout") or 0)
		refs.vignette.BackgroundTransparency = 0.65 + math.sin(os.clock() * 3) * 0.08
	elseif activeHere and (player:GetAttribute("HP") or 100) < 50 then
		refs.vignette.BackgroundTransparency = 0.85
	elseif refs.vignette.BackgroundTransparency < 0.9 and not refs.scare.Visible then
		refs.vignette.BackgroundTransparency = math.min(1, refs.vignette.BackgroundTransparency + 0.03)
	end
end

return HUD
