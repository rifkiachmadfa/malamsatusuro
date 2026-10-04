# CHANGELOG

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