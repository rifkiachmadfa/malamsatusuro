# BUG TRACKER

## STATUS DEFINITIONS

OPEN
INVESTIGATING
FIXED
VERIFIED
WONT_FIX


# ACTIVE BUGS

## BUG-001 — Dialog Pemandu tidak muncul/buntu setelah Kelor 4/4

Status:
VERIFIED (user melaporkan alur Kelor -> kunci berjalan di Studio, 2026-10-05)

Severity:
HIGH (quest Keris tidak bisa lanjut)

System:
GameFlowService / KerisQuestService / DialogueConfig

Steps to Reproduce:
Kumpulkan 4 Kelor sampai state KERIS = KELOR_COMPLETE, lalu bicara ke Pemandu.

Expected:
Pemandu memberi kunci, Kelor di semua Backpack dihapus, kunci jatuh ke satu pemain acak.

Actual:
Tidak ada dialog; quest berhenti di KELOR_COMPLETE.

Root Cause:
GameFlowService.getPemanduDialogueId hanya memetakan SEARCHING_KELOR. KELOR_COMPLETE tidak punya dialog dan tidak ada handler serah-terima kunci (Task 4.3 belum dibuat).

Fix:
Peta state->dialog (KERIS_DIALOGUES), dialog Pemandu_KerisKey, handOverKey di KerisQuestService.

Verification:
Dilaporkan lulus oleh user (2026-10-05); uji 3–4 pemain di Phase 11.

Affected Players:
1 / 2 / 3 / 4

Regression Risk:
Rendah. Tidak menyentuh pickup Kelor, QuestService, atau ItemService.

## BUG-002 — Party wipe tidak punya kode (Task 6.5 tertulis selesai)

Status:
OPEN (temuan audit kode 2026-10-17; belum direproduksi di Studio)

Severity:
HIGH (multiplayer: semua pemain knock = party buntu)

System:
KnockService / ReviveService / GravePuzzleService / QuestConfig

Steps to Reproduce:
Multiplayer, semua pemain knock (mis. 2 pemain gagal di makam Kantil, atau diserang hantu).

Expected:
TASKS Task 6.5 / ADR-031/032: semua knock = party wipe (CANTIL_PUZZLE -> SEARCHING_FLOWERS, makam kosong, bunga direset).

Actual:
Pencarian kode: `KnockService.onAllKnocked` TIDAK punya pendengar di mana pun; tidak ada kode yang memanggil transisi wipe. Hanya komentar yang menyebut party wipe. Tanpa Minyak Zaitun/rekan berdiri, pemain tidak bisa pulih.

Root Cause:
Pendengar `onAllKnocked` tidak pernah dipasang (kemungkinan tertinggal saat Task 6.5). Belum diverifikasi di Studio.

Fix:
Belum dikerjakan (di luar scope Phase 9 Kuntilanak). Mitigasi hantu: pemain terakhir berdiri tidak di-knock oleh hantu (ADR-048).

Verification:
-

Affected Players:
2 / 3 / 4 (solo memakai jalur FailureService sendiri)

Regression Risk:
Sedang: menyentuh GravePuzzleService/QuestService/CollectibleService reset.

## Risiko diketahui (belum bug terkonfirmasi)
- Pemegang kunci mati/respawn: Backpack reset, kunci hilang (ADR-018, dibahas Phase 5/6). Pemegang keluar game sudah ditangani.
- src/server/Services/PemanduService.luau adalah kode mati (tidak di-require, mengacu QuestConfig.Order/def.pemandu yang tidak ada). Usul: hapus setelah disetujui.

Do not add speculative bugs.


# BUG TEMPLATE

## BUG-XXX

Status:
OPEN

Severity:
LOW / MEDIUM / HIGH / CRITICAL

System:

Description:

Steps to Reproduce:

Expected:

Actual:

Root Cause:

Fix:

Verification:

Affected Players:
1 / 2 / 3 / 4

Regression Risk:


# RULES

A bug must be reproducible whenever possible.

Do not mark a bug FIXED merely because code was changed.

Use VERIFIED only after the fix has been tested.

Critical bugs affecting:
- multiplayer progression
- item duplication
- quest state
- RemoteEvent security
- party wipe
- final progression

must be prioritized over cosmetic bugs.