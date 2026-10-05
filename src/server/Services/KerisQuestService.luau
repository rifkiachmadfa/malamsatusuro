--!strict
-- KerisQuestService: logika dunia untuk quest Keris Pusaka (Phase 4).
-- Alur: Kelor (4 dari 8, acak di server) -> Pemandu memberi Kunci Peti ke SATU pemain acak -> peti ->
-- memory puzzle (MemoryPuzzleService) -> Keris Pusaka -> disimpan di RitualCollection (RitualCollectionService)
-- -> quest COMPLETE. Pemandu hanya melaporkan (dialog), tidak menyelesaikan quest.
--
-- State pickup (server): AVAILABLE -> COLLECTING -> COLLECTED. Pickup hanya diterima dari objek yang
-- terdaftar di tabel server dan saat quest berada di SEARCHING_KELOR, sehingga tidak bisa digandakan.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("Config"):WaitForChild("GameConfig") :: ModuleScript)
local ItemConfig = require(Shared:WaitForChild("Config"):WaitForChild("ItemConfig") :: ModuleScript)
local QuestConfig = require(Shared:WaitForChild("Config"):WaitForChild("QuestConfig") :: ModuleScript)
local Log = require(Shared:WaitForChild("Util"):WaitForChild("Log") :: ModuleScript)
local Services = script.Parent
local GameManager = require(Services:WaitForChild("GameManager") :: ModuleScript)
local DialogueService = require(Services:WaitForChild("DialogueService") :: ModuleScript)
local MemoryPuzzleService = require(Services:WaitForChild("MemoryPuzzleService") :: ModuleScript)
local NoticeService = require(Services:WaitForChild("NoticeService") :: ModuleScript)
local QuestService = require(Services:WaitForChild("QuestService") :: ModuleScript)
local ItemService = require(Services:WaitForChild("ItemService") :: ModuleScript)
local InteractionService = require(Services:WaitForChild("InteractionService") :: ModuleScript)
local RandomSpawnService = require(Services:WaitForChild("RandomSpawnService") :: ModuleScript)

local TAG = "KerisQuestService"
local QUEST_ID = "KERIS"
local KELOR_COUNTER = "Kelor"
local KELOR_ITEM_ID = "DaunKelor"
local KELOR_INTERACTION_ID = "Kelor"
local KELOR_PICKUP_DISTANCE = 8
local KEY_ITEM_ID = "KunciPeti"
local KEY_DIALOGUE_ID = "Pemandu_KerisKey" -- dialog Pemandu saat KELOR_COMPLETE (lihat GameFlowService)
local KERIS_ITEM_ID = "KerisPusaka"
local CHEST_INTERACTION_ID = "Chest"
local CHEST_MAX_DISTANCE = 12

type PickupState = {
	status: "AVAILABLE" | "COLLECTING" | "COLLECTED",
	spawnName: string,
}

local KerisQuestService = {}

local pickups: { [Instance]: PickupState } = {}
local chest: Instance? = nil
-- Pemegang item quest unik (KunciPeti, KerisPusaka). Dipakai memindahkan item jika pemegangnya keluar game.
local holders: { [string]: Player } = {}
local rng = Random.new()

local function findKelorSpawns(): Instance?
	local questObjects = Workspace:FindFirstChild("QuestObjects")
	return questObjects and questObjects:FindFirstChild("KelorSpawns")
end

local function clearKelor()
	local toRemove: { Instance } = {}
	for model in pickups do
		table.insert(toRemove, model)
	end
	table.clear(pickups)
	for _, model in toRemove do
		model:Destroy()
	end
end

