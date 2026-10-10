--!strict
-- GravePuzzleService: placement bunga di makam dan validasi jawaban quest Kantil (Task 5.7-5.8, ADR-029).
-- Clue = SurfaceGui di makam (Studio); kode hanya mengurus penempatan dan pengecekan, semuanya di server.
--
-- Alur (validasi PER BUNGA, ADR-029/030):
--   FLOWERS_COMPLETE -> pemain MEMEGANG (equip) bunga lalu [E] di makam. Percobaan pertama memajukan state
--   sampai CANTIL_PUZZLE (puzzle berjalan). Setiap bunga dinilai saat itu juga:
--     BENAR -> bunga dipakai (tetap di makam), progres (n/4). Makam penuh -> pemain terakhir menerima
--              Kembang Kantil Hitam -> CANTIL_BLACK_OBTAINED.
--     SALAH -> bunga TIDAK dipakai (tetap di Backpack pemain itu, tidak ada bunga hilang), makam tidak berubah,
--              hook onWrong dipanggil (Phase 6: jumpscare + knock; semua knock = party wipe).
-- Semua langkah tanpa yield, sehingga dua pemain yang menekan [E] bersamaan tidak bisa mengisi satu makam dua kali.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("Config"):WaitForChild("GameConfig") :: ModuleScript)
local ItemConfig = require(Shared:WaitForChild("Config"):WaitForChild("ItemConfig") :: ModuleScript)
local Log = require(Shared:WaitForChild("Util"):WaitForChild("Log") :: ModuleScript)
local Config = require(script.Parent.Parent:WaitForChild("Config"):WaitForChild("GravePuzzleConfig") :: ModuleScript)
local Services = script.Parent
local GameManager = require(Services:WaitForChild("GameManager") :: ModuleScript)
local InteractionService = require(Services:WaitForChild("InteractionService") :: ModuleScript)
local ItemService = require(Services:WaitForChild("ItemService") :: ModuleScript)
local NoticeService = require(Services:WaitForChild("NoticeService") :: ModuleScript)
local QuestService = require(Services:WaitForChild("QuestService") :: ModuleScript)

local TAG = "GravePuzzleService"
local QUEST_ID = Config.QUEST_ID

type Slot = {
	itemId: string,
	placer: Player,
}

export type WrongListener = (player: Player, graveName: string, itemId: string) -> ()

local GravePuzzleService = {}

local graves: { [string]: Instance } = {} -- nama makam -> objek
local graveNames: { [Instance]: string } = {} -- objek -> nama makam
local slots: { [string]: Slot } = {} -- nama makam -> bunga yang sudah diletakkan
local totalGraves = 0
local rewardHolder: Player? = nil
local wrongListeners: { WrongListener } = {}
local rng = Random.new()

local function displayName(itemId: string): string
	local def = ItemConfig.Items[itemId]
	return if def then def.displayName else itemId
end

local function isFlower(itemId: unknown): boolean
	if type(itemId) ~= "string" then
		return false
	end
	for _, flowerId in Config.ANSWER do
		if flowerId == itemId then
			return true
		end
	end
	return false
end

local function slotCount(): number
	local count = 0
	for _ in slots do
		count += 1
	end
	return count
end

