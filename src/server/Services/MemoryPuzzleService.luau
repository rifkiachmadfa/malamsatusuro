--!strict
-- MemoryPuzzleService: sesi minigame ingat-dan-susun suku kata (server-authoritative).
-- Server membuat urutan acak, memantau waktu, memvalidasi jawaban, dan mengatur state pemain (MINIGAME).
-- Client hanya menampilkan dan MENGIRIM jawaban. Hasil akhir (hadiah) diputuskan callback onCorrect milik pemanggil.
-- Satu sesi aktif untuk seluruh party pada satu waktu.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("Config"):WaitForChild("GameConfig") :: ModuleScript)
local MemoryPuzzleConfig = require(Shared:WaitForChild("Config"):WaitForChild("MemoryPuzzleConfig") :: ModuleScript)
local Log = require(Shared:WaitForChild("Util"):WaitForChild("Log") :: ModuleScript)
local Remotes = require(Shared:WaitForChild("Remotes") :: ModuleScript)
local GameManager = require(script.Parent:WaitForChild("GameManager") :: ModuleScript)

local TAG = "MemoryPuzzleService"
local Config = MemoryPuzzleConfig
local PlayerState = GameConfig.PlayerState

export type CorrectHandler = (player: Player) -> boolean

type Attempt = {
	id: number,
	sequence: { string },
	startedAt: number,
	onCorrect: CorrectHandler,
}

local MemoryPuzzleService = {}

local attempts: { [Player]: Attempt } = {}
local lastAction: { [Player]: number } = {}
local activePlayer: Player? = nil
local nextId = 0
local updateRemote: RemoteEvent
local rng = Random.new()

local syllableSet: { [string]: boolean } = {}
for _, syllable in Config.SYLLABLES do
	syllableSet[syllable] = true
end

local function shuffled(source: { string }): { string }
	local list = table.clone(source)
	for i = #list, 2, -1 do
		local j = rng:NextInteger(1, i)
		list[i], list[j] = list[j], list[i]
	end
	return list
end

-- Akhiri sesi pemain: bersihkan state server, kembalikan state pemain ke NORMAL.
local function closeAttempt(player: Player, notifyClient: boolean)
	if attempts[player] == nil then
		return
	end
	attempts[player] = nil
	if activePlayer == player then
		activePlayer = nil
	end
	if GameManager.getPlayerState(player) == PlayerState.MINIGAME then
		GameManager.setPlayerState(player, PlayerState.NORMAL)
	end
	if notifyClient then
		updateRemote:FireClient(player, { action = "Close" })
	end
end

-- Jawaban valid = array tepat sebanyak SYLLABLES, tiap item string suku kata yang dikenal, tanpa duplikat.
local function parseAnswer(raw: unknown): { string }?
	if typeof(raw) ~= "table" then
		return nil
	end
	local answer = raw :: { [any]: any }

	local count = 0
	for _ in answer do
		count += 1
	end
	if count ~= #Config.SYLLABLES then
		return nil
	end

	local result: { string } = {}
	local seen: { [string]: boolean } = {}
	for i = 1, #Config.SYLLABLES do
		local value = answer[i]
		if typeof(value) ~= "string" or not syllableSet[value] or seen[value] then
			return nil
		end
		seen[value] = true
		result[i] = value
	end
	return result
end

function MemoryPuzzleService.getActivePlayer(): Player?
	return activePlayer
end

-- Mulai sesi untuk pemain. Return false jika sesi lain sedang berjalan atau state pemain tidak mengizinkan.
-- onCorrect dipanggil HANYA jika jawaban benar; return true = hadiah berhasil diberikan.
function MemoryPuzzleService.start(player: Player, onCorrect: CorrectHandler): boolean
	if activePlayer ~= nil or attempts[player] ~= nil then
		return false
	end
	if not GameManager.setPlayerState(player, PlayerState.MINIGAME) then
		return false
	end

	nextId += 1
	local attempt: Attempt = {
		id = nextId,
		sequence = shuffled(Config.SYLLABLES),
		startedAt = os.clock(),
		onCorrect = onCorrect,
	}
	attempts[player] = attempt
	activePlayer = player

	updateRemote:FireClient(player, {
		action = "Start",
		syllables = Config.SYLLABLES,
		sequence = attempt.sequence,
		memorizeSeconds = Config.MEMORIZE_SECONDS,
		answerSeconds = Config.ANSWER_SECONDS,
	})

	local id = attempt.id
	task.delay(Config.MEMORIZE_SECONDS + Config.ANSWER_SECONDS + Config.TIMEOUT_GRACE, function()
		local current = attempts[player]
		if current and current.id == id then
			Log.info(TAG, string.format("sesi %s kedaluwarsa", player.Name))
			closeAttempt(player, true)
		end
	end)

	Log.info(TAG, string.format("sesi dimulai untuk %s", player.Name))
	return true
end

local function onAction(player: Player, raw: unknown)
	if typeof(raw) ~= "table" then
		Log.warn(TAG, string.format("payload tidak valid dari %s", player.Name))
		return
	end
	local payload = raw :: { [any]: any }

	local attempt = attempts[player]
	if not attempt then
		return
	end

	local now = os.clock()
	local last = lastAction[player]
	if last and now - last < Config.ACTION_COOLDOWN then
		return
	end
	lastAction[player] = now

	local action = payload.action
	if action == "Cancel" then
		closeAttempt(player, true)
		return
	end
	if action ~= "Submit" then
		Log.warn(TAG, string.format("aksi tidak dikenal dari %s", player.Name))
		return
	end

	-- Jawaban tidak boleh masuk sebelum fase hafalan selesai (client tidak bisa melompati fase).
	if now < attempt.startedAt + Config.MEMORIZE_SECONDS - Config.MEMORIZE_TOLERANCE then
		Log.warn(TAG, string.format("Submit terlalu cepat dari %s", player.Name))
		return
	end

	local answer = parseAnswer(payload.answer)
	if not answer then
		Log.warn(TAG, string.format("format jawaban tidak valid dari %s", player.Name))
		return
	end

	local correct = true
	for i, syllable in attempt.sequence do
		if answer[i] ~= syllable then
			correct = false
			break
		end
	end

	local success = false
	if correct then
		local ok, result = pcall(attempt.onCorrect, player)
		if not ok then
			Log.warn(TAG, "onCorrect error: " .. tostring(result))
		end
		success = ok and result == true
	end

	updateRemote:FireClient(player, { action = "Result", success = success, correct = correct })
	closeAttempt(player, false)
	Log.info(TAG, string.format("%s menjawab: %s", player.Name, if success then "BENAR" elseif correct then "benar tapi hadiah gagal" else "salah"))
end

function MemoryPuzzleService.init()
	updateRemote = Remotes.get(Remotes.Names.MemoryPuzzleUpdate)
	Remotes.get(Remotes.Names.MemoryPuzzleAction).OnServerEvent:Connect(onAction)

	Players.PlayerRemoving:Connect(function(player: Player)
		closeAttempt(player, false)
		lastAction[player] = nil
	end)

	Log.info(TAG, "siap")
end

return table.freeze(MemoryPuzzleService)
