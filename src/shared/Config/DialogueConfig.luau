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
	-- Dipakai saat KERIS di KERIS_OBTAINED untuk pemegang keris. Hanya petunjuk: keris disimpan di RitualCollection. PLACEHOLDER.
	Pemandu_KerisStore = {
		speaker = "Pemandu",
		lines = {
			"Itu keris pusaka dusun ini.",
			"Simpanlah di tempat ritual. Aku hanya bisa menyaksikan.",
		},
	},
	-- Dipakai saat KERIS di KERIS_OBTAINED untuk pemain yang TIDAK memegang keris. PLACEHOLDER.
	Pemandu_KerisWait = {
		speaker = "Pemandu",
		lines = {
			"Keris itu ada pada salah satu kawanmu. Suruh dia menyimpannya di tempat ritual.",
		},
	},
	-- Pemandu MELAPOR: keris sudah tersimpan di tempat ritual (KERIS COMPLETE). Menamatkan dialog ini memberi
	-- quest berikutnya (Kantil). PLACEHOLDER.
	Pemandu_KerisDone = {
		speaker = "Pemandu",
		lines = {
			"Keris Pusaka sudah tersimpan di tempat ritual. Satu pusaka telah kembali.",
			"Pusaka berikutnya adalah kembang kantil hitam. Untuk itu kita butuh empat bunga yang tersebar di dusun ini.",
			"Carilah mawar merah, mawar putih, melati, dan kantil kuning.",
		},
	},
	-- Dipakai saat KANTIL di SEARCHING_FLOWERS. PLACEHOLDER.
	Pemandu_KantilSearch = {
		speaker = "Pemandu",
		lines = {
			"Carilah empat bunga: mawar merah, mawar putih, melati, dan kantil kuning.",
			"Jangan berpisah terlalu jauh.",
		},
	},
	-- Dipakai saat KANTIL di FLOWERS_COMPLETE (petunjuk saja). PLACEHOLDER.
	Pemandu_KantilGrave = {
		speaker = "Pemandu",
		lines = {
			"Bunga sudah lengkap. Bawalah ke makam di ujung dusun.",
		},
	},
	-- Dipakai saat KANTIL di FLOWERS_PLACEMENT / CANTIL_PUZZLE. PLACEHOLDER.
	Pemandu_KantilPuzzle = {
		speaker = "Pemandu",
		lines = {
			"Baca petunjuk di makam, lalu letakkan setiap bunga di makam yang tepat.",
			"Pegang bunganya, lalu tekan E di dekat makam.",
		},
	},
	-- Dipakai saat KANTIL di CANTIL_BLACK_OBTAINED (petunjuk saja; penyimpanan di RitualCollection, ADR-026). PLACEHOLDER.
	Pemandu_KantilStore = {
		speaker = "Pemandu",
		lines = {
			"Kembang kantil hitam sudah muncul. Simpan di tempat ritual.",
		},
	},
}

return table.freeze(DialogueConfig)