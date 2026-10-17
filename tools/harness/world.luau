-- Rakit dunia uji: modul asli dari SOURCES + mock service Roblox-spesifik + peta uji.
local KELOR_SPAWN_POS = {
	K1 = V3.new(0, 0, 0), K2 = V3.new(100, 0, 0), K3 = V3.new(0, 0, 200), K4 = V3.new(300, 0, 300),
	K5 = V3.new(-150, 0, 50), K6 = V3.new(60, 0, -120), K7 = V3.new(200, 0, 100), K8 = V3.new(-80, 0, -200),
}
local GHOST_SPAWN_POS = {
	KS1 = V3.new(10, 0, 10), KS2 = V3.new(110, 0, 10), KS3 = V3.new(0, 0, 215), KS4 = V3.new(310, 0, 310),
}

local function buildWorld(opts)
	opts = opts or {}
	local W, H = newWorldBase()
	local get = H.get
	W.get = get

	-- Modul ASLI
	local function real(parent, name, path) H.addSource(parent, name, SOURCES[path]) end
	real(H.SharedConfig, "GameConfig", "shared/Config/GameConfig")
	real(H.SharedConfig, "QuestConfig", "shared/Config/QuestConfig")
	real(H.SharedConfig, "CollectionConfig", "shared/Config/CollectionConfig")
	real(H.SharedConfig, "ItemConfig", "shared/Config/ItemConfig")
	real(H.SharedUtil, "Log", "shared/Util/Log")
	real(H.SharedUtil, "Spatial", "shared/Util/Spatial")
	real(H.ServerConfig, "GhostConfig", "server/Config/GhostConfig")
	real(H.ServerConfig, "FailureConfig", "server/Config/FailureConfig")
	real(H.ServerConfig, "KnockConfig", "server/Config/KnockConfig")
	real(H.Services, "GameManager", "server/Services/GameManager")
	real(H.Services, "QuestService", "server/Services/QuestService")
	real(H.Services, "CollectibleService", "server/Services/CollectibleService")
	real(H.Services, "FailureService", "server/Services/FailureService")
	real(H.Services, "GhostService", "server/Services/GhostService")
	real(H.Services, "PartyService", "server/Services/PartyService")
	real(H.Ghosts, "Kuntilanak", "server/Ghosts/Kuntilanak")

	-- Mock
	local Players = H.PlayersSvc
	H.addMock(H.Services, "NoticeService", function()
		return {
			send = function(p, t) table.insert(W.notices, { to = p, text = t }) end,
			broadcast = function(t) table.insert(W.broadcasts, t) end,
			notifyParty = function(actor, selfText, othersText)
				for _, m in Players:GetPlayers() do
					table.insert(W.notices, { to = m, text = if m == actor then selfText else othersText })
				end
			end,
		}
	end)
	H.addMock(H.Services, "JumpscareService", function()
		return { play = function(p, ghostId) table.insert(W.jumpscares, { player = p, ghostId = ghostId }) return true end }
	end)
	H.addMock(H.Services, "InteractionService", function()
		return { register = function(id, handler) W.handlers[id] = handler end }
	end)
	-- Item: hitungan per pemain; Backpack direset saat respawn (ADR-018).
	local items = {}
	W.items = items
	H.addMock(H.Services, "ItemService", function()
		local S = {}
		function S.getTemplate(id) return { template = id } end
		function S.give(p, id, n) items[p] = items[p] or {} items[p][id] = (items[p][id] or 0) + (n or 1) return true end
		function S.count(p, id) return (items[p] and items[p][id]) or 0 end
		function S.has(p, id, n) return S.count(p, id) >= (n or 1) end
		function S.consume(p, id, n)
			n = n or 1
			if S.count(p, id) < n then return false end
			items[p][id] -= n
			return true
		end
		function S.isHeld(p, id) return S.count(p, id) > 0 end
		return S
	end)
	-- RandomSpawn: pilih titik acak dari container, pickup = Model bertanda.
	local runtime = H.folder(H.Workspace, "QuestRuntime")
	H.addMock(H.Services, "RandomSpawnService", function()
		local S = {}
		function S.getRuntimeFolder() return runtime end
		function S.pickSpawns(container, count, exclude)
			local c = {}
			for _, ch in container:GetChildren() do
				if not (exclude and exclude[ch]) then table.insert(c, ch) end
			end
			table.sort(c, function(a, b) return a.Name < b.Name end)
			count = math.min(count, #c)
			for i = 1, count do
				local j = math.random(i, #c)
				c[i], c[j] = c[j], c[i]
			end
			local out = {}
			for i = 1, count do out[i] = c[i] end
			return out
		end
		function S.createPickup(template, spawn, parent, info)
			local m = newInstance("Model", "Pickup_" .. spawn.Name)
			local part = newInstance("Part", "Handle")
			part.Parent = m
			m.PrimaryPart = part
			part.Position = spawn.Position
			m:SetAttribute("InteractionId", info.interactionId)
			rawset(m, "_spawn", spawn)
			m.Parent = parent
			return m
		end
		return S
	end)
	-- Knock: perilaku inti saja (state NORMAL -> KNOCKED lewat GameManager asli).
	H.addMock(H.Services, "KnockService", function()
		local S = {}
		local down = {}
		function S.knock(p, reason)
			local gm = get("GameManager")
			if gm.getPlayerState(p) ~= "NORMAL" then return false end
			gm.setPlayerState(p, "KNOCKED")
			down[p] = true
			table.insert(W.knocks, { player = p, reason = reason })
			return true
		end
		function S.isKnocked(p) return down[p] == true end
		return S
	end)

	-- Peta
	local QO = H.folder(H.Workspace, "QuestObjects")
	local KS = H.folder(QO, "KelorSpawns")
	for name, pos in KELOR_SPAWN_POS do
		local p = newInstance("Part", name) p.Position = pos p.Parent = KS
	end
	if not opts.noGhostSpawns then
		local GS = H.folder(QO, "KuntilanakSpawn")
		for name, pos in GHOST_SPAWN_POS do
			local p = newInstance("Part", name) p.Position = pos p.Parent = GS
		end
	end

	-- Pemain
	function W.addPlayer(name, pos)
		local pl = newInstance("Player", name)
		pl.Parent = Players
		local bp = newInstance("Backpack", "Backpack") bp.Parent = pl
		local ch = newInstance("Model", name)
		local hum = newInstance("Humanoid", "Humanoid") hum.Health = 100 hum.Parent = ch
		local root = newInstance("Part", "HumanoidRootPart") root.Position = pos root.Parent = ch
		ch.PrimaryPart = root
		pl.Character = ch
		pl.LoadCharacter = function(self)
			W.respawns[self] = (W.respawns[self] or 0) + 1
			items[self] = {} -- Backpack reset
			self.Character:FindFirstChild("HumanoidRootPart").Position = V3.new(0, 0, -400) -- titik respawn
		end
		Players.PlayerAdded:Fire(pl)
		return pl
	end
	function W.setPos(pl, pos) pl.Character:FindFirstChild("HumanoidRootPart").Position = pos end
	function W.pos(pl) return pl.Character:FindFirstChild("HumanoidRootPart").Position end
	function W.leave(pl)
		Players.PlayerRemoving:Fire(pl)
		pl.Parent = nil
	end
	function W.step(dt, n, onStep)
		for i = 1, n do
			if onStep then onStep(i, dt) end
			H.RunSvc.Heartbeat:Fire(dt)
		end
	end

	-- Boot (urutan seperti init.server): GameManager, QuestService, CollectibleService, GhostService
	get("GameManager").init()
	get("QuestService").init()
	get("CollectibleService").init()
	get("FailureService").init()
	get("GhostService").init()
	W.P = H.req(H.ServerConfig:WaitForChild("GhostConfig")).Ghosts.Kuntilanak.params
	W.Q = get("QuestService")
	W.GM = get("GameManager")
	W.Items = get("ItemService")
	W.Ghost = get("GhostService")
	W.Failure = get("FailureService")
	W.Collect = get("CollectibleService")

	function W.startKelor()
		assert(W.Q.activate("KERIS"))
		assert(W.Q.transition("KERIS", "SEARCHING_KELOR"))
	end
	function W.pickups()
		local out = {}
		for _, m in runtime:GetChildren() do
			if m:GetAttribute("InteractionId") == "Kelor" then table.insert(out, m) end
		end
		table.sort(out, function(a, b) return a.Name < b.Name end)
		return out
	end
	function W.pickup(pl, model)
		model = model or W.pickups()[1]
		W.handlers.Kelor(pl, model)
		return model
	end
	function W.ghostList() return W.Ghost.getActive("Kuntilanak") end
	function W.held(pl) return W.Items.count(pl, "DaunKelor") end
	-- Invarian Kelor: counter party == total Kelor di tangan pemain; pickup di dunia == target - counter (selama SEARCHING_KELOR).
	function W.invariant()
		local counter = W.Q.getCounter("KERIS", "Kelor")
		local total = 0
		for _, p in Players:GetPlayers() do total += W.held(p) end
		local ok1 = (counter == total)
		local ok2 = true
		if W.Q.getState("KERIS") == "SEARCHING_KELOR" then ok2 = (#W.pickups() == 4 - counter) end
		return ok1 and ok2, string.format("counter=%d held=%d worldPickups=%d", counter, total, #W.pickups())
	end
	return W
end
