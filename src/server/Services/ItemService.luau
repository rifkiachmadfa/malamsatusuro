--!strict
-- ItemService: pembungkus tipis Player.Backpack (ADR-018). Tidak ada struktur inventory sendiri.
-- Item = Tool hasil clone dari ServerStorage.QuestTemplates, diberi Attribute ItemId oleh server.
-- Progres quest TIDAK dihitung dari sini (itu milik QuestService). Semua fungsi berjalan tanpa yield,
-- jadi give/consume atomik terhadap permintaan lain di server.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ItemConfig = require(Shared:WaitForChild("Config"):WaitForChild("ItemConfig") :: ModuleScript)
local Log = require(Shared:WaitForChild("Util"):WaitForChild("Log") :: ModuleScript)

local TAG = "ItemService"
local ATTR_ITEM_ID = ItemConfig.ATTR_ITEM_ID
local ATTR_COUNT = ItemConfig.ATTR_COUNT

local ItemService = {}

local function getDef(itemId: string): ItemConfig.ItemDef?
	return (ItemConfig.Items :: any)[itemId]
end

local function getTemplate(def: ItemConfig.ItemDef): Tool?
	local folder = ServerStorage:FindFirstChild(ItemConfig.TEMPLATE_FOLDER)
	if not folder then
		return nil
	end
	local template = folder:FindFirstChild(def.templateName)
	if template and template:IsA("Tool") then
		return template
	end
	return nil
end

local function validAmount(amount: number): boolean
	return amount == amount and amount >= 1 and amount % 1 == 0 and amount <= ItemConfig.MAX_STACK
end

-- Tool yang di-equip pindah ke Character, jadi Backpack DAN Character harus dicek.
local function collectTools(player: Player, itemId: string): { Tool }
	local found: { Tool } = {}
	local containers: { Instance } = {}

	local backpack = player:FindFirstChildOfClass("Backpack")
	if backpack then
		table.insert(containers, backpack)
	end
	if player.Character then
		table.insert(containers, player.Character)
	end

	for _, container in containers do
		for _, child in container:GetChildren() do
			if child:IsA("Tool") and child:GetAttribute(ATTR_ITEM_ID) == itemId then
				table.insert(found, child)
			end
		end
	end
	return found
end

local function toolCount(tool: Tool, def: ItemConfig.ItemDef): number
	if not def.stackable then
		return 1
	end
	local value = tool:GetAttribute(ATTR_COUNT)
	return if typeof(value) == "number" then value else 1
end

local function refreshTool(tool: Tool, def: ItemConfig.ItemDef)
	local label = def.displayName
	if def.stackable then
		local count = toolCount(tool, def)
		if count > 1 then
			label = string.format("%s x%d", def.displayName, count)
		end
	end
	tool.Name = label
	tool.ToolTip = label
end

local function newTool(template: Tool, itemId: string, def: ItemConfig.ItemDef, count: number): Tool
	local tool = template:Clone()
	tool.CanBeDropped = false
	tool:SetAttribute(ATTR_ITEM_ID, itemId)
	if def.stackable then
		tool:SetAttribute(ATTR_COUNT, count)
	end
	refreshTool(tool, def)
	return tool
end

-- Template Tool untuk sebuah item (dipakai sistem lain untuk visual pickup di dunia). nil jika belum ada.
function ItemService.getTemplate(itemId: string): Tool?
	local def = getDef(itemId)
	if not def then
		return nil
	end
	return getTemplate(def)
end

-- Dipanggil sekali saat boot: laporkan template yang belum dibuat (dependency, bukan error).
function ItemService.init()
	local missing: { string } = {}
	local total = 0
	for itemId, def in ItemConfig.Items :: { [string]: ItemConfig.ItemDef } do
		total += 1
		if not getTemplate(def) then
			table.insert(missing, itemId)
		end
	end

	if #missing == 0 then
		Log.info(TAG, string.format("siap, %d template item lengkap", total))
	else
		table.sort(missing)
		Log.warn(
			TAG,
			string.format(
				"siap, tapi %d/%d template belum ada di ServerStorage.%s: %s",
				#missing,
				total,
				ItemConfig.TEMPLATE_FOLDER,
				table.concat(missing, ", ")
			)
		)
	end
