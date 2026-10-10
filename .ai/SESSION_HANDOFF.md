# SESSION HANDOFF

Last Updated: 2026-10-10

## Ringkasan
- Fase aktif: PHASE 5 — KEMBANG KANTIL HITAM (belum dimulai). Phase 1–4 selesai (Phase 4 dengan catatan: 3–4 pemain di Phase 10). Quest KERIS lengkap: Kelor -> kunci -> peti -> memory puzzle -> keris -> simpan di RitualCollection.
- Aturan wajib: semua notifikasi lewat NoticeService (ADR-025); quest selesai saat item disimpan di RitualCollection, Pemandu hanya melapor (ADR-026). Lihat AGENTS.md.
- Repo: github.com/rifkiachmadfa/malamsatusuro (folder lokal: D:\roblox\malam-satu-suro)
- `src/` berisi: shared (Config/GameConfig, Config/DialogueConfig, Util/Log, Util/Spatial, Util/Interactable, Remotes),
  server (Services/GameManager, SpawnService, InteractionService, DialogueService, init.server),
  client (Controllers/InteractionController, DialogueController, UI/Theme, init.client).
- QuestService ada tapi belum dipanggil siapa pun. Inventory = Backpack Tool (ADR-018).

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

## Uji Task 2.1 di Studio (Play Solo, Command Bar mode server)
```lua
local Q = require(game.ServerScriptService.Server.Services.QuestService)
print(Q.activate("KANTIL"))                 -- harus false (KERIS belum COMPLETE)
print(Q.activate("KERIS"))                  -- true; ReplicatedStorage.QuestState attribute KERIS_State = ACTIVE
print(Q.addProgress("KERIS","Kelor",1))     -- nil (state belum SEARCHING_KELOR)
print(Q.transition("KERIS","SEARCHING_KELOR"))
print(Q.addProgress("KERIS","Kelor",1), Q.addProgress("KERIS","Kelor",2), Q.addProgress("KERIS","Kelor",1)) -- 1 3 4
print(Q.getState("KERIS"))                  -- KELOR_COMPLETE
print(Q.addProgress("KERIS","Kelor",1))     -- nil (progres berlebih ditolak)
```
Cek juga Output: tag [QuestService] tanpa error, dan Attribute di ReplicatedStorage.QuestState berubah.

## Uji Task 2.3 di Studio
1. Play Solo, dekati Pemandu, tekan [E], klik Next sampai dialog habis.
2. Output harus menampilkan berurutan: `[GameFlowService] intro selesai oleh <nama>, memulai game`, `[GameManager] state game: LOBBY -> INTRO`, `INTRO -> QUEST_KERIS`, `[QuestService] state quest (KERIS): LOCKED -> ACTIVE`, `ACTIVE -> SEARCHING_KELOR`.
3. Cek ReplicatedStorage.GameState = QUEST_KERIS dan ReplicatedStorage.QuestState.KERIS_State = SEARCHING_KELOR.
4. Ulangi dialog: tidak boleh ada transisi baru. Tutup dialog di tengah (Close): game tidak boleh mulai.
5. Multi-pemain: 2 pemain menamatkan dialog hampir bersamaan, transisi hanya terjadi sekali.

## Uji Task 2.2 di Studio
1. Play Solo: sebelum bicara ke Pemandu, panel quest TIDAK boleh tampil.
2. Selesaikan dialog intro: panel muncul di kanan atas, di bawah menu Roblox: MALAM SURO, KERIS PUSAKA dengan "○ Kumpulkan Daun Kelor 0/4" dst, KANTIL dan KAFAN hanya 1 baris.
3. Bicara ke Pemandu lagi: dialog baru (kelor), bukan intro.
4. Command Bar (server): `local Q=require(game.ServerScriptService.Server.Services.QuestService); Q.addProgress("KERIS","Kelor",1)` -> panel berubah ke 1/4; sampai 4/4 baris jadi "✓" (abu-abu).
5. Klik header untuk minimize/maximize. Tes di Device Emulator (HP): tidak menimpa tombol menu Roblox, teks terbaca.
6. 2 pemain: progres sama di kedua layar.

