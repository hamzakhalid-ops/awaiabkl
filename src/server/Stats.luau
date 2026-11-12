-- Leaderstats + DataStore persistence (safe to run in Studio without API access).
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")

local Stats = {}

local store = nil
pcall(function()
	store = DataStoreService:GetDataStore("HollowShift_Stats_v1")
end)

local FIELDS = { "Escapes", "Nights", "Earned" }

local function load(player)
	local ls = Instance.new("Folder")
	ls.Name = "leaderstats"
	for _, name in FIELDS do
		local v = Instance.new("IntValue")
		v.Name = name
		v.Parent = ls
	end
	ls.Parent = player
	if store then
		local ok, data = pcall(function()
			return store:GetAsync(tostring(player.UserId))
		end)
		if ok and type(data) == "table" then
			for _, name in FIELDS do
				ls[name].Value = tonumber(data[name]) or 0
			end
		end
	end
end

local function save(player)
	local ls = player:FindFirstChild("leaderstats")
	if not store or not ls then
		return
	end
	local data = {}
	for _, name in FIELDS do
		data[name] = ls[name].Value
	end
	pcall(function()
		store:SetAsync(tostring(player.UserId), data)
	end)
end

function Stats.add(player, field, amount)
	local ls = player:FindFirstChild("leaderstats")
	local v = ls and ls:FindFirstChild(field)
	if v then
		v.Value += amount
	end
end

function Stats.saveAll()
	for _, p in Players:GetPlayers() do
		task.spawn(save, p)
	end
end

function Stats.init()
	Players.PlayerAdded:Connect(load)
	for _, p in Players:GetPlayers() do
		task.spawn(load, p)
	end
	Players.PlayerRemoving:Connect(save)
	game:BindToClose(function()
		for _, p in Players:GetPlayers() do
			save(p)
		end
	end)
end

return Stats
