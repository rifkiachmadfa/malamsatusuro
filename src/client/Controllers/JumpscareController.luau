--!strict
-- JumpscareController: jumpscare di layar pemain ini saja (Phase 6, Task 6.2, ADR-033).
-- Model 3D berrig dari ReplicatedStorage/GhostModels dimasukkan ke ViewportFrame layar penuh, animasi diputar,
-- kamera melonjak mendekat dengan goyang layar, kilat putih di awal dan layar menggelap di akhir.
-- Hanya tampilan: tidak mengirim apa pun ke server dan tidak menentukan hasil gameplay.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Log = require(Shared:WaitForChild("Util"):WaitForChild("Log") :: ModuleScript)
local Remotes = require(Shared:WaitForChild("Remotes") :: ModuleScript)
local JumpscareConfig = require(Shared:WaitForChild("Config"):WaitForChild("JumpscareConfig") :: ModuleScript)

local TAG = "JumpscareController"
local localPlayer = Players.LocalPlayer

local JumpscareController = {}

local active = false

local function makeFrame(name: string, color: Color3, zIndex: number, transparency: number): Frame
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = color
	frame.BackgroundTransparency = transparency
	frame.BorderSizePixel = 0
	frame.ZIndex = zIndex
	return frame
end

local function play(ghostId: string)
	if active then
		return
	end
	local def = JumpscareConfig.Ghosts[ghostId]
	if not def then
		return
	end

	local folder = ReplicatedStorage:FindFirstChild(JumpscareConfig.MODEL_FOLDER)
	local source = folder and folder:FindFirstChild(def.modelName)
	if not source or not source:IsA("Model") then
		Log.warn(TAG, "model jumpscare tidak ditemukan: " .. def.modelName)
		return
	end

	active = true

	local gui = Instance.new("ScreenGui")
	gui.Name = "JumpscareGui"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.DisplayOrder = 100 -- di atas semua GUI lain

	-- "stage" lebih besar dari layar supaya goyangan tidak memperlihatkan tepi.
	local stage = Instance.new("Frame")
	stage.Name = "Stage"
	stage.AnchorPoint = Vector2.new(0.5, 0.5)
	stage.Position = UDim2.fromScale(0.5, 0.5)
	stage.Size = UDim2.fromScale(1.08, 1.08)
	stage.BackgroundColor3 = Color3.new(0, 0, 0)
	stage.BorderSizePixel = 0
	stage.Parent = gui

	local viewport = Instance.new("ViewportFrame")
	viewport.Name = "Viewport"
	viewport.Size = UDim2.fromScale(1, 1)
	viewport.BackgroundColor3 = Color3.new(0, 0, 0)
	viewport.BorderSizePixel = 0
	viewport.Ambient = Color3.fromRGB(130, 130, 130)
	viewport.LightColor = Color3.fromRGB(255, 255, 255)
	viewport.LightDirection = Vector3.new(0, -0.3, -1)
	viewport.Parent = stage

	local model = source:Clone()
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BaseScript") then
			descendant:Destroy()
		end
	end
	model:PivotTo(CFrame.Angles(0, math.rad(def.yawOffset), 0))
	model.Parent = viewport

	local camera = Instance.new("Camera")
	camera.FieldOfView = def.fov
	camera.Parent = viewport
	viewport.CurrentCamera = camera

	local flash = makeFrame("Flash", Color3.new(1, 1, 1), 3, 0)
	flash.Parent = gui
	local fade = makeFrame("Fade", Color3.new(0, 0, 0), 4, 1)
	fade.Parent = gui

	-- Titik bidik: kepala (jika ada), kalau tidak HumanoidRootPart.
	local head = model:FindFirstChild("Head")
	local root = model:FindFirstChild("HumanoidRootPart")
	local focusPart: BasePart? = nil
	if head and head:IsA("BasePart") then
		focusPart = head
	elseif root and root:IsA("BasePart") then
		focusPart = root
	end
	if not focusPart then
		Log.warn(TAG, "model tanpa Head/HumanoidRootPart: " .. def.modelName)
		gui:Destroy()
		active = false
		return
	end

	local facing = Vector3.new(0, 0, -1)
	if root and root:IsA("BasePart") then
		facing = root.CFrame.LookVector
	end
	local height = math.max(model:GetExtentsSize().Y, 1)
	local basePosition = focusPart.Position
	local lookOffset = Vector3.new(0, def.lookOffsetScale * height, 0)

	-- Animasi pada rig di dalam ViewportFrame.
	local track: AnimationTrack? = nil
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid then
		local animator = humanoid:FindFirstChildOfClass("Animator")
		if not animator then
			local created = Instance.new("Animator")
			created.Parent = humanoid
			animator = created
		end
		local animation = Instance.new("Animation")
		animation.AnimationId = def.animationId
		local ok, result = pcall(animator.LoadAnimation, animator, animation)
		if ok and result then
			track = result :: AnimationTrack
			track.Priority = Enum.AnimationPriority.Action
			track:Play()
		else
			Log.warn(TAG, "animasi jumpscare gagal dimuat: " .. def.animationId)
		end
	else
		Log.warn(TAG, "model tanpa Humanoid, animasi dilewati: " .. def.modelName)
	end

	local sound: Sound? = nil
	if def.soundId ~= "" then
		local created = Instance.new("Sound")
		created.SoundId = def.soundId
		created.Volume = def.soundVolume
		created.Parent = SoundService
		created:Play()
		sound = created
	end

	gui.Parent = localPlayer:WaitForChild("PlayerGui")

	local startTime = os.clock()
	local connection: RBXScriptConnection? = nil
	connection = RunService.RenderStepped:Connect(function()
		local elapsed = os.clock() - startTime

		if elapsed >= def.duration then
			if connection then
				connection:Disconnect()
			end
			if track then
				track:Stop(0)
			end
			if sound then
				sound:Destroy()
			end
			gui:Destroy()
			active = false
			return
		end

		-- Lonjakan kamera: jauh -> dekat (ease-out), selalu membidik posisi kepala saat ini.
		local alpha = math.clamp(elapsed / def.lungeTime, 0, 1)
		local eased = 1 - (1 - alpha) ^ 3
		local distance = (def.distanceStartScale + (def.distanceEndScale - def.distanceStartScale) * eased) * height
		local target = focusPart.Position + lookOffset
		local origin = basePosition + facing * distance + lookOffset
		camera.CFrame = CFrame.lookAt(origin, target)

		-- Goyang layar, mereda perlahan.
		local amplitude = def.shake * (1 - 0.5 * math.clamp(elapsed / def.duration, 0, 1))
		stage.Position = UDim2.new(0.5, (math.random() * 2 - 1) * amplitude, 0.5, (math.random() * 2 - 1) * amplitude)

		flash.BackgroundTransparency = math.clamp(elapsed / def.flashTime, 0, 1)
		local fadeProgress = (elapsed - (def.duration - def.fadeOutTime)) / def.fadeOutTime
		fade.BackgroundTransparency = 1 - math.clamp(fadeProgress, 0, 1)
	end)
end

function JumpscareController.init()
	Remotes.get(Remotes.Names.Jumpscare).OnClientEvent:Connect(function(ghostId: unknown)
		if typeof(ghostId) == "string" then
			play(ghostId)
		end
	end)
end

return JumpscareController
