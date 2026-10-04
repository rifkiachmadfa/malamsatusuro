--!strict
-- RandomSpawnService: pemilihan titik spawn acak (server) dan pembuatan objek pickup di dunia.
-- Dipakai Kelor sekarang, bunga Kantil nanti (ADR-006: randomisasi hanya di server).
-- Pickup BUKAN Tool di Workspace (Roblox memungut Tool otomatis saat disentuh): visual diambil dari
-- isi Tool template, dijadikan Model statis ber-tag Interactable, dan diambil hanya lewat [E] (ADR-018).

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("Config"):WaitForChild("GameConfig") :: ModuleScript)
local Log = require(Shared:WaitForChild("Util"):WaitForChild("Log") :: ModuleScript)

local TAG = "RandomSpawnService"
local RUNTIME_FOLDER = "QuestRuntime" -- folder Workspace yang dibuat server untuk objek quest dinamis
local InteractionConfig = GameConfig.Interaction

export type PickupInfo = {
	interactionId: string,
	actionText: string,
	objectText: string,
	maxDistance: number?,
}

local RandomSpawnService = {}

local rng = Random.new()

local function isSpawnable(instance: Instance): boolean
	return instance:IsA("BasePart") or instance:IsA("Model")
end

function RandomSpawnService.getCFrame(spawn: Instance): CFrame?
	if spawn:IsA("Model") then
		return spawn:GetPivot()
	elseif spawn:IsA("BasePart") then
		return spawn.CFrame
	end
	return nil
end

-- Folder runtime untuk pickup (dibuat jika belum ada).
function RandomSpawnService.getRuntimeFolder(): Folder
	local existing = Workspace:FindFirstChild(RUNTIME_FOLDER)
	if existing and existing:IsA("Folder") then
		return existing
	end
	local folder = Instance.new("Folder")
	folder.Name = RUNTIME_FOLDER
	folder.Parent = Workspace
	return folder
end

-- Pilih `count` titik spawn berbeda secara acak dari anak-anak `container`.
-- Jika titik yang tersedia kurang dari `count`, semuanya dipakai dan dicatat sebagai warning.
function RandomSpawnService.pickSpawns(container: Instance, count: number): { Instance }
	local candidates: { Instance } = {}
	for _, child in container:GetChildren() do
		if isSpawnable(child) then
			table.insert(candidates, child)
		end
	end
	table.sort(candidates, function(a: Instance, b: Instance)
		return a.Name < b.Name
	end)

	if #candidates < count then
		Log.warn(TAG, string.format("%s hanya punya %d titik spawn, butuh %d", container.Name, #candidates, count))
		count = #candidates
	end

	-- Fisher-Yates parsial: hasilnya `count` elemen berbeda.
	for i = 1, count do
		local j = rng:NextInteger(i, #candidates)
		candidates[i], candidates[j] = candidates[j], candidates[i]
	end

	local picked: { Instance } = {}
	for i = 1, count do
		picked[i] = candidates[i]
	end
	return picked
end

-- Buat pickup di posisi (dan arah) titik spawn. Return nil jika template tidak punya bagian visual.
function RandomSpawnService.createPickup(template: Tool, spawn: Instance, parent: Instance, info: PickupInfo): Model?
	local cframe = RandomSpawnService.getCFrame(spawn)
	if not cframe then
		Log.warn(TAG, "titik spawn tidak valid: " .. spawn.Name)
		return nil
	end

	local clone = template:Clone()
	local model = Instance.new("Model")
	model.Name = "Pickup_" .. spawn.Name

	for _, child in clone:GetChildren() do
		if not child:IsA("BaseScript") then
			child.Parent = model
		end
	end
	clone:Destroy()

	local primary: BasePart? = nil
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BaseScript") then
			descendant:Destroy()
		elseif descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.CanTouch = false
			if primary == nil or descendant.Name == "Handle" then
				primary = descendant
			end
		end
	end

	if not primary then
		Log.warn(TAG, string.format("template %s tidak punya BasePart (Handle) untuk visual pickup", template.Name))
		model:Destroy()
		return nil
	end

	model.PrimaryPart = primary
	model:PivotTo(cframe)

	model:SetAttribute(InteractionConfig.ATTR_ID, info.interactionId)
	model:SetAttribute(InteractionConfig.ATTR_ACTION_TEXT, info.actionText)
	model:SetAttribute(InteractionConfig.ATTR_OBJECT_TEXT, info.objectText)
	if info.maxDistance then
		model:SetAttribute(InteractionConfig.ATTR_MAX_DISTANCE, info.maxDistance)
	end
	CollectionService:AddTag(model, InteractionConfig.TAG)

	model.Parent = parent
	return model
end

return table.freeze(RandomSpawnService)
