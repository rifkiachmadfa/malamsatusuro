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
	GAMELAN_FAIL = "Pocong", -- PLACEHOLDER (ADR-039): ganti ke hantu lain nanti, cukup tambah entri di JumpscareConfig.Ghosts
} :: { [string]: string })
FailureConfig.DEFAULT_JUMPSCARE = "Pocong"

FailureConfig.SOLO_FAIL_NOTICE = "Kamu gagal. Kembali berbicara kepada Pemandu untuk mengulang."

-- Penyebab gagal yang hukumannya LEBIH RINGAN saat pemain tidak punya rekan yang bisa menyadarkan (ADR-048):
-- solo, atau semua rekan sudah knock (pemain terakhir yang berdiri). Hukumannya jumpscare + respawn, TANPA reset quest
-- dan tanpa knock. Alasannya: knock butuh rekan untuk revive; knock pemain terakhir membuat party buntu (belum ada
-- party wipe untuk quest di luar Kantil). Penyebab yang tidak terdaftar di sini memakai kebijakan lama (ADR-032).
-- Sisi multiplayer (masih ada rekan berdiri) tetap KNOCK untuk semua penyebab.
FailureConfig.RESPAWN_ONLY_WHEN_ALONE = table.freeze({
	GHOST_KUNTILANAK = true,
} :: { [string]: boolean })

-- Jumpscare per hantu ditambahkan di JumpscareByReason di atas bila model berbeda sudah ada.
-- PLACEHOLDER: GHOST_KUNTILANAK sementara memakai DEFAULT_JUMPSCARE (Pocong) sampai model Kuntilanak dibuat user
-- (ServerStorage/GhostModels/Kuntilanak + entri di JumpscareConfig.Ghosts).

FailureConfig.ALONE_RESPAWN_NOTICE = "Kamu ditangkap dan terbangun lagi. Tidak ada rekan di dekatmu, jadi kamu tidak pingsan."

-- Item yang dibersihkan dari Backpack saat quest di-reset (selain Backpack yang memang reset saat respawn, ADR-018).
FailureConfig.RESET_ITEMS = table.freeze({
	KANTIL = table.freeze({ "MawarMerah", "MawarPutih", "Melati", "KantilKuning", "KembangKantilHitam" }),
} :: { [string]: { string } })

return table.freeze(FailureConfig)
