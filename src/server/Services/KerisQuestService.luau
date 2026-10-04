--!strict
-- KerisQuestService: logika dunia untuk quest Keris Pusaka (Phase 4).
-- Task ini: spawn Kelor (4 dari 8, acak di server), pickup lewat [E], progres party-wide.
-- Peti, kunci, memory puzzle, dan penyerahan keris ditambahkan bertahap di task berikutnya.
--
-- State pickup (server): AVAILABLE -> COLLECTING -> COLLECTED. Pickup hanya diterima dari objek yang
-- terdaftar di tabel server dan saat quest berada di SEARCHING_KELOR, sehingga tidak bisa digandakan.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("Config"):WaitForChild("GameConfig") :: ModuleScript)
local QuestConfig = require(Shared:WaitForChild("Config"):WaitForChild("QuestConfig") :: ModuleScript)
local Log = require(Shared:WaitForChild("Util"):WaitForChild("Log") :: ModuleScript)
local Services = script.Parent
local GameManager = require(Services:WaitForChild("GameManager") :: ModuleScript)
local DialogueService = require(Services:WaitForChild("DialogueService") :: ModuleScript)
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

type PickupState = {
	status: "AVAILABLE" | "COLLECTING" | "COLLECTED",
	spawnName: string,
}

local KerisQuestService = {}

local pickups: { [Instance]: PickupState } = {}
local keyHolder: Player? = nil
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
end

-- Pilih satu pemain acak (server) yang boleh memegang kunci. Hanya pemain NORMAL ber-Backpack.
local function pickKeyHolder(exclude: Player?): Player?
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

-- Hapus semua Daun Kelor dari semua pemain (item quest sudah diserahkan ke Pemandu).
local function stripKelor()
	for _, member in Players:GetPlayers() do
		local owned = ItemService.count(member, KELOR_ITEM_ID)
		if owned > 0 then
			ItemService.consume(member, KELOR_ITEM_ID, owned)
		end
	end
end

-- Serah-terima kunci: dipanggil setelah dialog Pemandu_KerisKey tamat. Tanpa yield, jadi dua pemain yang
-- menamatkan dialog bersamaan tidak bisa menghasilkan dua kunci (pemanggil kedua melihat state sudah berubah).
-- Urutan: beri kunci -> transisi state -> hapus Kelor. Jika gagal di tengah, kunci dibatalkan.
local function handOverKey(player: Player)
	if QuestService.getState(QUEST_ID) ~= "KELOR_COMPLETE" then
		return
	end

	local holder = pickKeyHolder(nil)
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

	keyHolder = holder
	stripKelor()
	Log.info(TAG, string.format("%s menamatkan dialog; Kunci Peti diberikan ke %s", player.Name, holder.Name))
end

-- Pemegang kunci keluar sebelum peti dibuka: pindahkan kunci ke pemain lain agar quest tidak buntu.
local function onPlayerRemoving(leaving: Player)
	if leaving ~= keyHolder then
		return
	end
	keyHolder = nil

	local state = QuestService.getState(QUEST_ID)
	if state ~= "KEY_OBTAINED" and state ~= "CHEST_AVAILABLE" then
		return
	end

	local newHolder = pickKeyHolder(leaving)
	if newHolder and ItemService.give(newHolder, KEY_ITEM_ID, 1) then
		keyHolder = newHolder
		Log.info(TAG, string.format("pemegang kunci keluar; Kunci Peti dipindah ke %s", newHolder.Name))
	else
		Log.warn(TAG, "pemegang kunci keluar dan tidak ada pemain lain yang bisa menerima kunci")
	end
end

function KerisQuestService.getKeyHolder(): Player?
	return keyHolder
end

function KerisQuestService.init()
	InteractionService.register(KELOR_INTERACTION_ID, onKelorInteract)

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
	end)

	Log.info(TAG, "siap")
end

return table.freeze(KerisQuestService)
