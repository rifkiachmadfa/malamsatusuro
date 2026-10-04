# SESSION HANDOFF

Last Updated: 2026-10-04

## Ringkasan
- Fase aktif: PHASE 1 — FOUNDATION (Task 1.1 sampai 1.6 selesai)
- Repo: github.com/rifkiachmadfa/malamsatusuro (folder lokal: D:\roblox\malam-satu-suro)
- `src/` berisi: `shared/Config/GameConfig`, `shared/Util/Log`, `shared/Remotes`, `server/Services/GameManager`, `server/Services/SpawnService`, serta bootstrap `server/init.server` dan `client/init.client`.
- Belum ada logika quest/gameplay.

## Cara kerja saat ini
- Chat Claude TANPA MCP Studio. AI hanya melihat GitHub; hasil test Studio/Output ditempel oleh user.
- Git hanya untuk script. Map/objek Studio tetap di place file lokal (ADR-011). Place file di-ignore Git dan dicadangkan manual.
- Editor: pakai extension "Luau Language Server"; extension Lua (sumneko) dimatikan untuk workspace ini.

## Objek Workspace yang sudah dibuat user (di Studio, tidak ada di Git)
- Workspace.SpawnPoints: Spawn1 (SpawnLocation, satu titik spawn untuk semua pemain)

## Kode debug SEMENTARA (harus dihapus di akhir Phase 1)
- DebugPing (remote + handler di init.server + FireServer di init.client)
- Uji transisi state di init.server (task.delay + debugTestPlayerStates)
- Log GameState di init.client

## Langkah berikutnya
1. Task 1.7: Pemandu NPC dan interaksi dasar (AI akan memberi daftar objek Workspace).
2. Task 1.8: GUI foundation.