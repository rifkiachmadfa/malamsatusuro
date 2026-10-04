--!strict
-- InteractionService: satu pintu untuk semua interaksi [E].
-- Client hanya MEMINTA (InteractionRequest). Server memvalidasi lalu memanggil handler terdaftar.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("Config"):WaitForChild("GameConfig") :: ModuleScript)
local Log = require(Shared:WaitForChild("Util"):WaitForChild("Log") :: ModuleScript)
local Spatial = require(Shared:WaitForChild("Util"):WaitForChild("Spatial") :: ModuleScript)
local Interactable = require(Shared:WaitForChild("Util"):WaitForChild("Interactable") :: ModuleScript)
local Remotes = require(Shared:WaitForChild("Remotes") :: ModuleScript)
local GameManager = require(script.Parent:WaitForChild("GameManager") :: ModuleScript)

local Config = GameConfig.Interaction
local TAG = "InteractionService"

export type Handler = (player: Player, target: Instance) -> ()

local InteractionService = {}

local handlers: { [string]: Handler } = {}
local lastRequest: { [Player]: number } = {}

-- Daftarkan handler untuk satu InteractionId. Satu id = satu handler.
function InteractionService.register(interactionId: string, handler: Handler)
	assert(handlers[interactionId] == nil, "InteractionId sudah terdaftar: " .. interactionId)
	handlers[interactionId] = handler
end

-- Jarak maksimum interaksi untuk sebuah objek (dipakai juga oleh DialogueService).
function InteractionService.getMaxDistance(target: Instance): number
	return Interactable.getMaxDistance(target)
end

local function reject(player: Player, reason: string)
	Log.warn(TAG, string.format("request %s ditolak: %s", player.Name, reason))
end

local function onRequest(player: Player, rawTarget: unknown)
	if typeof(rawTarget) ~= "Instance" then
		reject(player, "target bukan Instance")
		return
	end
	local target = rawTarget :: Instance

	-- Cooldown per pemain (anti-spam). Dicek paling awal agar murah.
	local now = os.clock()
	local last = lastRequest[player]
	if last and now - last < Config.REQUEST_COOLDOWN then
		return
	end
	lastRequest[player] = now

	if not target:IsDescendantOf(Workspace) or not CollectionService:HasTag(target, Config.TAG) then
		reject(player, "target bukan objek interaktif")
		return
	end

	if GameManager.getPlayerState(player) ~= GameConfig.PlayerState.NORMAL then
		return
	end

	local interactionId = Interactable.getId(target)
	if not interactionId then
		reject(player, "target tanpa InteractionId")
		return
	end

	local handler = handlers[interactionId]
	if not handler then
		reject(player, "tidak ada handler untuk " .. interactionId)
		return
	end

	local playerPosition = Spatial.getCharacterPosition(player)
	local targetPosition = Spatial.getPosition(target)
	if not playerPosition or not targetPosition then
		reject(player, "posisi tidak valid")
		return
	end

	local maxDistance = Interactable.getMaxDistance(target) + Config.DISTANCE_TOLERANCE
	if (playerPosition - targetPosition).Magnitude > maxDistance then
		reject(player, "terlalu jauh dari " .. target.Name)
		return
	end

	handler(player, target)
end

function InteractionService.init()
	local tagged = #CollectionService:GetTagged(Config.TAG)
	if tagged == 0 then
		Log.warn(TAG, "dependency belum ada: tidak ada objek ber-tag " .. Config.TAG)
	else
		Log.info(TAG, string.format("siap, %d objek interaktif", tagged))
	end

	local request = Remotes.get(Remotes.Names.InteractionRequest)
	request.OnServerEvent:Connect(onRequest)

	Players.PlayerRemoving:Connect(function(player: Player)
		lastRequest[player] = nil
	end)
end

return table.freeze(InteractionService)