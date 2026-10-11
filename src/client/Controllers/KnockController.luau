--!strict
-- KnockController: overlay minimal untuk pemain yang KNOCK (Phase 6, Task 6.3). Hanya tampilan.
-- Membaca Attribute "PlayerState" milik pemain lokal (direplikasi GameManager); muncul saat KNOCKED, hilang saat
-- state lain. Layar menggelap dengan vinyet dan teks "Kamu pingsan". Client tidak menentukan state apa pun.
-- DisplayOrder di bawah notifikasi (30) dan jumpscare (100) agar keduanya tetap terlihat di atas overlay ini.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("Config"):WaitForChild("GameConfig") :: ModuleScript)
local Theme = require(script.Parent.Parent:WaitForChild("UI"):WaitForChild("Theme") :: ModuleScript)

local STATE_ATTRIBUTE = "PlayerState"
local TITLE = "KAMU PINGSAN"
local HINT = "Tunggu rekanmu menyadarkanmu dengan Minyak Zaitun."
local FADE_SECONDS = 0.4
local DIM_TRANSPARENCY = 0.55 -- redaman seluruh layar (0 = hitam penuh)

local localPlayer = Players.LocalPlayer

local KnockController = {}

local gui: ScreenGui
local group: CanvasGroup
local shown = false
local currentTween: Tween? = nil

-- Bayangan gelap di satu sisi layar: pekat di tepi, memudar ke tengah.
local function makeEdge(name: string, rotation: number, size: UDim2, anchor: Vector2, position: UDim2)
	local edge = Instance.new("Frame")
	edge.Name = name
	edge.AnchorPoint = anchor
	edge.Position = position
	edge.Size = size
	edge.BackgroundColor3 = Theme.Black
	edge.BorderSizePixel = 0
	edge.Parent = group

	local gradient = Instance.new("UIGradient")
	gradient.Rotation = rotation
	gradient.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(1, 1),
	})
	gradient.Parent = edge
end

local function makeLabel(name: string, text: string, font: Enum.Font, size: number, color: Color3, yScale: number)
	local label = Instance.new("TextLabel")
	label.Name = name
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = UDim2.fromScale(0.5, yScale)
	label.Size = UDim2.new(0.8, 0, 0, size + 8)
	label.BackgroundTransparency = 1
	label.Font = font
	label.Text = text
	label.TextSize = size
	label.TextColor3 = color
	label.TextWrapped = true
	label.Parent = group
end

local function build()
	gui = Instance.new("ScreenGui")
	gui.Name = "KnockGui"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.DisplayOrder = 20
	gui.Enabled = false

	group = Instance.new("CanvasGroup")
	group.Name = "Overlay"
	group.Size = UDim2.fromScale(1, 1)
	group.BackgroundColor3 = Theme.Black
	group.BackgroundTransparency = DIM_TRANSPARENCY
	group.BorderSizePixel = 0
	group.GroupTransparency = 1
	group.Parent = gui

	makeEdge("Top", 90, UDim2.fromScale(1, 0.4), Vector2.new(0, 0), UDim2.fromScale(0, 0))
	makeEdge("Bottom", 270, UDim2.fromScale(1, 0.4), Vector2.new(0, 1), UDim2.fromScale(0, 1))
	makeEdge("Left", 0, UDim2.fromScale(0.3, 1), Vector2.new(0, 0), UDim2.fromScale(0, 0))
	makeEdge("Right", 180, UDim2.fromScale(0.3, 1), Vector2.new(1, 0), UDim2.fromScale(1, 0))

	makeLabel("Title", TITLE, Theme.FontBold, 30, Theme.White, 0.46)
	makeLabel("Hint", HINT, Theme.FontBody, 16, Theme.Muted, 0.53)

	gui.Parent = localPlayer:WaitForChild("PlayerGui")
end

-- Sembunyikan hotbar Roblox selama knock (server sudah melarang equip; ini hanya merapikan tampilan).
local function setBackpackVisible(visible: boolean)
	pcall(StarterGui.SetCoreGuiEnabled, StarterGui, Enum.CoreGuiType.Backpack, visible)
end

local function fadeTo(target: number)
	if currentTween then
		currentTween:Cancel()
	end
	local tween = TweenService:Create(group, TweenInfo.new(FADE_SECONDS), { GroupTransparency = target })
	currentTween = tween
	tween.Completed:Connect(function()
		if not shown then
			gui.Enabled = false
		end
	end)
	tween:Play()
end

local function apply()
	local knocked = localPlayer:GetAttribute(STATE_ATTRIBUTE) == GameConfig.PlayerState.KNOCKED
	if knocked == shown then
		return
	end
	shown = knocked
	setBackpackVisible(not knocked)
	if knocked then
		gui.Enabled = true
		fadeTo(0)
	else
		fadeTo(1)
	end
end

function KnockController.init()
	build()
	localPlayer:GetAttributeChangedSignal(STATE_ATTRIBUTE):Connect(apply)
	apply()
end

return KnockController
