--!strict
-- ReviveService: revive pemain KNOCK dengan Minyak Zaitun (Phase 6, Task 6.4, ADR-035).
--
-- Alur (semua keputusan di server; client hanya MEMINTA Start/Cancel dan menggambar progress bar):
--   penyelamat memegang (equip) Minyak Zaitun + dekat pemain KNOCK -> menahan [E] -> client kirim Start
--   -> server memvalidasi, membuat SESI, penyelamat jadi REVIVING -> server memvalidasi ulang tiap TICK_SECONDS
--   -> HOLD_SECONDS terlewat tanpa pembatalan -> consume 1 Minyak Zaitun + KnockService.recover(target).
--
-- Sesi dibatalkan jika: client Cancel (lepas tombol), penyelamat menjauh/mati/keluar/ganti tool/zaitun habis,
-- target pulih/keluar/tidak lagi KNOCK. Zaitun hanya berkurang SAAT berhasil (tidak ada yang hilang pada pembatalan).
-- Kunci: satu sesi per penyelamat dan satu sesi per target (dua penyelamat tidak bisa memakai dua zaitun pada
-- satu korban). Semua langkah penyelesaian tanpa yield sehingga tidak bisa dieksekusi ganda.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("Config"):WaitForChild("GameConfig") :: ModuleScript)
local ItemConfig = require(Shared:WaitForChild("Config"):WaitForChild("ItemConfig") :: ModuleScript)
local Config = require(Shared:WaitForChild("Config"):WaitForChild("ReviveConfig") :: ModuleScript)
local Log = require(Shared:WaitForChild("Util"):WaitForChild("Log") :: ModuleScript)
local Spatial = require(Shared:WaitForChild("Util"):WaitForChild("Spatial") :: ModuleScript)
local Remotes = require(Shared:WaitForChild("Remotes") :: ModuleScript)
local Services = script.Parent
local GameManager = require(Services:WaitForChild("GameManager") :: ModuleScript)
local ItemService = require(Services:WaitForChild("ItemService") :: ModuleScript)
local KnockService = require(Services:WaitForChild("KnockService") :: ModuleScript)
local NoticeService = require(Services:WaitForChild("NoticeService") :: ModuleScript)

local TAG = "ReviveService"
local PlayerState = GameConfig.PlayerState

type Session = {
	rescuer: Player,
	target: Player,
	startedAt: number,
	ended: boolean,
}

local ReviveService = {}

local sessions: { [Player]: Session } = {} -- penyelamat -> sesi
local targetLocks: { [Player]: Session } = {} -- target -> sesi (satu penyelamat per korban)
local lastStart: { [Player]: number } = {}
local updateRemote: RemoteEvent

local function itemName(): string
	local def = ItemConfig.Items[Config.ITEM_ID]
	return if def then def.displayName else Config.ITEM_ID
end

-- Tool yang sedang dipegang (equip) penyelamat adalah Minyak Zaitun, dan jumlahnya memang >= 1.
local function holdsPotion(player: Player): boolean
	local character = player.Character
	if not character then
		return false
	end
	local tool = character:FindFirstChildOfClass("Tool")
	if not tool or tool:GetAttribute(ItemConfig.ATTR_ITEM_ID) ~= Config.ITEM_ID then
		return false
	end
	return ItemService.has(player, Config.ITEM_ID, 1)
end

-- Alasan sesi tidak valid (string, teks notifikasi untuk penyelamat; "" = batal diam-diam), atau nil bila valid.
local function invalidReason(session: Session, allowedExtra: number): string?
	local rescuer, target = session.rescuer, session.target
	if rescuer.Parent ~= Players or target.Parent ~= Players then
		return ""
	end
	if GameManager.getPlayerState(rescuer) ~= PlayerState.REVIVING then
		return ""
	end
	if not KnockService.isKnocked(target) then
		return "" -- sudah pulih (mis. direvive lewat jalur lain); tidak perlu notifikasi tambahan
	end
	if not holdsPotion(rescuer) then
		return string.format("Revive batal: pegang %s di tangan.", itemName())
	end
	local rescuerPos = Spatial.getCharacterPosition(rescuer)
	local targetPos = Spatial.getCharacterPosition(target)
	if not rescuerPos or not targetPos then
		return ""
	end
	if (rescuerPos - targetPos).Magnitude > Config.MAX_DISTANCE + allowedExtra then
		return string.format("Revive batal: kamu terlalu jauh dari %s.", target.Name)
	end
	return nil
end

local function endSession(session: Session, success: boolean, notice: string?)
	if session.ended then
		return
	end
	session.ended = true
	if sessions[session.rescuer] == session then
		sessions[session.rescuer] = nil
	end
	if targetLocks[session.target] == session then
		targetLocks[session.target] = nil
	end

	local rescuer = session.rescuer
	if rescuer.Parent == Players then
		-- REVIVING -> NORMAL (jika penyelamat sudah berpindah state lain, biarkan state itu).
		if GameManager.getPlayerState(rescuer) == PlayerState.REVIVING then
			GameManager.setPlayerState(rescuer, PlayerState.NORMAL)
		end
		updateRemote:FireClient(rescuer, { action = "Stop", success = success })
		if notice and notice ~= "" then
			NoticeService.send(rescuer, notice)
		end
	end
end

