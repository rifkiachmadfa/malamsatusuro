--!strict
-- QuestConfig: definisi quest (data saja, tanpa logika game).
-- Dipakai server (QuestService) dan client (Quest UI). Lihat ADR-018/ADR-019.

export type CounterDef = {
	target: number, -- jumlah party-wide yang dibutuhkan
	requiredState: string, -- progres hanya diterima saat quest berada di state ini
	completeState: string, -- state tujuan otomatis saat target tercapai
}

export type ObjectiveDef = {
	text: string, -- teks tampilan (Indonesia); NOTE: redaksi sementara, samakan dengan GDD
	doneAt: string, -- objective selesai jika state quest sudah mencapai/melewati state ini
	counter: string?, -- jika ada, UI menampilkan "n/target" dari counter ini
}

export type QuestDef = {
	id: string,
	displayName: string,
	states: { string }, -- urutan state (dipakai UI untuk menentukan objective yang sudah selesai)
	objectives: { ObjectiveDef },
	initialState: string,
	transitions: { [string]: { string } },
	counters: { [string]: CounterDef },
	resetCountersOnEnter: { [string]: { string } }, -- state -> daftar counter yang di-reset saat masuk state itu
}

local QuestConfig = {}

-- Urutan quest. Quest berikutnya hanya bisa aktif jika semua quest sebelumnya COMPLETE.
QuestConfig.ORDER = table.freeze({ "KERIS", "KANTIL", "KAFAN" })

QuestConfig.STATE_FOLDER = "QuestState" -- Folder di ReplicatedStorage; state direplikasi lewat Attribute

-- Nama Attribute yang direplikasi (satu tempat agar server dan client tidak berbeda).
function QuestConfig.stateAttribute(questId: string): string
	return questId .. "_State"
end

function QuestConfig.counterAttribute(questId: string, counterId: string): string
	return questId .. "_" .. counterId
end

-- Bangun transisi linear: states[i] -> states[i + 1].
local function chain(states: { string }): { [string]: { string } }
	local transitions: { [string]: { string } } = {}
	for i = 1, #states - 1 do
		transitions[states[i]] = { states[i + 1] }
	end
	transitions[states[#states]] = {}
	return transitions
end

-- QUEST 01 — KERIS PUSAKA
-- Memory puzzle gagal = tetap di CHEST_PUZZLE (coba lagi), bukan transisi.
local kerisStates = {
	"LOCKED",
	"ACTIVE",
	"SEARCHING_KELOR",
	"KELOR_COMPLETE",
	"KEY_OBTAINED",
	"CHEST_AVAILABLE",
	"CHEST_PUZZLE",
	"KERIS_OBTAINED",
	"KERIS_SUBMITTED",
	"COMPLETE",
}
local kerisTransitions = chain(kerisStates)

-- QUEST 02 — KEMBANG KANTIL HITAM
-- Gagal puzzle = knock/revive (state pemain, bukan state quest). Party wipe = CANTIL_PUZZLE -> SEARCHING_FLOWERS.
local kantilStates = {
	"LOCKED",
	"ACTIVE",
	"SEARCHING_FLOWERS",
	"FLOWERS_COMPLETE",
	"FLOWERS_PLACEMENT",
	"CANTIL_PUZZLE",
	"CANTIL_BLACK_OBTAINED",
	"CANTIL_SUBMITTED",
	"COMPLETE",
}
local kantilTransitions = chain(kantilStates)
kantilTransitions["CANTIL_PUZZLE"] = { "CANTIL_BLACK_OBTAINED", "SEARCHING_FLOWERS" }

-- QUEST 03 — KAIN KAFAN
-- State party saja. Skor dan PLAYER_COMPLETE bersifat per pemain (Phase 7), bukan state party.
local kafanStates = {
	"LOCKED",
	"ACTIVE",
	"FIND_GAMELAN",
	"GAMELAN_ACTIVE",
	"ALL_PLAYER_COMPLETE",
	"KAIN_OBTAINED",
	"KAIN_SUBMITTED",
	"COMPLETE",
}
local kafanTransitions = chain(kafanStates)

QuestConfig.Quests = table.freeze({
	KERIS = {
		id = "KERIS",
		displayName = "Keris Pusaka",
		states = kerisStates,
		objectives = {
			{ text = "Kumpulkan Daun Kelor", doneAt = "KELOR_COMPLETE", counter = "Kelor" },
			{ text = "Dapatkan Kunci", doneAt = "KEY_OBTAINED" },
			{ text = "Buka Peti", doneAt = "KERIS_OBTAINED" },
			{ text = "Serahkan Keris", doneAt = "KERIS_SUBMITTED" },
		},
		initialState = "LOCKED",
		transitions = kerisTransitions,
		counters = {
			Kelor = { target = 4, requiredState = "SEARCHING_KELOR", completeState = "KELOR_COMPLETE" },
		},
		resetCountersOnEnter = {},
	} :: QuestDef,
	KANTIL = {
		id = "KANTIL",
		displayName = "Kembang Kantil Hitam",
		states = kantilStates,
		objectives = {
			{ text = "Cari 4 Bunga", doneAt = "FLOWERS_COMPLETE", counter = "Flowers" },
			{ text = "Selesaikan teka-teki makam", doneAt = "CANTIL_BLACK_OBTAINED" },
			{ text = "Serahkan Kembang Kantil Hitam", doneAt = "CANTIL_SUBMITTED" },
		},
		initialState = "LOCKED",
		transitions = kantilTransitions,
		counters = {
			Flowers = { target = 4, requiredState = "SEARCHING_FLOWERS", completeState = "FLOWERS_COMPLETE" },
		},
		resetCountersOnEnter = {
			SEARCHING_FLOWERS = { "Flowers" }, -- party wipe mengulang pencarian bunga dari 0
		},
	} :: QuestDef,
	KAFAN = {
		id = "KAFAN",
		displayName = "Kain Kafan",
		states = kafanStates,
		objectives = {
			{ text = "Cari tempat gamelan", doneAt = "GAMELAN_ACTIVE" },
			{ text = "Mainkan gamelan (skor 80+)", doneAt = "ALL_PLAYER_COMPLETE" },
			{ text = "Serahkan Kain Kafan", doneAt = "KAIN_SUBMITTED" },
		},
		initialState = "LOCKED",
		transitions = kafanTransitions,
		counters = {},
		resetCountersOnEnter = {},
	} :: QuestDef,
})

return table.freeze(QuestConfig)
