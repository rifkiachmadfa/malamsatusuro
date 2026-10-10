--!strict
-- CollectionConfig: objective "kumpulkan N item di titik spawn acak" (Kelor, bunga Kantil, dst).
-- Semua dijalankan oleh SATU modul generik: CollectibleService (ADR-027). Objective baru = tambah entri di sini,
-- jangan menyalin logika Kelor. Hanya data.

export type Collection = {
	id: string,
	questId: string, -- quest pemilik
	counterId: string, -- counter party-wide di QuestConfig; target counter = jumlah titik aktif
	activeState: string, -- pickup ada di dunia selama quest berada di state ini (masuk = spawn, keluar = hapus)
	spawnFolder: string, -- anak Workspace.QuestObjects berisi titik spawn (Part/Model)
	interactionId: string, -- InteractionId pickup (didaftarkan ke InteractionService)
	itemIds: { string }, -- item yang di-spawn (ItemConfig)
	assignment: "SAME" | "DISTINCT", -- SAME: semua pickup = itemIds[1]; DISTINCT: tiap item tepat sekali, diacak ke titik aktif
	actionText: string, -- teks prompt, mis. "Ambil"
	pickupDistance: number,
	completeNotice: string?, -- notifikasi ke semua pemain saat target tercapai
}

local CollectionConfig = {}

CollectionConfig.Collections = table.freeze({
	{
		id = "Kelor",
		questId = "KERIS",
		counterId = "Kelor",
		activeState = "SEARCHING_KELOR",
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
		activeState = "SEARCHING_FLOWERS",
		spawnFolder = "FlowerSpawns",
		interactionId = "Flower",
		itemIds = { "MawarMerah", "MawarPutih", "Melati", "KantilKuning" },
		assignment = "DISTINCT",
		actionText = "Petik",
		pickupDistance = 8,
		completeNotice = "Keempat bunga sudah terkumpul. Kembali ke Pemandu.",
	},
} :: { Collection })

return table.freeze(CollectionConfig)
