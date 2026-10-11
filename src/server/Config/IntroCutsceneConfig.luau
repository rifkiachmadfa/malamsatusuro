--!strict
-- IntroCutsceneConfig: cutscene pembuka saat pemain masuk (TES awal, ADR-041). SISI SERVER. Hanya data.
-- Cutscene dibuat user dengan plugin Open Cutscene Editor; ModuleScript-nya ada di Studio (tidak masuk Git, ADR-011):
--   ServerStorage/CutScenes/CutscenePlayer1 .. CutscenePlayer4  (masing-masing punya fungsi PlayCutscene(player))
-- Pemain ke-N yang masuk memutar CutscenePlayerN (slot terendah yang kosong; dipakai ulang setelah pemain keluar).

local IntroCutsceneConfig = {}

IntroCutsceneConfig.ENABLED = true -- matikan (false) untuk menonaktifkan tanpa menghapus kode
IntroCutsceneConfig.FOLDER_NAME = "CutScenes" -- di ServerStorage
IntroCutsceneConfig.MODULE_PREFIX = "CutscenePlayer" -- + nomor slot
IntroCutsceneConfig.MAX_SLOT = 4
IntroCutsceneConfig.START_DELAY = 1 -- detik setelah karakter pertama muncul, agar kamera tidak direset oleh spawn

return table.freeze(IntroCutsceneConfig)
