# ARCHITECTURAL DECISIONS

This document records important project decisions.

AI MUST read this before proposing architectural changes.


## ADR-001 — ROJO

Decision:

The project uses Rojo for synchronization between source-controlled files and Roblox Studio.

Reason:

Luau source must be maintainable through VS Code and Git.

Status:
ACCEPTED


## ADR-002 — GIT AS TECHNICAL MEMORY

Decision:

Git/GitHub is the persistent technical history of the project.

Reason:

AI sessions may change.

The repository must remain the reliable implementation history.

Status:
ACCEPTED


## ADR-003 — SERVER AUTHORITATIVE GAMEPLAY

Decision:

Important gameplay state is controlled by the server.

Reason:

The game is multiplayer and important progression must not depend on client trust.

Status:
ACCEPTED


## ADR-004 — PARTY-WIDE QUEST PROGRESSION

Decision:

Quest progression is shared across the party.

Individual inventory remains player-specific.

Status:
ACCEPTED


## ADR-005 — MODULAR DEVELOPMENT

Decision:

The project is developed in phases.

A system must be tested before becoming a dependency for the next major system.

Status:
ACCEPTED


## ADR-006 — RANDOM SPAWN SERVER SIDE

Decision:

Quest randomization is controlled by the server.

Applies to:
- Kelor
- Flowers
- other gameplay-critical randomization

Reason:

Players must receive the same authoritative world state.

Status:
ACCEPTED


## ADR-007 — CLIENT REQUEST / SERVER VALIDATE

Decision:

Clients may request actions.

Server validates and executes important actions.

Status:
ACCEPTED


## ADR-008 — NO UNNECESSARY FRAMEWORK

Decision:

Do not introduce large frameworks unless they solve an actual project problem.

Prefer Roblox-native services and simple modular Luau architecture.

Status:
ACCEPTED


## ADR-009 — QUEST STATE MACHINE

Decision:

Major quest progression should use explicit states.

Reason:

Prevent invalid progression and make debugging easier.

Status:
ACCEPTED


## ADR-010 — DO NOT REWRITE UNRELATED SYSTEMS

Decision:

Feature work should remain scoped.

Unrelated refactoring requires explicit justification.

Status:
ACCEPTED


## ADR-011 — GIT HANYA UNTUK SCRIPT

Decision:

Git menyimpan script (Rojo `src/`) dan dokumentasi. Map, model, dan objek Studio tetap di place file lokal dan tidak masuk Git.

Consequences:

- Objek map tidak bisa diaudit dari repo; harus lewat Studio (tempel Explorer/Output atau MCP).
- Backup place file lokal dilakukan manual sebelum perubahan besar.
- Objek yang dibutuhkan tapi belum ada dicatat sebagai dependency, bukan dibuat sebagai pengganti.

Status:
ACCEPTED


## ADR-012 — AI TANPA MCP STUDIO (SEMENTARA)

Decision:

Saat ini AI bekerja tanpa Roblox Studio MCP. Verifikasi runtime dilakukan user dan dilaporkan ke AI.

Reason:

Pilihan user. MCP dapat dipertimbangkan lagi nanti (Studio built-in MCP + Claude Code).

Status:
ACCEPTED (dapat ditinjau ulang)



## ADR-013 — REMOTES LEWAT SATU MODUL

Decision:

Semua RemoteEvent dibuat oleh server lewat `Remotes.init()` (src/shared/Remotes.luau) dan diambil lewat `Remotes.get()`. Nama remote hanya didefinisikan di `Remotes.Names`.

Reason:

Mencegah nama remote tersebar sebagai string, dan menjaga boundary client-server tetap jelas dan tervalidasi (ADR-007).

Status:
ACCEPTED



## ADR-014 — GAME MANAGER DAN REPLIKASI STATE LEWAT ATTRIBUTE

Decision:

GameManager (src/server/Services/GameManager.luau) adalah satu-satunya pemilik state game dan state pemain. Transisi hanya lewat tabel yang eksplisit (ADR-009). State direplikasi ke client lewat Attribute (`ReplicatedStorage.GameState`, `Player.PlayerState`), bukan RemoteEvent.

Reason:

Attribute otomatis sampai ke pemain yang join belakangan dan tidak bisa diubah client untuk server. Aturan transisi pemain masih dasar dan akan ditinjau di Phase 6.

Status:
ACCEPTED



## ADR-015 — SPAWN LEWAT SPAWNLOCATION, SERVICE HANYA MEMERIKSA

Decision:

Titik spawn berupa SpawnLocation di Workspace.SpawnPoints (dibuat di Studio, tidak masuk Git). SpawnService (server) hanya memeriksa dependency dan mencatat posisi spawn; tidak memindahkan pemain.

Reason:

Mekanisme spawn bawaan Roblox sudah mendukung banyak pemain. Penugasan titik spawn per pemain (deterministik) baru dibuat bila terbukti perlu.

Status:
ACCEPTED