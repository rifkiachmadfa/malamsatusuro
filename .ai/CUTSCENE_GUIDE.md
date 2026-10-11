# CUTSCENE GUIDE — membuat scene kamera dan memutarnya (implementasi nyata)

Last Updated: 2026-10-11
Sumber: tes Studio user (Output ditempel) + ADR-041/042 (tes, kini dihapus) + ADR-043 (implementasi nyata).

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

## 5. Penamaan modul (ADR-043)

Cutscene join (ADR-041) dan trigger tes (ADR-042) sudah DIHAPUS, jadi `CutscenePlayerN` hanya berarti urutan scene ritual akhir (N = urutan). Daftar modul ada di `CutsceneConfig.MODULE_NAMES` (server/Config); mengganti nama modul di Studio = ubah daftar itu.

## 6. Implementasi nyata (SELESAI di kode, ADR-043; belum dites Studio)

- `server/Services/CutsceneService.play(participants): boolean` — logika MERGED hasil tes: gabung CutsceneInfo semua modul, satu pemutaran, durasi = jumlah `Time` + margin; yield sampai selesai; TIDAK mengubah state pemain; tidak pernah melempar error.
- `server/Config/CutsceneConfig` — `ENABLED`, `LAYOUT` (`PARALLEL` | `BEFORE_STEPS`), `FOLDER_NAME`, `MODULE_NAMES`, nama objek plugin, `DURATION_MARGIN`, `SCENE_JOIN_TIME`.
- Titik integrasi: `FinalRitualService.runSequence` membekukan pemain (state CUTSCENE) lalu memanggil `playSequence(participants)`: letterbox masuk -> kamera (PARALLEL: berjalan bersama subtitle; kartu TAMAT menunggu kamera selesai) -> kartu TAMAT -> `release`.
- Menambah scene: tambah modul OCE di ServerStorage/CutScenes lalu tambah namanya di `MODULE_NAMES`.

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

## 9. Alat debug

- Matikan kamera tanpa menghapus kode: `CutsceneConfig.ENABLED = false` (ritual tetap jalan dengan letterbox + subtitle).
- Ubah tata letak: `CutsceneConfig.LAYOUT = "BEFORE_STEPS"`.
- Kamera terbang mulus antar scene: `CutsceneConfig.SCENE_JOIN_TIME = nil`.
- Mengecek durasi hitung vs tampilan: lihat Output `[CutsceneService] memutar N scene ... (X.XXs)`; sesuaikan `DURATION_MARGIN` bila kamera kepotong/telat.
- Alat tes lama (`DUMP_CLONE_INFO`, `DURATIONS`, `MODE`) ikut dihapus bersama CutsceneTestService.
