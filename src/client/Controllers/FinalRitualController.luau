--!strict
-- FinalRitualController: tampilan ritual akhir (Phase 8, ADR-040). HANYA tampilan; client tidak mengirim apa pun
-- dan tidak menentukan state apa pun.
--   1) HUD kecil "BERKUMPUL DI TEMPAT RITUAL n/N" saat game FINAL_RITUAL (dari Attribute ReplicatedStorage).
--   2) Cutscene: letterbox + subtitle per langkah + transisi Lighting + kartu "TAMAT" (dari remote CutsceneUpdate).
-- DisplayOrder 25: di atas KnockGui (20), di bawah notifikasi (30) dan jumpscare (100).

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("Config"):WaitForChild("GameConfig") :: ModuleScript)
local FinalRitualConfig = require(Shared:WaitForChild("Config"):WaitForChild("FinalRitualConfig") :: ModuleScript)
local Remotes = require(Shared:WaitForChild("Remotes") :: ModuleScript)
local Theme = require(script.Parent.Parent:WaitForChild("UI"):WaitForChild("Theme") :: ModuleScript)

local GAME_STATE_ATTRIBUTE = "GameState"
local BAR_HEIGHT = 0.13 -- skala tinggi letterbox
local FADE = 0.4

local localPlayer = Players.LocalPlayer

local FinalRitualController = {}

-- HUD
local hudGui: ScreenGui
local hudLabel: TextLabel

-- Cutscene
local sceneGui: ScreenGui
local topBar: Frame
local bottomBar: Frame
local speakerLabel: TextLabel
local textLabel: TextLabel
local blackout: Frame
local titleLabel: TextLabel
local subtitleLabel: TextLabel
local stepToken = 0

local function tween(instance: Instance, seconds: number, goal: { [string]: any })
	TweenService:Create(instance, TweenInfo.new(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), goal):Play()
end

local function setBackpackVisible(visible: boolean)
	pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, visible)
	end)
end

local function makeLabel(
	name: string,
	font: Enum.Font,
	size: number,
	color: Color3,
	position: UDim2,
	parent: Instance
): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = position
	label.Size = UDim2.new(0.8, 0, 0, size + 10)
	label.BackgroundTransparency = 1
	label.Font = font
	label.Text = ""
	label.TextSize = size
	label.TextColor3 = color
	label.TextWrapped = true
	label.TextTransparency = 1
	label.TextStrokeColor3 = Theme.Black
	label.TextStrokeTransparency = 0.6
	label.Parent = parent
	return label
end

-- ===== HUD berkumpul =====

local function refreshHud()
	local inGathering = ReplicatedStorage:GetAttribute(GAME_STATE_ATTRIBUTE) == GameConfig.GameState.FINAL_RITUAL
	local ready = ReplicatedStorage:GetAttribute(FinalRitualConfig.ATTR_READY)
	local required = ReplicatedStorage:GetAttribute(FinalRitualConfig.ATTR_REQUIRED)
	local holding = ReplicatedStorage:GetAttribute(FinalRitualConfig.ATTR_HOLDING) == true

	if not inGathering or type(ready) ~= "number" or type(required) ~= "number" then
		hudGui.Enabled = false
		return
	end

	hudLabel.Text = string.format(
		"%s  %d/%d",
		if holding then "TAHAN POSISI..." else "BERKUMPUL DI TEMPAT RITUAL",
		ready,
		required
	)
	hudGui.Enabled = true
end

local function buildHud()
	hudGui = Instance.new("ScreenGui")
	hudGui.Name = "FinalRitualHud"
	hudGui.ResetOnSpawn = false
	hudGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	hudGui.DisplayOrder = 10
	hudGui.Enabled = false

	hudLabel = Instance.new("TextLabel")
	hudLabel.Name = "Label"
	hudLabel.AnchorPoint = Vector2.new(0.5, 0)
	hudLabel.Position = UDim2.new(0.5, 0, 0, 56)
	hudLabel.Size = UDim2.new(0, 320, 0, 34)
	hudLabel.BackgroundColor3 = Theme.Black
	hudLabel.BackgroundTransparency = Theme.PanelTransparency
	hudLabel.BorderSizePixel = 0
	hudLabel.Font = Theme.FontBold
	hudLabel.TextSize = 15
	hudLabel.TextColor3 = Theme.White
	hudLabel.Text = ""
	hudLabel.Parent = hudGui

	hudGui.Parent = localPlayer:WaitForChild("PlayerGui")
end

-- ===== Cutscene =====

local function applyEnvironment(name: string?)
	local env = name and FinalRitualConfig.Environments[name]
	if not env then
		return
	end
	tween(Lighting, env.tweenSeconds, {
		Brightness = env.brightness,
		ClockTime = env.clockTime,
		FogColor = env.fogColor,
		FogEnd = env.fogEnd,
		Ambient = env.ambient,
		OutdoorAmbient = env.outdoorAmbient,
	})
end

