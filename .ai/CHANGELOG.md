# CHANGELOG

## 2026-10-11 — Phase 7 revisi: skor 100 dipertahankan, gagal < 80 = jumpscare, musik terdengar pemain lain (ADR-039) (belum dites di Studio)
- Arahan user: skor mulai 100 dan turun (Good -1, Miss -3; angka = asumsi AI, di GamelanConfig); skor < 80 kapan pun = UI langsung tutup + jumpscare (Pocong dulu, sama seperti makam); musik terdengar pemain lain, UI hanya untuk pemain yang bermain, pemain lain bebas bergerak
- GamelanConfig: `START_SCORE`, `PERFECT/GOOD/MISS_PENALTY`, `MISS_GRACE`, `WORLD_SOUND_VOLUME`, `WORLD_ROLLOFF_MIN/MAX`, `MUSIC_PLAYER_ATTR`, `MUSIC_START_ATTR`; `PERFECT_POINTS`/`GOOD_POINTS` dihapus
- RhythmGameService: skor turun, Miss real-time di server (Heartbeat + sapu akhir), `failSession`, `start(player, onFinish, hooks?)` dengan `onFail/onPlaying/onClosed`; remote `GamelanUpdate` menambah action `Score`
- FailureService: fungsi baru `scare(player, reason)` (jumpscare tanpa knock/reset); FailureConfig: `JumpscareByReason.GAMELAN_FAIL`
- KafanQuestService: hook gagal (jumpscare + notifikasi), musik dunia lewat Attribute pada objek Gamelan
- Client: GamelanController skor dari server (mulai 100, tanpa hitung lokal); baru `GamelanMusicController` (suara spasial di gamelan untuk pemain lain, tersinkron waktu server, mendukung pemain yang baru masuk); didaftarkan di init.client
- Verifikasi AI: luau-compile semua file berubah OK; harness offline BARU yang memuat file src/ asli (stub Roblox, jam palsu, 52 cek) LULUS: skor awal 100, lulus sempurna, gagal seketika saat Miss ke-7 (bukan akhir lagu), gagal di Good ke-21, 6 Miss tetap lulus (82), Cancel/keluar/knock tanpa jumpscare, musik dunia nyala saat Ready dan mati di semua akhir sesi, B tidak melihat Start dan tidak dibekukan, input tak sah tidak mengubah skor. TIDAK dites di Studio: GUI, jumpscare nyata, musik spasial, sinkron audio, multiplayer sungguhan
- Catatan: `phase7_harness.luau` dan `phase7-gamelan-ADR-038.patch` di root repo adalah snapshot lama (salinan gabungan, bukan memuat src/) dan TIDAK mencerminkan perubahan ini

## 2026-10-11 — Phase 7 awal: gamelan ritme 4 kolom, satu pemain (ADR-038) (belum dites di Studio)
- Perubahan dari GDD (arahan user): SATU pemain memainkan gamelan, 4 kolom (Q W E R di PC, ketuk di mobile), durasi 97 detik, musik placeholder (`GamelanConfig.SOUND_ID` kosong)
- Baru: shared/Config/GamelanConfig, server/Services/RhythmGameService (chart, sesi, validasi, skor), server/Services/KafanQuestService (objek Gamelan, state, hadiah Kain Kafan), client/Controllers/GamelanController (GUI ritme), remote `GamelanUpdate` dan `GamelanAction`
- QuestConfig: state `ALL_PLAYER_COMPLETE` diganti `GAMELAN_COMPLETE`; GameFlowService: KAFAN di QUEST_FLOW dan laporan Kantil (`Pemandu_KantilDone`) memulai Kafan; DialogueConfig: dialog placeholder Kantil Done / Kafan Search / Store / Wait
- init.server/init.client: service dan controller baru; InteractionController dan ReviveController diblokir saat gamelan terbuka
- Verifikasi AI: luau-compile semua file OK; harness offline server (stub Roblox, jam palsu) 53 cek LULUS: chart, sesi tunggal, skor sempurna/good/campuran/nol, anti-curang (waktu palsu, duplikat, spam, payload aneh), cancel/knock/keluar/karakter hilang/timeout Ready, alur quest + hadiah + pemegang keluar. GUI client TIDAK dites (hanya kompilasi). Tidak ada tes Studio

