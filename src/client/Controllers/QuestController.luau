--!strict
-- QuestController: panel Quest di kanan atas. HANYA tampilan.
-- Sumber kebenaran = Attribute QuestSnapshot di ReplicatedStorage (ditulis server).
-- Panel bisa diminimize. Posisi di bawah topbar Roblox (TopbarSafeInsets).

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local QuestConfig = require(Shared:WaitForChild("Config"):WaitForChild("QuestConfig") :: ModuleScript)
local Theme = require(script.Parent.Parent:WaitForChild("UI"):WaitForChild("Theme") :: ModuleScript)

local HEADER_TITLE = "MALAM SURO"
local TEXT_SIZE = 14
local HEADER_HEIGHT = 40 -- target sentuh minimal

local localPlayer = Players.LocalPlayer

local QuestController = {}

local gui: ScreenGui
local body: Frame
local toggleButton: TextButton
local minimized = false

local function addLabel(text: string, font: Enum.Font, color: Color3, order: number, indent: number)
	local label = Instance.new("TextLabel")
	label.Name = "Row" .. order
	label.LayoutOrder = order
	label.BackgroundTransparency = 1
	label.BorderSizePixel = 0
	label.Size = UDim2.new(1, 0, 0, 0)
	label.AutomaticSize = Enum.AutomaticSize.Y
	label.Font = font
	label.TextSize = TEXT_SIZE
	label.TextColor3 = color
	label.TextWrapped = true
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Top
	label.Text = text

	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, indent)
	padding.Parent = label

	label.Parent = body
end

local function clearBody()
	for _, child in body:GetChildren() do
		if child:IsA("TextLabel") then
			child:Destroy()
		end
	end
end

local function render()
	local raw = ReplicatedStorage:GetAttribute(QuestConfig.ATTRIBUTE)
	clearBody()

	if typeof(raw) ~= "string" then
		gui.Enabled = false
		return
	end

	local ok, snapshot = pcall(HttpService.JSONDecode, HttpService, raw)
	if not ok or typeof(snapshot) ~= "table" or typeof(snapshot.quests) ~= "table" or #snapshot.quests == 0 then
		gui.Enabled = false
		return
	end

	local order = 0
	for _, quest in snapshot.quests do
		if typeof(quest) == "table" and typeof(quest.title) == "string" then
			order += 1
			local done = quest.done == true
			addLabel(
				(if done then "✓ " else "") .. quest.title,
				Theme.FontBold,
				if done then Theme.Muted else Theme.White,
				order,
				0
			)

			if not done and typeof(quest.objectives) == "table" then
				for _, objective in quest.objectives do
					if typeof(objective) == "table" and typeof(objective.label) == "string" then
						order += 1
						local text = objective.label
						if typeof(objective.target) == "number" then
							text ..= string.format(" %d/%d", objective.current or 0, objective.target)
						end
						local objectiveDone = objective.done == true
						addLabel(
							(if objectiveDone then "✓ " else "○ ") .. text,
							Theme.FontBody,
							if objectiveDone then Theme.Muted else Theme.White,
							order,
							8
						)
					end
				end
			end
		end
	end

	gui.Enabled = true
end

local function applyMinimized()
	body.Visible = not minimized
	toggleButton.Text = HEADER_TITLE .. (if minimized then "  [+]" else "  [–]")
end

local function build()
	gui = Instance.new("ScreenGui")
	gui.Name = "QuestGui"
	gui.ResetOnSpawn = false
	gui.ScreenInsets = Enum.ScreenInsets.TopbarSafeInsets
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.DisplayOrder = 5
	gui.Enabled = false

	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.AnchorPoint = Vector2.new(1, 0)
	panel.Position = UDim2.new(1, -8, 0, 8)
	panel.Size = UDim2.fromScale(0.3, 0)
	panel.AutomaticSize = Enum.AutomaticSize.Y
	panel.BackgroundColor3 = Theme.Black
	panel.BackgroundTransparency = Theme.PanelTransparency
	panel.BorderSizePixel = 0
	panel.Parent = gui

	local sizeLimit = Instance.new("UISizeConstraint")
	sizeLimit.MinSize = Vector2.new(190, 0)
	sizeLimit.MaxSize = Vector2.new(300, math.huge)
	sizeLimit.Parent = panel

	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 10)
	padding.PaddingRight = UDim.new(0, 10)
	padding.PaddingBottom = UDim.new(0, 8)
	padding.Parent = panel

	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 4)
	layout.Parent = panel

	toggleButton = Instance.new("TextButton")
	toggleButton.Name = "Header"
	toggleButton.LayoutOrder = 0
	toggleButton.Size = UDim2.new(1, 0, 0, HEADER_HEIGHT)
	toggleButton.BackgroundTransparency = 1
	toggleButton.BorderSizePixel = 0
	toggleButton.AutoButtonColor = false
	toggleButton.Font = Theme.FontBold
	toggleButton.TextSize = 16
	toggleButton.TextColor3 = Theme.White
	toggleButton.TextXAlignment = Enum.TextXAlignment.Left
	toggleButton.Text = HEADER_TITLE
	toggleButton.Parent = panel

	body = Instance.new("Frame")
	body.Name = "Body"
	body.LayoutOrder = 1
	body.Size = UDim2.new(1, 0, 0, 0)
	body.AutomaticSize = Enum.AutomaticSize.Y
	body.BackgroundTransparency = 1
	body.BorderSizePixel = 0
	body.Parent = panel

	local bodyLayout = Instance.new("UIListLayout")
	bodyLayout.SortOrder = Enum.SortOrder.LayoutOrder
	bodyLayout.Padding = UDim.new(0, 3)
	bodyLayout.Parent = body

	toggleButton.Activated:Connect(function()
		minimized = not minimized
		applyMinimized()
	end)

	applyMinimized()
	gui.Parent = localPlayer:WaitForChild("PlayerGui")
end

function QuestController.init()
	build()
	ReplicatedStorage:GetAttributeChangedSignal(QuestConfig.ATTRIBUTE):Connect(render)
	render() -- state yang sudah ada saat pemain join belakangan
end

return table.freeze(QuestController)