--!strict
-- CutsceneTestService: trigger TES cutscene (Phase 8, ADR-042). BUKAN bagian alur gameplay final.
-- ProximityPrompt di Workspace.triggerCutscene memutar semua modul di ServerStorage/CutScenes BERURUTAN
-- (CutscenePlayer1 -> 4) untuk SEMUA pemain yang ada saat prompt ditekan. Tidak mengubah state game maupun quest.
-- Terpisah dari IntroCutsceneService (ADR-041, cutscene saat join per slot) dan FinalRitualService (ADR-040, ending).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("Config"):WaitForChild("GameConfig") :: ModuleScript)
local Log = require(Shared:WaitForChild("Util"):WaitForChild("Log") :: ModuleScript)
local GameManager = require(script.Parent:WaitForChild("GameManager") :: ModuleScript)
local Config = require(script.Parent.Parent:WaitForChild("Config"):WaitForChild("CutsceneTestConfig") :: ModuleScript)

local TAG = "CutsceneTestService"
local PlayerState = GameConfig.PlayerState

local CutsceneTestService = {}

local running = false

local function findTrigger(): Instance?
	local deadline = os.clock() + Config.FIND_TIMEOUT
	repeat
		local found = Workspace:FindFirstChild(Config.TRIGGER_NAME, true)
		if found then
			return found
		end
		task.wait(0.5)
	until os.clock() >= deadline
	return nil
end

-- ProximityPrompt harus berada di BasePart (atau Attachment).
local function resolveAnchor(trigger: Instance): BasePart?
	if trigger:IsA("BasePart") then
		return trigger
	end
	if trigger:IsA("Model") then
		return trigger.PrimaryPart or trigger:FindFirstChildWhichIsA("BasePart", true)
	end
	return trigger:FindFirstChildWhichIsA("BasePart", true)
end

local function getOrCreatePrompt(trigger: Instance): ProximityPrompt?
	local existing = trigger:FindFirstChildWhichIsA("ProximityPrompt", true)
	if existing then
		return existing
	end
	local anchor = resolveAnchor(trigger)
	if not anchor then
		Log.warn(TAG, string.format("%s bukan/tidak punya BasePart; prompt tidak bisa dibuat", trigger:GetFullName()))
		return nil
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = Config.PROMPT_ACTION
	prompt.ObjectText = Config.PROMPT_OBJECT
	prompt.MaxActivationDistance = Config.PROMPT_DISTANCE
	prompt.HoldDuration = 0
	prompt.RequiresLineOfSight = false
	prompt.Parent = anchor
	return prompt
end

