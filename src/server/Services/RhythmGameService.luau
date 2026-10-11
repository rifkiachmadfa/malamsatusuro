--!strict
-- RhythmGameService: mesin minigame ritme 4 kolom (Guitar Hero) untuk gamelan (Phase 7, ADR-038).
-- Server-authoritative: server membuat chart acak, menentukan kapan sesi mulai/selesai, memvalidasi SETIAP tekanan,
-- menilai Miss secara real-time, menghitung skor, dan memutuskan lulus/gagal. Client hanya menampilkan dan MENGIRIM
-- tekanan { lane, t }. Satu sesi aktif untuk seluruh party; hanya SATU pemain yang bermain.
-- Hadiah/hukuman diputuskan callback pemanggil (onFinish / hooks.onFail).
--
-- Skor (ADR-039): MULAI START_SCORE (100), turun per Good/Miss. Skor < REQUIRED_SCORE kapan pun = GAGAL SEKETIKA:
-- client diminta menutup UI, sesi ditutup, hooks.onFail dipanggil (jumpscare oleh pemanggil).
-- Bertahan sampai durasi habis = lulus.
--
-- Alur: start() -> client memuat musik -> "Ready" (jam sesi server mulai) -> tekanan "Hit" (+ tick Miss server) ->
--       skor < batas: gagal | durasi habis: server menutup sesi, memanggil onFinish, mengirim hasil.
-- Batasan jujur: server tidak bisa memastikan tekanan berasal dari tangan manusia; yang dijamin: tidak ada skor
-- tanpa waktu nyata berjalan, tiap not hanya bisa dinilai sekali, tekanan dibatasi laju dan jumlah, dan hasil akhir
-- selalu dari server.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("Config"):WaitForChild("GameConfig") :: ModuleScript)
local GamelanConfig = require(Shared:WaitForChild("Config"):WaitForChild("GamelanConfig") :: ModuleScript)
local Log = require(Shared:WaitForChild("Util"):WaitForChild("Log") :: ModuleScript)
local Remotes = require(Shared:WaitForChild("Remotes") :: ModuleScript)
local GameManager = require(script.Parent:WaitForChild("GameManager") :: ModuleScript)

local TAG = "RhythmGameService"
local Config = GamelanConfig
local PlayerState = GameConfig.PlayerState
local PLAYER_STATE_ATTRIBUTE = "PlayerState"

export type Result = {
	score: number, -- 0-100
	perfect: number,
	good: number,
	miss: number,
	total: number, -- jumlah not
	passed: boolean,
}

-- Dipanggil saat sesi selesai NORMAL (bukan dibatalkan). Return true = hadiah berhasil diberikan.
export type FinishHandler = (player: Player, result: Result) -> boolean

-- Hook opsional dari pemanggil (semua dipanggil lewat pcall).
export type Hooks = {
	-- Skor jatuh di bawah batas. Dipanggil SETELAH sesi ditutup dan UI client diminta tutup. Boleh yield
	-- (dijalankan di thread terpisah), mis. memutar jumpscare.
	onFail: ((player: Player, result: Result) -> ())?,
	-- Musik pemain mulai (client mengirim Ready, jam sesi mulai).
	onPlaying: ((player: Player) -> ())?,
	-- Sesi berakhir dengan cara APA PUN (lulus, gagal, batal, keluar). Aman dipanggil tanpa onPlaying.
	onClosed: ((player: Player) -> ())?,
}

type Note = { time: number, lane: number, judged: boolean }

type Session = {
	id: number,
	notes: { Note },
	startedAt: number?, -- jam server saat client mengirim Ready
	onFinish: FinishHandler,
	hooks: Hooks,
	perfect: number,
	good: number,
	missed: number,
	score: number, -- mulai START_SCORE, hanya turun
	nextJudge: number, -- indeks not berikutnya yang dicek untuk Miss (not terurut waktu)
	hitCount: number,
	rejected: number,
	lastHitAt: number,
	savedWalkSpeed: number?,
	savedJumpPower: number?,
	savedJumpHeight: number?,
	connections: { RBXScriptConnection },
}

local RhythmGameService = {}

local sessions: { [Player]: Session } = {}
local activePlayer: Player? = nil
local nextId = 0
local updateRemote: RemoteEvent
local rng = Random.new()

-- ===== Chart =====

