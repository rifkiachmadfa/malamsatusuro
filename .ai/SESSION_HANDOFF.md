# SESSION HANDOFF

Last Updated: 2026-10-11

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
3. Panel Quest hanya menampilkan KANTIL: judul "KEMBANG KANTIL HITAM" dengan satu baris "○ Kembali berbicara kepada Pemandu" (state RETRY_GUIDE; bukan Keris tercentang). Bunga di map hilang, makam kosong dan tanpa prompt.
4. Bicara ke Pemandu: dialog ulangi (Pemandu_KantilRetry, bukan dialog laporan Keris). Tamatkan dialog -> Output `menamatkan dialog ulangi; memulai ulang quest KANTIL`, state RETRY_GUIDE -> ACTIVE -> SEARCHING_FLOWERS, 4 bunga baru muncul acak, counter 0/4, panel Quest kembali ke "Cari 4 Bunga 0/4". Bicara ke Pemandu lagi sebelum/sesudahnya tidak memulai ganda.
5. Selesaikan quest dengan benar sampai Kembang Kantil Hitam: tidak ada sisa state lama (makam penuh/hadiah ganda).
6. Spam bunga salah beberapa kali cepat: hanya satu urutan gagal berjalan (tidak ada reset ganda/error).
7. Gagal di tengah (sebagian bunga sudah benar di makam): setelah reset, makam kosong dan semua mulai dari 0.
8. 2 pemain (Test > Clients 2): bunga salah -> pemain itu knock (BUKAN respawn); quest tidak direset. Pemain 2 keluar sehingga tersisa 1: bunga salah berikutnya = jalur solo.
Laporkan Output dan apakah panel Quest/dialog Pemandu terlihat benar setelah reset.

## Uji Studio Task 6.2 (jumpscare)
Prasyarat: ServerStorage/GhostModels/Pocong ada (Model R15 dengan Humanoid, Head, HumanoidRootPart). Animasi 121504540587696 harus milik akun/grup pemilik place (atau publik) agar bisa dimuat.
1. Play Solo. Output server saat boot: `[JumpscareService] 1 model hantu dipublikasikan ke client` lalu `siap`. Explorer saat Play: ReplicatedStorage/GhostModels/Pocong ada (tanpa script).
2. Uji cepat tanpa quest, Command Bar server: `require(game.ServerScriptService.Server.Services.JumpscareService).play(game.Players:GetPlayers()[1], "Pocong")`
   EXPECTED: kilat putih disertai suara placeholder (bass bawaan Roblox) hanya di pemain itu, Pocong melonjak ke depan layar dengan animasi, layar bergoyang, menggelap di akhir (~2 detik). Karakter diam selama itu (tidak bisa jalan), lalu bisa bergerak lagi. Tidak ada error di Output server/client.
3. Jika TIDAK ada suara: Output client mungkin memuat warn aset; ganti `soundId` di JumpscareConfig dengan rbxassetid:// milik Anda (placeholder ini belum diverifikasi AI). Jika Pocong membelakangi kamera: ubah `yawOffset = 180` di JumpscareConfig. Jika terlalu dekat/jauh: ubah distanceStartScale/distanceEndScale. Jika animasi tidak jalan: lihat warn `animasi jumpscare gagal dimuat` (biasanya izin aset).
4. Quest nyata, SOLO: bunga salah di makam -> jumpscare -> setelah selesai respawn dan quest 2 direset (lihat uji 6.1b langkah 2–8). Notifikasi "Kamu gagal..." muncul setelah respawn.
5. 2 pemain (Test > Clients 2): pemain 1 bunga salah -> jumpscare HANYA di layar pemain 1, pemain 2 tidak melihat apa pun dan masih bisa bergerak -> setelah itu pemain 1 knock (berbaring).
6. Spam bunga salah saat jumpscare berjalan: tidak ada jumpscare ganda/tumpuk, tidak ada error.
Laporkan: tampilan Pocong (arah, ukuran, animasi), durasi terasa pas atau tidak, dan Output.

## Uji Studio Task 6.3 (Knock UI minimal)
Butuh pemain knock: Test > Clients 2 (multiplayer), atau Command Bar server `require(game.ServerScriptService.Server.Services.KnockService).knock(game.Players:GetPlayers()[1], "TEST")` (solo).
1. EXPECTED saat knock: layar pemain itu menggelap perlahan (~0,4 detik) dengan bayangan di tepi, teks "KAMU PINGSAN" dan "Tunggu rekanmu menyadarkanmu dengan Minyak Zaitun." di tengah. Hotbar Roblox hilang. Pemain lain TIDAK melihat overlay.
2. Notifikasi (toast) tetap terlihat DI ATAS overlay. Jika jumpscare dipicu (bunga salah), jumpscare menutupi overlay lalu overlay terlihat setelah pemain jatuh knock.
3. `K.recover(p)` di Command Bar: overlay memudar dan hilang, hotbar muncul lagi, pemain bisa bergerak.
4. Reset karakter saat knock: overlay tetap tampil setelah respawn (state tetap KNOCKED).
5. Quest UI di kanan atas tetap bisa terbaca (overlay tidak menutup toast dan jumpscare; panel quest di bawah overlay boleh redup).
Laporkan: tampilan teks terbaca, tidak ada error client.

