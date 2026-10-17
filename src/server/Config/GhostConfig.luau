--!strict
-- GhostConfig: definisi hantu untuk Ghost Encounter System (Phase 9, ADR-047/048). SISI SERVER.
-- Hantu NON-COMBAT: tidak bisa dilawan, pemain hanya bereaksi sesuai aturan hantu itu. Semua keputusan di server.
--
-- Hantu baru = (1) satu entri di Ghosts + masukkan id-nya ke ORDER, (2) satu modul perilaku di
-- server/Ghosts/<behavior>.luau. GhostService (host generik) tidak perlu diubah. Penyebab gagal (failureReason)
-- harus didaftarkan di KnockConfig.Reason, jumpscare + kebijakan hukumannya di FailureConfig.
--
-- SEMUA ANGKA di `params` adalah ASUMSI AWAL (belum ada di GDD) dan disetel lewat tes Studio, bukan lewat kode.

export type GhostDef = {
	id: string,
	displayName: string,
	enabled: boolean, -- false = tidak dimuat sama sekali
	behavior: string, -- nama ModuleScript di server/Ghosts
	modelName: string, -- Model di ServerStorage/GhostModels (folder yang sama dengan model jumpscare, JumpscareConfig)
	failureReason: string, -- KnockConfig.Reason; dipakai FailureService untuk jumpscare + hukuman
	questId: string, -- quest pemilik (dipakai FailureService.fail)
	maxActive: number, -- jumlah instance hidup bersamaan untuk hantu ini
	bindings: { [string]: string }, -- nama objek dunia/quest/item yang diikat perilaku (tanpa magic string di kode)
	texts: { [string]: string }, -- notifikasi (Indonesia, PLACEHOLDER), tampil lewat NoticeService (ADR-025)
	sounds: { [string]: string }, -- SoundId; "" = tanpa suara. spawn = sekali saat muncul, loop = berulang selama hidup
	animations: { [string]: string }, -- AnimationId; "" = tanpa animasi. chase = di-LOOP selama hantu mengejar (fase CHASING)
	params: { [string]: number }, -- angka perilaku (studs, detik, studs/detik)
}

-- Parameter PRESENTASI per model (opsional; bila tidak ada di `params`, dipakai nilai default ini):
--   facingYawDegrees  putar arah hadap model (derajat). Isi 180 bila hantu berjalan mundur / wajah membelakangi arah gerak.
--   spawnVolume       volume suara spawn (0..10)
--   loopVolume        volume suara loop selama hidup
--   soundMaxDistance  RollOffMaxDistance (studs) kedua suara
--   chaseAnimSpeed    kecepatan putar animasi chase (1 = normal)
local PRESENTATION_DEFAULTS = table.freeze({
	facingYawDegrees = 0,
	spawnVolume = 1,
	loopVolume = 0.6,
	soundMaxDistance = 90,
	chaseAnimSpeed = 1,
} :: { [string]: number })

local GhostConfig = {}

-- Urutan pemuatan (dan init behavior).
GhostConfig.PRESENTATION_DEFAULTS = PRESENTATION_DEFAULTS
GhostConfig.ORDER = table.freeze({ "Kuntilanak" } :: { string })

GhostConfig.TICK_INTERVAL = 1 / 30 -- detik; update perilaku dibatasi sekian (Heartbeat dikumpulkan)
GhostConfig.RUNTIME_FOLDER = "GhostRuntime" -- folder Workspace untuk body hantu yang sedang hidup (dibuat server)
GhostConfig.MODEL_FOLDER = "GhostModels" -- di ServerStorage
-- Dependency model belum ada = body PLACEHOLDER sederhana agar logika bisa diuji; log warning tiap kali dipakai.
-- Setel false bila ingin hantu TIDAK muncul sama sekali sampai model asli ada.
GhostConfig.ALLOW_PLACEHOLDER_BODY = true

