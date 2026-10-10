--!strict
-- FailureConfig: kebijakan kegagalan quest (Phase 6, ADR-032). SISI SERVER.
-- Multiplayer: pemain yang gagal di-KNOCK (KnockService). Solo: jumpscare -> respawn -> quest di-reset,
-- mulai lagi lewat Pemandu.

local FailureConfig = {}

-- Saklar hukuman bunga salah di makam. false = bunga salah hanya notifikasi (untuk menguji makam tanpa hukuman).
FailureConfig.FAIL_ON_WRONG_FLOWER = true

-- Solo: jeda sebelum respawn (detik). Task 6.2 menggantikannya dengan durasi jumpscare.
FailureConfig.SOLO_RESPAWN_DELAY = 1.5
FailureConfig.SOLO_FAIL_NOTICE = "Kamu gagal. Kembali ke Pemandu untuk mengulang dari awal."

-- Item yang dibersihkan dari Backpack saat quest di-reset (selain Backpack yang memang reset saat respawn, ADR-018).
FailureConfig.RESET_ITEMS = table.freeze({
	KANTIL = table.freeze({ "MawarMerah", "MawarPutih", "Melati", "KantilKuning", "KembangKantilHitam" }),
} :: { [string]: { string } })

return table.freeze(FailureConfig)
