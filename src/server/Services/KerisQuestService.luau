--!strict
-- KerisQuestService: logika dunia untuk quest Keris Pusaka (Phase 4).
-- Task ini: spawn Kelor (4 dari 8, acak di server), pickup lewat [E], progres party-wide.
-- Peti, kunci, memory puzzle, dan penyerahan keris ditambahkan bertahap di task berikutnya.
--
-- State pickup (server): AVAILABLE -> COLLECTING -> COLLECTED. Pickup hanya diterima dari objek yang
-- terdaftar di tabel server dan saat quest berada di SEARCHING_KELOR, sehingga tidak bisa digandakan.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local QuestConfig = require(Shared:WaitForChild("Config"):WaitForChild("QuestConfig") :: ModuleScript)
local Log = require(Shared:WaitForChild("Util"):WaitForChild("Log") :: ModuleScript)
local Services = script.Parent
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

type PickupState = {
	status: "AVAILABLE" | "COLLECTING" | "COLLECTED",
	spawnName: string,
}

local KerisQuestService = {}

local pickups: { [Instance]: PickupState } = {}

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

function KerisQuestService.init()
	InteractionService.register(KELOR_INTERACTION_ID, onKelorInteract)

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
