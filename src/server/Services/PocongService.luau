--!nonstrict
-- PocongService (Phase 9.3, ADR-048). SERVER-AUTHORITATIVE, non-combat.
--
-- Aturan:
--  * Satu Pocong muncul di titik Workspace.PocongSpawn tiap bunga dipetik (onFlowerCollected).
--  * Pocong HANYA mengejar pemain yang memegang bunga (Backpack / dipegang). Lainnya diabaikan.
--  * Zona obor (TorchCounter): Pocong tidak bisa masuk zona dan tidak bisa mengknock pemain di dalamnya.
--    Kalau semua pemegang bunga ada di zona -> Pocong mundur lalu menunggu.
--    Begitu ada pemegang bunga di luar zona -> Pocong mengejar lagi.
--  * Tidak ada pemegang bunga selama NO_TARGET_GRACE_SECONDS -> Pocong tenggelam.
--
-- Dependensi API proyek disuntik lewat PocongService.configure(...) supaya modul ini tidak
-- menebak nama fungsi service lain. Lihat contoh pemasangan di .ai/ADR-048_POCONG_TORCH_COUNTER.md.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

-- ASUMSI: src/shared dipetakan Rojo ke ReplicatedStorage.Shared (sesuaikan bila berbeda)
local CFG = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("PocongConfig"))

local PocongService = {}

-- ============================================================
-- Dependensi (disuntik)
-- ============================================================
local knockFn = nil -- (player: Player, reason: string) -> ()
local isPlayerNormalFn = nil -- (player: Player) -> boolean   (default: Humanoid hidup)
local hasFlowerFn = nil -- (player: Player) -> boolean        (default: pindai Tool bunga)

function PocongService.configure(opts)
	knockFn = opts.knock or knockFn
	isPlayerNormalFn = opts.isPlayerNormal or isPlayerNormalFn
	hasFlowerFn = opts.hasFlower or hasFlowerFn
end

-- ============================================================
-- State
-- ============================================================
local active = {}
local nextId = 0
local lastKnockAt = {}
local connection = nil
local holderPlayers = {}
local lastHolderRefresh = -math.huge
local warnedPlaceholder = false

local lastTriggerAt = {}
local seenTools = setmetatable({}, { __mode = "k" })
local watchedContainers = setmetatable({}, { __mode = "k" })

-- Pencocokan longgar: huruf kecil, buang spasi/simbol. "Mawar Merah" == "MawarMerah" == "kembang_mawar_merah".
local function normalize(text)
	return (string.lower(text):gsub("[^%w]", ""))
end

local FLOWER_NORMALIZED = {}
for _, key in CFG.FLOWER_KEYS do
	table.insert(FLOWER_NORMALIZED, normalize(key))
end

local function matchesFlowerKey(text)
	local n = normalize(text)
	if n:find("hitam", 1, true) then
		return false -- Kembang Kantil Hitam = hadiah, bukan bunga yang dicari
	end
	for _, key in FLOWER_NORMALIZED do
		if n:find(key, 1, true) then
			return true
		end
	end
	return false
end

-- ============================================================
-- Util
-- ============================================================
local function flat(v)
	return Vector3.new(v.X, 0, v.Z)
end

local function safeUnit(v)
	local m = v.Magnitude
	if m < 0.01 then
		return nil
	end
	return v / m
end

local function getRoot(player)
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart")
end

