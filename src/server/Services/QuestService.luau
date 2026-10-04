--!strict
-- QuestService: SATU-SATUNYA pemilik state quest (party-wide, server-authoritative).
-- Progres quest milik party, bukan milik pemain. Inventory pemain = Phase 3.
-- Direplikasi ke client sebagai satu Attribute JSON di ReplicatedStorage (read-only bagi client).

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("Config"):WaitForChild("GameConfig") :: ModuleScript)
local QuestConfig = require(Shared:WaitForChild("Config"):WaitForChild("QuestConfig") :: ModuleScript)
local Log = require(Shared:WaitForChild("Util"):WaitForChild("Log") :: ModuleScript)
local GameManager = require(script.Parent:WaitForChild("GameManager") :: ModuleScript)

local GameState = GameConfig.GameState
local LOCKED = QuestConfig.LOCKED
local ACTIVE = QuestConfig.ACTIVE
local COMPLETE = QuestConfig.COMPLETE
local TAG = "QuestService"

type Runtime = {
	state: string,
	counters: { [string]: number },
	playersDone: { [number]: boolean }, -- UserId; dipakai quest berbasis skor per pemain (Kafan)
}

type Listener = (questId: string, newState: string, oldState: string) -> ()

local QuestService = {}

local runtimes: { [string]: Runtime } = {}
local listeners: { Listener } = {}
local initialized = false

-- ---------------------------------------------------------------- helpers

local function indexOf(list: { string }, value: string): number?
	return table.find(list, value)
end

local function nextQuestId(questId: string): string?
	local index = table.find(QuestConfig.Order, questId)
	if not index then
		return nil
	end
	return QuestConfig.Order[index + 1]
end

