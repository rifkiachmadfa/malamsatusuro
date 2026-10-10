--!strict
-- KnockService: pemilik state KNOCKED pemain (Phase 6, Task 6.1, ADR-031).
-- Knock = pemain berbaring dan tidak bisa bergerak/berinteraksi sampai dipulihkan (revive: Task 6.4+).
--
-- Service ini TIDAK tahu penyebab knock. Penyebab (bunga salah, hantu, dll) cukup memanggil
-- `KnockService.knock(player, reason)`. Pemulihan lewat `KnockService.recover(player)`; validasi revive
-- (ramuan, jarak, dsb) adalah tanggung jawab ReviveService, bukan service ini.
--
-- Dijaga server:
--   * state pemain di GameManager: NORMAL -> KNOCKED (InteractionService/DialogueService sudah menolak non-NORMAL)
--   * HumanoidRootPart di-Anchor dan diposisikan berbaring (client tidak bisa menggerakkannya)
--   * WalkSpeed/Jump = 0, tool dilepas dan tidak bisa di-equip
--   * reset karakter/mati saat knock tidak membebaskan: karakter baru diletakkan kembali di titik knock
--   * pemain keluar: data dibersihkan; jika semua pemain yang tersisa knock, listener onAllKnocked dipanggil

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("Config"):WaitForChild("GameConfig") :: ModuleScript)
local Log = require(Shared:WaitForChild("Util"):WaitForChild("Log") :: ModuleScript)
local Config = require(script.Parent.Parent:WaitForChild("Config"):WaitForChild("KnockConfig") :: ModuleScript)
local Services = script.Parent
local GameManager = require(Services:WaitForChild("GameManager") :: ModuleScript)
local NoticeService = require(Services:WaitForChild("NoticeService") :: ModuleScript)

local TAG = "KnockService"
local PlayerState = GameConfig.PlayerState

type SavedStats = {
	walkSpeed: number,
	jumpPower: number,
	jumpHeight: number,
	autoRotate: boolean,
}

type KnockData = {
	reason: string,
	standCFrame: CFrame, -- posisi/arah berdiri saat knock (dipakai saat pulih)
	lyingCFrame: CFrame, -- posisi/arah berbaring
	saved: SavedStats,
	connections: { RBXScriptConnection },
}

export type KnockedListener = (player: Player, reason: string) -> ()
export type RecoveredListener = (player: Player) -> ()
export type AllKnockedListener = () -> ()

local KnockService = {}

local knocked: { [Player]: KnockData } = {}
local knockedListeners: { KnockedListener } = {}
local recoveredListeners: { RecoveredListener } = {}
local allKnockedListeners: { AllKnockedListener } = {}

local function getParts(player: Player): (Humanoid?, BasePart?)
	local character = player.Character
	if not character then
		return nil, nil
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	if humanoid and root and root:IsA("BasePart") then
		return humanoid, root
	end
	return nil, nil
end

-- Pose berbaring telentang di atas lantai, arah badan mengikuti arah hadap saat knock.
local function computeLyingCFrame(character: Model, root: BasePart): CFrame
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character }
	params.RespectCanCollide = true

	local position = root.Position
	local result = Workspace:Raycast(position, Vector3.new(0, -Config.FLOOR_RAY_LENGTH, 0), params)
	local y = if result then result.Position.Y + Config.LIE_HEIGHT else position.Y - Config.FALLBACK_DROP

	local look = root.CFrame.LookVector
	local yaw = math.atan2(-look.X, -look.Z)
	return CFrame.new(position.X, y, position.Z) * CFrame.Angles(0, yaw, 0) * CFrame.Angles(math.rad(90), 0, 0)
end

local function applyPose(humanoid: Humanoid, root: BasePart, data: KnockData)
	humanoid:UnequipTools()
	humanoid.WalkSpeed = 0
	humanoid.JumpPower = 0
	humanoid.JumpHeight = 0
	humanoid.AutoRotate = false
	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero
	root.CFrame = data.lyingCFrame
	root.Anchored = true
end

local function disconnectAll(data: KnockData)
	for _, connection in data.connections do
		connection:Disconnect()
	end
	table.clear(data.connections)
end

-- Selama knock: tool yang masuk ke karakter (equip) langsung dilepas; karakter baru (reset/mati) dikembalikan ke titik knock.
local function watchPlayer(player: Player, data: KnockData)
	local function hookCharacter(character: Model)
		table.insert(
			data.connections,
			character.ChildAdded:Connect(function(child: Instance)
				if child:IsA("Tool") and knocked[player] == data then
					local humanoid = character:FindFirstChildOfClass("Humanoid")
					if humanoid then
						task.defer(function()
							humanoid:UnequipTools()
						end)
					end
				end
			end)
		)
	end

	if player.Character then
		hookCharacter(player.Character)
	end

	table.insert(
		data.connections,
		player.CharacterAdded:Connect(function(character: Model)
			hookCharacter(character)
			local humanoid = character:WaitForChild("Humanoid", 10)
			local root = character:WaitForChild("HumanoidRootPart", 10)
			if knocked[player] ~= data then
				return -- sudah pulih/keluar selagi menunggu
			end
			if humanoid and humanoid:IsA("Humanoid") and root and root:IsA("BasePart") then
				applyPose(humanoid, root, data)
				Log.info(TAG, string.format("%s respawn saat knock: dikembalikan ke titik knock", player.Name))
			end
		end)
	)
