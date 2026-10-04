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
local KerisQuestService = require(Services:WaitForChild("KerisQuestService") :: ModuleScript)

Log.info("Server", string.format("Malam Suro server siap (MAX_PLAYERS=%d)", GameConfig.MAX_PLAYERS))

Remotes.init()
GameManager.init()
QuestService.init()
ItemService.init()
SpawnService.init()
InteractionService.init()
DialogueService.init()
GameFlowService.init()
KerisQuestService.init()

-- Pemandu: objek Workspace.NPC.Pemandu (dibuat di Studio) ber-tag Interactable dengan InteractionId = "Pemandu".
InteractionService.register("Pemandu", function(player: Player, target: Instance)
	local dialogueId = GameFlowService.getPemanduDialogueId()
	if dialogueId then
		DialogueService.start(player, dialogueId, target)
	end
end)