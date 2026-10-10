# CHANGELOG

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