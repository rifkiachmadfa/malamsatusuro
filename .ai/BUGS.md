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
FIXED (kode diubah, BELUM VERIFIED di Studio)

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
Belum. Lihat "Uji Task 4.3" di SESSION_HANDOFF.

Affected Players:
1 / 2 / 3 / 4

Regression Risk:
Rendah. Tidak menyentuh pickup Kelor, QuestService, atau ItemService.

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