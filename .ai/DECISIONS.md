# ARCHITECTURAL DECISIONS

This document records important project decisions.

AI MUST read this before proposing architectural changes.


## ADR-001 — ROJO

Decision:

The project uses Rojo for synchronization between source-controlled files and Roblox Studio.

Reason:

Luau source must be maintainable through VS Code and Git.

Status:
ACCEPTED


## ADR-002 — GIT AS TECHNICAL MEMORY

Decision:

Git/GitHub is the persistent technical history of the project.

Reason:

AI sessions may change.

The repository must remain the reliable implementation history.

Status:
ACCEPTED


## ADR-003 — SERVER AUTHORITATIVE GAMEPLAY

Decision:

Important gameplay state is controlled by the server.

Reason:

The game is multiplayer and important progression must not depend on client trust.

Status:
ACCEPTED


## ADR-004 — PARTY-WIDE QUEST PROGRESSION

Decision:

Quest progression is shared across the party.

Individual inventory remains player-specific.

Status:
ACCEPTED


## ADR-005 — MODULAR DEVELOPMENT

Decision:

The project is developed in phases.

A system must be tested before becoming a dependency for the next major system.

Status:
ACCEPTED


## ADR-006 — RANDOM SPAWN SERVER SIDE

Decision:

Quest randomization is controlled by the server.

Applies to:
- Kelor
- Flowers
- other gameplay-critical randomization

Reason:

Players must receive the same authoritative world state.

Status:
ACCEPTED


## ADR-007 — CLIENT REQUEST / SERVER VALIDATE

Decision:

Clients may request actions.

Server validates and executes important actions.

Status:
ACCEPTED


## ADR-008 — NO UNNECESSARY FRAMEWORK

Decision:

Do not introduce large frameworks unless they solve an actual project problem.

Prefer Roblox-native services and simple modular Luau architecture.

Status:
ACCEPTED


## ADR-009 — QUEST STATE MACHINE

Decision:

Major quest progression should use explicit states.

Reason:

Prevent invalid progression and make debugging easier.

Status:
ACCEPTED


## ADR-010 — DO NOT REWRITE UNRELATED SYSTEMS

Decision:

Feature work should remain scoped.

Unrelated refactoring requires explicit justification.

Status:
ACCEPTED


## ADR-011 — GIT HANYA UNTUK SCRIPT

Decision:

Git menyimpan script (Rojo `src/`) dan dokumentasi. Map, model, dan objek Studio tetap di place file lokal dan tidak masuk Git.

Consequences:

- Objek map tidak bisa diaudit dari repo; harus lewat Studio (tempel Explorer/Output atau MCP).
- Backup place file lokal dilakukan manual sebelum perubahan besar.
- Objek yang dibutuhkan tapi belum ada dicatat sebagai dependency, bukan dibuat sebagai pengganti.

Status:
ACCEPTED


## ADR-012 — AI TANPA MCP STUDIO (SEMENTARA)

Decision:

Saat ini AI bekerja tanpa Roblox Studio MCP. Verifikasi runtime dilakukan user dan dilaporkan ke AI.

Reason:

Pilihan user. MCP dapat dipertimbangkan lagi nanti (Studio built-in MCP + Claude Code).

Status:
ACCEPTED (dapat ditinjau ulang)



## ADR-013 — REMOTES LEWAT SATU MODUL

Decision:

Semua RemoteEvent dibuat oleh server lewat `Remotes.init()` (src/shared/Remotes.luau) dan diambil lewat `Remotes.get()`. Nama remote hanya didefinisikan di `Remotes.Names`.

Reason:

Mencegah nama remote tersebar sebagai string, dan menjaga boundary client-server tetap jelas dan tervalidasi (ADR-007).

Status:
ACCEPTED



## ADR-014 — GAME MANAGER DAN REPLIKASI STATE LEWAT ATTRIBUTE

Decision:

GameManager (src/server/Services/GameManager.luau) adalah satu-satunya pemilik state game dan state pemain. Transisi hanya lewat tabel yang eksplisit (ADR-009). State direplikasi ke client lewat Attribute (`ReplicatedStorage.GameState`, `Player.PlayerState`), bukan RemoteEvent.

Reason:

Attribute otomatis sampai ke pemain yang join belakangan dan tidak bisa diubah client untuk server. Aturan transisi pemain masih dasar dan akan ditinjau di Phase 6.

Status:
ACCEPTED



## ADR-015 — SPAWN LEWAT SPAWNLOCATION, SERVICE HANYA MEMERIKSA

Decision:

Titik spawn berupa satu SpawnLocation (`Spawn1`) di Workspace.SpawnPoints (dibuat di Studio, tidak masuk Git); semua pemain spawn di area yang sama. SpawnService (server) hanya memeriksa dependency dan mencatat posisi spawn; tidak memindahkan pemain.

Reason:

Mekanisme spawn bawaan Roblox sudah mendukung banyak pemain. Penugasan titik spawn per pemain (deterministik) baru dibuat bila terbukti perlu.

Status:
ACCEPTED



## ADR-016 — INTERAKSI LEWAT TAG + ATTRIBUTE, SATU HANDLER PER ID

Decision:

Objek interaktif ditandai CollectionService tag `Interactable` dengan Attribute `InteractionId`, `ActionText`, `ObjectText`, `MaxDistance` (opsional). Client hanya mengirim `InteractionRequest(target)`. InteractionService memvalidasi (tipe, tag, cooldown, state pemain NORMAL, jarak) lalu memanggil handler yang didaftarkan per `InteractionId`. Nama atribut dan konstanta ada di `GameConfig.Interaction`.

Reason:

Satu jalur interaksi yang konsisten untuk semua sistem (Kelor, bunga, peti, gamelan, revive) tanpa abstraksi berlebihan. Validasi keamanan ada di satu tempat (ADR-007).

Status:
ACCEPTED (diuji user di Studio, 2026-10-04)


## ADR-017 — GUI DIBANGUN LEWAT KODE, TEMA HITAM-PUTIH, LAYOUT RESPONSIF

Decision:

GUI dibuat dari kode client (bukan objek StarterGui) agar masuk Git (ADR-011). Gaya terpusat di `client/UI/Theme`: hitam-putih, panel hitam semi transparan (transparansi 0.35), tanpa border. Responsif lewat Scale + TextScaled + UITextSizeConstraint + UISizeConstraint, dan `ScreenInsets = DeviceSafeInsets`. Target sentuh minimal 40–50 px. Dialog: server memegang indeks baris, client hanya menampilkan dan meminta Next/Close.

Reason:

Mobile-friendly tanpa asset Studio, mudah di-review di Git, dan tidak ada state dialog yang bisa dipalsukan client.

Status:
ACCEPTED (diuji user di Device Emulator, 2026-10-04)



## ADR-018 — INVENTORY = BACKPACK, ITEM = TOOL

Decision:

Tidak ada inventory kustom. Item quest adalah Tool di `Player.Backpack`, di-clone server dari `ServerStorage.QuestTemplates` (template dibuat user di Studio, tidak masuk Git, ADR-011). Satu modul tipis `ItemService` (server, Phase 3) hanya membungkus Backpack: give, has, consume, dan pemeriksaan template saat boot.

Rules:

- Progres quest (mis. Daun Kelor 4/4) milik QuestService dan TIDAK dihitung dari jumlah Tool. Tool hanya barang fisik pemain.
- Penyerahan ke Pemandu: server memastikan pemain memegang Tool-nya, menghapusnya, lalu memajukan state quest.
- Pencarian Tool harus mengecek Backpack DAN Character (Tool yang di-equip berpindah ke Character).
- Tool: `CanBeDropped = false`, Attribute `ItemId` diset server saat clone.
- Objek pickup di dunia BUKAN Tool di Workspace (Roblox memungut Tool otomatis saat disentuh). Pickup hanya lewat [E] (ADR-016). Spawner punya state server AVAILABLE -> COLLECTING -> COLLECTED.
- Spawn marker (KelorSpawn_N, FlowerSpawn_N) = penanda posisi; visual diambil dari template (asumsi, perlu dikonfirmasi saat Phase 4).
- Backpack reset saat respawn. KNOCKED bukan kematian Humanoid; kasus mati sungguhan dibahas di Phase 5/6.