## 2026-10-11 — Revisi Minyak Zaitun: selalu 2 pickup aktif, pengganti di titik berbeda (ADR-037) (belum dites di Studio)
- CollectionConfig: opsi baru `replenish`; entri `Zaitun` memakainya. Komentar entri diperbarui (menggantikan "tidak respawn setelah diambil" di ADR-036)
- CollectibleService: `placePickup` (diekstrak dari spawnAll), `usedSpawns`, `refill` setelah pickup diambil; Pickup menyimpan referensi titik spawn
- RandomSpawnService.pickSpawns: parameter opsional `exclude`
- Verifikasi AI: luau-compile 3 file OK; harness offline (stub Roblox, 7 skenario/20 cek, dijalankan 3x karena acak) LULUS: spawn awal 2, pengganti segera, titik baru tiap kali, tanpa duplikasi item, pool habis -> siklus baru, Kelor tidak terpengaruh. TIDAK ada tes Studio

## 2026-10-11 — Phase 6 Task 6.4: Minyak Zaitun spawner + revive tahan 3 detik (ADR-035, ADR-036) (belum dites di Studio)
- CollectionConfig/CollectibleService diperluas (generik, bukan salinan): `activeStates` (banyak state), `counterId` opsional, `spawnCount`, `clearOnLeave`. Kelor/Flowers hanya ganti ke `activeStates = { ... }`. Entri baru `Zaitun`: folder `QuestObjects/ZaitunSpawns`, 2 titik aktif dari semua Part, spawn di AWAL GAME (KERIS masuk SEARCHING_KELOR, setelah dialog intro), `clearOnLeave = false` (tidak dihapus saat quest berganti), tanpa progres quest
- Baru: shared/Config/ReviveConfig, server/Services/ReviveService (sesi revive server-authoritative), client/Controllers/ReviveController (prompt tahan + progress bar), remote `ReviveRequest` dan `ReviveUpdate`
- GameManager: transisi pemain NORMAL -> REVIVING (REVIVING = state penyelamat selama sesi)
- init.server: ReviveService.init() setelah KnockService. init.client: ReviveController.init; prompt interaksi lain disembunyikan saat prompt revive memegang tombol E
- Verifikasi AI: luau-compile semua file berubah/baru OK. TIDAK ada tes Studio dan tidak ada harness logika

## 2026-10-11 — Phase 6 Task 6.3: Knock UI minimal + pencatatan hasil tes
- Baru: client/Controllers/KnockController: overlay vinyet + "KAMU PINGSAN" + petunjuk Minyak Zaitun saat Attribute PlayerState = KNOCKED; fade in/out; hotbar Roblox disembunyikan selama knock. DisplayOrder 20 (di bawah notifikasi dan jumpscare). Tanpa marker di kepala korban (keputusan user: minimal)
- Hasil tes (dilaporkan user, Studio normal): Phase 5 (5.1–5.8) dan Phase 6 sampai 6.2 BERHASIL. ADR-027/028/029/032/033/034 ACCEPTED, ADR-031 ACCEPTED untuk 6.1–6.2, ADR-030 sebagian dibangun
- Verifikasi AI untuk 6.3: luau-compile OK. Belum dites di Studio

