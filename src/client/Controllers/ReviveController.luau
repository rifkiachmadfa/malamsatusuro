--!strict
-- ReviveController: prompt "tahan untuk menyadarkan" dan progress bar revive (Phase 6, Task 6.4, ADR-035).
-- HANYA tampilan + permintaan. Server yang memutuskan: client mengirim Start/Cancel, server memvalidasi,
-- menghitung 3 detik, mengurangi Minyak Zaitun, dan memulihkan korban. Progress bar mengikuti pesan Start dari server.
--
-- Prompt muncul saat ada pemain KNOCK dalam jarak MAX_DISTANCE (state dibaca dari Attribute "PlayerState" pemain lain).
--   * Memegang (equip) Minyak Zaitun: "Tahan [E] Sadarkan" (PC: tahan E, mobile/mouse: tahan tombolnya).
--   * Belum memegang: hanya petunjuk, tombol tidak aktif dan prompt interaksi lain tidak diblokir
--     (mis. pemain yang memegang bunga tetap bisa meletakkannya di makam tempat rekannya pingsan).

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("Config"):WaitForChild("GameConfig") :: ModuleScript)
local ItemConfig = require(Shared:WaitForChild("Config"):WaitForChild("ItemConfig") :: ModuleScript)
local Config = require(Shared:WaitForChild("Config"):WaitForChild("ReviveConfig") :: ModuleScript)
local Spatial = require(Shared:WaitForChild("Util"):WaitForChild("Spatial") :: ModuleScript)
local Remotes = require(Shared:WaitForChild("Remotes") :: ModuleScript)
local Theme = require(script.Parent.Parent:WaitForChild("UI"):WaitForChild("Theme") :: ModuleScript)

local ACTION_NAME = "MalamSuroRevive"
local STATE_ATTRIBUTE = "PlayerState"
local SCAN_INTERVAL = 0.1
local PlayerState = GameConfig.PlayerState

type ClientSession = {
	target: Player,
	startedAt: number,
	duration: number,
}

local localPlayer = Players.LocalPlayer

local ReviveController = {}

local gui: ScreenGui
local button: TextButton
local objectLabel: TextLabel
local actionLabel: TextLabel
local barFill: Frame
local requestRemote: RemoteEvent
local isBlocked: () -> boolean = function()
	return false
end

local nearTarget: Player? = nil -- pemain KNOCK terdekat dalam jarak
local holdingPotion = false -- sedang memegang Minyak Zaitun
local active = false -- prompt aktif (memegang zaitun + ada korban) atau sesi berjalan
local session: ClientSession? = nil
local held = false -- tombol sedang ditahan (Start sudah dikirim)
local bound = false

-- Minyak Zaitun: sedang dipegang (Character) / dimiliki (Backpack atau Character).
local function findPotion(container: Instance?): Tool?
	if not container then
		return nil
	end
	for _, child in container:GetChildren() do
		if child:IsA("Tool") and child:GetAttribute(ItemConfig.ATTR_ITEM_ID) == Config.ITEM_ID then
			return child
		end
	end
	return nil
end

local function isHolding(): boolean
	return findPotion(localPlayer.Character) ~= nil
end

local function ownsPotion(): boolean
	return findPotion(localPlayer.Character) ~= nil or findPotion(localPlayer:FindFirstChildOfClass("Backpack")) ~= nil
end

local function findNearestKnocked(): Player?
	local myPosition = Spatial.getCharacterPosition(localPlayer)
	if not myPosition then
		return nil
	end
	local best: Player? = nil
	local bestDistance = math.huge
	for _, other in Players:GetPlayers() do
		if other ~= localPlayer and other:GetAttribute(STATE_ATTRIBUTE) == PlayerState.KNOCKED then
			local position = Spatial.getCharacterPosition(other)
			if position then
				local distance = (position - myPosition).Magnitude
				if distance <= Config.MAX_DISTANCE and distance < bestDistance then
					best = other
					bestDistance = distance
				end
			end
		end
	end
	return best
end

local function release()
	if held then
		held = false
		requestRemote:FireServer({ action = "Cancel" })
	end
end

local function beginHold()
	if held or session or not active then
		return
	end
	local target = nearTarget
	if not target or not holdingPotion then
		return
	end
	held = true
	requestRemote:FireServer({ action = "Start", target = target })
end

local function bindKey()
	if bound then
		return
	end
	bound = true
	-- Prioritas tinggi + Sink: selama prompt revive aktif, E tidak ikut memicu interaksi lain.
	ContextActionService:BindActionAtPriority(
		ACTION_NAME,
		function(_name: string, state: Enum.UserInputState, _input: InputObject)
			if state == Enum.UserInputState.Begin then
				beginHold()
			elseif state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then
				release()
			end
			return Enum.ContextActionResult.Sink
		end,
		false,
		Enum.ContextActionPriority.High.Value,
		Enum.KeyCode.E,
		Enum.KeyCode.ButtonX
	)
end

local function unbindKey()
	if not bound then
		return
	end
	bound = false
	ContextActionService:UnbindAction(ACTION_NAME)
end