## Uji Task 3.1 di Studio (Play Solo, Command Bar mode server)
```lua
local I = require(game.ServerScriptService.Server.Services.ItemService)
local p = game.Players:GetPlayers()[1]
print(I.give(p, "DaunKelor", 2), I.count(p, "DaunKelor"))   -- true 2; Backpack: satu Tool "Daun Kelor x2"
print(I.give(p, "DaunKelor"), I.count(p, "DaunKelor"))      -- true 3; tetap satu Tool, jadi x3
print(I.consume(p, "DaunKelor", 5))                          -- false (kurang), jumlah tetap 3
print(I.consume(p, "DaunKelor", 3), I.count(p, "DaunKelor")) -- true 0; Tool hilang
print(I.give(p, "Palsu"))                                    -- false
print(I.give(p, "KunciPeti"), I.give(p, "KunciPeti"))        -- true lalu false (unique), jika template ada
```
Cek juga: Output saat boot menulis `[ItemService] siap, tapi N/10 template belum ada ...` (daftar template yang belum dibuat);
equip Tool (klik slot) lalu `give` lagi: jumlah tetap menyatu di satu Tool; tidak bisa di-drop (tekan Backspace).
2 pemain: item pemain A tidak muncul di Backpack pemain B.

## Uji Task 4.1–4.2 di Studio
1. Play Solo, selesaikan dialog intro. Output: `[KerisQuestService] Kelor aktif (4/8 titik): KelorSpawn_a, ...`.
2. Di Explorer: `Workspace.QuestRuntime` berisi 4 Model `Pickup_KelorSpawn_N`, tiap model muncul di titik spawn-nya. Hanya 4 dari 8 titik yang punya Kelor.
3. Stop lalu Play lagi: set titik aktif harus berbeda (acak), ulangi 3 kali.
4. Dekati satu Kelor: prompt `[E] Ambil / Daun Kelor`. Tekan E: Kelor hilang, Backpack berisi "Daun Kelor", panel quest 1/4. Ambil semua: 4/4 (Backpack "Daun Kelor x4" jika satu pemain), centang di panel, sisa pickup tidak ada, state KERIS = KELOR_COMPLETE.
5. Spam E di satu Kelor: hanya 1 item dan +1 progres.
6. 2 pemain: A ambil 1, B ambil 2, A ambil 1: kedua layar menampilkan 4/4; Backpack A dan B terpisah.
7. Periksa tampilan: model Kelor tidak tenggelam ke tanah / tidak miring aneh (lapor jika ya).

## Uji Task 4.3 di Studio
Prasyarat: Tool `KunciPeti` (dengan Handle, atau RequiresHandle=false) di ServerStorage.QuestTemplates.
1. Kumpulkan Kelor 4/4. Panel: "Dapatkan Kunci dari Pemandu" belum tercentang.
2. Bicara ke Pemandu, tamatkan dialog. Output: `state quest (KERIS): KELOR_COMPLETE -> KEY_OBTAINED`, `[KerisQuestService] ... Kunci Peti diberikan ke <nama>`.
3. Backpack: "Daun Kelor" hilang di SEMUA pemain; "Kunci Peti" hanya di satu pemain.
4. Bicara ke Pemandu lagi: dialog Pemandu_KerisChest, tidak ada kunci kedua.
5. 2-4 pemain: ulangi beberapa kali, pemegang kunci harus bervariasi; dua pemain menamatkan dialog bersamaan = tetap satu kunci.
6. Pemegang kunci keluar (sebelum peti): kunci pindah ke pemain lain.
7. Tanpa template KunciPeti: Output warning, state tetap KELOR_COMPLETE, Kelor tidak terhapus.

## Uji Quest UI satu-quest di Studio
1. Sebelum intro: panel tidak tampil. Setelah intro: hanya KERIS PUSAKA (4 objective), tanpa KANTIL/KAFAN.
2. Ubah state via Command Bar (server) untuk cek quest lain, mis. selesaikan KERIS lalu `QuestService.activate("KANTIL")`: panel hanya KEMBANG KANTIL HITAM.
3. Device Emulator: PC, tablet, HP landscape. Panel lebih kecil dari sebelumnya, teks terbaca, header bisa diketuk, tidak menimpa tombol menu Roblox.

