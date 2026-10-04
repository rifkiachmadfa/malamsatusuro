--!strict
-- Bootstrap client. Controller ditambahkan bertahap.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("Config"):WaitForChild("GameConfig") :: ModuleScript)
local Log = require(Shared:WaitForChild("Util"):WaitForChild("Log") :: ModuleScript)

local Controllers = script:WaitForChild("Controllers")
local DialogueController = require(Controllers:WaitForChild("DialogueController") :: ModuleScript)
local InteractionController = require(Controllers:WaitForChild("InteractionController") :: ModuleScript)
local QuestController = require(Controllers:WaitForChild("QuestController") :: ModuleScript)

Log.info("Client", string.format("Malam Suro client siap (MAX_PLAYERS=%d)", GameConfig.MAX_PLAYERS))

DialogueController.init()
InteractionController.init(DialogueController.isOpen)
QuestController.init()