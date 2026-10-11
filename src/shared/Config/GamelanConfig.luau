--!strict
-- GamelanConfig: aturan minigame ritme gamelan (quest Kain Kafan, Phase 7). Hanya data, tanpa logika.
-- SATU pemain memainkannya (keputusan user 2026-10-11, ADR-038). Gaya Guitar Hero: 4 kolom, not jatuh ke garis
-- tekan. PC: tombol Q W E R. Mobile: ketuk kolom. Server membuat chart, memvalidasi tiap tekanan, dan menghitung skor.

local GamelanConfig = {}

-- ===== Musik =====
-- PLACEHOLDER: isi dengan ID audio gamelan (format "rbxassetid://102528213806007"). Kosong = game tetap berjalan tanpa suara.
GamelanConfig.SOUND_ID = "rbxassetid://102528213806007"
GamelanConfig.SOUND_VOLUME = 0.8
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

-- ===== Penilaian =====
GamelanConfig.PERFECT_WINDOW = 0.10 -- detik, selisih tekan vs waktu not
GamelanConfig.GOOD_WINDOW = 0.20
GamelanConfig.PERFECT_POINTS = 10
GamelanConfig.GOOD_POINTS = 7
-- Skor akhir = persen dari poin maksimum (0-100). Lulus bila >= REQUIRED_SCORE.
GamelanConfig.REQUIRED_SCORE = 80

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
