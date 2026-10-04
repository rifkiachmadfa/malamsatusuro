# CURRENT PROJECT STATE

Last Updated:
2026-10-04

## CURRENT PHASE

PHASE 1 — FOUNDATION (Task 1.1 sampai 1.6 selesai)


## TOOLCHAIN

Windows → VS Code → Rojo 7.7.1 → Roblox Studio → Git / GitHub
AI bekerja tanpa MCP Studio (ADR-012): hasil test Studio/Output ditempel oleh user.


## SISTEM YANG SUDAH ADA DAN SUDAH DITES

- Kerangka src/: shared/Config/GameConfig, shared/Util/Log, bootstrap server dan client
- shared/Remotes: pembuat dan pengambil RemoteEvent (ADR-013)
- server/Services/GameManager: state game dan pemain dengan transisi eksplisit, direplikasi lewat Attribute (ADR-014)
- server/Services/SpawnService: pemeriksaan dependency SpawnPoints dan log posisi spawn (ADR-015)

Hasil test: 1 pemain lulus. Test 2 pemain lulus untuk GameManager. Test 4 pemain untuk SpawnService belum dilaporkan.


## OBJEK WORKSPACE (di Studio, tidak ada di Git)

- Workspace.SpawnPoints: Spawn1 (SpawnLocation)
- Map desa belum ada (hanya Baseplate dari Rojo dan titik spawn)


## KODE DEBUG SEMENTARA (hapus di akhir Phase 1)

- DebugPing (Remotes.Names, handler di init.server, FireServer di init.client)
- Uji transisi state di init.server
- Log GameState di init.client


## BELUM ADA

QuestService, PartyService, InventoryService, InteractionService, RandomSpawnService, chest, Kelor, quest Keris, bunga, puzzle Kantil, knock, revive, gamelan, quest Kafan, ritual akhir, Quest UI, cutscene, efek horor, Pemandu NPC.


## NEXT ACTION

1. Task 1.7: Pemandu NPC dan interaksi dasar [E] tervalidasi server.
2. Task 1.8: GUI foundation.


## IMPORTANT

Dokumen ini adalah kondisi terakhir yang diketahui. Perbarui setelah pekerjaan signifikan.
Jangan menulis bahwa sebuah sistem berfungsi kalau belum dites.