local function complete(session: Session)
	local rescuer, target = session.rescuer, session.target

	-- Validasi terakhir tanpa yield: consume -> recover. Gagal di tengah = kembalikan item.
	if not ItemService.consume(rescuer, Config.ITEM_ID, 1) then
		endSession(session, false, string.format("Revive batal: %s tidak tersedia.", itemName()))
		return
	end
	-- Penyelamat harus kembali NORMAL dulu agar state akhir konsisten; endSession mengurusnya setelah recover.
	if not KnockService.recover(target) then
		ItemService.give(rescuer, Config.ITEM_ID, 1)
		endSession(session, false, nil)
		return
	end

	local left = ItemService.count(rescuer, Config.ITEM_ID)
	Log.info(TAG, string.format("%s menyadarkan %s (sisa zaitun penyelamat: %d)", rescuer.Name, target.Name, left))
	endSession(session, true, string.format("Kamu menyadarkan %s. Sisa %s: %d.", target.Name, itemName(), left))
end

local function runSession(session: Session)
	while not session.ended do
		task.wait(Config.TICK_SECONDS)
		if session.ended then
			return
		end
		local reason = invalidReason(session, Config.DISTANCE_TOLERANCE)
		if reason ~= nil then
			Log.info(TAG, string.format("sesi %s -> %s dibatalkan%s", session.rescuer.Name, session.target.Name, if reason ~= "" then ": " .. reason else ""))
			endSession(session, false, reason)
			return
		end
		if os.clock() - session.startedAt >= Config.HOLD_SECONDS then
			complete(session)
			return
		end
	end
end

local function reject(player: Player, why: string, notice: string?)
	Log.warn(TAG, string.format("start %s ditolak: %s", player.Name, why))
	if notice then
		NoticeService.send(player, notice)
	end
end

local function onStart(player: Player, rawTarget: unknown)
	-- Cooldown per pemain (anti-spam), dicek paling awal.
	local now = os.clock()
	local last = lastStart[player]
	if last and now - last < Config.REQUEST_COOLDOWN then
		return
	end
	lastStart[player] = now

	if sessions[player] then
		return -- sudah ada sesi
	end
	if typeof(rawTarget) ~= "Instance" or not (rawTarget :: Instance):IsA("Player") then
		reject(player, "target bukan Player", nil)
		return
	end
	local target = rawTarget :: Player

	if target == player or target.Parent ~= Players then
		reject(player, "target tidak valid", nil)
		return
	end
	if GameManager.getPlayerState(player) ~= PlayerState.NORMAL then
		return -- knock/dialog/minigame/cutscene tidak bisa menyadarkan
	end
	if not KnockService.isKnocked(target) then
		reject(player, target.Name .. " tidak sedang knock", nil)
		return
	end
	if targetLocks[target] then
		reject(player, target.Name .. " sedang disadarkan", string.format("%s sedang disadarkan rekan lain.", target.Name))
		return
	end
	if not holdsPotion(player) then
		reject(player, "tidak memegang zaitun", string.format("Pegang %s di tangan untuk menyadarkan %s.", itemName(), target.Name))
		return
	end

	local session: Session = { rescuer = player, target = target, startedAt = os.clock(), ended = false }

	-- Penyelamat jadi REVIVING dulu (memblokir interaksi lain), lalu validasi penuh; gagal = kembali NORMAL.
	if not GameManager.setPlayerState(player, PlayerState.REVIVING) then
		return
	end
	local reason = invalidReason(session, Config.DISTANCE_TOLERANCE)
	if reason ~= nil then
		GameManager.setPlayerState(player, PlayerState.NORMAL)
		reject(player, "validasi awal gagal: " .. reason, if reason ~= "" then reason else nil)
		return
	end

	sessions[player] = session
	targetLocks[target] = session
	Log.info(TAG, string.format("%s mulai menyadarkan %s", player.Name, target.Name))
	updateRemote:FireClient(player, { action = "Start", targetName = target.Name, duration = Config.HOLD_SECONDS })
	task.spawn(function()
		local ok, err = pcall(runSession, session)
		if not ok then
			-- Jangan biarkan penyelamat tersangkut di REVIVING jika terjadi error tak terduga.
			Log.warn(TAG, "sesi error: " .. tostring(err))
			endSession(session, false, nil)
		end
	end)
end

local function onCancel(player: Player)
	local session = sessions[player]
	if session then
		Log.info(TAG, string.format("%s melepas tombol: sesi dibatalkan", player.Name))
		endSession(session, false, nil)
	end
end

local function onRequest(player: Player, payload: unknown)
	if typeof(payload) ~= "table" then
		return
	end
	local data = payload :: { [any]: any }
	local action = data.action
	if action == "Start" then
		onStart(player, data.target)
	elseif action == "Cancel" then
		onCancel(player)
	end
end

local function onPlayerRemoving(player: Player)
	lastStart[player] = nil
	local asRescuer = sessions[player]
	if asRescuer then
		endSession(asRescuer, false, nil)
	end
	local asTarget = targetLocks[player]
	if asTarget then
		endSession(asTarget, false, nil)
	end
end

function ReviveService.init()
	updateRemote = Remotes.get(Remotes.Names.ReviveUpdate)
	Remotes.get(Remotes.Names.ReviveRequest).OnServerEvent:Connect(onRequest)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	Log.info(TAG, string.format("siap (tahan %ds, jarak %d studs)", Config.HOLD_SECONDS, Config.MAX_DISTANCE))
end

return table.freeze(ReviveService)
