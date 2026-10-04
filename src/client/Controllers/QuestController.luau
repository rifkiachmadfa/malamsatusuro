--!strict
-- QuestController: Quest UI di kanan atas. Hanya tampilan; membaca Attribute yang direplikasi server
-- (ReplicatedStorage.QuestState). Client tidak pernah menentukan progres (ADR-007, ADR-019).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local QuestConfig = require(Shared:WaitForChild("Config"):WaitForChild("QuestConfig") :: ModuleScript)
local QuestView = require(Shared:WaitForChild("Util"):WaitForChild("QuestView") :: ModuleScript)
local Log = require(Shared:WaitForChild("Util"):WaitForChild("Log") :: ModuleScript)
local Theme = require(script.Parent.Parent:WaitForChild("UI"):WaitForChild("Theme") :: ModuleScript)

local TAG = "QuestController"
local FOLDER_TIMEOUT = 10
local TITLE = "MALAM SURO"
local ROW_TEXT_SIZE = 15
local TITLE_TEXT_SIZE = 16

local localPlayer = Players.LocalPlayer

local QuestController = {}

local stateFolder: Folder
local gui: ScreenGui
local header: TextButton
local body: Frame

local minimized = false
local renderQueued = false

local function readState(questId: string): string?
	local value = stateFolder:GetAttribute(QuestConfig.stateAttribute(questId))
	return if typeof(value) == "string" then value else nil
end

local function readCounter(questId: string, counterId: string): number?
	local value = stateFolder:GetAttribute(QuestConfig.counterAttribute(questId, counterId))
	return if typeof(value) == "number" then value else nil
end

local function updateHeader()
	header.Text = TITLE .. (if minimized then "   [ + ]" else "   [ - ]")
end

local function render()
	renderQueued = false

	for _, child in body:GetChildren() do
		if child:IsA("TextLabel") then
			child:Destroy()
		end
	end

	local lines = QuestView.build(readState, readCounter)
	gui.Enabled = #lines > 0
	body.Visible = not minimized

	for index, line in lines do
		local label = Instance.new("TextLabel")
		label.Name = "Row" .. index
		label.LayoutOrder = index
		label.BackgroundTransparency = 1
		label.BorderSizePixel = 0
		label.AutomaticSize = Enum.AutomaticSize.Y
		label.Size = UDim2.new(1, 0, 0, 0)
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.TextWrapped = true
		label.Text = line.text

		if line.kind == "title" then
			label.Font = Theme.FontBold
			label.TextSize = TITLE_TEXT_SIZE
			label.TextColor3 = Theme.White
			if index > 1 then
				local padding = Instance.new("UIPadding")
				padding.PaddingTop = UDim.new(0, 8)
				padding.Parent = label
			end
		else
			label.Font = Theme.FontBody
			label.TextSize = ROW_TEXT_SIZE
			label.TextColor3 = if line.done then Theme.Muted else Theme.White
		end

		label.Parent = body
	end
end

-- Gabungkan beberapa perubahan Attribute di frame yang sama menjadi satu render.
local function queueRender()
	if renderQueued then
		return
	end
	renderQueued = true
	task.defer(render)
end

local function build()
	gui = Instance.new("ScreenGui")
	gui.Name = "QuestGui"
	gui.ResetOnSpawn = false
	gui.ScreenInsets = Enum.ScreenInsets.TopbarSafeInsets -- di bawah menu Roblox, tidak menimpa tombol bawaan
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.DisplayOrder = 5
	gui.Enabled = false

	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.AnchorPoint = Vector2.new(1, 0)
	panel.Position = UDim2.new(1, -8, 0, 8)
	panel.Size = UDim2.fromScale(0.28, 0)
	panel.AutomaticSize = Enum.AutomaticSize.Y
	panel.BackgroundColor3 = Theme.Black
	panel.BackgroundTransparency = Theme.PanelTransparency
	panel.BorderSizePixel = 0
	panel.Parent = gui

	local sizeLimit = Instance.new("UISizeConstraint")
	sizeLimit.MinSize = Vector2.new(210, 0)
	sizeLimit.MaxSize = Vector2.new(340, math.huge)
	sizeLimit.Parent = panel

	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 10)
	padding.PaddingRight = UDim.new(0, 10)
	padding.PaddingTop = UDim.new(0, 4)
	padding.PaddingBottom = UDim.new(0, 10)
	padding.Parent = panel

	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 4)
	layout.Parent = panel

	-- Header = tombol penuh (tinggi 40 px) untuk minimize/maximize.
	header = Instance.new("TextButton")
	header.Name = "Header"
	header.LayoutOrder = 0
	header.Size = UDim2.new(1, 0, 0, 40)
	header.BackgroundTransparency = 1
	header.BorderSizePixel = 0
	header.AutoButtonColor = false
	header.Font = Theme.FontBold
	header.TextSize = 17
	header.TextColor3 = Theme.White
	header.TextXAlignment = Enum.TextXAlignment.Left
	header.Parent = panel
	updateHeader()

	body = Instance.new("Frame")
	body.Name = "Body"
	body.LayoutOrder = 1
	body.BackgroundTransparency = 1
	body.BorderSizePixel = 0
	body.AutomaticSize = Enum.AutomaticSize.Y
	body.Size = UDim2.new(1, 0, 0, 0)
	body.Parent = panel

	local bodyLayout = Instance.new("UIListLayout")
	bodyLayout.SortOrder = Enum.SortOrder.LayoutOrder
	bodyLayout.Padding = UDim.new(0, 2)
	bodyLayout.Parent = body

	header.Activated:Connect(function()
		minimized = not minimized
		updateHeader()
		body.Visible = not minimized
	end)

	gui.Parent = localPlayer:WaitForChild("PlayerGui")
end

function QuestController.init()
	local folder = ReplicatedStorage:WaitForChild(QuestConfig.STATE_FOLDER, FOLDER_TIMEOUT)
	if not folder or not folder:IsA("Folder") then
		Log.warn(TAG, "folder QuestState tidak ditemukan; Quest UI tidak aktif")
		return
	end
	stateFolder = folder

	build()
	stateFolder.AttributeChanged:Connect(queueRender)
	render()

	Log.info(TAG, "siap")
end

return QuestController
