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
KODE & TES STUDIO OK untuk 5.1–5.8 (dilaporkan user, Studio normal, 2026-10-11). Sisa (5.9 giliran tunggal, revive, party wipe, flower reset) dikerjakan di Phase 6 (Task 6.4–6.5).

- [x] 5.1 Flower spawn system (CollectibleService + CollectionConfig, ADR-027) — DITES user di Studio (normal, 2026-10-11)
- [x] 5.2 Server randomization (4 dari 8 titik, 4 jenis berbeda) — DITES user di Studio (normal, 2026-10-11)
- [x] 5.3 Flower collection — DITES user di Studio (normal, 2026-10-11)
- [x] 5.4 Party progress (counter Flowers 4/4) — DITES user di Studio (normal, 2026-10-11)
- [x] 5.5 Alur Pemandu: KERIS selesai -> laporan -> KANTIL (GameFlowService, ADR-028) — DITES user di Studio (normal, 2026-10-11)
- [x] 5.6 Grave clue — TANPA KODE: clue = SurfaceGui di makam (dibuat user di Studio); alur diuji user (2026-10-11)
- [x] 5.7 Flower placement (GravePuzzleService, ADR-029): equip bunga + [E] di makam; DITES user di Studio (normal, 2026-10-11)
- [x] 5.8 Puzzle validation PER BUNGA (server; bunga salah tidak dipakai + hook onWrong; benar tetap di makam) — DITES user di Studio (normal, 2026-10-11). JAWABAN MASIH PLACEHOLDER (ANSWER_CONFIRMED=false)
- [ ] 5.9 Turn/attempt control (satu pemain aktif) — DIPUTUSKAN user 2026-10-10: dikerjakan bersama sistem knock/revive di Phase 6 (bukan sekarang). Catatan desain: bunga terbagi antar pemain, jadi kunci giliran tidak boleh membatasi siapa yang meletakkan bunga; rancang bersama aturan knock pada pemain yang gagal
- [x] Knock system + jumpscare pada bunga salah (ADR-030–034): DITES user di Studio (normal, 2026-10-11); solo = respawn + reset quest, multiplayer = knock
- [x] Revive (Minyak Zaitun) — Task 6.4, kode ditulis, BELUM dites di Studio
- [x] Party wipe (semua knock = wipe; solo = langsung wipe; CANTIL_PUZZLE -> SEARCHING_FLOWERS; makam otomatis dikosongkan, bunga di Backpack belum dihapus)
- [x] Flower reset (hapus sisa bunga dari semua Backpack saat wipe)
- [x] Black Kantil reward (diberikan ke penempat bunga terakhir saat jawaban benar) — DITES user di Studio (normal, 2026-10-11)
- [x] NPC submission = simpan di RitualCollection (sudah ada di RitualConfig sejak ADR-026; belum dites untuk Kantil)

# PHASE 6 — KNOCK / REVIVE

Status:
DONE — ditutup dan dites user di Studio (dilaporkan user 2026-10-11). Dikerjakan bertahap sesuai ADR-031.

- [x] 6.1 Knock state (KnockService, server): berbaring + tidak bisa bergerak/berinteraksi, knock dari bunga salah — DITES user di Studio (normal, 2026-10-11)
- [x] 6.1b Kegagalan solo vs multiplayer (FailureService, ADR-032): solo = respawn + reset quest 2 + mulai lagi dari Pemandu; multiplayer = knock — DITES user di Studio (normal, 2026-10-11)
- [x] 6.2 Jumpscare client-only (ViewportFrame model 3D berrig + efek layar, hanya untuk pemain yang kena) lalu knock/respawn — DITES user di Studio (normal, 2026-10-11). Audio + state RETRY_GUIDE (ADR-034) ikut diuji; suara masih placeholder
- [x] 6.3 Knock UI MINIMAL (keputusan user: tanpa marker): overlay vinyet + teks "Kamu pingsan" di pemain knock (KnockController) — kode ditulis, luau-compile OK; BELUM dites di Studio. Marker di kepala korban TIDAK dikerjakan (bisa ditambah nanti)
- [x] 6.4 Ramuan Minyak Zaitun + revive (ADR-035/036): spawn 2 dari semua Part di `QuestObjects/ZaitunSpawns` (CollectibleService); revive = pegang zaitun, dekat korban, tahan [E] 3 detik, validasi + hitung waktu di server, kurangi 1 saat berhasil — kode ditulis, luau-compile OK; BELUM dites di Studio (lihat SESSION_HANDOFF "Uji Studio Task 6.4")
- [x] 6.4b Revisi zaitun (ADR-037): selalu 2 pickup aktif, pengganti di titik yang belum pernah dipakai — kode ditulis, harness offline lulus; BELUM dites di Studio
- [x] 6.5 Giliran tunggal (Task 5.9) + party wipe (semua knock) + reset bunga Kantil (hapus bunga di Backpack, spawn ulang)
- [x] Uji 1/2/3/4 pemain knock (jadwalkan di Phase 10 untuk 3–4 pemain)

