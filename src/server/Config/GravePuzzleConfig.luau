--!strict
-- GravePuzzleConfig: data puzzle makam Kantil (Task 5.7-5.8). SISI SERVER SAJA (ServerScriptService),
-- agar jawaban tidak ikut terreplikasi ke client. Clue dibaca pemain dari SurfaceGui di makam (dibuat di Studio, ADR-011);
-- kode tidak menampilkan atau mengirim clue.

local GravePuzzleConfig = {}

GravePuzzleConfig.QUEST_ID = "KANTIL"
GravePuzzleConfig.GRAVES_FOLDER = "Graves" -- Workspace.QuestObjects.Graves
GravePuzzleConfig.INTERACTION_ID = "GravePlace"
GravePuzzleConfig.ACTION_TEXT = "Letakkan Bunga"
GravePuzzleConfig.OBJECT_TEXT = "Makam"
GravePuzzleConfig.MAX_DISTANCE = 8
GravePuzzleConfig.REWARD_ITEM_ID = "KembangKantilHitam"

-- Placement dibuka pada state quest ini. CANTIL_PUZZLE termasuk: jawaban salah = tetap di state itu, coba lagi.
GravePuzzleConfig.OPEN_STATES = table.freeze({
	FLOWERS_COMPLETE = true,
	FLOWERS_PLACEMENT = true,
	CANTIL_PUZZLE = true,
} :: { [string]: boolean })

-- State di mana bunga milik pemain yang keluar game harus dipindahkan ke pemain lain.
GravePuzzleConfig.FLOWER_HOLD_STATES = table.freeze({
	SEARCHING_FLOWERS = true,
	FLOWERS_COMPLETE = true,
	FLOWERS_PLACEMENT = true,
	CANTIL_PUZZLE = true,
} :: { [string]: boolean })

-- Jawaban: nama makam di Workspace.QuestObjects.Graves -> ItemId bunga yang benar.
-- PLACEHOLDER: HARUS disamakan dengan teks clue di SurfaceGui makam. Ubah ANSWER_CONFIRMED jadi true setelah dicocokkan.
GravePuzzleConfig.ANSWER_CONFIRMED = false
GravePuzzleConfig.ANSWER = table.freeze({
	Grave_1 = "MawarMerah",
	Grave_2 = "MawarPutih",
	Grave_3 = "Melati",
	Grave_4 = "KantilKuning",
} :: { [string]: string })

return table.freeze(GravePuzzleConfig)
