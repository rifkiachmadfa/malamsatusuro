--!strict
-- GamelanConfig: aturan minigame ritme gamelan (quest Kain Kafan, Phase 7). Hanya data, tanpa logika.
-- SATU pemain memainkannya (keputusan user 2026-10-11, ADR-038). Gaya Guitar Hero: 4 kolom, not jatuh ke garis
-- tekan. PC: tombol Q W E R. Mobile: ketuk kolom. Server membuat chart, memvalidasi tiap tekanan, dan menghitung skor.
-- Skor MULAI 100 dan hanya turun; skor < REQUIRED_SCORE kapan pun = gagal seketika (ADR-039).

local GamelanConfig = {}

-- ===== Musik =====
-- PLACEHOLDER: isi dengan ID audio gamelan (format "rbxassetid://102528213806007"). Kosong = game tetap berjalan tanpa suara.
GamelanConfig.SOUND_ID = "rbxassetid://102528213806007"
GamelanConfig.SOUND_VOLUME = 0.8 -- volume musik untuk pemain yang bermain (lokal, tepat sinkron dengan not)
-- Musik untuk pemain LAIN (ADR-039): suara spasial di objek Gamelan, diputar client masing-masing.
GamelanConfig.WORLD_SOUND_VOLUME = 1
GamelanConfig.WORLD_ROLLOFF_MIN = 20 -- studs: sampai jarak ini volume penuh
GamelanConfig.WORLD_ROLLOFF_MAX = 160 -- studs: di luar jarak ini tidak terdengar
-- Attribute pada objek Gamelan (direplikasi ke semua client; juga berlaku bagi pemain yang baru masuk).
GamelanConfig.MUSIC_PLAYER_ATTR = "MusicPlayerUserId" -- UserId pemain yang bermain; kosong = tidak ada musik
GamelanConfig.MUSIC_START_ATTR = "MusicStartServerTime" -- Workspace:GetServerTimeNow() saat musik pemain mulai
-- Durasi sesi = durasi musik (1 menit 37 detik). Ubah di sini bila musik diganti.
GamelanConfig.DURATION_SECONDS = 97

-- ===== Kolom / input =====
GamelanConfig.LANE_COUNT = 4
GamelanConfig.LANE_LABELS = table.freeze({ "Q", "W", "E", "R" })
GamelanConfig.LANE_KEYCODES = table.freeze({ Enum.KeyCode.Q, Enum.KeyCode.W, Enum.KeyCode.E, Enum.KeyCode.R })

-- ===== Chart (dibuat server, acak per sesi) =====
-- Belum ada beatmap per lagu: not diletakkan di grid ketukan (BPM) dengan peluang NOTE_CHANCE per ketukan.
-- Setelah musik asli masuk: sesuaikan BPM dan LEAD_IN_SECONDS agar not terasa menyatu dengan musik.
GamelanConfig.BPM = 120
GamelanConfig.LEAD_IN_SECONDS = 2 -- not pertama muncul setelah jeda ini
GamelanConfig.TAIL_SECONDS = 4 -- tidak ada not di akhir musik
GamelanConfig.NOTE_CHANCE = 0.75
GamelanConfig.REPEAT_LANE_REJECT = 0.7 -- peluang menghindari kolom yang sama berturut-turut
GamelanConfig.APPROACH_SECONDS = 1.6 -- lama not jatuh dari atas ke garis tekan (tampilan)

-- ===== Penilaian (ADR-039: skor dipertahankan, bukan dikumpulkan) =====
GamelanConfig.PERFECT_WINDOW = 0.30 -- detik, selisih tekan vs waktu not
GamelanConfig.GOOD_WINDOW = 0.40
GamelanConfig.START_SCORE = 100
GamelanConfig.PERFECT_PENALTY = 0 -- pengurang skor per hasil
GamelanConfig.GOOD_PENALTY = 0
GamelanConfig.MISS_PENALTY = 2
-- Skor < REQUIRED_SCORE kapan pun = GAGAL seketika (UI ditutup, jumpscare). Bertahan sampai musik selesai = lulus.
-- Dengan nilai di atas: 6 Miss masih aman (82), Miss ke-7 gagal (79). Setel PENALTY agar kesulitan pas.
GamelanConfig.REQUIRED_SCORE = 80
-- Not dianggap Miss oleh server setelah waktu not + GOOD_WINDOW + MISS_GRACE (kelonggaran latensi jaringan).
GamelanConfig.MISS_GRACE = 0.4

-- ===== Validasi server (anti-curang, ADR-038) =====
GamelanConfig.READY_TIMEOUT = 10 -- detik menunggu client selesai memuat musik
GamelanConfig.END_GRACE = 3 -- detik setelah durasi habis sebelum server menutup sesi
-- Waktu lagu yang dilaporkan client (t) harus sesuai jam server: elapsed - SYNC_LATE <= t <= elapsed + SYNC_EARLY.
GamelanConfig.SYNC_EARLY_TOLERANCE = 0.3
GamelanConfig.SYNC_LATE_TOLERANCE = 2.0 -- mencakup latensi/lag jaringan
GamelanConfig.MIN_HIT_INTERVAL = 0.03 -- detik, antar tekanan dari satu pemain
GamelanConfig.MAX_HITS_FACTOR = 4 -- batas total tekanan = jumlah not x faktor ini (cegah spam)

-- ===== Gamelan di dunia =====
GamelanConfig.INTERACTION_ID = "Gamelan"
GamelanConfig.OBJECT_NAME = "Gamelan" -- Workspace.QuestObjects.Gamelan
GamelanConfig.ACTION_TEXT = "Mainkan"
GamelanConfig.OBJECT_TEXT = "Gamelan"
GamelanConfig.MAX_DISTANCE = 12

return table.freeze(GamelanConfig)
