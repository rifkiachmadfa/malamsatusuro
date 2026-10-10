# PROJECT TASKS

## HOW TO USE THIS FILE

Tasks are ordered by development priority.

Do not automatically implement every task.

Before starting a task:

1. inspect Git
2. inspect current state
3. inspect relevant code
4. inspect Roblox Studio when available
5. confirm dependencies
6. implement
7. test
8. update this file


# PHASE 0 — FOUNDATION AUDIT

Status:
REPOSITORY AUDIT DONE (2026-10-04)

- [x] Audit repository (1 commit, template Rojo)
- [x] Audit Rojo configuration (shared/server/client terpetakan)
- [X] Audit Roblox Studio structure (butuh Explorer dari user)
- [x] Audit existing scripts (hanya template Hello)
- [x] Audit RemoteEvents (belum ada di repo; Studio belum diperiksa)
- [x] Audit current map (butuh Studio)
- [x] Identify missing systems (semua sistem gameplay belum ada)
- [x] Identify broken systems (belum bisa dinilai tanpa Studio)
- [x] Establish baseline


# PHASE 1 — FOUNDATION

Status:
DONE (2026-10-04)

- [x] 1.1 Dokumentasi dasar (AGENTS.md, SESSION_HANDOFF.md, ADR-011/012)
- [x] 1.2 Strategi map: Git hanya script (ADR-011)
- [x] 1.3 Kerangka src/ (GameConfig, Log, bootstrap)
- [x] Finalize Rojo project structure
- [x] 1.4 Remotes foundation
- [x] GameManager
- [x] Basic game state
- [x] 1.6 Player spawn (test 4 pemain belum dilaporkan)
- [x] 1.7 Pemandu NPC + interaksi dasar — DITES user di Studio 2026-10-04 (1 pemain dan 2+ pemain)
- [x] 1.8 GUI foundation (dialog NPC, hitam-putih, mobile-friendly) — DITES user di Device Emulator (berbagai device)
- [x] 1.9 Multiplayer state foundation — dialog per pemain dites 2+ pemain; kode debug Phase 1 dihapus (test 4 pemain penuh dijadwalkan di Phase 10)

# PHASE 2 — QUEST SYSTEM

Status:
DONE (2026-10-05, diuji 1 dan 2 pemain; 3–4 pemain di Phase 10)

- [x] 2.1 QuestConfig + QuestService (state machine, counter party-wide, replikasi Attribute) — kode ditulis, logika lulus harness offline (32 cek); BELUM dites di Studio
- [x] 2.2 Quest UI dasar (QuestView + QuestController, top-right, minimize) — DITES user di Studio 1 pemain 2026-10-05: panel muncul, addProgress via Command Bar mengubah panel, minimize berfungsi. Device Emulator dan 2+ pemain belum dilaporkan
- [x] 2.3 Integrasi alur: dialog Pemandu -> GameManager (INTRO/QUEST_KERIS) + QuestService (GameFlowService, ADR-020) — DITES user di Studio 1 pemain 2026-10-05: urutan LOBBY->INTRO->QUEST_KERIS dan KERIS LOCKED->ACTIVE->SEARCHING_KELOR muncul di Output. Uji 2+ pemain belum
- [x] Uji Studio 2 pemain: progres counter dan panel sama di kedua layar (dilaporkan user 2026-10-05); 3–4 pemain dijadwalkan Phase 10


# PHASE 3 — INTERACTION & INVENTORY

Status:
IN PROGRESS
(ADR-018: tanpa InventoryService; item = Tool di Backpack, ItemService tipis. InteractionService sudah ada sejak Phase 1.)

- [x] InteractionService (selesai di Phase 1)
- [x] 3.1 ItemService (wrapper Backpack, ADR-018/022) + ItemConfig + pemeriksaan dependency QuestTemplates saat boot — pemeriksaan boot DITES user 2026-10-05 ("10 template item lengkap"); give/consume lulus harness offline (28 cek), diuji di Studio lewat pickup Kelor (Phase 4)
- [x] Server validation
- [x] Anti-duplication
- [x] Item collection


# PHASE 4 — KERIS PUSAKA

Status:
DONE dengan catatan (2026-10-05, ditutup atas instruksi user; commit 0d8dfa2). Status ini sempat termundur di commit 6acfb27 dan dipulihkan 2026-10-10. Uji 3–4 pemain di Phase 10.

- [x] 4.1 Kelor spawn system + server randomization + 4 active / 4 inactive (RandomSpawnService, KerisQuestService, ADR-023) — logika lulus harness offline (18 cek); BELUM dites di Studio
- [x] 4.2 Kelor collection + party progress (pickup [E], ItemService.give, QuestService.addProgress) — idem
- [x] Uji Studio 4.1–4.2 (1 dan 2 pemain)
- [x] 4.3 Key acquisition: Pemandu_KerisKey -> KunciPeti ke 1 pemain acak, Kelor semua pemain dihapus (KerisQuestService) — syntax OK (luau-compile); BELUM dites di Studio. Butuh template ServerStorage.QuestTemplates.KunciPeti (Tool)
- [x] Chest
- [x] Memory puzzle
- [x] Keris reward
- [x] NPC submission
- [x] Quest completion


