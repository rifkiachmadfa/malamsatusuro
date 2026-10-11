--!strict
-- FinalRitualService: ritual akhir (Phase 8, ADR-040). Server-authoritative; client hanya menampilkan.
--
-- Alur: KAFAN COMPLETE (3/3 pusaka tersimpan) -> Pemandu melapor (GameFlowService) -> game FINAL_RITUAL
--   -> GATHERING: semua pemain hidup + NORMAL harus berada di radius titik ritual selama START_HOLD_SECONDS
--   -> SEQUENCE: game ENDING, semua pemain CUTSCENE (dibekukan), cutscene/dialog dimainkan server per langkah
--   -> game GAME_COMPLETE, pemain dilepas.
-- Posisi pemain dihitung di server. Tidak ada remote client -> server di sistem ini (client tidak bisa memalsukan
-- "sudah berkumpul"). Item pusaka sudah divalidasi saat disimpan (RitualCollectionService, ADR-026).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("Config"):WaitForChild("GameConfig") :: ModuleScript)
local FinalRitualConfig = require(Shared:WaitForChild("Config"):WaitForChild("FinalRitualConfig") :: ModuleScript)
local RitualConfig = require(Shared:WaitForChild("Config"):WaitForChild("RitualConfig") :: ModuleScript)
local Log = require(Shared:WaitForChild("Util"):WaitForChild("Log") :: ModuleScript)
local Spatial = require(Shared:WaitForChild("Util"):WaitForChild("Spatial") :: ModuleScript)
local Remotes = require(Shared:WaitForChild("Remotes") :: ModuleScript)
local Services = script.Parent
local GameManager = require(Services:WaitForChild("GameManager") :: ModuleScript)
local KnockService = require(Services:WaitForChild("KnockService") :: ModuleScript)
local NoticeService = require(Services:WaitForChild("NoticeService") :: ModuleScript)
local PartyService = require(Services:WaitForChild("PartyService") :: ModuleScript)
local QuestService = require(Services:WaitForChild("QuestService") :: ModuleScript)

local TAG = "FinalRitualService"
local GameState = GameConfig.GameState
local PlayerState = GameConfig.PlayerState

type Phase = "IDLE" | "GATHERING" | "SEQUENCE" | "DONE"
type Saved = { walkSpeed: number, jumpPower: number, jumpHeight: number }

local FinalRitualService = {}

local phase: Phase = "IDLE"
local holdStartedAt: number? = nil
local updateRemote: RemoteEvent
local frozen: { [Player]: Saved } = {}
local warnedNoCenter = false

-- Fungsi pembaca agar pembandingan fase tidak dipersempit (narrowing) oleh pemeriksa tipe.
local function getPhase(): Phase
	return phase
end

-- ===== Syarat ritual =====

-- Semua persembahan (Keris, Kantil Hitam, Kain Kafan) sudah disimpan = quest-nya COMPLETE (ADR-026).
local function allOfferingsStored(): boolean
	for _, offering in RitualConfig.Offerings do
		if QuestService.getState(offering.questId) ~= "COMPLETE" then
			return false
		end
	end
	return true
end

-- ===== Berkumpul =====

local function resolveGatherCenter(): Vector3?
	local node: Instance? = Workspace
	for _, name in FinalRitualConfig.GATHER_OBJECT_PATH do
		node = node and node:FindFirstChild(name)
	end
	return node and Spatial.getPosition(node)
end

-- ready = pemain NORMAL yang berada di dalam radius; required = ukuran party (PartyService, minimal 1).
local function evaluate(): (number, number)
	local required = math.max(PartyService.getSize(), 1)
	local center = resolveGatherCenter()
	if not center then
		if not warnedNoCenter then
			warnedNoCenter = true
			Log.warn(TAG, "dependency belum ada: Workspace.QuestObjects.RitualCollection (titik kumpul ritual)")
		end
		return 0, required
	end

	local ready = 0
	for _, player in Players:GetPlayers() do
		if GameManager.getPlayerState(player) == PlayerState.NORMAL then
			local position = Spatial.getCharacterPosition(player)
			if position and (position - center).Magnitude <= FinalRitualConfig.GATHER_RADIUS then
				ready += 1
			end
		end
	end
	return ready, required
end

local function publish(ready: number?, required: number?, holding: boolean?)
	ReplicatedStorage:SetAttribute(FinalRitualConfig.ATTR_READY, ready)
	ReplicatedStorage:SetAttribute(FinalRitualConfig.ATTR_REQUIRED, required)
	ReplicatedStorage:SetAttribute(FinalRitualConfig.ATTR_HOLDING, holding)
end

-- ===== Pemain saat cutscene =====

local function freeze(player: Player)
	if not GameManager.setPlayerState(player, PlayerState.CUTSCENE) then
		return
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		frozen[player] = { walkSpeed = humanoid.WalkSpeed, jumpPower = humanoid.JumpPower, jumpHeight = humanoid.JumpHeight }
		humanoid.WalkSpeed = 0
		humanoid.JumpPower = 0
		humanoid.JumpHeight = 0
	end
end

local function release(player: Player)
	local saved = frozen[player]
	frozen[player] = nil
	if saved then
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.WalkSpeed = saved.walkSpeed
			humanoid.JumpPower = saved.jumpPower
			humanoid.JumpHeight = saved.jumpHeight
		end
	end
	if GameManager.getPlayerState(player) == PlayerState.CUTSCENE then
		GameManager.setPlayerState(player, PlayerState.NORMAL)
	end
