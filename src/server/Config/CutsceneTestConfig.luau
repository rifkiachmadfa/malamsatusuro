--!strict
-- CutsceneTestConfig: konfigurasi TRIGGER TES cutscene (Phase 8, ADR-042). HANYA UNTUK PENGEMBANGAN.
-- Hanya data, tanpa logika. Matikan lewat ENABLED = false, atau hapus CutsceneTestService + file ini sebelum publish.

local CutsceneTestConfig = {}

CutsceneTestConfig.ENABLED = true
CutsceneTestConfig.ONLY_IN_STUDIO = true -- true = tidak aktif di server live walau ENABLED = true

-- Objek di Workspace (dibuat user di Studio, tidak ada di Git). Dicari rekursif berdasarkan nama.
CutsceneTestConfig.TRIGGER_NAME = "triggerCutscene"
CutsceneTestConfig.FIND_TIMEOUT = 15 -- detik menunggu objek trigger muncul saat boot

-- ServerStorage/<FOLDER_NAME>/<MODULE_NAMES[i]>; dimainkan BERURUTAN dari atas ke bawah.
CutsceneTestConfig.FOLDER_NAME = "CutScenes"
CutsceneTestConfig.MODULE_NAMES = table.freeze({
	"CutscenePlayer1",
	"CutscenePlayer2",
	"CutscenePlayer3",
	"CutscenePlayer4",
})

-- Modul cutscene memanggil PlayCutscene(player) yang meng-clone LocalScript ke PlayerGui pemain.
-- Cutscene dianggap SELESAI saat clone itu hilang dari PlayerGui (menghancurkan diri sendiri).
CutsceneTestConfig.LOCAL_PLAYER_NAME = "LocalCutscenePlayer"
CutsceneTestConfig.MAX_WAIT_PER_CUTSCENE = 120 -- detik; batas tunggu bila durasi modul tidak diisi di DURATIONS
CutsceneTestConfig.NO_CLONE_DELAY = 5 -- detik jeda jika clone tidak terdeteksi (nama beda / tidak dibuat)
CutsceneTestConfig.GAP_BETWEEN = 0 -- jeda antar cutscene (0 = langsung sambung)

-- Script Open Cutscene Editor TIDAK menghilangkan clone-nya sendiri saat selesai (terbukti di tes Studio), jadi
-- durasi dihitung dari isi clone: CutsceneInfo berisi titik kamera (Position1, Position2, ...), tiap titik punya
-- NumberValue `Time` (detik menuju titik itu). Durasi = jumlah semua `Time` + DURATION_MARGIN.
-- Urutan prioritas durasi per modul: DURATIONS (manual) > otomatis dari CutsceneInfo > tunggu clone hilang
-- (maksimal MAX_WAIT_PER_CUTSCENE). Lanjut ke cutscene berikutnya saat clone hilang ATAU durasi habis.
CutsceneTestConfig.AUTO_DURATION = true
CutsceneTestConfig.INFO_NAME = "CutsceneInfo"
CutsceneTestConfig.TIME_VALUE_NAME = "Time"
CutsceneTestConfig.DURATION_MARGIN = 0.25 -- detik tambahan agar akhir tween (dan pemulihan kamera script) selesai dulu
CutsceneTestConfig.DURATIONS = table.freeze({} :: { [string]: number }) -- override manual, mis. CutscenePlayer1 = 12

-- MODE "MERGED": titik kamera (Position1..N) dari SEMUA modul digabung menjadi satu CutsceneInfo lalu diputar sebagai SATU
-- pemutaran (memakai LocalCutscenePlayer milik modul pertama), sehingga kamera tidak kembali ke pemain di antara scene.
-- Titik pertama scene ke-2 dst: `Time`-nya diganti SCENE_JOIN_TIME (detik) agar perpindahan antar scene berupa cut cepat;
-- nil = pakai `Time` aslinya (kamera terbang dari akhir scene sebelumnya ke awal scene berikutnya).
-- MODE "SEQUENTIAL": tiap modul memanggil PlayCutscene sendiri-sendiri (kamera kembali ke pemain di antara scene).
-- Bila penggabungan gagal (LocalCutscenePlayer / CutsceneInfo tidak ditemukan), otomatis jatuh ke SEQUENTIAL.
CutsceneTestConfig.MODE = "MERGED"
CutsceneTestConfig.SCENE_JOIN_TIME = 0.05 :: number?

-- Diagnostik: cetak isi clone ke Output saat cutscene mulai (mati secara default; nyalakan bila perlu).
CutsceneTestConfig.DUMP_CLONE_INFO = false
CutsceneTestConfig.DUMP_MAX_ITEMS = 25

-- Teks ProximityPrompt (dipakai hanya jika trigger belum punya ProximityPrompt).
CutsceneTestConfig.PROMPT_ACTION = "Putar Cutscene"
CutsceneTestConfig.PROMPT_OBJECT = "TES"
CutsceneTestConfig.PROMPT_DISTANCE = 10

return table.freeze(CutsceneTestConfig)
