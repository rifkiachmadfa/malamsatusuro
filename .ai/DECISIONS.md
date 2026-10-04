

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