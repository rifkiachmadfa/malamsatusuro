--!strict
-- CollectibleService: objective "kumpulkan N item di titik spawn acak" yang dipakai berulang (ADR-027).
-- Dipakai Kelor (Keris) dan bunga (Kantil); definisi ada di CollectionConfig. Satu logika untuk semuanya:
--   masuk activeState -> server memilih N titik acak (+ jenis item bila DISTINCT) -> pickup Model di dunia
--   [E] -> server validasi -> item ke Backpack pemain -> progres party-wide +1 -> notifikasi
--   keluar activeState -> pickup tersisa dihapus. Masuk activeState lagi (mis. party wipe) = spawn ulang.
--
-- State pickup (server): AVAILABLE -> COLLECTING -> COLLECTED. Pickup hanya diterima dari objek yang
-- terdaftar di tabel server dan saat quest berada di activeState, sehingga tidak bisa digandakan.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CollectionConfig = require(Shared:WaitForChild("Config"):WaitForChild("CollectionConfig") :: ModuleScript)
local ItemConfig = require(Shared:WaitForChild("Config"):WaitForChild("ItemConfig") :: ModuleScript)
local QuestConfig = require(Shared:WaitForChild("Config"):WaitForChild("QuestConfig") :: ModuleScript)
local Log = require(Shared:WaitForChild("Util"):WaitForChild("Log") :: ModuleScript)
local Services = script.Parent
local InteractionService = require(Services:WaitForChild("InteractionService") :: ModuleScript)
local ItemService = require(Services:WaitForChild("ItemService") :: ModuleScript)
local NoticeService = require(Services:WaitForChild("NoticeService") :: ModuleScript)
local QuestService = require(Services:WaitForChild("QuestService") :: ModuleScript)
local RandomSpawnService = require(Services:WaitForChild("RandomSpawnService") :: ModuleScript)

local TAG = "CollectibleService"

type Pickup = {
	status: "AVAILABLE" | "COLLECTING" | "COLLECTED",
	spawnName: string,
	itemId: string,
}

local CollectibleService = {}

local rng = Random.new()

local function displayName(itemId: string): string
	local def = ItemConfig.Items[itemId]
	return if def then def.displayName else itemId
end

local function findSpawnContainer(folderName: string): Instance?
	local questObjects = Workspace:FindFirstChild("QuestObjects")
	return questObjects and questObjects:FindFirstChild(folderName)
end

-- Jenis item per titik aktif. SAME: itemIds[1] di semua titik. DISTINCT: itemIds diacak, satu per titik.
local function assignItems(config: CollectionConfig.Collection, count: number): { string }
	local result: { string } = {}
	if config.assignment == "SAME" then
		for i = 1, count do
			result[i] = config.itemIds[1]
		end
		return result
	end

	local pool = table.clone(config.itemIds)
	for i = #pool, 2, -1 do
		local j = rng:NextInteger(1, i)
		pool[i], pool[j] = pool[j], pool[i]
	end
	for i = 1, count do
		result[i] = pool[i]
	end
	return result
end

local function register(config: CollectionConfig.Collection)
	local def = (QuestConfig.Quests :: any)[config.questId] :: QuestConfig.QuestDef?
	local counterDef = def and def.counters[config.counterId]
	assert(counterDef, string.format("[%s] counter %s.%s tidak ada di QuestConfig", TAG, config.questId, config.counterId))
	local target = counterDef.target

	if config.assignment == "DISTINCT" and #config.itemIds < target then
		Log.warn(TAG, string.format("%s: jenis item (%d) kurang dari target (%d)", config.id, #config.itemIds, target))
	end

	local pickups: { [Instance]: Pickup } = {}

	local function clear()
		local toRemove: { Instance } = {}
		for model in pickups do
			table.insert(toRemove, model)
		end
		table.clear(pickups)
		for _, model in toRemove do
			model:Destroy()
		end
	end

	local function spawnAll()
		clear()

		local container = findSpawnContainer(config.spawnFolder)
		if not container then
			Log.warn(TAG, string.format("dependency belum ada: Workspace.QuestObjects.%s", config.spawnFolder))
			return
		end

		local picked = RandomSpawnService.pickSpawns(container, target)
		local assigned = assignItems(config, #picked)
		local folder = RandomSpawnService.getRuntimeFolder()
		local summary: { string } = {}

		for i, spawn in picked do
			local itemId = assigned[i]
			local template = ItemService.getTemplate(itemId)
			if not template then
				Log.warn(TAG, "dependency belum ada: template " .. itemId)
			else
				local model = RandomSpawnService.createPickup(template, spawn, folder, {
					interactionId = config.interactionId,
					actionText = config.actionText,
					objectText = displayName(itemId),
					maxDistance = config.pickupDistance,
				})
				if model then
					pickups[model] = { status = "AVAILABLE", spawnName = spawn.Name, itemId = itemId }
					table.insert(summary, string.format("%s=%s", spawn.Name, itemId))
				end
			end
		end

		table.sort(summary)
		Log.info(
			TAG,
			string.format(
				"%s aktif (%d/%d titik): %s",
				config.id,
				#summary,
				#container:GetChildren(),
				table.concat(summary, ", ")
			)
		)
		if #summary < target then
			Log.warn(TAG, string.format("%s: hanya %d pickup ter-spawn, quest butuh %d", config.id, #summary, target))
		end
	end

	local function onInteract(player: Player, instance: Instance)
		local pickup = pickups[instance]
		if not pickup or pickup.status ~= "AVAILABLE" then
			return
		end
		if QuestService.getState(config.questId) ~= config.activeState then
			return
		end

		pickup.status = "COLLECTING"

		if not ItemService.give(player, pickup.itemId, 1) then
			pickup.status = "AVAILABLE"
			return
		end

		local progress = QuestService.addProgress(config.questId, config.counterId, 1)
		if progress == nil then
			-- Progres ditolak (state berubah): batalkan item agar tidak ada duplikat.
			ItemService.consume(player, pickup.itemId, 1)
			pickup.status = "AVAILABLE"
			return
		end

		pickup.status = "COLLECTED"
		pickups[instance] = nil
		instance:Destroy()
		Log.info(
			TAG,
			string.format("%s mengambil %s di %s (party %d/%d)", player.Name, pickup.itemId, pickup.spawnName, progress, target)
		)

		local name = displayName(pickup.itemId)
		NoticeService.notifyParty(
			player,
			string.format("Kamu mendapatkan %s (%d/%d).", name, progress, target),
			string.format("%s mendapatkan %s (%d/%d).", player.Name, name, progress, target)
		)
		if progress >= target and config.completeNotice then
			NoticeService.broadcast(config.completeNotice)
		end
	end

	InteractionService.register(config.interactionId, onInteract)
	QuestService.onStateChanged(function(questId: string, fromState: string, toState: string)
		if questId ~= config.questId then
			return
		end
		if toState == config.activeState then
			spawnAll()
		elseif fromState == config.activeState then
			clear()
		end
	end)
end

function CollectibleService.init()
	for _, config in CollectionConfig.Collections do
		register(config)
	end
	Log.info(TAG, string.format("siap, %d objective koleksi terdaftar", #CollectionConfig.Collections))
end

return table.freeze(CollectibleService)