Reason:

Pilihan user. Memakai mekanisme bawaan Roblox, tanpa struktur data inventory baru. Menggantikan `InventoryService` pada rencana awal.

Status:
ACCEPTED (user, 2026-10-05)



## ADR-019 — MODEL STATE QUEST: STATE PARTY SAJA, COUNTER DI CONFIG

Decision:

QuestService (src/server/Services/QuestService.luau) adalah satu-satunya pemilik state quest dan counter party. Definisi quest, transisi, dan counter ada di `shared/Config/QuestConfig` (data saja). State direplikasi lewat Attribute pada `ReplicatedStorage.QuestState` (`<QUEST>_State`, `<QUEST>_<Counter>`), mengikuti ADR-014.

Rules:

- Transisi hanya yang tercantum di QuestConfig (ADR-009). Gagal puzzle yang boleh coba lagi (CHEST_PUZZLE) tetap di state yang sama.
- `addProgress` hanya diterima saat quest berada di `requiredState` milik counter; nilai dibatasi target; saat target tercapai quest otomatis pindah ke `completeState`. Ini juga menolak progres berlebih/duplikat.
- Party wipe Kantil: transisi CANTIL_PUZZLE -> SEARCHING_FLOWERS, counter Flowers di-reset lewat `resetCountersOnEnter`. Quest lain tidak tersentuh.
- Kafan: DIGANTIKAN ADR-038 (satu pemain; ALL_PLAYER_COMPLETE diganti GAMELAN_COMPLETE). Teks lama: PLAYER_SCORE / SCORE>=80 / PLAYER_COMPLETE adalah state PER PEMAIN, bukan state party.
- Quest berikutnya hanya bisa activate jika semua quest sebelumnya COMPLETE.
- Layanan lain bereaksi lewat `QuestService.onStateChanged`, tidak mengubah state sendiri.

Status:
ACCEPTED (menunggu uji Studio, Task 2.1)



## ADR-020 — GAME DIMULAI OLEH PEMAIN PERTAMA YANG MENAMATKAN DIALOG INTRO

Decision:

`GameFlowService` (server) menjadi perekat peristiwa cerita ke GameManager dan QuestService. Saat pemain pertama menamatkan dialog `Pemandu_Intro` sampai baris terakhir (`DialogueService.onCompleted`), server menjalankan: GameManager LOBBY -> INTRO -> QUEST_KERIS, QuestService.activate("KERIS"), lalu KERIS -> SEARCHING_KELOR. Penyelesaian berikutnya diabaikan karena state game sudah bukan LOBBY. Menutup dialog di tengah (Close/menjauh) tidak memulai game.

Reason:

MVP sederhana untuk co-op. Kekurangan: pemain lain bisa melewatkan dialog intro. Alternatif (menunggu semua pemain selesai) ditunda karena pemain AFK bisa menahan party.

Status:
ACCEPTED (menunggu uji Studio, Task 2.3)



## ADR-021 — QUEST UI: QUESTVIEW MURNI + QUESTCONTROLLER, DIALOG PEMANDU MENURUT STATE

Decision:

- Quest UI dirender `client/Controllers/QuestController` dari Attribute `ReplicatedStorage.QuestState`. Logika "objective mana yang sudah selesai" ada di `shared/Util/QuestView` (fungsi murni, bisa dites tanpa Roblox) dan memakai urutan state + `objectives` di QuestConfig. Panel disembunyikan selama quest pertama masih LOCKED (game belum dimulai); quest LOCKED lain menampilkan objective pertama saja.
- Panel memakai `ScreenInsets = TopbarSafeInsets` agar tidak menimpa menu Roblox, dan header 40 px sebagai tombol minimize.
- Penyimpangan dari ADR-017: teks panel memakai TextSize tetap (15/16) + AutomaticSize, bukan TextScaled, karena TextScaled tidak cocok untuk daftar yang tinggi barisnya otomatis. Lebar panel tetap proporsional (28% layar, min 210, maks 340 px).
- Pemandu memilih dialog lewat `GameFlowService.getPemanduDialogueId()` (LOBBY -> intro; KERIS SEARCHING_KELOR -> Pemandu_KerisSearch; lainnya -> tidak ada dialog sampai quest-nya dibuat).
- Redaksi objective dan dialog adalah PLACEHOLDER; samakan dengan GDD.

Status:
ACCEPTED (menunggu uji Studio, Task 2.2)



## ADR-022 — ITEMSERVICE: STACK LEWAT ATTRIBUTE COUNT, ITEM UNIQUE, ALL-OR-NOTHING

Decision:

`ItemService` (server) membungkus Backpack sesuai ADR-018; definisi item di `shared/Config/ItemConfig`.

- Item stackable (Daun Kelor, bunga, Minyak Zaitun) = SATU Tool dengan Attribute `Count`; nama tampilan menjadi "Daun Kelor x3". Menghindari banyak slot hotbar untuk item yang sama. Pencarian selalu lewat Attribute `ItemId`, bukan nama Tool.
- Item `unique` (Kunci Peti, Keris Pusaka, Kembang Kantil Hitam, Kain Kafan): pemain tidak bisa memegang lebih dari satu; `give` kedua ditolak. Ini lapisan anti-duplikasi tambahan di luar state spawner dan QuestService.
- `give`/`consume` tanpa yield (atomik). `consume` semua-atau-tidak: ditolak jika jumlah kurang.
- Backpack dan Character sama-sama dicek (Tool yang di-equip ada di Character).
- Template yang belum ada atau bukan Tool: `give` ditolak + warning; `init` melaporkan daftar template yang hilang sebagai dependency (tidak membuat pengganti).
- Belum ditangani: item hilang saat respawn (Backpack reset). Diputuskan di Phase 5/6 bersama knock/mati.

Status:
ACCEPTED (menunggu uji Studio, Task 3.1)



## ADR-036 — COLLECTIBLESERVICE: BANYAK STATE AKTIF + OBJECTIVE TANPA COUNTER (MINYAK ZAITUN)

Decision (2026-10-11, memperluas ADR-027; bukan salinan logika):

- `CollectionConfig.Collection` berubah: `activeState: string` -> `activeStates: { string }`; `counterId` jadi opsional; ditambah `spawnCount`. Kelor dan Flowers hanya mengganti ke `activeStates = { <state lama> }`, perilakunya tidak berubah.
- Aturan siklus: MASUK `activeStates[1]` = spawn ulang acak (juga saat party wipe CANTIL_PUZZLE -> SEARCHING_FLOWERS); KELUAR dari semua `activeStates` = pickup dihapus; pindah antar state aktif tidak mengubah apa pun. Pickup hanya bisa diambil selama quest berada di salah satu `activeStates`.
- Entri tanpa `counterId` = pickup pendukung: hanya memberi item (tanpa `QuestService.addProgress`), notifikasi tanpa (n/N). Jumlah titik aktif dari `spawnCount` (wajib bila tanpa counter; bila ada counter default = target counter).
- Opsi baru `clearOnLeave = false`: pickup tidak dihapus dan tetap bisa diambil setelah keluar dari `activeStates` (spawn sekali saat masuk `activeStates[1]`).
- Minyak Zaitun = entri `Zaitun` (REVISI arahan user 2026-10-11: spawn di AWAL GAME agar pemain tahu dan bisa memegangnya sejak awal): quest KERIS, `activeStates = { "SEARCHING_KELOR" }` (= tepat setelah dialog intro selesai), `clearOnLeave = false`, folder `Workspace.QuestObjects.ZaitunSpawns`, `spawnCount = 2` (2 titik aktif dari seluruh Part di folder), `assignment = SAME`. Sebelumnya terikat quest KANTIL (SEARCHING_FLOWERS..CANTIL_PUZZLE).
- ASUMSI (belum diputuskan di GDD, minta konfirmasi user): zaitun TIDAK respawn setelah diambil (bahan langka); spawn ulang saat party wipe diputuskan di Task 6.5. Zaitun juga ter-spawn saat solo (tidak dibedakan). Pickup yang tidak diambil tidak pernah dihapus.

Status:
PROPOSED (kode ditulis, luau-compile OK, BELUM dites di Studio)

## ADR-035 — REVIVE: TAHAN 3 DETIK, SESI DI SERVER, PENYELAMAT = REVIVING