-- Pemain acak (server) yang valid menerima item. exclude boleh nil.
local function pickPlayer(exclude: Player?): Player?
	local candidates: { Player } = {}
	for _, candidate in Players:GetPlayers() do
		if
			candidate ~= exclude
			and GameManager.getPlayerState(candidate) == GameConfig.PlayerState.NORMAL
			and candidate:FindFirstChildOfClass("Backpack") ~= nil
		then
			table.insert(candidates, candidate)
		end
	end
	if #candidates == 0 then
		return nil
	end
	return candidates[rng:NextInteger(1, #candidates)]
end

-- Bunga yang sedang dipegang (equip) pemain, atau nil.
local function getHeldFlower(player: Player): string?
	local character = player.Character
	if not character then
		return nil
	end
	local tool = character:FindFirstChildOfClass("Tool")
	if not tool then
		return nil
	end
	local itemId = tool:GetAttribute(ItemConfig.ATTR_ITEM_ID)
	if isFlower(itemId) and ItemService.has(player, itemId :: string) then
		return itemId :: string
	end
	return nil
end

local function carriesFlower(player: Player): boolean
	for _, flowerId in Config.ANSWER do
		if ItemService.has(player, flowerId) then
			return true
		end
	end
	return false
end

-- Prompt makam hanya muncul saat placement terbuka dan makam itu masih kosong.
local function refreshGraves()
	local state = QuestService.getState(QUEST_ID)
	local open = state ~= nil and Config.OPEN_STATES[state] == true
	for name, grave in graves do
		if open and slots[name] == nil then
			CollectionService:AddTag(grave, GameConfig.Interaction.TAG)
		else
			CollectionService:RemoveTag(grave, GameConfig.Interaction.TAG)
		end
	end
end

local function fireWrong(player: Player, graveName: string, itemId: string)
	for _, listener in wrongListeners do
		task.spawn(listener, player, graveName, itemId)
	end
end

-- Hook bunga SALAH di makam (Phase 6: jumpscare + knock pemain itu; semua knock = party wipe).
function GravePuzzleService.onWrong(listener: WrongListener)
	table.insert(wrongListeners, listener)
end

function GravePuzzleService.getRewardHolder(): Player?
	return rewardHolder
end

-- Kembalikan semua bunga di makam ke penempatnya (atau pemain acak jika penempat sudah keluar), lalu kosongkan makam.
local function returnFlowers()
	for _, slot in slots do
		local recipient: Player? = if slot.placer.Parent == Players then slot.placer else pickPlayer(nil)
		if not recipient or not ItemService.give(recipient, slot.itemId, 1) then
			Log.warn(TAG, string.format("bunga %s tidak bisa dikembalikan", slot.itemId))
		end
	end
	table.clear(slots)
end

-- Rollback hadiah gagal: kembalikan bunga di makam ke penempatnya lalu kosongkan makam.
local function rollbackAll(): ()
	returnFlowers()
	refreshGraves()
end

-- Dipanggil saat semua makam terisi benar. state sudah CANTIL_PUZZLE.
local function complete(lastPlacer: Player)
	-- Beri hadiah dulu, baru pindah state. Gagal di tengah = hadiah dibatalkan dan bunga dikembalikan.
	local recipient: Player? = lastPlacer
	if lastPlacer.Parent ~= Players or not ItemService.give(lastPlacer, Config.REWARD_ITEM_ID, 1) then
		recipient = pickPlayer(nil)
		if not recipient or not ItemService.give(recipient, Config.REWARD_ITEM_ID, 1) then
			Log.warn(TAG, "gagal memberi " .. Config.REWARD_ITEM_ID .. "; bunga dikembalikan")
			rollbackAll()
			return
		end
	end
	local winner = recipient :: Player

	if not QuestService.transition(QUEST_ID, "CANTIL_BLACK_OBTAINED") then
		ItemService.consume(winner, Config.REWARD_ITEM_ID, 1)
		rollbackAll()
		return
	end

	table.clear(slots) -- bunga sudah terpakai; tidak dikembalikan
	rewardHolder = winner
	Log.info(TAG, string.format("makam lengkap; %s menerima %s", winner.Name, Config.REWARD_ITEM_ID))
	NoticeService.notifyParty(
		winner,
		"Kembang Kantil Hitam muncul dan kamu memegangnya. Simpan di tempat ritual.",
		string.format("%s memegang Kembang Kantil Hitam. Simpan di tempat ritual.", winner.Name)
	)
end

-- Majukan state sampai CANTIL_PUZZLE pada percobaan pertama. Return false jika ada transisi yang ditolak.
local function beginPuzzle(): boolean
	if QuestService.getState(QUEST_ID) == "FLOWERS_COMPLETE" and not QuestService.transition(QUEST_ID, "FLOWERS_PLACEMENT") then
		return false
	end
	if QuestService.getState(QUEST_ID) == "FLOWERS_PLACEMENT" and not QuestService.transition(QUEST_ID, "CANTIL_PUZZLE") then
		return false
	end
	return QuestService.getState(QUEST_ID) == "CANTIL_PUZZLE"
end

local function onGraveInteract(player: Player, target: Instance)
	local graveName = graveNames[target]
	if not graveName then
		return
	end

	local state = QuestService.getState(QUEST_ID)
	if state == nil or Config.OPEN_STATES[state] ~= true then
		return
	end
	if slots[graveName] ~= nil then
		return
	end

	local itemId = getHeldFlower(player)
	if not itemId then
		if carriesFlower(player) then
			NoticeService.send(player, "Pegang bunga yang ingin diletakkan (pilih dari hotbar), lalu tekan lagi.")
		else
			NoticeService.send(player, "Kamu tidak membawa bunga.")
		end
		return
	end

	local correct = Config.ANSWER[graveName] == itemId

	-- Hadiah harus bisa dibuat SEBELUM bunga terakhir dipakai (jangan sampai bunga habis tanpa hadiah).
	local isLast = correct and slotCount() + 1 == totalGraves
	if isLast and not ItemService.getTemplate(Config.REWARD_ITEM_ID) then
		Log.warn(TAG, "dependency belum ada: template " .. Config.REWARD_ITEM_ID .. " di ServerStorage.QuestTemplates")
		NoticeService.send(player, "Makam belum bisa diselesaikan.")
		return
	end

	if not beginPuzzle() then
		Log.warn(TAG, "gagal memulai puzzle makam (state " .. tostring(QuestService.getState(QUEST_ID)) .. ")")
		return
	end

	local name = displayName(itemId)
	if not correct then
		-- Bunga tetap di Backpack pemain (tidak dipakai); makam tidak berubah. Hukuman = hook (Phase 6).
		Log.info(TAG, string.format("%s meletakkan %s di %s: SALAH", player.Name, itemId, graveName))
		NoticeService.notifyParty(
			player,
			string.format("%s tidak cocok di makam ini!", name),
			string.format("%s meletakkan %s di makam yang salah!", player.Name, name)
		)
		fireWrong(player, graveName, itemId)
		return
	end

	if not ItemService.consume(player, itemId, 1) then
		return
	end
	slots[graveName] = { itemId = itemId, placer = player }
	local placed = slotCount()
	Log.info(TAG, string.format("%s meletakkan %s di %s: benar (%d/%d)", player.Name, itemId, graveName, placed, totalGraves))
	NoticeService.notifyParty(
		player,
		string.format("Kamu meletakkan %s di makam (%d/%d).", name, placed, totalGraves),
		string.format("%s meletakkan %s di makam (%d/%d).", player.Name, name, placed, totalGraves)
	)

	if placed < totalGraves then
		refreshGraves()
		return
	end
	complete(player)
end

-- Pemain keluar membawa bunga: pindahkan ke pemain lain agar quest tidak buntu (Backpack hilang bersama pemain).
local function onPlayerRemoving(leaving: Player)
	local state = QuestService.getState(QUEST_ID)
	if state ~= nil and Config.FLOWER_HOLD_STATES[state] == true then
		for _, flowerId in Config.ANSWER do
			local owned = ItemService.count(leaving, flowerId)
			if owned > 0 then
				local newHolder = pickPlayer(leaving)
				if newHolder and ItemService.give(newHolder, flowerId, owned) then
					NoticeService.notifyParty(
						newHolder,
						string.format("Pemain keluar. Kini kamu membawa %s.", displayName(flowerId)),
						string.format("Pemain keluar. Kini %s membawa %s.", newHolder.Name, displayName(flowerId))
					)
				else
					Log.warn(TAG, string.format("%s keluar membawa %s dan tidak ada pemain lain", leaving.Name, flowerId))
				end
			end
		end
	end

	if rewardHolder == leaving then
		rewardHolder = nil
		if state == "CANTIL_BLACK_OBTAINED" then
			local newHolder = pickPlayer(leaving)
			if newHolder and ItemService.give(newHolder, Config.REWARD_ITEM_ID, 1) then
				rewardHolder = newHolder
				NoticeService.notifyParty(
					newHolder,
					"Pemegang Kembang Kantil Hitam keluar. Kini kamu memegangnya.",
					string.format("Pemegang Kembang Kantil Hitam keluar. Kini %s memegangnya.", newHolder.Name)
				)
			else
				Log.warn(TAG, "pemegang Kembang Kantil Hitam keluar dan tidak ada pemain lain")
			end
		end
	end
end

local function setupGraves()
	local questObjects = Workspace:FindFirstChild("QuestObjects")
	local folder = questObjects and questObjects:FindFirstChild(Config.GRAVES_FOLDER)
	if not folder then
		Log.warn(TAG, "dependency belum ada: Workspace.QuestObjects." .. Config.GRAVES_FOLDER)
		return
	end

	local Interaction = GameConfig.Interaction
	for name in Config.ANSWER do
		local grave = folder:FindFirstChild(name)
		if not grave then
			Log.warn(TAG, string.format("dependency belum ada: makam %s di %s", name, Config.GRAVES_FOLDER))
		else
			grave:SetAttribute(Interaction.ATTR_ID, Config.INTERACTION_ID)
			grave:SetAttribute(Interaction.ATTR_ACTION_TEXT, Config.ACTION_TEXT)
			grave:SetAttribute(Interaction.ATTR_OBJECT_TEXT, Config.OBJECT_TEXT)
			grave:SetAttribute(Interaction.ATTR_MAX_DISTANCE, Config.MAX_DISTANCE)
			CollectionService:RemoveTag(grave, Interaction.TAG) -- baru aktif saat placement terbuka
			graves[name] = grave
			graveNames[grave] = name
		end
	end
end

function GravePuzzleService.init()
	for _ in Config.ANSWER do
		totalGraves += 1
	end

	InteractionService.register(Config.INTERACTION_ID, onGraveInteract)
	setupGraves()
	Players.PlayerRemoving:Connect(onPlayerRemoving)

	QuestService.onStateChanged(function(questId: string, _fromState: string, toState: string)
		if questId ~= QUEST_ID then
			return
		end
		-- Party wipe (CANTIL_PUZZLE -> SEARCHING_FLOWERS) atau reset: makam dikosongkan.
		if toState == "SEARCHING_FLOWERS" then
			table.clear(slots)
		end
		if toState == "CANTIL_SUBMITTED" or toState == "COMPLETE" then
			rewardHolder = nil
		end
		refreshGraves()
	end)

	if not Config.ANSWER_CONFIRMED then
		Log.warn(TAG, "jawaban makam masih PLACEHOLDER: samakan GravePuzzleConfig.ANSWER dengan clue di SurfaceGui")
	end
	local registered = 0
	for _ in graves do
		registered += 1
	end
	Log.info(TAG, string.format("siap, %d/%d makam terdaftar", registered, totalGraves))
end

return table.freeze(GravePuzzleService)