Catatan masa depan (belum dikerjakan, JANGAN dilupakan):
- Serangan hantu: knock via jalur yang sama (jumpscare -> KnockService.knock(player, "GHOST")). Perlu: AI hantu, deteksi serangan, knock saat pemain MINIGAME/dialog (batalkan sesi puzzle/dialog dulu).
- Aset jumpscare (model 3D berrig + animasi) disiapkan user; ID aset dikonfigurasi di Config.
- Teks dialog Pemandu_KantilRetry dan audio jumpscare (`rbxasset://sounds/bass.mp3`) masih PLACEHOLDER: ganti dengan teks final dan aset suara asli.
- Pemain knock yang rekan-rekannya keluar hingga tersisa satu: tangani di 6.5 (onAllKnocked -> jalur solo).

# LOBBY & MATCHMAKING (DIJADWALKAN, belum dikerjakan — catatan arahan user 2026-10-10)

Alur target: pemain masuk ke PLACE LOBBY terpisah (belum dibuat) -> memilih area Solo / 2 Pemain / 3 Pemain / 4 Pemain -> di-teleport ke place game ini (Malam Suro: Dusun Kelabu).

- [ ] Buat place lobby (Roblox place terpisah dalam satu experience) dengan 4 area pilihan (Solo, 2P, 3P, 4P)
- [ ] Area menahan pemain sampai jumlah terpenuhi (atau tombol mulai), lalu TeleportService:ReserveServer + TeleportAsync dengan TeleportData { mode / partySize }
- [ ] Place game membaca TeleportData: PartyService.getSize() memakai ukuran yang dipilih (bukan sekadar jumlah pemain live); batasi masuk sesuai ukuran, tolak pemain asing
- [ ] Fallback saat tes di Studio (tanpa TeleportData): pakai jumlah pemain live (perilaku sekarang)
- [ ] Penanganan pemain keluar di tengah game (party berkurang -> isSolo berubah, lihat ADR-032), pemain kembali ke lobby saat game selesai
- [ ] Pastikan semua sistem yang bergantung ukuran party (FailureService solo/multi, party wipe, gathering ritual akhir 1/1..4/4, Gamelan semua pemain) membaca PartyService
- [ ] Update GameConfig.MAX_PLAYERS dan dokumentasi; uji teleport antar place (hanya bisa di game yang dipublish, tidak di Studio Play Solo)

# PHASE 7 — KAIN KAFAN / GAMELAN

Status:
DITUTUP oleh user (commit 36b9c74 "clsoe phase 7", 2026-10-11); hasil tes Studio per-poin TIDAK dilaporkan ke AI, jadi GUI/audio/jumpscare gamelan tetap berstatus "belum terkonfirmasi" sampai dilaporkan. Riwayat: ADR-038/039. Perubahan GDD disetujui user 2026-10-11: SATU pemain bermain, 4 kolom (Q W E R / ketuk), durasi 97 detik, musik placeholder. Kode ditulis; BELUM dites di Studio.

