--!strict
-- DialogueService: sesi dialog NPC per pemain. Server memegang indeks baris;
-- client hanya menampilkan dan meminta "Next" / "Close".

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("Config"):WaitForChild("GameConfig") :: ModuleScript)
local DialogueConfig = require(Shared:WaitForChild("Config"):WaitForChild("DialogueConfig") :: ModuleScript)
local Log = require(Shared:WaitForChild("Util"):WaitForChild("Log") :: ModuleScript)
local Spatial = require(Shared:WaitForChild("Util"):WaitForChild("Spatial") :: ModuleScript)
local Remotes = require(Shared:WaitForChild("Remotes") :: ModuleScript)
local GameManager = require(script.Parent:WaitForChild("GameManager") :: ModuleScript)
local InteractionService = require(script.Parent:WaitForChild("InteractionService") :: ModuleScript)

local Config = GameConfig.Interaction
local TAG = "DialogueService"
local WATCH_INTERVAL = 0.5
local NEXT_COOLDOWN = 0.1

type Session = {
	dialogueId: string,
	index: number,
	npc: Instance,
	onFinished: (() -> ())?,
}

local DialogueService = {}

local sessions: { [Player]: Session } = {}
local lastNext: { [Player]: number } = {}
local updateRemote: RemoteEvent

local function sendLine(player: Player, session: Session)
	local dialogue = DialogueConfig[session.dialogueId]
	updateRemote:FireClient(player, {
		action = "Show",
		speaker = dialogue.speaker,
		text = dialogue.lines[session.index],
		isLast = session.index >= #dialogue.lines,
	})
end

local function closeSession(player: Player, notifyClient: boolean)
	if sessions[player] == nil then
		return
	end
	sessions[player] = nil
	if notifyClient then
		updateRemote:FireClient(player, { action = "Close" })
	end
end

-- Mulai dialog untuk pemain. Dipanggil dari handler InteractionService (sudah tervalidasi).
-- onFinished (opsional) dipanggil HANYA jika pemain membaca sampai baris terakhir
-- (bukan saat ditutup dini, menjauh, atau disconnect).
function DialogueService.start(player: Player, dialogueId: string, npc: Instance, onFinished: (() -> ())?)
	if sessions[player] then
		return
	end

	local dialogue = DialogueConfig[dialogueId]
	if not dialogue or #dialogue.lines == 0 then
		Log.warn(TAG, "dialog tidak ditemukan: " .. dialogueId)
		return
	end

	local session: Session = { dialogueId = dialogueId, index = 1, npc = npc, onFinished = onFinished }
	sessions[player] = session
	sendLine(player, session)
end

function DialogueService.isInDialogue(player: Player): boolean
	return sessions[player] ~= nil
end

local function onAction(player: Player, action: unknown)
	if action ~= "Next" and action ~= "Close" then
		Log.warn(TAG, string.format("aksi tidak valid dari %s", player.Name))
		return
	end

	local session = sessions[player]
	if not session then
		return
	end

	if action == "Close" then
		closeSession(player, false)
		return
	end

	local now = os.clock()
	local last = lastNext[player]
	if last and now - last < NEXT_COOLDOWN then
		return
	end
	lastNext[player] = now

	session.index += 1
	local dialogue = DialogueConfig[session.dialogueId]
	if session.index > #dialogue.lines then
		local onFinished = session.onFinished
		closeSession(player, true)
		if onFinished then
			task.spawn(onFinished)
		end
		return
	end
	sendLine(player, session)
end

-- Tutup dialog jika pemain menjauh, mati, atau tidak lagi NORMAL.
local function isSessionStillValid(player: Player, session: Session): boolean
	if not session.npc:IsDescendantOf(Workspace) then
		return false
	end
	if GameManager.getPlayerState(player) ~= GameConfig.PlayerState.NORMAL then
		return false
	end

	local playerPosition = Spatial.getCharacterPosition(player)
	local npcPosition = Spatial.getPosition(session.npc)
	if not playerPosition or not npcPosition then
		return false
	end

	local limit = InteractionService.getMaxDistance(session.npc) + Config.DISTANCE_TOLERANCE + Config.LEAVE_EXTRA_DISTANCE
	return (playerPosition - npcPosition).Magnitude <= limit
end

function DialogueService.init()
	updateRemote = Remotes.get(Remotes.Names.DialogueUpdate)
	Remotes.get(Remotes.Names.DialogueAction).OnServerEvent:Connect(onAction)

	Players.PlayerRemoving:Connect(function(player: Player)
		sessions[player] = nil
		lastNext[player] = nil
	end)

	task.spawn(function()
		while true do
			task.wait(WATCH_INTERVAL)
			for player, session in sessions do
				if not isSessionStillValid(player, session) then
					closeSession(player, true)
				end
			end
		end
	end)

	Log.info(TAG, "siap")
end

return table.freeze(DialogueService)