-- Jumlah Kelor aktif = target counter Kelor (satu sumber: QuestConfig), sisanya tidak di-spawn.
local function spawnKelor()
	clearKelor()

	local spawns = findKelorSpawns()
	if not spawns then
		Log.warn(TAG, "dependency belum ada: Workspace.QuestObjects.KelorSpawns")
		return
	end

	local template = ItemService.getTemplate(KELOR_ITEM_ID)
	if not template then
		Log.warn(TAG, "dependency belum ada: template " .. KELOR_ITEM_ID)
		return
	end

	local def = (QuestConfig.Quests :: any)[QUEST_ID] :: QuestConfig.QuestDef
	local activeCount = def.counters[KELOR_COUNTER].target

	local picked = RandomSpawnService.pickSpawns(spawns, activeCount)
	local folder = RandomSpawnService.getRuntimeFolder()
	local names: { string } = {}

	for _, spawn in picked do
		local model = RandomSpawnService.createPickup(template, spawn, folder, {
			interactionId = KELOR_INTERACTION_ID,
			actionText = "Ambil",
			objectText = "Daun Kelor",
			maxDistance = KELOR_PICKUP_DISTANCE,
		})
		if model then
			pickups[model] = { status = "AVAILABLE", spawnName = spawn.Name }
			table.insert(names, spawn.Name)
		end
	end

	table.sort(names)
	Log.info(TAG, string.format("Kelor aktif (%d/%d titik): %s", #names, #spawns:GetChildren(), table.concat(names, ", ")))
	if #names < activeCount then
		Log.warn(TAG, string.format("hanya %d Kelor ter-spawn, quest butuh %d", #names, activeCount))
	end
end

local function onKelorInteract(player: Player, target: Instance)
	local pickup = pickups[target]
	if not pickup or pickup.status ~= "AVAILABLE" then
		return
	end
	if QuestService.getState(QUEST_ID) ~= "SEARCHING_KELOR" then
		return
	end

	pickup.status = "COLLECTING"

	if not ItemService.give(player, KELOR_ITEM_ID, 1) then
		pickup.status = "AVAILABLE"
		return
	end

	local progress = QuestService.addProgress(QUEST_ID, KELOR_COUNTER, 1)
	if progress == nil then
		-- Progres ditolak (state berubah): batalkan item agar tidak ada duplikat.
		ItemService.consume(player, KELOR_ITEM_ID, 1)
		pickup.status = "AVAILABLE"
		return
	end

	pickup.status = "COLLECTED"
	pickups[target] = nil
	target:Destroy()
	Log.info(TAG, string.format("%s mengambil Kelor di %s (party %d)", player.Name, pickup.spawnName, progress))

	local def = (QuestConfig.Quests :: any)[QUEST_ID] :: QuestConfig.QuestDef
	local target = def.counters[KELOR_COUNTER].target
	NoticeService.notifyParty(
		player,
		string.format("Kamu mendapatkan Daun Kelor (%d/%d).", progress, target),
		string.format("%s mendapatkan Daun Kelor (%d/%d).", player.Name, progress, target)
	)
	if progress >= target then
		NoticeService.broadcast("Daun Kelor sudah lengkap. Kembali ke Pemandu.")
	end
end

-- Pilih satu pemain acak (server). Hanya pemain NORMAL ber-Backpack.
local function pickHolder(exclude: Player?): Player?
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

-- Hapus semua Daun Kelor dari semua pemain (Kelor sudah dipakai untuk mendapat kunci dari Pemandu).
local function stripKelor()
	for _, member in Players:GetPlayers() do
		local owned = ItemService.count(member, KELOR_ITEM_ID)
		if owned > 0 then
			ItemService.consume(member, KELOR_ITEM_ID, owned)
		end
	end
end

-- ===== Peti =====

local function setChestInteractive(enabled: boolean)
	if not chest then
		return
	end
	if enabled then
		CollectionService:AddTag(chest, GameConfig.Interaction.TAG)
	else
		CollectionService:RemoveTag(chest, GameConfig.Interaction.TAG)
	end
end

-- Dipanggil MemoryPuzzleService saat jawaban BENAR. Return true jika hadiah berhasil diberikan.
-- Urutan: beri keris -> transisi state -> hapus kunci. Gagal di tengah = keris dibatalkan.
local function onPuzzleCorrect(player: Player): boolean
	if QuestService.getState(QUEST_ID) ~= "CHEST_PUZZLE" then
		return false
	end
	if not ItemService.has(player, KEY_ITEM_ID) then
		return false
	end
	if not ItemService.give(player, KERIS_ITEM_ID, 1) then
		return false
	end
	if not QuestService.transition(QUEST_ID, "KERIS_OBTAINED") then
		ItemService.consume(player, KERIS_ITEM_ID, 1)
		return false
	end

	ItemService.consume(player, KEY_ITEM_ID, 1)
	holders[KEY_ITEM_ID] = nil
	holders[KERIS_ITEM_ID] = player
	NoticeService.notifyParty(
		player,
		"Kamu mendapatkan Keris Pusaka. Simpan di tempat ritual.",
		string.format("%s mendapatkan Keris Pusaka. Simpan di tempat ritual.", player.Name)
	)
	Log.info(TAG, string.format("%s membuka peti dan mendapat Keris Pusaka", player.Name))
	return true
end

local function onChestInteract(player: Player, target: Instance)
	if target ~= chest then
		return
	end

	local state = QuestService.getState(QUEST_ID)
	if state ~= "CHEST_AVAILABLE" and state ~= "CHEST_PUZZLE" then
		return
	end

	local busyWith = MemoryPuzzleService.getActivePlayer()
	if busyWith then
		if busyWith ~= player then
			NoticeService.send(player, busyWith.Name .. " sedang membuka peti.")
		end
		return
	end

	if not ItemService.has(player, KEY_ITEM_ID) then
		NoticeService.send(player, "Peti terkunci. Kamu tidak memegang Kunci Peti.")
		return
	end

	if not ItemService.getTemplate(KERIS_ITEM_ID) then
		Log.warn(TAG, "dependency belum ada: template KerisPusaka di ServerStorage.QuestTemplates")
		return
	end

	-- Gagal puzzle = tetap di CHEST_PUZZLE, boleh mencoba lagi (peti tidak terkunci permanen).
	if state == "CHEST_AVAILABLE" and not QuestService.transition(QUEST_ID, "CHEST_PUZZLE") then
		return
	end
	MemoryPuzzleService.start(player, onPuzzleCorrect)
end

local function setupChest()
	local questObjects = Workspace:FindFirstChild("QuestObjects")
	chest = questObjects and questObjects:FindFirstChild("Chest")
	if not chest then
		Log.warn(TAG, "dependency belum ada: Workspace.QuestObjects.Chest")
		return
	end

	local Interaction = GameConfig.Interaction
	chest:SetAttribute(Interaction.ATTR_ID, CHEST_INTERACTION_ID)
	chest:SetAttribute(Interaction.ATTR_ACTION_TEXT, "Buka")
	chest:SetAttribute(Interaction.ATTR_OBJECT_TEXT, "Peti")
	chest:SetAttribute(Interaction.ATTR_MAX_DISTANCE, CHEST_MAX_DISTANCE)
	setChestInteractive(false) -- baru bisa diinteraksi saat CHEST_AVAILABLE
end

-- ===== Kunci =====

-- Serah-terima kunci: dipanggil setelah dialog Pemandu_KerisKey tamat. Tanpa yield, jadi dua pemain yang
-- menamatkan dialog bersamaan tidak bisa menghasilkan dua kunci (pemanggil kedua melihat state sudah berubah).
-- Urutan: beri kunci -> transisi state -> hapus Kelor. Jika gagal di tengah, kunci dibatalkan.
local function handOverKey(player: Player)
	if QuestService.getState(QUEST_ID) ~= "KELOR_COMPLETE" then
		return
	end

	local holder = pickHolder(nil)
	if not holder then
		Log.warn(TAG, "tidak ada pemain valid untuk menerima kunci")
		return
	end

	if not ItemService.give(holder, KEY_ITEM_ID, 1) then
		Log.warn(TAG, "gagal memberi KunciPeti (cek template ServerStorage.QuestTemplates.KunciPeti)")
		return
	end

	if not QuestService.transition(QUEST_ID, "KEY_OBTAINED") then
		ItemService.consume(holder, KEY_ITEM_ID, 1)
		return
	end

	holders[KEY_ITEM_ID] = holder
	stripKelor()
	Log.info(TAG, string.format("%s menamatkan dialog; Kunci Peti diberikan ke %s", player.Name, holder.Name))

	-- Peti langsung bisa dibuka (oleh pemegang kunci saja).
	if not QuestService.transition(QUEST_ID, "CHEST_AVAILABLE") then
		Log.warn(TAG, "gagal membuka akses peti")
	end

	NoticeService.notifyParty(
		holder,
		"Kamu memegang Kunci Peti. Hanya kamu yang bisa membuka peti.",
		holder.Name .. " memegang Kunci Peti."
	)
end

-- ===== Pemegang item keluar game =====

local function reassignItem(itemId: string, leaving: Player)
	local newHolder = pickHolder(leaving)
	if newHolder and ItemService.give(newHolder, itemId, 1) then
		holders[itemId] = newHolder
		local def = ItemConfig.Items[itemId]
		local name = if def then def.displayName else itemId
		NoticeService.notifyParty(
			newHolder,
			string.format("Pemegang %s keluar. Kini kamu memegang %s.", name, name),
			string.format("Pemegang %s keluar. Kini %s memegang %s.", name, newHolder.Name, name)
		)
		Log.info(TAG, string.format("pemegang %s keluar; dipindah ke %s", itemId, newHolder.Name))
	else
		Log.warn(TAG, string.format("pemegang %s keluar dan tidak ada pemain lain yang bisa menerima", itemId))
	end
end

-- Pemegang kunci/keris keluar sebelum item dipakai: pindahkan ke pemain lain agar quest tidak buntu.
local function onPlayerRemoving(leaving: Player)
	local state = QuestService.getState(QUEST_ID)

	if holders[KEY_ITEM_ID] == leaving then
		holders[KEY_ITEM_ID] = nil
		if state == "KEY_OBTAINED" or state == "CHEST_AVAILABLE" or state == "CHEST_PUZZLE" then
			reassignItem(KEY_ITEM_ID, leaving)
		end
	end

	if holders[KERIS_ITEM_ID] == leaving then
		holders[KERIS_ITEM_ID] = nil
		if state == "KERIS_OBTAINED" then
			reassignItem(KERIS_ITEM_ID, leaving)
		end
	end
end

function KerisQuestService.getKeyHolder(): Player?
	return holders[KEY_ITEM_ID]
end

function KerisQuestService.init()
	InteractionService.register(KELOR_INTERACTION_ID, onKelorInteract)
	InteractionService.register(CHEST_INTERACTION_ID, onChestInteract)
	setupChest()

	DialogueService.onCompleted(function(player: Player, dialogueId: string)
		if dialogueId == KEY_DIALOGUE_ID then
			handOverKey(player)
		end
	end)
	Players.PlayerRemoving:Connect(onPlayerRemoving)

	QuestService.onStateChanged(function(questId: string, fromState: string, toState: string)
		if questId ~= QUEST_ID then
			return
		end
		if toState == "SEARCHING_KELOR" then
			spawnKelor()
		elseif fromState == "SEARCHING_KELOR" then
			clearKelor()
		end

		if toState == "KERIS_SUBMITTED" or toState == "COMPLETE" then
			holders[KERIS_ITEM_ID] = nil -- keris sudah disimpan di RitualCollection
		end

		if toState == "CHEST_AVAILABLE" then
			setChestInteractive(true)
		elseif toState == "KERIS_OBTAINED" then
			setChestInteractive(false)
		end
	end)

	Log.info(TAG, "siap")
end

return table.freeze(KerisQuestService)
