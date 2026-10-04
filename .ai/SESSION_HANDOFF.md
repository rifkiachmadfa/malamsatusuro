# SESSION HANDOFF

Last Updated: 2026-10-04

## Ringkasan
- Fase: Phase 2 SELESAI DENGAN CATATAN (T7-T9 belum dites). Siap masuk PHASE 3.
- Repo: github.com/rifkiachmadfa/malamsatusuro (lokal: D:\roblox\malam-satu-suro)
- AI tanpa MCP Studio. AI hanya melihat GitHub dan file yang dikirim; hasil test ditempel user.
- Git hanya untuk script; map/objek Studio ada di place file lokal (ADR-011).
- Alur kerja disepakati: AI audit repo -> rencana + pertanyaan -> user setuju -> kode -> user tes -> catat apa adanya.

## File src/ saat ini
shared: Config/{GameConfig, QuestConfig, DialogueConfig}, Util/{Log, Spatial, Interactable}, Remotes
server: init.server, Services/{GameManager, SpawnService, InteractionService, DialogueService, QuestService, PemanduService}
client: init.client, Controllers/{InteractionController, DialogueController, QuestController}, UI/Theme

## Pola yang harus diikuti
- Objek interaktif: tag `Interactable` + `InteractionId`; `InteractionService.register(id, handler)` (ADR-016).
- Progres quest HANYA lewat QuestService (advance/addProgress/reset). Jangan set state quest di tempat lain (ADR-018).
- Service lain bereaksi ke quest lewat `QuestService.onStateChanged(fn)`.
- Remote baru: tambah di `Remotes.Names`; validasi semua payload di server (ADR-013).
- GUI lewat kode client + `UI/Theme` (ADR-017). Quest UI membaca Attribute `QuestSnapshot` (ADR-019).
- Inventory (Phase 3) = per pemain. Progres quest = party. Jangan dicampur.

## Untuk Phase 3 (belum dikerjakan)
Pertanyaan yang harus dijawab user sebelum kode:
1. DaunKelor: Model atau Part? Sudah punya PrimaryPart / ProximityPrompt / tag / attribute? (kirim screenshot)
2. Inventory perlu UI (hotbar sederhana) atau cukup notifikasi "Mendapat Daun Kelor"?
3. Kunci dan Keris dimiliki satu pemain atau dibawa party?
4. Kelor dan bunga: item masuk inventory pemain dulu, atau langsung menambah counter party saat diambil?
Catatan desain awal: pengambilan item memakai state AVAILABLE -> COLLECTING -> COLLECTED di server (anti-duplikasi);
ItemConfig memuat 10 item (Daun Kelor, Kunci Peti, Keris Pusaka, Mawar Merah, Mawar Putih, Melati, Kantil Kuning,
Kembang Kantil Hitam, Minyak Zaitun, Kain Kafan). Serah-terima ke Pemandu (PemanduService) perlu ditambah
pemeriksaan item setelah InventoryService ada.

## Test yang masih terbuka dari Phase 2
T7 (Kantil -> Kafan -> FINAL_RITUAL), T8 (2-4 pemain di Studio), T9 (UI minimize, simbol, Device Emulator).
Panduan lengkap ada di riwayat chat; ringkas: Clients and Servers 2 pemain, hanya Player A bicara ke Pemandu,
cek panel muncul di layar Player B.

## Langkah berikutnya
1. AI: rencana Phase 3 + pertanyaan konfirmasi.
2. User: jawab, setujui, lalu AI menulis kode.