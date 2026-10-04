--!strict
-- SpawnService: memeriksa dependency titik spawn dan mencatat posisi spawn pemain.
-- Pemilihan titik spawn dilakukan Roblox lewat SpawnLocation di Workspace.SpawnPoints.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Log = require(Shared:WaitForChild("Util"):WaitForChild("Log") :: ModuleScript)

local TAG = "SpawnService"
local SPAWN_FOLDER_NAME = "SpawnPoints"

local SpawnService = {}

local function countSpawnPoints(): number
	local folder = Workspace:FindFirstChild(SPAWN_FOLDER_NAME)
	if not folder then
		return 0
	end

	local count = 0
	for _, child in folder:GetChildren() do
		if child:IsA("SpawnLocation") then
			count += 1
		end
	end
	return count
end

local function onCharacterAdded(player: Player, character: Model)
	local root = character:WaitForChild("HumanoidRootPart", 10)
	if root and root:IsA("BasePart") then
		local position = root.Position
		Log.info(TAG, string.format("%s spawn di (%.0f, %.0f, %.0f)", player.Name, position.X, position.Y, position.Z))
	end
end

local function watchPlayer(player: Player)
	player.CharacterAdded:Connect(function(character: Model)
		onCharacterAdded(player, character)
	end)
	if player.Character then
		task.spawn(onCharacterAdded, player, player.Character)
	end
end

function SpawnService.init()
	local count = countSpawnPoints()
	if count == 0 then
		Log.warn(TAG, "dependency belum ada: Workspace.SpawnPoints tidak berisi SpawnLocation")
	else
		Log.info(TAG, string.format("siap, %d SpawnLocation ditemukan", count))
	end

	for _, player in Players:GetPlayers() do
		watchPlayer(player)
	end
	Players.PlayerAdded:Connect(watchPlayer)
end

return table.freeze(SpawnService)