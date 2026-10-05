--!strict
-- GameFlowService: menghubungkan peristiwa cerita ke GameManager dan QuestService.
-- Hanya "perekat": state game tetap milik GameManager, state quest tetap milik QuestService.
-- Semua berjalan di server; client tidak ikut menentukan.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("Config"):WaitForChild("GameConfig") :: ModuleScript)
local Log = require(Shared:WaitForChild("Util"):WaitForChild("Log") :: ModuleScript)
local GameManager = require(script.Parent:WaitForChild("GameManager") :: ModuleScript)
local QuestService = require(script.Parent:WaitForChild("QuestService") :: ModuleScript)
local DialogueService = require(script.Parent:WaitForChild("DialogueService") :: ModuleScript)
local ItemService = require(script.Parent:WaitForChild("ItemService") :: ModuleScript)

local TAG = "GameFlowService"
local INTRO_DIALOGUE_ID = "Pemandu_Intro"

local GameState = GameConfig.GameState

-- Dialog Pemandu per state quest KERIS. State yang belum tercantum belum punya dialog (task berikutnya).
local KERIS_DIALOGUES: { [string]: string } = {
	SEARCHING_KELOR = "Pemandu_KerisSearch",
	KELOR_COMPLETE = "Pemandu_KerisKey", -- serah-terima kunci ditangani KerisQuestService
	KEY_OBTAINED = "Pemandu_KerisChest",
	CHEST_AVAILABLE = "Pemandu_KerisChest",
	CHEST_PUZZLE = "Pemandu_KerisChest",
	COMPLETE = "Pemandu_KerisDone",
	-- KERIS_OBTAINED ditentukan per pemain (pemegang keris atau bukan), lihat getPemanduDialogueId.
}

local GameFlowService = {}

-- Pemain pertama yang menamatkan dialog intro memulai game untuk seluruh party.
-- Pemain berikutnya (atau penyelesaian ganda) diabaikan karena state sudah bukan LOBBY.
local function startGame(player: Player)
	if GameManager.getState() ~= GameState.LOBBY then
		return
	end

	Log.info(TAG, string.format("intro selesai oleh %s, memulai game", player.Name))

	if not GameManager.transitionTo(GameState.INTRO) then
		return
	end
	if not GameManager.transitionTo(GameState.QUEST_KERIS) then
		return
	end
	if not QuestService.activate("KERIS") then
		Log.warn(TAG, "gagal mengaktifkan quest KERIS")
		return
	end
	if not QuestService.transition("KERIS", "SEARCHING_KELOR") then
		Log.warn(TAG, "gagal memulai pencarian Kelor")
	end
end

-- Dialog Pemandu menurut state saat ini. Return nil jika belum ada dialog untuk state tersebut
-- (dialog state lain ditambahkan bersama quest-nya di Phase 4 dst.).
function GameFlowService.getPemanduDialogueId(player: Player?): string?
	if GameManager.getState() == GameState.LOBBY then
		return INTRO_DIALOGUE_ID
	end
	local kerisState = QuestService.getState("KERIS")
	if kerisState == "KERIS_OBTAINED" then
		if player and ItemService.has(player, "KerisPusaka") then
			return "Pemandu_KerisStore"
		end
		return "Pemandu_KerisWait"
	end
	return kerisState and KERIS_DIALOGUES[kerisState] or nil
end

function GameFlowService.init()
	DialogueService.onCompleted(function(player: Player, dialogueId: string)
		if dialogueId == INTRO_DIALOGUE_ID then
			startGame(player)
		end
	end)

	Log.info(TAG, "siap")
end

return table.freeze(GameFlowService)