GhostConfig.Ghosts = table.freeze({
	-- KUNTILANAK (quest Keris / Daun Kelor). Desain user 2026-10-16 (ADR-048, menggantikan butir Kuntilanak di ADR-047):
	--   * muncul saat pemain mengambil Daun Kelor, di titik KuntilanakSpawn TERDEKAT dari titik Kelor itu
	--   * mengejar HANYA pemain yang membawa Daun Kelor
	--   * tertangkap = jumpscare + knock; Kelor di tangan korban dirampas dan muncul lagi di titik acak (hanya itu yang dicari ulang)
	--   * lawan: berdekatan dengan pemain lain (ia mundur); solo: lari sampai durasi tertentu lalu ia menyerah
	-- Aktif hanya selama quest di state bindings.activeState (SEARCHING_KELOR).
	Kuntilanak = {
		id = "Kuntilanak",
		displayName = "Kuntilanak",
		enabled = true,
		behavior = "Kuntilanak",
		modelName = "Kuntilanak",
		failureReason = "GHOST_KUNTILANAK",
		questId = "KERIS",
		maxActive = 1,
		bindings = {
			collectionId = "Kelor", -- CollectionConfig.Collections[].id yang memicu hantu
			itemId = "DaunKelor", -- item yang dicari hantu (ItemConfig)
			counterId = "Kelor", -- counter party-wide di QuestConfig (untuk notifikasi progres setelah perampasan)
			activeState = "SEARCHING_KELOR", -- state quest saat hantu boleh ada
			spawnFolder = "KuntilanakSpawn", -- Workspace.QuestObjects.<spawnFolder>: Part/Model titik muncul
		},
		texts = {
			spawn = "Terdengar tawa perempuan dari kejauhan... Kuntilanak mencium Daun Kelor.",
			stolen = "Kuntilanak merampas %d Daun Kelor darimu! Cari lagi di sekitar dusun.",
			stolenOthers = "Kuntilanak merampas %d Daun Kelor dari %s (%d/%d). Cari lagi.",
			repelled = "Kuntilanak mundur karena kalian berdekatan.",
			escaped = "Kuntilanak menyerah dan menghilang.",
			gone = "Kuntilanak menghilang.",
		},
		sounds = {
			spawn = "", -- TODO: tawa kuntilanak (aset suara belum ada)
			loop = "", -- TODO: desis/tawa berulang selama ia mengejar
		},
		animations = {
			chase = "", -- TODO: rbxassetid:// animasi mengejar (di-loop). Kosong = pose diam. Model harus punya rig (Motor6D + Humanoid/AnimationController)
		},
		params = {
			appearSeconds = 3, -- diam setelah muncul, belum bisa menangkap (peringatan + pemain sempat bereaksi)
			chaseSpeed = 12, -- studs/detik; pemain berlari 16, jadi bisa dihindari
			catchRadius = 4, -- studs (3D) dari HumanoidRootPart korban
			spawnYOffset = 3, -- studs di atas titik muncul (body melayang)
			targetYOffset = 0, -- studs; ketinggian body relatif terhadap HumanoidRootPart korban
			protectRadius = 15, -- pemain lain (NORMAL/REVIVING) sedekat ini dari korban = korban terlindungi
			holdDistance = 12, -- korban terlindungi: ia tidak mau mendekat lebih dari ini (mundur bila lebih dekat)
			repelSeconds = 6, -- akumulasi detik semua pembawa Kelor terlindungi -> ia mundur dan menghilang
			soloChaseSeconds = 25, -- solo (party tinggal 1): bertahan sekian detik tanpa tertangkap -> ia menyerah
			maxChaseSeconds = 90, -- pengaman: bagaimanapun ia menghilang setelah sekian detik mengejar
			noTargetSeconds = 8, -- tak ada pembawa Kelor yang valid selama ini -> ia menghilang
			facingYawDegrees = 0, -- setel 180 bila ia terlihat berjalan mundur
			spawnVolume = 1,
			loopVolume = 0.6,
			soundMaxDistance = 90,
			chaseAnimSpeed = 1,
		},
	} :: GhostDef,
} :: { [string]: GhostDef })

return table.freeze(GhostConfig)
