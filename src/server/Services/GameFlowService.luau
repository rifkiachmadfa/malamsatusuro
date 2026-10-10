--!strict
-- GameFlowService: menghubungkan peristiwa cerita ke GameManager dan QuestService.
-- Hanya "perekat": state game tetap milik GameManager, state quest tetap milik QuestService.
-- Semua berjalan di server; client tidak ikut menentukan.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("Config"):WaitForChild("GameConfig") :: ModuleScript)
local Log = require(Shared:WaitForChild("Util"):WaitForChild("Log") :: ModuleScript)
local QuestConfig = require(Shared:WaitForChild("Config"):WaitForChild("QuestConfig") :: ModuleScript)
local GameManager = require(script.Parent:WaitForChild("GameManager") :: ModuleScript)
local QuestService = require(script.Parent:WaitForChild("QuestService") :: ModuleScript)
local DialogueService = require(script.Parent:WaitForChild("DialogueService") :: ModuleScript)
local ItemService = require(script.Parent:WaitForChild("ItemService") :: ModuleScript)

local TAG = "GameFlowService"
local INTRO_DIALOGUE_ID = "Pemandu_Intro"

local GameState = GameConfig.GameState

-- Cara memulai tiap quest: state game dan state pertama quest. Quest KAFAN ditambahkan di Phase 7.
local QUEST_FLOW: { [string]: { gameState: string, startState: string } } = {
	KERIS = { gameState = GameState.QUEST_KERIS, startState = "SEARCHING_KELOR" },
	KANTIL = { gameState = GameState.QUEST_KANTIL, startState = "SEARCHING_FLOWERS" },
}

type DialogueRule = string | (player: Player?) -> string

-- Dialog Pemandu per state quest. State yang belum tercantum belum punya dialog (ditambah bersama quest-nya).
-- Nilai berupa fungsi = dialog bergantung pada pemain (mis. pemegang keris atau bukan).
local QUEST_DIALOGUES: { [string]: { [string]: DialogueRule } } = {
	KERIS = {
		SEARCHING_KELOR = "Pemandu_KerisSearch",
		KELOR_COMPLETE = "Pemandu_KerisKey", -- serah-terima kunci ditangani KerisQuestService
		KEY_OBTAINED = "Pemandu_KerisChest",
		CHEST_AVAILABLE = "Pemandu_KerisChest",
		CHEST_PUZZLE = "Pemandu_KerisChest",
		KERIS_OBTAINED = function(player: Player?): string
			if player and ItemService.has(player, "KerisPusaka") then
				return "Pemandu_KerisStore"
			end
			return "Pemandu_KerisWait"
		end,
	},
	KANTIL = {
		SEARCHING_FLOWERS = "Pemandu_KantilSearch",
		FLOWERS_COMPLETE = "Pemandu_KantilGrave",
		FLOWERS_PLACEMENT = "Pemandu_KantilPuzzle",
		CANTIL_PUZZLE = "Pemandu_KantilPuzzle",
		CANTIL_BLACK_OBTAINED = "Pemandu_KantilStore",
	},
}

-- Dialog LAPORAN saat sebuah quest sudah COMPLETE (item sudah disimpan di RitualCollection, ADR-026).
-- Pemandu hanya melapor; menamatkan dialog ini memberi quest berikutnya (jika masih LOCKED).
local REPORT_DIALOGUES: { [string]: { dialogueId: string, nextQuestId: string? } } = {
	KERIS = { dialogueId = "Pemandu_KerisDone", nextQuestId = "KANTIL" },
}

local GameFlowService = {}

-- Mulai quest: state game -> aktivasi -> state pertama. Return false jika ada langkah yang ditolak.
local function startQuest(questId: string): boolean
	local flow = QUEST_FLOW[questId]
	if not flow then
		Log.warn(TAG, "alur quest tidak dikenal: " .. questId)
		return false
	end
	if GameManager.getState() ~= flow.gameState and not GameManager.transitionTo(flow.gameState) then
		return false
	end
	if not QuestService.activate(questId) then
		Log.warn(TAG, "gagal mengaktifkan quest " .. questId)
		return false
	end
	if not QuestService.transition(questId, flow.startState) then
		Log.warn(TAG, string.format("gagal memulai quest %s (%s)", questId, flow.startState))
		return false
	end
	return true
end

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
	startQuest("KERIS")
end

-- Menamatkan dialog laporan: beri quest berikutnya. Aman dipanggil ganda (hanya jika quest berikutnya LOCKED).
local function onReportCompleted(player: Player, questId: string)
	local report = REPORT_DIALOGUES[questId]
	local nextQuestId = report and report.nextQuestId
	if not nextQuestId or QuestService.getState(nextQuestId) ~= "LOCKED" then
		return
	end
	Log.info(TAG, string.format("%s menamatkan laporan %s; memulai quest %s", player.Name, questId, nextQuestId))
	startQuest(nextQuestId)
end

-- Dialog Pemandu menurut state saat ini. Return nil jika belum ada dialog untuk state tersebut.
function GameFlowService.getPemanduDialogueId(player: Player?): string?
	if GameManager.getState() == GameState.LOBBY then
		return INTRO_DIALOGUE_ID
	end

	-- Quest berjalan = quest pertama yang bukan LOCKED dan bukan COMPLETE. Jika tidak ada,
	-- Pemandu melaporkan quest terakhir yang selesai.
	local lastComplete: string? = nil
	for _, questId in QuestConfig.ORDER do
		local state = QuestService.getState(questId)
		if state == nil or state == "LOCKED" then
			break
		end
		if state ~= "COMPLETE" then
			local rule = QUEST_DIALOGUES[questId] and QUEST_DIALOGUES[questId][state]
			if type(rule) == "function" then
				return rule(player)
			end
			return rule
		end
		lastComplete = questId
	end

	local report = lastComplete and REPORT_DIALOGUES[lastComplete]
	return report and report.dialogueId or nil
end

function GameFlowService.init()
	DialogueService.onCompleted(function(player: Player, dialogueId: string)
		if dialogueId == INTRO_DIALOGUE_ID then
			startGame(player)
			return
		end
		for questId, report in REPORT_DIALOGUES do
			if report.dialogueId == dialogueId then
				onReportCompleted(player, questId)
				return
			end
		end
	end)

	Log.info(TAG, "siap")
end

return table.freeze(GameFlowService)
