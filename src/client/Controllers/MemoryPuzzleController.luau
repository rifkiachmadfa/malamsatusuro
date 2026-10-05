--!strict
-- MemoryPuzzleController: GUI minigame ingat-dan-susun suku kata (HA NA CA RA KA).
-- Hanya tampilan dan input (ketuk/klik, jalan di PC dan mobile). Soal, waktu, dan penilaian milik server;
-- client mengirim jawaban dan menampilkan hasil dari server.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes") :: ModuleScript)
local Theme = require(script.Parent.Parent:WaitForChild("UI"):WaitForChild("Theme") :: ModuleScript)

local RESULT_SECONDS = 1.8
local TILE_FILLED = Color3.fromRGB(255, 255, 255)
local TILE_EMPTY = Color3.fromRGB(45, 45, 45)

local localPlayer = Players.LocalPlayer

local MemoryPuzzleController = {}

type Phase = "MEMORIZE" | "ANSWER" | "WAIT" | "RESULT"

local gui: ScreenGui
local titleLabel: TextLabel
local infoLabel: TextLabel
local slotsRow: Frame
local poolRow: Frame
local cancelButton: TextButton
local checkButton: TextButton
local actionRemote: RemoteEvent

local open = false
local phase: Phase = "MEMORIZE"
local token = 0 -- naikkan untuk membatalkan timer yang sedang berjalan
local sequence: { string } = {}
local poolOrder: { string } = {}
local slots: { [number]: string? } = {}

local function addTextConstraint(label: GuiObject, minSize: number, maxSize: number)
	local constraint = Instance.new("UITextSizeConstraint")
	constraint.MinTextSize = minSize
	constraint.MaxTextSize = maxSize
	constraint.Parent = label
end

local function makeLabel(name: string, font: Enum.Font, parent: Instance): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.BorderSizePixel = 0
	label.Font = font
	label.TextColor3 = Theme.White
	label.TextScaled = true
	label.TextWrapped = true
	label.Text = ""
	label.Parent = parent
	return label
end

local function makeRow(name: string, position: UDim2, parent: Instance): Frame
	local row = Instance.new("Frame")
	row.Name = name
	row.BackgroundTransparency = 1
	row.BorderSizePixel = 0
	row.Position = position
	row.Size = UDim2.fromScale(0.92, 0.2)
	row.Parent = parent

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0.02, 0)
	layout.Parent = row
	return row
end

local function makeButton(name: string, text: string, position: UDim2, parent: Instance): TextButton
	local button = Instance.new("TextButton")
	button.Name = name
	button.Position = position
	button.Size = UDim2.fromScale(0.3, 0.13)
	button.BackgroundColor3 = Theme.White
	button.BorderSizePixel = 0
	button.AutoButtonColor = true
	button.Font = Theme.FontBold
	button.TextColor3 = Theme.Black
	button.TextScaled = true
	button.Text = text
	button.Parent = parent
	addTextConstraint(button, 11, 20)
	return button
end

local function makeTile(parent: Instance, text: string, filled: boolean, order: number): TextButton
	local tile = Instance.new("TextButton")
	tile.Name = "Tile" .. order
	tile.LayoutOrder = order
	tile.Size = UDim2.fromScale(0.17, 0.95)
	tile.BorderSizePixel = 0
	tile.AutoButtonColor = filled
	tile.BackgroundColor3 = if filled then TILE_FILLED else TILE_EMPTY
	tile.Font = Theme.FontBold
	tile.TextColor3 = if filled then Theme.Black else Theme.Muted
	tile.TextScaled = true
	tile.Text = text
	tile.Parent = parent
	addTextConstraint(tile, 12, 34)
	return tile
end

local function clearRow(row: Frame)
	for _, child in row:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

local function allFilled(): boolean
	for i = 1, #sequence do
		if slots[i] == nil then
			return false
		end
	end
	return true
end

local renderAnswer: () -> ()

