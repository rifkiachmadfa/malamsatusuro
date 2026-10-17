--!strict
-- GhostService: HOST generik Ghost Encounter System (Phase 9, ADR-047/048). Server-authoritative.
--
-- Service ini hanya mengurus hal yang SAMA untuk semua hantu: memuat modul perilaku, membuat/menghapus body di dunia,
-- satu loop tick, menjaga jumlah instance (maxActive), dan jalur hukuman (FailureService). Aturan khas hantu
-- (kapan muncul, siapa dikejar, apa counter-nya, apa yang dirampas) ada di modul perilaku `server/Ghosts/<behavior>.luau`
-- dan angkanya di `Config/GhostConfig`.
--
-- Kontrak modul perilaku (lihat tipe Behavior):
--   init(host)              sekali saat boot: pasang pemicu (mis. CollectibleService.onCollected) dan panggil host.spawn
--   update(host, ghost, dt) tiap tick untuk setiap instance hidup milik perilaku itu
--   onDespawn(host, ghost, reason)  opsional, sebelum body dihapus
-- Modul perilaku memakai host yang dioper lewat parameter. Mereka boleh me-require GhostService HANYA untuk tipe
-- (Ghost/Host): aman karena GhostService baru me-require perilaku di init(), setelah modul ini selesai dimuat.
--
-- Hantu tidak bisa dilawan dan tidak memakai pathfinding di sini: gerak = helper host.move (melayang lurus).
-- Hukuman = host.punish -> FailureService.fail (jumpscare di layar korban, lalu knock/respawn sesuai kebijakan di FailureConfig).
-- Client hanya presentasi (jumpscare); body hantu direplikasi Roblox sebagai objek biasa.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("Config"):WaitForChild("GameConfig") :: ModuleScript)
local Log = require(Shared:WaitForChild("Util"):WaitForChild("Log") :: ModuleScript)
local Server = script.Parent.Parent
local Config = require(Server:WaitForChild("Config"):WaitForChild("GhostConfig") :: ModuleScript)
local Services = script.Parent
local FailureService = require(Services:WaitForChild("FailureService") :: ModuleScript)
local GameManager = require(Services:WaitForChild("GameManager") :: ModuleScript)

local TAG = "GhostService"
local PlayerState = GameConfig.PlayerState
local MAX_STEP = 0.25 -- detik; hitch panjang tidak boleh membuat hantu melompat jauh dalam satu update

export type Ghost = {
	id: string, -- id definisi (GhostConfig.Ghosts)
	def: Config.GhostDef,
	model: Model,
	root: BasePart,
	baseRotation: CFrame, -- rotasi root pada model ASLI (pose berdiri); gerak hanya menambah yaw di atasnya
	tracks: { [string]: AnimationTrack },
	age: number, -- detik sejak muncul
	phase: string, -- bebas, dikelola modul perilaku
	data: { [string]: any }, -- scratch milik modul perilaku
	alive: boolean,
}

export type Host = {
	spawn: (defId: string, at: CFrame) -> Ghost?,
	despawn: (ghost: Ghost, reason: string) -> (),
	despawnAll: (defId: string, reason: string) -> (),
	getActive: (defId: string) -> { Ghost },
	move: (ghost: Ghost, destination: Vector3, speed: number, dt: number, lookAt: Vector3?) -> (),
	playAnimation: (ghost: Ghost, name: string) -> boolean,
	stopAnimation: (ghost: Ghost, name: string) -> (),
	punish: (ghost: Ghost, player: Player, beforePunish: ((Player) -> ())?) -> boolean,
	param: (def: Config.GhostDef, name: string) -> number,
	presentation: (def: Config.GhostDef, name: string) -> number,
}

export type Behavior = {
	init: (host: Host) -> (),
	update: (host: Host, ghost: Ghost, dt: number) -> (),
	onDespawn: ((host: Host, ghost: Ghost, reason: string) -> ())?,
}

local GhostService = {}