## 2026-10-11 — Audio jumpscare (placeholder) + state RETRY_GUIDE (ADR-034) (belum dites di Studio)
- JumpscareConfig: soundId placeholder `rbxasset://sounds/bass.mp3` (suara bawaan Roblox, belum diverifikasi AI di Studio); ganti dengan aset asli. Diputar client hanya pada pemain yang kena
- QuestConfig: field opsional `retryState`/`retryObjective`; KANTIL punya state `RETRY_GUIDE` (di luar rantai linear, transisi RETRY_GUIDE -> ACTIVE)
- QuestService.reset memakai retryState (bukan LOCKED) dan activate menerima quest di retryState; GravePuzzleService mengosongkan makam saat RETRY_GUIDE
- Quest UI (QuestView): saat retryState hanya tampil "○ Kembali berbicara kepada Pemandu"
- GameFlowService: dialog Pemandu_KantilRetry (placeholder, DialogueConfig); menamatkannya memulai ulang quest (aman dipanggil ganda). Notifikasi solo gagal disesuaikan
- Verifikasi AI: luau-compile file berubah OK. Tidak ada tes Studio

## 2026-10-11 — Phase 6 Task 6.2: jumpscare client-only (ADR-033) (belum dites di Studio)
- Baru: shared/Config/JumpscareConfig, server/Services/JumpscareService, client/Controllers/JumpscareController, remote `Jumpscare`
- Model dibaca dari ServerStorage/GhostModels/Pocong, disalin server ke ReplicatedStorage/GhostModels (script dibuang); animasi 121504540587696
- Tampilan: ViewportFrame layar penuh HANYA di pemain yang kena: model berrig + animasi, kamera melonjak dekat, goyang layar, kilat putih awal, gelap akhir
- FailureService: urutan gagal = CUTSCENE -> jumpscare (server menunggu durasi, root di-anchor) -> hukuman (solo: respawn + reset quest, multiplayer: knock). Penyebab gagal ganda diabaikan lewat gate state NORMAL
- FailureConfig: SOLO_RESPAWN_DELAY dihapus; ditambah JumpscareByReason/DEFAULT_JUMPSCARE
- Verifikasi AI: luau-compile semua file berubah OK. Tidak ada tes Studio

## 2026-10-10 — Kegagalan solo vs multiplayer (ADR-032) (belum dites di Studio)
- Baru: FailureService + FailureConfig (satu pintu `fail(player, reason, questId)`), PartyService (getSize/isSolo dari jumlah pemain)
- Solo: bunga salah -> pemain dikunci (CUTSCENE) -> jeda -> item quest dibersihkan -> QuestService.reset("KANTIL") -> respawn -> NORMAL; Pemandu memulai ulang quest. Multiplayer: knock
- QuestService.reset(questId) baru (kembali ke LOCKED, counter 0, ditolak untuk COMPLETE/state awal). GravePuzzleService mengosongkan makam saat LOCKED
- Saklar bunga salah pindah dari KnockConfig ke FailureConfig.FAIL_ON_WRONG_FLOWER
- Catatan masa depan ditulis: lobby place + pilih Solo/2/3/4 + teleport (TASKS)
- Verifikasi AI: luau-compile semua file berubah OK. Tidak ada tes Studio

## 2026-10-10 — Bootstrap: Remotes.init() dipindah ke paling awal (belum dites di Studio)
- init.server: Remotes.init() sebelum require service, agar kegagalan satu service tidak membuat client macet ("Folder Remotes tidak ditemukan"). Tidak memperbaiki penyebab error server; itu menunggu Output server dari user

## 2026-10-10 — Phase 6 Task 6.1: KnockService (state knock di server) (belum dites di Studio)
- Baru: server/Services/KnockService, server/Config/KnockConfig, ADR-031. API: knock(player, reason), recover(player), isKnocked, getKnockedCount, onKnocked/onRecovered/onAllKnocked
- Knock: state pemain NORMAL -> KNOCKED, HumanoidRootPart di-Anchor dan berbaring telentang di lantai (raycast), WalkSpeed/Jump 0, tool dilepas dan tidak bisa di-equip, respawn/reset saat knock dikembalikan ke titik knock, notifikasi lewat NoticeService
- init.server: bunga salah (GravePuzzleService.onWrong) -> KnockService.knock, dengan saklar KnockConfig.KNOCK_ON_WRONG_FLOWER. Belum ada jumpscare, UI knock, revive, party wipe
- Verifikasi AI: luau-compile 3 file berubah OK. Tidak ada tes Studio dan tidak ada harness logika

