--!strict
-- NoticeController: notifikasi (toast) dari server di tengah atas layar. Hanya tampilan.
-- Beberapa notifikasi ditumpuk (terbaru di bawah) supaya pesan beruntun tidak saling menimpa.
-- Satu-satunya jalur notifikasi gameplay: server memakai NoticeService (ADR-025).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes") :: ModuleScript)
local Theme = require(script.Parent.Parent:WaitForChild("UI"):WaitForChild("Theme") :: ModuleScript)

local SHOW_SECONDS = 4
local MAX_VISIBLE = 4
local MAX_LENGTH = 140
local ROW_HEIGHT = 30
local ROW_GAP = 4

local localPlayer = Players.LocalPlayer

local NoticeController = {}

local gui: ScreenGui
local container: Frame
local order = 0
local visible: { TextLabel } = {}

local function removeLabel(label: TextLabel)
	local index = table.find(visible, label)
	if index then
		table.remove(visible, index)
	end
	label:Destroy()
end

local function show(text: string)
	order += 1

	local label = Instance.new("TextLabel")
	label.Name = "Notice" .. order
	label.LayoutOrder = order
	label.Size = UDim2.new(1, 0, 0, ROW_HEIGHT)
	label.BackgroundColor3 = Theme.Black
	label.BackgroundTransparency = Theme.PanelTransparency
	label.BorderSizePixel = 0
	label.Font = Theme.FontBody
	label.TextColor3 = Theme.White
	label.TextScaled = true
	label.TextWrapped = true
	label.Text = string.sub(text, 1, MAX_LENGTH)
	label.Parent = container

	local textLimit = Instance.new("UITextSizeConstraint")
	textLimit.MinTextSize = 10
	textLimit.MaxTextSize = 15
	textLimit.Parent = label

	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 8)
	padding.PaddingRight = UDim.new(0, 8)
	padding.PaddingTop = UDim.new(0, 2)
	padding.PaddingBottom = UDim.new(0, 2)
	padding.Parent = label

	table.insert(visible, label)
	if #visible > MAX_VISIBLE then
		removeLabel(visible[1]) -- buang yang paling lama
	end

	gui.Enabled = true
	task.delay(SHOW_SECONDS, function()
		if label.Parent then
			removeLabel(label)
		end
	end)
end

local function build()
	gui = Instance.new("ScreenGui")
	gui.Name = "NoticeGui"
	gui.ResetOnSpawn = false
	gui.ScreenInsets = Enum.ScreenInsets.TopbarSafeInsets -- di bawah menu Roblox
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.DisplayOrder = 30

	container = Instance.new("Frame")
	container.Name = "Container"
	container.AnchorPoint = Vector2.new(0.5, 0)
	container.Position = UDim2.new(0.5, 0, 0, 8)
	container.Size = UDim2.fromScale(0.6, 0)
	container.AutomaticSize = Enum.AutomaticSize.Y
	container.BackgroundTransparency = 1
	container.BorderSizePixel = 0
	container.Parent = gui

	local sizeLimit = Instance.new("UISizeConstraint")
	sizeLimit.MinSize = Vector2.new(220, 0)
	sizeLimit.MaxSize = Vector2.new(480, math.huge)
	sizeLimit.Parent = container

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Vertical
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, ROW_GAP)
	layout.Parent = container

	gui.Parent = localPlayer:WaitForChild("PlayerGui")
end

function NoticeController.init()
	build()
	Remotes.get(Remotes.Names.Notice).OnClientEvent:Connect(function(text: unknown)
		if typeof(text) == "string" and text ~= "" then
			show(text)
		end
	end)
end

return NoticeController