- [x] Gamelan interaction ([E] Mainkan, KafanQuestService) — kode ditulis, belum dites Studio
- [x] Rhythm UI (GamelanController) — kode ditulis, hanya kompilasi, belum dites Studio
- [x] four columns (Q W E R di PC, ketuk kolom di mobile)
- [x] Note system (chart acak di grid BPM, dibuat server) — beatmap sesuai musik asli = menyusul
- [x] Input handling (tekan saat ditekan; Q/W/E/R ditelan; karakter dibekukan server)
- [x] Score (REVISI ADR-039: mulai 100, Good -1, Miss -3; gagal seketika < 80 -> UI tutup + jumpscare; kode ditulis, logika server lulus harness, belum dites Studio)
- [x] Score validation (server: sinkron jam, once-per-note, rate limit; harness offline 53 cek lulus)
- [x] Retry (gagal skor = jumpscare lalu boleh main lagi; tanpa knock/reset, ADR-039)
- [x] Musik terdengar pemain lain (Attribute di objek Gamelan + GamelanMusicController, ADR-039) — belum dites Studio
- [ ] Ganti model hantu jumpscare gamelan (FailureConfig.JumpscareByReason.GAMELAN_FAIL; sementara Pocong)
- [x] Player completion (SATU pemain; ALL_PLAYER_COMPLETE -> GAMELAN_COMPLETE)
- [x] Reward (KainKafan ke pemain yang lulus; butuh template ServerStorage.QuestTemplates.KainKafan)
- [x] NPC submission = simpan di RitualCollection (sudah ada di RitualConfig; belum dites untuk Kafan)
- [x] ID musik sudah diisi user di GamelanConfig.SOUND_ID; sesuaikan BPM/LEAD_IN agar not menyatu dengan musik; setel GOOD/MISS_PENALTY sesuai rasa
- [x] Tes Studio (lihat SESSION_HANDOFF "Uji Studio Phase 7")

# PHASE 8 — FINAL RITUAL

Status:
IN PROGRESS (ADR-040, 2026-10-11). Kode ditulis; logika server lulus harness offline (65 cek, 1–4 pemain); client (HUD, cutscene) hanya kompilasi; BELUM dites di Studio.

- [x] Ritual requirements: ritual hanya terbuka bila KERIS, KANTIL, KAFAN semua COMPLETE (dicek GameFlowService DAN FinalRitualService) — harness
- [x] Item submission validation: SUDAH ada sejak ADR-026 (RitualCollectionService: consume item -> SUBMITTED -> COMPLETE); tidak diubah. Perlu dites Studio untuk Kantil dan Kafan (belum pernah dites)
- [x] Pemandu sequence (bagian 1): laporan akhir `Pemandu_KafanDone` -> membuka FINAL_RITUAL; `Pemandu_FinalGather` = pengingat saat menunggu — dialog PLACEHOLDER
- [x] Party gathering + readiness tracking: radius 30 studs dari pivot `QuestObjects.RitualCollection`, dihitung SERVER; semua pemain hidup + NORMAL, tahan 3 detik; HUD "n/N" — harness 1/1..4/4
- [x] Pemandu sequence (bagian 2) + Dialogue: 5 langkah subtitle otomatis dari server (`FinalRitualConfig.Sequence`) — teks PLACEHOLDER
- [x] Environment transition: preset Lighting `Ritual` -> `Fajar` (tween di client); horor penuh = Phase 9
- [x] Cutscene: letterbox + subtitle + kartu akhir (FinalRitualController); TANPA gerak kamera (belum dikerjakan)
- [x] Ending + Game complete state: ENDING -> GAME_COMPLETE, pemain dilepas — harness
- [ ] Tes Studio 1–4 pemain (lihat SESSION_HANDOFF "Uji Studio Phase 8")
- [ ] Ganti teks placeholder dengan naskah GDD (Pemandu_KafanDone, Pemandu_FinalGather, FinalRitualConfig.Sequence)
- [ ] Opsional (butuh keputusan user): gerak kamera cutscene, kembali ke lobby setelah GAME_COMPLETE (menunggu sistem lobby), dialog interaktif per-pemain vs subtitle otomatis


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