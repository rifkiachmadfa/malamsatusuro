--!nonstrict
-- Konfigurasi Pocong (Phase 9.3, ADR-048).
-- Semua angka = ASUMSI awal. Setel lewat tes Studio, jangan hardcode di service.

local PocongConfig = {}

-- Objek di Workspace (dibuat user di Studio, tidak ada di Git)
PocongConfig.SPAWN_CONTAINER = "PocongSpawn" -- anak langsung = titik spawn (1-4): BasePart / Model / Attachment
PocongConfig.TORCH_CONTAINER = "TorchCounter" -- anak langsung (atau anak Folder) = obor; atau obor tunggal
PocongConfig.TORCH_TAG = "TorchCounter" -- alternatif: obor bertag CollectionService
PocongConfig.TORCH_RADIUS_ATTRIBUTE = "Radius" -- Attribute number di obor, override radius default
PocongConfig.GHOST_FOLDER = "Ghosts" -- folder runtime di Workspace untuk Pocong aktif

-- Template model Pocong: {Service, anak, anak, ...}. Kalau tidak ada -> placeholder + warn.
PocongConfig.MODEL_PATH = table.freeze({ "ServerStorage", "GhostModels", "Pocong" })

-- Item bunga yang membuat pemain jadi target. Cocok lewat Attribute "ItemId" ATAU nama Tool.
-- Kembang Kantil Hitam sengaja TIDAK termasuk (itu hadiah, bukan bunga yang dicari).
PocongConfig.FLOWER_KEYS = table.freeze({
	"MawarMerah",
	"MawarPutih",
	"Melati",
	"KantilKuning",
	"Mawar Merah",
	"Mawar Putih",
	"Kantil Kuning",
})

-- Spawn
PocongConfig.MAX_ACTIVE = 4 -- juga dibatasi jumlah titik PocongSpawn
PocongConfig.SPAWN_TELEGRAPH_SECONDS = 3 -- muncul diam dulu (adil bagi pemain)
PocongConfig.MIN_SPAWN_DISTANCE = 30 -- titik spawn minimal sejauh ini dari pemetik; kalau tak ada, pakai yang terjauh

-- Gerak melompat berirama
PocongConfig.MOVE_SPEED = 14 -- studs/dtk saat fase gerak (rata-rata efektif lebih rendah karena jeda)
PocongConfig.HOP_MOVE_SECONDS = 1.2
PocongConfig.HOP_PAUSE_SECONDS = 0.8
PocongConfig.HOP_HEIGHT = 1.5

-- Serangan
PocongConfig.CATCH_RADIUS = 5
PocongConfig.KNOCK_COOLDOWN_SECONDS = 3 -- per pemain
PocongConfig.POST_KNOCK_PAUSE_SECONDS = 2.5 -- Pocong diam sebentar setelah mengknock

-- Counter obor
PocongConfig.TORCH_DEFAULT_RADIUS = 18
PocongConfig.RETREAT_DISTANCE = 45 -- menjauh dari pemain di zona sampai sejauh ini, lalu menunggu
PocongConfig.RETREAT_SPEED_MULTIPLIER = 1

-- Despawn
PocongConfig.NO_TARGET_GRACE_SECONDS = 4 -- tidak ada pemegang bunga selama ini -> tenggelam
PocongConfig.SINK_SECONDS = 2.5
PocongConfig.SINK_SPEED = 3

-- Teknis
PocongConfig.HOLDER_REFRESH_SECONDS = 0.3 -- seberapa sering Backpack dipindai
PocongConfig.GROUND_RAY_UP = 20
PocongConfig.GROUND_RAY_DOWN = 80

return PocongConfig