local function generateChart(): { Note }
	local notes: { Note } = {}
	local beat = 60 / Config.BPM
	local lastTime = Config.DURATION_SECONDS - Config.TAIL_SECONDS
	local lastLane = 0
	local index = 0
	while true do
		local t = Config.LEAD_IN_SECONDS + index * beat
		if t > lastTime then
			break
		end
		index += 1
		if rng:NextNumber() < Config.NOTE_CHANCE then
			local lane = rng:NextInteger(1, Config.LANE_COUNT)
			if lane == lastLane and rng:NextNumber() < Config.REPEAT_LANE_REJECT then
				local shift = rng:NextInteger(1, Config.LANE_COUNT - 1)
				lane = (lane - 1 + shift) % Config.LANE_COUNT + 1
			end
			lastLane = lane
			table.insert(notes, { time = math.floor(t * 1000 + 0.5) / 1000, lane = lane, judged = false })
		end
	end
	return notes
end

-- ===== Kunci gerak pemain selama bermain =====
-- Tombol Q/W/E/R dipakai sebagai kolom, jadi karakter dibekukan (WalkSpeed/Jump = 0) agar tidak berjalan.
-- Dipulihkan hanya jika masih beku oleh kita (tidak menimpa KnockService).

local function getHumanoid(player: Player): Humanoid?
	local character = player.Character
	return character and character:FindFirstChildOfClass("Humanoid")
end

local function lockMovement(player: Player, session: Session)
	local humanoid = getHumanoid(player)
	if not humanoid then
		return
	end
	session.savedWalkSpeed = humanoid.WalkSpeed
	session.savedJumpPower = humanoid.JumpPower
	session.savedJumpHeight = humanoid.JumpHeight
	humanoid.WalkSpeed = 0
	humanoid.JumpPower = 0
	humanoid.JumpHeight = 0
end

local function unlockMovement(player: Player, session: Session)
	local humanoid = getHumanoid(player)
	if not humanoid or humanoid.WalkSpeed ~= 0 then
		return
	end
	humanoid.WalkSpeed = session.savedWalkSpeed or 16
	humanoid.JumpPower = session.savedJumpPower or 50
	humanoid.JumpHeight = session.savedJumpHeight or 7.2
end

-- ===== Sesi =====

-- Akhiri sesi: lepas koneksi, pulihkan gerak dan state pemain, bebaskan slot.
local function closeSession(player: Player, notifyClient: boolean)
	local session = sessions[player]
	if not session then
		return
	end
	sessions[player] = nil
	if activePlayer == player then
		activePlayer = nil
	end
	for _, connection in session.connections do
		connection:Disconnect()
	end
	unlockMovement(player, session)
	if GameManager.getPlayerState(player) == PlayerState.MINIGAME then
		GameManager.setPlayerState(player, PlayerState.NORMAL)
	end
	if notifyClient then
		updateRemote:FireClient(player, { action = "Close" })
	end
	local onClosed = session.hooks.onClosed
	if onClosed then
		local ok, err = pcall(onClosed, player)
		if not ok then
			Log.warn(TAG, "onClosed error: " .. tostring(err))
		end
	end
end

local function computeResult(session: Session): Result
	return {
		score = session.score,
		perfect = session.perfect,
		good = session.good,
		miss = session.missed,
		total = #session.notes,
		passed = session.score >= Config.REQUIRED_SCORE,
	}
end

local function sendScore(player: Player, session: Session)
	updateRemote:FireClient(player, { action = "Score", score = session.score })
end

-- Skor jatuh di bawah batas: tutup sesi (client menutup UI + musik), lalu serahkan ke hooks.onFail.
local function failSession(player: Player, session: Session)
	if sessions[player] ~= session then
		return
	end
	local result = computeResult(session)
	Log.info(
		TAG,
		string.format(
			"%s GAGAL: skor %d < %d (perfect %d, good %d, miss %d dari %d not)",
			player.Name,
			result.score,
			Config.REQUIRED_SCORE,
			result.perfect,
			result.good,
			result.miss,
			result.total
		)
	)
	local onFail = session.hooks.onFail
	closeSession(player, true)
	if onFail then
		task.spawn(function()
			local ok, err = pcall(onFail, player, result)
			if not ok then
				Log.warn(TAG, "onFail error: " .. tostring(err))
			end
		end)
	end
end

-- Not yang sudah lewat jendela penilaian + kelonggaran latensi dan belum dinilai = Miss (diputuskan server).
-- `elapsed` = detik sejak Ready. Return true jika ada not yang menjadi Miss.
local function judgeExpired(session: Session, elapsed: number): boolean
	local changed = false
	while true do
		local note = session.notes[session.nextJudge]
		if note == nil or note.time + Config.GOOD_WINDOW + Config.MISS_GRACE >= elapsed then
			break
		end
		session.nextJudge += 1
		if not note.judged then
			note.judged = true
			session.missed += 1
			session.score = math.max(0, session.score - Config.MISS_PENALTY)
			changed = true
		end
	end
	return changed
