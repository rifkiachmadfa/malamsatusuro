# MALAM SURO: DUSUN KELABU
# GAME CONTEXT

## 1. IDENTITAS

Title:
Malam Suro: Dusun Kelabu

Platform:
Roblox

Genre:
Horror + Adventure + Puzzle + Co-op

Players:
1–4 players

Perspective:
Third Person

Language:
Indonesian

Core Experience:
Exploration + Cooperation + Puzzle + Horror + Story


## 2. CORE GAME LOOP

Player enters the village.

→ Meets Pemandu
→ Receives quest
→ Explores the village
→ Collects required items
→ Solves puzzles
→ Obtains ritual item
→ Submits item to Pemandu
→ Unlocks next quest
→ Completes all required quests
→ Performs final ritual
→ Party gathering
→ Ending


## 3. CORE DESIGN PRINCIPLE

The game is NOT primarily a combat game.

The primary experience is:

- exploration
- cooperation
- puzzle solving
- atmosphere
- horror
- story progression

Combat should not become the dominant gameplay loop unless explicitly approved.


## 4. PLAYER COUNT

The game must support:

1 player
2 players
3 players
4 players

Multiplayer must be considered from the beginning.

Do not design systems as single-player first and "add multiplayer later."


## 5. PARTY PROGRESSION

Quest progression is PARTY-WIDE.

Example:

Player A collects 1 item.
Player B collects 2 items.
Player C collects 1 item.

Party progress becomes:

4/4

It does NOT become separate personal progress.

Individual inventory and shared quest progression are different concepts.


## 6. MAIN QUEST FLOW

LOBBY
→ INTRO
→ QUEST KERIS
→ QUEST KANTIL
→ QUEST KAFAN
→ FINAL RITUAL
→ ENDING
→ GAME COMPLETE


## 7. QUEST 01 — KERIS PUSAKA

Gameplay:
Exploration + Collection + Memory Puzzle

Kelor:
8 possible spawn locations.

Each run:
4 active
4 inactive

Flow:

SEARCH KELOR
→ COLLECT 4 KELOR
→ OBTAIN KEY
→ OPEN CHEST
→ MEMORY PUZZLE
→ OBTAIN KERIS
→ SUBMIT KERIS
→ QUEST COMPLETE


## 8. QUEST 02 — KEMBANG KANTIL HITAM

Gameplay:
Exploration + Item Matching + Horror Survival + Revive

Flower spawn:
8 possible locations.

Each run:
4 active flowers.

Flower types:

- Mawar Merah
- Mawar Putih
- Melati
- Kantil Kuning

Flow:

SEARCH FLOWERS
→ COLLECT 4 FLOWERS
→ GO TO GRAVE
→ READ CLUE
→ PLACE FLOWERS
→ SOLVE PUZZLE
→ OBTAIN KEMBANG KANTIL HITAM
→ SUBMIT
→ QUEST COMPLETE


Failure:

Puzzle failure
→ Player Knocked
→ Another Player Revives
→ Try Again

If all players are knocked:

PARTY WIPE
→ Reset Kantil flower-search mechanism
→ Continue


## 9. QUEST 03 — KAIN KAFAN

Gameplay:
Rhythm Game / Gamelan

Flow:

FIND GAMELAN
→ PLAY GAMELAN
→ RHYTHM GAME
→ SCORE >= 80
→ PLAYER COMPLETE

Each player must achieve the required score.

Example:

Player A = 92 ✓
Player B = 88 ✓
Player C = 73 ✗
Player D = 95 ✓

Only Player C needs another attempt.

When all players complete:

→ KAIN KAFAN
→ SUBMIT
→ QUEST COMPLETE


## 10. FINAL RITUAL

Requirements:

Keris Pusaka submitted
Kembang Kantil Hitam submitted
Kain Kafan submitted

Then:

FINAL RITUAL
→ PARTY GATHERING
→ Pemandu sequence
→ Dialogue
→ Environment changes
→ Cutscene
→ Ending


## 11. INTERACTION STYLE

Core interaction uses:

[E] Ambil
[E] Buka
[E] Gunakan
[E] Mainkan
[E] Baca
[E] Serahkan
[E] Revive

Interactions should use a reusable architecture rather than unrelated implementations for every object.


## 12. IMPORTANT ITEMS

- Daun Kelor
- Kunci Peti
- Keris Pusaka
- Mawar Merah
- Mawar Putih
- Melati
- Kantil Kuning
- Kembang Kantil Hitam
- Minyak Zaitun
- Kain Kafan


## 13. QUEST UI

Quest UI is located at the top-right.

It communicates:

- current quest
- current objective
- progress
- completed objective
- pending objective

Example:

MALAM SURO

KERIS PUSAKA
✓ Kumpulkan Daun Kelor 4/4
✓ Dapatkan Kunci
○ Buka Peti
○ Serahkan Keris


## 14. HORROR DIRECTION

Horror should primarily come from:

- atmosphere
- environmental storytelling
- sound
- lighting
- fog
- empty houses
- strange events
- silhouettes
- footsteps
- distant sounds
- environmental changes

Jumpscares should be limited.

Do not rely on constant jumpscares.


## 15. TECHNICAL PRINCIPLES

Server-authoritative multiplayer.

Server controls important gameplay state.

Client controls presentation and input.

Client REQUESTS.
Server VALIDATES.
Server DECIDES.

Never trust client declarations for:

- quest completion
- inventory rewards
- item collection
- score
- puzzle completion
- revive
- final progression


## 16. DEVELOPMENT PRINCIPLE

Build incrementally.

SYSTEM
→ TEST
→ FIX
→ INTEGRATE
→ MULTIPLAYER TEST
→ NEXT SYSTEM

Do not build all systems simultaneously.


## 17. SOURCE OF TRUTH

Design:
GDD

Technical implementation:
Git repository

Live Roblox state:
Roblox Studio

AI conversation:
Temporary context only

The AI must never assume that previous conversation history represents the current implementation.


## 18. CURRENT DEVELOPMENT TOOLCHAIN

Operating System:
Windows

Engine:
Roblox Studio

Code:
Luau

Project synchronization:
Rojo

Version control:
Git / GitHub

AI:
Claude Project + other AI clients when appropriate

AI project memory:
.ai/


## 19. IMPORTANT RULE

Before implementing any task:

READ THE CURRENT REPOSITORY.

Do not code based solely on this file.

This file describes the intended game.

The repository describes what actually exists.