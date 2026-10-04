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
- Kafan: PLAYER_SCORE / SCORE>=80 / PLAYER_COMPLETE dari GDD adalah state PER PEMAIN (Phase 7), bukan state party. State party Kafan: FIND_GAMELAN -> GAMELAN_ACTIVE -> ALL_PLAYER_COMPLETE -> KAIN_OBTAINED -> KAIN_SUBMITTED -> COMPLETE.
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



## ADR-023 — PICKUP DUNIA = MODEL DARI TEMPLATE; RANDOMSPAWNSERVICE GENERIK + SERVICE PER QUEST

Decision:

- `RandomSpawnService` (server) generik: `pickSpawns` (pilih N titik berbeda, acak di server) dan `createPickup` (buat Model statis dari isi Tool template: Script dibuang, semua BasePart Anchored/CanCollide=false/CanTouch=false, PrimaryPart = Handle, di-pivot ke CFrame titik spawn, diberi tag Interactable + Attribute). Pickup dibuat di `Workspace.QuestRuntime` (folder dibuat server saat runtime, tidak masuk Git).
- Logika per quest ada di service quest sendiri. `KerisQuestService` menangani Kelor sekarang (peti/kunci/puzzle/penyerahan menyusul) dan dipakai ulang polanya oleh quest Kantil.
- Jumlah Kelor aktif = `target` counter Kelor di QuestConfig (satu sumber kebenaran).
- Spawn dipicu `QuestService.onStateChanged` (masuk SEARCHING_KELOR), dibersihkan saat keluar dari state itu.
- Pickup: tabel server `pickups[model] = {status}` dengan AVAILABLE -> COLLECTING -> COLLECTED. Diterima hanya jika objek terdaftar, status AVAILABLE, dan quest di SEARCHING_KELOR. Urutan: give item -> addProgress; jika addProgress ditolak, item dibatalkan (consume) dan pickup kembali AVAILABLE.
- Titik spawn (KelorSpawn_N) hanya penanda; service tidak mengubah/menyembunyikannya. Model muncul dengan orientasi dan pusat titik spawn.

Status:
ACCEPTED (menunggu uji Studio, Task 4.1–4.4)