end

-- Dipanggil tiap Heartbeat selama sesi berjalan: Miss real-time -> skor -> gagal bila di bawah batas.
local function onTick(player: Player, session: Session)
	local startedAt = session.startedAt
	if sessions[player] ~= session or startedAt == nil then
		return
	end
	if judgeExpired(session, os.clock() - startedAt) then
		sendScore(player, session)
		if session.score < Config.REQUIRED_SCORE then
			failSession(player, session)
		end
	end
end

-- Durasi habis: hitung skor di server, panggil onFinish, kirim hasil, tutup sesi.
local function finishSession(player: Player, session: Session)
	if sessions[player] ~= session then
		return
	end

	-- Pemain tidak lagi MINIGAME (mis. knock, mati) = sesi tidak sah, tanpa hasil/hadiah.
	if GameManager.getPlayerState(player) ~= PlayerState.MINIGAME then
		Log.info(TAG, string.format("sesi %s dibatalkan: state pemain berubah", player.Name))
		closeSession(player, true)
		return
	end

	-- Sapu not terakhir yang belum dinilai (tick mungkin belum menjangkau); bisa menggagalkan sesi.
	if judgeExpired(session, math.huge) and session.score < Config.REQUIRED_SCORE then
		failSession(player, session)
		return
	end

	local result = computeResult(session)
	local rewarded = false
	local ok, handlerResult = pcall(session.onFinish, player, result)
	if not ok then
		Log.warn(TAG, "onFinish error: " .. tostring(handlerResult))
	else
		rewarded = result.passed and handlerResult == true
	end

	updateRemote:FireClient(player, {
		action = "Result",
		score = result.score,
		perfect = result.perfect,
		good = result.good,
		miss = result.miss,
		total = result.total,
		passed = result.passed,
		rewarded = rewarded,
	})
	Log.info(
		TAG,
		string.format(
			"%s selesai: skor %d (perfect %d, good %d, miss %d dari %d) %s",
			player.Name,
			result.score,
			result.perfect,
			result.good,
			result.miss,
			result.total,
			if rewarded then "LULUS" elseif result.passed then "lulus tapi hadiah gagal" else "tidak lulus"
		)
	)
	closeSession(player, false)
end

function RhythmGameService.getActivePlayer(): Player?
	return activePlayer
end

