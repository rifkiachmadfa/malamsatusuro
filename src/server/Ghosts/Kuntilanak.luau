--!strict
-- Kuntilanak: perilaku hantu quest Keris / Daun Kelor (Phase 9, ADR-048). Dimuat GhostService (host generik).
--
-- ATURAN (desain user 2026-10-16; semua angka di GhostConfig.Ghosts.Kuntilanak.params):
--   MUNCUL    saat pemain mengambil Daun Kelor (CollectibleService.onCollected), di titik QuestObjects/KuntilanakSpawn
--             yang TERDEKAT dari titik Kelor yang baru diambil. Satu Kuntilanak sekaligus. Pickup terakhir (Kelor 4/4,
--             quest pindah ke KELOR_COMPLETE) tidak memanggilnya, dan ia menghilang saat quest keluar dari SEARCHING_KELOR.
--   TARGET    HANYA pemain NORMAL yang membawa Daun Kelor (Backpack atau tangan). Pemain tanpa Kelor diabaikan.
--   TANGKAP   jarak <= catchRadius: Kelor korban (semua yang ia bawa) dirampas -> muncul lagi di titik acak yang bebas dan
--             progres party berkurang (CollectibleService.returnToWorld) -> jumpscare + knock (FailureService, kebijakan
--             GHOST_KUNTILANAK: solo / pemain terakhir yang berdiri = respawn tanpa reset quest). Hantu lalu menghilang.
--   LAWAN     pemain lain (NORMAL/REVIVING) dalam protectRadius dari korban = korban terlindungi: ia tidak bisa menangkap,
--             menahan jarak holdDistance, dan menyerah setelah repelSeconds. Ia lebih suka mengejar pembawa yang TIDAK terlindungi.
--   SOLO      tak ada pelindung (solo, atau rekan lain sudah knock): bertahan soloChaseSeconds tanpa tertangkap -> ia menyerah.
--   PENGAMAN  menghilang bila tak ada pembawa valid noTargetSeconds, atau maxChaseSeconds berlalu.
-- Hantu hanya menangkap pemain berstatus NORMAL, jadi sesi puzzle/revive/cutscene tidak pernah terpotong olehnya
-- (prasyarat 9.0 ADR-047 belum perlu untuk hantu ini; dialog yang terbuka ditutup DialogueService saat status berubah).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("Config"):WaitForChild("GameConfig") :: ModuleScript)
local QuestConfig = require(Shared:WaitForChild("Config"):WaitForChild("QuestConfig") :: ModuleScript)
local Log = require(Shared:WaitForChild("Util"):WaitForChild("Log") :: ModuleScript)
local Spatial = require(Shared:WaitForChild("Util"):WaitForChild("Spatial") :: ModuleScript)
local Server = script.Parent.Parent
local Config = require(Server:WaitForChild("Config"):WaitForChild("GhostConfig") :: ModuleScript)
local Services = Server:WaitForChild("Services")
-- Hanya untuk tipe (Ghost/Host/Behavior); lihat catatan di GhostService.
local GhostService = require(Services:WaitForChild("GhostService") :: ModuleScript)
local CollectibleService = require(Services:WaitForChild("CollectibleService") :: ModuleScript)
local GameManager = require(Services:WaitForChild("GameManager") :: ModuleScript)
local ItemService = require(Services:WaitForChild("ItemService") :: ModuleScript)
local NoticeService = require(Services:WaitForChild("NoticeService") :: ModuleScript)
local QuestService = require(Services:WaitForChild("QuestService") :: ModuleScript)

type Ghost = GhostService.Ghost
type Host = GhostService.Host

local TAG = "Kuntilanak"
local ID = "Kuntilanak"
local PlayerState = GameConfig.PlayerState

-- Teks notifikasi saat hantu menghilang, menurut alasan. Alasan tanpa entri = tanpa notifikasi (mis. CAUGHT, ERROR).
local DESPAWN_TEXT: { [string]: string } = {
	REPELLED = "repelled",
	ESCAPED = "escaped",
	NO_HOLDER = "gone",
	TIMEOUT = "gone",
	QUEST_STATE = "gone",
}

type State = {
	target: Player?,
	chaseTime: number,
	protectedTime: number,
	noTargetTime: number,
}

local Kuntilanak = {}

local function getDef(): Config.GhostDef
	local def = Config.Ghosts[ID]
	assert(def, "GhostConfig.Ghosts." .. ID .. " tidak ada")
	return def
end

local function getState(ghost: Ghost): State
	local state = ghost.data.state :: State?
	if not state then
		state = { target = nil, chaseTime = 0, protectedTime = 0, noTargetTime = 0 }
		ghost.data.state = state
	end
	return state :: State
end