local function placeSyllable(syllable: string)
	if phase ~= "ANSWER" then
		return
	end
	for i = 1, #sequence do
		if slots[i] == nil then
			slots[i] = syllable
			renderAnswer()
			return
		end
	end
end

local function removeFromSlot(index: number)
	if phase ~= "ANSWER" or slots[index] == nil then
		return
	end
	slots[index] = nil
	renderAnswer()
end

-- Fase jawab: slot (bisa diketuk untuk mengembalikan) + sisa suku kata di bawahnya.
function renderAnswer()
	clearRow(slotsRow)
	clearRow(poolRow)

	for i = 1, #sequence do
		local value = slots[i]
		local tile = makeTile(slotsRow, value or tostring(i), value ~= nil, i)
		tile.Activated:Connect(function()
			removeFromSlot(i)
		end)
	end

	for order, syllable in poolOrder do
		local used = false
		for i = 1, #sequence do
			if slots[i] == syllable then
				used = true
				break
			end
		end
		if not used then
			local tile = makeTile(poolRow, syllable, true, order)
			tile.Activated:Connect(function()
				placeSyllable(syllable)
			end)
		end
	end

	checkButton.Visible = allFilled()
end

local function closeLocal()
	if not open then
		return
	end
	open = false
	token += 1
	gui.Enabled = false
end

local function runCountdown(seconds: number, prefix: string, myToken: number, onDone: () -> ())
	task.spawn(function()
		local deadline = os.clock() + seconds
		while token == myToken do
			local remaining = deadline - os.clock()
			if remaining <= 0 then
				break
			end
			infoLabel.Text = string.format("%s %d", prefix, math.ceil(remaining))
			task.wait(0.1)
		end
		if token == myToken then
			onDone()
		end
	end)
end

local function startAnswer(answerSeconds: number)
	token += 1
	local myToken = token
	phase = "ANSWER"
	slots = {}
	titleLabel.Text = "SUSUN URUTANNYA"
	renderAnswer()
	runCountdown(answerSeconds, "Sisa waktu:", myToken, function()
		infoLabel.Text = "Waktu habis"
	end)
end

local function startMemorize(memorizeSeconds: number, answerSeconds: number)
	token += 1
	local myToken = token
	phase = "MEMORIZE"
	titleLabel.Text = "INGAT URUTAN INI"
	checkButton.Visible = false
	clearRow(poolRow)
	clearRow(slotsRow)
	for i, syllable in sequence do
		makeTile(slotsRow, syllable, true, i).AutoButtonColor = false
	end
	runCountdown(memorizeSeconds, "Hafalkan:", myToken, function()
		startAnswer(answerSeconds)
	end)
end

local function submit()
	if phase ~= "ANSWER" or not allFilled() then
		return
	end
	local answer: { string } = {}
	for i = 1, #sequence do
		answer[i] = slots[i] :: string
	end

	phase = "WAIT"
	token += 1
	checkButton.Visible = false
	infoLabel.Text = "Memeriksa..."
	actionRemote:FireServer({ action = "Submit", answer = answer })
end

local function cancel()
	if not open then
		return
	end
	actionRemote:FireServer({ action = "Cancel" })
	closeLocal()
end

local function readStringList(value: unknown): { string }?
	if typeof(value) ~= "table" then
		return nil
	end
	local list: { string } = {}
	for _, item in value :: { any } do
		if typeof(item) ~= "string" then
			return nil
		end
		table.insert(list, item)
	end
	return list
end