Decision (2026-10-11, Phase 6 Task 6.4; arahan user):

- Syarat: penyelamat (state NORMAL) MEMEGANG (equip) Minyak Zaitun, berada dalam `MAX_DISTANCE` (8 studs, toleransi lag +4 di server) dari pemain KNOCK, menahan [E] (PC) / menahan tombol prompt (mobile, mouse) selama `HOLD_SECONDS` = 3. Config di `shared/Config/ReviveConfig` (client dan server memakai nilai yang sama).
- `ReviveService` (server) memiliki SESI: client hanya mengirim `ReviveRequest {action="Start", target=Player}` / `{action="Cancel"}`. Server memvalidasi (payload, target Player, target KNOCK, penyelamat NORMAL, memegang zaitun, jarak, kunci target, cooldown 0,5 dtk), membalas `ReviveUpdate {action="Start", targetName, duration}`, lalu memvalidasi ulang tiap 0,1 dtk dan MENGHITUNG waktu sendiri (client hanya menggambar progress bar). Selesai: consume 1 Minyak Zaitun -> `KnockService.recover(target)`; recover gagal = zaitun dikembalikan.
- Pembatalan tanpa kehilangan zaitun: lepas tombol, menjauh, ganti/hilang tool, mati/keluar, target pulih/keluar. Zaitun hanya berkurang saat berhasil.
- Kunci: satu sesi per penyelamat, satu sesi per korban (dua penyelamat tidak bisa memakai dua zaitun pada satu korban).
- State: `GameManager` mendapat transisi NORMAL -> REVIVING. REVIVING = state PENYELAMAT selama sesi (memblokir interaksi/dialog lain lewat guard NORMAL yang sudah ada); korban tetap KNOCKED sampai recover. Konsekuensi: `KnockService.knock` menolak pemain REVIVING (relevan untuk serangan hantu nanti: sesi harus dibatalkan dulu).
- Client (`ReviveController`): prompt muncul bila ada pemain KNOCK dalam jarak. Memegang zaitun = "Tahan [E] Sadarkan" (mengikat E dengan prioritas tinggi + menyembunyikan prompt interaksi lain). Tidak memegang = hanya petunjuk ("Pegang Minyak Zaitun" / "Butuh Minyak Zaitun"), tidak memblokir prompt lain (korban sering jatuh di makam yang masih perlu diisi bunga).
- Notifikasi (ADR-025): penyelamat menerima "Kamu menyadarkan X. Sisa Minyak Zaitun: n."; korban/rekan dapat "sadar kembali" dari KnockService; penolakan bermakna (tidak memegang zaitun, korban sedang disadarkan, terlalu jauh) lewat NoticeService.

Status:
PROPOSED (kode ditulis, luau-compile OK, BELUM dites di Studio)

## ADR-034 — RESET QUEST = STATE RETRY_GUIDE ("KEMBALI BICARA KE PEMANDU")

Decision (arahan user 2026-10-11, merevisi langkah reset di ADR-032):

- `QuestService.reset(questId)` mengembalikan quest ke `retryState` (KANTIL: `RETRY_GUIDE`), bukan LOCKED. Sebelumnya KANTIL LOCKED membuat Quest UI menampilkan Keris yang sudah selesai, membingungkan pemain.
- `RETRY_GUIDE` adalah state sungguhan milik server (direplikasi seperti state lain), di luar rantai linear: hanya transisi RETRY_GUIDE -> ACTIVE. Quest UI cukup membaca state: tampil satu objective "Kembali berbicara kepada Pemandu" (`retryObjective`).
- Pemandu memberi dialog khusus `Pemandu_KantilRetry`; menamatkannya memanggil `startQuest` (state game tetap QUEST_KANTIL), quest masuk ACTIVE -> SEARCHING_FLOWERS dengan counter 0 dan bunga baru. Penyelesaian dialog ganda aman (hanya jika state masih retryState).
- `QuestService.activate` menerima quest di LOCKED atau retryState. Quest lain tanpa `retryState` tetap kembali ke state awal.
- Aturan baru untuk quest lain: jika ingin dukungan "ulangi", cukup tambah `retryState`/`retryObjective` di QuestConfig, transisi retryState -> ACTIVE, dan dialog ulangi di GameFlowService.

Status:
ACCEPTED (diuji user di Studio, 2026-10-11)

## ADR-033 — JUMPSCARE: VIEWPORTFRAME LOKAL, SERVER MENUNGGU DURASI

Decision (2026-10-11, melaksanakan ADR-031):

- Model hantu hidup di ServerStorage/GhostModels (dikelola di Studio, bukan Rojo). JumpscareService menyalinnya saat boot ke ReplicatedStorage/GhostModels tanpa script supaya client bisa membuat ViewportFrame. Model baru yang ditambah saat Play baru terlihat setelah Play ulang.
- Remote `Jumpscare` memakai FireClient ke SATU pemain: pemain lain tidak melihat jumpscare. Client hanya presentasi (model + animasi + kamera + efek layar) dan tidak mengirim apa pun balik.
- Server menunggu `duration` (JumpscareConfig) lalu FailureService menjatuhkan hukuman. Durasi dibaca dari config bersama, client berhenti sendiri pada durasi yang sama; GUI tidak reset saat respawn sehingga tetap menutup layar sampai selesai.
- Selama jumpscare pemain berstatus CUTSCENE dan root di-anchor di server. Jika model/definisi tidak ada, jumpscare dilewati dan hukuman tetap berjalan (fail-open).
- Jarak kamera dinyatakan dalam kelipatan tinggi model (tidak tergantung skala model). Parameter tampilan per hantu ada di JumpscareConfig (yawOffset, fov, jarak, goyang, kilat, suara).
- Menambah hantu = satu entri baru di JumpscareConfig.Ghosts + model di ServerStorage/GhostModels.

Status:
ACCEPTED (diuji user di Studio, 2026-10-11)

## ADR-032 — KEGAGALAN SOLO = JUMPSCARE + RESPAWN + RESET QUEST; MULTIPLAYER = KNOCK

Decision (arahan user 2026-10-10, MENGGANTIKAN bagian solo di ADR-030):

- Solo (tersisa 1 pemain): kegagalan = jumpscare (6.2) -> respawn -> quest yang gagal di-reset dari awal -> pemain bertemu Pemandu lagi untuk memulai. Solo TIDAK di-knock (tidak ada rekan untuk revive, pemain terjebak).
- Multiplayer (2+ pemain): kegagalan = jumpscare -> knock. Rekan menyadarkan dengan Minyak Zaitun. Semua knock = party wipe (6.5, quest KANTIL -> SEARCHING_FLOWERS) tidak berubah.
- `FailureService.fail(player, reason, questId)` = satu-satunya pintu untuk semua penyebab gagal (bunga salah sekarang, hantu nanti). Memilih jalur lewat `PartyService.isSolo()`.
- Reset quest: `QuestService.reset(questId)` mengembalikan quest ke LOCKED + counter 0 (bukan transisi biasa; COMPLETE ditolak). Karena KERIS sudah COMPLETE dan state game tetap QUEST_KANTIL, dialog laporan Pemandu (Pemandu_KerisDone) memicu `startQuest("KANTIL")` seperti biasa. Teks dialog ulang masih memakai dialog laporan lama (placeholder); dialog khusus "ulangi" bisa ditambah nanti.
- Selama urutan solo gagal, pemain berstatus CUTSCENE (interaksi diblokir), kembali NORMAL setelah respawn. Item quest dibersihkan eksplisit; Backpack juga reset oleh respawn (ADR-018).
- `PartyService` sekarang = jumlah pemain di server. Rencana lobby (TASKS "Lobby & matchmaking") akan memasok mode dari TeleportData; pemanggil tidak perlu berubah.
- Risiko terbuka: pemain knock yang rekan-rekannya keluar sampai tersisa satu (solo mendadak) perlu ditangani di 6.5 lewat onAllKnocked (jalur solo = soloFail, bukan wipe biasa).

Status:
ACCEPTED (diuji user di Studio, 2026-10-11)

## ADR-031 — PHASE 6 DIPECAH BERTAHAP; KNOCKSERVICE TIDAK TAHU PENYEBAB; JUMPSCARE = VIEWPORT 3D LOKAL

