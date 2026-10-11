--!strict
-- KafanQuestService: quest 03 Kain Kafan (Phase 7). Perekat antara objek Gamelan di dunia, RhythmGameService
-- (minigame), QuestService (state), dan ItemService (hadiah). Pola sama dengan KerisQuestService.
-- SATU pemain memainkan gamelan (ADR-038). Skor >= REQUIRED_SCORE -> Kain Kafan diberikan ke pemain itu ->
-- ia menyimpannya di RitualCollection (ADR-026, ditangani RitualCollectionService, bukan di sini).
-- Gagal skor = boleh main lagi (siapa pun di party), tanpa hukuman.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("Config"):WaitForChild("GameConfig") :: ModuleScript)
local GamelanConfig = require(Shared:WaitForChild("Config"):WaitForChild("GamelanConfig") :: ModuleScript)
local Log = require(Shared:WaitForChild("Util"):WaitForChild("Log") :: ModuleScript)
local Services = script.Parent
local InteractionService = require(Services:WaitForChild("InteractionService") :: ModuleScript)
local ItemService = require(Services:WaitForChild("ItemService") :: ModuleScript)
local NoticeService = require(Services:WaitForChild("NoticeService") :: ModuleScript)
local QuestService = require(Services:WaitForChild("QuestService") :: ModuleScript)
local RhythmGameService = require(Services:WaitForChild("RhythmGameService") :: ModuleScript)

local TAG = "KafanQuestService"
local QUEST_ID = "KAFAN"
local KAIN_ITEM_ID = "KainKafan"

local KafanQuestService = {}

local gamelan: Instance? = nil
local kainHolder: Player? = nil -- pemegang Kain Kafan (dipindah jika keluar sebelum menyimpan)

-- ===== Objek gamelan =====

local function isPlayable(state: string?): boolean
	return state == "FIND_GAMELAN" or state == "GAMELAN_ACTIVE"
end

-- Prompt [E] Mainkan hanya ada saat quest Kafan menunggu permainan.
local function refreshInteractable()
	if not gamelan then
		return
	end
	if isPlayable(QuestService.getState(QUEST_ID)) then
		CollectionService:AddTag(gamelan, GameConfig.Interaction.TAG)
	else
		CollectionService:RemoveTag(gamelan, GameConfig.Interaction.TAG)
	end
end

-- Dipanggil RhythmGameService saat sesi selesai. Return true jika Kain Kafan berhasil diberikan.
-- Urutan: beri kain -> GAMELAN_COMPLETE -> KAIN_OBTAINED. Gagal di tengah = kain dibatalkan (tidak ada duplikat).
local function onFinish(player: Player, result: RhythmGameService.Result): boolean
	if not result.passed then
		NoticeService.send(
			player,
			string.format(
				"Skor %d. Butuh %d untuk lulus. Mainkan gamelan lagi.",
				result.score,
				GamelanConfig.REQUIRED_SCORE
			)
		)
		return false
	end

	if QuestService.getState(QUEST_ID) ~= "GAMELAN_ACTIVE" then
		return false
	end
	if not ItemService.give(player, KAIN_ITEM_ID, 1) then
		Log.warn(TAG, "gagal memberi KainKafan (cek template ServerStorage.QuestTemplates.KainKafan)")
		NoticeService.send(player, "Terjadi masalah. Mainkan gamelan lagi.")
		return false
	end
	if not QuestService.transition(QUEST_ID, "GAMELAN_COMPLETE") then
		ItemService.consume(player, KAIN_ITEM_ID, 1)
		return false
	end
	if not QuestService.transition(QUEST_ID, "KAIN_OBTAINED") then
		Log.warn(TAG, "gagal pindah ke KAIN_OBTAINED setelah GAMELAN_COMPLETE")
	end

	kainHolder = player
	NoticeService.notifyParty(
		player,
		string.format("Skor %d. Kamu mendapatkan Kain Kafan. Simpan di tempat ritual.", result.score),
		string.format("%s mendapatkan Kain Kafan (skor %d). Simpan di tempat ritual.", player.Name, result.score)
	)
	Log.info(TAG, string.format("%s lulus gamelan (skor %d) dan mendapat Kain Kafan", player.Name, result.score))
	return true
