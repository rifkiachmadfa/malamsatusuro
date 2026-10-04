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

## Alur task
AUDIT -> CURRENT STATE -> PLAN -> IMPLEMENT -> TEST -> DEBUG -> REVIEW DIFF -> UPDATE .ai/ -> COMMIT -> HANDOFF

## Setelah task selesai
Update CURRENT_STATE.md, TASKS.md, SESSION_HANDOFF.md. Bug belum selesai -> BUGS.md. Keputusan arsitektur -> DECISIONS.md.