local behaviors: { [string]: Behavior } = {}
local active: { [string]: { Ghost } } = {}
local warnedPlaceholder: { [string]: boolean } = {}
local initialized = false

local function getRuntimeFolder(): Folder
	local existing = Workspace:FindFirstChild(Config.RUNTIME_FOLDER)
	if existing and existing:IsA("Folder") then
		return existing
	end
	local folder = Instance.new("Folder")
	folder.Name = Config.RUNTIME_FOLDER
	folder.Parent = Workspace
	return folder
end

local function findRoot(model: Model): BasePart?
	if model.PrimaryPart then
		return model.PrimaryPart
	end
	local named = model:FindFirstChild("HumanoidRootPart")
	if named and named:IsA("BasePart") then
		return named
	end
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			return descendant
		end
	end
	return nil
end

-- Body PLACEHOLDER (dependency model belum ada): satu Part putih setengah transparan, hanya untuk menguji logika.
local function buildPlaceholder(def: Config.GhostDef): Model
	local model = Instance.new("Model")
	model.Name = def.id
	local part = Instance.new("Part")
	part.Name = "HumanoidRootPart"
	part.Size = Vector3.new(2, 6, 2)
	part.Color = Color3.fromRGB(235, 235, 240)
	part.Transparency = 0.35
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part:SetAttribute("Placeholder", true)
	part.Parent = model
	model.PrimaryPart = part
	return model
end

-- Cari Animator di model; bila ada Humanoid/AnimationController tanpa Animator, buat satu (server yang memutar animasi,
-- Roblox mereplikasi ke client). nil = model tidak punya rig animasi.
local function ensureAnimator(model: Model): Animator?
	local existing = model:FindFirstChildWhichIsA("Animator", true)
	if existing then
		return existing
	end
	local controller = model:FindFirstChildWhichIsA("Humanoid", true) or model:FindFirstChildWhichIsA("AnimationController", true)
	if controller then
		local animator = Instance.new("Animator")
		animator.Parent = controller
		return animator
	end
	return nil
end

local function hasAnimations(def: Config.GhostDef): boolean
	for _, id in def.animations do
		if id ~= "" then
			return true
		end
	end
	return false
end

-- Body dari ServerStorage/GhostModels/<modelName>; tanpa script, root di-anchor, tidak bertabrakan, tidak bisa disentuh.
-- Bila hantu punya animasi: bagian yang tersambung (Motor6D/Weld) ke root DILEPAS dari anchor (massless) agar animasi bisa
-- menggerakkannya; bagian yang tidak tersambung tetap di-anchor supaya tidak jatuh. Tanpa animasi = semua di-anchor (perilaku lama).
-- Mengembalikan model + rotasi root ASLI (pose berdiri) untuk dipertahankan saat spawn/gerak.
local function buildBody(def: Config.GhostDef): (Model?, CFrame)
	local source = ServerStorage:FindFirstChild(Config.MODEL_FOLDER)
	local template = source and source:FindFirstChild(def.modelName)
	if template and template:IsA("Model") then
		local model = template:Clone()
		local root = findRoot(model)
		if root then
			-- Baca SEBELUM menyentuh apa pun: ini rotasi model saat berdiri di Workspace.
			local look = root.CFrame.LookVector
			local authoredYaw = math.atan2(-look.X, -look.Z)
			local baseRotation = CFrame.Angles(0, -authoredYaw, 0) * root.CFrame.Rotation
			local animated = hasAnimations(def)
			local connected: { [Instance]: boolean } = {}
			for _, part in root:GetConnectedParts(true) do
				connected[part] = true
			end

			for _, descendant in model:GetDescendants() do
				if descendant:IsA("BaseScript") then
					descendant:Destroy()
				elseif descendant:IsA("BasePart") then
					descendant.Anchored = not (animated and descendant ~= root and connected[descendant] == true)
					descendant.CanCollide = false
					descendant.CanTouch = false
					descendant.CanQuery = false
				if descendant ~= root and connected[descendant] == true then
					descendant.Massless = true
				end
				elseif descendant:IsA("Humanoid") then
					descendant.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
				end
			end
			root.Anchored = true
			root.PivotOffset = CFrame.new() -- pivot = pusat part; offset rotasi dari Pivot Editor membuat model rebah saat PivotTo
			model.PrimaryPart = root
			Log.info(TAG, string.format("%s: rotasi model asli (derajat) = %s", def.id, tostring(root.Orientation)))
			return model, baseRotation
		end
		Log.warn(TAG, string.format("model %s tidak punya BasePart", def.modelName))
		model:Destroy()
	end

	if not Config.ALLOW_PLACEHOLDER_BODY then
		Log.warn(TAG, string.format("dependency belum ada: ServerStorage.%s.%s; %s tidak di-spawn", Config.MODEL_FOLDER, def.modelName, def.id))
		return nil, CFrame.new()
	end
	if not warnedPlaceholder[def.id] then
		warnedPlaceholder[def.id] = true
		Log.warn(
			TAG,
			string.format("dependency belum ada: ServerStorage.%s.%s; %s memakai body PLACEHOLDER", Config.MODEL_FOLDER, def.modelName, def.id)
		)
	end
	return buildPlaceholder(def), CFrame.new()
