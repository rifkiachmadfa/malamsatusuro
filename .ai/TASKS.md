# PROJECT TASKS

## HOW TO USE THIS FILE

Tasks are ordered by development priority.

Do not automatically implement every task.

Before starting a task:

1. inspect Git
2. inspect current state
3. inspect relevant code
4. inspect Roblox Studio when available
5. confirm dependencies
6. implement
7. test
8. update this file


# PHASE 0 — FOUNDATION AUDIT

Status:
REPOSITORY AUDIT DONE (2026-10-04) — Studio audit PENDING

- [x] Audit repository (1 commit, template Rojo)
- [x] Audit Rojo configuration (shared/server/client terpetakan)
- [ ] Audit Roblox Studio structure (butuh Explorer dari user)
- [x] Audit existing scripts (hanya template Hello)
- [ ] Audit RemoteEvents (belum ada di repo; Studio belum diperiksa)
- [ ] Audit current map (butuh Studio)
- [x] Identify missing systems (semua sistem gameplay belum ada)
- [ ] Identify broken systems (belum bisa dinilai tanpa Studio)
- [ ] Establish baseline


# PHASE 1 — FOUNDATION

Status:
IN PROGRESS

- [x] 1.1 Dokumentasi dasar (AGENTS.md, SESSION_HANDOFF.md, ADR-011/012)
- [ ] Multiplayer state foundation
- [x] 1.2 Strategi map: Git hanya script (ADR-011)
- [ ] Finalize Rojo project structure
- [ ] GameManager
- [ ] Basic game state
- [ ] Player spawn
- [ ] Pemandu NPC
- [ ] Basic interaction system
- [ ] Basic GUI foundation

# PHASE 2 — QUEST SYSTEM

Status:
NOT STARTED

- [ ] QuestService
- [ ] Quest configuration
- [ ] Party progression
- [ ] Quest state machine
- [ ] Quest synchronization
- [ ] Quest UI


# PHASE 3 — INTERACTION & INVENTORY

Status:
NOT STARTED

- [ ] InteractionService
- [ ] InventoryService
- [ ] Item configuration
- [ ] Server validation
- [ ] Anti-duplication
- [ ] Item collection


# PHASE 4 — KERIS PUSAKA

Status:
NOT STARTED

- [ ] Kelor spawn system
- [ ] Server randomization
- [ ] 4 active / 4 inactive
- [ ] Kelor collection
- [ ] Party progress
- [ ] Key acquisition
- [ ] Chest
- [ ] Memory puzzle
- [ ] Keris reward
- [ ] NPC submission
- [ ] Quest completion


# PHASE 5 — KEMBANG KANTIL HITAM

Status:
NOT STARTED

- [ ] Flower spawn system
- [ ] Server randomization
- [ ] Flower collection
- [ ] Party progress
- [ ] Grave clue
- [ ] Flower placement
- [ ] Puzzle validation
- [ ] Knock system
- [ ] Revive
- [ ] Party wipe
- [ ] Flower reset
- [ ] Black Kantil reward
- [ ] NPC submission


# PHASE 6 — KNOCK / REVIVE

Status:
NOT STARTED

- [ ] Knock state
- [ ] Knock UI
- [ ] Revive interaction
- [ ] Revive validation
- [ ] Party wipe detection
- [ ] Kantil-specific reset


# PHASE 7 — KAIN KAFAN / GAMELAN

Status:
NOT STARTED

- [ ] Gamelan interaction
- [ ] Rhythm UI
- [ ] Six columns
- [ ] Note system
- [ ] Input handling
- [ ] Score
- [ ] Score validation
- [ ] Retry
- [ ] Player completion
- [ ] All-player completion
- [ ] Reward
- [ ] NPC submission


# PHASE 8 — FINAL RITUAL

Status:
NOT STARTED

- [ ] Ritual requirements
- [ ] Item submission validation
- [ ] Party gathering
- [ ] Readiness tracking
- [ ] Pemandu sequence
- [ ] Dialogue
- [ ] Environment transition
- [ ] Cutscene
- [ ] Ending
- [ ] Game complete state


# PHASE 9 — HORROR POLISH

Status:
NOT STARTED

- [ ] Fog
- [ ] Lighting
- [ ] Environmental horror
- [ ] Audio
- [ ] Footsteps
- [ ] Whispers
- [ ] Horror events
- [ ] Limited jumpscares
- [ ] Environmental transitions


# PHASE 10 — MULTIPLAYER TESTING

Status:
NOT STARTED

- [ ] 1-player test
- [ ] 2-player test
- [ ] 3-player test
- [ ] 4-player test
- [ ] simultaneous interaction
- [ ] disconnect test
- [ ] reconnect test
- [ ] item duplication test
- [ ] invalid RemoteEvent test
- [ ] party progression test
- [ ] knock/revive test
- [ ] party wipe test
- [ ] final ritual test


# PHASE 11 — OPTIMIZATION

Status:
NOT STARTED

- [ ] Server performance
- [ ] Client performance
- [ ] RemoteEvent usage
- [ ] Memory
- [ ] Connections
- [ ] Loops
- [ ] Part count
- [ ] Particles
- [ ] Audio instances
- [ ] UI update frequency


# PHASE 12 — FINAL BUILD

Status:
NOT STARTED

- [ ] Full playthrough
- [ ] Multiplayer playthrough
- [ ] Security sanity check
- [ ] Performance check
- [ ] Cleanup
- [ ] Documentation
- [ ] Git review
- [ ] Release candidate