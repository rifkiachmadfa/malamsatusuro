--!strict
-- DialogueController: menampilkan dialog NPC. Hanya tampilan; alur dialog dimiliki server.
-- Layout memakai Scale + TextScaled + constraint agar proporsional di semua device
-- (HP portrait/landscape, tablet, desktop) dan tidak terpotong notch (DeviceSafeInsets).

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes") :: ModuleScript)
local Theme = require(script.Parent.Parent:WaitForChild("UI"):WaitForChild("Theme") :: ModuleScript)

local ACTION_ADVANCE = "MalamSuroDialogueAdvance"
local ACTION_CLOSE = "MalamSuroDialogueClose"
local TYPE_SPEED = 45 -- karakter per detik
local HINT_NEXT = "Ketuk untuk lanjut"
local HINT_LAST = "Ketuk untuk menutup"

local localPlayer = Players.LocalPlayer

local DialogueController = {}

local gui: ScreenGui
local nameLabel: TextLabel
local textLabel: TextLabel
local hintLabel: TextLabel
local actionRemote: RemoteEvent

local open = false
local typing = false
local typingToken = 0
local currentIsLast = false

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
	label.TextWrapped = true
	label.Text = ""
	label.Parent = parent
	return label
end

local function finishTyping()
	typingToken += 1
	typing = false
	textLabel.MaxVisibleGraphemes = -1
	hintLabel.Text = if currentIsLast then HINT_LAST else HINT_NEXT
	hintLabel.Visible = true
end

local function startTyping(text: string)
	typingToken += 1
	local token = typingToken

	textLabel.Text = text
	textLabel.MaxVisibleGraphemes = 0
	hintLabel.Visible = false
	typing = true

	task.spawn(function()
		local total = utf8.len(text) or #text
		local shown = 0
		while shown < total do
			task.wait(1 / TYPE_SPEED)
			if token ~= typingToken then
				return
			end
			shown += 1
			textLabel.MaxVisibleGraphemes = shown
		end
		if token == typingToken then
			finishTyping()
		end
	end)
end

local function advance()
	if not open then
		return
	end
	if typing then
		finishTyping() -- ketukan pertama: tampilkan teks penuh
		return
	end
	actionRemote:FireServer("Next")
end

local function closeLocal()
	if not open then
		return
	end
	open = false
	typingToken += 1
	typing = false
	ContextActionService:UnbindAction(ACTION_ADVANCE)
	ContextActionService:UnbindAction(ACTION_CLOSE)
	gui.Enabled = false
end

local function requestClose()
	if not open then
		return
	end
	closeLocal()
	actionRemote:FireServer("Close")
end

local function bindInput()
	ContextActionService:BindActionAtPriority(
		ACTION_ADVANCE,
		function(_name: string, state: Enum.UserInputState, _input: InputObject)
			if state == Enum.UserInputState.Begin then
				advance()
			end
			return Enum.ContextActionResult.Sink
		end,
		false,
		Enum.ContextActionPriority.High.Value,
		Enum.KeyCode.E,
		Enum.KeyCode.Space,
		Enum.KeyCode.Return,
		Enum.KeyCode.ButtonA
	)
	ContextActionService:BindActionAtPriority(
		ACTION_CLOSE,
		function(_name: string, state: Enum.UserInputState, _input: InputObject)
			if state == Enum.UserInputState.Begin then
				requestClose()
			end
			return Enum.ContextActionResult.Sink
		end,
		false,
		Enum.ContextActionPriority.High.Value,
		Enum.KeyCode.ButtonB
	)
end

local function build()
	gui = Instance.new("ScreenGui")
	gui.Name = "DialogueGui"
	gui.ResetOnSpawn = false
	gui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.DisplayOrder = 10
	gui.Enabled = false

	-- Panel = tombol penuh, jadi seluruh panel bisa diketuk untuk lanjut.
	local panel = Instance.new("TextButton")
	panel.Name = "Panel"
	panel.Text = ""
	panel.AutoButtonColor = false
	panel.AnchorPoint = Vector2.new(0.5, 1)
	panel.Position = UDim2.fromScale(0.5, 0.97)
	panel.Size = UDim2.fromScale(0.92, 0.3)
	panel.BackgroundColor3 = Theme.Black
	panel.BackgroundTransparency = Theme.PanelTransparency
	panel.BorderSizePixel = 0
	panel.Parent = gui

	local sizeLimit = Instance.new("UISizeConstraint")
	sizeLimit.MinSize = Vector2.new(0, 120)
	sizeLimit.MaxSize = Vector2.new(820, 280)
	sizeLimit.Parent = panel

	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0.03, 0)
	padding.PaddingRight = UDim.new(0.03, 0)
	padding.PaddingTop = UDim.new(0.08, 0)
	padding.PaddingBottom = UDim.new(0.06, 0)
	padding.Parent = panel

	nameLabel = makeLabel("Speaker", Theme.FontBold, Theme.White, panel)
	nameLabel.Position = UDim2.fromScale(0, 0)
	nameLabel.Size = UDim2.fromScale(0.8, 0.2)
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	addTextConstraint(nameLabel, 12, 24)

	textLabel = makeLabel("Text", Theme.FontBody, Theme.White, panel)
	textLabel.Position = UDim2.fromScale(0, 0.26)
	textLabel.Size = UDim2.fromScale(1, 0.52)
	textLabel.TextXAlignment = Enum.TextXAlignment.Left
	textLabel.TextYAlignment = Enum.TextYAlignment.Top
	addTextConstraint(textLabel, 12, 26)

	hintLabel = makeLabel("Hint", Theme.FontBody, Theme.Muted, panel)
	hintLabel.Position = UDim2.fromScale(0, 0.84)
	hintLabel.Size = UDim2.fromScale(1, 0.16)
	hintLabel.TextXAlignment = Enum.TextXAlignment.Right
	addTextConstraint(hintLabel, 11, 16)

	-- Tombol tutup: minimal 40x40 px supaya mudah disentuh.
	local closeButton = Instance.new("TextButton")
	closeButton.Name = "Close"
	closeButton.AnchorPoint = Vector2.new(1, 0)
	closeButton.Position = UDim2.fromScale(1, 0)
	closeButton.Size = UDim2.fromOffset(40, 40)
	closeButton.BackgroundTransparency = 1
	closeButton.BorderSizePixel = 0
	closeButton.AutoButtonColor = false
	closeButton.Font = Theme.FontBold
	closeButton.Text = "X"
	closeButton.TextSize = 20
	closeButton.TextColor3 = Theme.White
	closeButton.ZIndex = 2
	closeButton.Parent = panel

	panel.Activated:Connect(advance)
	closeButton.Activated:Connect(requestClose)

	gui.Parent = localPlayer:WaitForChild("PlayerGui")
end

local function onUpdate(payload: unknown)
	if typeof(payload) ~= "table" then
		return
	end
	local data = payload :: { [string]: unknown }

	if data.action == "Close" then
		closeLocal()
		return
	end

	if data.action ~= "Show" then
		return
	end

	local speaker = data.speaker
	local text = data.text
	if typeof(speaker) ~= "string" or typeof(text) ~= "string" then
		return
	end

	currentIsLast = data.isLast == true
	nameLabel.Text = speaker

	if not open then
		open = true
		gui.Enabled = true
		bindInput()
	end
	startTyping(text)
end

function DialogueController.isOpen(): boolean
	return open
end

function DialogueController.init()
	actionRemote = Remotes.get(Remotes.Names.DialogueAction)
	build()
	Remotes.get(Remotes.Names.DialogueUpdate).OnClientEvent:Connect(onUpdate)
end

return DialogueController