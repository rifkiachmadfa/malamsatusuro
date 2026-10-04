--!strict
-- GameConfig: konstanta global game. Hanya data, tanpa logika.

local GameConfig = {}

GameConfig.MIN_PLAYERS = 1
GameConfig.MAX_PLAYERS = 4

-- State game (milik server, lihat GameManager nanti)
GameConfig.GameState = table.freeze({
	LOBBY = "LOBBY",
	INTRO = "INTRO",
	QUEST_KERIS = "QUEST_KERIS",
	QUEST_KANTIL = "QUEST_KANTIL",
	QUEST_KAFAN = "QUEST_KAFAN",
	FINAL_RITUAL = "FINAL_RITUAL",
	ENDING = "ENDING",
	GAME_COMPLETE = "GAME_COMPLETE",
})

-- State per pemain
GameConfig.PlayerState = table.freeze({
	NORMAL = "NORMAL",
	KNOCKED = "KNOCKED",
	REVIVING = "REVIVING",
	MINIGAME = "MINIGAME",
	CUTSCENE = "CUTSCENE",
})

-- Sistem interaksi [E]. Objek interaktif = CollectionService tag + Attribute.
GameConfig.Interaction = table.freeze({
	TAG = "Interactable",
	ATTR_ID = "InteractionId", -- wajib: dipetakan ke handler server
	ATTR_ACTION_TEXT = "ActionText", -- contoh: "Bicara"
	ATTR_OBJECT_TEXT = "ObjectText", -- contoh: "Pemandu"
	ATTR_MAX_DISTANCE = "MaxDistance", -- opsional, studs
	DEFAULT_DISTANCE = 10,
	DISTANCE_TOLERANCE = 4, -- toleransi lag untuk validasi server
	LEAVE_EXTRA_DISTANCE = 6, -- dialog ditutup server jika pemain menjauh sejauh ini
	REQUEST_COOLDOWN = 0.3, -- detik, per pemain
})

return table.freeze(GameConfig)