--!strict
-- FailureService: kebijakan saat pemain GAGAL di quest (Phase 6, ADR-032). Satu pintu untuk semua penyebab
-- (bunga salah sekarang, serangan hantu nanti): `FailureService.fail(player, reason, questId)`.
--
--   Multiplayer -> KnockService.knock (rekan menyadarkan dengan Minyak Zaitun)
--   Solo        -> [jumpscare: Task 6.2] -> respawn -> quest di-reset ke awal -> mulai lagi lewat Pemandu
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
local KnockService = require(Services:WaitForChild("KnockService") :: ModuleScript)
local NoticeService = require(Services:WaitForChild("NoticeService") :: ModuleScript)
local PartyService = require(Services:WaitForChild("PartyService") :: ModuleScript)
local QuestService = require(Services:WaitForChild("QuestService") :: ModuleScript)

local TAG = "FailureService"
local PlayerState = GameConfig.PlayerState

local FailureService = {}

local soloBusy = false

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

-- Solo: pemain dikunci (CUTSCENE) selama urutan gagal, lalu respawn dan quest di-reset.
local function soloFail(player: Player, reason: string, questId: string)
	if soloBusy then
		return
	end
	if not GameManager.setPlayerState(player, PlayerState.CUTSCENE) then
		return
	end
	soloBusy = true
	Log.info(TAG, string.format("solo gagal (%s, quest %s): %s", reason, questId, player.Name))
	NoticeService.send(player, Config.SOLO_FAIL_NOTICE)

	-- Task 6.2: jumpscare dimainkan di sini; durasinya menggantikan SOLO_RESPAWN_DELAY.
	task.wait(Config.SOLO_RESPAWN_DELAY)

	if player.Parent == Players then
		clearQuestItems(player, questId)
		if not QuestService.reset(questId) then
			Log.warn(TAG, "reset quest ditolak: " .. questId)
		end
		player:LoadCharacter()
		GameManager.setPlayerState(player, PlayerState.NORMAL)
	end
	soloBusy = false
end

-- Pemain gagal di quest `questId` karena `reason` (lihat KnockConfig.Reason).
function FailureService.fail(player: Player, reason: string, questId: string)
	if player.Parent ~= Players then
		return
	end
	if PartyService.isSolo() then
		task.spawn(soloFail, player, reason, questId)
	else
		KnockService.knock(player, reason)
	end
end

function FailureService.init()
	Log.info(TAG, "siap")
end

return table.freeze(FailureService)
