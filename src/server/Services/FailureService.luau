--!strict
-- FailureService: kebijakan saat pemain GAGAL di quest (Phase 6, ADR-032). Satu pintu untuk semua penyebab
-- (bunga salah sekarang, serangan hantu nanti): `FailureService.fail(player, reason, questId)`.
--
--   Semua        -> jumpscare di layar pemain yang gagal (JumpscareService, ADR-033)
--   Multiplayer  -> lalu KnockService.knock (rekan menyadarkan dengan Minyak Zaitun)
--   Solo         -> lalu respawn -> quest di-reset ke awal -> mulai lagi lewat Pemandu
--
-- Solo tidak boleh di-knock: tidak ada rekan yang bisa menyadarkan, pemain akan terjebak.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("Config"):WaitForChild("GameConfig") :: ModuleScript)
local Log = require(Shared:WaitForChild("Util"):WaitForChild("Log") :: ModuleScript)
local Config = require(script.Parent.Parent:WaitForChild("Config"):WaitForChild("FailureConfig") :: ModuleScript)
local Services = script.Parent
local GameManager = require(Services:WaitForChild("GameManager") :: ModuleScript)
local ItemService = require(Services:WaitForChild("ItemService") :: ModuleScript)
local JumpscareService = require(Services:WaitForChild("JumpscareService") :: ModuleScript)
local KnockService = require(Services:WaitForChild("KnockService") :: ModuleScript)
local NoticeService = require(Services:WaitForChild("NoticeService") :: ModuleScript)
local PartyService = require(Services:WaitForChild("PartyService") :: ModuleScript)
local QuestService = require(Services:WaitForChild("QuestService") :: ModuleScript)

local TAG = "FailureService"
local PlayerState = GameConfig.PlayerState

local FailureService = {}

local function clearQuestItems(player: Player, questId: string)
	local itemIds = Config.RESET_ITEMS[questId]
	if not itemIds then
		return
	end
	for _, itemId in itemIds do
		local owned = ItemService.count(player, itemId)
		if owned > 0 then
			ItemService.consume(player, itemId, owned)
		end
	end
end

-- Setelah jumpscare, SOLO: item quest dibersihkan, quest di-reset, respawn.
local function soloAftermath(player: Player, reason: string, questId: string)
	Log.info(TAG, string.format("solo gagal (%s, quest %s): %s", reason, questId, player.Name))
	clearQuestItems(player, questId)
	if not QuestService.reset(questId) then
		Log.warn(TAG, "reset quest ditolak: " .. questId)
	end
	player:LoadCharacter()
	GameManager.setPlayerState(player, PlayerState.NORMAL)
	NoticeService.send(player, Config.SOLO_FAIL_NOTICE)
end

-- Urutan gagal: kunci pemain (CUTSCENE) -> jumpscare di layarnya -> hukuman (solo/multiplayer).
-- Pemain berstatus bukan NORMAL (sedang gagal/knock/cutscene) diabaikan, jadi tidak bisa ganda.
local function failureSequence(player: Player, reason: string, questId: string)
	if not GameManager.setPlayerState(player, PlayerState.CUTSCENE) then
		return
	end

	local ghostId = Config.JumpscareByReason[reason] or Config.DEFAULT_JUMPSCARE
	JumpscareService.play(player, ghostId)

	if player.Parent ~= Players then
		return
	end

	-- Ukuran party dinilai SETELAH jumpscare (pemain lain bisa keluar selama jumpscare).
	if PartyService.isSolo() then
		soloAftermath(player, reason, questId)
	else
		GameManager.setPlayerState(player, PlayerState.NORMAL)
		KnockService.knock(player, reason)
	end
end

-- Pemain gagal di quest `questId` karena `reason` (lihat KnockConfig.Reason).
function FailureService.fail(player: Player, reason: string, questId: string)
	if player.Parent ~= Players then
		return
	end
	if GameManager.getPlayerState(player) ~= PlayerState.NORMAL then
		return
	end
	task.spawn(failureSequence, player, reason, questId)
end

function FailureService.init()
	Log.info(TAG, "siap")
end

return table.freeze(FailureService)