## Uji Studio 4.4–4.6 (peti, puzzle, keris)
Prasyarat: Tool `KunciPeti` dan `KerisPusaka` (Handle) di ServerStorage.QuestTemplates; `Workspace.QuestObjects.Chest` ada.
1. Selesaikan Kelor -> Pemandu: toast "Kamu memegang Kunci Peti" (pemegang) / "<nama> memegang Kunci Peti" (lainnya).
2. Pemain tanpa kunci mendekati peti: prompt "Buka" muncul, ditekan -> toast "Peti terkunci".
3. Pemegang kunci: buka peti -> overlay "INGAT URUTAN INI" 6 detik (5 suku kata), lalu "SUSUN URUTANNYA": ketuk token ke slot, ketuk slot untuk mengembalikan, PERIKSA.
4. Salah: "URUTAN SALAH", buka lagi -> urutan baru. Benar: "PETI TERBUKA", Keris ada di Backpack, kunci hilang, peti tak bisa dibuka lagi.
5. Saat satu pemain bermain, pemain lain buka peti -> toast "<nama> sedang membuka peti".
6. Pemegang keris bicara ke Pemandu: hanya petunjuk, keris TETAP di Backpack, quest belum selesai.
7. Pemegang keris ke `QuestObjects.RitualCollection`: prompt "Simpan" -> keris hilang, quest COMPLETE (semua tercentang), toast "Kamu menyimpan Keris Pusaka di tempat ritual (1/3)" untuk pelaku dan "<nama> menyimpan ..." untuk rekan. Non-pemegang menekan prompt: toast "tidak membawa benda ritual". Setelah itu Pemandu melapor (Pemandu_KerisDone).
8. Notifikasi: ambil Kelor -> pelaku "Kamu mendapatkan Daun Kelor (n/4)", rekan "<nama> mendapatkan ..."; 4/4 -> toast "Daun Kelor sudah lengkap. Kembali ke Pemandu." Toast beruntun menumpuk, tidak saling menimpa.
9. Device Emulator HP: tile terbaca, semua bisa diketuk. Tutup dengan BATAL: sesi berakhir, bisa coba lagi. Pemegang keluar game: kunci/keris pindah ke pemain lain.

## Uji Studio Phase 5 awal (flower collection) + regresi Kelor
Prasyarat: Workspace.QuestObjects.FlowerSpawns berisi 8 Part/Model (nama bebas); template MawarMerah, MawarPutih, Melati, KantilKuning.
1. REGRESI KELOR: mulai game, 4 Kelor muncul di titik acak, [E] Ambil memberi item, toast "Kamu mendapatkan Daun Kelor (n/4)", rekan melihat "<nama> mendapatkan ...", pickup hilang setelah diambil, 4/4 -> "Daun Kelor sudah lengkap". Alur kunci/peti/puzzle/ritual seperti sebelumnya.
2. Setelah keris disimpan di RitualCollection (KERIS COMPLETE): bicara ke Pemandu -> dialog laporan (3 baris) -> panel Quest berganti ke KEMBANG KANTIL HITAM "Cari 4 Bunga 0/4".
3. 4 bunga muncul di 4 dari 8 titik; keempat jenis berbeda (Mawar Merah, Mawar Putih, Melati, Kantil Kuning). Prompt "Petik" menampilkan nama jenisnya. Jalankan ulang beberapa kali: titik dan penempatan jenis berubah.
4. 2 pemain mengambil bunga bergantian: panel di kedua layar sama (n/4), toast "<nama> mendapatkan Mawar Merah (1/4)". Setelah 4/4: toast "Keempat bunga sudah terkumpul" dan Pemandu: "Bawalah ke makam".
5. Dua pemain menekan bunga yang sama bersamaan: hanya satu yang mendapat item.

## Uji Studio Task 5.7–5.8 (makam: placement + validasi)
Prasyarat: Workspace.QuestObjects.Graves berisi Grave_1..4 (Model/Part, SurfaceGui clue); template KembangKantilHitam; GravePuzzleConfig.ANSWER dicocokkan dengan clue. Output boot: `[GravePuzzleService] siap, 4/4 makam terdaftar` (dan warn PLACEHOLDER selama ANSWER_CONFIRMED=false).
1. Selesaikan sampai 4 bunga terkumpul (FLOWERS_COMPLETE). Keempat makam menampilkan prompt "Letakkan Bunga / Makam"; sebelum itu tidak ada prompt.
2. Tekan E tanpa bunga: toast "Kamu tidak membawa bunga". Bawa bunga tapi tidak di-equip: toast "Pegang bunga ...".
3. Equip satu bunga yang BENAR, E di makam: bunga hilang, toast (n/4) untuk pelaku dan rekan, prompt makam itu hilang. Output: state KANTIL FLOWERS_COMPLETE -> FLOWERS_PLACEMENT -> CANTIL_PUZZLE (puzzle berjalan sejak percobaan pertama).
4. Letakkan semua sesuai clue: state CANTIL_BLACK_OBTAINED, penempat terakhir memegang Kembang Kantil Hitam (toast), panel quest tercentang "Selesaikan teka-teki makam". Pemandu: dialog Pemandu_KantilStore. Simpan di RitualCollection menyelesaikan quest.
5. Bunga SALAH di sebuah makam: toast "<bunga> tidak cocok di makam ini!" (rekan: "<nama> meletakkan ... di makam yang salah!"), bunga TETAP di Backpack pemain itu, makam tetap kosong dan berprompt, bunga yang benar sebelumnya tetap di makam. Belum ada jumpscare/knock (Phase 6, ADR-030). Lanjutkan dengan bunga benar sampai selesai: tidak ada bunga yang hilang.
6. 2 pemain menekan E di makam yang sama bersamaan: hanya satu bunga terpakai. Pemain yang memegang bunga keluar: bunganya muncul di Backpack pemain lain.
7. Tanpa template KembangKantilHitam: bunga terakhir TIDAK terpakai, Output warn dependency.
8. Equip bunga lalu karakter freeze? Cek Handle.Anchored template (lihat catatan Daun Kelor).