Decision (arahan user 2026-10-10):

- Phase 6 dikerjakan bertahap, tiap tahap divalidasi user sebelum lanjut: 6.1 KnockService (server) -> 6.2 jumpscare (client) lalu knock -> 6.3 Knock UI -> 6.4 ramuan di map + revive -> 6.5 giliran tunggal, party wipe, flower reset.
- `KnockService` generik: `knock(player, reason)`. Penyebab (bunga salah, hantu penyerang di masa depan) hanya memanggil API ini. Pemulihan `recover(player)` TANPA validasi revive; syarat revive (ramuan di-equip, dekat korban, sekali pakai) milik ReviveService (6.4).
- Pose knock: HumanoidRootPart di-Anchor di server, badan berbaring telentang; WalkSpeed/Jump 0; tool dilepas. Anchor di server membuat client tidak bisa menggeser karakter. Reset/mati saat knock tidak membebaskan: CharacterAdded mengembalikan ke titik knock. Catatan: Backpack tetap reset saat respawn (ADR-018).
- Jumpscare (Task 6.2): presentasi CLIENT-ONLY pada pemain yang terkena saja: model 3D berrig + animasi di ViewportFrame layar pemain itu, dengan efek layar. Server hanya mengirim event ke satu pemain (Remote baru) dan menunggu durasi tetap sebelum memanggil knock; client tidak menentukan hasil gameplay. Urutan: onWrong -> jumpscare -> knock. Pemain lain tidak melihat jumpscare.
- Revive (Task 6.4): ramuan = item `MinyakZaitun` (sudah ada di ItemConfig, stackable) berupa Tool; disebar di map lewat CollectibleService. Syarat: penolong punya MinyakZaitun di Backpack DAN meng-equip-nya, dekat pemain knock; berhasil -> kurangi 1 (Tool hilang jika habis) -> recover(korban).
- Serangan hantu BELUM dibuat: dicatat di TASKS sebagai pekerjaan masa depan. Karena knock berbasis `reason`, hantu cukup memanggil jalur jumpscare + knock yang sama.
- Batasan 6.1: `knock` hanya menerima pemain berstatus NORMAL. Knock saat MINIGAME/dialog (mis. hantu menyerang saat puzzle) butuh pembatalan sesi MemoryPuzzleService; ditunda sampai hantu dibuat.

Status:
ACCEPTED untuk 6.1 dan 6.2 (diuji user di Studio, 2026-10-11); 6.3 menunggu uji; 6.4–6.5 belum dikerjakan

## ADR-030 — POLA KEGAGALAN KANTIL: BUNGA SALAH = JUMPSCARE + KNOCK; SEMUA KNOCK = WIPE (SOLO = LANGSUNG WIPE)

Decision (pola dari user 2026-10-10, dibangun di Phase 6):

- Meletakkan bunga yang SALAH di sebuah makam langsung memicu jumpscare lalu knock pada pemain itu.
- Multiplayer: pemain di-knock; bunga yang salah kembali ke pemain itu dan bunga yang sudah benar tetap di makam (jawaban user). Rekan yang berdiri melanjutkan; revive dengan Minyak Zaitun.
- [DIGANTI ADR-032 2026-10-10] Solo: jumpscare -> respawn -> quest KANTIL direset ke LOCKED dan dimulai lagi lewat Pemandu (Keris yang sudah disimpan tidak ikut reset).
- Disatukan: setelah pelaku di-knock, jika tidak ada lagi pemain NORMAL (semua knock) = party wipe (CANTIL_PUZZLE -> SEARCHING_FLOWERS, makam kosong, bunga di Backpack dihapus lalu di-spawn ulang lewat CollectibleService). [Solo = cabang khusus, lihat ADR-032.]
- Jumpscare = presentasi client (event dari server, visual/audio Phase 9). Kontrol giliran tunggal (Task 5.9) dirancang bersama paket ini.
- Titik sambung di kode: `GravePuzzleService.onWrong(player, graveName, itemId)`. TIDAK perlu mengubah QuestConfig (wipe dari CANTIL_PUZZLE sudah ada).

Status:
SEBAGIAN DIBANGUN: bunga salah -> jumpscare -> knock/solo respawn sudah diuji (ADR-031–034); party wipe dan flower reset menunggu Task 6.5

## ADR-029 — GRAVEPUZZLESERVICE: PLACEMENT BUNGA DI MAKAM, JAWABAN DI SERVER

Decision:

- Clue = SurfaceGui di makam (dibuat user di Studio, ADR-011). Kode tidak menampilkan/mengirim clue (tidak ada Task 5.6 berkode).
- Placement: pemain MEMEGANG (equip) bunga lalu [E] "Letakkan Bunga" di makam `Workspace.QuestObjects.Graves.<Grave_N>`. Tanpa GUI/Remote baru. Server membaca Tool yang di-equip, bukan client.
- ASUMSI (belum diputuskan di GDD): 4 makam, tiap bunga dicocokkan ke makam yang benar (jumlah makam = jumlah entri `GravePuzzleConfig.ANSWER`). Jawaban benar = peta makam -> ItemId di `src/server/Config/GravePuzzleConfig.luau` (sisi server agar tidak terreplikasi). ANSWER saat ini PLACEHOLDER (`ANSWER_CONFIRMED=false`, ada warn saat boot).
- Validasi PER BUNGA (diperbarui 2026-10-10 sesuai pola desain user): setiap bunga dinilai saat diletakkan. Percobaan pertama memajukan state FLOWERS_COMPLETE -> FLOWERS_PLACEMENT -> CANTIL_PUZZLE (puzzle berjalan; wipe dari CANTIL_PUZZLE sudah valid di QuestConfig). BENAR: bunga dipakai dan tetap di makam, progres (n/4). SALAH: bunga TIDAK dipakai (tetap di Backpack pemain, tidak ada bunga hilang), makam tidak berubah, hook onWrong(player, graveName, itemId). Makam penuh -> CANTIL_BLACK_OBTAINED.
- Hadiah Kembang Kantil Hitam ke penempat bunga terakhir. Template hadiah dicek SEBELUM bunga terakhir dipakai. Gagal di tengah = rollback.
- Hook `GravePuzzleService.onWrong(listener)` dipanggil per bunga salah; jumpscare + knock (Phase 6, ADR-030) dipasang di sini. SAMPAI PHASE 6 bunga salah belum berhukuman (hanya notifikasi).
- Bunga pemain yang keluar game dipindah ke pemain lain (state pencarian s.d. puzzle). Pemegang hadiah yang keluar: hadiah dipindah.
- Party wipe (masuk SEARCHING_FLOWERS) mengosongkan slot makam. Penghapusan sisa bunga dari Backpack = task Flower reset.
- DITUNDA (diputuskan user 2026-10-10): kontrol giliran tunggal dikerjakan bersama sistem knock/revive di Phase 6. Sementara itu setiap [E] atomik di server dan bunga terbagi antar pemain, jadi tidak ada kunci giliran. Titik sambung: hook onWrong.
- Duplikasi kecil `pickPlayer` (mirip `pickHolder` KerisQuestService); kandidat util bersama saat ada pemakai ketiga.

Status:
ACCEPTED (diuji user di Studio, 2026-10-11). Catatan: jawaban GravePuzzleConfig.ANSWER masih placeholder (ANSWER_CONFIRMED=false)

## ADR-028 — GAMEFLOWSERVICE GENERIK: PEMANDU MELAPOR QUEST SELESAI LALU MEMBERI QUEST BERIKUTNYA

Decision:

- `QUEST_FLOW` (questId -> state game + state pertama) dan `startQuest` dipakai bersama intro (KERIS) dan quest berikutnya. Tidak ada urutan aktivasi yang di-hardcode per quest.
- `QUEST_DIALOGUES[quest][state]` memetakan dialog Pemandu per state (nilai boleh fungsi untuk dialog per pemain). Quest berjalan = quest pertama yang bukan LOCKED/COMPLETE.
- `REPORT_DIALOGUES[quest]`: saat quest COMPLETE (item sudah disimpan di RitualCollection, ADR-026), Pemandu melapor; menamatkan dialog laporan memberi quest berikutnya bila masih LOCKED (aman dipanggil ganda). Sekarang: KERIS -> KANTIL. KAFAN ditambahkan di Phase 7.
- ASUMSI (belum diputuskan di GDD): quest berikutnya dimulai lewat dialog laporan Pemandu, sesuai core loop "bertemu Pemandu -> menerima quest". Mengubah ke aktivasi otomatis cukup mengganti pemicu startQuest.

