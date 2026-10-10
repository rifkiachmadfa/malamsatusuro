--!strict
-- Bootstrap server. Service ditambahkan bertahap.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("Config"):WaitForChild("GameConfig") :: ModuleScript)
local Log = require(Shared:WaitForChild("Util"):WaitForChild("Log") :: ModuleScript)
local Remotes = require(Shared:WaitForChild("Remotes") :: ModuleScript)

local Services = script:WaitForChild("Services")
local GameManager = require(Services:WaitForChild("GameManager") :: ModuleScript)
local SpawnService = require(Services:WaitForChild("SpawnService") :: ModuleScript)
local InteractionService = require(Services:WaitForChild("InteractionService") :: ModuleScript)
local DialogueService = require(Services:WaitForChild("DialogueService") :: ModuleScript)
local QuestService = require(Services:WaitForChild("QuestService") :: ModuleScript)
local ItemService = require(Services:WaitForChild("ItemService") :: ModuleScript)
local GameFlowService = require(Services:WaitForChild("GameFlowService") :: ModuleScript)
local NoticeService = require(Services:WaitForChild("NoticeService") :: ModuleScript)
local MemoryPuzzleService = require(Services:WaitForChild("MemoryPuzzleService") :: ModuleScript)
local RitualCollectionService = require(Services:WaitForChild("RitualCollectionService") :: ModuleScript)
local CollectibleService = require(Services:WaitForChild("CollectibleService") :: ModuleScript)
local KerisQuestService = require(Services:WaitForChild("KerisQuestService") :: ModuleScript)
local GravePuzzleService = require(Services:WaitForChild("GravePuzzleService") :: ModuleScript)

Log.info("Server", string.format("Malam Suro server siap (MAX_PLAYERS=%d)", GameConfig.MAX_PLAYERS))

Remotes.init()
GameManager.init()
QuestService.init()
ItemService.init()
SpawnService.init()
InteractionService.init()
DialogueService.init()
GameFlowService.init()
NoticeService.init()
MemoryPuzzleService.init()
CollectibleService.init()
KerisQuestService.init()
RitualCollectionService.init()
GravePuzzleService.init()

-- Pemandu: objek Workspace.NPC.Pemandu (dibuat di Studio) ber-tag Interactable dengan InteractionId = "Pemandu".
InteractionService.register("Pemandu", function(player: Player, target: Instance)
	local dialogueId = GameFlowService.getPemanduDialogueId(player)
	if dialogueId then
		DialogueService.start(player, dialogueId, target)
	end
end)