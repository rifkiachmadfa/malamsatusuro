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

return table.freeze(GameConfig)