Status:
ACCEPTED (diuji user di Studio, 2026-10-11)

## ADR-027 — COLLECTIBLESERVICE: SATU MODUL UNTUK SEMUA OBJECTIVE KOLEKSI

Decision:

- `CollectibleService` (server) menjalankan semua objective "kumpulkan N item di titik acak". Definisi di `CollectionConfig.Collections` (questId, counterId, activeState, spawnFolder, interactionId, itemIds, assignment, actionText, pickupDistance, completeNotice). Kelor (KERIS) dan Flowers (KANTIL) adalah dua entri; logika Kelor dipindah dari KerisQuestService tanpa perubahan perilaku.
- Siklus: masuk activeState -> pilih N titik acak (N = target counter di QuestConfig, satu sumber kebenaran) -> spawn pickup Model; [E] -> validasi server (objek terdaftar, status AVAILABLE, state quest benar) -> item ke Backpack -> progres party-wide -> notifikasi; keluar activeState -> pickup sisa dihapus. Masuk activeState lagi (party wipe Kantil) = spawn ulang.
- `assignment`: SAME (semua titik item yang sama, Kelor) atau DISTINCT (tiap jenis item tepat sekali, diacak ke titik aktif, bunga). ASUMSI bunga: 4 titik aktif dari 8, empat jenis masing-masing sekali (GDD hanya menyebut 8 lokasi, 4 aktif, 4 jenis).
- Status pickup server: AVAILABLE -> COLLECTING -> COLLECTED (anti-duplikasi). Notifikasi lewat NoticeService.
- Belum termasuk: penghapusan bunga dari Backpack saat party wipe (Task "Flower reset").

Status:
ACCEPTED (diuji user di Studio, 2026-10-11)

## ADR-026 — QUEST SELESAI = ITEM DISIMPAN DI RITUALCOLLECTION; PEMANDU HANYA MELAPOR

Decision:

- Item akhir quest (Keris Pusaka, Kembang Kantil Hitam, Kain Kafan) disimpan di `Workspace.QuestObjects.RitualCollection` (Model) lewat satu prompt [E] Simpan. Saat disimpan: item dihapus dari Backpack -> state `*_SUBMITTED` -> `COMPLETE`.
- `RitualCollectionService` generik; daftar persembahan di `RitualConfig.Offerings` (questId, itemId, obtainedState, submittedState). Server memilih persembahan dari state quest dan isi Backpack pemain; client tidak menentukan apa pun.
- Prompt hanya aktif (tag) saat ada quest yang itemnya sudah didapat tetapi belum disimpan.
- Pemandu tidak lagi menyelesaikan quest. Dialognya: `Pemandu_KerisStore` (petunjuk untuk pemegang), `Pemandu_KerisWait` (non-pemegang), `Pemandu_KerisDone` (melapor setelah COMPLETE). Menggantikan alur "serahkan ke Pemandu" di Task 4.6.
- `getStoredCount()` dipakai Phase 8 (ritual akhir) untuk memastikan ketiga persembahan sudah tersimpan.
- Aktivasi quest berikutnya setelah COMPLETE belum ditentukan (Phase 5).

Status:
ACCEPTED (Phase 4 ditutup 2026-10-05)

## ADR-025 — SEMUA NOTIFIKASI LEWAT NOTICESERVICE

Decision:

- `NoticeService` (server) + `NoticeController` (client) adalah satu-satunya jalur notifikasi gameplay. Dilarang membuat jalur lain.
- API: `send(player, text)`, `broadcast(text)`, `notifyParty(actor, selfText, othersText)` (pelaku "Kamu ...", rekan "<nama> ...").
- Notifikasi wajib untuk item didapat (pemain dan rekan), progres party, perpindahan kunci/keris, knock, revive, party wipe, quest selesai, pemain keluar yang memengaruhi quest, dan penolakan aksi yang perlu penjelasan.
- Client menumpuk hingga 4 toast (terbaru di bawah, 4 detik) agar pesan beruntun tidak saling menimpa.
- Notifikasi hanya tampilan; tidak membawa keputusan gameplay.

Status:
ACCEPTED

## ADR-024 — MEMORY PUZZLE PETI: SESI SERVER, GUI TAP, SATU SESI PER PARTY

Decision:

- Minigame ingat-dan-susun suku kata HA NA CA RA KA. Server membuat urutan acak (MemoryPuzzleConfig.SYLLABLES), client menampilkannya MEMORIZE_SECONDS lalu menyembunyikannya; pemain menyusun ulang dengan mengetuk token.
- `MemoryPuzzleService` generik (callback onCorrect milik pemanggil). Server memvalidasi: pemain, sesi aktif, cooldown aksi, fase hafalan sudah lewat, format jawaban (5 token unik dikenal), lalu membandingkan dengan urutan soal. Timeout sesi di server.
- Satu sesi aktif per party; pemain berstatus MINIGAME selama sesi (interaksi lain terblokir oleh InteractionService).
- Gagal = tidak ada hukuman, state tetap CHEST_PUZZLE, peti bisa dibuka lagi (urutan baru). Peti hanya interaktif saat CHEST_AVAILABLE/CHEST_PUZZLE (tag diatur server).
- Item unik (KunciPeti, KerisPusaka) dilacak di `holders`; jika pemegang keluar game, dipindah ke pemain acak lain.
- GUI memakai tombol (bukan keyboard) agar sama di PC dan mobile. Aksara Jawa tidak dipakai (font Roblox tidak menjamin glyph); teks latin.

Status:
ACCEPTED (Phase 4 ditutup 2026-10-05)

## ADR-023 — PICKUP DUNIA = MODEL DARI TEMPLATE; RANDOMSPAWNSERVICE GENERIK + SERVICE PER QUEST

Decision:

- `RandomSpawnService` (server) generik: `pickSpawns` (pilih N titik berbeda, acak di server) dan `createPickup` (buat Model statis dari isi Tool template: Script dibuang, semua BasePart Anchored/CanCollide=false/CanTouch=false, PrimaryPart = Handle, di-pivot ke CFrame titik spawn, diberi tag Interactable + Attribute). Pickup dibuat di `Workspace.QuestRuntime` (folder dibuat server saat runtime, tidak masuk Git).
- Logika per quest ada di service quest sendiri. `KerisQuestService` menangani Kelor sekarang (peti/kunci/puzzle/penyerahan menyusul) dan dipakai ulang polanya oleh quest Kantil.
- Jumlah Kelor aktif = `target` counter Kelor di QuestConfig (satu sumber kebenaran).
- Spawn dipicu `QuestService.onStateChanged` (masuk SEARCHING_KELOR), dibersihkan saat keluar dari state itu.
- Pickup: tabel server `pickups[model] = {status}` dengan AVAILABLE -> COLLECTING -> COLLECTED. Diterima hanya jika objek terdaftar, status AVAILABLE, dan quest di SEARCHING_KELOR. Urutan: give item -> addProgress; jika addProgress ditolak, item dibatalkan (consume) dan pickup kembali AVAILABLE.
- Titik spawn (KelorSpawn_N) hanya penanda; service tidak mengubah/menyembunyikannya. Model muncul dengan orientasi dan pusat titik spawn.

Status:
ACCEPTED (Phase 4 ditutup 2026-10-05)

## ADR-037 — MINYAK ZAITUN SELALU 2 PICKUP AKTIF (REPLENISH) DI TITIK BERBEDA

Context:

Revive memakai Minyak Zaitun (ADR-035/036) dan ADR-036 menetapkan zaitun tidak respawn setelah diambil. Kesalahan berulang (knock berkali-kali) bisa menghabiskan zaitun yang ada. REVISI user 2026-10-11: zaitun harus SELALU ada 2 di dunia walau sudah dibawa pemain; spawn berikutnya tidak boleh di titik yang pernah dipakai.

Decision:

