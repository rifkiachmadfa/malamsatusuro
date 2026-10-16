# ADR-048 — POCONG (TASK 9.3) DIGANTI: SPAWN DI `PocongSpawn`, TARGET = PEMEGANG BUNGA, COUNTER = ZONA OBOR `TorchCounter`

> Tempel isi bagian ini ke `.ai/DECISIONS.md` (file ini dibuat terpisah karena DECISIONS.md tidak bisa di-diff tanpa melihat isinya), lalu hapus file ini.
> Tandai butir Pocong di ADR-047 / TASKS 9.3 sebagai `[DIGANTI ADR-048]`.

## Context

Task 9.3 di ADR-047 mendefinisikan Pocong yang muncul 40-60 studs dari pemetik dan dikalahkan dengan berkumpul bersama rekan. Arahan user (2026-10-20) mengganti perilaku itu.

## Decision

- Spawn: tiap bunga dipetik, server memunculkan SATU Pocong di salah satu titik anak `Workspace.PocongSpawn` (1-4 titik). Titik dipilih acak dari yang kosong dan minimal `MIN_SPAWN_DISTANCE` dari pemetik (fallback: yang terjauh). Jumlah Pocong aktif <= jumlah titik dan <= `MAX_ACTIVE`.
- Target: HANYA pemain yang memegang bunga (Tool bunga di Backpack atau sedang dipegang). Pemain tanpa bunga tidak pernah dikejar.
- Counter: zona obor `Workspace.TorchCounter` (radius dari Attribute `Radius`, default `TORCH_DEFAULT_RADIUS`).
  - Pocong tidak bisa masuk zona dan tidak bisa mengknock pemain di dalam zona.
  - Jika SEMUA pemegang bunga ada di zona: Pocong mundur sampai `RETREAT_DISTANCE`, lalu menunggu (WAIT).
  - Begitu ada pemegang bunga di luar zona: Pocong mengejar lagi (CHASE).
- Kena = `KnockService` reason `GHOST` (jalur yang sama dengan Kuntilanak), cooldown per pemain, Pocong diam sebentar setelah mengknock.
- Despawn: tidak ada pemegang bunga selama `NO_TARGET_GRACE_SECONDS` -> tenggelam. `PocongService.reset()` dipanggil saat party wipe / reset quest KANTIL.
- Gerak: melompat berirama (gerak 1,2 dtk, jeda 0,8 dtk), tanpa pathfinding, anchored, digerakkan server.
- Config: `src/shared/Config/PocongConfig.luau`. Logika: `src/server/Services/PocongService.luau`. Dependensi API proyek disuntik lewat `PocongService.configure`.

## Consequences / batasan

- Semua angka = ASUMSI, belum dites.
- Nama Tool/Attribute bunga di `PocongConfig.FLOWER_KEYS` adalah tebakan; cocokkan dengan ItemConfig.
- Satu Pocong per bunga bisa membuat 4 Pocong sekaligus; setel `MAX_ACTIVE` dari hasil tes.
- Pocong terhalang zona hanya secara posisi XZ-3D radius; obor di area sempit/bertingkat mungkin perlu radius per obor.
- Dependency Studio: `Workspace.PocongSpawn` (1-4 part), `Workspace.TorchCounter` (obor), model `ServerStorage.GhostModels.Pocong` (opsional; ada placeholder).

## Pemasangan (3 titik, di luar patch ini karena file target belum terbaca)

1. Bootstrap server (tempat service lain di-start), SESUDAH `KnockService` siap:

```lua
local PocongService = require(script.Parent.Services.PocongService) -- sesuaikan path
PocongService.configure({
	knock = function(player, reason)
		KnockService.knock(player, reason) -- sesuaikan nama/signature asli
	end,
	isPlayerNormal = function(player)
		return KnockService.isNormal(player) -- sesuaikan; JIKA TIDAK DIISI, pemain yang sudah knock bisa di-knock ulang
	end,
	-- hasFlower: opsional, default memindai Tool bunga
})
PocongService.start()
```

2. `CollectibleService`, tepat setelah bunga BERHASIL diberikan (setelah validasi + give, di jalur server):

```lua
PocongService.onFlowerCollected(player)
```

3. Party wipe / reset quest KANTIL / quest KANTIL selesai (di tempat bunga direset):

```lua
PocongService.reset()
```

## TEST (dijalankan user di Studio; belum ada hasil)

EXPECTED / TEST, ulangi untuk 1, 2, 3, 4 pemain:

1. Petik bunga -> setelah ~3 dtk Pocong bergerak melompat dari titik `PocongSpawn` menuju pemegang bunga.
2. Pemain TANPA bunga di dekat Pocong -> tidak dikejar, tidak di-knock.
3. Pemegang bunga masuk zona obor -> Pocong berhenti di tepi zona / menjauh, lalu menunggu.
4. Pemain keluar zona -> Pocong mengejar lagi.
5. Pocong menyentuh pemain di luar zona -> knock (reason GHOST); tidak knock ulang dalam 3 dtk.
6. Pemain di dalam zona di tepi, Pocong menempel -> TIDAK di-knock.
7. Letakkan semua bunga di makam / buang bunga -> Pocong tenggelam setelah ~4 dtk.
8. Petik 4 bunga cepat -> maksimum Pocong = jumlah titik; tidak ada dua Pocong di titik yang sama.
9. Party wipe -> semua Pocong hilang.
10. Pemain keluar saat dikejar -> tidak ada error di Output.

RESULT: BELUM DIJALANKAN.
