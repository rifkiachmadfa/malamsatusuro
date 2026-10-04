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
	Pemandu_Idle = {
		speaker = "Pemandu",
		lines = {
			"Belum ada yang perlu kuminta dari kalian saat ini.",
		},
	},

	-- QUEST 01 — KERIS PUSAKA
	Keris_Brief = {
		speaker = "Pemandu",
		lines = {
			"Carilah Keris Pusaka. Benda itu tersimpan dalam sebuah peti terkunci.",
			"Mulailah dengan mengumpulkan daun kelor yang tersebar di dusun ini.",
		},
	},
	Keris_Hint = {
		speaker = "Pemandu",
		lines = { "Teruskan pencarian Keris Pusaka. Jangan berjalan sendirian terlalu jauh." },
	},
	Keris_Submit = {
		speaker = "Pemandu",
		lines = { "Keris Pusaka. Kalian berhasil. Satu syarat ritual sudah terpenuhi." },
	},

	-- QUEST 02 — KEMBANG KANTIL HITAM
	Kantil_Brief = {
		speaker = "Pemandu",
		lines = {
			"Berikutnya, kembang kantil hitam. Bunga itu hanya mekar bila bunga-bunga lain disusun dengan benar.",
			"Kumpulkan bunga di dusun ini, lalu bawa ke makam.",
		},
	},
	Kantil_Hint = {
		speaker = "Pemandu",
		lines = { "Teruskan mencari kembang kantil hitam. Saling jaga di dekat makam." },
	},
	Kantil_Submit = {
		speaker = "Pemandu",
		lines = { "Kembang kantil hitam. Dua syarat ritual sudah terpenuhi." },
	},

	-- QUEST 03 — KAIN KAFAN
	Kafan_Brief = {
		speaker = "Pemandu",
		lines = {
			"Yang terakhir, kain kafan. Kain itu menunggu di tempat gamelan.",
			"Semua dari kalian harus memainkannya dengan baik.",
		},
	},
	Kafan_Hint = {
		speaker = "Pemandu",
		lines = { "Temukan tempat gamelan. Semua pemain harus ikut memainkannya." },
	},
	Kafan_Submit = {
		speaker = "Pemandu",
		lines = { "Kain kafan. Semua syarat ritual sudah lengkap." },
	},
}

return table.freeze(DialogueConfig)