-- Diagnostik: cetak turunan clone (nama, class, dan Value bila ada) untuk mencari durasi / sinyal selesai.
local function dumpClone(clone: Instance, label: string)
	local lines: { string } = {}
	for _, item in clone:GetDescendants() do
		if #lines >= Config.DUMP_MAX_ITEMS then
			table.insert(lines, "...")
			break
		end
		local text = item:GetFullName():sub(#clone:GetFullName() + 2) .. " [" .. item.ClassName .. "]"
		local okValue, value = pcall(function()
			return (item :: any).Value
		end)
		if okValue and value ~= nil then
			text ..= " = " .. tostring(value)
		end
		table.insert(lines, text)
	end
	for name, value in clone:GetAttributes() do
		table.insert(lines, "@" .. name .. " = " .. tostring(value))
	end
	Log.info(TAG, string.format("%s isi clone (%d baris): %s", label, #lines, table.concat(lines, " | ")))
end

-- Durasi otomatis: jumlah NumberValue `Time` pada tiap titik di CutsceneInfo. nil bila tidak ditemukan / tidak > 0.
local function computeAutoDuration(clone: Instance): number?
	local info = clone:FindFirstChild(Config.INFO_NAME)
	if not info then
		return nil
	end
	local total = 0
	for _, point in info:GetChildren() do
		local timeValue = point:FindFirstChild(Config.TIME_VALUE_NAME)
		if timeValue and timeValue:IsA("NumberValue") and timeValue.Value > 0 then
			total += timeValue.Value
		end
	end
	if total <= 0 then
		return nil
	end
	return total
end

-- Tunggu semua clone hilang, atau durasi `fixed` habis (bila ada), atau MAX_WAIT_PER_CUTSCENE; lalu bersihkan clone.
local function waitForClones(label: string, clones: { Instance }, fixed: number?, source: string)
	local limit: number = fixed or Config.MAX_WAIT_PER_CUTSCENE
	if fixed then
		Log.info(TAG, string.format("%s durasi %.2fs (%s)", label, fixed, source))
	end
	local started = os.clock()
	while true do
		local elapsed = os.clock() - started
		if elapsed >= limit then
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
			Log.info(TAG, string.format("%s selesai (%.1f detik)", label, elapsed))
			return
		end
		task.wait(math.min(0.25, limit - elapsed))
	end

	if fixed then
		Log.info(TAG, string.format("%s selesai menurut durasi %.2fs; clone dibersihkan", label, limit))
	else
		Log.warn(
			TAG,
			string.format(
				"%s timeout %ds: clone tidak menghilang sendiri; dihancurkan paksa (durasi tidak bisa dihitung dari CutsceneInfo; isi DURATIONS agar tidak menunggu lama)",
				label,
				limit
			)
		)
	end
	for _, clone in clones do
		if clone.Parent ~= nil then
			clone:Destroy()
		end
	end
end

-- Putar satu modul untuk semua peserta, lalu tunggu semua clone LocalCutscenePlayer hilang (atau timeout).
local function playModule(moduleScript: ModuleScript, participants: { Player })
	local okRequire, loaded = pcall(require, moduleScript)
	local module: any = loaded
	if not okRequire or type(module) ~= "table" or type(module.PlayCutscene) ~= "function" then
		Log.warn(TAG, string.format("%s tidak valid (butuh function PlayCutscene(player)); dilewati", moduleScript.Name))
		return
	end

	local clones: { Instance } = {}
	for _, player in participants do
		local gui = player:FindFirstChildOfClass("PlayerGui")
		if player.Parent == Players and gui then
			local before: { [Instance]: boolean } = {}
			for _, child in gui:GetChildren() do
				before[child] = true
			end
			local ok, err = pcall(function()
				module.PlayCutscene(player)
			end)
			if not ok then
				Log.warn(TAG, string.format("%s gagal untuk %s: %s", moduleScript.Name, player.Name, tostring(err)))
			else
				for _, child in gui:GetChildren() do
					if child.Name == Config.LOCAL_PLAYER_NAME and not before[child] then
						table.insert(clones, child)
						break
					end
				end
			end
		end
	end

	if Config.DUMP_CLONE_INFO and clones[1] then
		dumpClone(clones[1], moduleScript.Name)
	end

	if #clones == 0 then
		Log.warn(
			TAG,
			string.format(
				"%s: clone '%s' tidak terdeteksi di PlayerGui; menunggu %ds",
				moduleScript.Name,
				Config.LOCAL_PLAYER_NAME,
				Config.NO_CLONE_DELAY
			)
		)
		task.wait(Config.NO_CLONE_DELAY)
		return
	end

	local fixed: number? = Config.DURATIONS[moduleScript.Name]
	local source = "manual"
	if not fixed and Config.AUTO_DURATION then
		local auto = computeAutoDuration(clones[1])
		if auto then
			fixed = auto + Config.DURATION_MARGIN
			source = string.format("otomatis dari %s: %.2fs + margin %.2fs", Config.INFO_NAME, auto, Config.DURATION_MARGIN)
		end
	end
	waitForClones(moduleScript.Name, clones, fixed, source)
end

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
				total += timeValue.Value
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

-- MODE MERGED. true bila ditangani (sukses atau sudah dibersihkan); false = pemanggil jatuh ke SEQUENTIAL.
local function playMerged(folder: Instance, participants: { Player }): boolean
	local modules: { ModuleScript } = {}
	for _, name in Config.MODULE_NAMES do
		local found = folder:FindFirstChild(name)
		if found and found:IsA("ModuleScript") then
			table.insert(modules, found)
		else
			Log.warn(TAG, string.format("ServerStorage.%s.%s (ModuleScript) tidak ditemukan; dilewati", Config.FOLDER_NAME, name))
		end
	end
	if #modules == 0 then
		return false
	end

	local template = modules[1]:FindFirstChild(Config.LOCAL_PLAYER_NAME)
	if not template or not template:IsA("LocalScript") then
		Log.warn(TAG, string.format("%s tidak punya LocalScript '%s'; MERGED dibatalkan", modules[1].Name, Config.LOCAL_PLAYER_NAME))
		return false
	end
	local merged, total = buildMergedInfo(modules)
	if not merged or total <= 0 then
		if merged then
			merged:Destroy()
		end
		Log.warn(TAG, "penggabungan CutsceneInfo gagal / total durasi 0; MERGED dibatalkan")
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
				Log.warn(TAG, string.format("MERGED gagal untuk %s: %s", player.Name, tostring(err)))
			end
		end
	end
	merged:Destroy()

	if #clones == 0 then
		Log.warn(TAG, "MERGED: tidak ada pemain yang berhasil memulai cutscene")
		return true
	end

	Log.info(TAG, string.format("memutar gabungan %d cutscene sebagai satu pemutaran (total Time %.2fs)", #modules, total))
	waitForClones("Gabungan", clones, total + Config.DURATION_MARGIN, string.format("jumlah Time %.2fs + margin %.2fs", total, Config.DURATION_MARGIN))
	return true
end

-- Putar semua modul berurutan untuk peserta. Pemain NORMAL dikunci ke CUTSCENE selama sesi lalu dikembalikan.
function CutsceneTestService.playSequence(participants: { Player })
	local folder = ServerStorage:FindFirstChild(Config.FOLDER_NAME)
	if not folder then
		Log.warn(TAG, string.format("ServerStorage.%s tidak ditemukan", Config.FOLDER_NAME))
		return
	end

	local locked: { Player } = {}
	for _, player in participants do
		if GameManager.getPlayerState(player) == PlayerState.NORMAL and GameManager.setPlayerState(player, PlayerState.CUTSCENE) then
			table.insert(locked, player)
		end
	end

	local ok, err = pcall(function()
		if Config.MODE == "MERGED" and playMerged(folder, participants) then
			return
		end
		if Config.MODE == "MERGED" then
			Log.warn(TAG, "jatuh ke mode SEQUENTIAL")
		end
		for index, name in Config.MODULE_NAMES do
			local moduleScript = folder:FindFirstChild(name)
			if moduleScript and moduleScript:IsA("ModuleScript") then
				Log.info(TAG, string.format("memutar %d/%d: %s", index, #Config.MODULE_NAMES, name))
				playModule(moduleScript, participants)
				if Config.GAP_BETWEEN > 0 then
					task.wait(Config.GAP_BETWEEN)
				end
			else
				Log.warn(TAG, string.format("ServerStorage.%s.%s (ModuleScript) tidak ditemukan; dilewati", Config.FOLDER_NAME, name))
			end
		end
	end)
	if not ok then
		Log.warn(TAG, "urutan cutscene error: " .. tostring(err))
	end

	for _, player in locked do
		if player.Parent == Players and GameManager.getPlayerState(player) == PlayerState.CUTSCENE then
			GameManager.setPlayerState(player, PlayerState.NORMAL)
		end
	end
end

function CutsceneTestService.init()
	if not Config.ENABLED then
		return
	end
	if Config.ONLY_IN_STUDIO and not RunService:IsStudio() then
		return
	end

	task.spawn(function()
		local trigger = findTrigger()
		if not trigger then
			Log.warn(TAG, string.format("Workspace.%s tidak ditemukan (dependency Studio); trigger tes tidak aktif", Config.TRIGGER_NAME))
			return
		end
		local prompt = getOrCreatePrompt(trigger)
		if not prompt then
			return
		end

		prompt.Triggered:Connect(function(player: Player)
			if running then
				return
			end
			running = true
			prompt.Enabled = false
			Log.info(TAG, string.format("dipicu oleh %s", player.Name))

			task.spawn(function()
				CutsceneTestService.playSequence(Players:GetPlayers())
				running = false
				prompt.Enabled = true
				Log.info(TAG, "urutan cutscene selesai; trigger aktif lagi")
			end)
		end)
		Log.info(TAG, string.format("siap: %s (tes cutscene, hanya Studio)", prompt:GetFullName()))
	end)
end

return CutsceneTestService
