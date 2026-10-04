--!strict
-- GameManager: pemilik state game dan state pemain (server-authoritative).
-- State direplikasi ke client lewat Attribute (read-only bagi client).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("Config"):WaitForChild("GameConfig") :: ModuleScript)
local Log = require(Shared:WaitForChild("Util"):WaitForChild("Log") :: ModuleScript)

local GameState = GameConfig.GameState
local PlayerState = GameConfig.PlayerState

local TAG = "GameManager"
local GAME_STATE_ATTRIBUTE = "GameState"
local PLAYER_STATE_ATTRIBUTE = "PlayerState"

-- Transisi yang diizinkan. Selain ini = ditolak.
local GAME_TRANSITIONS: { [string]: { string } } = {
	[GameState.LOBBY] = { GameState.INTRO },
	[GameState.INTRO] = { GameState.QUEST_KERIS },
	[GameState.QUEST_KERIS] = { GameState.QUEST_KANTIL },
	[GameState.QUEST_KANTIL] = { GameState.QUEST_KAFAN },
	[GameState.QUEST_KAFAN] = { GameState.FINAL_RITUAL },
	[GameState.FINAL_RITUAL] = { GameState.ENDING },
	[GameState.ENDING] = { GameState.GAME_COMPLETE },
	[GameState.GAME_COMPLETE] = {},
}

local PLAYER_TRANSITIONS: { [string]: { string } } = {
	[PlayerState.NORMAL] = { PlayerState.KNOCKED, PlayerState.MINIGAME, PlayerState.CUTSCENE },
	[PlayerState.KNOCKED] = { PlayerState.REVIVING, PlayerState.NORMAL },
	[PlayerState.REVIVING] = { PlayerState.NORMAL, PlayerState.KNOCKED },
	[PlayerState.MINIGAME] = { PlayerState.NORMAL, PlayerState.KNOCKED },
	[PlayerState.CUTSCENE] = { PlayerState.NORMAL },
}

local function isAllowed(transitions: { [string]: { string } }, from: string, to: string): boolean
	local allowed = transitions[from]
	if not allowed then
		return false
	end
	return table.find(allowed, to) ~= nil
end

local GameManager = {}

local currentState: string = GameState.LOBBY
local playerStates: { [Player]: string } = {}
local initialized = false

local function registerPlayer(player: Player)
	playerStates[player] = PlayerState.NORMAL
	player:SetAttribute(PLAYER_STATE_ATTRIBUTE, PlayerState.NORMAL)
end

function GameManager.init()
	assert(not initialized, "GameManager.init sudah dipanggil")
	initialized = true

	ReplicatedStorage:SetAttribute(GAME_STATE_ATTRIBUTE, currentState)

	for _, player in Players:GetPlayers() do
		registerPlayer(player)
	end
	Players.PlayerAdded:Connect(registerPlayer)
	Players.PlayerRemoving:Connect(function(player: Player)
		playerStates[player] = nil
	end)

	Log.info(TAG, "siap, state awal " .. currentState)
end

function GameManager.getState(): string
	return currentState
end

-- Return true jika transisi diterima, false jika ditolak.
function GameManager.transitionTo(newState: string): boolean
	if not isAllowed(GAME_TRANSITIONS, currentState, newState) then
		Log.warn(TAG, string.format("transisi game ditolak: %s -> %s", currentState, newState))
		return false
	end

	local previous = currentState
	currentState = newState
	ReplicatedStorage:SetAttribute(GAME_STATE_ATTRIBUTE, currentState)
	Log.info(TAG, string.format("state game: %s -> %s", previous, newState))
	return true
end

function GameManager.getPlayerState(player: Player): string?
	return playerStates[player]
end

-- Return true jika transisi diterima, false jika ditolak.
function GameManager.setPlayerState(player: Player, newState: string): boolean
	local current = playerStates[player]
	if not current then
		Log.warn(TAG, string.format("pemain tidak terdaftar: %s", player.Name))
		return false
	end

	if not isAllowed(PLAYER_TRANSITIONS, current, newState) then
		Log.warn(TAG, string.format("transisi pemain ditolak (%s): %s -> %s", player.Name, current, newState))
		return false
	end

	playerStates[player] = newState
	player:SetAttribute(PLAYER_STATE_ATTRIBUTE, newState)
	Log.info(TAG, string.format("state pemain (%s): %s -> %s", player.Name, current, newState))
	return true
end

return table.freeze(GameManager)