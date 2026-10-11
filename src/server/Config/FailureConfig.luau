--!strict
-- FailureConfig: kebijakan kegagalan quest (Phase 6, ADR-032). SISI SERVER.
-- Multiplayer: pemain yang gagal di-KNOCK (KnockService). Solo: jumpscare -> respawn -> quest di-reset,
-- mulai lagi lewat Pemandu.

local FailureConfig = {}

-- Saklar hukuman bunga salah di makam. false = bunga salah hanya notifikasi (untuk menguji makam tanpa hukuman).
FailureConfig.FAIL_ON_WRONG_FLOWER = true

-- Jumpscare per penyebab gagal (id hantu dari JumpscareConfig.Ghosts). Penyebab tanpa entri memakai DEFAULT_JUMPSCARE.
FailureConfig.JumpscareByReason = table.freeze({
	WRONG_FLOWER = "Pocong",
} :: { [string]: string })
FailureConfig.DEFAULT_JUMPSCARE = "Pocong"

FailureConfig.SOLO_FAIL_NOTICE = "Kamu gagal. Kembali berbicara kepada Pemandu untuk mengulang."

-- Item yang dibersihkan dari Backpack saat quest di-reset (selain Backpack yang memang reset saat respawn, ADR-018).
FailureConfig.RESET_ITEMS = table.freeze({
	KANTIL = table.freeze({ "MawarMerah", "MawarPutih", "Melati", "KantilKuning", "KembangKantilHitam" }),
} :: { [string]: { string } })

return table.freeze(FailureConfig)