local function onUpdate(raw: unknown)
	if typeof(raw) ~= "table" then
		return
	end
	local data = raw :: { [string]: any }

	if data.action == "Start" then
		local newSequence = readStringList(data.sequence)
		local syllables = readStringList(data.syllables)
		local memorizeSeconds = data.memorizeSeconds
		local answerSeconds = data.answerSeconds
		if
			not newSequence
			or not syllables
			or typeof(memorizeSeconds) ~= "number"
			or typeof(answerSeconds) ~= "number"
		then
			return
		end

		sequence = newSequence
		poolOrder = table.clone(syllables)
		for i = #poolOrder, 2, -1 do -- urutan pilihan diacak (hanya tampilan)
			local j = math.random(1, i)
			poolOrder[i], poolOrder[j] = poolOrder[j], poolOrder[i]
		end

		open = true
		gui.Enabled = true
		cancelButton.Visible = true
		startMemorize(memorizeSeconds, answerSeconds)
	elseif data.action == "Result" then
		if not open then
			return
		end
		token += 1
		local myToken = token
		phase = "RESULT"
		checkButton.Visible = false
		cancelButton.Visible = false
		if data.success == true then
			titleLabel.Text = "PETI TERBUKA"
			infoLabel.Text = "Keris Pusaka ada di tanganmu."
		elseif data.correct == true then
			titleLabel.Text = "TERJADI MASALAH"
			infoLabel.Text = "Coba buka peti lagi."
		else
			titleLabel.Text = "URUTAN SALAH"
			infoLabel.Text = "Buka peti lagi untuk mencoba kembali."
		end
		task.delay(RESULT_SECONDS, function()
			if token == myToken then
				closeLocal()
			end
		end)
	elseif data.action == "Close" then
		closeLocal()
	end
end

local function build()
	gui = Instance.new("ScreenGui")
	gui.Name = "MemoryPuzzleGui"
	gui.ResetOnSpawn = false
	gui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.DisplayOrder = 20
	gui.Enabled = false

	local overlay = Instance.new("Frame")
	overlay.Name = "Overlay"
	overlay.Size = UDim2.fromScale(1, 1)
	overlay.BackgroundColor3 = Theme.Black
	overlay.BackgroundTransparency = 0.4
	overlay.BorderSizePixel = 0
	overlay.Active = true -- menahan ketukan agar tidak tembus ke dunia
	overlay.Parent = gui

	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromScale(0.82, 0.86)
	panel.BackgroundColor3 = Theme.Black
	panel.BackgroundTransparency = 0.1
	panel.BorderSizePixel = 0
	panel.Parent = overlay

	local sizeLimit = Instance.new("UISizeConstraint")
	sizeLimit.MaxSize = Vector2.new(600, 420)
	sizeLimit.Parent = panel

	titleLabel = makeLabel("Title", Theme.FontBold, panel)
	titleLabel.Position = UDim2.fromScale(0.04, 0.03)
	titleLabel.Size = UDim2.fromScale(0.92, 0.12)
	addTextConstraint(titleLabel, 14, 28)

	infoLabel = makeLabel("Info", Theme.FontBody, panel)
	infoLabel.TextColor3 = Theme.Muted
	infoLabel.Position = UDim2.fromScale(0.04, 0.16)
	infoLabel.Size = UDim2.fromScale(0.92, 0.08)
	addTextConstraint(infoLabel, 11, 18)

	slotsRow = makeRow("Slots", UDim2.fromScale(0.04, 0.27), panel)
	poolRow = makeRow("Pool", UDim2.fromScale(0.04, 0.54), panel)

	cancelButton = makeButton("Cancel", "BATAL", UDim2.fromScale(0.04, 0.82), panel)
	cancelButton.Activated:Connect(cancel)

	checkButton = makeButton("Check", "PERIKSA", UDim2.fromScale(0.66, 0.82), panel)
	checkButton.Activated:Connect(submit)

	gui.Parent = localPlayer:WaitForChild("PlayerGui")
end

function MemoryPuzzleController.isOpen(): boolean
	return open
end

function MemoryPuzzleController.init()
	actionRemote = Remotes.get(Remotes.Names.MemoryPuzzleAction)
	build()
	Remotes.get(Remotes.Names.MemoryPuzzleUpdate).OnClientEvent:Connect(onUpdate)
end

return MemoryPuzzleController
