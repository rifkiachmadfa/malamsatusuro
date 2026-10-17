-- Harness offline: menjalankan modul ASLI repo di atas mock Roblox minimal (tanpa Studio).
-- Yang asli: GameManager, QuestService, CollectibleService, FailureService, GhostService, Ghosts/Kuntilanak,
--            PartyService, semua Config, Log, Spatial. Yang dimock: Jumpscare/Knock/Notice/Item/Interaction/RandomSpawn.

local OUT = {}
local function emit(line) table.insert(OUT, line) end

-- ===== Vector3 / CFrame =====
local V3 = {}
local V3mt = {}
V3mt.__index = function(v, k)
	if k == "Magnitude" then
		return math.sqrt(v.X * v.X + v.Y * v.Y + v.Z * v.Z)
	elseif k == "Unit" then
		local m = math.sqrt(v.X * v.X + v.Y * v.Y + v.Z * v.Z)
		return V3.new(v.X / m, v.Y / m, v.Z / m)
	end
	return nil
end
V3mt.__add = function(a, b) return V3.new(a.X + b.X, a.Y + b.Y, a.Z + b.Z) end
V3mt.__sub = function(a, b) return V3.new(a.X - b.X, a.Y - b.Y, a.Z - b.Z) end
V3mt.__mul = function(a, b)
	if type(a) == "number" then return V3.new(a * b.X, a * b.Y, a * b.Z) end
	if type(b) == "number" then return V3.new(a.X * b, a.Y * b, a.Z * b) end
	return V3.new(a.X * b.X, a.Y * b.Y, a.Z * b.Z)
end
V3mt.__eq = function(a, b) return a.X == b.X and a.Y == b.Y and a.Z == b.Z end
V3mt.__tostring = function(v) return string.format("(%.1f, %.1f, %.1f)", v.X, v.Y, v.Z) end
function V3.new(x, y, z) return setmetatable({ X = x or 0, Y = y or 0, Z = z or 0, __isV3 = true }, V3mt) end
V3.zero = V3.new(0, 0, 0)

local CF = {}
local CFmt = {}
CFmt.__index = function(c, k)
	if k == "Rotation" then return setmetatable({ Position = V3.zero }, CFmt) end
	if k == "LookVector" then return V3.new(0, 0, -1) end
	return nil
end
CFmt.__mul = function(a, b) return setmetatable({ Position = a.Position }, CFmt) end
function CF.new(p, y, z)
	if type(p) == "number" then p = V3.new(p, y, z) end
	return setmetatable({ Position = p or V3.zero, __isCF = true }, CFmt)
end
function CF.lookAt(a, b) return setmetatable({ Position = a }, CFmt) end
function CF.Angles(_x, _y, _z) return setmetatable({ Position = V3.zero }, CFmt) end

-- ===== Signal =====
local function newSignal()
	local s = { handlers = {} }
	function s:Connect(fn)
		local c = { fn = fn, on = true }
		table.insert(self.handlers, c)
		return { Disconnect = function() c.on = false end }
	end
	function s:Fire(...)
		for _, c in self.handlers do
			if c.on then c.fn(...) end
		end
	end
	return s
end

-- ===== Instance =====
local PARENT_CLASS = {
	Part = "BasePart", BasePart = "PVInstance", Model = "PVInstance", PVInstance = "Instance",
	Folder = "Instance", Humanoid = "Instance", ModuleScript = "Instance", Player = "Instance",
	Players = "Instance", Backpack = "Instance", Tool = "Instance", Sound = "Instance",
}
local methods = {}
local Inst = {}
local function detach(node)
	local p = rawget(node, "_parent")
	if p then
		local kids = rawget(p, "_kids")
		local i = table.find(kids, node)
		if i then table.remove(kids, i) end
	end
	rawset(node, "_parent", nil)
