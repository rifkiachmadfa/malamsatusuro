--!strict
-- PemanduService: dialog Pemandu mengikuti state quest (data di QuestConfig.pemandu).
-- Pemandu hanya menjalankan transisi quest setelah dialog selesai dibaca,
-- dan hanya jika state quest belum berubah sejak dialog dimulai (anti dobel-eksekusi).
-- Phase 2: serah-terima hanya memeriksa STATE. Pemeriksaan item = Phase 3 (InventoryService).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("Config"):WaitForChild("GameConfig") :: ModuleScript)
local QuestConfig = require(Shared:WaitForChild("Config"):WaitForChild("QuestConfig") :: ModuleScript)
local DialogueConfig = require(Shared:WaitForChild("Config"):WaitForChild("DialogueConfig") :: ModuleScript)
local Log = require(Shared:WaitForChild("Util"):WaitForChild("Log") :: ModuleScript)
local GameManager = require(script.Parent:WaitForChild("GameManager") :: ModuleScript)
local InteractionService = require(script.Parent:WaitForChild("InteractionService") :: ModuleScript)
local DialogueService = require(script.Parent:WaitForChild("DialogueService") :: ModuleScript)
local QuestService = require(script.Parent:WaitForChild("QuestService") :: ModuleScript)

local INTERACTION_ID = "Pemandu"
local INTRO_DIALOGUE = "Pemandu_Intro"
local IDLE_DIALOGUE = "Pemandu_Idle"
local TAG = "PemanduService"

local PemanduService = {}

local function assertDialogue(id: string)
	assert(DialogueConfig[id], "dialog tidak ada di DialogueConfig: " .. id)
end

local function onInteract(player: Player, target: Instance)
	if DialogueService.isInDialogue(player) then
		return
	end

	if GameManager.getState() == GameConfig.GameState.LOBBY then
		DialogueService.start(player, INTRO_DIALOGUE, target, function()
			QuestService.startGame()
		end)
		return
	end

	local questId = QuestService.getActiveQuestId()
	if not questId then
		DialogueService.start(player, IDLE_DIALOGUE, target)
		return
	end

	local def = QuestConfig.Quests[questId]
	local state = QuestService.getState(questId) :: string
	local entry = def.pemandu[state]
	if not entry then
		DialogueService.start(player, def.hintDialogue, target)
		return
	end

	DialogueService.start(player, entry.dialogue, target, function()
		if QuestService.getState(questId) ~= state then
			return -- pemain lain sudah menjalankan transisi ini
		end
		for _, nextState in entry.advance or {} do
			if not QuestService.advance(questId, nextState) then
				break
			end
		end
	end)
end

function PemanduService.init()
	assertDialogue(INTRO_DIALOGUE)
	assertDialogue(IDLE_DIALOGUE)
	for _, questId in QuestConfig.Order do
		local def = QuestConfig.Quests[questId]
		assertDialogue(def.hintDialogue)
		for _, entry in def.pemandu do
			assertDialogue(entry.dialogue)
		end
	end

	InteractionService.register(INTERACTION_ID, onInteract)
	Log.info(TAG, "siap")
end

return table.freeze(PemanduService)