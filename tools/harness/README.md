# Harness offline (Phase 9, ADR-048)

Menjalankan modul ASLI repo (QuestService, CollectibleService, GhostService, Ghosts/Kuntilanak, FailureService,
GameManager, semua Config) di atas mock Roblox minimal, memakai `luau` CLI. BUKAN pengganti tes Studio.

    python3 tools/harness/gen.py . /path/ke/luau            # suite normal
    python3 tools/harness/gen.py . /path/ke/luau M1 M2 ...  # mutation test: HARUS ada tes yang gagal

Mutasi M1..M7 merusak satu aturan kunci (perlindungan rekan, perampasan Kelor, kebijakan pemain terakhir,
syarat pembawa, pengurangan progres, state 4/4, status NORMAL). Mutasi yang lolos = tes kurang kuat.
Yang dimock: Notice/Jumpscare/Knock/Item/Interaction/RandomSpawn. Perilaku Roblox nyata (Touched, replikasi,
animasi, jarak nyata, lag) TIDAK tercakup.
