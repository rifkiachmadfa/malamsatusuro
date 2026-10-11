--!strict
-- IntroCutsceneService: memutar cutscene kamera pembuka untuk tiap pemain yang masuk (ADR-041, TES awal).
-- Cutscene dibuat user dengan plugin Open Cutscene Editor. Tiap ModuleScript (ServerStorage/CutScenes/CutscenePlayerN)
-- punya `PlayCutscene(player)` yang menyalin LocalScript pemutar ke PlayerGui pemain itu; kamera dijalankan di client.
-- Server hanya memilih slot dan memicu. Objek cutscene = dependency Studio: bila hilang, hanya warn (tidak membuat pengganti).
-- BELUM ada: penguncian pemain selama cutscene dan sinyal "selesai" (plugin tidak memberi callback ke server).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Log = require(Shared:WaitForChild("Util"):WaitForChild("Log") :: ModuleScript)
local Config = require(script.Parent.Parent:WaitForChild("Config"):WaitForChild("IntroCutsceneConfig") :: ModuleScript)

local TAG = "IntroCutsceneService"

local IntroCutsceneService = {}

local slots: { [Player]: number } = {}

-- Slot terendah yang kosong (1..MAX_SLOT), atau nil bila penuh.
local function claimSlot(player: Player): number?
	local used: { [number]: boolean } = {}
	for _, slot in slots do
		used[slot] = true
	end
	for slot = 1, Config.MAX_SLOT do
		if not used[slot] then
			slots[player] = slot
			return slot
		end
	end
	return nil
end

local function findModule(slot: number): ModuleScript?
	local folder = ServerStorage:FindFirstChild(Config.FOLDER_NAME)
	local found = folder and folder:FindFirstChild(Config.MODULE_PREFIX .. tostring(slot))
	if found and found:IsA("ModuleScript") then
		return found
	end
	return nil
end

local function play(player: Player, slot: number)
	local moduleScript = findModule(slot)
	if not moduleScript then
		Log.warn(
			TAG,
			string.format(
				"dependency belum ada: ServerStorage.%s.%s%d (cutscene %s tidak diputar)",
				Config.FOLDER_NAME,
				Config.MODULE_PREFIX,
				slot,
				player.Name
			)
		)
		return
	end

	-- Tunggu karakter pertama; memutar sebelum spawn membuat kamera direset oleh Roblox.
	if not player.Character then
		player.CharacterAdded:Wait()
	end
	task.wait(Config.START_DELAY)
	if player.Parent ~= Players then
		return
	end

	local ok, result = pcall(require, moduleScript)
	if not ok or type(result) ~= "table" or type((result :: any).PlayCutscene) ~= "function" then
		Log.warn(TAG, string.format("%s tidak punya fungsi PlayCutscene: %s", moduleScript.Name, tostring(result)))
		return
	end

	local played, err = pcall((result :: any).PlayCutscene, player)
	if played then
		Log.info(TAG, string.format("cutscene %s diputar untuk %s (slot %d)", moduleScript.Name, player.Name, slot))
	else
		Log.warn(TAG, string.format("PlayCutscene %s gagal untuk %s: %s", moduleScript.Name, player.Name, tostring(err)))
	end
end

local function onPlayerAdded(player: Player)
	if slots[player] then
		return
	end
	local slot = claimSlot(player)
	if not slot then
		Log.warn(TAG, string.format("slot cutscene penuh (%d); %s tidak mendapat cutscene", Config.MAX_SLOT, player.Name))
		return
	end
	task.spawn(play, player, slot)
end

function IntroCutsceneService.init()
	if not Config.ENABLED then
		Log.info(TAG, "dimatikan (IntroCutsceneConfig.ENABLED = false)")
		return
	end

	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(function(player: Player)
		slots[player] = nil
	end)
	-- Pemain yang sudah ada saat service dimuat (Play Solo di Studio).
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end

	Log.info(TAG, "siap")
end

return table.freeze(IntroCutsceneService)