end

-- ===== Urutan ritual + ending =====

local function playSequence()
	updateRemote:FireAllClients({ action = "Start" })
	task.wait(FinalRitualConfig.INTRO_SECONDS)

	for _, step in FinalRitualConfig.Sequence do
		updateRemote:FireAllClients({
			action = "Step",
			speaker = step.speaker,
			text = step.text,
			duration = step.duration,
			env = step.env,
		})
		task.wait(step.duration)
	end

	updateRemote:FireAllClients({
		action = "End",
		title = FinalRitualConfig.END_TITLE,
		subtitle = FinalRitualConfig.END_SUBTITLE,
		duration = FinalRitualConfig.END_CARD_SECONDS,
	})
	task.wait(FinalRitualConfig.END_CARD_SECONDS)
	updateRemote:FireAllClients({ action = "Close" })
end

local function runSequence()
	for _, player in Players:GetPlayers() do
		freeze(player)
	end

	-- Error di tengah cutscene tidak boleh membuat pemain terkunci selamanya.
	local ok, err = pcall(playSequence)
	if not ok then
		Log.warn(TAG, "cutscene error: " .. tostring(err))
		updateRemote:FireAllClients({ action = "Close" })
	end

	GameManager.transitionTo(GameState.GAME_COMPLETE)
	for _, player in Players:GetPlayers() do
		release(player)
	end
	phase = "DONE"
	Log.info(TAG, "ritual selesai; game GAME_COMPLETE")
end

-- Dipanggil HANYA dari tick() (tanpa yield sebelum phase berubah), jadi tidak bisa mulai ganda.
local function startSequence()
	if getPhase() ~= "GATHERING" or not allOfferingsStored() then
		return
	end
	if not GameManager.transitionTo(GameState.ENDING) then
		holdStartedAt = nil -- state game tidak mengizinkan; coba lagi di tick berikutnya
		return
	end
	phase = "SEQUENCE"
	holdStartedAt = nil
	publish(nil, nil, nil)
	Log.info(TAG, "semua berkumpul; ritual dimulai (game ENDING)")
	task.spawn(runSequence)
end

-- Satu pemeriksaan kesiapan. Dipanggil loop internal tiap CHECK_INTERVAL (publik agar bisa diuji).
function FinalRitualService.tick()
	if getPhase() ~= "GATHERING" then
		return
	end

	local ready, required = evaluate()
	if ready >= required then
		local startedAt = holdStartedAt
		if startedAt == nil then
			holdStartedAt = os.clock()
			NoticeService.broadcast("Semua sudah berkumpul. Tetap di tempat ritual...")
		elseif os.clock() - startedAt >= FinalRitualConfig.START_HOLD_SECONDS then
			startSequence()
			return
		end
	elseif holdStartedAt ~= nil then
		holdStartedAt = nil
		NoticeService.broadcast("Ada yang meninggalkan tempat ritual. Berkumpullah lagi.")
	end
	publish(ready, required, holdStartedAt ~= nil)
end

local function beginGathering()
	if getPhase() ~= "IDLE" then
		return
	end
	if not allOfferingsStored() then
		Log.warn(TAG, "FINAL_RITUAL ditolak: belum semua pusaka tersimpan")
		return
	end
	phase = "GATHERING"
	holdStartedAt = nil

	-- Pemain yang masih pingsan akan menghalangi syarat "semua berkumpul" (knock tidak dihitung siap).
	-- Fase ini tidak punya mekanik gagal, jadi pulihkan agar tidak soft-lock (lihat ADR-040).
	for _, player in Players:GetPlayers() do
		if KnockService.isKnocked(player) and KnockService.recover(player) then
			NoticeService.send(player, "Kekuatan ritual menyadarkanmu.")
		end
	end

	NoticeService.broadcast("Ketiga pusaka sudah lengkap. Berkumpullah di tempat ritual.")
	Log.info(TAG, "FINAL_RITUAL: menunggu pemain berkumpul")

	task.spawn(function()
		while getPhase() == "GATHERING" do
			task.wait(FinalRitualConfig.CHECK_INTERVAL)
			FinalRitualService.tick()
		end
	end)
end

function FinalRitualService.getPhase(): string
	return phase
end

function FinalRitualService.init()
	updateRemote = Remotes.get(Remotes.Names.CutsceneUpdate)

	GameManager.onStateChanged(function(_previous: string, newState: string)
		if newState == GameState.FINAL_RITUAL then
			beginGathering()
		end
	end)

	-- Pusaka ketiga tersimpan: arahkan pemain ke Pemandu (Pemandu melapor lalu membuka ritual akhir).
	QuestService.onStateChanged(function(questId: string, _fromState: string, toState: string)
		if toState == "COMPLETE" and allOfferingsStored() then
			NoticeService.broadcast("Ketiga pusaka sudah tersimpan. Temui Pemandu.")
			Log.info(TAG, "semua pusaka tersimpan (terakhir: " .. questId .. ")")
		end
	end)

	Players.PlayerRemoving:Connect(function(player: Player)
		frozen[player] = nil
	end)

	Log.info(TAG, "siap")
end

return table.freeze(FinalRitualService)
