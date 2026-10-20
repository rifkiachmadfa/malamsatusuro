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
local RhythmGameService = require(Services:WaitForChild("RhythmGameService") :: ModuleScript)
local KafanQuestService = require(Services:WaitForChild("KafanQuestService") :: ModuleScript)
local FinalRitualService = require(Services:WaitForChild("FinalRitualService") :: ModuleScript)
local GravePuzzleService = require(Services:WaitForChild("GravePuzzleService") :: ModuleScript)
local KnockService = require(Services:WaitForChild("KnockService") :: ModuleScript)
local ReviveService = require(Services:WaitForChild("ReviveService") :: ModuleScript)
local KnockConfig = require(script:WaitForChild("Config"):WaitForChild("KnockConfig") :: ModuleScript)
local FailureConfig = require(script:WaitForChild("Config"):WaitForChild("FailureConfig") :: ModuleScript)
local JumpscareService = require(Services:WaitForChild("JumpscareService") :: ModuleScript)
local FailureService = require(Services:WaitForChild("FailureService") :: ModuleScript)
local GhostService = require(Services:WaitForChild("GhostService") :: ModuleScript)
local PocongService = require(Services:WaitForChild("PocongService") :: ModuleScript)
local PlayerState = GameConfig.PlayerState

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
ReviveService.init()
JumpscareService.init()
FailureService.init()
RhythmGameService.init()
KafanQuestService.init()
FinalRitualService.init()
-- Ghost Encounter System (Phase 9, ADR-048): terakhir, karena perilaku hantu memasang pendengar ke CollectibleService/QuestService.
GhostService.init()

-- Pocong (Phase 9.3, desain obor TorchCounter): berdiri sendiri di luar GhostService (lihat .ai/CURRENT_STATE.md).
-- Pemicu spawn = pemantau Tool bunga di Backpack (PocongConfig.WATCH_BACKPACK); knock lewat KnockService.
PocongService.configure({
	-- Tertangkap Pocong = jumpscare lalu knock (multiplayer) atau kebijakan solo ADR-032 (FailureService).
	fail = function(player: Player)
		FailureService.fail(player, KnockConfig.Reason.GHOST_POCONG, "KANTIL")
	end,
	isPlayerNormal = function(player: Player): boolean
		return GameManager.getPlayerState(player) == PlayerState.NORMAL
	end,
})
PocongService.start()
-- Pocong hanya hidup selama KANTIL = SEARCHING_FLOWERS. Masuk ke state itu lagi (party wipe) atau keluar darinya
-- (bunga lengkap / selesai / reset) = bersihkan semua Pocong.
QuestService.onStateChanged(function(questId: string, _fromState: string, _toState: string)
	if questId == "KANTIL" then
		PocongService.reset()
	end
end)

-- Bunga salah di makam -> kebijakan gagal (ADR-030/032): multiplayer = knock, solo = respawn + reset quest.
-- Jumpscare (ADR-033) dimainkan di dalam FailureService sebelum hukuman.
GravePuzzleService.onWrong(function(player: Player, _graveName: string, _itemId: string)
	if FailureConfig.FAIL_ON_WRONG_FLOWER then
		FailureService.fail(player, KnockConfig.Reason.WRONG_FLOWER, "KANTIL")
	end
end)

-- Pemandu: objek Workspace.NPC.Pemandu (dibuat di Studio) ber-tag Interactable dengan InteractionId = "Pemandu".
InteractionService.register("Pemandu", function(player: Player, target: Instance)
	-- KELOR_COMPLETE: Kelor harus dipegang dan diserahkan dulu (ADR-046); dialog kunci menyusul setelah semua terserahkan.
	if KerisQuestService.handleKelorHandIn(player) then
		return
	end
	local dialogueId = GameFlowService.getPemanduDialogueId(player)
	if dialogueId then
		DialogueService.start(player, dialogueId, target)
	end
end)