end
Inst.__index = function(t, k)
	if k == "Parent" then return rawget(t, "_parent") end
	if k == "CFrame" then return rawget(t, "_cf") end
	if k == "Position" then
		local cf = rawget(t, "_cf")
		return cf and cf.Position or nil
	end
	return methods[k]
end
Inst.__newindex = function(t, k, v)
	if k == "Parent" then
		detach(t)
		if v then
			rawset(t, "_parent", v)
			table.insert(rawget(v, "_kids"), t)
		end
	elseif k == "CFrame" then
		rawset(t, "_cf", v)
	elseif k == "Position" then
		rawset(t, "_cf", CF.new(v))
	else
		rawset(t, k, v)
	end
end
local function newInstance(class, name)
	local n = setmetatable({ ClassName = class, Name = name or class, _kids = {}, _attrs = {}, _tags = {} }, Inst)
	if class == "Part" then rawset(n, "_cf", CF.new(V3.zero)) end
	return n
end
function methods.IsA(self, cls)
	local c = self.ClassName
	while c do
		if c == cls then return true end
		c = PARENT_CLASS[c]
	end
	return cls == "Instance"
end
function methods.FindFirstChild(self, name)
	for _, k in rawget(self, "_kids") do
		if k.Name == name then return k end
	end
	return nil
end
function methods.WaitForChild(self, name)
	local c = methods.FindFirstChild(self, name)
	if not c then error("WaitForChild: tidak ada '" .. name .. "' di " .. self.Name, 2) end
	return c
end
function methods.FindFirstChildOfClass(self, cls)
	for _, k in rawget(self, "_kids") do
		if k.ClassName == cls then return k end
	end
	return nil
end
function methods.GetChildren(self) return table.clone(rawget(self, "_kids")) end
function methods.GetDescendants(self)
	local out = {}
	local function walk(n)
		for _, k in rawget(n, "_kids") do
			table.insert(out, k)
			walk(k)
		end
	end
	walk(self)
	return out
end
function methods.Destroy(self)
	rawset(self, "_destroyed", true)
	detach(self)
	for _, k in methods.GetChildren(self) do methods.Destroy(k) end
end
function methods.SetAttribute(self, k, v) rawget(self, "_attrs")[k] = v end
function methods.GetAttribute(self, k) return rawget(self, "_attrs")[k] end
function methods.IsDescendantOf(self, anc)
	local p = rawget(self, "_parent")
	while p do
		if p == anc then return true end
		p = rawget(p, "_parent")
	end
	return false
end
function methods.GetPivot(self)
	if self.PrimaryPart then return self.PrimaryPart._cf end
	return CF.new(V3.zero)
end
function methods.PivotTo(self, cf)
	if self.PrimaryPart then rawset(self.PrimaryPart, "_cf", cf) end
end
function methods.UnequipTools(self) end

local function typeofShim(v)
	if type(v) == "table" then
		if rawget(v, "ClassName") then return "Instance" end
		if rawget(v, "__isV3") then return "Vector3" end
		if rawget(v, "__isCF") then return "CFrame" end
	end
	return type(v)
end

