--!strict
-- Bootstrap server. Service akan ditambahkan bertahap.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("Config"):WaitForChild("GameConfig") :: ModuleScript)
local Log = require(Shared:WaitForChild("Util"):WaitForChild("Log") :: ModuleScript)
local Remotes = require(Shared:WaitForChild("Remotes") :: ModuleScript)

Log.info("Server", string.format("Malam Suro server siap (MAX_PLAYERS=%d)", GameConfig.MAX_PLAYERS))

Remotes.init()

-- SEMENTARA (Task 1.4): contoh pola "client meminta, server memvalidasi".
local debugPing = Remotes.get(Remotes.Names.DebugPing)
debugPing.OnServerEvent:Connect(function(player: Player, payload: unknown)
	if typeof(payload) ~= "string" or #payload > 32 then
		Log.warn("Server", string.format("DebugPing ditolak dari %s: payload tidak valid", player.Name))
		return
	end
	Log.info("Server", string.format("DebugPing dari %s: %s", player.Name, payload))
end)