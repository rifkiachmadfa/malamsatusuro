# CHANGELOG

<<<<<<< HEAD
## 2026-10-05 — Quest UI: satu quest aktif + ukuran lebih kecil (belum dites di Studio)
- QuestView: hanya quest berjalan yang tampil (getCurrentQuestId); quest LOCKED/berikutnya disembunyikan; quest selesai hilang saat quest berikutnya aktif
- QuestController: lebar 210 px, teks 13/14, header 32 px, UIScale mengikuti tinggi layar (0.85–1.0)
- Verifikasi AI: luau-compile OK; tes offline QuestView 6/6 skenario. Tidak ada tes Studio

=======
>>>>>>> fix: BUG-001 dialog Pemandu KELOR_COMPLETE; Task 4.3 serah-terima kunci acak
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