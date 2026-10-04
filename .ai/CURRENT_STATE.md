# CURRENT PROJECT STATE

Last Updated:
2026-10-05

## CURRENT PHASE

PHASE 1 — FOUNDATION: SELESAI.
PHASE 2 — QUEST SYSTEM: SELESAI (diuji 1 dan 2 pemain).
PHASE 3 — INTERACTION & INVENTORY: ItemService selesai (boot diuji; give/consume diuji lewat Phase 4).
PHASE 4 — KERIS PUSAKA: SEDANG BERJALAN (4.1 spawn Kelor + 4.2 pickup/progres: kode selesai, belum dites di Studio).


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
- server/Services/QuestService + shared/Config/QuestConfig (Task 2.1, ADR-019): state machine 3 quest, counter party-wide, replikasi Attribute ke ReplicatedStorage.QuestState. STATUS: logika lulus harness offline (stub Roblox, 32 cek); BELUM dites di Studio. 
- server/Services/GameFlowService (Task 2.3, ADR-020) + DialogueService.onCompleted: dialog Pemandu_Intro selesai -> game LOBBY->INTRO->QUEST_KERIS, quest KERIS ACTIVE->SEARCHING_KELOR. STATUS: DITES user di Studio (1 pemain, 2026-10-05): transisi game dan quest benar di Output. Setelah intro, Pemandu memutar Pemandu_KerisSearch (placeholder) selama SEARCHING_KELOR; state lain belum punya dialog.
- client/Controllers/QuestController + shared/Util/QuestView (Task 2.2, ADR-021): Quest UI kanan atas dari Attribute QuestState. STATUS: DITES user di Studio (1 pemain, 2026-10-05): panel muncul setelah intro, addProgress via Command Bar mengubah panel, minimize berfungsi. Belum dilaporkan: Device Emulator, 2+ pemain.
- server/Services/ItemService + shared/Config/ItemConfig (Task 3.1, ADR-022): give/has/count/consume Tool di Backpack, stack lewat Attribute Count, item unique. STATUS: logika lulus harness offline (28 cek); BELUM dites di Studio. Dipakai KerisQuestService untuk pickup Kelor.
- server/Services/RandomSpawnService + KerisQuestService (Task 4.1–4.2, ADR-023): saat KERIS masuk SEARCHING_KELOR, server memilih 4 dari 8 titik di Workspace.QuestObjects.KelorSpawns, membuat pickup Model dari template DaunKelor di Workspace.QuestRuntime; [E] Ambil -> item ke Backpack + progres party. STATUS: logika lulus harness offline (18 cek); pembuatan Model visual dan pickup di Studio BELUM dites.
- Pemandu NPC: dialog berjalan; teks dialog masih PLACEHOLDER (ganti dengan naskah GDD)

Hasil test (dilaporkan user, 2026-10-04):
- Interaksi dan dialog Pemandu: lulus (1 pemain, 2+ pemain)
- Tampilan dialog: lulus di berbagai device di Device Emulator
- Output server/client: tanpa error dari kode project
- Belum dites: 4 pemain penuh; disconnect/reconnect saat dialog (dijadwalkan Phase 10)


## OBJEK WORKSPACE (di Studio, tidak ada di Git)

Dari screenshot user (2026-10-05), belum diverifikasi lewat Explorer lengkap:
- Workspace.QuestObjects: KelorSpawns (KelorSpawn_1..8), FlowerSpawns (FlowerSpawn_1..8), Graves (Grave_1..4), Chest, Gamelan, RitualCollection
- QuestTemplates (Tool): DaunKelor, KantilKuning, MawarMerah, MawarPutih, Melati
- DEPENDENCY BELUM ADA: template KunciPeti, KerisPusaka, KembangKantilHitam, MinyakZaitun, KainKafan

- Workspace.SpawnPoints: Spawn1 (SpawnLocation)
- Workspace.NPC.Pemandu: Model R15 (Block Rig), HumanoidRootPart Anchored, tag Interactable,
  attribute InteractionId=Pemandu, ActionText=Bicara, ObjectText=Pemandu, MaxDistance=10
- Map desa belum ada


## CATATAN KEAMANAN

Output Studio menunjukkan `Requiring asset 257460689 (cloud_257463543.SkyboxInserter)`: script dari model langit Toolbox
memuat modul dari asset ID luar. Bukan kode project. Perlu ditinjau/dihapus user sebelum publish.


## BELUM ADA

ItemService (ADR-018, tanpa InventoryService), chest, Kelor, quest Keris, bunga, puzzle Kantil, knock, revive, gamelan, quest Kafan, ritual akhir, cutscene, efek horor.


## NEXT ACTION

1. User: uji Kelor di Studio (lihat SESSION_HANDOFF), lapor Output dan tampilan (posisi/orientasi model Kelor).
2. Task 4.3: kunci peti setelah 4/4 (KELOR_COMPLETE -> KEY_OBTAINED), lalu peti dan memory puzzle.
3. User (masih terbuka): tinjau SkyboxInserter; ganti teks placeholder dengan naskah GDD.

## IMPORTANT

Dokumen ini adalah kondisi terakhir yang diketahui. Perbarui setelah pekerjaan signifikan.
Jangan menulis bahwa sebuah sistem berfungsi kalau belum dites.