-- ===== Dunia uji =====
local function newWorldBase()
	local W = { notices = {}, broadcasts = {}, knocks = {}, jumpscares = {}, respawns = {}, handlers = {}, errors = {}, logs = {} }

	local function logLine(prefix, ...)
		local parts = table.pack(...)
		for i = 1, parts.n do parts[i] = tostring(parts[i]) end
		table.insert(W.logs, prefix .. table.concat(parts, " "))
	end

	-- Tree
	local RS = newInstance("Folder", "ReplicatedStorage")
	local SSS = newInstance("Folder", "ServerScriptService")
	local SStorage = newInstance("Folder", "ServerStorage")
	local Workspace = newInstance("Folder", "Workspace")
	local PlayersSvc = newInstance("Players", "Players")
	PlayersSvc.PlayerAdded = newSignal()
	PlayersSvc.PlayerRemoving = newSignal()
	PlayersSvc.GetPlayers = function(self)
		local out = {}
		for _, k in rawget(self, "_kids") do
			if k.ClassName == "Player" then table.insert(out, k) end
		end
		return out
	end
	local RunSvc = newInstance("Folder", "RunService")
	RunSvc.Heartbeat = newSignal()
	RunSvc.IsServer = function() return true end

	local function folder(parent, name)
		local f = newInstance("Folder", name)
		f.Parent = parent
		return f
	end
	local Shared = folder(RS, "Shared")
	local SharedConfig = folder(Shared, "Config")
	local SharedUtil = folder(Shared, "Util")
	local Server = folder(SSS, "Server")
	local ServerConfig = folder(Server, "Config")
	local Services = folder(Server, "Services")
	local Ghosts = folder(Server, "Ghosts")

	local game_ = {
		GetService = function(_, name)
			if name == "Players" then return PlayersSvc end
			if name == "ReplicatedStorage" then return RS end
			if name == "ServerStorage" then return SStorage end
			if name == "Workspace" then return Workspace end
			if name == "RunService" then return RunSvc end
			error("GetService tidak dimock: " .. name)
		end,
	}

	-- Globals untuk modul
	local taskLib = {
		spawn = function(f, ...)
			local ok, err = pcall(f, ...)
			if not ok then table.insert(W.errors, tostring(err)) logLine("[TASK-ERROR] ", err) end
		end,
		defer = function(f, ...)
			local ok, err = pcall(f, ...)
			if not ok then table.insert(W.errors, tostring(err)) end
		end,
		wait = function(n) return n or 0 end,
	}
	local Random_ = { new = function() return {
		NextInteger = function(_, a, b) return math.random(a, b) end,
		NextNumber = function() return math.random() end,
	} end }
	local globals = {
		game = game_, task = taskLib, Instance = { new = function(c) return newInstance(c) end },
		Vector3 = V3, CFrame = CF, Random = Random_, typeof = typeofShim,
		Color3 = { fromRGB = function(r, g, b) return { r, g, b } end },
		Enum = { HumanoidDisplayDistanceType = { None = "None" } },
		print = function(...) logLine("", ...) end,
		warn = function(...) logLine("[WARN] ", ...) end,
	}

	-- Loader modul
	local cache = {}
	local requireShim
	local function envFor(node)
		local env = setmetatable({ script = node, require = function(n) return requireShim(n) end }, { __index = function(_, k)
			local g = globals[k]
			if g ~= nil then return g end
			return _G[k]
		end })
		return env
	end
	requireShim = function(node)
		if cache[node] ~= nil then return cache[node] end
		local m
		if rawget(node, "_factory") then
			m = rawget(node, "_factory")()
		else
			local src = rawget(node, "_src")
			assert(src, "modul tanpa source: " .. node.Name)
			local f, err = loadstring(src, "=" .. node.Name)
			if not f then error("compile " .. node.Name .. ": " .. tostring(err)) end
			setfenv(f, envFor(node))
			m = f()
		end
		cache[node] = m
		return m
	end

	local function addSource(parent, name, src)
		local n = newInstance("ModuleScript", name)
		rawset(n, "_src", src)
		n.Parent = parent
		return n
	end
	local function addMock(parent, name, factory)
		local n = newInstance("ModuleScript", name)
		rawset(n, "_factory", factory)
		n.Parent = parent
		return n
	end
	local function get(name) return requireShim(Services:WaitForChild(name)) end

	return W, {
		RS = RS, Workspace = Workspace, PlayersSvc = PlayersSvc, RunSvc = RunSvc, SStorage = SStorage,
		SharedConfig = SharedConfig, SharedUtil = SharedUtil, ServerConfig = ServerConfig,
		Services = Services, Ghosts = Ghosts, addSource = addSource, addMock = addMock, get = get,
		folder = folder, logLine = logLine, req = function(n) return requireShim(n) end,
	}
end
