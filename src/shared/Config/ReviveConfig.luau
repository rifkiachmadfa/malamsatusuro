--!strict
-- ReviveConfig: pengaturan revive dengan Minyak Zaitun (Phase 6, Task 6.4, ADR-035).
-- Shared: server memvalidasi, client memakai ITEM_ID dan MAX_DISTANCE yang SAMA untuk menampilkan prompt.
-- Revive = pemain NORMAL yang MEMEGANG (equip) Minyak Zaitun menahan [E] di dekat pemain KNOCK selama HOLD_SECONDS.

local ReviveConfig = {}

ReviveConfig.ITEM_ID = "MinyakZaitun" -- item (ItemConfig) yang dipegang penyelamat; dikurangi 1 saat revive berhasil
ReviveConfig.HOLD_SECONDS = 3 -- lama menahan interaksi (dihitung SERVER)
ReviveConfig.MAX_DISTANCE = 8 -- studs penyelamat <-> pemain knock (client menampilkan prompt dalam jarak ini)
ReviveConfig.DISTANCE_TOLERANCE = 4 -- toleransi lag untuk validasi server (sesi dibatalkan jika lewat MAX + toleransi)
ReviveConfig.TICK_SECONDS = 0.1 -- interval validasi ulang selama sesi berjalan
ReviveConfig.REQUEST_COOLDOWN = 0.5 -- detik, per pemain (anti-spam Start)

return table.freeze(ReviveConfig)
