# SESSION HANDOFF

Last Updated: 2026-10-05

## Ringkasan
- Fase aktif: PHASE 4 — KERIS PUSAKA. Phase 2 selesai (1 dan 2 pemain); Phase 3 ItemService selesai. Task 4.1–4.2 (spawn + pickup Kelor) kode selesai, belum dites di Studio.
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

<<<<<<< HEAD
## Uji Quest UI satu-quest di Studio
1. Sebelum intro: panel tidak tampil. Setelah intro: hanya KERIS PUSAKA (4 objective), tanpa KANTIL/KAFAN.
2. Ubah state via Command Bar (server) untuk cek quest lain, mis. selesaikan KERIS lalu `QuestService.activate("KANTIL")`: panel hanya KEMBANG KANTIL HITAM.
3. Device Emulator: PC, tablet, HP landscape. Panel lebih kecil dari sebelumnya, teks terbaca, header bisa diketuk, tidak menimpa tombol menu Roblox.

=======
>>>>>>> fix: BUG-001 dialog Pemandu KELOR_COMPLETE; Task 4.3 serah-terima kunci acak
## Langkah berikutnya
1. User: uji 2.1 di atas dan lapor Output; tinjau SkyboxInserter; siapkan naskah dialog Pemandu.
2. Task 2.2 Quest UI, Task 2.3 alur Pemandu -> quest.