# PHASE 5 — KEMBANG KANTIL HITAM

Status:
IN PROGRESS (2026-10-10). Kode 5.1–5.8 ada; SEMUANYA belum dites di Studio. Knock/revive/party wipe/flower reset menunggu Phase 6.

- [x] 5.1 Flower spawn system (CollectibleService + CollectionConfig, ADR-027) — harness offline; BELUM dites di Studio
- [x] 5.2 Server randomization (4 dari 8 titik, 4 jenis berbeda) — idem
- [x] 5.3 Flower collection — idem
- [x] 5.4 Party progress (counter Flowers 4/4) — idem
- [x] 5.5 Alur Pemandu: KERIS selesai -> laporan -> KANTIL (GameFlowService, ADR-028) — idem
- [x] 5.6 Grave clue — TANPA KODE: clue = SurfaceGui di makam (dibuat user di Studio). Dependency Studio, belum diverifikasi AI
- [x] 5.7 Flower placement (GravePuzzleService, ADR-029): equip bunga + [E] di makam; harness offline 47 cek; BELUM dites di Studio
- [x] 5.8 Puzzle validation (server, jawaban di server/Config/GravePuzzleConfig) — idem. JAWABAN MASIH PLACEHOLDER (ANSWER_CONFIRMED=false)
- [ ] 5.9 Turn/attempt control (satu pemain aktif) — DIPUTUSKAN user 2026-10-10: dikerjakan bersama sistem knock/revive di Phase 6 (bukan sekarang). Catatan desain: bunga terbagi antar pemain, jadi kunci giliran tidak boleh membatasi siapa yang meletakkan bunga; rancang bersama aturan knock pada pemain yang gagal
- [ ] Knock system (hook GravePuzzleService.onWrong sudah ada)
- [ ] Revive (Minyak Zaitun)
- [ ] Party wipe (CANTIL_PUZZLE -> SEARCHING_FLOWERS; makam otomatis dikosongkan, bunga di Backpack belum dihapus)
- [ ] Flower reset (hapus sisa bunga dari semua Backpack saat wipe)
- [x] Black Kantil reward (diberikan ke penempat bunga terakhir saat jawaban benar) — harness offline
- [x] NPC submission = simpan di RitualCollection (sudah ada di RitualConfig sejak ADR-026; belum dites untuk Kantil)

# PHASE 6 — KNOCK / REVIVE

Status:
NOT STARTED

- [ ] Knock state
- [ ] Knock UI
- [ ] Revive interaction
- [ ] Revive validation
- [ ] Party wipe detection
- [ ] Kantil-specific reset


# PHASE 7 — KAIN KAFAN / GAMELAN

Status:
NOT STARTED

- [ ] Gamelan interaction
- [ ] Rhythm UI
- [ ] Six columns
- [ ] Note system
- [ ] Input handling
- [ ] Score
- [ ] Score validation
- [ ] Retry
- [ ] Player completion
- [ ] All-player completion
- [ ] Reward
- [ ] NPC submission


# PHASE 8 — FINAL RITUAL

Status:
NOT STARTED

- [ ] Ritual requirements
- [ ] Item submission validation
- [ ] Party gathering
- [ ] Readiness tracking
- [ ] Pemandu sequence
- [ ] Dialogue
- [ ] Environment transition
- [ ] Cutscene
- [ ] Ending
- [ ] Game complete state


# PHASE 9 — HORROR POLISH

Status:
NOT STARTED

- [ ] Fog
- [ ] Lighting
- [ ] Environmental horror
- [ ] Audio
- [ ] Footsteps
- [ ] Whispers
- [ ] Horror events
- [ ] Limited jumpscares
- [ ] Environmental transitions


# PHASE 10 — MULTIPLAYER TESTING

Status:
NOT STARTED

- [ ] 1-player test
- [ ] 2-player test
- [ ] 3-player test
- [ ] 4-player test
- [ ] simultaneous interaction
- [ ] disconnect test
- [ ] reconnect test
- [ ] item duplication test
- [ ] invalid RemoteEvent test
- [ ] party progression test
- [ ] knock/revive test
- [ ] party wipe test
- [ ] final ritual test


# PHASE 11 — OPTIMIZATION

Status:
NOT STARTED

- [ ] Server performance
- [ ] Client performance
- [ ] RemoteEvent usage
- [ ] Memory
- [ ] Connections
- [ ] Loops
- [ ] Part count
- [ ] Particles
- [ ] Audio instances
- [ ] UI update frequency


# PHASE 12 — FINAL BUILD

Status:
NOT STARTED

- [ ] Full playthrough
- [ ] Multiplayer playthrough
- [ ] Security sanity check
- [ ] Performance check
- [ ] Cleanup
- [ ] Documentation
- [ ] Git review
- [ ] Release candidate