-- Pembawa Kelor yang valid dijadikan target: NORMAL, hidup, dan membawa item (Backpack atau tangan).
local function isHolder(player: Player, itemId: string): boolean
	return player.Parent == Players
		and GameManager.getPlayerState(player) == PlayerState.NORMAL
		and Spatial.getCharacterPosition(player) ~= nil
		and ItemService.count(player, itemId) > 0
end

-- Terlindungi = ada pemain LAIN (NORMAL atau sedang REVIVING) dalam `radius` studs dari `position`.
-- Pemain knock tidak melindungi (tidak bisa menolong).
local function isProtected(target: Player, position: Vector3, radius: number): boolean
	for _, other in Players:GetPlayers() do
		if other ~= target then
			local state = GameManager.getPlayerState(other)
			if state == PlayerState.NORMAL or state == PlayerState.REVIVING then
				local otherPosition = Spatial.getCharacterPosition(other)
				if otherPosition and (otherPosition - position).Magnitude <= radius then
					return true
				end
			end
		end
	end
	return false
end

-- Hanya satu pemain yang masih berdiri (bukan knock): solo, atau rekan lain sudah knock. Tak ada yang bisa melindunginya,
-- jadi aturan solo berlaku (bertahan soloChaseSeconds lalu hantu menyerah).
local function onlyOneStanding(): boolean
	local standing = 0
	for _, player in Players:GetPlayers() do
		local state = GameManager.getPlayerState(player)
		if state ~= nil and state ~= PlayerState.KNOCKED then
			standing += 1
		end
	end
	return standing <= 1
end

-- Pilih pembawa terdekat yang TIDAK terlindungi; bila semua terlindungi, pembawa terlindungi yang terdekat.
local function pickTarget(from: Vector3, itemId: string, protectRadius: number): Player?
	local bestFree: Player? = nil
	local bestFreeDistance = math.huge
	local bestAny: Player? = nil
	local bestAnyDistance = math.huge

	for _, player in Players:GetPlayers() do
		if isHolder(player, itemId) then
			local position = Spatial.getCharacterPosition(player)
			if position then
				local distance = (position - from).Magnitude
				if distance < bestAnyDistance then
					bestAny, bestAnyDistance = player, distance
				end
				if distance < bestFreeDistance and not isProtected(player, position, protectRadius) then
					bestFree, bestFreeDistance = player, distance
				end
			end
		end
	end
	return bestFree or bestAny
end

-- Posisi titik KuntilanakSpawn terdekat dari `origin`; nil bila folder/titik belum ada (dependency Studio).
local function nearestSpawnPosition(origin: Vector3?, folderName: string): Vector3?
	local questObjects = Workspace:FindFirstChild("QuestObjects")
	local container = questObjects and questObjects:FindFirstChild(folderName)
	if not container then
		return nil
	end

	local best: Vector3? = nil
	local bestName = ""
	local bestDistance = math.huge
	for _, child in container:GetChildren() do
		local position = Spatial.getPosition(child)
		if position then
			local distance = if origin then (position - origin).Magnitude else 0
			if distance < bestDistance or (distance == bestDistance and child.Name < bestName) then
				best, bestName, bestDistance = position, child.Name, distance
			end
		end
	end
	return best
end

local function text(def: Config.GhostDef, key: string): string
	local value = def.texts[key]
	assert(value, string.format("[%s] texts.%s tidak ada di GhostConfig", TAG, key))
	return value
end

-- Tangkap `victim`: rampas Kelornya (atomik, tanpa yield) lalu hukum lewat FailureService. Return true bila hukuman dijatuhkan.
local function catchPlayer(host: Host, ghost: Ghost, victim: Player): boolean
	local def = ghost.def
	local bindings = def.bindings
	local stolen = 0

	local punished = host.punish(ghost, victim, function(player: Player)
		local owned = ItemService.count(player, bindings.itemId)
		if owned <= 0 then
			return
		end
		-- Urutan: kembalikan ke dunia + kurangi progres dulu (bisa menolak/mengembalikan lebih sedikit), baru hapus dari pemain
		-- sebanyak yang benar-benar dikembalikan. Tanpa yield di antaranya, jadi progres + pickup + isi Backpack selalu cocok.
		stolen = CollectibleService.returnToWorld(bindings.collectionId, owned)
		if stolen > 0 and not ItemService.consume(player, bindings.itemId, stolen) then
			Log.warn(TAG, string.format("KONSISTENSI: consume %s gagal setelah returnToWorld (%s)", bindings.itemId, player.Name))
		end
	end)
	if not punished then
		return false
	end

	Log.info(TAG, string.format("%s tertangkap; %d %s dirampas", victim.Name, stolen, bindings.itemId))
	if stolen > 0 then
		local questDef = (QuestConfig.Quests :: any)[def.questId] :: QuestConfig.QuestDef
		local target = questDef.counters[bindings.counterId].target
		local progress = QuestService.getCounter(def.questId, bindings.counterId) or 0
		NoticeService.notifyParty(
			victim,
			string.format(text(def, "stolen"), stolen),
			string.format(text(def, "stolenOthers"), stolen, victim.Name, progress, target)
		)
	end
	host.despawn(ghost, "CAUGHT")
	return true
