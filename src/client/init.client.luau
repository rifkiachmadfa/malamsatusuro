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
local NoticeController = require(Controllers:WaitForChild("NoticeController") :: ModuleScript)
local MemoryPuzzleController = require(Controllers:WaitForChild("MemoryPuzzleController") :: ModuleScript)
local JumpscareController = require(Controllers:WaitForChild("JumpscareController") :: ModuleScript)
local KnockController = require(Controllers:WaitForChild("KnockController") :: ModuleScript)
local ReviveController = require(Controllers:WaitForChild("ReviveController") :: ModuleScript)

Log.info("Client", string.format("Malam Suro client siap (MAX_PLAYERS=%d)", GameConfig.MAX_PLAYERS))

DialogueController.init()
-- Prompt revive (memegang Minyak Zaitun + ada korban) memegang tombol E: prompt interaksi lain disembunyikan.
InteractionController.init(function(): boolean
	return DialogueController.isOpen() or MemoryPuzzleController.isOpen() or ReviveController.isActive()
end)
QuestController.init()
NoticeController.init()
MemoryPuzzleController.init()
JumpscareController.init()
KnockController.init()
ReviveController.init(function(): boolean
	return DialogueController.isOpen() or MemoryPuzzleController.isOpen()
end)