local function isAlive(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	return humanoid ~= nil and humanoid.Health > 0
end

local function isEligible(player)
	if not getRoot(player) or not isAlive(player) then
		return false
	end
	if isPlayerNormalFn and not isPlayerNormalFn(player) then
		return false
	end
	return true
end

local function isFlowerTool(tool)
	if not tool:IsA("Tool") then
		return false
	end
	local id = tool:GetAttribute("ItemId")
	if typeof(id) == "string" and matchesFlowerKey(id) then
		return true
	end
	return matchesFlowerKey(tool.Name)
end

local function defaultHasFlower(player)
	local backpack = player:FindFirstChildOfClass("Backpack")
	if backpack then
		for _, child in backpack:GetChildren() do
			if isFlowerTool(child) then
				return true
			end
		end
	end
	local character = player.Character
	if character then
		for _, child in character:GetChildren() do
			if isFlowerTool(child) then
				return true
			end
		end
	end
	return false
end

local function playerHoldsFlower(player)
	if hasFlowerFn then
		return hasFlowerFn(player)
	end
	return defaultHasFlower(player)
end

local function getGhostFolder()
	local folder = Workspace:FindFirstChild(CFG.GHOST_FOLDER)
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = CFG.GHOST_FOLDER
		folder.Parent = Workspace
	end
	return folder
end

-- ============================================================
-- Titik spawn & obor (dibaca dari Workspace tiap dipakai; jumlahnya kecil)
-- ============================================================
local function toEntry(inst)
	if inst:IsA("BasePart") then
		return { inst = inst, pos = inst.Position }
	elseif inst:IsA("Model") then
		return { inst = inst, pos = inst:GetPivot().Position }
	elseif inst:IsA("Attachment") then
		return { inst = inst, pos = inst.WorldPosition }
	end
	return nil
end

local function debugLog(...)
	if CFG.DEBUG_LOG then
		print("[PocongService]", ...)
	end
end

-- Cari container: path persis dari Workspace dulu, lalu pencarian rekursif berdasar nama.
local function findContainer(path, name)
	local node = Workspace
	for _, part in path do
		node = node and node:FindFirstChild(part)
	end
	if node and node ~= Workspace then
		return node
	end
	return Workspace:FindFirstChild(name, true)
end

local function getSpawnPoints()
	local list = {}
	local container = findContainer(CFG.SPAWN_PATH, CFG.SPAWN_CONTAINER)
	if not container then
		return list
	end
	for _, child in container:GetChildren() do
		local entry = toEntry(child)
		if entry then
			table.insert(list, entry)
		end
	end
	if #list == 0 then
		local entry = toEntry(container)
		if entry then
			table.insert(list, entry)
		end
	end
	return list
end

local function getTorches()
	local torches = {}
	local seen = {}

	local function add(inst)
		if seen[inst] then
			return
		end
		local entry = toEntry(inst)
		if not entry then
			return
		end
		seen[inst] = true
		local radius = inst:GetAttribute(CFG.TORCH_RADIUS_ATTRIBUTE)
		if typeof(radius) ~= "number" then
			radius = CFG.TORCH_DEFAULT_RADIUS
		end
		table.insert(torches, { pos = entry.pos, radius = radius })
	end

	local container = findContainer(CFG.TORCH_PATH, CFG.TORCH_CONTAINER)
	if container then
		if container:IsA("Folder") then
			for _, child in container:GetChildren() do
				if child:IsA("Folder") then
					for _, grandChild in child:GetChildren() do
						add(grandChild)
					end
				else
					add(child)
				end
			end
		elseif container:IsA("Model") and #container:GetChildren() > 0 and not container.PrimaryPart then
			-- Model berisi banyak obor
			local hasModelChild = false
			for _, child in container:GetChildren() do
				if child:IsA("Model") then
					hasModelChild = true
					add(child)
				end
			end
			if not hasModelChild then
				add(container)
			end
		else
			add(container)
		end
	end
	for _, tagged in CollectionService:GetTagged(CFG.TORCH_TAG) do
		add(tagged)
	end
	return torches
end

local function inAnyZone(position, torches)
	for _, torch in torches do
		if (position - torch.pos).Magnitude <= torch.radius then
			return true
		end
	end
	return false
end

-- ============================================================
-- Model
-- ============================================================
local function resolveTemplate()
	local path = CFG.MODEL_PATH
	local node = game:GetService(path[1])
	for i = 2, #path do
		node = node and node:FindFirstChild(path[i])
	end
	if node and node:IsA("Model") then
		return node
	end
	return nil
end

local function createModel()
	local template = resolveTemplate()
	local model
	if template then
		model = template:Clone()
	else
		if not warnedPlaceholder then
			warnedPlaceholder = true
			warn("[PocongService] Template model tidak ditemukan di " .. table.concat(CFG.MODEL_PATH, ".") .. "; memakai placeholder")
		end
		model = Instance.new("Model")
		local body = Instance.new("Part")
		body.Name = "Body"
		body.Size = Vector3.new(3, 6, 3)
		body.Color = Color3.fromRGB(235, 235, 225)
		body.Material = Enum.Material.Fabric
		body.Parent = model
		model.PrimaryPart = body
	end
	model.Name = "Pocong"
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanTouch = false
			d.CanQuery = false
		end
	end
	return model
end

-- ============================================================
-- Pocong
-- ============================================================
local function setState(p, state)
	if p.state ~= state then
		p.state = state
		p.model:SetAttribute("PocongState", state) -- untuk audio/efek client nanti
	end
end

local function applyPose(p, hopOffset)
	local origin = p.pos + Vector3.new(0, p.pivotOffsetY + hopOffset, 0)
	p.model:PivotTo(CFrame.lookAt(origin, origin + p.facing))
end

local function resetHop(p)
	p.hopPhase = "PAUSE"
	p.hopUntil = 0
end

local function snapToGround(pos, params)
	local result = Workspace:Raycast(
		pos + Vector3.new(0, CFG.GROUND_RAY_UP, 0),
		Vector3.new(0, -(CFG.GROUND_RAY_UP + CFG.GROUND_RAY_DOWN), 0),
		params
	)
	if result then
		return result.Position
	end
	return pos
end

local function spawnPocong(entry, picker)
	local model = createModel()
	local _, size = model:GetBoundingBox()

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { model, getGhostFolder() }

	nextId += 1
	local p = {
		id = nextId,
		model = model,
		spawnInst = entry.inst,
		state = "SPAWNING",
		stateUntil = os.clock() + CFG.SPAWN_TELEGRAPH_SECONDS,
		pos = snapToGround(entry.pos, params),
		facing = Vector3.new(0, 0, -1),
		pivotOffsetY = size.Y / 2,
		hopPhase = "PAUSE",
		hopUntil = 0,
		hopStart = 0,
		noTargetSince = nil,
		target = nil,
	}

	local root = picker and getRoot(picker)
	if root then
		local dir = safeUnit(flat(root.Position - p.pos))
		if dir then
			p.facing = dir
		end
	end

	model:SetAttribute("PocongState", "SPAWNING")
	applyPose(p, 0)
	model.Parent = getGhostFolder()
	table.insert(active, p)
	return p
end

local function tryCatch(p, player, now)
	local last = lastKnockAt[player]
	if last and now - last < CFG.KNOCK_COOLDOWN_SECONDS then
		return
	end
	lastKnockAt[player] = now
	if knockFn then
		local ok, err = pcall(knockFn, player, "GHOST")
		if not ok then
			warn("[PocongService] knock gagal: " .. tostring(err))
		end
	else
		warn("[PocongService] knock belum dipasang lewat configure(); pemain tidak di-knock")
	end
	setState(p, "PAUSED")
	p.stateUntil = now + CFG.POST_KNOCK_PAUSE_SECONDS
end

-- Gerak melompat berirama. Mengembalikan offset tinggi lompatan. Tidak pernah MASUK zona obor.
local function movePocong(p, dir, speed, dt, now, torches)
	if now >= p.hopUntil then
		if p.hopPhase == "MOVE" then
			p.hopPhase = "PAUSE"
			p.hopUntil = now + CFG.HOP_PAUSE_SECONDS
		else
			p.hopPhase = "MOVE"
			p.hopUntil = now + CFG.HOP_MOVE_SECONDS
			p.hopStart = now
		end
	end
	if p.hopPhase ~= "MOVE" then
		return 0
	end

	p.facing = dir
	local nextPos = p.pos + dir * speed * dt
	if not (inAnyZone(nextPos, torches) and not inAnyZone(p.pos, torches)) then
		p.pos = nextPos
	end
	local progress = math.clamp((now - p.hopStart) / CFG.HOP_MOVE_SECONDS, 0, 1)
	return math.sin(math.pi * progress) * CFG.HOP_HEIGHT
end

-- Mengembalikan true bila Pocong harus dihapus.
local function stepPocong(p, now, dt, holders, torches, rayParams)
	if p.state == "SINKING" then
		p.pos = p.pos - Vector3.new(0, CFG.SINK_SPEED * dt, 0)
		applyPose(p, 0)
		return now >= p.stateUntil
	end

	if p.state == "SPAWNING" or p.state == "PAUSED" then
		if now < p.stateUntil then
			resetHop(p)
			applyPose(p, 0)
			return false
		end
		setState(p, "CHASE")
	end

	if #holders == 0 then
		p.noTargetSince = p.noTargetSince or now
		if now - p.noTargetSince >= CFG.NO_TARGET_GRACE_SECONDS then
			debugLog("Pocong", p.id, "tenggelam: tidak ada pemegang bunga yang valid (Tool bunga tidak terdeteksi / pemain knock)")
			setState(p, "SINKING")
			p.stateUntil = now + CFG.SINK_SECONDS
			return false
		end
		setState(p, "WAIT")
		resetHop(p)
		applyPose(p, 0)
		return false
	end
	p.noTargetSince = nil

	local nearestOut, distOut = nil, math.huge
	local nearestIn, distIn = nil, math.huge
	for _, h in holders do
		local d = (h.pos - p.pos).Magnitude
		if h.inZone then
			if d < distIn then
				nearestIn, distIn = h, d
			end
		elseif d < distOut then
			nearestOut, distOut = h, d
		end
	end

	local hop = 0
	if nearestOut then
		-- Ada pemegang bunga di luar zona -> kejar
		setState(p, "CHASE")
		p.target = nearestOut.player
		if distOut <= CFG.CATCH_RADIUS then
			tryCatch(p, nearestOut.player, now)
			applyPose(p, 0)
			return false
		end
		local dir = safeUnit(flat(nearestOut.pos - p.pos))
		if dir then
			hop = movePocong(p, dir, CFG.MOVE_SPEED, dt, now, torches)
		end
	else
		-- Semua pemegang bunga ada di zona obor -> menjauh lalu menunggu
		p.target = nearestIn.player
		if flat(nearestIn.pos - p.pos).Magnitude < CFG.RETREAT_DISTANCE then
			setState(p, "RETREAT")
			local away = safeUnit(flat(p.pos - nearestIn.pos)) or p.facing
			hop = movePocong(p, away, CFG.MOVE_SPEED * CFG.RETREAT_SPEED_MULTIPLIER, dt, now, torches)
		else
			setState(p, "WAIT")
			resetHop(p)
		end
	end

	p.pos = snapToGround(p.pos, rayParams)
	applyPose(p, hop)
	return false
end

-- ============================================================
-- Loop
-- ============================================================
local function buildHolders(now, torches)
	if now - lastHolderRefresh >= CFG.HOLDER_REFRESH_SECONDS then
		lastHolderRefresh = now
		holderPlayers = {}
		for _, player in Players:GetPlayers() do
			if playerHoldsFlower(player) then
				table.insert(holderPlayers, player)
			end
		end
	end
	local list = {}
	for _, player in holderPlayers do
		if player.Parent and isEligible(player) then
			local pos = getRoot(player).Position
			table.insert(list, { player = player, pos = pos, inZone = inAnyZone(pos, torches) })
		end
	end
	return list
end

local function onHeartbeat(dt)
	if #active == 0 then
		return
	end
	local now = os.clock()
	local torches = getTorches()
	local holders = buildHolders(now, torches)

	local filter = { getGhostFolder() }
	for _, player in Players:GetPlayers() do
		if player.Character then
			table.insert(filter, player.Character)
		end
	end
	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.FilterDescendantsInstances = filter

	for i = #active, 1, -1 do
		local p = active[i]
		if not p.model.Parent then
			table.remove(active, i)
		elseif stepPocong(p, now, dt, holders, torches, rayParams) then
			p.model:Destroy()
			table.remove(active, i)
		end
	end
end

-- ============================================================
-- API publik
-- ============================================================

-- Panggil SERVER-SIDE tepat setelah bunga berhasil diberikan ke pemain (setelah validasi + ItemService.give).
-- Mengembalikan true bila sebuah Pocong dimunculkan.
function PocongService.onFlowerCollected(picker)
	debugLog("onFlowerCollected dipanggil oleh", picker and picker.Name or "nil", "| aktif:", #active)
	if picker then
		local nowTrigger = os.clock()
		local lastTrigger = lastTriggerAt[picker]
		if lastTrigger and nowTrigger - lastTrigger < CFG.TRIGGER_DEDUPE_SECONDS then
			debugLog("diabaikan: pemicu ganda <", CFG.TRIGGER_DEDUPE_SECONDS, "dtk")
			return false
		end
		lastTriggerAt[picker] = nowTrigger
	end
	if #active >= CFG.MAX_ACTIVE then
		debugLog("batal: MAX_ACTIVE tercapai")
		return false
	end
	local points = getSpawnPoints()
	if #points == 0 then
		warn("[PocongService] Titik spawn tidak ditemukan (dicari: Workspace." .. table.concat(CFG.SPAWN_PATH, ".") .. " lalu nama '" .. CFG.SPAWN_CONTAINER .. "'); Pocong tidak muncul")
		return false
	end
	debugLog("titik spawn ditemukan:", #points)

	local occupied = {}
	for _, p in active do
		occupied[p.spawnInst] = true
	end

	local pickerRoot = picker and getRoot(picker)
	local free, farEnough = {}, {}
	for _, entry in points do
		if not occupied[entry.inst] then
			table.insert(free, entry)
			if not pickerRoot or (entry.pos - pickerRoot.Position).Magnitude >= CFG.MIN_SPAWN_DISTANCE then
				table.insert(farEnough, entry)
			end
		end
	end
	if #free == 0 then
		return false
	end

	local chosen
	if #farEnough > 0 then
		chosen = farEnough[math.random(1, #farEnough)]
	else
		chosen = free[1]
		for _, entry in free do
			if (entry.pos - pickerRoot.Position).Magnitude > (chosen.pos - pickerRoot.Position).Magnitude then
				chosen = entry
			end
		end
	end

	local spawned = spawnPocong(chosen, picker)
	debugLog("Pocong spawn di", chosen.inst:GetFullName(), "| id:", spawned.id)
	return true
end

-- Hapus semua Pocong sekarang (party wipe / reset quest KANTIL / quest selesai).
function PocongService.reset()
	for i = #active, 1, -1 do
		active[i].model:Destroy()
		active[i] = nil
	end
	table.clear(lastKnockAt)
end

function PocongService.getActiveCount()
	return #active
end

-- Pemantau Tool bunga: pemicu spawn mandiri (tidak bergantung pada wiring CollectibleService).
local function onToolAdded(player, tool)
	if not tool:IsA("Tool") then
		return
	end
	local isFlower = isFlowerTool(tool)
	debugLog("Tool masuk ke", player.Name, "| nama:", tool.Name, "| ItemId:", tool:GetAttribute("ItemId"), "| bunga?", isFlower)
	if not isFlower or seenTools[tool] then
		return
	end
	seenTools[tool] = true
	PocongService.onFlowerCollected(player)
end

local function watchContainer(player, container)
	if watchedContainers[container] then
		return
	end
	watchedContainers[container] = true
	container.ChildAdded:Connect(function(child)
		onToolAdded(player, child)
	end)
	for _, child in container:GetChildren() do
		if child:IsA("Tool") and isFlowerTool(child) then
			seenTools[child] = true -- sudah dipegang sebelum pemantau aktif: tidak memicu spawn
		end
	end
end

local function watchPlayer(player)
	local function watchBackpack()
		local backpack = player:WaitForChild("Backpack", 10)
		if backpack then
			watchContainer(player, backpack)
		end
	end
	task.spawn(watchBackpack)
	local function onCharacter(character)
		watchContainer(player, character)
		task.spawn(watchBackpack) -- Backpack dibuat ulang saat respawn
	end
	player.CharacterAdded:Connect(onCharacter)
	if player.Character then
		onCharacter(player.Character)
	end
end

function PocongService.start()
	if connection then
		return
	end
	if CFG.WATCH_BACKPACK then
		for _, player in Players:GetPlayers() do
			watchPlayer(player)
		end
		Players.PlayerAdded:Connect(watchPlayer)
	end
	debugLog("start() | spawn:", #getSpawnPoints(), "| obor:", #getTorches(), "| template model:", resolveTemplate() ~= nil)
	getGhostFolder()
	connection = RunService.Heartbeat:Connect(onHeartbeat)
	Players.PlayerRemoving:Connect(function(player)
		lastKnockAt[player] = nil
	end)
end

return PocongService
