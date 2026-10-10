--!strict
-- Bootstrap server. Service ditambahkan bertahap.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("Config"):WaitForChild("GameConfig") :: ModuleScript)
local Log = require(Shared:WaitForChild("Util"):WaitForChild("Log") :: ModuleScript)
local Remotes = require(Shared:WaitForChild("Remotes") :: ModuleScript)

-- Remote dibuat PERTAMA, sebelum require service. Jika satu service gagal dimuat, client tidak ikut macet
-- menunggu folder Remotes (error "Folder Remotes tidak ditemukan"); error asli tetap muncul di Output server.
Remotes.init()

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
local KnockService = require(Services:WaitForChild("KnockService") :: ModuleScript)
local KnockConfig = require(script:WaitForChild("Config"):WaitForChild("KnockConfig") :: ModuleScript)
local FailureConfig = require(script:WaitForChild("Config"):WaitForChild("FailureConfig") :: ModuleScript)
local FailureService = require(Services:WaitForChild("FailureService") :: ModuleScript)

Log.info("Server", string.format("Malam Suro server siap (MAX_PLAYERS=%d)", GameConfig.MAX_PLAYERS))

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
KnockService.init()
FailureService.init()

-- Bunga salah di makam -> kebijakan gagal (ADR-030/032): multiplayer = knock, solo = respawn + reset quest.
-- Task 6.2 menyisipkan jumpscare sebelum hukuman.
GravePuzzleService.onWrong(function(player: Player, _graveName: string, _itemId: string)
	if FailureConfig.FAIL_ON_WRONG_FLOWER then
		FailureService.fail(player, KnockConfig.Reason.WRONG_FLOWER, "KANTIL")
	end
end)

-- Pemandu: objek Workspace.NPC.Pemandu (dibuat di Studio) ber-tag Interactable dengan InteractionId = "Pemandu".
InteractionService.register("Pemandu", function(player: Player, target: Instance)
	local dialogueId = GameFlowService.getPemanduDialogueId(player)
	if dialogueId then
		DialogueService.start(player, dialogueId, target)
	end
end)