local function validateConfig()
	for _, questId in QuestConfig.Order do
		local def = QuestConfig.Quests[questId]
		assert(def, "quest tidak ada di config: " .. questId)
		assert(def.states[1] == LOCKED and def.states[2] == ACTIVE, questId .. ": states harus diawali LOCKED, ACTIVE")
		assert(def.states[#def.states] == COMPLETE, questId .. ": states harus diakhiri COMPLETE")
		for from, to in def.resets do
			assert(indexOf(def.states, from) and indexOf(def.states, to), questId .. ": reset memakai state tidak dikenal")
		end
		for counterId, counter in def.counters do
			local whileIndex = indexOf(def.states, counter.whileState)
			local completeIndex = indexOf(def.states, counter.completeState)
			assert(whileIndex and completeIndex and completeIndex == whileIndex + 1, questId .. ": counter " .. counterId .. " tidak valid")
		end
		for _, objective in def.objectives do
			assert(indexOf(def.states, objective.doneWhen), questId .. ": objective " .. objective.id .. " memakai state tidak dikenal")
			if objective.counter then
				assert(def.counters[objective.counter], questId .. ": objective " .. objective.id .. " memakai counter tidak dikenal")
			end
		end
	end
end

-- ---------------------------------------------------------------- sinkronisasi

local function buildSnapshot(): { [string]: any }
	local quests = {}
	for _, questId in QuestConfig.Order do
		local def = QuestConfig.Quests[questId]
		local runtime = runtimes[questId]
		if runtime.state ~= LOCKED then
			local isDone = runtime.state == COMPLETE
			local objectives = {}
			if not isDone then
				local stateIndex = indexOf(def.states, runtime.state) :: number
				for _, objective in def.objectives do
					local objectiveDone = stateIndex >= (indexOf(def.states, objective.doneWhen) :: number)
					local entry: { [string]: any } = { label = objective.label, done = objectiveDone }
					if objective.counter then
						local counter = def.counters[objective.counter]
						entry.target = counter.target
						entry.current = if objectiveDone then counter.target else (runtime.counters[objective.counter] or 0)
					end
					table.insert(objectives, entry)
				end
			end
			table.insert(quests, { id = questId, title = def.title, done = isDone, objectives = objectives })
		end
	end
	return { quests = quests }
end

local function publish()
	ReplicatedStorage:SetAttribute(QuestConfig.ATTRIBUTE, HttpService:JSONEncode(buildSnapshot()))
end

-- ---------------------------------------------------------------- state

local function notify(questId: string, newState: string, oldState: string)
	for _, listener in listeners do
		task.spawn(listener, questId, newState, oldState)
	end
end

local setState -- forward declaration

-- Quest selesai: buka quest berikutnya (atau masuk FINAL_RITUAL setelah quest terakhir).
local function onQuestComplete(questId: string)
	local nextId = nextQuestId(questId)
	if nextId then
		local nextDef = QuestConfig.Quests[nextId]
		if GameManager.transitionTo(nextDef.gameState) then
			setState(nextId, ACTIVE)
		end
	else
		GameManager.transitionTo(GameState.FINAL_RITUAL)
	end
end

function setState(questId: string, newState: string)
	local runtime = runtimes[questId]
	local oldState = runtime.state
	runtime.state = newState
	publish()
	Log.info(TAG, string.format("quest %s: %s -> %s", questId, oldState, newState))
	notify(questId, newState, oldState)
	if newState == COMPLETE then
		onQuestComplete(questId)
	end
end

local function reject(message: string): boolean
	Log.warn(TAG, message)
	return false
end

-- ---------------------------------------------------------------- API publik

function QuestService.init()
	assert(not initialized, "QuestService.init sudah dipanggil")
	initialized = true

	validateConfig()
	for _, questId in QuestConfig.Order do
		runtimes[questId] = { state = LOCKED, counters = {}, playersDone = {} }
	end
	publish()
	Log.info(TAG, "siap")
end

function QuestService.getState(questId: string): string?
	local runtime = runtimes[questId]
	return if runtime then runtime.state else nil
end

-- Quest yang sedang berjalan (bukan LOCKED, bukan COMPLETE). nil jika tidak ada.
function QuestService.getActiveQuestId(): string?
	for _, questId in QuestConfig.Order do
		local state = runtimes[questId].state
		if state ~= LOCKED and state ~= COMPLETE then
			return questId
		end
	end
	return nil
end

function QuestService.getCounter(questId: string, counterId: string): number
	local runtime = runtimes[questId]
	return if runtime then (runtime.counters[counterId] or 0) else 0
end

-- Dipanggil setelah intro Pemandu selesai dibaca. Hanya berlaku di LOBBY.
function QuestService.startGame(): boolean
	if GameManager.getState() ~= GameState.LOBBY then
		Log.info(TAG, "startGame diabaikan: game sudah berjalan")
		return false
	end
	local firstId = QuestConfig.Order[1]
	if not GameManager.transitionTo(GameState.INTRO) then
		return false
	end
	if not GameManager.transitionTo(QuestConfig.Quests[firstId].gameState) then
		return false
	end
	setState(firstId, ACTIVE)
	return true
end

-- Maju ke state BERIKUTNYA. expectedFrom (opsional) mencegah dobel-eksekusi dari event yang telat.
function QuestService.advance(questId: string, toState: string, expectedFrom: string?): boolean
	local def = QuestConfig.Quests[questId]
	local runtime = runtimes[questId]
	if not def or not runtime then
		return reject("advance: quest tidak dikenal: " .. tostring(questId))
	end
	if expectedFrom ~= nil and runtime.state ~= expectedFrom then
		return reject(string.format("advance %s ditolak: state sekarang %s, diharapkan %s", questId, runtime.state, expectedFrom))
	end
	if runtime.state == LOCKED then
		return reject("advance ditolak: quest masih LOCKED: " .. questId)
	end
	if GameManager.getState() ~= def.gameState then
		return reject(string.format("advance %s ditolak: GameState %s", questId, GameManager.getState()))
	end

	local currentIndex = indexOf(def.states, runtime.state) :: number
	if def.states[currentIndex + 1] ~= toState then
		return reject(string.format("transisi quest ditolak (%s): %s -> %s", questId, runtime.state, toState))
	end

	setState(questId, toState)
	return true
end

-- Tambah progres counter party. Mengembalikan nilai baru, atau nil jika ditolak.
function QuestService.addProgress(questId: string, counterId: string, amount: number): number?
	local def = QuestConfig.Quests[questId]
	local runtime = runtimes[questId]
	local counter = def and def.counters[counterId]
	if not def or not runtime or not counter then
		reject(string.format("addProgress: counter tidak dikenal: %s/%s", tostring(questId), tostring(counterId)))
		return nil
	end
	if amount ~= math.floor(amount) or amount < 1 then
		reject("addProgress: amount tidak valid")
		return nil
	end
	if runtime.state ~= counter.whileState then
		reject(string.format("addProgress %s/%s ditolak: state %s", questId, counterId, runtime.state))
		return nil
	end

	local value = math.min(counter.target, (runtime.counters[counterId] or 0) + amount)
	runtime.counters[counterId] = value
	publish()
	Log.info(TAG, string.format("progres %s/%s: %d/%d", questId, counterId, value, counter.target))

	if value >= counter.target then
		QuestService.advance(questId, counter.completeState, counter.whileState)
	end
	return value
end

-- Transisi mundur yang didaftarkan di `resets` (contoh: party wipe Kantil). Counter quest dikosongkan.
function QuestService.reset(questId: string, toState: string): boolean
	local def = QuestConfig.Quests[questId]
	local runtime = runtimes[questId]
	if not def or not runtime then
		return reject("reset: quest tidak dikenal: " .. tostring(questId))
	end
	if def.resets[runtime.state] ~= toState then
		return reject(string.format("reset ditolak (%s): %s -> %s", questId, runtime.state, toState))
	end

	table.clear(runtime.counters)
	table.clear(runtime.playersDone)
	setState(questId, toState)
	return true
end

-- Daftar listener perubahan state untuk service lain (Phase 4+). Mengembalikan fungsi disconnect.
function QuestService.onStateChanged(listener: Listener): () -> ()
	table.insert(listeners, listener)
	return function()
		local index = table.find(listeners, listener)
		if index then
			table.remove(listeners, index)
		end
	end
end

-- Penanda per pemain (struktur untuk Kafan, Phase 7). Bukan state quest (ADR-020).
function QuestService.markPlayerDone(questId: string, player: Player)
	local runtime = runtimes[questId]
	if runtime then
		runtime.playersDone[player.UserId] = true
	end
end

function QuestService.isPlayerDone(questId: string, player: Player): boolean
	local runtime = runtimes[questId]
	return runtime ~= nil and runtime.playersDone[player.UserId] == true
end

-- true jika SEMUA pemain yang sedang ada sudah ditandai selesai (dan ada minimal 1 pemain).
function QuestService.areAllPlayersDone(questId: string): boolean
	local runtime = runtimes[questId]
	if not runtime then
		return false
	end
	local players = Players:GetPlayers()
	if #players == 0 then
		return false
	end
	for _, player in players do
		if not runtime.playersDone[player.UserId] then
			return false
		end
	end
	return true
end

return table.freeze(QuestService)