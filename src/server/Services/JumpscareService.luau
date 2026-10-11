--!strict
-- JumpscareService: memicu jumpscare pada SATU pemain (Phase 6, Task 6.2, ADR-033).
-- Presentasi sepenuhnya di client pemain itu (ViewportFrame berisi model 3D berrig + animasi); pemain lain tidak melihat apa pun.
-- Server hanya: (1) mempublikasikan model ke client, (2) membekukan pemain, (3) mengirim event ke pemain itu,
-- (4) menunggu durasi lalu mengembalikan kontrol ke pemanggil (FailureService) untuk menjatuhkan hukuman.
-- Client tidak menentukan hasil gameplay apa pun.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Log = require(Shared:WaitForChild("Util"):WaitForChild("Log") :: ModuleScript)
local Remotes = require(Shared:WaitForChild("Remotes") :: ModuleScript)
local JumpscareConfig = require(Shared:WaitForChild("Config"):WaitForChild("JumpscareConfig") :: ModuleScript)

local TAG = "JumpscareService"

local JumpscareService = {}

local remote: RemoteEvent? = nil
local published: Folder? = nil

-- Salin semua Model di ServerStorage/GhostModels ke ReplicatedStorage/GhostModels (tanpa script).
local function publishModels()
	local source = ServerStorage:FindFirstChild(JumpscareConfig.SOURCE_FOLDER)
	if not source then
		Log.warn(TAG, string.format("ServerStorage.%s tidak ditemukan; jumpscare dilewati", JumpscareConfig.SOURCE_FOLDER))
		return
	end

	local folder = ReplicatedStorage:FindFirstChild(JumpscareConfig.MODEL_FOLDER)
	if folder then
		folder:ClearAllChildren()
	else
		local created = Instance.new("Folder")
		created.Name = JumpscareConfig.MODEL_FOLDER
		created.Parent = ReplicatedStorage
		folder = created
	end

	local count = 0
	for _, child in source:GetChildren() do
		if child:IsA("Model") then
			local copy = child:Clone()
			for _, descendant in copy:GetDescendants() do
				if descendant:IsA("BaseScript") then
					descendant:Destroy() -- AnimateScript dsb tidak diperlukan; animasi diputar client
				end
			end
			copy.Parent = folder
			count += 1
		end
	end
	published = folder :: Folder
	Log.info(TAG, string.format("%d model hantu dipublikasikan ke client", count))
end

local function getRoot(player: Player): BasePart?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root
	end
	return nil
end

-- Mainkan jumpscare `ghostId` pada `player`. MENUNGGU (yield) selama durasi jumpscare.
-- Return false (langsung, tanpa menunggu) jika model/definisi tidak ada: hukuman tetap berjalan tanpa jumpscare.
function JumpscareService.play(player: Player, ghostId: string): boolean
	local def = JumpscareConfig.Ghosts[ghostId]
	if not def then
		Log.warn(TAG, "hantu tidak dikenal: " .. tostring(ghostId))
		return false
	end
	if not remote or not published or not published:FindFirstChild(def.modelName) then
		Log.warn(TAG, string.format("model %s belum tersedia; jumpscare dilewati", def.modelName))
		return false
	end
	if player.Parent ~= Players then
		return false
	end

	-- Bekukan selama jumpscare (di-anchor di server, tidak bisa digeser client).
	local root = getRoot(player)
	local wasAnchored = root ~= nil and root.Anchored
	if root then
		root.Anchored = true
	end

	Log.info(TAG, string.format("jumpscare %s -> %s", ghostId, player.Name))
	remote:FireClient(player, ghostId)
	task.wait(def.duration)

	if root and root.Parent and getRoot(player) == root then
		root.Anchored = wasAnchored
	end
	return true
end

function JumpscareService.init()
	remote = Remotes.get(Remotes.Names.Jumpscare)
	publishModels()
	Log.info(TAG, "siap")
end

return table.freeze(JumpscareService)