local function buildScene()
	sceneGui = Instance.new("ScreenGui")
	sceneGui.Name = "CutsceneGui"
	sceneGui.ResetOnSpawn = false
	sceneGui.IgnoreGuiInset = true
	sceneGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	sceneGui.DisplayOrder = 25
	sceneGui.Enabled = false

	blackout = Instance.new("Frame")
	blackout.Name = "Blackout"
	blackout.Size = UDim2.fromScale(1, 1)
	blackout.BackgroundColor3 = Theme.Black
	blackout.BackgroundTransparency = 1
	blackout.BorderSizePixel = 0
	blackout.ZIndex = 1
	blackout.Parent = sceneGui

	topBar = Instance.new("Frame")
	topBar.Name = "TopBar"
	topBar.AnchorPoint = Vector2.new(0, 0)
	topBar.Position = UDim2.fromScale(0, -BAR_HEIGHT)
	topBar.Size = UDim2.fromScale(1, BAR_HEIGHT)
	topBar.BackgroundColor3 = Theme.Black
	topBar.BorderSizePixel = 0
	topBar.ZIndex = 2
	topBar.Parent = sceneGui

	bottomBar = Instance.new("Frame")
	bottomBar.Name = "BottomBar"
	bottomBar.AnchorPoint = Vector2.new(0, 0)
	bottomBar.Position = UDim2.fromScale(0, 1)
	bottomBar.Size = UDim2.fromScale(1, BAR_HEIGHT)
	bottomBar.BackgroundColor3 = Theme.Black
	bottomBar.BorderSizePixel = 0
	bottomBar.ZIndex = 2
	bottomBar.Parent = sceneGui

	speakerLabel = makeLabel("Speaker", Theme.FontBold, 15, Theme.Muted, UDim2.fromScale(0.5, 0.72), sceneGui)
	speakerLabel.ZIndex = 3
	textLabel = makeLabel("Text", Theme.FontBody, 22, Theme.White, UDim2.fromScale(0.5, 0.78), sceneGui)
	textLabel.ZIndex = 3
	titleLabel = makeLabel("Title", Theme.FontBold, 44, Theme.White, UDim2.fromScale(0.5, 0.46), sceneGui)
	titleLabel.ZIndex = 4
	subtitleLabel = makeLabel("Subtitle", Theme.FontBody, 18, Theme.Muted, UDim2.fromScale(0.5, 0.54), sceneGui)
	subtitleLabel.ZIndex = 4

	sceneGui.Parent = localPlayer:WaitForChild("PlayerGui")
end

local function onStart()
	stepToken += 1
	textLabel.TextTransparency = 1
	speakerLabel.TextTransparency = 1
	titleLabel.TextTransparency = 1
	subtitleLabel.TextTransparency = 1
	blackout.BackgroundTransparency = 1
	sceneGui.Enabled = true
	hudGui.Enabled = false
	setBackpackVisible(false)
	tween(topBar, 1, { Position = UDim2.fromScale(0, 0) })
	tween(bottomBar, 1, { Position = UDim2.fromScale(0, 1 - BAR_HEIGHT) })
end

local function onStep(data: any)
	if type(data.text) ~= "string" or type(data.duration) ~= "number" then
		return
	end
	stepToken += 1
	local token = stepToken

	speakerLabel.Text = if type(data.speaker) == "string" then string.upper(data.speaker) else ""
	textLabel.Text = data.text
	tween(speakerLabel, FADE, { TextTransparency = 0 })
	tween(textLabel, FADE, { TextTransparency = 0 })
	applyEnvironment(if type(data.env) == "string" then data.env else nil)

	-- Memudar sedikit sebelum langkah berikutnya; token mencegah pemudaran langkah lama menimpa langkah baru.
	task.delay(math.max(data.duration - FADE, 0.1), function()
		if stepToken == token then
			tween(speakerLabel, FADE, { TextTransparency = 1 })
			tween(textLabel, FADE, { TextTransparency = 1 })
		end
	end)
end

local function onEnd(data: any)
	stepToken += 1
	speakerLabel.TextTransparency = 1
	textLabel.TextTransparency = 1
	titleLabel.Text = if type(data.title) == "string" then data.title else ""
	subtitleLabel.Text = if type(data.subtitle) == "string" then data.subtitle else ""
	tween(blackout, 1.5, { BackgroundTransparency = 0 })
	task.delay(1.5, function()
		tween(titleLabel, 1.5, { TextTransparency = 0 })
		tween(subtitleLabel, 1.5, { TextTransparency = 0 })
	end)
end

local function onClose()
	stepToken += 1
	tween(titleLabel, 1, { TextTransparency = 1 })
	tween(subtitleLabel, 1, { TextTransparency = 1 })
	tween(blackout, 1.5, { BackgroundTransparency = 1 })
	tween(topBar, 1.5, { Position = UDim2.fromScale(0, -BAR_HEIGHT) })
	tween(bottomBar, 1.5, { Position = UDim2.fromScale(0, 1) })
	task.delay(1.6, function()
		sceneGui.Enabled = false
		setBackpackVisible(true)
		refreshHud()
	end)
end

function FinalRitualController.init()
	buildHud()
	buildScene()

	ReplicatedStorage:GetAttributeChangedSignal(GAME_STATE_ATTRIBUTE):Connect(refreshHud)
	ReplicatedStorage:GetAttributeChangedSignal(FinalRitualConfig.ATTR_READY):Connect(refreshHud)
	ReplicatedStorage:GetAttributeChangedSignal(FinalRitualConfig.ATTR_REQUIRED):Connect(refreshHud)
	ReplicatedStorage:GetAttributeChangedSignal(FinalRitualConfig.ATTR_HOLDING):Connect(refreshHud)
	refreshHud()

	Remotes.get(Remotes.Names.CutsceneUpdate).OnClientEvent:Connect(function(payload: unknown)
		if type(payload) ~= "table" then
			return
		end
		local data = payload :: any
		if data.action == "Start" then
			onStart()
		elseif data.action == "Step" then
			onStep(data)
		elseif data.action == "End" then
			onEnd(data)
		elseif data.action == "Close" then
			onClose()
		end
	end)
end

return FinalRitualController
