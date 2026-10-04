--!strict
-- Bootstrap client. Controller akan ditambahkan bertahap.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("Config"):WaitForChild("GameConfig") :: ModuleScript)
local Log = require(Shared:WaitForChild("Util"):WaitForChild("Log") :: ModuleScript)

Log.info("Client", string.format("Malam Suro client siap (MAX_PLAYERS=%d)", GameConfig.MAX_PLAYERS))