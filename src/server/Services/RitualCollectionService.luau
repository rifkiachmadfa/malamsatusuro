--!strict
-- RitualCollectionService: tempat menyimpan item quest akhir (Keris, Kembang Kantil Hitam, Kain Kafan).
-- Quest SELESAI saat item disimpan di sini (ADR-026). Pemandu hanya melaporkan, tidak menyelesaikan quest.
-- Satu objek (Workspace.QuestObjects.RitualCollection), satu prompt [E] Simpan; server menentukan item mana
-- yang disimpan dari state quest dan isi Backpack pemain. Daftar persembahan ada di RitualConfig.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("Config"):WaitForChild("GameConfig") :: ModuleScript)
local ItemConfig = require(Shared:WaitForChild("Config"):WaitForChild("ItemConfig") :: ModuleScript)
local RitualConfig = require(Shared:WaitForChild("Config"):WaitForChild("RitualConfig") :: ModuleScript)
local Log = require(Shared:WaitForChild("Util"):WaitForChild("Log") :: ModuleScript)
local Services = script.Parent
local InteractionService = require(Services:WaitForChild("InteractionService") :: ModuleScript)
local ItemService = require(Services:WaitForChild("ItemService") :: ModuleScript)
local NoticeService = require(Services:WaitForChild("NoticeService") :: ModuleScript)
local QuestService = require(Services:WaitForChild("QuestService") :: ModuleScript)

local TAG = "RitualCollectionService"

local RitualCollectionService = {}

local ritual: Instance? = nil

local function displayName(itemId: string): string
	local def = ItemConfig.Items[itemId]
	return if def then def.displayName else itemId
end

-- Quest yang sudah menyimpan persembahannya (state COMPLETE).
function RitualCollectionService.getStoredCount(): number
	local count = 0
	for _, offering in RitualConfig.Offerings do
		if QuestService.getState(offering.questId) == "COMPLETE" then
			count += 1
		end
	end
	return count
end

-- Prompt hanya muncul saat ada quest yang itemnya sudah didapat tetapi belum disimpan.
local function refreshInteractable()
	if not ritual then
		return
	end
	local awaiting = false
	for _, offering in RitualConfig.Offerings do
		if QuestService.getState(offering.questId) == offering.obtainedState then
			awaiting = true
			break
		end
	end
	if awaiting then
		CollectionService:AddTag(ritual, GameConfig.Interaction.TAG)
	else
		CollectionService:RemoveTag(ritual, GameConfig.Interaction.TAG)
	end
end

-- Simpan item: hapus dari Backpack -> SUBMITTED -> COMPLETE. Tanpa yield, jadi tidak bisa ganda.
local function store(player: Player, offering: RitualConfig.Offering): boolean
	if not ItemService.consume(player, offering.itemId, 1) then
		return false
	end
	if not QuestService.transition(offering.questId, offering.submittedState) then
		ItemService.give(player, offering.itemId, 1)
		return false
	end
	if not QuestService.transition(offering.questId, "COMPLETE") then
		Log.warn(TAG, string.format("quest %s gagal COMPLETE setelah item disimpan", offering.questId))
		return false
	end
	return true
end

local function onInteract(player: Player, target: Instance)
	if target ~= ritual then
		return
	end

	for _, offering in RitualConfig.Offerings do
		if
			QuestService.getState(offering.questId) == offering.obtainedState
			and ItemService.has(player, offering.itemId)
		then
			if store(player, offering) then
				local name = displayName(offering.itemId)
				local total = #RitualConfig.Offerings
				local stored = RitualCollectionService.getStoredCount()
				NoticeService.notifyParty(
					player,
					string.format("Kamu menyimpan %s di tempat ritual (%d/%d).", name, stored, total),
					string.format("%s menyimpan %s di tempat ritual (%d/%d).", player.Name, name, stored, total)
				)
				Log.info(
					TAG,
					string.format("%s menyimpan %s; quest %s COMPLETE", player.Name, offering.itemId, offering.questId)
				)
			end
			return
		end
	end

	NoticeService.send(player, "Kamu tidak membawa benda ritual untuk disimpan.")
end

function RitualCollectionService.init()
	local questObjects = Workspace:FindFirstChild("QuestObjects")
	ritual = questObjects and questObjects:FindFirstChild(RitualConfig.MODEL_NAME)

	if ritual then
		local Interaction = GameConfig.Interaction
		ritual:SetAttribute(Interaction.ATTR_ID, RitualConfig.INTERACTION_ID)
		ritual:SetAttribute(Interaction.ATTR_ACTION_TEXT, RitualConfig.ACTION_TEXT)
		ritual:SetAttribute(Interaction.ATTR_OBJECT_TEXT, RitualConfig.OBJECT_TEXT)
		ritual:SetAttribute(Interaction.ATTR_MAX_DISTANCE, RitualConfig.MAX_DISTANCE)
		refreshInteractable()
	else
		Log.warn(TAG, "dependency belum ada: Workspace.QuestObjects.RitualCollection")
	end

	InteractionService.register(RitualConfig.INTERACTION_ID, onInteract)
	QuestService.onStateChanged(function(_questId: string, _fromState: string, _toState: string)
		refreshInteractable()
	end)

	Log.info(TAG, "siap")
end

return table.freeze(RitualCollectionService)
