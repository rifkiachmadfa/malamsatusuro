--!strict
-- GamelanMusicController: musik gamelan di dunia untuk pemain LAIN (Phase 7, ADR-039).
-- Server menandai pemain yang bermain + waktu mulai lewat Attribute pada objek Workspace.QuestObjects.Gamelan
-- (GamelanConfig.MUSIC_PLAYER_ATTR / MUSIC_START_ATTR). Setiap client lain memutar suara SPASIAL di gamelan,
-- dimulai dari posisi yang sesuai waktu server (pemain yang baru masuk ikut tersinkron).
-- Pemain yang bermain TIDAK memutar suara ini: ia mendengar musik lokalnya (GamelanController) yang sinkron dengan not.
-- Hanya audio: tidak ada GUI, tidak mengirim apa pun ke server, tidak memengaruhi gameplay.

local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GamelanConfig = require(Shared:WaitForChild("Config"):WaitForChild("GamelanConfig") :: ModuleScript)
local Log = require(Shared:WaitForChild("Util"):WaitForChild("Log") :: ModuleScript)

local TAG = "GamelanMusicController"
local FIND_TIMEOUT = 60 -- detik menunggu objek Gamelan muncul (map/streaming)
local Config = GamelanConfig
local localPlayer = Players.LocalPlayer

local GamelanMusicController = {}

local gamelan: Instance? = nil
local current: Sound? = nil
local currentKey: string? = nil -- "<userId>:<startTime>" sesi yang sedang diputar
local token = 0 -- naikkan untuk membatalkan pemuatan yang sedang berjalan

-- Bagian fisik tempat suara dipasang (Sound spasial harus berada di BasePart).
local function findSoundPart(target: Instance): BasePart?
	if target:IsA("BasePart") then
		return target
	end
	if target:IsA("Model") then
		if target.PrimaryPart then
			return target.PrimaryPart
		end
		return target:FindFirstChildWhichIsA("BasePart", true)
	end
	return nil
end

local function stopMusic()
	token += 1
	currentKey = nil
	if current then
		current:Stop()
		current:Destroy()
		current = nil
	end
end

local function refresh()
	local target = gamelan
	if not target then
		return
	end

	local userId = target:GetAttribute(Config.MUSIC_PLAYER_ATTR)
	local startTime = target:GetAttribute(Config.MUSIC_START_ATTR)
	if typeof(userId) ~= "number" or typeof(startTime) ~= "number" then
		stopMusic()
		return
	end
	if userId == localPlayer.UserId then
		stopMusic() -- pemain yang bermain memakai musik lokalnya sendiri
		return
	end

	local key = string.format("%d:%f", userId, startTime)
	if key == currentKey then
		return -- sesi yang sama sudah diputar (hindari mulai ulang)
	end
	stopMusic()

	local id = Config.SOUND_ID
	if id == "" or id == "rbxassetid://0" then
		return
	end
	local part = findSoundPart(target)
	if not part then
		Log.warn(TAG, "objek Gamelan tanpa BasePart; musik dunia dilewati")
		return
	end

	local sound = Instance.new("Sound")
	sound.Name = "GamelanWorldMusic"
	sound.SoundId = id
	sound.Volume = Config.WORLD_SOUND_VOLUME
	sound.Looped = false
	sound.RollOffMode = Enum.RollOffMode.InverseTapered
	sound.RollOffMinDistance = Config.WORLD_ROLLOFF_MIN
	sound.RollOffMaxDistance = Config.WORLD_ROLLOFF_MAX
	sound.Parent = part
	current = sound
	currentKey = key
	local myToken = token

	task.spawn(function()
		pcall(function()
			ContentProvider:PreloadAsync({ sound })
		end)
		if token ~= myToken then
			return -- dibatalkan saat memuat
		end
		-- Hitung ulang setelah memuat: musik pemain sudah berjalan sejak startTime.
		local offset = Workspace:GetServerTimeNow() - startTime
		if offset >= Config.DURATION_SECONDS then
			stopMusic()
			return
		end
		sound.TimePosition = math.max(0, offset)
		sound:Play()
	end)

	sound.Ended:Connect(function()
		if current == sound then
			stopMusic()
		end
	end)
end

function GamelanMusicController.init()
	task.spawn(function()
		local questObjects = Workspace:WaitForChild("QuestObjects", FIND_TIMEOUT)
		local found = questObjects and questObjects:WaitForChild(Config.OBJECT_NAME, FIND_TIMEOUT)
		if not found then
			Log.warn(TAG, "Workspace.QuestObjects." .. Config.OBJECT_NAME .. " tidak ditemukan; musik dunia nonaktif")
			return
		end
		gamelan = found
		found:GetAttributeChangedSignal(Config.MUSIC_PLAYER_ATTR):Connect(refresh)
		found:GetAttributeChangedSignal(Config.MUSIC_START_ATTR):Connect(refresh)
		refresh() -- pemain yang baru masuk saat gamelan sedang dimainkan
	end)
end

return GamelanMusicController
