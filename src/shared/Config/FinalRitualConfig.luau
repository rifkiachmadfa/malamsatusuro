--!strict
-- FinalRitualConfig: data ritual akhir (Phase 8, ADR-040). Hanya data, tanpa logika.
-- CATATAN: SEMUA teks di Sequence adalah PLACEHOLDER netral. Ganti dengan naskah GDD yang disetujui.

export type Environment = {
	tweenSeconds: number, -- lama transisi di client
	brightness: number,
	clockTime: number,
	fogColor: Color3,
	fogEnd: number,
	ambient: Color3,
	outdoorAmbient: Color3,
}

export type Step = {
	speaker: string?, -- nil = narasi tanpa nama pembicara
	text: string,
	duration: number, -- detik teks ditampilkan (server menunggu selama ini)
	env: string?, -- nama di Environments; dimainkan client (Lighting) saat langkah ini mulai
}

local FinalRitualConfig = {}

-- ===== Berkumpul (gathering) =====
-- Titik kumpul = pivot objek ini (sudah ada: dipakai juga untuk menyimpan pusaka). Tidak ada dependency baru.
FinalRitualConfig.GATHER_OBJECT_PATH = table.freeze({ "QuestObjects", "RitualCollection" })
FinalRitualConfig.GATHER_RADIUS = 30 -- studs dari pivot; dihitung di SERVER dari posisi karakter
FinalRitualConfig.START_HOLD_SECONDS = 3 -- semua harus tetap berkumpul selama ini sebelum ritual mulai
FinalRitualConfig.CHECK_INTERVAL = 0.5

-- Attribute di ReplicatedStorage (hanya dibaca client untuk HUD "n/N").
FinalRitualConfig.ATTR_READY = "FinalRitual_Ready"
FinalRitualConfig.ATTR_REQUIRED = "FinalRitual_Required"
FinalRitualConfig.ATTR_HOLDING = "FinalRitual_Holding"

-- ===== Cutscene / ending =====
FinalRitualConfig.INTRO_SECONDS = 1.5 -- jeda setelah "Start" (letterbox masuk) sebelum langkah pertama
FinalRitualConfig.END_CARD_SECONDS = 8
FinalRitualConfig.END_TITLE = "TAMAT"
FinalRitualConfig.END_SUBTITLE = "Malam Suro: Dusun Kelabu"

-- Lingkungan (dimainkan di client; server hanya menyebut namanya). Horor penuh = Phase 10 (ancaman hantu = Phase 9, ADR-047).
FinalRitualConfig.Environments = table.freeze({
	Ritual = table.freeze({
		tweenSeconds = 3,
		brightness = 0.4,
		clockTime = 0,
		fogColor = Color3.fromRGB(18, 18, 24),
		fogEnd = 110,
		ambient = Color3.fromRGB(10, 10, 16),
		outdoorAmbient = Color3.fromRGB(14, 14, 24),
	} :: Environment),
	Fajar = table.freeze({
		tweenSeconds = 6,
		brightness = 2,
		clockTime = 5.8,
		fogColor = Color3.fromRGB(205, 195, 185),
		fogEnd = 450,
		ambient = Color3.fromRGB(90, 85, 80),
		outdoorAmbient = Color3.fromRGB(120, 110, 100),
	} :: Environment),
} :: { [string]: Environment })

-- Urutan ritual (dimainkan server, satu per satu). Pemandu bicara; langkah tanpa speaker = narasi.
FinalRitualConfig.Sequence = table.freeze({
	{ speaker = "Pemandu", text = "Tiga pusaka telah kembali: keris, kembang, dan kain.", duration = 4.5, env = "Ritual" },
	{ speaker = "Pemandu", text = "Berdirilah berdampingan. Jangan ada yang bergerak.", duration = 4 },
	{ speaker = "Pemandu", text = "Malam Suro dimulai. Dusun ini mengingat kalian.", duration = 5 },
	{ text = "Kabut perlahan menipis...", duration = 4.5, env = "Fajar" },
	{ speaker = "Pemandu", text = "Dusun Kelabu kembali tenang. Terima kasih sudah menemaniku.", duration = 5 },
} :: { Step })

return table.freeze(FinalRitualConfig)