end

-- Semua pemain yang tersisa (selain exclude) sedang knock = dasar party wipe (Task 6.5).
local function checkAllKnocked(exclude: Player?)
	local total = 0
	local down = 0
	for _, member in Players:GetPlayers() do
		if member ~= exclude then
			total += 1
			if knocked[member] then
				down += 1
			end
		end
	end
	if total > 0 and down == total then
		Log.info(TAG, string.format("semua pemain knock (%d/%d)", down, total))
		for _, listener in allKnockedListeners do
			task.spawn(listener)
		end
	end
end

function KnockService.isKnocked(player: Player): boolean
	return knocked[player] ~= nil
end

function KnockService.getKnockedCount(): number
	local count = 0
	for _ in knocked do
		count += 1
	end
	return count
end

function KnockService.onKnocked(listener: KnockedListener)
	table.insert(knockedListeners, listener)
end

function KnockService.onRecovered(listener: RecoveredListener)
	table.insert(recoveredListeners, listener)
end

-- Dipanggil saat setiap pemain yang tersisa sedang knock (solo: satu pemain knock = langsung terpanggil).
function KnockService.onAllKnocked(listener: AllKnockedListener)
	table.insert(allKnockedListeners, listener)
end

-- Knock pemain NORMAL. Return false jika ditolak (bukan NORMAL, karakter tidak valid, dsb).
function KnockService.knock(player: Player, reason: string): boolean
	if player.Parent ~= Players then
		return false
	end
	if GameManager.getPlayerState(player) ~= PlayerState.NORMAL then
		Log.warn(TAG, string.format("knock %s ditolak: state %s", player.Name, tostring(GameManager.getPlayerState(player))))
		return false
	end

	local humanoid, root = getParts(player)
	if not humanoid or not root or humanoid.Health <= 0 then
		Log.warn(TAG, string.format("knock %s ditolak: karakter tidak valid", player.Name))
		return false
	end
	local character = player.Character :: Model

	if not GameManager.setPlayerState(player, PlayerState.KNOCKED) then
		return false
	end

	local data: KnockData = {
		reason = reason,
		standCFrame = root.CFrame,
		lyingCFrame = computeLyingCFrame(character, root),
		saved = {
			walkSpeed = humanoid.WalkSpeed,
			jumpPower = humanoid.JumpPower,
			jumpHeight = humanoid.JumpHeight,
			autoRotate = humanoid.AutoRotate,
		},
		connections = {},
	}
	knocked[player] = data
	applyPose(humanoid, root, data)
	watchPlayer(player, data)

	Log.info(TAG, string.format("%s knock (%s)", player.Name, reason))
	NoticeService.notifyParty(
		player,
		"Kamu pingsan. Tunggu rekan menyadarkanmu dengan Minyak Zaitun.",
		string.format("%s pingsan! Bawa Minyak Zaitun untuk menyadarkannya.", player.Name)
	)

	for _, listener in knockedListeners do
		task.spawn(listener, player, reason)
	end
	checkAllKnocked(nil)
	return true
end

-- Pulihkan pemain knock (tanpa validasi revive; itu milik ReviveService). Return false jika pemain tidak knock.
function KnockService.recover(player: Player): boolean
	local data = knocked[player]
	if not data then
		return false
	end
	if not GameManager.setPlayerState(player, PlayerState.NORMAL) then
		return false
	end

	knocked[player] = nil
	disconnectAll(data)

	local humanoid, root = getParts(player)
	if humanoid and root then
		root.CFrame = data.standCFrame
		root.Anchored = false
		humanoid.WalkSpeed = data.saved.walkSpeed
		humanoid.JumpPower = data.saved.jumpPower
		humanoid.JumpHeight = data.saved.jumpHeight
		humanoid.AutoRotate = data.saved.autoRotate
	end

	Log.info(TAG, string.format("%s pulih dari knock", player.Name))
	NoticeService.notifyParty(player, "Kamu sadar kembali.", string.format("%s sadar kembali.", player.Name))

	for _, listener in recoveredListeners do
		task.spawn(listener, player)
	end
	return true
end

local function onPlayerRemoving(player: Player)
	local data = knocked[player]
	if data then
		disconnectAll(data)
		knocked[player] = nil
		Log.info(TAG, string.format("%s keluar saat knock", player.Name))
	end
	-- Pemain tersisa mungkin semuanya knock setelah ini.
	task.defer(function()
		checkAllKnocked(player)
	end)
end

function KnockService.init()
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	Log.info(TAG, "siap")
end

return table.freeze(KnockService)