end

local function onGamelanInteract(player: Player, target: Instance)
	if target ~= gamelan then
		return
	end

	local state = QuestService.getState(QUEST_ID)
	if not isPlayable(state) then
		return
	end

	local busyWith = RhythmGameService.getActivePlayer()
	if busyWith then
		if busyWith ~= player then
			NoticeService.send(player, busyWith.Name .. " sedang memainkan gamelan.")
		end
		return
	end

	if not ItemService.getTemplate(KAIN_ITEM_ID) then
		Log.warn(TAG, "dependency belum ada: template KainKafan di ServerStorage.QuestTemplates")
		return
	end

	-- Pertama kali gamelan ditemukan: FIND_GAMELAN -> GAMELAN_ACTIVE. Gagal skor = tetap GAMELAN_ACTIVE (coba lagi).
	if state == "FIND_GAMELAN" and not QuestService.transition(QUEST_ID, "GAMELAN_ACTIVE") then
		return
	end

	if not RhythmGameService.start(player, onFinish) then
		return
	end
	NoticeService.notifyParty(
		player,
		"Kamu mulai memainkan gamelan.",
		string.format("%s mulai memainkan gamelan.", player.Name)
	)
end

local function setupGamelan()
	local questObjects = Workspace:FindFirstChild("QuestObjects")
	gamelan = questObjects and questObjects:FindFirstChild(GamelanConfig.OBJECT_NAME)
	if not gamelan then
		Log.warn(TAG, "dependency belum ada: Workspace.QuestObjects." .. GamelanConfig.OBJECT_NAME)
		return
	end

	local Interaction = GameConfig.Interaction
	gamelan:SetAttribute(Interaction.ATTR_ID, GamelanConfig.INTERACTION_ID)
	gamelan:SetAttribute(Interaction.ATTR_ACTION_TEXT, GamelanConfig.ACTION_TEXT)
	gamelan:SetAttribute(Interaction.ATTR_OBJECT_TEXT, GamelanConfig.OBJECT_TEXT)
	gamelan:SetAttribute(Interaction.ATTR_MAX_DISTANCE, GamelanConfig.MAX_DISTANCE)
	refreshInteractable()
end

-- ===== Pemegang kain keluar game =====

local function onPlayerRemoving(leaving: Player)
	if kainHolder ~= leaving then
		return
	end
	kainHolder = nil
	if QuestService.getState(QUEST_ID) ~= "KAIN_OBTAINED" then
		return
	end
	for _, other in Players:GetPlayers() do
		if other ~= leaving and ItemService.give(other, KAIN_ITEM_ID, 1) then
			kainHolder = other
			NoticeService.notifyParty(
				other,
				"Pemegang Kain Kafan keluar. Kini kamu memegang Kain Kafan.",
				string.format("Pemegang Kain Kafan keluar. Kini %s memegang Kain Kafan.", other.Name)
			)
			Log.info(TAG, string.format("pemegang Kain Kafan keluar; dipindah ke %s", other.Name))
			return
		end
	end
	Log.warn(TAG, "pemegang Kain Kafan keluar dan tidak ada pemain lain yang bisa menerima")
end

function KafanQuestService.getKainHolder(): Player?
	return kainHolder
end

function KafanQuestService.init()
	InteractionService.register(GamelanConfig.INTERACTION_ID, onGamelanInteract)
	setupGamelan()

	Players.PlayerRemoving:Connect(onPlayerRemoving)

	QuestService.onStateChanged(function(questId: string, _fromState: string, toState: string)
		if questId ~= QUEST_ID then
			return
		end
		if toState == "KAIN_SUBMITTED" or toState == "COMPLETE" then
			kainHolder = nil -- kain sudah disimpan di RitualCollection
		end
		refreshInteractable()
	end)

	Log.info(TAG, "siap")
end

return table.freeze(KafanQuestService)