- Opsi generik baru `replenish` di `CollectionConfig` (bukan service baru; ADR-027 tetap DRY). Dipakai entri `Zaitun`. Hanya untuk entri tanpa `counterId` (di-assert saat register).
- `CollectibleService`: tiap pickup `COLLECTED`, server langsung `refill`: jumlah aktif dipulihkan ke `target` (2). Pengganti dipilih acak (server) dari titik di `ZaitunSpawns` yang BELUM PERNAH dipakai sejak spawn awal (`usedSpawns`). Titik yang dipakai pickup yang tidak diambil juga tetap tercatat "terpakai".
- `RandomSpawnService.pickSpawns(container, count, exclude?)`: parameter `exclude` opsional (kompatibel mundur; Kelor/bunga tidak berubah).
- Pool habis (semua titik pernah dipakai): ASUMSI (belum diputuskan user) = daftar "pernah dipakai" di-reset agar revive tidak buntu, TAPI titik yang sedang aktif dan titik yang baru saja diambil tetap dikecualikan; log warning "siklus baru". Alternatif bila user mau: berhenti respawn saat pool habis.
- `usedSpawns` di-reset hanya bila spawnAll berjalan ulang (masuk lagi ke SEARCHING_KELOR). Itu tidak terjadi pada alur normal (KERIS hanya sekali).
- Tidak mengubah: validasi pickup (AVAILABLE -> COLLECTING -> COLLECTED), ReviveService, pengurangan zaitun saat revive berhasil.
- Tidak termasuk: zaitun yang hilang dari Backpack karena pemain mati/respawn (risiko ADR-018) tidak memicu spawn pengganti; pengganti hanya muncul saat pickup di dunia diambil.

Konsekuensi: jumlah titik di `ZaitunSpawns` menentukan berapa kali pengganti bisa muncul sebelum siklus baru (N titik: 2 awal + N-2 pengganti). Disarankan >= 6 titik.

Status:
ACCEPTED sebagai arahan user; logika lulus harness offline; BELUM dites di Studio.


## ADR-038 — QUEST KAFAN: GAMELAN RITME 4 KOLOM, SATU PEMAIN, SERVER-AUTHORITATIVE

Context:

GDD awal (GAME_CONTEXT bagian 9, ADR-019): semua pemain harus mencapai skor >= 80 (per pemain, 6 kolom). REVISI user 2026-10-11: hanya SATU pemain yang memainkan gamelan; gaya Guitar Hero dengan 4 kolom; PC memakai Q W E R, mobile mengetuk layar; musik gamelan diputar saat mulai (ID audio menyusul), durasi sesi = durasi musik (1 menit 37 detik = 97 detik).

Decision:

- Perubahan terhadap GDD (disetujui user): 4 kolom (bukan 6); SATU pemain bermain; skor >= 80 meluluskan quest untuk seluruh party. Tidak ada lagi skor/komplesi per pemain. State party Kafan: LOCKED -> ACTIVE -> FIND_GAMELAN -> GAMELAN_ACTIVE -> GAMELAN_COMPLETE -> KAIN_OBTAINED -> KAIN_SUBMITTED -> COMPLETE (`ALL_PLAYER_COMPLETE` diganti `GAMELAN_COMPLETE`; ADR-019 poin Kafan digantikan).
- [DIGANTIKAN ADR-039: skor kini mulai 100 dan turun] Skor akhir = persen dari poin maksimum (0-100): Perfect 10 poin, Good 7, Miss 0, lulus bila >= 80 (ASUMSI: GDD hanya menyebut poin per not dan batas 80; dipilih persen agar batas 80 tetap bermakna berapa pun jumlah not). Jendela waktu: Perfect +-0,10 dtk, Good +-0,20 dtk (config).
- Dua service, mengikuti pola Keris: `RhythmGameService` (mesin minigame generik: chart, sesi, validasi, skor) dan `KafanQuestService` (objek Gamelan, transisi state, hadiah, pemegang kain). Client: `GamelanController` (GUI + input). Config: `shared/Config/GamelanConfig`. Remote: `GamelanUpdate`, `GamelanAction`.
- Server-authoritative: chart dibuat server (acak per sesi di grid BPM, belum ada beatmap per lagu — ASUMSI sampai musik asli masuk). Client memuat musik lalu mengirim `Ready` (jam sesi server mulai di saat itu), lalu `Hit {lane, t}` tiap tekanan. Server memeriksa: payload valid; lane integer 1-4; jam lagu `t` cocok dengan jam server (tidak boleh dari masa depan > 0,3 dtk atau tertinggal > 2 dtk); jarak minimal antar tekanan; batas total tekanan; satu not hanya bisa dinilai sekali. Server menutup sesi sendiri saat durasi habis (+3 dtk) dan menghitung skor. Client tidak mengirim "selesai" atau skor.
- BATASAN JUJUR: server tidak bisa membedakan bot yang menekan di waktu nyata dari manusia (client harus tahu chart agar bisa menggambar not). Yang dicegah: skor instan tanpa waktu berjalan, duplikasi, spam, dan skor yang dikarang client. Bila perlu nanti: kirim chart bertahap per jendela dan/atau deteksi pola tekanan terlalu sempurna.
- Selama bermain: state pemain MINIGAME; karakter dibekukan server (WalkSpeed/Jump 0, dipulihkan hanya bila masih beku oleh sesi) karena Q/W/E/R bertabrakan dengan gerak/interaksi; client menelan Q/W/E/R (ContextActionService prioritas tinggi) dan InteractionController diblokir. Sesi dibatalkan tanpa hasil/hadiah bila pemain knock, karakter hilang, keluar, menekan BATAL, atau musik tidak siap dalam 10 dtk.
- Hanya satu sesi per party. Pemain lain yang menekan [E] diberi notifikasi "<nama> sedang memainkan gamelan". Gagal skor = tetap GAMELAN_ACTIVE; siapa pun boleh mencoba lagi (ADR-039 menambah jumpscare saat gagal, tetap tanpa knock/reset).
- Alur quest: Pemandu_KantilDone (laporan Kantil COMPLETE) memulai KAFAN (GameFlowService: `KAFAN` di QUEST_FLOW dan REPORT_DIALOGUES KANTIL). [E] Mainkan pertama: FIND_GAMELAN -> GAMELAN_ACTIVE. Lulus: beri KainKafan -> GAMELAN_COMPLETE -> KAIN_OBTAINED; kain disimpan di RitualCollection (ADR-026, tidak berubah). Pemegang kain keluar sebelum menyimpan: kain dipindah ke pemain lain.
- Musik diputar lokal di client pemain yang bermain (sinkron dengan jam sesi). [Opsi rekan ikut mendengar DIKERJAKAN di ADR-039.]

Dependency (Studio): `Workspace.QuestObjects.Gamelan` (Model/Part), template Tool `ServerStorage.QuestTemplates.KainKafan`, ID audio di `GamelanConfig.SOUND_ID`.

Status:
ACCEPTED sebagai arahan user; server lulus harness offline; client hanya lulus kompilasi; BELUM dites di Studio.



## ADR-039 — GAMELAN: SKOR DIPERTAHANKAN (100 -> TURUN), GAGAL < 80 = JUMPSCARE, MUSIK TERDENGAR PEMAIN LAIN

Context:

ADR-038: skor akhir = persen poin yang dikumpulkan; gagal skor hanya notifikasi dan boleh ulang tanpa hukuman. REVISI user 2026-10-11 (sesi lanjutan Phase 7): skor MULAI 100 dan pemain harus mempertahankannya; skor < 80 = langsung tutup UI + jumpscare seperti minigame makam (model hantu sama dulu, nanti diganti); musik harus terdengar pemain lain, UI hanya untuk pemain yang bermain, pemain lain bebas bergerak, pemain yang bermain diam.

Decision:

