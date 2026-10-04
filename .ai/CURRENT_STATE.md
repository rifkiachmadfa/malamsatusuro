# CURRENT PROJECT STATE

Last Updated:
2026-10-04

## CURRENT PHASE

PHASE 2 — QUEST SYSTEM: SELESAI DENGAN CATATAN (lihat "BELUM DITES").
Berikutnya: PHASE 3 — INTERACTION + INVENTORY (belum dimulai; mulai dengan audit + rencana, tanpa langsung kode).

## TOOLCHAIN

Windows → VS Code → Rojo 7.7.1 → Roblox Studio → Git / GitHub
AI bekerja tanpa MCP Studio (ADR-012): hasil test Studio/Output ditempel oleh user.

## SISTEM YANG SUDAH ADA

Phase 1 (dites user, 1 dan 2+ pemain):
- Kerangka src/, Remotes, GameManager, SpawnService, InteractionService, DialogueService,
  InteractionController, DialogueController, Theme (ADR-013..017)

Phase 2 (dites user di Studio, 1 pemain, 2026-10-04):
- shared/Config/QuestConfig: data 3 quest (states, resets, counters, objectives, dialog Pemandu)
- server/Services/QuestService: state quest party-wide. API: getState, getActiveQuestId, getCounter,
  startGame, advance, addProgress, reset, onStateChanged, markPlayerDone/isPlayerDone/areAllPlayersDone
- server/Services/PemanduService: dialog Pemandu mengikuti state quest; transisi setelah dialog dibaca sampai habis
- client/Controllers/QuestController: Quest UI kanan atas (minimize, TopbarSafeInsets), hanya merender snapshot server
- DialogueService: parameter `onFinished` (hanya bila dibaca sampai baris terakhir)
- DialogueConfig: dialog quest PLACEHOLDER (Brief, Hint, Submit) + Pemandu_Idle

## HASIL TEST PHASE 2

Dilaporkan user (Studio, Play, 1 pemain):
- T1 mulai game lewat dialog intro: LULUS (INTRO -> QUEST_KERIS, Keris LOCKED -> ACTIVE)
- T2 Pemandu Brief: LULUS (ACTIVE -> SEARCHING_KELOR)
- T3 counter party: LULUS (addProgress menambah counter, UI berubah)
- T4 lompat state ditolak: LULUS (SEARCHING_KELOR -> KERIS_OBTAINED = false + warning, state tetap)
- advance berurutan KEY_OBTAINED..KERIS_OBTAINED: LULUS (4x true)
- addProgress pada quest LOCKED (Kantil) ditolak: perilaku benar
- T5 serah-terima Keris ke Pemandu dan T6 Kantil + party wipe (reset): dilaporkan user "aman" (log tidak ditempel)

Verifikasi AI (bukan Studio): luau-compile 8 file OK; tes logika dengan mock Roblox 30/30.

## OBJEK STUDIO (tidak ada di Git, ADR-011)

- Workspace.SpawnPoints.Spawn1; Workspace.NPC.Pemandu (tag Interactable, InteractionId=Pemandu)
- Workspace.QuestObjects: KelorSpawns (KelorSpawn_1..8), FlowerSpawns (FlowerSpawn_1..8), Graves (Grave_1..4),
  Chest, Gamelan, RitualCollection
- ServerStorage.QuestTemplates: DaunKelor, KantilKuning, MawarMerah, MawarPutih, Melati
- Belum ada template: Kunci, Keris, Minyak Zaitun, Kantil Hitam, Kain Kafan (dibutuhkan Phase 3-7)
- Belum diperiksa: tipe DaunKelor (Model/Part), PrimaryPart, tag/attribute pada spawn dan template (Phase 3/4)

## CATATAN PENTING UNTUK TEST

Command Bar Studio harus memakai konteks Server. Pola test: `_G.Q = require(game.ServerScriptService.Server.Services.QuestService)`
lalu panggil `_G.Q.addProgress(...)`, `_G.Q.advance(...)`, `_G.Q.reset(...)`. Satu baris per eksekusi.

## CATATAN KEAMANAN

`SkyboxInserter` (Requiring asset 257460689) dari model langit Toolbox masih perlu ditinjau/dihapus sebelum publish.

## ASUMSI YANG BERLAKU

- Bunga Kantil dihitung total 4 (bukan per jenis).
- Objective "Bicara dengan Pemandu" ditambahkan di tiap quest (tidak ada di contoh GDD).
- Serah-terima ke Pemandu di Phase 2 hanya memeriksa STATE. Pemeriksaan kepemilikan item dibuat di Phase 3.
- Satu server = satu party; boleh join di tengah game.
- Kelor/bunga BELUM muncul di map: spawn dan pengambilan item adalah Phase 3-5 (bukan bug Phase 2).

## BELUM ADA

InventoryService, ItemConfig, RandomSpawnService, pengambilan item, peti, puzzle Keris/Kantil, knock, revive,
gamelan, ritual akhir, cutscene, efek horor. Teks dialog masih placeholder.

## NEXT ACTION

1. AI: audit repo + rencana Phase 3 (tanpa kode), ajukan pertanyaan konfirmasi.
2. User: jawab pertanyaan Phase 3 (lihat SESSION_HANDOFF); kirim screenshot isi DaunKelor (Explorer + Properties).
3. Opsional: jalankan T7-T9.

## IMPORTANT

Dokumen ini adalah kondisi terakhir yang diketahui. Jangan menulis bahwa sistem berfungsi kalau belum dites.