# CURRENT PROJECT STATE

Last Updated:
2026-10-04

## CURRENT PHASE

PHASE 1 — FOUNDATION: SELESAI.
Berikutnya: PHASE 2 — QUEST SYSTEM (belum dimulai).


## TOOLCHAIN

Windows → VS Code → Rojo 7.7.1 → Roblox Studio → Git / GitHub
AI bekerja tanpa MCP Studio (ADR-012): hasil test Studio/Output ditempel oleh user.


## SISTEM YANG SUDAH ADA DAN SUDAH DITES

- Kerangka src/: shared/Config (GameConfig, DialogueConfig), shared/Util (Log, Spatial, Interactable), bootstrap server dan client
- shared/Remotes: pembuat dan pengambil RemoteEvent (ADR-013). Remote aktif: InteractionRequest, DialogueUpdate, DialogueAction
- server/Services/GameManager: state game dan pemain, direplikasi lewat Attribute (ADR-014)
- server/Services/SpawnService: pemeriksaan dependency SpawnPoints (ADR-015)
- server/Services/InteractionService: interaksi [E] tervalidasi server, tag + attribute (ADR-016)
- server/Services/DialogueService: sesi dialog per pemain, indeks baris di server
- client/Controllers/InteractionController dan DialogueController; client/UI/Theme hitam-putih (ADR-017)
- Pemandu NPC: dialog berjalan; teks dialog masih PLACEHOLDER (ganti dengan naskah GDD)

Hasil test (dilaporkan user, 2026-10-04):
- Interaksi dan dialog Pemandu: lulus (1 pemain, 2+ pemain)
- Tampilan dialog: lulus di berbagai device di Device Emulator
- Output server/client: tanpa error dari kode project
- Belum dites: 4 pemain penuh; disconnect/reconnect saat dialog (dijadwalkan Phase 10)


## OBJEK WORKSPACE (di Studio, tidak ada di Git)

- Workspace.SpawnPoints: Spawn1 (SpawnLocation)
- Workspace.NPC.Pemandu: Model R15 (Block Rig), HumanoidRootPart Anchored, tag Interactable,
  attribute InteractionId=Pemandu, ActionText=Bicara, ObjectText=Pemandu, MaxDistance=10
- Map desa belum ada


## CATATAN KEAMANAN

Output Studio menunjukkan `Requiring asset 257460689 (cloud_257463543.SkyboxInserter)`: script dari model langit Toolbox
memuat modul dari asset ID luar. Bukan kode project. Perlu ditinjau/dihapus user sebelum publish.


## BELUM ADA

QuestService, PartyService, InventoryService, RandomSpawnService, chest, Kelor, quest Keris, bunga, puzzle Kantil, knock, revive, gamelan, quest Kafan, ritual akhir, Quest UI, cutscene, efek horor.


## NEXT ACTION

1. User: tinjau/hapus SkyboxInserter; ganti teks dialog placeholder dengan naskah GDD.
2. Phase 2: QuestService (party-wide progression, state machine, konfigurasi quest, sinkronisasi, Quest UI dasar).
   AI mulai dengan audit repo + rencana, tanpa langsung menulis kode.


## IMPORTANT

Dokumen ini adalah kondisi terakhir yang diketahui. Perbarui setelah pekerjaan signifikan.
Jangan menulis bahwa sebuah sistem berfungsi kalau belum dites.