## Uji Studio Task 6.4 (Minyak Zaitun spawner + revive)
Prasyarat Studio: `Workspace.QuestObjects.ZaitunSpawns` berisi >= 3 Part/Model spawn; `ServerStorage.QuestTemplates.MinyakZaitun` (Tool) dengan Handle (Anchored=false, ada Part visual). Test > Clients 2 (minimal 2 pemain; revive butuh rekan). Lihat Output server dan client.
A. SPAWNER
1. EXPECTED: Output tepat setelah dialog intro selesai (KERIS masuk SEARCHING_KELOR, bersamaan dengan Kelor): `[CollectibleService] Zaitun aktif (2/N titik): ZaitunSpawn_x=MinyakZaitun, ZaitunSpawn_y=MinyakZaitun` (N = jumlah Part di folder). Hanya 2 pickup Minyak Zaitun di `Workspace.QuestRuntime`.
2. [E] Ambil di pickup: item "Minyak Zaitun" di Backpack, toast "Kamu mendapatkan Minyak Zaitun." (rekan: "<nama> mendapatkan ..."), TANPA angka (n/N), counter Bunga 0/4 tidak berubah. Pickup hilang. Ambil yang kedua: Backpack jadi "Minyak Zaitun x2" atau dua pemain masing-masing satu.
3. Zaitun TIDAK hilang saat quest Keris selesai atau Kantil dimulai: pickup yang belum diambil tetap ada dan bisa diambil kapan saja. Solo gagal / reset Kantil tidak men-spawn zaitun lagi dan tidak menghapusnya.
4. Spam [E] / 2 pemain [E] bersamaan di satu pickup: hanya satu yang mendapat item.
B. REVIVE (pemain A knock, pemain B penyelamat)
5. Knock A (bunga salah di makam saat 2 pemain, atau Command Bar server: `require(game.ServerScriptService.Server.Services.KnockService).knock(game.Players:GetPlayers()[1], "TEST")`).
6. B dekat A TANPA zaitun: prompt kecil "A pingsan / Butuh Minyak Zaitun" (tanpa [E]). B punya zaitun tapi tidak di-equip: "Pegang Minyak Zaitun". Tekan E: tidak terjadi apa-apa.
7. B equip zaitun: prompt jadi "Tahan [E] Sadarkan". Tahan E: progress bar terisi ~3 detik, Output `mulai menyadarkan`, lalu `menyadarkan`; A berdiri (state NORMAL), B toast "Kamu menyadarkan A. Sisa Minyak Zaitun: n." (stack x2 -> x1; x1 -> tool hilang).
8. Lepas E sebelum 3 detik: bar hilang, A tetap knock, zaitun TIDAK berkurang, Output `melepas tombol`. Tahan lagi dari awal berfungsi.
9. Menjauh > ~12 studs saat menahan: batal + toast "terlalu jauh". Un-equip / ganti tool saat menahan: batal + toast "pegang Minyak Zaitun". Reset karakter B saat menahan: batal, tidak ada error, B kembali NORMAL.
10. Dua penyelamat (B dan C) menahan pada A bersamaan: hanya satu sesi berjalan, yang kedua toast "sedang disadarkan rekan lain"; zaitun yang berkurang hanya satu.
11. Mobile (Device Emulator): tombol prompt bisa ditahan (jari ditahan), lepas = batal.
12. Prompt revive dan prompt interaksi lain (mis. makam) berdekatan: saat memegang bunga, prompt makam tetap berfungsi (E ke makam); saat memegang zaitun, E ke revive.
13. KNOCK A, B menyadarkan, A berjalan normal, bisa [E] lagi; A knock lagi lalu disadarkan lagi (tidak ada sisa state REVIVING/Anchored).
Laporkan Output (server dan client) dan perilaku yang berbeda dari EXPECTED.