## 2026-10-10 — Task 5.8 direvisi: validasi PER BUNGA (pola desain user), ADR-030 (belum dites di Studio)
- GravePuzzleService: bunga dinilai saat diletakkan. Benar = dipakai dan tetap di makam; salah = tidak dipakai (tetap di Backpack), makam tidak berubah, hook onWrong(player, graveName, itemId). Percobaan pertama memajukan state sampai CANTIL_PUZZLE. Validasi di akhir dan pengembalian massal dihapus
- ADR-029 diperbarui; ADR-030 (bunga salah = jumpscare + knock; semua knock = wipe; solo = langsung wipe) PROPOSED untuk Phase 6
- Verifikasi AI: luau-compile; harness offline 55 cek lulus. Tidak ada tes Studio. Sampai Phase 6 bunga salah belum berhukuman

## 2026-10-10 — Phase 5: placement bunga dan validasi puzzle makam (belum dites di Studio)
- Baru: GravePuzzleService, server/Config/GravePuzzleConfig (jawaban sisi server), ADR-029; registrasi di init.server
- Dialog baru (placeholder): Pemandu_KantilPuzzle, Pemandu_KantilStore; GameFlowService memetakan FLOWERS_PLACEMENT, CANTIL_PUZZLE, CANTIL_BLACK_OBTAINED
- Docs: status Phase 4 di TASKS.md dipulihkan ke DONE dengan catatan; Phase 5 diselaraskan dengan kode aktual
- Verifikasi AI: luau-compile semua file berubah; harness offline 47 cek lulus (jalur benar 2 pemain, makam ganda ditolak, salah+kembali+coba lagi, hook onWrong, template hadiah hilang, pemain/pemegang keluar, reset makam, Graves hilang). Tidak ada tes Studio
- Temuan: grave clue/placement belum ada sebelum task ini (tercatat "dibuat" oleh user); alur Kantil buntu di FLOWERS_COMPLETE

## 2026-10-05 — Phase 5 mulai: CollectibleService generik + pencarian bunga Kantil (belum dites di Studio)
- Baru: CollectibleService, CollectionConfig (Kelor dan Flowers), ADR-027/028
- Refactor: logika Kelor dipindah dari KerisQuestService ke CollectibleService (perilaku sama); GameFlowService generik (QUEST_FLOW, QUEST_DIALOGUES, REPORT_DIALOGUES): Pemandu melapor KERIS selesai lalu memberi quest KANTIL
- Dialog baru (placeholder): Pemandu_KantilSearch, Pemandu_KantilGrave; Pemandu_KerisDone kini memberi quest berikutnya
- Verifikasi AI: luau-compile semua file; harness offline 70 cek lulus (Kelor via modul generik, 4 bunga jenis berbeda, progres party 3 pemain, pickup ganda/palsu ditolak, spawn ulang saat party wipe). Tidak ada tes Studio

## 2026-10-05 — Penutupan Phase 4 (Keris Pusaka)
- Phase 4 DONE dengan catatan (ditutup atas instruksi user). ADR-023/024/026 -> ACCEPTED, BUG-001 -> VERIFIED
- Utang: uji 3–4 pemain (Phase 10), respawn menghilangkan kunci (Phase 5/6), pemicu aktivasi KANTIL, teks placeholder, PemanduService kode mati
- Berikutnya: Phase 5 (Kantil)

