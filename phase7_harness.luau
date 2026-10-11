
local Enum = {KeyCode={Q="Q",W="W",E="E",R="R"}}
local Random = {new=function(seed) return {NextNumber=function() return math.random() end, NextInteger=function(_,a,b) return math.random(a,b) end} end}
math.randomseed(42)
local nowT = 1000
local function fakeNow() return nowT end
local tasks = {}
local task = {
  delay=function(secs, fn) table.insert(tasks,{t=nowT+secs, fn=fn}) end,
  spawn=function(fn,...) fn(...) end,
}
local function advance(dt)
  local target = nowT + dt
  while true do
    local idx, best = nil, nil
    for i,tk in ipairs(tasks) do if tk.t <= target and (not best or tk.t < best.t) then best=tk idx=i end end
    if not best then break end
    table.remove(tasks, idx)
    nowT = math.max(nowT, best.t)
    best.fn()
  end
  nowT = target
end
local Log = {info=function() end, warn=function(_,m) warns = (warns or 0)+1; lastWarn=m end}
local GameConfig = {PlayerState={NORMAL="NORMAL",KNOCKED="KNOCKED",REVIVING="REVIVING",MINIGAME="MINIGAME",CUTSCENE="CUTSCENE"},
  Interaction={ATTR_ID="a",ATTR_ACTION_TEXT="b",ATTR_OBJECT_TEXT="c",ATTR_MAX_DISTANCE="d",TAG="Interactable"}}

local function mkSignal()
  local s={handlers={}}
  function s:Connect(f) local c={f=f}; table.insert(self.handlers,c); return {Disconnect=function() c.f=nil end} end
  function s:Fire(...) for _,c in ipairs(self.handlers) do if c.f then c.f(...) end end end
  return s
end
local players = {}
local function mkPlayer(name)
  local p={Name=name,_attr={},_sig={},CharacterRemoving=mkSignal()}
  local hum={WalkSpeed=16,JumpPower=50,JumpHeight=7.2}
  p.Character={FindFirstChildOfClass=function() return hum end}
  p.hum=hum
  function p:GetAttributeChangedSignal(n) self._sig[n]=self._sig[n] or mkSignal(); return self._sig[n] end
  function p:SetAttribute(n,v) self._attr[n]=v; if self._sig[n] then self._sig[n]:Fire() end end
  table.insert(players,p)
  return p
end
local removing = mkSignal()
local Players={PlayerRemoving=removing, GetPlayers=function() return players end}

local GameManager do
  local st={}
  local allowed={NORMAL={KNOCKED=1,MINIGAME=1,CUTSCENE=1,REVIVING=1},MINIGAME={NORMAL=1,KNOCKED=1},KNOCKED={NORMAL=1,REVIVING=1}}
  GameManager={
    getPlayerState=function(p) return st[p] or "NORMAL" end,
    setPlayerState=function(p,n) local c=st[p] or "NORMAL"; if not (allowed[c] and allowed[c][n]) then return false end; st[p]=n; p:SetAttribute("PlayerState",n); return true end,
  }
end

local remotes={}
local function mkRemote(name)
  local r={name=name,sent={},OnServerEvent=mkSignal()}
  function r:FireClient(p,payload) table.insert(self.sent,{p=p,d=payload}) end
  return r
end
local Remotes={Names={GamelanUpdate="GamelanUpdate",GamelanAction="GamelanAction"},get=function(n) remotes[n]=remotes[n] or mkRemote(n); return remotes[n] end}
local function sendAction(p,payload) Remotes.get("GamelanAction").OnServerEvent:Fire(p,payload) end
local function lastUpdate(kind)
  local sent=Remotes.get("GamelanUpdate").sent
  for i=#sent,1,-1 do if sent[i].d.action==kind then return sent[i].d end end
end

