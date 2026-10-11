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
	-- Dipakai saat KANTIL di RETRY_GUIDE (solo gagal, ADR-034). Menamatkannya memulai ulang quest. PLACEHOLDER.
	Pemandu_KantilRetry = {
		speaker = "Pemandu",
		lines = {
			"Kau kembali. Dusun ini tidak memaafkan kesalahan, tapi masih memberi kesempatan.",
			"Kita mulai lagi dari awal. Carilah empat bunga: mawar merah, mawar putih, melati, dan kantil kuning.",
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
	-- Pemandu MELAPOR: kembang kantil hitam sudah tersimpan (KANTIL COMPLETE). Menamatkannya memulai quest Kafan. PLACEHOLDER.
	Pemandu_KantilDone = {
		speaker = "Pemandu",
		lines = {
			"Kembang kantil hitam sudah tersimpan di tempat ritual. Dua pusaka telah kembali.",
			"Yang terakhir adalah kain kafan. Kain itu hanya mau diserahkan bila gamelan di dusun ini dimainkan dengan benar.",
			"Carilah gamelannya. Satu orang saja yang memainkannya; yang lain menemani.",
		},
	},
	-- Dipakai saat KAFAN di FIND_GAMELAN / GAMELAN_ACTIVE (petunjuk). PLACEHOLDER.
	Pemandu_KafanSearch = {
		speaker = "Pemandu",
		lines = {
			"Temukan gamelan itu, lalu mainkan. Tekan Q, W, E, R mengikuti irama, atau ketuk kolomnya di layar.",
			"Bila gagal, kau boleh mencoba lagi.",
		},
	},
	-- Dipakai saat KAFAN di KAIN_OBTAINED untuk pemain yang MEMEGANG kain (petunjuk saja; penyimpanan di RitualCollection). PLACEHOLDER.
	Pemandu_KafanStore = {
		speaker = "Pemandu",
		lines = {
			"Kain kafan sudah ada di tanganmu. Simpan di tempat ritual.",
		},
	},
	-- Dipakai saat KAFAN di KAIN_OBTAINED untuk pemain yang TIDAK memegang kain. PLACEHOLDER.
	Pemandu_KafanWait = {
		speaker = "Pemandu",
		lines = {
			"Kain itu ada pada salah satu kawanmu. Suruh dia menyimpannya di tempat ritual.",
		},
	},
	-- Pemandu MELAPOR: kain kafan tersimpan = ketiga pusaka lengkap (KAFAN COMPLETE). Menamatkan dialog ini membuka ritual akhir
	-- (game FINAL_RITUAL, ADR-040). PLACEHOLDER: ganti dengan naskah GDD.
	Pemandu_KafanDone = {
		speaker = "Pemandu",
		lines = {
			"Kain kafan sudah tersimpan. Ketiga pusaka telah kembali ke tempatnya.",
			"Tinggal satu hal: ritual terakhir. Semua dari kalian harus berkumpul di tempat ritual.",
			"Jangan ada yang tertinggal.",
		},
	},
	-- Dipakai saat game FINAL_RITUAL (menunggu semua berkumpul). Dialog ini hanya pengingat. PLACEHOLDER.
	Pemandu_FinalGather = {
		speaker = "Pemandu",
		lines = {
			"Berkumpullah di tempat ritual. Ritual dimulai setelah kalian semua berada di sana.",
		},
	},
}

return table.freeze(DialogueConfig)