end

function Kuntilanak.init(host: Host)
	local def = getDef()
	local bindings = def.bindings

	CollectibleService.onCollected(function(collectionId: string, _player: Player, kelorSpawn: Instance, _itemId: string)
		if collectionId ~= bindings.collectionId then
			return
		end
		-- Dijalankan lewat task.spawn: periksa ulang state. Pickup terakhir (4/4) sudah memindahkan quest ke KELOR_COMPLETE.
		if QuestService.getState(def.questId) ~= bindings.activeState then
			return
		end
		if #host.getActive(ID) >= def.maxActive then
			return
		end

		local position = nearestSpawnPosition(Spatial.getPosition(kelorSpawn), bindings.spawnFolder)
		if not position then
			Log.warn(TAG, string.format("dependency belum ada: Workspace.QuestObjects.%s (butuh >= 1 Part)", bindings.spawnFolder))
			return
		end
		local ghost = host.spawn(ID, CFrame.new(position + Vector3.new(0, host.param(def, "spawnYOffset"), 0)))
		if ghost then
			NoticeService.broadcast(text(def, "spawn"))
		end
	end)

	QuestService.onStateChanged(function(questId: string, _fromState: string, toState: string)
		if questId == def.questId and toState ~= bindings.activeState then
			host.despawnAll(ID, "QUEST_STATE")
		end
	end)
end

function Kuntilanak.update(host: Host, ghost: Ghost, dt: number)
	local def = ghost.def
	local bindings = def.bindings
	local state = getState(ghost)

	if QuestService.getState(def.questId) ~= bindings.activeState then
		host.despawn(ghost, "QUEST_STATE")
		return
	end

	-- Peringatan: diam sebentar setelah muncul, belum bisa menangkap.
	if ghost.phase == "NEW" then
		ghost.phase = "APPEARING"
	end
	if ghost.phase == "APPEARING" then
		if ghost.age >= host.param(def, "appearSeconds") then
			ghost.phase = "CHASING"
		end
		return
	end

	state.chaseTime += dt
	if state.chaseTime >= host.param(def, "maxChaseSeconds") then
		host.despawn(ghost, "TIMEOUT")
		return
	end
	if onlyOneStanding() and state.chaseTime >= host.param(def, "soloChaseSeconds") then
		host.despawn(ghost, "ESCAPED")
		return
	end

	local protectRadius = host.param(def, "protectRadius")
	local ghostPosition = ghost.root.Position

	-- Pertahankan target selama masih valid DAN tidak terlindungi; selain itu pilih ulang (lebih suka yang sendirian).
	local target = state.target
	local targetPosition: Vector3? = nil
	local keep = false
	if target and isHolder(target, bindings.itemId) then
		targetPosition = Spatial.getCharacterPosition(target)
		keep = targetPosition ~= nil and not isProtected(target, targetPosition, protectRadius)
	end
	if not keep then
		target = pickTarget(ghostPosition, bindings.itemId, protectRadius)
		state.target = target
		targetPosition = if target then Spatial.getCharacterPosition(target) else nil
	end

	if not target or not targetPosition then
		state.noTargetTime += dt
		if state.noTargetTime >= host.param(def, "noTargetSeconds") then
			host.despawn(ghost, "NO_HOLDER")
		end
		return
	end
	state.noTargetTime = 0

	local aim = targetPosition + Vector3.new(0, host.param(def, "targetYOffset"), 0)
	local speed = host.param(def, "chaseSpeed")

	if isProtected(target, targetPosition, protectRadius) then
		-- Dilawan: tidak bisa menangkap, menahan jarak, lalu menyerah bila terus terlindungi.
		state.protectedTime += dt
		if state.protectedTime >= host.param(def, "repelSeconds") then
			host.despawn(ghost, "REPELLED")
			return
		end
		if (aim - ghostPosition).Magnitude < host.param(def, "holdDistance") then
			local away = ghostPosition - aim
			local direction = if away.Magnitude > 1e-3 then away.Unit else Vector3.new(0, 0, 1)
			host.move(ghost, ghostPosition + direction * 10, speed, dt, aim)
		end
		return
	end
	state.protectedTime = math.max(0, state.protectedTime - dt)

	host.move(ghost, aim, speed, dt, nil)
	if (ghost.root.Position - aim).Magnitude <= host.param(def, "catchRadius") then
		catchPlayer(host, ghost, target)
	end
end

function Kuntilanak.onDespawn(_host: Host, ghost: Ghost, reason: string)
	local key = DESPAWN_TEXT[reason]
	if key then
		NoticeService.broadcast(text(ghost.def, key))
	end
end

local behavior: GhostService.Behavior = Kuntilanak
return behavior