-- Mulai sesi untuk pemain. Return false jika sesi lain berjalan atau state pemain tidak mengizinkan.
function RhythmGameService.start(player: Player, onFinish: FinishHandler, hooks: Hooks?): boolean
	if activePlayer ~= nil or sessions[player] ~= nil then
		return false
	end
	if not GameManager.setPlayerState(player, PlayerState.MINIGAME) then
		return false
	end

	nextId += 1
	local session: Session = {
		id = nextId,
		notes = generateChart(),
		startedAt = nil,
		onFinish = onFinish,
		hooks = hooks or {},
		perfect = 0,
		good = 0,
		missed = 0,
		score = Config.START_SCORE,
		nextJudge = 1,
		hitCount = 0,
		rejected = 0,
		lastHitAt = 0,
		connections = {},
	}
	sessions[player] = session
	activePlayer = player
	lockMovement(player, session)

	-- Batalkan sesi bila state pemain berubah (knock) atau karakter hilang (mati/respawn).
	table.insert(
		session.connections,
		player:GetAttributeChangedSignal(PLAYER_STATE_ATTRIBUTE):Connect(function()
			if sessions[player] == session and GameManager.getPlayerState(player) ~= PlayerState.MINIGAME then
				Log.info(TAG, string.format("sesi %s dibatalkan: state pemain berubah", player.Name))
				closeSession(player, true)
			end
		end)
	)
	table.insert(
		session.connections,
		player.CharacterRemoving:Connect(function()
			if sessions[player] == session then
				Log.info(TAG, string.format("sesi %s dibatalkan: karakter hilang", player.Name))
				closeSession(player, true)
			end
		end)
	)

	local payloadNotes: { { number } } = {}
	for i, note in session.notes do
		payloadNotes[i] = { note.time, note.lane }
	end
	updateRemote:FireClient(player, {
		action = "Start",
		notes = payloadNotes,
		duration = Config.DURATION_SECONDS,
		score = session.score,
	})

	-- Client harus mengirim Ready (musik siap) dalam READY_TIMEOUT.
	task.delay(Config.READY_TIMEOUT, function()
		if sessions[player] == session and session.startedAt == nil then
			Log.info(TAG, string.format("sesi %s dibatalkan: Ready tidak diterima", player.Name))
			closeSession(player, true)
		end
	end)

	Log.info(TAG, string.format("sesi dimulai untuk %s (%d not)", player.Name, #session.notes))
	return true
end

-- ===== Input dari client =====

local function onReady(player: Player, session: Session)
	if session.startedAt ~= nil then
		return -- Ready ganda diabaikan
	end
	session.startedAt = os.clock()
	task.delay(Config.DURATION_SECONDS + Config.END_GRACE, function()
		finishSession(player, session)
	end)
	-- Penilai Miss real-time (tidak bergantung pada tekanan pemain).
	table.insert(
		session.connections,
		RunService.Heartbeat:Connect(function()
			onTick(player, session)
		end)
	)
	local onPlaying = session.hooks.onPlaying
	if onPlaying then
		local ok, err = pcall(onPlaying, player)
		if not ok then
			Log.warn(TAG, "onPlaying error: " .. tostring(err))
		end
	end
end

local function isFiniteNumber(value: unknown): boolean
	return typeof(value) == "number" and value == value and math.abs(value :: number) < 1e6
end

local function onHit(player: Player, session: Session, payload: { [any]: any })
	local startedAt = session.startedAt
	if startedAt == nil then
		return -- belum Ready
	end

	local lane = payload.lane
	local t = payload.t
	if not isFiniteNumber(lane) or not isFiniteNumber(t) then
		session.rejected += 1
		return
	end
	local laneNumber = lane :: number
	local songTime = t :: number
	if laneNumber % 1 ~= 0 or laneNumber < 1 or laneNumber > Config.LANE_COUNT then
		session.rejected += 1
		return
	end

	local now = os.clock()
	if now - session.lastHitAt < Config.MIN_HIT_INTERVAL then
		return
	end
	session.lastHitAt = now

	session.hitCount += 1
	if session.hitCount > #session.notes * Config.MAX_HITS_FACTOR then
		return
	end

	-- Waktu lagu dari client harus cocok dengan jam server (tidak boleh "dari masa depan" atau jauh tertinggal).
	local elapsed = now - startedAt
	if
		songTime > elapsed + Config.SYNC_EARLY_TOLERANCE
		or songTime < elapsed - Config.SYNC_LATE_TOLERANCE
		or songTime > Config.DURATION_SECONDS + Config.GOOD_WINDOW
	then
		session.rejected += 1
		if session.rejected == 20 then
			Log.warn(TAG, string.format("%s: banyak tekanan ditolak (waktu tidak sinkron)", player.Name))
		end
		return
	end

	-- Not belum dinilai terdekat di kolom itu dalam jendela GOOD.
	local best: Note? = nil
	local bestDelta = math.huge
	for _, note in session.notes do
		if note.lane == laneNumber and not note.judged then
			local delta = math.abs(note.time - songTime)
			if delta <= Config.GOOD_WINDOW and delta < bestDelta then
				best = note
				bestDelta = delta
			end
		end
	end
	if not best then
		return -- tekanan tanpa not: tidak ada penalti
	end

	best.judged = true
	local penalty = Config.PERFECT_PENALTY
	if bestDelta <= Config.PERFECT_WINDOW then
		session.perfect += 1
	else
		session.good += 1
		penalty = Config.GOOD_PENALTY
	end
	if penalty > 0 then
		session.score = math.max(0, session.score - penalty)
		sendScore(player, session)
		if session.score < Config.REQUIRED_SCORE then
			failSession(player, session)
		end
	end
end

local function onAction(player: Player, raw: unknown)
	if typeof(raw) ~= "table" then
		return
	end
	local session = sessions[player]
	if not session then
		return
	end
	local payload = raw :: { [any]: any }
	local action = payload.action

	if action == "Ready" then
		onReady(player, session)
	elseif action == "Hit" then
		onHit(player, session, payload)
	elseif action == "Cancel" then
		Log.info(TAG, string.format("%s membatalkan sesi", player.Name))
		closeSession(player, true)
	end
end

function RhythmGameService.init()
	updateRemote = Remotes.get(Remotes.Names.GamelanUpdate)
	Remotes.get(Remotes.Names.GamelanAction).OnServerEvent:Connect(onAction)

	Players.PlayerRemoving:Connect(function(player: Player)
		closeSession(player, false)
	end)

	Log.info(TAG, "siap")
end

return table.freeze(RhythmGameService)