- Penilaian (MENGGANTIKAN poin ADR-038 tentang "persen poin"): `START_SCORE = 100`; tiap Good -`GOOD_PENALTY` (1), tiap Miss -`MISS_PENALTY` (3), Perfect -`PERFECT_PENALTY` (0). Konstanta `PERFECT_POINTS`/`GOOD_POINTS` dihapus. Angka penalti ADALAH ASUMSI AI (user tidak menyebut): 6 Miss masih aman (82), Miss ke-7 gagal (79); 20 Good aman, Good ke-21 gagal. Semua di GamelanConfig untuk disetel.
- Gagal kapan pun skor < `REQUIRED_SCORE` (80), diputuskan SERVER. Miss dinilai server real-time (Heartbeat): not menjadi Miss setelah `note.time + GOOD_WINDOW + MISS_GRACE` (0,4 dtk kelonggaran latensi) bila belum dinilai; tanpa tekanan sama sekali = gagal di Miss ke-7, bukan di akhir lagu. Sapu akhir sebelum menghitung hasil. Tekanan tanpa not tetap tanpa penalti (hindari hukuman karena spam/latensi).
- Gagal: `RhythmGameService.failSession` menutup sesi (kirim `Close` -> client menutup GUI dan menghentikan musik lokal), lalu memanggil `hooks.onFail` di thread terpisah. Lulus = bertahan sampai durasi habis dengan skor >= 80; alur hadiah ADR-038 tidak berubah. Tidak ada layar Result untuk gagal.
- API baru `RhythmGameService.start(player, onFinish, hooks?)` (kompatibel mundur) dengan `Hooks = { onFail, onPlaying, onClosed }`. Remote `GamelanUpdate` menambah `{ action = "Score", score }` (server -> client tiap skor berubah; client TIDAK menghitung skor sendiri) dan `Start.score`.
- Jumpscare: `FailureService.scare(player, reason)` = CUTSCENE -> jumpscare (JumpscareService, ADR-033) -> NORMAL, TANPA knock/reset quest. `FailureConfig.JumpscareByReason.GAMELAN_FAIL = "Pocong"` (placeholder; ganti ke hantu lain = ubah satu entri + tambah model di JumpscareConfig.Ghosts). ASUMSI: "sama seperti grave" diartikan jumpscare saja; knock/respawn grave TIDAK dipakai karena ADR-038 menetapkan gagal gamelan boleh diulang langsung. Jika user ingin hukuman penuh, ganti `FailureService.scare` di `KafanQuestService.onFail` dengan `FailureService.fail`.
- Musik untuk pemain lain: `hooks.onPlaying` (saat Ready) menulis Attribute pada objek Gamelan: `MusicStartServerTime` lalu `MusicPlayerUserId`; `hooks.onClosed` (semua akhir sesi) menghapusnya. Client lain (`GamelanMusicController`) memutar `Sound` spasial di BasePart gamelan (InverseTapered, min 20 / maks 160 studs), `TimePosition` dari `Workspace:GetServerTimeNow() - start` sehingga pemain yang baru masuk ikut tersinkron. Pemain yang bermain TIDAK memutar suara dunia (memakai musik lokal yang sinkron dengan not; tidak ada gema ganda). Memakai Attribute (pola ADR-014), bukan Remote baru. Presentasi audio murni di client; server tidak mempercayai apa pun dari client untuk ini.
- UI hanya di client pemain yang bermain (tidak berubah: GUI lokal, Remote `GamelanUpdate` hanya `FireClient` ke pemain itu). Pemain lain tidak dikunci apa pun. Pemain yang bermain diam: WalkSpeed/Jump 0 dari server + Q/W/E/R ditelan client + InteractionController diblokir (ADR-038, tidak berubah). Dipulihkan di closeSession (lulus/gagal/batal/keluar), dan jumpscare lalu mengunci ulang sebentar.

Consequences / batasan:

- Sinkron musik dunia vs musik pemain tidak presisi (selisih latensi jaringan, beberapa ratus ms); disengaja, hanya latar bagi pemain lain.
- Skor di layar bergerak sedikit terlambat dari teks MISS (server menilai Miss +0,4 dtk setelah client menampilkan MISS).
- Anti-bot tetap terbatas (ADR-038). Gagal-karena-diam mempersulit "hit nol" tetapi tidak membedakan bot.
- Kain Kafan di Backpack tetap hilang bila pemegang mati (ADR-018, tidak berubah).

Status:
ACCEPTED sebagai arahan user; logika server lulus harness offline; client (GUI, musik dunia) BELUM dites di Studio.


## ADR-040 — RITUAL AKHIR: PEMANDU MELAPOR, BERKUMPUL DIHITUNG SERVER, CUTSCENE DIMAINKAN SERVER, CLIENT HANYA TAMPILAN

Context:

Phase 8 (GDD bagian ritual akhir): pusaka tersimpan -> aktivasi ritual -> pemain berkumpul (1/1..4/4) -> urutan Pemandu -> dialog -> perubahan lingkungan -> cutscene -> ending -> GAME_COMPLETE. Penyimpanan dan validasi item sudah ada (ADR-026), jadi Phase 8 hanya menambah lapisan di atasnya.

Decision:

- Pemicu: laporan Pemandu terakhir (`Pemandu_KafanDone`, REPORT_DIALOGUES.KAFAN `startsFinalRitual`) -> `GameFlowService.startFinalRitual` -> `GameManager.transitionTo(FINAL_RITUAL)` hanya dari QUEST_KAFAN dan hanya jika SEMUA quest COMPLETE. Mengikuti pola ADR-026/028 (Pemandu melapor; keputusan di server). `FinalRitualService.beginGathering` memeriksa ulang 3/3 (sabuk pengaman bila state dipaksa dari luar).
- `GameManager.onStateChanged(listener)` ditambahkan (additive, pola sama dengan `QuestService.onStateChanged`); FinalRitualService bereaksi pada FINAL_RITUAL tanpa GameFlowService mengenalnya (tanpa dependensi melingkar).
- Berkumpul = SERVER menghitung: pemain dengan state NORMAL, karakter hidup, dalam `GATHER_RADIUS` (30 studs) dari pivot `Workspace.QuestObjects.RitualCollection`. Target = `PartyService.getSize()` (min 1), dihitung ulang tiap tick sehingga pemain yang keluar mengecilkan target. Semua siap terus-menerus selama `START_HOLD_SECONDS` (3 dtk) -> mulai; ada yang meninggalkan -> hold direset + notifikasi. Titik kumpul = objek yang sudah wajib ada (tanpa dependency Studio baru); jika hilang: warn sekali dan ritual tidak mulai.
- TIDAK ADA remote client -> server di sistem ini: client tidak bisa mengaku "sudah berkumpul". Client hanya membaca Attribute ReplicatedStorage (`FinalRitual_Ready/Required/Holding`) untuk HUD "n/N" (pola ADR-014).
- Fase internal `IDLE -> GATHERING -> SEQUENCE -> DONE`. Perpindahan ke SEQUENCE terjadi tanpa yield di dalam `tick()` sehingga tidak bisa mulai ganda; `transitionTo(ENDING)` juga menolak transisi kedua.
- Cutscene dimainkan SERVER per langkah (`FinalRitualConfig.Sequence`), dikirim lewat satu remote server -> client `CutsceneUpdate` (`Start/Step/End/Close`) memakai `FireAllClients`. Dipilih subtitle otomatis (bukan DialogueService) karena DialogueService adalah sesi per-pemain berbasis tombol Next dan akan membuat tiap pemain bergerak dengan kecepatan sendiri; ritual harus serentak. Konsekuensi: tidak ada tombol skip. Perubahan lingkungan (Lighting) dimainkan client lokal menurut nama preset dari server (Lighting direplikasi server -> client tidak halus, jadi tween di client).
- Selama cutscene: state pemain CUTSCENE (InteractionService dan DialogueService sudah menolak non-NORMAL) + Humanoid WalkSpeed/JumpPower/JumpHeight 0, dipulihkan saat selesai. Urutan selesai: End card -> `Close` -> GAME_COMPLETE -> pemain dilepas (NORMAL). Seluruh cutscene dibungkus pcall: error di tengah tetap menyelesaikan game dan melepas pemain (tidak ada soft-lock).
- Pemain knock saat FINAL_RITUAL dibuka dipulihkan otomatis (KnockService.recover) karena knock tidak dihitung "siap" dan fase ini tidak punya mekanik gagal; tanpa ini satu pemain pingsan tanpa Minyak Zaitun memblokir akhir game (soft-lock). Tinjau ulang di Phase 9 bila ada hantu di fase ini.
- Perubahan GDD: tidak ada. Teks Pemandu/ritual = PLACEHOLDER (GDD tidak tersedia di repo).