local QuestConfig=(function() 
-- QuestConfig: definisi quest (data saja, tanpa logika game).
-- Dipakai server (QuestService) dan client (Quest UI). Lihat ADR-018/ADR-019.

export type CounterDef = {
	target: number, -- jumlah party-wide yang dibutuhkan
	requiredState: string, -- progres hanya diterima saat quest berada di state ini
	completeState: string, -- state tujuan otomatis saat target tercapai
}

export type ObjectiveDef = {
	text: string, -- teks tampilan (Indonesia); NOTE: redaksi sementara, samakan dengan GDD
	doneAt: string, -- objective selesai jika state quest sudah mencapai/melewati state ini
	counter: string?, -- jika ada, UI menampilkan "n/target" dari counter ini
}

export type QuestDef = {
	id: string,
	displayName: string,
	states: { string }, -- urutan state (dipakai UI untuk menentukan objective yang sudah selesai)
	objectives: { ObjectiveDef },
	initialState: string,
	transitions: { [string]: { string } },
	counters: { [string]: CounterDef },
	resetCountersOnEnter: { [string]: { string } }, -- state -> daftar counter yang di-reset saat masuk state itu
	-- Opsional: state "ulangi" di luar rantai linear. QuestService.reset() mengembalikan quest ke state ini
	-- (bukan LOCKED) dan Pemandu memulai ulang lewat dialog; Quest UI hanya menampilkan retryObjective.
	retryState: string?,
	retryObjective: string?,
}

local QuestConfig = {}

-- Urutan quest. Quest berikutnya hanya bisa aktif jika semua quest sebelumnya COMPLETE.
QuestConfig.ORDER = table.freeze({ "KERIS", "KANTIL", "KAFAN" })

QuestConfig.STATE_FOLDER = "QuestState" -- Folder di ReplicatedStorage; state direplikasi lewat Attribute

-- Nama Attribute yang direplikasi (satu tempat agar server dan client tidak berbeda).
function QuestConfig.stateAttribute(questId: string): string
	return questId .. "_State"
end

function QuestConfig.counterAttribute(questId: string, counterId: string): string
	return questId .. "_" .. counterId
end

-- Bangun transisi linear: states[i] -> states[i + 1].
local function chain(states: { string }): { [string]: { string } }
	local transitions: { [string]: { string } } = {}
	for i = 1, #states - 1 do
		transitions[states[i]] = { states[i + 1] }
	end
	transitions[states[#states]] = {}
	return transitions
end

-- QUEST 01 — KERIS PUSAKA
-- Memory puzzle gagal = tetap di CHEST_PUZZLE (coba lagi), bukan transisi.
local kerisStates = {
	"LOCKED",
	"ACTIVE",
	"SEARCHING_KELOR",
	"KELOR_COMPLETE",
	"KEY_OBTAINED",
	"CHEST_AVAILABLE",
	"CHEST_PUZZLE",
	"KERIS_OBTAINED",
	"KERIS_SUBMITTED",
	"COMPLETE",
}
local kerisTransitions = chain(kerisStates)

-- QUEST 02 — KEMBANG KANTIL HITAM
-- Gagal puzzle = knock/revive (state pemain, bukan state quest). Party wipe = CANTIL_PUZZLE -> SEARCHING_FLOWERS.
local kantilStates = {
	"LOCKED",
	"ACTIVE",
	"SEARCHING_FLOWERS",
	"FLOWERS_COMPLETE",
	"FLOWERS_PLACEMENT",
	"CANTIL_PUZZLE",
	"CANTIL_BLACK_OBTAINED",
	"CANTIL_SUBMITTED",
	"COMPLETE",
}
local kantilTransitions = chain(kantilStates)
kantilTransitions["CANTIL_PUZZLE"] = { "CANTIL_BLACK_OBTAINED", "SEARCHING_FLOWERS" }
-- Solo gagal (ADR-034): quest direset ke RETRY_GUIDE; bicara ke Pemandu -> ACTIVE (state di luar rantai linear).
kantilTransitions["RETRY_GUIDE"] = { "ACTIVE" }

-- QUEST 03 — KAIN KAFAN
-- REVISI user 2026-10-11 (ADR-038): hanya SATU pemain yang memainkan gamelan; skor >= 80 = quest lulus untuk seluruh party.
-- Gagal skor = tetap GAMELAN_ACTIVE (main lagi), bukan transisi.
local kafanStates = {
	"LOCKED",
	"ACTIVE",
	"FIND_GAMELAN",
	"GAMELAN_ACTIVE",
	"GAMELAN_COMPLETE",
	"KAIN_OBTAINED",
	"KAIN_SUBMITTED",
	"COMPLETE",
}
local kafanTransitions = chain(kafanStates)

QuestConfig.Quests = table.freeze({
	KERIS = {
		id = "KERIS",
		displayName = "Keris Pusaka",
		states = kerisStates,
		objectives = {
			{ text = "Kumpulkan Daun Kelor", doneAt = "KELOR_COMPLETE", counter = "Kelor" },
			{ text = "Dapatkan Kunci dari Pemandu", doneAt = "KEY_OBTAINED" },
			{ text = "Buka Peti", doneAt = "KERIS_OBTAINED" },
			{ text = "Simpan Keris di tempat ritual", doneAt = "KERIS_SUBMITTED" },
		},
		initialState = "LOCKED",
		transitions = kerisTransitions,
		counters = {
			Kelor = { target = 4, requiredState = "SEARCHING_KELOR", completeState = "KELOR_COMPLETE" },
		},
		resetCountersOnEnter = {},
	} :: QuestDef,
	KANTIL = {
		id = "KANTIL",
		displayName = "Kembang Kantil Hitam",
		states = kantilStates,
		objectives = {
			{ text = "Cari 4 Bunga", doneAt = "FLOWERS_COMPLETE", counter = "Flowers" },
			{ text = "Selesaikan teka-teki makam", doneAt = "CANTIL_BLACK_OBTAINED" },
			{ text = "Simpan Kembang Kantil Hitam di tempat ritual", doneAt = "CANTIL_SUBMITTED" },
		},
		initialState = "LOCKED",
		transitions = kantilTransitions,
		counters = {
			Flowers = { target = 4, requiredState = "SEARCHING_FLOWERS", completeState = "FLOWERS_COMPLETE" },
		},
		resetCountersOnEnter = {
			SEARCHING_FLOWERS = { "Flowers" }, -- party wipe mengulang pencarian bunga dari 0
		},
		retryState = "RETRY_GUIDE",
		retryObjective = "Kembali berbicara kepada Pemandu",
	} :: QuestDef,
	KAFAN = {
		id = "KAFAN",
		displayName = "Kain Kafan",
		states = kafanStates,
		objectives = {
			{ text = "Cari tempat gamelan", doneAt = "GAMELAN_ACTIVE" },
			{ text = "Mainkan gamelan (skor 80+)", doneAt = "GAMELAN_COMPLETE" },
			{ text = "Simpan Kain Kafan di tempat ritual", doneAt = "KAIN_SUBMITTED" },
		},
		initialState = "LOCKED",
		transitions = kafanTransitions,
		counters = {},
		resetCountersOnEnter = {},
	} :: QuestDef,
})

return QuestConfig
 end)()
local GamelanConfig=(function() 
-- GamelanConfig: aturan minigame ritme gamelan (quest Kain Kafan, Phase 7). Hanya data, tanpa logika.
-- SATU pemain memainkannya (keputusan user 2026-10-11, ADR-038). Gaya Guitar Hero: 4 kolom, not jatuh ke garis
-- tekan. PC: tombol Q W E R. Mobile: ketuk kolom. Server membuat chart, memvalidasi tiap tekanan, dan menghitung skor.

local GamelanConfig = {}

-- ===== Musik =====
-- PLACEHOLDER: isi dengan ID audio gamelan (format "rbxassetid://123456789"). Kosong = game tetap berjalan tanpa suara.
GamelanConfig.SOUND_ID = ""
GamelanConfig.SOUND_VOLUME = 0.8
-- Durasi sesi = durasi musik (1 menit 37 detik). Ubah di sini bila musik diganti.
GamelanConfig.DURATION_SECONDS = 97

-- ===== Kolom / input =====
GamelanConfig.LANE_COUNT = 4
GamelanConfig.LANE_LABELS = table.freeze({ "Q", "W", "E", "R" })
GamelanConfig.LANE_KEYCODES = table.freeze({ Enum.KeyCode.Q, Enum.KeyCode.W, Enum.KeyCode.E, Enum.KeyCode.R })

-- ===== Chart (dibuat server, acak per sesi) =====
-- Belum ada beatmap per lagu: not diletakkan di grid ketukan (BPM) dengan peluang NOTE_CHANCE per ketukan.
-- Setelah musik asli masuk: sesuaikan BPM dan LEAD_IN_SECONDS agar not terasa menyatu dengan musik.
GamelanConfig.BPM = 96
GamelanConfig.LEAD_IN_SECONDS = 3 -- not pertama muncul setelah jeda ini
GamelanConfig.TAIL_SECONDS = 4 -- tidak ada not di akhir musik
GamelanConfig.NOTE_CHANCE = 0.75
GamelanConfig.REPEAT_LANE_REJECT = 0.7 -- peluang menghindari kolom yang sama berturut-turut
GamelanConfig.APPROACH_SECONDS = 1.6 -- lama not jatuh dari atas ke garis tekan (tampilan)

-- ===== Penilaian =====
GamelanConfig.PERFECT_WINDOW = 0.10 -- detik, selisih tekan vs waktu not
GamelanConfig.GOOD_WINDOW = 0.20
GamelanConfig.PERFECT_POINTS = 10
GamelanConfig.GOOD_POINTS = 7
-- Skor akhir = persen dari poin maksimum (0-100). Lulus bila >= REQUIRED_SCORE.
GamelanConfig.REQUIRED_SCORE = 80

-- ===== Validasi server (anti-curang, ADR-038) =====
GamelanConfig.READY_TIMEOUT = 10 -- detik menunggu client selesai memuat musik
GamelanConfig.END_GRACE = 3 -- detik setelah durasi habis sebelum server menutup sesi
-- Waktu lagu yang dilaporkan client (t) harus sesuai jam server: elapsed - SYNC_LATE <= t <= elapsed + SYNC_EARLY.
GamelanConfig.SYNC_EARLY_TOLERANCE = 0.3
GamelanConfig.SYNC_LATE_TOLERANCE = 2.0 -- mencakup latensi/lag jaringan
GamelanConfig.MIN_HIT_INTERVAL = 0.03 -- detik, antar tekanan dari satu pemain
GamelanConfig.MAX_HITS_FACTOR = 4 -- batas total tekanan = jumlah not x faktor ini (cegah spam)

-- ===== Gamelan di dunia =====
GamelanConfig.INTERACTION_ID = "Gamelan"
GamelanConfig.OBJECT_NAME = "Gamelan" -- Workspace.QuestObjects.Gamelan
GamelanConfig.ACTION_TEXT = "Mainkan"
GamelanConfig.OBJECT_TEXT = "Gamelan"
GamelanConfig.MAX_DISTANCE = 12

return GamelanConfig
 end)()

-- QuestService stub memakai transisi nyata dari QuestConfig
local qstate={KAFAN="LOCKED"}
local listeners={}
local QuestService={
  getState=function(q) return qstate[q] end,
  transition=function(q,n)
    local allowed=QuestConfig.Quests[q].transitions[qstate[q]]
    if not allowed or not table.find(allowed,n) then return false end
    local from=qstate[q]; qstate[q]=n
    for _,l in ipairs(listeners) do l(q,from,n) end
    return true
  end,
  onStateChanged=function(f) table.insert(listeners,f) end,
}
local items={}
local templates={KainKafan=true}
local ItemService={
  getTemplate=function(id) return templates[id] and {} or nil end,
  give=function(p,id,n) if not templates[id] then return false end; items[p]=items[p] or {}; items[p][id]=(items[p][id] or 0)+n; return true end,
  consume=function(p,id,n) items[p][id]=items[p][id]-n; return true end,
  has=function(p,id) return items[p] and (items[p][id] or 0)>0 end,
}
local notices={}
local NoticeService={
  send=function(p,t) table.insert(notices,{p=p,t=t}) end,
  broadcast=function(t) table.insert(notices,{t=t}) end,
  notifyParty=function(p,a,b) table.insert(notices,{p=p,t=a,o=b}) end,
}
local handlers={}
local InteractionService={register=function(id,f) handlers[id]=f end}
local tags={}
local CollectionService={AddTag=function(_,i,t) tags[i]=true end,RemoveTag=function(_,i,t) tags[i]=nil end}
local gamelanObj={Name="Gamelan",SetAttribute=function() end}
local Workspace={FindFirstChild=function(self,n) if n=="QuestObjects" then return {FindFirstChild=function(_,m) return m=="Gamelan" and gamelanObj or nil end} end end}

local RhythmGameService=(function() -- RhythmGameService: mesin minigame ritme 4 kolom (Guitar Hero) untuk gamelan (Phase 7, ADR-038).
-- Server-authoritative: server membuat chart acak, menentukan kapan sesi mulai/selesai, memvalidasi SETIAP tekanan,
-- menghitung skor, dan memutuskan lulus/tidak. Client hanya menampilkan dan MENGIRIM tekanan { lane, t }.
-- Satu sesi aktif untuk seluruh party; hanya SATU pemain yang bermain. Hadiah diputuskan callback onFinish pemanggil.
--
-- Alur: start() -> client memuat musik -> "Ready" (jam sesi server mulai) -> tekanan "Hit" -> durasi habis ->
--       server menutup sesi, menghitung skor, memanggil onFinish, mengirim hasil.
-- Batasan jujur: server tidak bisa memastikan tekanan berasal dari tangan manusia; yang dijamin: tidak ada skor
-- tanpa waktu nyata berjalan, tiap not hanya bisa dinilai sekali, tekanan dibatasi laju dan jumlah, dan hasil akhir
-- selalu dari server.



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

type Note = { time: number, lane: number, judged: boolean }

type Session = {
	id: number,
	notes: { Note },
	startedAt: number?, -- jam server saat client mengirim Ready
	onFinish: FinishHandler,
	perfect: number,
	good: number,
	points: number,
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
end

local function computeResult(session: Session): Result
	local total = #session.notes
	local maxPoints = total * Config.PERFECT_POINTS
	local score = 0
	if maxPoints > 0 then
		score = math.floor(session.points / maxPoints * 100 + 0.5)
	end
	return {
		score = score,
		perfect = session.perfect,
		good = session.good,
		miss = total - session.perfect - session.good,
		total = total,
		passed = score >= Config.REQUIRED_SCORE,
	}
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
function RhythmGameService.start(player: Player, onFinish: FinishHandler): boolean
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
		perfect = 0,
		good = 0,
		points = 0,
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
	session.startedAt = fakeNow()
	task.delay(Config.DURATION_SECONDS + Config.END_GRACE, function()
		finishSession(player, session)
	end)
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

	local now = fakeNow()
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
	if bestDelta <= Config.PERFECT_WINDOW then
		session.perfect += 1
		session.points += Config.PERFECT_POINTS
	else
		session.good += 1
		session.points += Config.GOOD_POINTS
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

return RhythmGameService
 end)()
local KafanQuestService=(function() -- KafanQuestService: quest 03 Kain Kafan (Phase 7). Perekat antara objek Gamelan di dunia, RhythmGameService
-- (minigame), QuestService (state), dan ItemService (hadiah). Pola sama dengan KerisQuestService.
-- SATU pemain memainkan gamelan (ADR-038). Skor >= REQUIRED_SCORE -> Kain Kafan diberikan ke pemain itu ->
-- ia menyimpannya di RitualCollection (ADR-026, ditangani RitualCollectionService, bukan di sini).
-- Gagal skor = boleh main lagi (siapa pun di party), tanpa hukuman.



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

return KafanQuestService
 end)()

local fails,total=0,0
local function check(c,msg) total+=1; if c then print("  PASS "..msg) else fails+=1; print("  FAIL "..msg) end end
local Cfg=GamelanConfig
RhythmGameService.init()

local function newSession(p, onFinish)
  local called={n=0}
  local ok=RhythmGameService.start(p, function(pl,res) called.n+=1; called.res=res; return (onFinish and onFinish(pl,res)) or false end)
  return ok, called
end
local function ready(p) sendAction(p,{action="Ready"}) end
-- mainkan seluruh chart: mode(note)-> delta
local function playAll(p, notes, deltaFn, startAt)
  local t0=startAt
  for i,n in ipairs(notes) do
    local target=t0+n[1]+0.05
    if target>nowT then advance(target-nowT) end
    sendAction(p,{action="Hit",lane=n[2],t=n[1]+deltaFn(i)})
  end
end

print("== R1 chart")
local A=mkPlayer("A"); local B=mkPlayer("B")
local ok,called=newSession(A,function() return true end)
check(ok,"sesi A dimulai")
local start=lastUpdate("Start")
check(start and start.duration==97,"durasi 97 detik dikirim")
local notes=start.notes
check(#notes>=80 and #notes<=140,"jumlah not wajar: "..#notes)
local okChart=true
for i,n in ipairs(notes) do
  if n[1]<Cfg.LEAD_IN_SECONDS-0.001 or n[1]>Cfg.DURATION_SECONDS-Cfg.TAIL_SECONDS+0.001 or n[2]<1 or n[2]>4 or (i>1 and n[1]<=notes[i-1][1]) then okChart=false end
end
check(okChart,"semua not dalam rentang, kolom 1-4, urut waktu")
check(GameManager.getPlayerState(A)=="MINIGAME","state A = MINIGAME")
check(A.hum.WalkSpeed==0,"karakter dibekukan")

print("== R2 sesi lain ditolak (satu pemain)")
local okB=RhythmGameService.start(B,function() return true end)
check(okB==false,"B tidak bisa mulai saat A bermain")
check(RhythmGameService.getActivePlayer()==A,"active player = A")

print("== R3 tekanan sebelum Ready diabaikan")
sendAction(A,{action="Hit",lane=notes[1][2],t=notes[1][1]})
-- lanjut: Ready lalu main sempurna
ready(A); ready(A)
local T0=nowT
playAll(A,notes,function() return 0 end,T0)
advance(T0+Cfg.DURATION_SECONDS+Cfg.END_GRACE+1-nowT)
local res=lastUpdate("Result")
check(called.n==1,"onFinish dipanggil tepat sekali (Ready ganda aman)")
check(res and res.score==100 and res.passed and res.rewarded,"main sempurna: skor 100, lulus, hadiah")
check(GameManager.getPlayerState(A)=="NORMAL","state kembali NORMAL")
check(A.hum.WalkSpeed==16 and A.hum.JumpPower==50,"gerak dipulihkan")
check(RhythmGameService.getActivePlayer()==nil,"slot bebas")

print("== R4 hanya GOOD (selisih 0.15) = 70 -> gagal")
local ok2,c2=newSession(A,function() return true end)
local s2=lastUpdate("Start"); ready(A); local T1=nowT
playAll(A,s2.notes,function() return 0.15 end,T1)
advance(T1+100-(nowT-T1)+0)
local r2=lastUpdate("Result")
check(r2.score==70 and not r2.passed and not r2.rewarded,"skor 70, tidak lulus")
check(r2.good==#s2.notes and r2.perfect==0,"semua GOOD")

print("== R5 campuran 50/50 = 85 -> lulus")
newSession(A,function() return true end)
local s3=lastUpdate("Start"); ready(A); local T2=nowT
playAll(A,s3.notes,function(i) return (i%2==0) and 0.15 or 0.02 end,T2)
advance(110)
local r3=lastUpdate("Result")
local expected=math.floor(((r3.perfect*10+r3.good*7)/(r3.total*10))*100+0.5)
check(r3.score==expected and r3.score>=80 and r3.passed,"skor campuran "..r3.score.." dihitung benar & lulus")

print("== R6 tanpa tekanan = skor 0, semua miss")
newSession(A,function() return true end)
local s4=lastUpdate("Start"); ready(A); advance(110)
local r4=lastUpdate("Result")
check(r4.score==0 and r4.miss==#s4.notes and not r4.passed,"skor 0, miss semua")

print("== R7 anti-curang: waktu palsu")
newSession(A,function() return true end)
local s5=lastUpdate("Start"); ready(A); local T3=nowT
for _,n in ipairs(s5.notes) do sendAction(A,{action="Hit",lane=n[2],t=n[1]}); advance(0.04) end
-- semua dikirim dalam ~4 detik waktu server, padahal t menunjuk hingga 93 detik => ditolak kecuali not awal
advance(110)
local r5=lastUpdate("Result")
check(r5.score<10,"curang instan (kirim semua not sekaligus): skor "..r5.score.." (hampir 0)")

print("== R8 duplikat pada not yang sama")
newSession(A,function() return true end)
local s6=lastUpdate("Start"); ready(A); local T4=nowT
advance(s6.notes[1][1]+0.05)
for i=1,5 do sendAction(A,{action="Hit",lane=s6.notes[1][2],t=s6.notes[1][1]}); advance(0.05) end
advance(110)
local r6=lastUpdate("Result")
check(r6.perfect+r6.good==1,"5 tekanan pada 1 not hanya dihitung 1")

print("== R9 spam tekanan melebihi batas tidak error, tidak menaikkan skor")
newSession(A,function() return true end)
local s7=lastUpdate("Start"); ready(A)
for i=1,#s7.notes*6 do sendAction(A,{action="Hit",lane=1,t=0}); advance(0.04) end
advance(110)
local r7=lastUpdate("Result")
check(r7.score<=5,"spam: skor tetap rendah ("..r7.score..")")

print("== R10 payload tidak valid")
newSession(A,function() return true end)
ready(A)
local before=warns or 0
sendAction(A,{action="Hit",lane="x",t=1}); sendAction(A,{action="Hit",lane=0/0,t=1}); sendAction(A,{action="Hit",lane=9,t=1})
sendAction(A,{action="Hit",lane=1.5,t=1}); sendAction(A,{action="Hit",lane=1,t=math.huge}); sendAction(A,"bukan tabel"); sendAction(A,nil)
sendAction(A,{action="Apa"})
check(true,"tidak ada error pada payload aneh")
sendAction(A,{action="Cancel"})

print("== R11 Cancel: tanpa hasil, state pulih")
local ok3,c3=newSession(A,function() return true end)
ready(A); sendAction(A,{action="Cancel"})
check(c3.n==0,"onFinish tidak dipanggil")
check(GameManager.getPlayerState(A)=="NORMAL" and RhythmGameService.getActivePlayer()==nil,"state NORMAL & slot bebas")
check(lastUpdate("Close")~=nil,"client diberi Close")
advance(120)
check(c3.n==0,"timer lama tidak memanggil onFinish setelah cancel")

print("== R12 knock di tengah sesi")
local ok4,c4=newSession(A,function() return true end)
ready(A); advance(5)
GameManager.setPlayerState(A,"KNOCKED")
check(RhythmGameService.getActivePlayer()==nil,"sesi dibatalkan saat KNOCKED")
advance(120)
check(c4.n==0,"tidak ada hasil/hadiah setelah knock")
GameManager.setPlayerState(A,"NORMAL")

print("== R13 Ready tidak datang")
local ok5,c5=newSession(A,function() return true end)
advance(Cfg.READY_TIMEOUT+1)
check(RhythmGameService.getActivePlayer()==nil and c5.n==0,"timeout Ready menutup sesi")
check(A.hum.WalkSpeed==16,"gerak dipulihkan setelah timeout")

print("== R14 pemain keluar")
local ok6,c6=newSession(A,function() return true end)
ready(A); removing:Fire(A)
check(RhythmGameService.getActivePlayer()==nil,"slot bebas saat pemain keluar")
advance(120)
check(c6.n==0,"tidak ada onFinish setelah pemain keluar")

print("== R15 karakter hilang")
local ok7,c7=newSession(A,function() return true end)
ready(A); A.CharacterRemoving:Fire()
check(RhythmGameService.getActivePlayer()==nil and c7.n==0,"sesi ditutup saat karakter hilang")
advance(120)

print("== R16 pemain lain boleh main setelah A selesai")
local ok8=RhythmGameService.start(B,function() return false end)
check(ok8,"B bisa mulai setelah slot bebas")
RhythmGameService.start(A,function() return true end) -- ditolak
sendAction(B,{action="Cancel"})

------ KafanQuestService ------
print("== K1 interaksi gamelan mengikuti state quest")
KafanQuestService.init()
check(tags[gamelanObj]==nil,"LOCKED: gamelan tidak interaktif")
QuestService.transition("KAFAN","ACTIVE")
check(tags[gamelanObj]==nil,"ACTIVE: belum interaktif")
QuestService.transition("KAFAN","FIND_GAMELAN")
check(tags[gamelanObj]==true,"FIND_GAMELAN: gamelan interaktif")

print("== K2 template hilang -> tidak mulai")
templates.KainKafan=nil
handlers.Gamelan(A,gamelanObj)
check(qstate.KAFAN=="FIND_GAMELAN" and RhythmGameService.getActivePlayer()==nil,"tanpa template: state tetap, tidak ada sesi")
templates.KainKafan=true

print("== K3 interaksi pertama: FIND -> GAMELAN_ACTIVE + sesi")
handlers.Gamelan(A,gamelanObj)
check(qstate.KAFAN=="GAMELAN_ACTIVE","state GAMELAN_ACTIVE")
check(RhythmGameService.getActivePlayer()==A,"A bermain")
check(notices[#notices].t=="Kamu mulai memainkan gamelan.","notifikasi mulai (ADR-025)")

print("== K4 pemain lain: ditolak dengan notifikasi")
local nBefore=#notices
handlers.Gamelan(B,gamelanObj)
check(RhythmGameService.getActivePlayer()==A,"tetap A")
check(notices[#notices].t=="A sedang memainkan gamelan.","B diberi tahu A sedang bermain")
-- A gagal skor
ready(A); advance(110)
check(qstate.KAFAN=="GAMELAN_ACTIVE" and not (items[A] and items[A].KainKafan),"gagal skor: state tetap, tanpa item")
check(string.find(notices[#notices].t,"Skor 0")~=nil,"notifikasi skor gagal")

print("== K5 main lagi dan lulus (oleh B): item sekali, quest maju")
handlers.Gamelan(B,gamelanObj)
check(RhythmGameService.getActivePlayer()==B,"B mencoba lagi")
local sB=lastUpdate("Start"); ready(B); local TB=nowT
playAll(B,sB.notes,function() return 0 end,TB)
advance(110)
check(qstate.KAFAN=="KAIN_OBTAINED","state KAIN_OBTAINED")
check(items[B] and items[B].KainKafan==1,"B memegang tepat 1 Kain Kafan")
check(KafanQuestService.getKainHolder()==B,"pemegang tercatat")
check(tags[gamelanObj]==nil,"gamelan tidak interaktif lagi setelah lulus")
handlers.Gamelan(A,gamelanObj)
check(RhythmGameService.getActivePlayer()==nil,"tidak bisa main lagi setelah KAIN_OBTAINED (tidak ada duplikat kain)")

print("== K6 pemegang keluar -> kain pindah")
removing:Fire(B)
for i,p in ipairs(players) do if p==B then table.remove(players,i) break end end
check(items[A] and items[A].KainKafan==1,"kain dipindah ke A")
check(KafanQuestService.getKainHolder()==A,"pemegang baru A")

print("== K7 penyimpanan di ritual membersihkan pemegang")
QuestService.transition("KAFAN","KAIN_SUBMITTED")
check(KafanQuestService.getKainHolder()==nil,"pemegang direset saat disimpan")

print(string.format("%d/%d cek lulus", total-fails, total))
print(fails==0 and "SEMUA LULUS" or ("GAGAL: "..fails))
