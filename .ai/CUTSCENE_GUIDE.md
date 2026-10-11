# CUTSCENE GUIDE — membuat scene kamera dan memutarnya (implementasi nyata)

Last Updated: 2026-10-11
Sumber: tes Studio user (Output ditempel) + ADR-041 (cutscene join) + ADR-042 (trigger tes, mode MERGED).

Legenda status: **[TERBUKTI]** = terlihat di Output Studio. **[DILAPORKAN]** = user melapor berhasil, tanpa Output. **[ASUMSI]** = belum diverifikasi.

---

## 1. Ringkasan cara kerja

- Scene kamera dibuat user dengan plugin **Open Cutscene Editor** (OCE). Hasilnya satu `ModuleScript` per scene di `ServerStorage/CutScenes/` (objek Studio, tidak ada di Git, ADR-011).
- Server TIDAK mengirim data kamera. Kamera dijalankan sepenuhnya di client oleh `LocalCutscenePlayer` (LocalScript dari plugin). Server hanya memutuskan KAPAN memutar dan untuk SIAPA.
- Plugin TIDAK memberi sinyal "selesai" ke server. **[TERBUKTI]** clone `LocalCutscenePlayer` tidak menghilang sendiri setelah cutscene selesai.

## 2. Struktur modul scene (hasil OCE) **[TERBUKTI]**

```
ServerStorage/CutScenes/<NamaScene>        (ModuleScript, punya function PlayCutscene(player))
├── LocalCutscenePlayer                    (LocalScript, Disabled = true; pemutar kamera)
└── CutsceneInfo                           (Folder)
    ├── Position1                          (CFrameValue = posisi kamera)
    │   ├── Time                           (NumberValue, detik MENUJU titik ini)
    │   ├── EasingStyle                    (StringValue, mis. Linear)
    │   └── EasingDirection                (StringValue, mis. Out)
    ├── Position2 ...
```

`PlayCutscene(player)` bawaan: clone `LocalCutscenePlayer`, clone `CutsceneInfo` jadi ANAK clone itu, parent ke `PlayerGui`, lalu `Disabled = false`.

**Durasi scene = jumlah semua `Time`.** Contoh: Position1 = 3, Position2 = 1.5 -> 4,5 detik. **[TERBUKTI]** Waktu tunggu server 4,75 detik (4,5 + margin 0,25) cocok dengan tampilan.

## 3. Dua temuan penting dari tes

1. **Memanggil `PlayCutscene` modul demi modul menghasilkan jeda dan kamera kembali ke pemain di antara scene. [TERBUKTI]** Tiap pemutaran dimulai dari kamera pemain dan melepas kamera di akhir. Ini perilaku plugin, bukan bug server.
2. **Solusi: mode MERGED (ADR-042). [DILAPORKAN]** Titik `PositionN` semua scene digabung jadi satu `CutsceneInfo` (Position1..N berurutan) dan diputar SATU kali memakai `LocalCutscenePlayer` modul pertama. Titik pertama scene ke-2 dst diberi `Time = SCENE_JOIN_TIME` (0,05) supaya perpindahan berupa cut. Modul asli tidak diubah (hanya salinan).

## 4. Membuat scene baru (langkah)

1. Buka OCE, buat scene di Studio, simpan sebagai ModuleScript di `ServerStorage/CutScenes/`.
2. Beri nama sesuai peran (lihat bagian 5 soal bentrok nama). Satu scene = satu modul = satu rangkaian `PositionN`.
3. Setiap titik wajib punya `Time` (NumberValue, > 0). Titik tanpa `Time` tidak dihitung dalam durasi otomatis.
4. Jaga tiap scene tetap pendek dan berdiri sendiri; urutan antar scene ditentukan nama/daftar di config, bukan di dalam modul.
5. Bila scene akan DIGABUNG: semua modul harus memuat `LocalCutscenePlayer` yang sama (yang dipakai hanya milik modul pertama) **[ASUMSI]**. Jangan ubah script pemutar di satu modul saja.
6. Hindari lebih dari 9 titik per rangkaian gabungan sampai urutan Position di script plugin dipastikan numerik **[ASUMSI]** (penggabungan kita mengurutkan numerik dan menamai Position1..N, tetapi cara script plugin mengurutkan belum diperiksa).
7. Tes: nyalakan `DUMP_CLONE_INFO` di `CutsceneTestConfig` untuk melihat isi clone di Output; cek durasi hitung vs tampilan; sesuaikan `DURATION_MARGIN` / `DURATIONS` bila meleset.

## 5. PERHATIAN: bentrok nama dengan cutscene join

`CutscenePlayerN` dipakai dengan DUA arti:
- ADR-041 (`IntroCutsceneService`): N = **slot pemain** (pemain ke-N memutar modul ke-N, paralel).
- ADR-042 (`CutsceneTestService`, mode MERGED): N = **urutan scene**, semua diputar untuk semua pemain.

