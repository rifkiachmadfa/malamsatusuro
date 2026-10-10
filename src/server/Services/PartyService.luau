--!strict
-- PartyService: ukuran party saat ini (Phase 6, ADR-032).
-- SEKARANG ukuran = jumlah pemain di server. RENCANA: pemain masuk dari place lobby dan memilih Solo/2/3/4
-- pemain, lalu di-teleport ke place ini; mode itu akan dibaca dari TeleportData (lihat TASKS "Lobby & matchmaking").
-- Semua kode lain bertanya lewat service ini, jadi sumber ukuran party cukup diganti di satu tempat.

local Players = game:GetService("Players")

local PartyService = {}

function PartyService.getSize(): number
	return #Players:GetPlayers()
end

-- Solo = tersisa satu pemain (termasuk party yang anggotanya keluar sampai tinggal satu).
function PartyService.isSolo(): boolean
	return PartyService.getSize() <= 1
end

return table.freeze(PartyService)