## Uji Studio Task 6.1 (KnockService)
Server Command Bar (Play Solo, mode server). Prasyarat tidak ada; tidak perlu template baru.
```lua
local K = require(game.ServerScriptService.Server.Services.KnockService)
local p = game.Players:GetPlayers()[1]
print(K.knock(p, "TEST"))   -- true
```
1. EXPECTED knock: karakter berbaring telentang di lantai, tidak bisa jalan/lompat/berputar, tool yang dipegang terlepas, toast "Kamu pingsan ...", Output `[KnockService] <nama> knock (TEST)` dan `state pemain: NORMAL -> KNOCKED`, lalu `semua pemain knock (1/1)` (solo).
2. Prompt [E] tidak muncul saat knock (jaga: hidden di client, server menolak). Coba equip tool dari hotbar: langsung terlepas.
3. `print(K.knock(p, "TEST"))` lagi -> false (sudah KNOCKED), Output warn ditolak.
4. Tekan tombol Reset karakter (Esc > Reset): karakter baru muncul dan dikembalikan ke titik knock, tetap berbaring (Output "respawn saat knock").
5. `print(K.recover(p))` -> true: berdiri di tempat knock, bisa jalan/lompat normal, toast "Kamu sadar kembali". `print(K.recover(p))` lagi -> false.
6. Makam: setelah FLOWERS_COMPLETE letakkan bunga SALAH -> toast salah + toast pingsan, pemain berbaring. Ini hanya terjadi saat MULTIPLAYER (2+ pemain); solo lihat uji 6.1b. Set `FailureConfig.FAIL_ON_WRONG_FLOWER = false` untuk menonaktifkan hukuman.
7. 2 pemain (Test > Clients 2): knock pemain 1 -> pemain 2 tetap bisa bergerak, melihat pemain 1 berbaring, toast "<nama> pingsan!". Knock pemain 2 juga -> Output `semua pemain knock (2/2)`. Pemain 1 keluar saat knock: tidak ada error.
Laporkan: berbaringnya terlihat benar (tidak tenggelam/melayang/miring), serta Output/error.

## Uji Studio Task 6.1b (solo gagal = respawn + reset quest 2)
Play Solo (1 pemain). Jalankan sampai 4 bunga terkumpul (FLOWERS_COMPLETE).
1. EXPECTED: letakkan bunga SALAH di makam -> toast "bunga tidak cocok", toast "Kamu gagal. Kembali ke Pemandu ...". Pemain TIDAK berbaring/knock. Output: `[FailureService] solo gagal (WRONG_FLOWER, quest KANTIL)`, `state pemain: NORMAL -> CUTSCENE`.
2. Setelah ~1,5 detik: Output `quest direset (KANTIL): <state> -> LOCKED`, karakter respawn di titik spawn, `CUTSCENE -> NORMAL`, Backpack kosong dari bunga.
3. Panel Quest tidak lagi menampilkan KANTIL aktif (KANTIL LOCKED). Bunga di map hilang, makam kosong dan tanpa prompt.
4. Bicara ke Pemandu: dialog laporan (Pemandu_KerisDone). Tamatkan dialog -> Output `memulai quest KANTIL`, state LOCKED -> ACTIVE -> SEARCHING_FLOWERS, 4 bunga baru muncul acak, counter 0/4.
5. Selesaikan quest dengan benar sampai Kembang Kantil Hitam: tidak ada sisa state lama (makam penuh/hadiah ganda).
6. Spam bunga salah beberapa kali cepat: hanya satu urutan gagal berjalan (tidak ada reset ganda/error).
7. Gagal di tengah (sebagian bunga sudah benar di makam): setelah reset, makam kosong dan semua mulai dari 0.
8. 2 pemain (Test > Clients 2): bunga salah -> pemain itu knock (BUKAN respawn); quest tidak direset. Pemain 2 keluar sehingga tersisa 1: bunga salah berikutnya = jalur solo.
Laporkan Output dan apakah panel Quest/dialog Pemandu terlihat benar setelah reset.

## Langkah berikutnya
1. User: uji 2.1 di atas dan lapor Output; tinjau SkyboxInserter; siapkan naskah dialog Pemandu.
2. Task 2.2 Quest UI, Task 2.3 alur Pemandu -> quest.