--!strict
-- CutsceneService: memutar cutscene kamera plugin Open Cutscene Editor untuk sekelompok pemain (ADR-043).
-- Hasil ekstraksi dari CutsceneTestService (ADR-042, terbukti di Studio): CutsceneInfo semua modul digabung
-- menjadi satu pemutaran memakai LocalCutscenePlayer milik modul pertama.
--
-- Kontrak:
--   * `play` MENUNGGU (yield) sampai cutscene selesai (durasi dihitung dari `Time`, plugin tidak memberi sinyal selesai).
--   * `play` TIDAK mengubah state pemain. Pemanggil yang freeze/release (satu pemilik state).
--   * Tidak pernah melempar error; gagal = warn + return false (alur game tetap lanjut tanpa kamera).
--   * Server hanya memutuskan kapan dan untuk siapa; kamera berjalan di client.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Log = require(Shared:WaitForChild("Util"):WaitForChild("Log") :: ModuleScript)
local Config = require(script.Parent.Parent:WaitForChild("Config"):WaitForChild("CutsceneConfig") :: ModuleScript)

local TAG = "CutsceneService"

local CutsceneService = {}

-- Titik kamera "PositionN" pada satu CutsceneInfo, terurut menurut angka N.
local function sortedPositions(info: Instance): { Instance }
	local points: { Instance } = {}
	for _, child in info:GetChildren() do
		if string.match(child.Name, "^Position%d+$") then
			table.insert(points, child)
		end
	end
	table.sort(points, function(a: Instance, b: Instance): boolean
		return (tonumber(string.match(a.Name, "%d+")) or 0) < (tonumber(string.match(b.Name, "%d+")) or 0)
	end)
	return points
end

-- Gabungkan CutsceneInfo semua modul menjadi satu Folder (Position1..N berurutan). Mengembalikan folder + total `Time`.
local function buildMergedInfo(modules: { ModuleScript }): (Folder?, number)
	local merged = Instance.new("Folder")
	merged.Name = Config.INFO_NAME
	local index = 0
	local total = 0
	for sceneIndex, moduleScript in modules do
		local info = moduleScript:FindFirstChild(Config.INFO_NAME)
		if not info then
			Log.warn(TAG, string.format("%s tidak punya %s; penggabungan dibatalkan", moduleScript.Name, Config.INFO_NAME))
			merged:Destroy()
			return nil, 0
		end
		if sceneIndex == 1 then
			-- Anak non-Position (bila ada) dan atribut dipakai dari scene pertama saja.
			for _, child in info:GetChildren() do
				if not string.match(child.Name, "^Position%d+$") then
					child:Clone().Parent = merged
				end
			end
			for name, value in info:GetAttributes() do
				merged:SetAttribute(name, value)
			end
		end
		for pointIndex, point in sortedPositions(info) do
			local copy = point:Clone()
			index += 1
			copy.Name = "Position" .. tostring(index)
			local timeValue = copy:FindFirstChild(Config.TIME_VALUE_NAME)
			if timeValue and timeValue:IsA("NumberValue") then
				if sceneIndex > 1 and pointIndex == 1 and Config.SCENE_JOIN_TIME ~= nil then
					timeValue.Value = Config.SCENE_JOIN_TIME
				end
				if timeValue.Value > 0 then
					total += timeValue.Value
				end
			end
			copy.Parent = merged
		end
	end
	if index == 0 then
		merged:Destroy()
		return nil, 0
	end
	return merged, total
end

-- Tunggu semua clone hilang atau `limit` detik habis; lalu hancurkan clone yang tersisa.
local function waitForClones(clones: { Instance }, limit: number)
	local started = os.clock()
	while true do
		local remaining = limit - (os.clock() - started)
		if remaining <= 0 then
			break
		end
		local alive = false
		for _, clone in clones do
			if clone.Parent ~= nil then
				alive = true
				break
			end
		end
		if not alive then
			break
		end
		task.wait(math.min(0.25, remaining))
	end
	for _, clone in clones do
		if clone.Parent ~= nil then
			clone:Destroy()
		end
	end
end

local function collectModules(folder: Instance): { ModuleScript }
	local modules: { ModuleScript } = {}
	for _, name in Config.MODULE_NAMES do
		local found = folder:FindFirstChild(name)
		if found and found:IsA("ModuleScript") then
			table.insert(modules, found)
		else
			Log.warn(TAG, string.format("ServerStorage.%s.%s (ModuleScript) tidak ditemukan; dilewati", Config.FOLDER_NAME, name))
		end
	end
	return modules
end

-- Putar semua scene sebagai satu pemutaran untuk `participants`. Yield sampai selesai.
-- true bila cutscene dimulai untuk minimal satu pemain; false bila dilewati (nonaktif / dependency hilang / gagal).
function CutsceneService.play(participants: { Player }): boolean
	if not Config.ENABLED then
		Log.info(TAG, "dimatikan (CutsceneConfig.ENABLED = false); kamera dilewati")
		return false
	end

	local folder = ServerStorage:FindFirstChild(Config.FOLDER_NAME)
	if not folder then
		Log.warn(TAG, string.format("dependency belum ada: ServerStorage.%s; kamera dilewati", Config.FOLDER_NAME))
		return false
	end
	local modules = collectModules(folder)
	if #modules == 0 then
		return false
	end
	local template = modules[1]:FindFirstChild(Config.LOCAL_PLAYER_NAME)
	if not template or not template:IsA("LocalScript") then
		Log.warn(TAG, string.format("%s tidak punya LocalScript '%s'; kamera dilewati", modules[1].Name, Config.LOCAL_PLAYER_NAME))
		return false
	end
	local merged, total = buildMergedInfo(modules)
	if not merged or total <= 0 then
		if merged then
			merged:Destroy()
		end
		Log.warn(TAG, "CutsceneInfo kosong / total durasi 0; kamera dilewati")
		return false
	end

	-- Sama dengan PlayCutscene bawaan modul: info jadi anak LocalScript, parent ke PlayerGui, lalu Disabled = false.
	local clones: { Instance } = {}
	for _, player in participants do
		local gui = player:FindFirstChildOfClass("PlayerGui")
		if player.Parent == Players and gui then
			local ok, err = pcall(function()
				local localPlayer = template:Clone() :: LocalScript
				merged:Clone().Parent = localPlayer
				localPlayer.Parent = gui
				localPlayer.Disabled = false
				table.insert(clones, localPlayer)
			end)
			if not ok then
				Log.warn(TAG, string.format("gagal memulai kamera untuk %s: %s", player.Name, tostring(err)))
			end
		end
	end
	merged:Destroy()

	if #clones == 0 then
		Log.warn(TAG, "tidak ada pemain yang berhasil memulai kamera")
		return false
	end

	local duration = total + Config.DURATION_MARGIN
	Log.info(
		TAG,
		string.format("memutar %d scene sebagai satu pemutaran untuk %d pemain (%.2fs)", #modules, #clones, duration)
	)
	waitForClones(clones, duration)
	Log.info(TAG, "kamera selesai")
	return true
end

return table.freeze(CutsceneService)
