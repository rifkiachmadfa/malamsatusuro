--!strict
-- MemoryPuzzleConfig: aturan minigame ingat-dan-susun suku kata (peti Keris). Hanya data.
-- Server memilih urutan acak dari SYLLABLES; pemain melihatnya MEMORIZE_SECONDS lalu harus menyusunnya kembali.

local MemoryPuzzleConfig = {}

-- Suku kata aksara Jawa (Hanacaraka). Urutan di sini hanya daftar token; urutan soal diacak server.
MemoryPuzzleConfig.SYLLABLES = table.freeze({ "HA", "NA", "CA", "RA", "KA" })

MemoryPuzzleConfig.MEMORIZE_SECONDS = 6 -- waktu melihat urutan
MemoryPuzzleConfig.ANSWER_SECONDS = 30 -- waktu menyusun setelah urutan disembunyikan
MemoryPuzzleConfig.TIMEOUT_GRACE = 3 -- toleransi server sebelum percobaan dianggap kedaluwarsa
MemoryPuzzleConfig.MEMORIZE_TOLERANCE = 0.5 -- toleransi lag: Submit sebelum MEMORIZE_SECONDS - ini ditolak
MemoryPuzzleConfig.ACTION_COOLDOWN = 0.2 -- detik, per pemain

return table.freeze(MemoryPuzzleConfig)