## 2026-10-05 — Aturan notifikasi (ADR-025) + penyimpanan di RitualCollection (ADR-026) (belum dites di Studio)
- Baru: RitualCollectionService, RitualConfig. NoticeService.notifyParty; NoticeController menumpuk hingga 4 toast
- Diubah: KerisQuestService (penyerahan ke Pemandu dihapus; notifikasi Kelor n/N, kunci, keris, pemegang pindah), DialogueConfig (Store/Wait/Done), GameFlowService, QuestConfig (teks "Simpan ... di tempat ritual"), init.server, AGENTS.md (aturan notifikasi dan penyelesaian quest)
- Alur Keris: ... KERIS_OBTAINED -> simpan di RitualCollection -> KERIS_SUBMITTED -> COMPLETE; Pemandu hanya melapor
- Verifikasi AI: luau-compile semua file; harness offline 45 cek lulus. Notifikasi Kelor (pickup) dan GUI toast belum teruji (tidak ada Studio)

## 2026-10-05 — Task 4.4–4.6: peti, memory puzzle, keris, penyerahan (belum dites di Studio)
- Baru: MemoryPuzzleService (sesi, timeout, validasi), NoticeService + NoticeController (toast), MemoryPuzzleController (GUI tap), MemoryPuzzleConfig, remote MemoryPuzzleUpdate/MemoryPuzzleAction/Notice
- Diubah: KerisQuestService (peti, onPuzzleCorrect, handOverKeris, pemegang item pindah saat keluar), GameFlowService (dialog Pemandu per pemain: Submit/Wait/Done), DialogueConfig (placeholder), init.server/init.client (wiring, blokir interaksi saat puzzle)
- Alur: KELOR_COMPLETE -> KEY_OBTAINED -> CHEST_AVAILABLE -> CHEST_PUZZLE -> KERIS_OBTAINED -> KERIS_SUBMITTED -> COMPLETE
- Verifikasi AI: luau-compile semua file; harness offline 36 cek lulus (satu pemegang kunci, non-pemegang ditolak, sesi tunggal, submit terlalu cepat/payload sampah ditolak, salah=boleh ulang, benar=keris tanpa duplikat, penyerahan ganda tidak berefek, timeout/cancel/keluar). Tidak ada tes Studio / GUI

## 2026-10-05 — Quest UI: satu quest aktif + ukuran lebih kecil (belum dites di Studio)
- QuestView: hanya quest berjalan yang tampil (getCurrentQuestId); quest LOCKED/berikutnya disembunyikan; quest selesai hilang saat quest berikutnya aktif
- QuestController: lebar 210 px, teks 13/14, header 32 px, UIScale mengikuti tinggi layar (0.85–1.0)
- Verifikasi AI: luau-compile OK; tes offline QuestView 6/6 skenario. Tidak ada tes Studio

## 2026-10-05 — Task 4.3: serah-terima kunci (belum dites di Studio)
- Diubah: GameFlowService (peta dialog Pemandu per state KERIS), KerisQuestService (handOverKey, pindah kunci saat pemegang keluar), DialogueConfig (Pemandu_KerisKey, Pemandu_KerisChest, placeholder), QuestConfig (teks objective "Dapatkan Kunci dari Pemandu")
- Memperbaiki BUG-001. Verifikasi AI: luau-compile 4 file OK; tidak ada tes Studio

## 2026-10-04 — Penutupan Phase 2
- Phase 2 ditandai DONE dengan catatan: T1-T6 lulus (1 pemain, Studio); T7-T9 belum dites
- Dokumen diperbarui: CURRENT_STATE, SESSION_HANDOFF, TASKS, DECISIONS (status ADR-018..021)
- Tidak ada perubahan kode

## 2026-10-04 — Phase 2: Quest System (belum dites di Studio)
- Baru: QuestConfig, QuestService, PemanduService, QuestController
- Diubah: DialogueService (callback onFinished), DialogueConfig (dialog quest placeholder),
  init.server dan init.client (service/controller baru)
- Registrasi InteractionId "Pemandu" dipindah ke PemanduService
- Dokumen: ADR-018..021, CURRENT_STATE, SESSION_HANDOFF, TASKS
- Verifikasi AI: luau-compile 8 file OK; tes mock 30/30