## Uji Studio Revisi Zaitun (ADR-037)
Prasyarat: `Workspace.QuestObjects.ZaitunSpawns` berisi >= 6 Part/Model; template `MinyakZaitun` ada. Lihat Output server.
1. EXPECTED: setelah dialog intro, `[CollectibleService] Zaitun aktif (2/N titik): ...` dan hanya 2 pickup zaitun di `Workspace.QuestRuntime`.
2. Ambil 1 zaitun ([E]): pickup hilang dan SEGERA muncul 1 pickup baru. Output `Zaitun pengganti ter-spawn: <titik> (aktif 2/2)`; titik BUKAN titik yang pernah dipakai. Selalu ada 2 pickup di dunia.
3. Ulangi sampai titik habis: tiap pengganti di titik berbeda. Setelah N titik: warning `semua titik sudah pernah dipakai... (siklus baru)`; titik baru tidak sama dengan yang baru diambil / yang sedang aktif.
4. Spam [E] / 2 pemain bersamaan di satu pickup: item hanya masuk satu kali; pengganti hanya satu.
5. Kelor/bunga tidak berubah (tanpa pengganti). Revive (6.4) tetap jalan.
Laporkan Output dan jika ada pickup yang muncul di titik yang sama dua kali sebelum siklus baru.

## Uji Studio Phase 7 (gamelan ritme, ADR-038)
Prasyarat Studio: `Workspace.QuestObjects.Gamelan` (Model/Part); `ServerStorage.QuestTemplates.KainKafan` (Tool dengan Handle, Anchored=false). `GamelanConfig.SOUND_ID` boleh kosong (main tanpa suara) atau isi "rbxassetid://<id>". Test > Clients 2 (satu pemain bermain, satu mengamati).
Jalan pintas (Command Bar server) agar langsung ke quest Kafan tanpa memainkan Keris/Kantil:
```lua
local S = game.ServerScriptService.Server.Services
local Q = require(S.QuestService)
local C = require(game.ReplicatedStorage.Shared.Config.QuestConfig)
for _, id in { "KERIS", "KANTIL" } do
	local def = C.Quests[id]
	for i = 2, #def.states do Q.transition(id, def.states[i]) end
end
Q.activate("KAFAN"); Q.transition("KAFAN", "FIND_GAMELAN")
```
(Efek samping: service lain ikut bereaksi pada state itu, mis. spawn pickup; abaikan.) Alur normal: simpan Kantil di RitualCollection -> bicara ke Pemandu (Pemandu_KantilDone) -> quest Kafan mulai.
1. EXPECTED: di FIND_GAMELAN gamelan menampilkan prompt "[E] Mainkan Gamelan". Quest UI: "Cari tempat gamelan".
2. [E]: GUI ritme muncul (4 kolom, huruf Q W E R di bawah, SKOR kiri atas, waktu 1:37 kanan atas, tombol BATAL). Output server `sesi dimulai untuk <nama> (N not)`. Toast "Kamu mulai memainkan gamelan." / rekan: "<nama> mulai memainkan gamelan." Quest UI: objective pertama tercentang.
3. Musik: bila SOUND_ID diisi, musik mulai bersamaan dengan jam sesi; bila kosong, tidak ada suara tetapi not tetap jalan. Not pertama muncul ~3 detik setelah mulai.
4. PC: tekan Q W E R saat not tiba di garis putih. Karakter TIDAK berjalan saat W ditekan, tidak melompat, E tidak memicu interaksi lain. Mobile (Device Emulator): ketuk kolom. Mouse: klik kolom.
5. Umpan balik: PERFECT / GOOD / MISS di tengah, combo "xN", kolom berkedip saat ditekan, SKOR bertambah.
6. Setelah 1:37 (dan hitung mundur 0:00): layar "Menghitung skor...", lalu hasil. Skor >= 80: "KAIN KAFAN DIDAPAT", toast skor + "Kamu mendapatkan Kain Kafan. Simpan di tempat ritual." (rekan mendapat toast), item Kain Kafan di Backpack, Quest UI maju. Skor < 80: "SKOR TIDAK CUKUP (BUTUH 80)", toast skor, [E] gamelan tetap bisa diulang.
7. Pemain lain menekan [E] saat A bermain: toast "<A> sedang memainkan gamelan.", tidak ada sesi kedua. Pemain lain tidak melihat GUI A.
8. BATAL di tengah: GUI tutup, musik berhenti, karakter bisa bergerak lagi, tidak ada kain, bisa mulai ulang.
9. Reset karakter / knock di tengah sesi: GUI tutup, tidak ada hasil/hadiah, karakter normal.
10. Setelah dapat kain: [E] gamelan hilang; [E] Simpan di RitualCollection -> quest KAFAN COMPLETE (ritual 3/3).
11. Output server TANPA error; catat apakah terasa not terlambat/terlalu cepat terhadap musik (untuk menyetel BPM/LEAD_IN dan jendela waktu).
Laporkan Output (server dan client), skor yang didapat, dan perilaku yang berbeda dari EXPECTED (terutama sinkron suara-not di mobile).

## Langkah berikutnya
1. User: uji 2.1 di atas dan lapor Output; tinjau SkyboxInserter; siapkan naskah dialog Pemandu.
2. Task 2.2 Quest UI, Task 2.3 alur Pemandu -> quest.