end

-- Parameter presentasi: nilai di def.params, jika tidak ada = default di GhostConfig.
local function presentationValue(def: Config.GhostDef, name: string): number
	local value = def.params[name]
	if typeof(value) == "number" then
		return value
	end
	return (Config.PRESENTATION_DEFAULTS :: { [string]: number })[name] or 0
end

local function attachSound(root: BasePart, def: Config.GhostDef, name: string, soundId: string?, looped: boolean, volumeParam: string)
	if soundId == nil or soundId == "" then
		return
	end
	local sound = Instance.new("Sound")
	sound.Name = name
	sound.SoundId = soundId
	sound.Looped = looped
	sound.Volume = presentationValue(def, volumeParam)
	sound.RollOffMaxDistance = presentationValue(def, "soundMaxDistance")
	sound.Parent = root
	sound:Play()
end

-- ===== Host (dipakai modul perilaku) =====

local host: Host = {} :: any

function host.spawn(defId: string, at: CFrame): Ghost?
	local def = Config.Ghosts[defId]
	local list = active[defId]
	if not def or not def.enabled or not list then
		Log.warn(TAG, "spawn ditolak: hantu tidak aktif/tidak dikenal: " .. tostring(defId))
		return nil
	end
	if #list >= def.maxActive then
		return nil
	end

	local model, baseRotation = buildBody(def)
	if not model then
		return nil
	end
	local root = findRoot(model)
	if not root then
		model:Destroy()
		return nil
	end

	-- Pertahankan pose asli model (berdiri): rotasi spawn point hanya menambah di atas rotasi asli.
	model:PivotTo(at * baseRotation)
	model:SetAttribute("GhostId", def.id)
	model.Parent = getRuntimeFolder()
	attachSound(root, def, "SpawnSound", def.sounds.spawn, false, "spawnVolume")
	attachSound(root, def, "LoopSound", def.sounds.loop, true, "loopVolume")

	local ghost: Ghost = {
		id = def.id,
		def = def,
		model = model,
		root = root,
		baseRotation = baseRotation,
		tracks = {},
		age = 0,
		phase = "NEW",
		data = {},
		alive = true,
	}
	table.insert(list, ghost)
	Log.info(TAG, string.format("%s muncul di %s", def.id, tostring(root.Position)))
	return ghost
end

function host.despawn(ghost: Ghost, reason: string)
	if not ghost.alive then
		return
	end
	ghost.alive = false

	local list = active[ghost.id]
	if list then
		local index = table.find(list, ghost)
		if index then
			table.remove(list, index)
		end
	end

	local behavior = behaviors[ghost.id]
	if behavior and behavior.onDespawn then
		local ok, err = pcall(behavior.onDespawn, host, ghost, reason)
		if not ok then
			Log.warn(TAG, string.format("onDespawn %s error: %s", ghost.id, tostring(err)))
		end
	end

	ghost.model:Destroy()
	Log.info(TAG, string.format("%s menghilang (%s)", ghost.id, reason))
