--!strict
-- QuestService: pemilik state quest dan progres PARTY-WIDE (ADR-004, ADR-009, ADR-019).
-- Progres milik party, bukan pemain, dan TIDAK dihitung dari jumlah Tool di Backpack (ADR-018).
-- State direplikasi ke client lewat Attribute pada ReplicatedStorage.QuestState (read-only bagi client).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local QuestConfig = require(Shared:WaitForChild("Config"):WaitForChild("QuestConfig") :: ModuleScript)
local Log = require(Shared:WaitForChild("Util"):WaitForChild("Log") :: ModuleScript)

local TAG = "QuestService"

export type StateListener = (questId: string, fromState: string, toState: string) -> ()

local QuestService = {}

local questStates: { [string]: string } = {}
local counters: { [string]: { [string]: number } } = {}
local listeners: { StateListener } = {}
local stateFolder: Folder? = nil
local initialized = false

local function publishState(questId: string)
	if stateFolder then
		stateFolder:SetAttribute(QuestConfig.stateAttribute(questId), questStates[questId])
	end
end

local function publishCounter(questId: string, counterId: string)
	if stateFolder then
		stateFolder:SetAttribute(QuestConfig.counterAttribute(questId, counterId), counters[questId][counterId])
	end
end

local function getDef(questId: string): QuestConfig.QuestDef?
	return (QuestConfig.Quests :: any)[questId]
end

function QuestService.init()
	assert(not initialized, "QuestService.init sudah dipanggil")
	initialized = true

	local existing = ReplicatedStorage:FindFirstChild(QuestConfig.STATE_FOLDER)
	if existing and existing:IsA("Folder") then
		stateFolder = existing
	else
		local folder = Instance.new("Folder")
		folder.Name = QuestConfig.STATE_FOLDER
		folder.Parent = ReplicatedStorage
		stateFolder = folder
	end

	for _, questId in QuestConfig.ORDER do
		local def = getDef(questId)
		assert(def, "quest tidak ada di QuestConfig.Quests: " .. questId)
		questStates[questId] = def.initialState
		counters[questId] = {}
		for counterId in def.counters do
			counters[questId][counterId] = 0
			publishCounter(questId, counterId)
		end
		publishState(questId)
	end

	Log.info(TAG, string.format("siap, %d quest terdaftar (semua LOCKED)", #QuestConfig.ORDER))
end

-- Daftarkan callback yang dipanggil setelah state quest berubah (dijalankan lewat task.spawn,
-- sehingga error di listener tidak menggagalkan transisi).
function QuestService.onStateChanged(listener: StateListener)
	table.insert(listeners, listener)
end

function QuestService.getState(questId: string): string?
	return questStates[questId]
end

function QuestService.getCounter(questId: string, counterId: string): number?
	local questCounters = counters[questId]
	return questCounters and questCounters[counterId]
end

-- Pindah state quest. Hanya transisi yang tercantum di QuestConfig yang diterima.
-- Return true jika diterima, false jika ditolak.
function QuestService.transition(questId: string, newState: string): boolean
	local def = getDef(questId)
	local current = questStates[questId]
	if not def or not current then
		Log.warn(TAG, "quest tidak dikenal: " .. tostring(questId))
		return false
	end

	local allowed = def.transitions[current]
	if not allowed or table.find(allowed, newState) == nil then
		Log.warn(TAG, string.format("transisi ditolak (%s): %s -> %s", questId, current, newState))
		return false
	end

	questStates[questId] = newState

	local toReset = def.resetCountersOnEnter[newState]
	if toReset then
		for _, counterId in toReset do
			counters[questId][counterId] = 0
			publishCounter(questId, counterId)
		end
	end

	publishState(questId)
	Log.info(TAG, string.format("state quest (%s): %s -> %s", questId, current, newState))

	for _, listener in listeners do
		task.spawn(listener, questId, current, newState)
	end
	return true
end

-- Aktifkan quest: harus LOCKED, dan semua quest sebelumnya di urutan harus COMPLETE.
function QuestService.activate(questId: string): boolean
	if questStates[questId] ~= "LOCKED" then
		Log.warn(TAG, string.format("activate ditolak (%s): state %s", tostring(questId), tostring(questStates[questId])))
		return false
	end

	for _, previousId in QuestConfig.ORDER do
		if previousId == questId then
			break
		end
		if questStates[previousId] ~= "COMPLETE" then
			Log.warn(TAG, string.format("activate ditolak (%s): %s belum COMPLETE", questId, previousId))
			return false
		end
	end

	return QuestService.transition(questId, "ACTIVE")
end

-- Ulangi quest dari awal: kembali ke state awal (LOCKED), semua counter 0. Bukan transisi biasa; dipakai
-- kegagalan solo (FailureService, ADR-032). Quest COMPLETE atau yang sudah di state awal ditolak.
function QuestService.reset(questId: string): boolean
	local def = getDef(questId)
	local current = questStates[questId]
	if not def or not current then
		Log.warn(TAG, "quest tidak dikenal: " .. tostring(questId))
		return false
	end
	if current == def.initialState or current == "COMPLETE" then
		Log.warn(TAG, string.format("reset ditolak (%s): state %s", questId, current))
		return false
	end

	questStates[questId] = def.initialState
	for counterId in def.counters do
		counters[questId][counterId] = 0
		publishCounter(questId, counterId)
	end
	publishState(questId)
	Log.info(TAG, string.format("quest direset (%s): %s -> %s", questId, current, def.initialState))

	for _, listener in listeners do
		task.spawn(listener, questId, current, def.initialState)
	end
	return true
end

-- Tambah progres party. Hanya diterima saat quest berada di requiredState milik counter,
-- dan nilai dibatasi sampai target. Saat target tercapai, quest otomatis pindah ke completeState.
-- Return nilai counter terbaru, atau nil jika ditolak (state salah / counter tidak ada / amount tidak valid).
function QuestService.addProgress(questId: string, counterId: string, amount: number): number?
	local def = getDef(questId)
	if not def then
		Log.warn(TAG, "quest tidak dikenal: " .. tostring(questId))
		return nil
	end

	local counterDef = def.counters[counterId]
	if not counterDef then
		Log.warn(TAG, string.format("counter tidak ada (%s.%s)", questId, tostring(counterId)))
		return nil
	end

	if amount ~= amount or amount < 1 or amount % 1 ~= 0 then
		Log.warn(TAG, string.format("amount tidak valid (%s.%s): %s", questId, counterId, tostring(amount)))
		return nil
	end

	if questStates[questId] ~= counterDef.requiredState then
		Log.warn(
			TAG,
			string.format(
				"progres ditolak (%s.%s): state %s, butuh %s",
				questId,
				counterId,
				tostring(questStates[questId]),
				counterDef.requiredState
			)
		)
		return nil
	end

	local value = math.min(counterDef.target, counters[questId][counterId] + amount)
	counters[questId][counterId] = value
	publishCounter(questId, counterId)
	Log.info(TAG, string.format("progres (%s.%s): %d/%d", questId, counterId, value, counterDef.target))

	if value >= counterDef.target then
		QuestService.transition(questId, counterDef.completeState)
	end
	return value
end

return table.freeze(QuestService)
