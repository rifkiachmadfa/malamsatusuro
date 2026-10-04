--!strict
-- Bootstrap server. Service ditambahkan bertahap.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("Config"):WaitForChild("GameConfig") :: ModuleScript)
local Log = require(Shared:WaitForChild("Util"):WaitForChild("Log") :: ModuleScript)
local Remotes = require(Shared:WaitForChild("Remotes") :: ModuleScript)

local Services = script:WaitForChild("Services")
local GameManager = require(Services:WaitForChild("GameManager") :: ModuleScript)
local SpawnService = require(Services:WaitForChild("SpawnService") :: ModuleScript)

Log.info("Server", string.format("Malam Suro server siap (MAX_PLAYERS=%d)", GameConfig.MAX_PLAYERS))

Remotes.init()
GameManager.init()

-- SEMENTARA (Task 1.4): contoh pola "client meminta, server memvalidasi".
local debugPing = Remotes.get(Remotes.Names.DebugPing)
debugPing.OnServerEvent:Connect(function(player: Player, payload: unknown)
	if typeof(payload) ~= "string" or #payload > 32 then
		Log.warn("Server", string.format("DebugPing ditolak dari %s: payload tidak valid", player.Name))
		return
	end
	Log.info("Server", string.format("DebugPing dari %s: %s", player.Name, payload))
end)

-- SEMENTARA (Task 1.5): uji transisi state. Hapus di akhir Phase 1.
task.delay(1, function()
	GameManager.transitionTo(GameConfig.GameState.QUEST_KANTIL) -- harus ditolak
	GameManager.transitionTo(GameConfig.GameState.INTRO) -- harus diterima
end)

local function debugTestPlayerStates(player: Player)
	task.delay(1, function()
		local playerState = GameConfig.PlayerState
		GameManager.setPlayerState(player, playerState.REVIVING) -- harus ditolak
		GameManager.setPlayerState(player, playerState.KNOCKED)
		GameManager.setPlayerState(player, playerState.REVIVING)
		GameManager.setPlayerState(player, playerState.NORMAL)
	end)
end

for _, player in Players:GetPlayers() do
	debugTestPlayerStates(player)
end
Players.PlayerAdded:Connect(debugTestPlayerStates)