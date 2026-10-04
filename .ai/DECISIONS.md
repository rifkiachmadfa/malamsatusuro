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