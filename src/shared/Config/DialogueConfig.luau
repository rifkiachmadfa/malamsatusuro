--!strict
-- DialogueConfig: data dialog NPC. Hanya data.
-- CATATAN: teks di bawah adalah PLACEHOLDER netral. Ganti dengan naskah GDD yang disetujui.

export type Dialogue = {
	speaker: string,
	lines: { string },
}

local DialogueConfig: { [string]: Dialogue } = {
	Pemandu_Intro = {
		speaker = "Pemandu",
		lines = {
			"Akhirnya kalian tiba. Dusun ini sudah lama menunggu.",
			"Malam Suro bukan malam biasa. Jangan berpisah terlalu jauh dari kawan kalian.",
			"Nanti akan kuberi tahu apa yang harus dicari. Bersiaplah.",
		},
	},
	-- Dipakai saat KERIS berada di SEARCHING_KELOR. PLACEHOLDER: ganti dengan naskah GDD.
	Pemandu_KerisSearch = {
		speaker = "Pemandu",
		lines = {
			"Carilah daun kelor di sekitar dusun. Kita butuh empat helai.",
			"Jangan terlalu jauh dari kawan kalian.",
		},
	},
	-- Dipakai saat KERIS di KELOR_COMPLETE. Setelah dialog selesai, server memberi Kunci Peti ke SATU pemain acak
	-- dan menghapus semua Daun Kelor. PLACEHOLDER: ganti dengan naskah GDD.
	Pemandu_KerisKey = {
		speaker = "Pemandu",
		lines = {
			"Empat helai kelor sudah terkumpul. Serahkan semuanya padaku.",
			"Kunci peti kuberikan pada salah satu dari kalian. Hanya dia yang bisa membuka peti itu.",
			"Carilah peti itu bersama-sama.",
		},
	},
	-- Dipakai saat KERIS di KEY_OBTAINED / CHEST_AVAILABLE. PLACEHOLDER: ganti dengan naskah GDD.
	Pemandu_KerisChest = {
		speaker = "Pemandu",
		lines = {
			"Kunci sudah ada pada salah satu dari kalian.",
			"Temukan peti itu dan bukalah.",
		},
	},
}

return table.freeze(DialogueConfig)