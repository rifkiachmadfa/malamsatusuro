# AGENTS.md — Aturan untuk AI di repo ini

Project: MALAM SURO: DUSUN KELABU (Roblox, horor co-op 1–4 pemain, bahasa Indonesia).

## Sebelum mengerjakan apa pun
1. Baca seluruh `.ai/` (GAME_CONTEXT, CURRENT_STATE, TASKS, BUGS, DECISIONS, SESSION_HANDOFF).
2. Cek `git status`, branch aktif, dan `git log`.
3. Lihat `default.project.json` dan `src/`.
4. Jangan menganggap dokumentasi = kondisi aktual. Kondisi aktual = Git + source + Studio.

## Aturan inti
- Server-authoritative. Client hanya meminta, server memvalidasi dan memutuskan.
- Progres quest = party-wide. Inventory = per pemain.
- Kerjakan bertahap per fase (lihat TASKS.md). Jangan lompat fase tanpa alasan teknis.
- Jangan ubah sistem yang tidak terkait task aktif. Baca DECISIONS.md sebelum mengubah arsitektur.
- Jangan mengklaim "sudah dites" tanpa test nyata. Hasil test harus apa adanya.
- Script dikelola Rojo (`src/` -> Studio). Jangan membuat script duplikat langsung di Studio.
- Map dan objek Studio TIDAK ada di Git (lihat ADR-011). Objek yang belum ada = dependency, bukan alasan membuat pengganti.

## Aturan notifikasi (ADR-025)
- SEMUA pemberitahuan ke pemain lewat `NoticeService` (toast di client). Dilarang membuat toast/label/print/GUI notifikasi sendiri.
- Wajib ada notifikasi untuk: pemain atau rekan mendapat item, progres party (mis. Kelor 3/4), kunci/keris berpindah pemegang, knock, revive, party wipe, quest selesai, pemain keluar yang memengaruhi quest, dan penolakan aksi yang perlu penjelasan (mis. "Peti terkunci").
- Pakai `NoticeService.notifyParty(pelaku, "Kamu ...", "<nama> ...")` untuk kejadian pemain; `broadcast` untuk kejadian party; `send` untuk satu pemain.
- Teks Bahasa Indonesia, singkat, sebut nama pemain dan progres (n/N) bila relevan. Fitur baru (knock, revive, Kantil, Gamelan, ritual akhir) harus menyertakan notifikasi sejak awal.

## Aturan penyelesaian quest (ADR-026)
- Quest SELESAI saat item quest disimpan di `Workspace.QuestObjects.RitualCollection` (RitualCollectionService, daftar di RitualConfig), BUKAN saat bicara ke Pemandu.
- Pemandu hanya MELAPOR/memberi petunjuk (dialog). Jangan menaruh logika penyelesaian quest di dialog Pemandu.
- Item akhir: Keris Pusaka, Kembang Kantil Hitam, Kain Kafan. Phase 8 (ritual akhir) membaca status simpanan dari sini.

## Aturan DRY objective koleksi (ADR-027)
- Objective "kumpulkan N item di titik spawn acak" (Kelor, bunga, dan yang serupa) HANYA lewat `CollectibleService`, dikonfigurasi di `shared/Config/CollectionConfig.luau`. Jangan menyalin logika spawn/pickup/progres ke service quest.
- Objective koleksi baru = tambah entri di CollectionConfig (+ counter di QuestConfig + titik spawn di Workspace.QuestObjects). Perilaku yang belum didukung modul = perluas modul generik, bukan membuat salinan.
- Penyimpanan item akhir selalu lewat RitualCollection (ADR-026); notifikasi selalu lewat NoticeService (ADR-025).

## Alur task
AUDIT -> CURRENT STATE -> PLAN -> IMPLEMENT -> TEST -> DEBUG -> REVIEW DIFF -> UPDATE .ai/ -> COMMIT -> HANDOFF

## Setelah task selesai
Update CURRENT_STATE.md, TASKS.md, SESSION_HANDOFF.md. Bug belum selesai -> BUGS.md. Keputusan arsitektur -> DECISIONS.md.
