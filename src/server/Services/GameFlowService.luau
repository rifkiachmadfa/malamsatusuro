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

local TAG = "GameFlowService"
local INTRO_DIALOGUE_ID = "Pemandu_Intro"

local GameState = GameConfig.GameState

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
function GameFlowService.getPemanduDialogueId(): string?
	if GameManager.getState() == GameState.LOBBY then
		return INTRO_DIALOGUE_ID
	end
	if QuestService.getState("KERIS") == "SEARCHING_KELOR" then
		return "Pemandu_KerisSearch"
	end
	return nil
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
