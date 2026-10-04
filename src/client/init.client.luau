--!strict
-- Bootstrap client. Controller ditambahkan bertahap.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("Config"):WaitForChild("GameConfig") :: ModuleScript)
local Log = require(Shared:WaitForChild("Util"):WaitForChild("Log") :: ModuleScript)
local Remotes = require(Shared:WaitForChild("Remotes") :: ModuleScript)

Log.info("Client", string.format("Malam Suro client siap (MAX_PLAYERS=%d)", GameConfig.MAX_PLAYERS))

-- SEMENTARA (Task 1.4): satu ping valid dan satu ping sengaja salah untuk menguji validasi server.
local debugPing = Remotes.get(Remotes.Names.DebugPing)
debugPing:FireServer("halo")
debugPing:FireServer(12345)

-- SEMENTARA (Task 1.5): membuktikan state game sampai ke client lewat Attribute.
local function logGameState()
	Log.info("Client", "GameState = " .. tostring(ReplicatedStorage:GetAttribute("GameState")))
end
logGameState()
ReplicatedStorage:GetAttributeChangedSignal("GameState"):Connect(logGameState)