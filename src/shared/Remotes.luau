-- Creates (server) or waits for (client) every remote the game uses.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local RELIABLE = {
	"SetMovement", -- client -> server ("Sprint"|"Crouch", bool)
	"Flashlight", -- client -> server toggle
	"DropItem", -- client -> server
	"TakePhoto", -- client -> server
	"SkillCheck", -- server -> client start, client -> server result
	"PhotoResult", -- server -> client
	"Notify", -- server -> client (text, color)
	"Jumpscare", -- server -> client (monsterKind, downed)
	"RoundEnd", -- server -> client summary
}
local UNRELIABLE = {
	"LookDir", -- client -> server camera look vector (used by the Still)
}

local Remotes = {}

if RunService:IsServer() then
	local folder = ReplicatedStorage:FindFirstChild("Remotes") or Instance.new("Folder")
	folder.Name = "Remotes"
	folder.Parent = ReplicatedStorage
	local function ensure(name, class)
		local r = folder:FindFirstChild(name)
		if not r then
			r = Instance.new(class)
			r.Name = name
			r.Parent = folder
		end
		Remotes[name] = r
	end
	for _, name in RELIABLE do
		ensure(name, "RemoteEvent")
	end
	for _, name in UNRELIABLE do
		ensure(name, "UnreliableRemoteEvent")
	end
else
	local folder = ReplicatedStorage:WaitForChild("Remotes")
	for _, name in RELIABLE do
		Remotes[name] = folder:WaitForChild(name)
	end
	for _, name in UNRELIABLE do
		Remotes[name] = folder:WaitForChild(name)
	end
end

return Remotes