Consequences / batasan:

- Pemain yang bergabung di tengah cutscene tidak dibekukan dan hanya melihat sisa langkah (lobby/teleport nanti membuat ini jarang).
- Belum ada gerak kamera; letterbox + subtitle + Lighting saja. Efek horor lengkap = Phase 9.
- Setelah GAME_COMPLETE pemain bebas bergerak; kembali ke lobby menunggu sistem lobby.

Status:
ACCEPTED (implementasi atas arahan user "mulai kerjakan phase 8"); logika server lulus harness offline; client BELUM dites di Studio.


## ADR-041 — CUTSCENE PEMBUKA SAAT JOIN: MODUL PLUGIN PER SLOT PEMAIN, SERVER HANYA MEMICU

Context:

User membuat cutscene kamera dengan plugin Open Cutscene Editor (menggantikan rencana Phase 8 "kamera lewat script"). Hasilnya ModuleScript `ServerStorage/CutScenes/CutscenePlayer1..4`, tiap modul punya `PlayCutscene(player)` yang menyalin LocalScript pemutar + CutsceneInfo ke PlayerGui. User meminta TES dulu saat pemain masuk.

Decision:

- `IntroCutsceneService` (server) memilih slot (terendah yang kosong, 1..4) per pemain yang masuk dan memanggil `CutscenePlayerN.PlayCutscene(player)` dalam pcall, setelah karakter pertama muncul + `START_DELAY` (1 dtk) supaya kamera tidak direset spawn. Kamera dijalankan sepenuhnya di client oleh script plugin; server tidak mengirim data kamera.
- Objek Studio = dependency (ADR-011): modul hilang/tanpa `PlayCutscene` = warn, tidak membuat pengganti. Rojo tidak memetakan ServerStorage, jadi folder `CutScenes` aman dari sinkronisasi.
- Saklar `IntroCutsceneConfig.ENABLED`.

Consequences / batasan (jujur):

- Plugin tidak memberi sinyal "selesai" ke server: pemain TIDAK dikunci selama cutscene dan alur game (dialog Pemandu, interaksi) tetap bisa berjalan; kamera bisa konflik dengan tindakan pemain. Perlu keputusan: durasi tetap untuk state CUTSCENE, atau sinyal selesai dari LocalScript.
- Pemain yang masuk di tengah game ikut memutar cutscene (TES saja; kelak dibatasi ke LOBBY/pemain pertama).
- Jika modul membuat kamera Scriptable dan tidak mengembalikannya, kamera macet; tergantung implementasi plugin (belum diperiksa).
- Cutscene ritual akhir (ADR-040) belum memakai cutscene plugin; bisa disambungkan serupa (modul terpisah + pemicu dari FinalRitualService).

Status:
ACCEPTED sebagai arahan user (tes awal); logika slot lulus harness offline; BELUM dites di Studio.


## ADR-042 — TRIGGER TES CUTSCENE (PROXIMITYPROMPT, SEMENTARA)

Context:

User sedang membuat cutscene (plugin Open Cutscene Editor, ADR-041) dan butuh cara memutarnya tanpa menyelesaikan quest atau masuk ulang. `Workspace.triggerCutscene` dibuat user di Studio (tidak ada di Git, ADR-011). IntroCutsceneService (ADR-041) hanya memutar saat join, per slot pemain.

Decision:

- `CutsceneTestService` (server) memakai ProximityPrompt (bukan InteractionService) karena ini alat tes, bukan interaksi gameplay; sengaja terpisah supaya mudah dicabut. Memakai ProximityPrompt yang sudah ada di trigger; bila tidak ada, dibuat di BasePart trigger.
- `Triggered` hanya jalan di server; penjaga `running` mencegah urutan ganda; prompt dimatikan selama urutan.
- Urutan: CutscenePlayer1 -> 2 -> 3 -> 4, tiap modul diputar untuk SEMUA pemain yang ada, lalu menunggu semua clone `LocalCutscenePlayer` hilang dari PlayerGui sebelum modul berikutnya. Timeout 120 dtk per modul (clone dihancurkan paksa); bila clone tidak terdeteksi, jeda 5 dtk.
- Pemain NORMAL dikunci ke CUTSCENE selama urutan lalu dikembalikan ke NORMAL; pemain dengan state lain tidak disentuh.
- Tidak mengubah state game/quest. Hanya aktif di Studio (`ONLY_IN_STUDIO`); saklar `ENABLED`.

Assumptions (belum diverifikasi, minta konfirmasi user):

- "Berurutan" = Player1..4 diputar satu per satu untuk semua pemain. ADR-041 memakai N sebagai slot pemain (satu modul per pemain, paralel); jika tes ingin meniru itu, tambahkan mode PER_SLOT.
- LocalScript `LocalCutscenePlayer` menghancurkan dirinya sendiri saat cutscene selesai (plugin tidak memberi callback ke server, ADR-041). Bila tidak, tiap modul menunggu sampai timeout.

Revisi (tes Studio pertama, 2026-10-11): clone `LocalCutscenePlayer` TIDAK menghilang sendiri setelah `CutscenePlayer1` dimulai (Output berhenti di "memutar 1/4"), jadi asumsi kedua salah/belum terbukti. Perbaikan: `GAP_BETWEEN = 0` (langsung sambung); `DURATIONS` per modul di CutsceneTestConfig (lanjut saat clone hilang ATAU durasi habis, lalu clone dibersihkan); `DUMP_CLONE_INFO` mencetak isi clone/CutsceneInfo ke Output untuk mencari nilai durasi atau sinyal selesai bawaan plugin. Solusi final (sinyal selesai sungguhan dari script plugin) menunggu isi `LocalCutscenePlayer` dari user.

Revisi 2 (tes Studio kedua): dump clone menunjukkan `CutsceneInfo` (Open Cutscene Editor) = titik kamera `Position1..N` (CFrameValue), tiap titik punya `Time` (NumberValue, detik), `EasingStyle`, `EasingDirection`. Contoh: Position1 Time=3, Position2 Time=1.5 (total 4,5 dtk). Keputusan: durasi OTOMATIS = jumlah `Time` semua titik + `DURATION_MARGIN` (0,25 dtk); prioritas `DURATIONS` manual > otomatis > tunggu clone hilang (maks 120 dtk). `DUMP_CLONE_INFO` default mati. Asumsi: `Time` = detik menuju titik itu (sesuai nilai 3 dan 1,5); penyimpangan sedikit antara durasi hitung dan tampilan = sesuaikan `DURATION_MARGIN`/`DURATIONS`. Margin berarti ada jeda sangat singkat sebelum cutscene berikutnya (kamera bisa sempat kembali ke karakter).

Revisi 3 (tes Studio ketiga): urutan 1->4 jalan penuh dengan durasi otomatis, tetapi ada jeda panjang dan kamera kembali ke pemain di antara scene (tiap `PlayCutscene` = pemutaran terpisah yang dimulai dari kamera pemain dan melepas kamera di akhir). Keputusan: `MODE = "MERGED"` (default): titik `PositionN` dari semua modul digabung jadi satu `CutsceneInfo` (Position1..N berurutan, urut numerik) dan diputar SATU kali memakai `LocalCutscenePlayer` milik modul pertama, meniru isi `PlayCutscene` bawaan (info jadi anak LocalScript, parent ke PlayerGui, `Disabled = false`). Titik pertama scene ke-2 dst memakai `Time = SCENE_JOIN_TIME` (0,05) agar perpindahan berupa cut; nil = kamera terbang. Modul asli di ServerStorage tidak diubah (hanya salinan). Jatuh otomatis ke SEQUENTIAL bila LocalCutscenePlayer/CutsceneInfo tidak ada. Asumsi (belum terverifikasi): LocalCutscenePlayer semua modul identik (dipakai milik modul pertama); script membaca `CutsceneInfo` anak LocalScript dan memutar `PositionN` berurutan; `Time` titik pertama = waktu menuju titik itu. Loop tunggu diperhalus (tidur min(0.25, sisa)) agar tidak terlambat sampai 0,25 dtk.

Status:
ACCEPTED sebagai alat tes; BELUM lulus tes Studio (urutan berhenti di modul 1; perbaikan di atas belum dites).

