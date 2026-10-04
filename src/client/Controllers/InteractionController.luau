--!strict
-- InteractionController: mencari objek interaktif terdekat dan menampilkan prompt.
-- Hanya MEMINTA interaksi; server yang memvalidasi dan memutuskan.

local CollectionService = game:GetService("CollectionService")
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("Config"):WaitForChild("GameConfig") :: ModuleScript)
local Spatial = require(Shared:WaitForChild("Util"):WaitForChild("Spatial") :: ModuleScript)
local Interactable = require(Shared:WaitForChild("Util"):WaitForChild("Interactable") :: ModuleScript)
local Remotes = require(Shared:WaitForChild("Remotes") :: ModuleScript)
local Theme = require(script.Parent.Parent:WaitForChild("UI"):WaitForChild("Theme") :: ModuleScript)

local Config = GameConfig.Interaction
local ACTION_NAME = "MalamSuroInteract"
local SCAN_INTERVAL = 0.1
local LOCAL_COOLDOWN = 0.4

local localPlayer = Players.LocalPlayer

local InteractionController = {}

local gui: ScreenGui
local objectLabel: TextLabel
local actionLabel: TextLabel
local requestRemote: RemoteEvent
local isBlocked: () -> boolean = function()
	return false
end

local currentTarget: Instance? = nil
local bound = false
local lastRequest = 0

local function requestInteract()
	local target = currentTarget
	if not target then
		return
	end
	local now = os.clock()
	if now - lastRequest < LOCAL_COOLDOWN then
		return
	end
	lastRequest = now
	requestRemote:FireServer(target)
end

local function bindKey()
	if bound then
		return
	end
	bound = true
	ContextActionService:BindAction(ACTION_NAME, function(_name: string, state: Enum.UserInputState, _input: InputObject)
		if state == Enum.UserInputState.Begin then
			requestInteract()
			return Enum.ContextActionResult.Sink
		end
		return Enum.ContextActionResult.Pass
	end, false, Enum.KeyCode.E, Enum.KeyCode.ButtonX)
end

local function unbindKey()
	if not bound then
		return
	end
	bound = false
	ContextActionService:UnbindAction(ACTION_NAME)
end

local function setTarget(target: Instance?)
	if target == currentTarget then
		return
	end
	currentTarget = target

	if not target then
		gui.Enabled = false
		unbindKey()
		return
	end

	local actionText = Interactable.getActionText(target)
	local touchOnly = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
	actionLabel.Text = if touchOnly then actionText else ("[E] " .. actionText)
	objectLabel.Text = Interactable.getObjectText(target)
	gui.Enabled = true
	bindKey()
end

local function findNearestTarget(): Instance?
	if isBlocked() or localPlayer:GetAttribute("PlayerState") ~= GameConfig.PlayerState.NORMAL then
		return nil
	end

	local playerPosition = Spatial.getCharacterPosition(localPlayer)
	if not playerPosition then
		return nil
	end

	local best: Instance? = nil
	local bestDistance = math.huge
	for _, candidate in CollectionService:GetTagged(Config.TAG) do
		if candidate:IsDescendantOf(Workspace) then
			local position = Spatial.getPosition(candidate)
			if position then
				local distance = (position - playerPosition).Magnitude
				if distance <= Interactable.getMaxDistance(candidate) and distance < bestDistance then
					best = candidate
					bestDistance = distance
				end
			end
		end
	end
	return best
end

local function addTextConstraint(label: TextLabel, minSize: number, maxSize: number)
	local constraint = Instance.new("UITextSizeConstraint")
	constraint.MinTextSize = minSize
	constraint.MaxTextSize = maxSize
	constraint.Parent = label
end

local function makeLabel(name: string, font: Enum.Font, color: Color3, parent: Instance): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.BorderSizePixel = 0
	label.Font = font
	label.TextColor3 = color
	label.TextScaled = true
	label.Text = ""
	label.Parent = parent
	return label
end

local function build()
	gui = Instance.new("ScreenGui")
	gui.Name = "InteractionGui"
	gui.ResetOnSpawn = false
	gui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.DisplayOrder = 5
	gui.Enabled = false

	-- Tombol prompt: bisa diketuk di mobile, tinggi minimal 50 px.
	local button = Instance.new("TextButton")
	button.Name = "Prompt"
	button.Text = ""
	button.AutoButtonColor = false
	button.AnchorPoint = Vector2.new(0.5, 0.5)
	button.Position = UDim2.fromScale(0.5, 0.74)
	button.Size = UDim2.fromScale(0.4, 0.1)
	button.BackgroundColor3 = Theme.Black
	button.BackgroundTransparency = Theme.PanelTransparency
	button.BorderSizePixel = 0
	button.Parent = gui

	local sizeLimit = Instance.new("UISizeConstraint")
	sizeLimit.MinSize = Vector2.new(180, 50)
	sizeLimit.MaxSize = Vector2.new(360, 72)
	sizeLimit.Parent = button

	objectLabel = makeLabel("Object", Theme.FontBody, Theme.Muted, button)
	objectLabel.Position = UDim2.fromScale(0, 0.08)
	objectLabel.Size = UDim2.fromScale(1, 0.36)
	addTextConstraint(objectLabel, 10, 15)

	actionLabel = makeLabel("Action", Theme.FontBold, Theme.White, button)
	actionLabel.Position = UDim2.fromScale(0, 0.46)
	actionLabel.Size = UDim2.fromScale(1, 0.46)
	addTextConstraint(actionLabel, 12, 22)

	button.Activated:Connect(requestInteract)
	gui.Parent = localPlayer:WaitForChild("PlayerGui")
end

-- blockedCheck: dipakai agar prompt tersembunyi saat GUI lain (mis. dialog) terbuka.
function InteractionController.init(blockedCheck: () -> boolean)
	isBlocked = blockedCheck
	requestRemote = Remotes.get(Remotes.Names.InteractionRequest)
	build()

	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt: number)
		elapsed += dt
		if elapsed < SCAN_INTERVAL then
			return
		end
		elapsed = 0
		setTarget(findNearestTarget())
	end)
end

return InteractionController