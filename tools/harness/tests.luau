-- Skenario uji Kuntilanak (Phase 9). Setiap test membangun dunia baru.
local RESULTS = {} -- { name, ok, detail }
local current = nil

local function check(cond, msg)
	if not cond then
		table.insert(current.fails, msg)
	end
end
local function test(name, fn)
	current = { name = name, fails = {} }
	local W
	local ok, err = pcall(function() W = fn() end)
	if not ok then table.insert(current.fails, "EXCEPTION: " .. tostring(err)) end
	table.insert(RESULTS, current)
	current.world = W
end

local function nearestGhostSpawn(pos)
	local best, bestD
	for name, p in GHOST_SPAWN_POS do
		local d = (p - pos).Magnitude
		if not bestD or d < bestD then best, bestD = name, d end
	end
	return best, GHOST_SPAWN_POS[best]
end

local function noErrors(W) check(#W.errors == 0, "task error: " .. table.concat(W.errors, " | ")) end
local function inv(W, label)
	local ok, d = W.invariant()
	check(ok, "invarian Kelor gagal " .. (label or "") .. ": " .. d)
end
local function lastGhostNotice(W, text)
	for _, b in W.broadcasts do if string.find(b, text, 1, true) then return true end end
	return false
end

-- 1. Muncul di titik KuntilanakSpawn TERDEKAT dari titik Kelor yang diambil (diulang untuk berbagai titik acak)
test("spawn di titik terdekat dari Kelor (30 dunia acak)", function()
	local last
	for i = 1, 30 do
		math.randomseed(i * 7919)
		local W = buildWorld()
		last = W
		W.startKelor()
		local p = W.addPlayer("A", V3.new(500, 0, 500))
		local model = W.pickup(p)
		local spawnPos = rawget(model, "_spawn").Position
		local expectedName, expectedPos = nearestGhostSpawn(spawnPos)
		local g = W.ghostList()
		check(#g == 1, "dunia " .. i .. ": ghost count " .. #g)
		if g[1] then
			local got = g[1].root.Position
			check(got.X == expectedPos.X and got.Z == expectedPos.Z, string.format("dunia %d: ghost di %s, harusnya %s (%s)", i, tostring(got), expectedName, tostring(expectedPos)))
			check(g[1].phase == "APPEARING" or g[1].phase == "NEW", "fase awal " .. g[1].phase)
		end
		check(lastGhostNotice(W, "Kuntilanak mencium"), "notifikasi spawn tidak ada")
		noErrors(W)
	end
	return last
end)

-- 2. Tidak mengejar saat appearSeconds; setelah itu mengejar pembawa dan menangkap (solo = respawn tanpa reset quest)
test("solo: diam saat appearing lalu menangkap, Kelor dirampas, respawn tanpa reset quest", function()
	math.randomseed(1)
	local W = buildWorld()
	W.startKelor()
	local p = W.addPlayer("A", V3.new(60, 0, 60))
	W.pickup(p)
	check(W.held(p) == 1, "Kelor di tangan setelah pickup")
	local g = W.ghostList()[1]
	local start = g.root.Position
	W.step(0.1, 25) -- 2.5 dtk < appearSeconds (3)
	check((g.root.Position - start).Magnitude < 0.001, "hantu bergerak saat masih appearing")
	check(#W.jumpscares == 0, "jumpscare terlalu dini")
	W.step(0.1, 200) -- cukup untuk mengejar jarak ~70 studs pada 12 studs/dtk
	check(#W.ghostList() == 0, "hantu masih ada setelah menangkap")
	check(#W.jumpscares == 1 and W.jumpscares[1].player == p, "jumpscare tidak tepat sasaran: " .. #W.jumpscares)
	check(#W.knocks == 0, "solo tidak boleh knock")
	check(W.respawns[p] == 1, "solo harus respawn tepat sekali: " .. tostring(W.respawns[p]))
	check(W.Q.getState("KERIS") == "SEARCHING_KELOR", "quest TIDAK boleh direset: " .. tostring(W.Q.getState("KERIS")))
	check(W.held(p) == 0, "Kelor korban harus hilang")
	check(W.Q.getCounter("KERIS", "Kelor") == 0, "progres party harus kembali 0")
	check(#W.pickups() == 4, "Kelor harus muncul lagi di dunia (4 aktif): " .. #W.pickups())
	check(W.GM.getPlayerState(p) == "NORMAL", "state pemain harus NORMAL: " .. tostring(W.GM.getPlayerState(p)))
	inv(W, "solo tangkap")
	noErrors(W)
	return W
end)

-- 3. Multi: pembawa sendirian (rekan jauh) tertangkap -> KNOCK (bukan respawn)
test("multi: pembawa tidak terlindungi tertangkap = knock + Kelor dirampas", function()
	math.randomseed(2)
	local W = buildWorld()
	W.startKelor()
	local a = W.addPlayer("A", V3.new(60, 0, 60))
	local b = W.addPlayer("B", V3.new(900, 0, 900)) -- jauh, tidak melindungi
	W.pickup(a)
	W.pickup(b) -- B juga ambil satu (counter 2); hantu sudah aktif (maxActive 1)
	check(W.Q.getCounter("KERIS", "Kelor") == 2, "counter 2")
	W.step(0.1, 400)
	check(#W.knocks >= 1 and W.knocks[1].reason == "GHOST_KUNTILANAK", "harus knock dengan reason GHOST_KUNTILANAK")
	check(W.respawns[a] == nil and W.respawns[b] == nil, "multi tidak boleh respawn")
	local victim = W.knocks[1] and W.knocks[1].player
	check(victim ~= nil and W.held(victim) == 0, "Kelor korban harus hilang")
	check(W.Q.getState("KERIS") == "SEARCHING_KELOR", "quest tidak boleh berubah")
	inv(W, "multi tangkap")
	noErrors(W)
	return W
end)

-- 4. Lawan: berdekatan dengan pemain lain -> tidak tertangkap, hantu menyerah
test("lawan: berdekatan dengan rekan = hantu mundur (REPELLED), Kelor tetap", function()
	math.randomseed(3)
	local W = buildWorld()
	W.startKelor()
	local a = W.addPlayer("A", V3.new(60, 0, 60))
	local b = W.addPlayer("B", V3.new(66, 0, 60))
	W.pickup(a)
	W.step(0.1, 300)
	check(#W.jumpscares == 0, "tidak boleh ada jumpscare saat terlindungi")
	check(#W.knocks == 0 and W.respawns[a] == nil, "tidak boleh knock/respawn")
	check(#W.ghostList() == 0, "hantu harus sudah menyerah")
	check(W.held(a) == 1, "Kelor A tetap")
	check(lastGhostNotice(W, "mundur"), "notifikasi mundur tidak ada")
	inv(W, "repel")
	noErrors(W)
	return W
end)

-- 5. Perlindungan hilang di tengah kejar -> tertangkap
test("rekan menjauh di tengah kejar = pembawa tertangkap (knock)", function()
	math.randomseed(4)
	local W = buildWorld()
	W.startKelor()
	local a = W.addPlayer("A", V3.new(60, 0, 60))
	local b = W.addPlayer("B", V3.new(66, 0, 60))
	W.pickup(a)
	W.step(0.1, 45) -- 4.5 dtk: appear 3 dtk + 1.5 dtk terlindungi (< repel 6)
	check(#W.ghostList() == 1, "hantu masih harus ada sebelum rekan menjauh")
	W.setPos(b, V3.new(900, 0, 900))
	W.step(0.1, 300)
	check(#W.knocks == 1 and W.knocks[1].player == a, "A harus knock setelah B menjauh: " .. #W.knocks)
	check(W.held(a) == 0, "Kelor A dirampas")
	inv(W, "perlindungan hilang")
	noErrors(W)
	return W
end)

-- 6. Pemain terakhir berdiri: rekan lain knock -> respawn saja (tidak boleh membuat party buntu)
test("pemain terakhir berdiri tertangkap = respawn, BUKAN knock", function()
	math.randomseed(5)
	local W = buildWorld()
	W.startKelor()
	local a = W.addPlayer("A", V3.new(60, 0, 60))
	local b = W.addPlayer("B", V3.new(62, 0, 60))
	W.pickup(a)
	W.GM.setPlayerState(b, "KNOCKED") -- B pingsan di dekat A (tidak melindungi)
	W.step(0.1, 300)
	check(#W.knocks == 0, "A pemain terakhir: tidak boleh knock (party buntu): " .. #W.knocks)
	check(W.respawns[a] == 1, "A harus respawn: " .. tostring(W.respawns[a]))
	check(W.held(a) == 0 and W.Q.getCounter("KERIS", "Kelor") == 0, "Kelor dirampas dan progres turun")
	check(W.Q.getState("KERIS") == "SEARCHING_KELOR", "quest tidak direset")
	check(W.GM.getPlayerState(b) == "KNOCKED", "B tetap knock (tidak disentuh)")
	inv(W, "pemain terakhir")
	noErrors(W)
	return W
end)

-- 7. Solo lari -> hantu menyerah setelah soloChaseSeconds
test("solo lari: hantu menyerah (ESCAPED), Kelor tetap, tanpa jumpscare", function()
	math.randomseed(6)
	local W = buildWorld()
	W.startKelor()
	local p = W.addPlayer("A", V3.new(60, 0, 60))
	W.pickup(p)
	local x = 60
	W.step(0.1, 600, function()
		x += 1.6 -- 16 studs/dtk > kecepatan hantu 12
		W.setPos(p, V3.new(x, 0, 60))
	end)
	check(#W.jumpscares == 0 and #W.knocks == 0 and W.respawns[p] == nil, "pelari tidak boleh kena hukuman")
	check(#W.ghostList() == 0, "hantu harus menyerah")
	check(lastGhostNotice(W, "menyerah"), "notifikasi menyerah tidak ada")
	check(W.held(p) == 1, "Kelor tetap di tangan")
	inv(W, "solo lari")
	noErrors(W)
	return W
end)

-- 8. Tanpa pembawa Kelor -> tidak mengejar
test("pemain tanpa Kelor diabaikan (NO_HOLDER)", function()
	math.randomseed(7)
	local W = buildWorld()
	W.startKelor()
	local p = W.addPlayer("A", V3.new(60, 0, 60))
	local q = W.addPlayer("B", V3.new(62, 0, 60)) -- tidak membawa Kelor, dekat hantu
	W.pickup(p)
	W.Items.consume(p, "DaunKelor", 1) -- simulasi Kelor sudah tidak dibawa
	W.step(0.1, 300)
	check(#W.jumpscares == 0 and #W.knocks == 0, "tidak boleh ada hukuman tanpa pembawa")
	check(#W.ghostList() == 0, "hantu harus menghilang karena tidak ada pembawa")
	noErrors(W)
	return W
end)

-- 9. Pickup ke-4 (KELOR_COMPLETE) tidak memunculkan hantu; hantu aktif menghilang saat quest keluar dari state
test("Kelor 4/4: tidak ada hantu baru; hantu aktif hilang saat KELOR_COMPLETE", function()
	math.randomseed(8)
	local W = buildWorld()
	W.startKelor()
	local p = W.addPlayer("A", V3.new(500, 0, 500))
	W.pickup(p)
	check(#W.ghostList() == 1, "hantu muncul di pickup pertama")
	W.pickup(p); check(#W.ghostList() == 1, "pickup ke-2: tetap 1 hantu (maxActive)")
	W.pickup(p)
	W.pickup(p) -- ke-4 -> KELOR_COMPLETE
	check(W.Q.getState("KERIS") == "KELOR_COMPLETE", "state harus KELOR_COMPLETE: " .. tostring(W.Q.getState("KERIS")))
	check(#W.ghostList() == 0, "hantu harus hilang saat quest keluar dari SEARCHING_KELOR")
	check(W.held(p) == 4, "pemain tetap membawa 4 Kelor")
	-- pickup ke-4 saja tidak boleh memicu hantu
	local W2 = buildWorld()
	W2.startKelor()
	local p2 = W2.addPlayer("A", V3.new(500, 0, 500))
	for i = 1, 3 do W2.pickup(p2); W2.Ghost.despawnAll("Kuntilanak", "TEST") end
	W2.pickup(p2) -- ke-4
	check(#W2.ghostList() == 0, "pickup ke-4 tidak boleh memanggil hantu")
	check(W2.Q.getState("KERIS") == "KELOR_COMPLETE", "state W2")
	noErrors(W)
	noErrors(W2)
	return W
end)

-- 10. Hanya pemain NORMAL yang dikejar
test("pembawa berstatus MINIGAME tidak dikejar/ditangkap", function()
	math.randomseed(9)
	local W = buildWorld()
	W.startKelor()
	local p = W.addPlayer("A", V3.new(40, 0, 40))
	W.pickup(p)
	W.GM.setPlayerState(p, "MINIGAME")
	W.step(0.1, 300)
	check(#W.jumpscares == 0 and #W.knocks == 0 and W.respawns[p] == nil, "pemain MINIGAME tidak boleh dihukum")
	check(W.held(p) == 1, "Kelor tidak dirampas")
	noErrors(W)
	return W
end)

-- 11. Pemain keluar saat dikejar
test("target keluar game saat dikejar: tanpa error, hantu hilang", function()
	math.randomseed(10)
	local W = buildWorld()
	W.startKelor()
	local a = W.addPlayer("A", V3.new(60, 0, 60))
	local b = W.addPlayer("B", V3.new(900, 0, 900))
	W.pickup(a)
	W.step(0.1, 40)
	W.leave(a)
	W.step(0.1, 200)
	check(#W.ghostList() == 0, "hantu harus hilang")
	check(#W.jumpscares == 0, "tidak ada jumpscare untuk pemain yang sudah keluar")
	noErrors(W)
	return W
end)

-- 12. Dependency Studio belum ada: tidak crash, pickup tetap normal
test("folder KuntilanakSpawn belum ada: pickup tetap jalan, tanpa hantu/error", function()
	math.randomseed(11)
	local W = buildWorld({ noGhostSpawns = true })
	W.startKelor()
	local p = W.addPlayer("A", V3.new(0, 0, 0))
	W.pickup(p)
	check(W.Q.getCounter("KERIS", "Kelor") == 1 and W.held(p) == 1, "pickup Kelor tetap bekerja")
	check(#W.ghostList() == 0, "tanpa titik spawn tidak boleh ada hantu")
	local warned = false
	for _, l in W.logs do if string.find(l, "KuntilanakSpawn", 1, true) then warned = true end end
	check(warned, "harus ada warning dependency KuntilanakSpawn")
	noErrors(W)
	return W
end)

-- 13. Isolasi error: update perilaku error tidak merusak game
test("error di update perilaku: hantu di-despawn, game lanjut", function()
	math.randomseed(12)
	local W = buildWorld()
	W.startKelor()
	local p = W.addPlayer("A", V3.new(60, 0, 60))
	W.pickup(p)
	W.step(0.1, 40)
	local g = W.ghostList()[1]
	g.data.state = 5 -- rusak sengaja
	W.step(0.1, 5)
	check(#W.ghostList() == 0, "hantu error harus di-despawn")
	check(W.held(p) == 1 and #W.jumpscares == 0, "pemain tidak terdampak")
	W.pickup(p) -- game tetap jalan; hantu baru boleh muncul
	check(#W.ghostList() == 1, "hantu baru bisa muncul lagi")
	noErrors(W)
	return W
end)

-- 14. API baru: QuestService.removeProgress
test("QuestService.removeProgress: validasi", function()
	local W = buildWorld()
	W.startKelor()
	local Q = W.Q
	Q.addProgress("KERIS", "Kelor", 2)
	check(Q.removeProgress("KERIS", "Kelor", 1) == 1, "turun ke 1")
	check(Q.removeProgress("KERIS", "Kelor", 0) == nil, "amount 0 ditolak")
	check(Q.removeProgress("KERIS", "Kelor", 1.5) == nil, "amount pecahan ditolak")
	check(Q.removeProgress("KERIS", "Kelor", 0 / 0) == nil, "NaN ditolak")
	check(Q.removeProgress("KERIS", "Nope", 1) == nil, "counter tak dikenal ditolak")
	check(Q.removeProgress("NOPE", "Kelor", 1) == nil, "quest tak dikenal ditolak")
	check(Q.removeProgress("KERIS", "Kelor", 5) == 0, "dibatasi minimal 0")
	Q.addProgress("KERIS", "Kelor", 4) -- 4/4 -> KELOR_COMPLETE
	check(Q.getState("KERIS") == "KELOR_COMPLETE", "state KELOR_COMPLETE")
	check(Q.removeProgress("KERIS", "Kelor", 1) == nil, "tidak boleh mengurangi setelah state lewat requiredState")
	check(Q.getCounter("KERIS", "Kelor") == 4, "counter tetap 4")
	return W
end)

-- 15. API baru: CollectibleService.returnToWorld
test("CollectibleService.returnToWorld: konsisten dan aman", function()
	math.randomseed(13)
	local W = buildWorld()
	W.startKelor()
	local p = W.addPlayer("A", V3.new(500, 0, 500))
	W.pickup(p); W.pickup(p)
	check(W.Q.getCounter("KERIS", "Kelor") == 2 and #W.pickups() == 2, "awal: counter 2, pickup dunia 2")
	check(W.Collect.returnToWorld("Kelor", 0) == 0, "jumlah 0 ditolak")
	check(W.Collect.returnToWorld("Kelor", 1.5) == 0, "jumlah pecahan ditolak")
	check(W.Collect.returnToWorld("Nope", 1) == 0, "id tak dikenal ditolak")
	check(W.Collect.returnToWorld("Zaitun", 1) == 0, "objective tanpa counter ditolak")
	check(W.Collect.returnToWorld("Flowers", 1) == 0, "objective di quest lain (state tidak aktif) ditolak")
	local n = W.Collect.returnToWorld("Kelor", 2)
	check(n == 2, "mengembalikan 2: " .. tostring(n))
	check(W.Q.getCounter("KERIS", "Kelor") == 0 and #W.pickups() == 4, "counter 0 dan 4 pickup di dunia")
	-- titik tidak boleh dobel
	local seen, dup = {}, false
	for _, m in W.pickups() do
		local s = rawget(m, "_spawn")
		if seen[s] then dup = true end
		seen[s] = true
	end
	check(not dup, "dua pickup di satu titik")
	-- state salah
	W.Q.addProgress("KERIS", "Kelor", 4) -- KELOR_COMPLETE
	check(W.Collect.returnToWorld("Kelor", 1) == 0, "state salah ditolak")
	return W
end)

-- 16. Regresi: kebijakan lama WRONG_FLOWER tidak berubah
test("regresi FailureService: WRONG_FLOWER solo=respawn, multi=knock (termasuk pemain terakhir)", function()
	local W = buildWorld()
	local a = W.addPlayer("A", V3.new(0, 0, 0))
	W.Failure.fail(a, "WRONG_FLOWER", "KANTIL")
	check(W.respawns[a] == 1 and #W.knocks == 0, "solo: respawn, tanpa knock")
	check(#W.jumpscares == 1 and W.jumpscares[1].ghostId == "Pocong", "jumpscare Pocong untuk bunga salah")

	local W2 = buildWorld()
	local x = W2.addPlayer("X", V3.new(0, 0, 0))
	local y = W2.addPlayer("Y", V3.new(10, 0, 0))
	W2.GM.setPlayerState(y, "KNOCKED") -- X pemain terakhir
	W2.Failure.fail(x, "WRONG_FLOWER", "KANTIL")
	check(#W2.knocks == 1 and W2.knocks[1].reason == "WRONG_FLOWER" and W2.respawns[x] == nil, "WRONG_FLOWER pemain terakhir tetap KNOCK (kebijakan lama tak berubah)")
	noErrors(W)
	noErrors(W2)
	return W
end)

-- 17. Request ganda: pickup yang sama tidak bisa dipanggil dua kali (anti duplikasi)
test("anti duplikasi: interaksi ganda pada pickup yang sama", function()
	math.randomseed(14)
	local W = buildWorld()
	W.startKelor()
	local p = W.addPlayer("A", V3.new(0, 0, 0))
	local m = W.pickups()[1]
	W.handlers.Kelor(p, m)
	W.handlers.Kelor(p, m)
	check(W.held(p) == 1 and W.Q.getCounter("KERIS", "Kelor") == 1, "pickup ganda tidak boleh menggandakan item")
	inv(W, "pickup ganda")
	return W
end)

-- ===== Laporan =====
local passed, failed = 0, 0
for _, r in RESULTS do
	if #r.fails == 0 then
		passed += 1
		print("PASS  " .. r.name)
	else
		failed += 1
		print("FAIL  " .. r.name)
		for _, f in r.fails do print("        - " .. f) end
	end
end
print(string.format("== %d lulus, %d gagal, total %d ==", passed, failed, #RESULTS))
