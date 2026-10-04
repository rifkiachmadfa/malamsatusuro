# SESSION HANDOFF

Last Updated: 2026-10-04

## Ringkasan
- Fase aktif: Phase 1 SELESAI. Siap masuk PHASE 2 — QUEST SYSTEM.
- Repo: github.com/rifkiachmadfa/malamsatusuro (folder lokal: D:\roblox\malam-satu-suro)
- `src/` berisi: shared (Config/GameConfig, Config/DialogueConfig, Util/Log, Util/Spatial, Util/Interactable, Remotes),
  server (Services/GameManager, SpawnService, InteractionService, DialogueService, init.server),
  client (Controllers/InteractionController, DialogueController, UI/Theme, init.client).
- Belum ada logika quest/gameplay.

## Cara kerja saat ini
- Chat Claude TANPA MCP Studio. AI hanya melihat GitHub dan file yang dikirim; hasil test Studio/Output ditempel oleh user.
- Git hanya untuk script. Map/objek Studio tetap di place file lokal (ADR-011). Place file di-ignore Git dan dicadangkan manual.
- Editor: extension "Luau Language Server"; extension Lua (sumneko) dimatikan untuk workspace ini.

## Objek Workspace yang dibuat user (di Studio, tidak ada di Git)
- Workspace.SpawnPoints: Spawn1 (SpawnLocation)
- Workspace.NPC.Pemandu: lihat CURRENT_STATE

## Pola yang harus diikuti sistem berikutnya
- Objek interaktif: tag `Interactable` + attribute `InteractionId`; daftarkan handler lewat `InteractionService.register(id, handler)` (ADR-016).
- Remote baru: tambahkan nama di `Remotes.Names`; server memvalidasi semua payload.
- GUI: dibangun lewat kode di client, pakai `UI/Theme` (ADR-017).

## Langkah berikutnya
1. User: tinjau SkyboxInserter; siapkan naskah dialog Pemandu.
2. Phase 2: QuestService.