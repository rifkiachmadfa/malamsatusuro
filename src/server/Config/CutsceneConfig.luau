--!strict
-- CutsceneConfig: cutscene kamera ritual akhir (Phase 8, ADR-043). SISI SERVER. Hanya data, tanpa logika.
-- Scene dibuat user dengan plugin Open Cutscene Editor (OCE); ModuleScript-nya ada di Studio (tidak masuk Git, ADR-011):
--   ServerStorage/CutScenes/CutscenePlayer1 .. CutscenePlayer4
-- Semua scene digabung menjadi SATU pemutaran (mode MERGED hasil tes ADR-042) supaya kamera tidak kembali ke pemain
-- di antara scene. Urutan = urutan MODULE_NAMES.

local CutsceneConfig = {}

CutsceneConfig.ENABLED = true -- false = ritual tetap jalan tanpa kamera (hanya letterbox + subtitle)

-- "PARALLEL": kamera diputar bersamaan dengan langkah subtitle FinalRitualConfig.Sequence; kartu TAMAT menunggu
--   kamera selesai (bila kamera lebih lama dari subtitle).
-- "BEFORE_STEPS": kamera diputar penuh dulu, baru subtitle (kamera kembali ke pemain sebelum subtitle mulai).
CutsceneConfig.LAYOUT = "PARALLEL"

CutsceneConfig.FOLDER_NAME = "CutScenes" -- di ServerStorage
CutsceneConfig.MODULE_NAMES = table.freeze({
	"CutscenePlayer1",
	"CutscenePlayer2",
	"CutscenePlayer3",
	"CutscenePlayer4",
})

-- Nama objek hasil plugin OCE (terbukti di tes Studio, lihat .ai/CUTSCENE_GUIDE.md).
CutsceneConfig.LOCAL_PLAYER_NAME = "LocalCutscenePlayer" -- LocalScript pemutar di tiap modul
CutsceneConfig.INFO_NAME = "CutsceneInfo" -- Folder titik kamera Position1..N
CutsceneConfig.TIME_VALUE_NAME = "Time" -- NumberValue detik MENUJU titik itu

-- Plugin tidak memberi sinyal selesai, jadi durasi = jumlah `Time` semua titik + margin.
CutsceneConfig.DURATION_MARGIN = 0.25 -- detik, agar akhir tween dan pemulihan kamera script selesai dulu
-- Titik pertama scene ke-2 dst memakai Time ini (cut cepat antar scene). nil = kamera terbang dari akhir scene sebelumnya.
CutsceneConfig.SCENE_JOIN_TIME = 0.05 :: number?

return table.freeze(CutsceneConfig)