end

function host.despawnAll(defId: string, reason: string)
	local list = active[defId]
	if not list then
		return
	end
	for _, ghost in table.clone(list) do
		host.despawn(ghost, reason)
	end
end

function host.getActive(defId: string): { Ghost }
	local list = active[defId]
	return if list then table.clone(list) else {}
end

-- Gerak melayang lurus (tanpa pathfinding, menembus dinding) menuju `destination` dengan kecepatan `speed` studs/detik.
-- Body menghadap `lookAt` (default = destination) secara mendatar agar tidak miring.
function host.move(ghost: Ghost, destination: Vector3, speed: number, dt: number, lookAt: Vector3?)
	local root = ghost.root
	local current = root.Position
	local delta = destination - current
	local distance = delta.Magnitude
	local newPosition = current
	if distance > 1e-3 then
		newPosition = current + delta.Unit * math.min(distance, speed * dt)
	end

	-- Hanya putar yaw (sumbu Y) lalu kalikan rotasi ASLI model. CFrame.lookAt murni akan MENIMPA rotasi asli sehingga
	-- model yang pivot/root-nya tidak sejajar sumbu dunia (mis. mesh impor) terlihat tertidur/rebah.
	local focus = lookAt or destination
	local flat = Vector3.new(focus.X, newPosition.Y, focus.Z)
	local cframe: CFrame
	if (flat - newPosition).Magnitude > 0.1 then
		local direction = flat - newPosition
		local yaw = math.atan2(-direction.X, -direction.Z) + math.rad(presentationValue(ghost.def, "facingYawDegrees"))
		cframe = CFrame.new(newPosition) * CFrame.Angles(0, yaw, 0) * ghost.baseRotation
	else
		cframe = CFrame.new(newPosition) * root.CFrame.Rotation
	end
	ghost.model:PivotTo(cframe)
end

-- Putar animasi bernama (key di GhostConfig animations) dengan LOOP. Return false bila tak ada ID / tak ada rig / gagal muat
-- (hantu tetap jalan tanpa animasi; hanya warning). Dipanggil berulang aman: animasi yang sudah main tidak diulang.
function host.playAnimation(ghost: Ghost, name: string): boolean
	local existing = ghost.tracks[name]
	if existing then
		if not existing.IsPlaying then
			existing:Play()
		end
		return true
	end
	local animationId = ghost.def.animations[name]
	if animationId == nil or animationId == "" then
		return false
	end
	local animator = ensureAnimator(ghost.model)
	if not animator then
		Log.warn(TAG, string.format("%s: animasi '%s' diset tetapi model tidak punya Humanoid/AnimationController", ghost.id, name))
		return false
	end
	local animation = Instance.new("Animation")
	animation.AnimationId = animationId
	local ok, trackOrErr = pcall(function()
		return animator:LoadAnimation(animation)
	end)
	if not ok then
		Log.warn(TAG, string.format("%s: gagal memuat animasi '%s': %s", ghost.id, name, tostring(trackOrErr)))
		return false
	end
	local track = trackOrErr :: AnimationTrack
	track.Looped = true
	track.Priority = Enum.AnimationPriority.Action
	track:Play(0.2, 1, presentationValue(ghost.def, "chaseAnimSpeed"))
	ghost.tracks[name] = track
	return true
end

function host.stopAnimation(ghost: Ghost, name: string)
	local track = ghost.tracks[name]
	if track then
		track:Stop(0.2)
		ghost.tracks[name] = nil
	end
end

function host.presentation(def: Config.GhostDef, name: string): number
	return presentationValue(def, name)
end