Keduanya membaca folder dan nama yang sama, jadi trigger tes memutar modul yang sama dengan cutscene join. Untuk implementasi nyata ritual akhir, **buat set modul terpisah** (mis. folder `ServerStorage/CutScenes/Ending/` berisi `Scene1..N`, atau prefix `EndingScene`) dan buat daftarnya di config baru. Jangan memakai ulang `CutscenePlayerN` untuk ending.

## 6. Rencana implementasi nyata (Phase 8, BELUM dikerjakan)

Titik integrasi: `FinalRitualService.runSequence` -> `playSequence` (state ENDING, semua pemain sudah `freeze` ke state CUTSCENE + WalkSpeed 0, lalu `release` + `GAME_COMPLETE`).

Usulan bertahap:
1. Ekstrak logika dari `CutsceneTestService` (`buildMergedInfo`, `playMerged`, `waitForClones`) menjadi service server permanen, mis. `CutsceneService.play(participants, sceneConfig)` yang **yield sampai selesai** dan TIDAK mengubah state pemain (pemanggil yang `freeze`/`release`, supaya tidak ada dua pemilik state).
2. Config scene (mis. `CutsceneConfig`): nama folder, daftar modul berurutan, `SCENE_JOIN_TIME`, `DURATION_MARGIN`, `DURATIONS` (override).
3. Panggil dari `FinalRitualService.playSequence` di dalam `pcall` yang sudah ada. Pilih satu: **serial** (kamera dulu, lalu subtitle/ending) atau **paralel** (`task.spawn` kamera sambil langkah subtitle jalan; selaraskan durasi `FinalRitualConfig.Sequence` dengan total Time). Serial paling sederhana dan paling aman.
4. Jangan menumpuk UI: letterbox/subtitle `FinalRitualController` dan kamera plugin berjalan di client yang sama; uji agar tidak saling menimpa. Transisi Lighting (`Ritual` -> `Fajar`) tidak terpengaruh kamera.
5. Hapus trigger tes sebelum publish: `CutsceneTestService.luau`, `CutsceneTestConfig.luau`, dua baris di `init.server.luau`, dan objek `Workspace.triggerCutscene`.

## 7. Aturan wajib (selaras AGENTS.md)

- Server memutuskan mulai dan selesai; client tidak melapor "cutscene selesai" untuk gameplay.
- Semua pemakaian state `CUTSCENE` harus dipulihkan di jalur error: bungkus dengan `pcall` dan selalu `release`, supaya pemain tidak terkunci.
- Pemain yang keluar saat cutscene: cek `player.Parent == Players` sebelum menyentuh state/PlayerGui.
- Pemain KNOCKED/REVIVING jangan dipaksa ke CUTSCENE (transisi GameManager hanya dari NORMAL). `FinalRitualService` memulihkan knock saat ritual dibuka.
- Notifikasi pemain hanya lewat `NoticeService` (ADR-025). Log lewat `Log`.

## 8. Risiko dan hal yang belum diketahui

- **[ASUMSI]** `LocalCutscenePlayer` identik di semua modul; script membaca `CutsceneInfo` anaknya dan memutar `PositionN` berurutan; `Time` titik pertama = waktu menuju titik itu.
- Hasil mode MERGED hanya dilaporkan user ("bagus"), tanpa Output; rincian visual (cut vs terbang, kamera akhir) belum dicatat.
- Kamera tidak kembali ke karakter secara halus di akhir: perilaku script plugin saat selesai belum diperiksa (bisa snap ke karakter).
- Pemain yang bergabung saat cutscene berlangsung tidak ikut memutar (peserta ditentukan saat dimulai).
- Plugin tidak mendukung audio/dialog di `CutsceneInfo`; musik/suara/subtitle perlu timeline sendiri (server memutar suara atau client lewat `CutsceneUpdate`).
- Durasi dihitung dari `Time`; jika script plugin menambah jeda internal, tampilan bisa lebih panjang dari hitungan (naikkan margin atau isi `DURATIONS`).
- Respawn/mati saat cutscene: script plugin menonaktifkan state mati hanya bila memang dibuat begitu **[ASUMSI]**; belum diuji.

## 9. Alat debug (sementara, CutsceneTestConfig)

- `MODE = "SEQUENTIAL"` = perilaku lama (satu pemutaran per modul, ada jeda).
- `DUMP_CLONE_INFO = true` = cetak isi clone ke Output.
- `DURATIONS = { NamaModul = detik }` = paksa durasi satu modul.
- `SCENE_JOIN_TIME = nil` = kamera terbang mulus antar scene (bukan cut).
- Hanya aktif di Studio (`ONLY_IN_STUDIO`).