local function refresh()
	local localState = localPlayer:GetAttribute(STATE_ATTRIBUTE)
	local stateOk = localState == PlayerState.NORMAL or localState == PlayerState.REVIVING

	holdingPotion = isHolding()
	nearTarget = if stateOk and not isBlocked() then findNearestKnocked() else nil

	local shownTarget = if session then session.target else nearTarget
	if not shownTarget or (not stateOk and not session) then
		active = false
		gui.Enabled = false
		unbindKey()
		release()
		return
	end

	gui.Enabled = true
	objectLabel.Text = shownTarget.Name .. " pingsan"

	if session or holdingPotion then
		active = true
		local touchOnly = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
		actionLabel.Text = if touchOnly then "Tahan untuk menyadarkan" else "Tahan [E] Sadarkan"
		bindKey()
	else
		active = false
		unbindKey()
		release()
		actionLabel.Text = if ownsPotion() then "Pegang Minyak Zaitun" else "Butuh Minyak Zaitun"
	end
end

local function makeLabel(name: string, font: Enum.Font, color: Color3, parent: Instance, minSize: number, maxSize: number): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.BorderSizePixel = 0
	label.Font = font
	label.TextColor3 = color
	label.TextScaled = true
	label.Text = ""
	label.Parent = parent

	local constraint = Instance.new("UITextSizeConstraint")
	constraint.MinTextSize = minSize
	constraint.MaxTextSize = maxSize
	constraint.Parent = label
	return label
end

local function build()
	gui = Instance.new("ScreenGui")
	gui.Name = "ReviveGui"
	gui.ResetOnSpawn = false
	gui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.DisplayOrder = 6
	gui.Enabled = false

	-- Di atas prompt interaksi biasa (0.74) agar keduanya bisa tampil bersamaan.
	button = Instance.new("TextButton")
	button.Name = "Prompt"
	button.Text = ""
	button.AutoButtonColor = false
	button.AnchorPoint = Vector2.new(0.5, 0.5)
	button.Position = UDim2.fromScale(0.5, 0.6)
	button.Size = UDim2.fromScale(0.4, 0.1)
	button.BackgroundColor3 = Theme.Black
	button.BackgroundTransparency = Theme.PanelTransparency
	button.BorderSizePixel = 0
	button.Parent = gui

	local sizeLimit = Instance.new("UISizeConstraint")
	sizeLimit.MinSize = Vector2.new(200, 56)
	sizeLimit.MaxSize = Vector2.new(360, 76)
	sizeLimit.Parent = button

	objectLabel = makeLabel("Object", Theme.FontBody, Theme.Muted, button, 10, 15)
	objectLabel.Position = UDim2.fromScale(0, 0.05)
	objectLabel.Size = UDim2.fromScale(1, 0.3)

	actionLabel = makeLabel("Action", Theme.FontBold, Theme.White, button, 12, 20)
	actionLabel.Position = UDim2.fromScale(0, 0.37)
	actionLabel.Size = UDim2.fromScale(1, 0.4)

	local barBack = Instance.new("Frame")
	barBack.Name = "BarBack"
	barBack.AnchorPoint = Vector2.new(0.5, 1)
	barBack.Position = UDim2.fromScale(0.5, 0.94)
	barBack.Size = UDim2.fromScale(0.86, 0.09)
	barBack.BackgroundColor3 = Theme.White
	barBack.BackgroundTransparency = 0.8
	barBack.BorderSizePixel = 0
	barBack.Parent = button

	barFill = Instance.new("Frame")
	barFill.Name = "Fill"
	barFill.Size = UDim2.fromScale(0, 1)
	barFill.BackgroundColor3 = Theme.White
	barFill.BorderSizePixel = 0
	barFill.Parent = barBack

	-- Mobile / mouse: tahan tombol prompt. (PC juga bisa menahan E.)
	button.InputBegan:Connect(function(input: InputObject)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			beginHold()
		end
	end)
	button.InputEnded:Connect(function(input: InputObject)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			release()
		end
	end)

	gui.Parent = localPlayer:WaitForChild("PlayerGui")
end

-- blockedCheck: prompt disembunyikan saat GUI lain (dialog/puzzle) terbuka.
function ReviveController.init(blockedCheck: () -> boolean)
	isBlocked = blockedCheck
	requestRemote = Remotes.get(Remotes.Names.ReviveRequest)
	build()

	Remotes.get(Remotes.Names.ReviveUpdate).OnClientEvent:Connect(function(payload: unknown)
		if typeof(payload) ~= "table" then
			return
		end
		local data = payload :: { [any]: any }
		if data.action == "Start" then
			local duration = data.duration
			local targetPlayer: Player? = nil
			if typeof(data.targetName) == "string" then
				targetPlayer = Players:FindFirstChild(data.targetName :: string) :: Player?
			end
			if targetPlayer and typeof(duration) == "number" then
				session = { target = targetPlayer, startedAt = os.clock(), duration = duration }
				barFill.Size = UDim2.fromScale(0, 1)
			end
		elseif data.action == "Stop" then
			session = nil
			barFill.Size = UDim2.fromScale(0, 1)
		end
		refresh()
	end)

	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt: number)
		local current = session
		if current then
			barFill.Size = UDim2.fromScale(math.clamp((os.clock() - current.startedAt) / current.duration, 0, 1), 1)
		end
		elapsed += dt
		if elapsed >= SCAN_INTERVAL then
			elapsed = 0
			refresh()
		end
	end)
end

-- True saat prompt revive memegang tombol E (memegang zaitun + ada korban, atau sesi berjalan).
-- Dipakai InteractionController agar prompt interaksi lain tidak bentrok di tombol yang sama.
function ReviveController.isActive(): boolean
	return active
end

return ReviveController
