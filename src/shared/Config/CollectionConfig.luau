--!strict
-- CollectionConfig: objective "kumpulkan N item di titik spawn acak" (Kelor, bunga Kantil, dst).
-- Semua dijalankan oleh SATU modul generik: CollectibleService (ADR-027). Objective baru = tambah entri di sini,
-- jangan menyalin logika Kelor. Hanya data.
-- Entri tanpa counterId = pickup pendukung (mis. Minyak Zaitun): tidak menambah progres quest (ADR-035).

export type Collection = {
	id: string,
	questId: string, -- quest pemilik
	counterId: string?, -- counter party-wide di QuestConfig; target counter = jumlah titik aktif. nil = tanpa progres
	spawnCount: number?, -- jumlah titik aktif. Wajib bila counterId nil; bila ada counterId, default = target counter
	activeStates: { string }, -- pickup ada di dunia selama quest berada di salah satu state ini. MASUK ke state PERTAMA
	-- = (spawn ulang) acak; keluar dari semua state = hapus. State berikutnya hanya memperpanjang masa hidup pickup.
	spawnFolder: string, -- anak Workspace.QuestObjects berisi titik spawn (Part/Model)
	interactionId: string, -- InteractionId pickup (didaftarkan ke InteractionService)
	itemIds: { string }, -- item yang di-spawn (ItemConfig)
	assignment: "SAME" | "DISTINCT", -- SAME: semua pickup = itemIds[1]; DISTINCT: tiap item tepat sekali, diacak ke titik aktif
	actionText: string, -- teks prompt, mis. "Ambil"
	pickupDistance: number,
	completeNotice: string?, -- notifikasi ke semua pemain saat target tercapai (hanya bila ada counterId)
	clearOnLeave: boolean?, -- default true. false = pickup TIDAK dihapus dan tetap bisa diambil setelah keluar dari activeStates
	-- (spawn sekali saat masuk activeStates[1]; dipakai Minyak Zaitun: ada sejak awal game)
}

local CollectionConfig = {}

CollectionConfig.Collections = table.freeze({
	{
		id = "Kelor",
		questId = "KERIS",
		counterId = "Kelor",
		activeStates = { "SEARCHING_KELOR" },
		spawnFolder = "KelorSpawns",
		interactionId = "Kelor",
		itemIds = { "DaunKelor" },
		assignment = "SAME",
		actionText = "Ambil",
		pickupDistance = 8,
		completeNotice = "Daun Kelor sudah lengkap. Kembali ke Pemandu.",
	},
	-- Asumsi (belum ada di GDD): 4 titik aktif dari 8, tiap jenis bunga muncul tepat satu kali.
	{
		id = "Flowers",
		questId = "KANTIL",
		counterId = "Flowers",
		activeStates = { "SEARCHING_FLOWERS" },
		spawnFolder = "FlowerSpawns",
		interactionId = "Flower",
		itemIds = { "MawarMerah", "MawarPutih", "Melati", "KantilKuning" },
		assignment = "DISTINCT",
		actionText = "Petik",
		pickupDistance = 8,
		completeNotice = "Keempat bunga sudah terkumpul. Kembali ke Pemandu.",
	},
	-- Minyak Zaitun (ramuan revive, ADR-035/036): 2 titik aktif dari semua titik di ZaitunSpawns, tanpa progres quest.
	-- Spawn di AWAL GAME: saat quest Keris mulai (SEARCHING_KELOR, tepat setelah dialog intro) agar pemain sudah bisa
	-- mengambil dan terbiasa memegangnya sebelum quest Kantil. Tidak dihapus saat quest berganti, tidak respawn
	-- setelah diambil (bahan langka; spawn ulang saat party wipe = keputusan terbuka, Task 6.5).
	{
		id = "Zaitun",
		questId = "KERIS",
		counterId = nil,
		spawnCount = 2,
		activeStates = { "SEARCHING_KELOR" },
		clearOnLeave = false,
		spawnFolder = "ZaitunSpawns",
		interactionId = "Zaitun",
		itemIds = { "MinyakZaitun" },
		assignment = "SAME",
		actionText = "Ambil",
		pickupDistance = 8,
	},
} :: { Collection })

return table.freeze(CollectionConfig)