-- Jatuhkan hukuman pada `player`: hanya pemain berstatus NORMAL yang bisa dihukum (status lain = sudah ditangani sistem lain).
-- `beforePunish` dijalankan SEBELUM hukuman dan tanpa yield (mis. merampas item) agar atomik; bila melempar error,
-- error naik ke tick (hantu di-despawn) dan TIDAK ada hukuman. Return false bila pemain tidak valid untuk dihukum.
function host.punish(ghost: Ghost, player: Player, beforePunish: ((Player) -> ())?): boolean
	if player.Parent ~= Players then
		return false
	end
	if GameManager.getPlayerState(player) ~= PlayerState.NORMAL then
		return false
	end
	if beforePunish then
		beforePunish(player)
	end
	FailureService.fail(player, ghost.def.failureReason, ghost.def.questId)
	return true
end

-- Ambil angka dari GhostConfig; nilai yang hilang = kesalahan konfigurasi, gagal keras dan jelas (bukan nil diam-diam).
function host.param(def: Config.GhostDef, name: string): number
	local value = def.params[name]
	assert(typeof(value) == "number", string.format("[%s] %s: params.%s tidak ada di GhostConfig", TAG, def.id, name))
	return value
end

-- ===== Loop =====

local function tick(dt: number)
	for defId, list in active do
		local behavior = behaviors[defId]
		if behavior and #list > 0 then
			for _, ghost in table.clone(list) do
				if ghost.alive then
					ghost.age += dt
					local ok, err = pcall(behavior.update, host, ghost, dt)
					if not ok then
						Log.warn(TAG, string.format("update %s error: %s", defId, tostring(err)))
						host.despawn(ghost, "ERROR")
					end
				end
			end
		end
	end
end

-- Muat satu modul perilaku. Gagal = hantu itu dilewati (warning), hantu lain dan game tetap jalan.
local function loadBehavior(def: Config.GhostDef): boolean
	local folder = Server:FindFirstChild("Ghosts")
	local moduleScript = folder and folder:FindFirstChild(def.behavior)
	if not moduleScript or not moduleScript:IsA("ModuleScript") then
		Log.warn(TAG, string.format("modul perilaku %s tidak ditemukan di Server/Ghosts; %s dilewati", def.behavior, def.id))
		return false
	end

	local okRequire, loaded = pcall(require, moduleScript)
	if not okRequire then
		Log.warn(TAG, string.format("gagal memuat perilaku %s: %s", def.behavior, tostring(loaded)))
		return false
	end
	local behavior = loaded :: Behavior
	if type(behavior) ~= "table" or type(behavior.init) ~= "function" or type(behavior.update) ~= "function" then
		Log.warn(TAG, string.format("perilaku %s tidak memenuhi kontrak (init/update); %s dilewati", def.behavior, def.id))
		return false
	end

	behaviors[def.id] = behavior
	active[def.id] = {}
	local okInit, err = pcall(behavior.init, host)
	if not okInit then
		Log.warn(TAG, string.format("init perilaku %s error: %s", def.behavior, tostring(err)))
		behaviors[def.id] = nil
		active[def.id] = nil
		return false
	end
	return true
end

function GhostService.getActive(defId: string): { Ghost }
	return host.getActive(defId)
end

function GhostService.despawnAll(defId: string, reason: string)
	host.despawnAll(defId, reason)
end

function GhostService.init()
	assert(not initialized, "GhostService.init sudah dipanggil")
	initialized = true

	local loaded: { string } = {}
	for _, defId in Config.ORDER do
		local def = Config.Ghosts[defId]
		if not def then
			Log.warn(TAG, "GhostConfig.ORDER memuat id yang tidak ada: " .. tostring(defId))
		elseif def.enabled and loadBehavior(def) then
			table.insert(loaded, defId)
		end
	end

	local accumulated = 0
	RunService.Heartbeat:Connect(function(dt: number)
		accumulated += dt
		if accumulated < Config.TICK_INTERVAL then
			return
		end
		local step = math.min(accumulated, MAX_STEP)
		accumulated = 0
		tick(step)
	end)

	Log.info(TAG, string.format("siap, %d hantu dimuat: %s", #loaded, table.concat(loaded, ", ")))
end

return table.freeze(GhostService)
