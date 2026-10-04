--!strict
-- QuestConfig: data tiga quest. Hanya data, tanpa logika.
-- Urutan `states` = urutan progres. Transisi maju hanya ke state BERIKUTNYA dalam daftar.
-- Transisi mundur hanya lewat `resets` (contoh: party wipe Kantil).

export type Objective = {
	id: string,
	label: string,
	doneWhen: string, -- objective dianggap selesai saat state quest >= state ini
	counter: string?, -- id counter yang ditampilkan sebagai current/target
}

export type Counter = {
	target: number,
	whileState: string, -- counter hanya boleh bertambah saat quest di state ini
	completeState: string, -- state tujuan otomatis saat counter mencapai target
}

export type PemanduEntry = {
	dialogue: string, -- id di DialogueConfig
	advance: { string }?, -- state berurutan yang dijalankan setelah dialog selesai dibaca
}

export type Quest = {
	id: string,
	title: string,
	gameState: string, -- GameState yang aktif selama quest ini berjalan
	states: { string },
	resets: { [string]: string }, -- [state saat ini] = state tujuan mundur
	counters: { [string]: Counter },
	objectives: { Objective },
	pemandu: { [string]: PemanduEntry }, -- dialog Pemandu per state quest
	hintDialogue: string, -- dialog Pemandu untuk state yang tidak punya entri
}

local QuestConfig = {}

QuestConfig.ATTRIBUTE = "QuestSnapshot" -- Attribute di ReplicatedStorage (JSON, read-only bagi client)
QuestConfig.LOCKED = "LOCKED"
QuestConfig.ACTIVE = "ACTIVE"
QuestConfig.COMPLETE = "COMPLETE"

QuestConfig.Order = table.freeze({ "Keris", "Kantil", "Kafan" })

local Quests: { [string]: Quest } = {
	Keris = {
		id = "Keris",
		title = "KERIS PUSAKA",
		gameState = "QUEST_KERIS",
		states = {
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
		},
		resets = {},
		counters = {
			kelor = { target = 4, whileState = "SEARCHING_KELOR", completeState = "KELOR_COMPLETE" },
		},
		objectives = {
			{ id = "talk", label = "Bicara dengan Pemandu", doneWhen = "SEARCHING_KELOR" },
			{ id = "kelor", label = "Kumpulkan Daun Kelor", doneWhen = "KELOR_COMPLETE", counter = "kelor" },
			{ id = "key", label = "Dapatkan Kunci", doneWhen = "KEY_OBTAINED" },
			{ id = "chest", label = "Buka Peti", doneWhen = "KERIS_OBTAINED" },
			{ id = "submit", label = "Serahkan Keris", doneWhen = "KERIS_SUBMITTED" },
		},
		pemandu = {
			ACTIVE = { dialogue = "Keris_Brief", advance = { "SEARCHING_KELOR" } },
			KERIS_OBTAINED = { dialogue = "Keris_Submit", advance = { "KERIS_SUBMITTED", "COMPLETE" } },
		},
		hintDialogue = "Keris_Hint",
	},

	Kantil = {
		id = "Kantil",
		title = "KEMBANG KANTIL HITAM",
		gameState = "QUEST_KANTIL",
		states = {
			"LOCKED",
			"ACTIVE",
			"SEARCHING_FLOWERS",
			"FLOWERS_COMPLETE",
			"FLOWERS_PLACEMENT",
			"CANTIL_PUZZLE",
			"CANTIL_BLACK_OBTAINED",
			"CANTIL_SUBMITTED",
			"COMPLETE",
		},
		-- Party wipe: hanya reset pencarian bunga, bukan seluruh game.
		resets = {
			CANTIL_PUZZLE = "SEARCHING_FLOWERS",
		},
		counters = {
			flowers = { target = 4, whileState = "SEARCHING_FLOWERS", completeState = "FLOWERS_COMPLETE" },
		},
		objectives = {
			{ id = "talk", label = "Bicara dengan Pemandu", doneWhen = "SEARCHING_FLOWERS" },
			{ id = "flowers", label = "Cari Bunga", doneWhen = "FLOWERS_COMPLETE", counter = "flowers" },
			{ id = "puzzle", label = "Susun bunga di makam", doneWhen = "CANTIL_BLACK_OBTAINED" },
			{ id = "submit", label = "Serahkan Kembang Kantil Hitam", doneWhen = "CANTIL_SUBMITTED" },
		},
		pemandu = {
			ACTIVE = { dialogue = "Kantil_Brief", advance = { "SEARCHING_FLOWERS" } },
			CANTIL_BLACK_OBTAINED = { dialogue = "Kantil_Submit", advance = { "CANTIL_SUBMITTED", "COMPLETE" } },
		},
		hintDialogue = "Kantil_Hint",
	},

	-- Skor gamelan per pemain BUKAN state quest (ADR-020): quest tetap di GAMELAN_ACTIVE
	-- sampai semua pemain lolos, lalu maju ke KAIN_OBTAINED.
	Kafan = {
		id = "Kafan",
		title = "KAIN KAFAN",
		gameState = "QUEST_KAFAN",
		states = {
			"LOCKED",
			"ACTIVE",
			"FIND_GAMELAN",
			"GAMELAN_ACTIVE",
			"KAIN_OBTAINED",
			"KAIN_SUBMITTED",
			"COMPLETE",
		},
		resets = {},
		counters = {},
		objectives = {
			{ id = "talk", label = "Bicara dengan Pemandu", doneWhen = "FIND_GAMELAN" },
			{ id = "find", label = "Cari tempat gamelan", doneWhen = "GAMELAN_ACTIVE" },
			{ id = "play", label = "Mainkan gamelan (semua pemain)", doneWhen = "KAIN_OBTAINED" },
			{ id = "submit", label = "Serahkan Kain Kafan", doneWhen = "KAIN_SUBMITTED" },
		},
		pemandu = {
			ACTIVE = { dialogue = "Kafan_Brief", advance = { "FIND_GAMELAN" } },
			KAIN_OBTAINED = { dialogue = "Kafan_Submit", advance = { "KAIN_SUBMITTED", "COMPLETE" } },
		},
		hintDialogue = "Kafan_Hint",
	},
}

QuestConfig.Quests = Quests

return table.freeze(QuestConfig)