end

-- Jumlah item (Backpack + Character).
function ItemService.count(player: Player, itemId: string): number
	local def = getDef(itemId)
	if not def then
		return 0
	end
	local total = 0
	for _, tool in collectTools(player, itemId) do
		total += toolCount(tool, def)
	end
	return total
end

function ItemService.has(player: Player, itemId: string, amount: number?): boolean
	return ItemService.count(player, itemId) >= (amount or 1)
end

-- Beri item ke pemain. Return true jika berhasil. Ditolak jika: item/template tidak ada,
-- amount tidak valid, Backpack tidak ada, item unique sudah dimiliki, atau melewati MAX_STACK.
function ItemService.give(player: Player, itemId: string, amount: number?): boolean
	local qty = amount or 1
	local def = getDef(itemId)
	if not def then
		Log.warn(TAG, "item tidak dikenal: " .. tostring(itemId))
		return false
	end
	if not validAmount(qty) then
		Log.warn(TAG, string.format("amount tidak valid (%s): %s", itemId, tostring(qty)))
		return false
	end

	local template = getTemplate(def)
	if not template then
		Log.warn(TAG, string.format("template %s belum ada di ServerStorage.%s", def.templateName, ItemConfig.TEMPLATE_FOLDER))
		return false
	end

	local backpack = player:FindFirstChildOfClass("Backpack")
	if not backpack then
		Log.warn(TAG, string.format("%s tidak punya Backpack", player.Name))
		return false
	end

	local existing = collectTools(player, itemId)
	local owned = 0
	for _, tool in existing do
		owned += toolCount(tool, def)
	end

	if def.unique then
		if owned >= 1 or qty > 1 then
			Log.warn(TAG, string.format("item unique %s ditolak untuk %s (sudah punya/amount>1)", itemId, player.Name))
			return false
		end
	end

	if def.stackable then
		if owned + qty > ItemConfig.MAX_STACK then
			Log.warn(TAG, string.format("stack %s melewati batas untuk %s", itemId, player.Name))
			return false
		end
		if #existing > 0 then
			local tool = existing[1]
			tool:SetAttribute(ATTR_COUNT, toolCount(tool, def) + qty)
			refreshTool(tool, def)
		else
			newTool(template, itemId, def, qty).Parent = backpack
		end
	else
		for _ = 1, qty do
			newTool(template, itemId, def, 1).Parent = backpack
		end
	end

	Log.info(TAG, string.format("%s menerima %s x%d", player.Name, itemId, qty))
	return true
end

-- Ambil (hapus) item dari pemain. Semua atau tidak sama sekali: ditolak jika jumlahnya kurang.
function ItemService.consume(player: Player, itemId: string, amount: number?): boolean
	local qty = amount or 1
	local def = getDef(itemId)
	if not def or not validAmount(qty) then
		Log.warn(TAG, string.format("consume ditolak (%s, %s)", tostring(itemId), tostring(qty)))
		return false
	end

	local tools = collectTools(player, itemId)
	local owned = 0
	for _, tool in tools do
		owned += toolCount(tool, def)
	end
	if owned < qty then
		return false
	end

	local remaining = qty
	for _, tool in tools do
		if remaining <= 0 then
			break
		end
		local count = toolCount(tool, def)
		if count <= remaining then
			remaining -= count
			tool:Destroy()
		else
			tool:SetAttribute(ATTR_COUNT, count - remaining)
			refreshTool(tool, def)
			remaining = 0
		end
	end

	Log.info(TAG, string.format("%s kehilangan %s x%d", player.Name, itemId, qty))
	return true
end

return table.freeze(ItemService)
