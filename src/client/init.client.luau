-- HOLLOW SHIFT client: input, HUD loop, server events.
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local HUD = require(script.HUD)
local SkillCheck = require(script.SkillCheck)
local Effects = require(script.Effects)

local player = Players.LocalPlayer

task.spawn(function()
	for _ = 1, 10 do
		local ok = pcall(StarterGui.SetCoreGuiEnabled, StarterGui, Enum.CoreGuiType.Health, false)
		if ok then
			break
		end
		task.wait(1)
	end
end)

local gui = HUD.init()
SkillCheck.init(gui)
Effects.init(HUD)

local function inRound()
	return ReplicatedStorage:GetAttribute("Phase") == "Playing" and player:GetAttribute("InRound") == true and not player:GetAttribute("Dead") and not player:GetAttribute("Escaped")
end

---------------------------------------------------------------- controls
local crouching = false

ContextActionService:BindAction("HS_Sprint", function(_, state)
	if state == Enum.UserInputState.Begin then
		Remotes.SetMovement:FireServer("Sprint", true)
	elseif state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then
		Remotes.SetMovement:FireServer("Sprint", false)
	end
	return Enum.ContextActionResult.Pass
end, true, Enum.KeyCode.LeftShift, Enum.KeyCode.ButtonL3)
ContextActionService:SetTitle("HS_Sprint", "Run")
ContextActionService:SetPosition("HS_Sprint", UDim2.new(1, -170, 1, -150))

ContextActionService:BindAction("HS_Crouch", function(_, state)
	if state == Enum.UserInputState.Begin then
		crouching = not crouching
		Remotes.SetMovement:FireServer("Crouch", crouching)
	end
	return Enum.ContextActionResult.Sink
end, true, Enum.KeyCode.C, Enum.KeyCode.LeftControl, Enum.KeyCode.ButtonB)
ContextActionService:SetTitle("HS_Crouch", "Crouch")
ContextActionService:SetPosition("HS_Crouch", UDim2.new(1, -240, 1, -90))

ContextActionService:BindAction("HS_Flashlight", function(_, state)
	if state == Enum.UserInputState.Begin and inRound() then
		Remotes.Flashlight:FireServer()
	end
	return Enum.ContextActionResult.Sink
end, true, Enum.KeyCode.F, Enum.KeyCode.ButtonY)
ContextActionService:SetTitle("HS_Flashlight", "Light")
ContextActionService:SetPosition("HS_Flashlight", UDim2.new(1, -240, 1, -160))

ContextActionService:BindAction("HS_Photo", function(_, state)
	if state == Enum.UserInputState.Begin and inRound() then
		Remotes.TakePhoto:FireServer()
	end
	return Enum.ContextActionResult.Sink
end, true, Enum.KeyCode.R, Enum.KeyCode.ButtonR2)
ContextActionService:SetTitle("HS_Photo", "Flash")
ContextActionService:SetPosition("HS_Photo", UDim2.new(1, -310, 1, -120))

ContextActionService:BindAction("HS_Drop", function(_, state)
	if state == Enum.UserInputState.Begin and inRound() then
		Remotes.DropItem:FireServer()
	end
	return Enum.ContextActionResult.Sink
end, true, Enum.KeyCode.Q, Enum.KeyCode.DPadDown)
ContextActionService:SetTitle("HS_Drop", "Drop")
ContextActionService:SetPosition("HS_Drop", UDim2.new(1, -170, 1, -220))

-- Reset crouch when a new character spawns
player.CharacterAdded:Connect(function()
	crouching = false
end)

---------------------------------------------------------------- look direction (the Still checks this)
task.spawn(function()
	while true do
		task.wait(0.12)
		if inRound() then
			Remotes.LookDir:FireServer(Workspace.CurrentCamera.CFrame.LookVector)
		end
	end
end)

---------------------------------------------------------------- server events
Remotes.Notify.OnClientEvent:Connect(function(text, color)
	HUD.notify(text, color)
end)

Remotes.Jumpscare.OnClientEvent:Connect(function(kind, downed)
	HUD.jumpscare(kind)
	Effects.playOnce(Config.SOUNDS.Jumpscare, if downed then 1 else 0.7)
end)

Remotes.PhotoResult.OnClientEvent:Connect(function(ok, hits, bonus, reason)
	if not ok then
		HUD.notify(reason or "Camera failed", Color3.fromRGB(200, 200, 200))
		return
	end
	HUD.flash(0.9)
	Effects.playOnce(Config.SOUNDS.CameraFlash, 0.8)
	if #hits == 0 then
		HUD.notify("Nothing in frame...", Color3.fromRGB(180, 180, 180))
	elseif bonus == 0 then
		HUD.notify("Already have footage of that. The flash still stings it.", Color3.fromRGB(220, 220, 160))
	end
end)

Remotes.RoundEnd.OnClientEvent:Connect(function(data)
	HUD.showEnd(data)
	crouching = false
end)

local lastElevator, lastGens = false, 0
ReplicatedStorage:GetAttributeChangedSignal("ElevatorOpen"):Connect(function()
	local open = ReplicatedStorage:GetAttribute("ElevatorOpen") == true
	if open and not lastElevator then
		Effects.playOnce(Config.SOUNDS.ElevatorOpen, 1)
	end
	lastElevator = open
end)
ReplicatedStorage:GetAttributeChangedSignal("GensDone"):Connect(function()
	local n = ReplicatedStorage:GetAttribute("GensDone") or 0
	if n > lastGens then
		Effects.playOnce(Config.SOUNDS.GeneratorDone, 0.8)
	end
	lastGens = n
end)

---------------------------------------------------------------- HUD loop
while true do
	HUD.update()
	task.wait(0.1)
end
