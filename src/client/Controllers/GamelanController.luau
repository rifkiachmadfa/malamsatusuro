--!strict
-- GamelanController: GUI minigame ritme gamelan (4 kolom, gaya Guitar Hero), Phase 7 (ADR-038).
-- PC: tombol Q W E R. Mobile/mouse: ketuk kolom. Hanya tampilan dan input:
--   server membuat chart, memvalidasi tiap tekanan, dan menghitung skor akhir.
-- Penilaian di client (Perfect/Good/Miss) hanya umpan balik instan; SKOR dan hasil akhir SELALU dari server (ADR-039):
-- skor mulai 100 dan hanya turun; server mengirim "Score" tiap berubah dan "Close" bila skor < batas (gagal).
-- GUI ini hanya ada di layar pemain yang bermain; pemain lain tidak melihatnya (mereka hanya mendengar musiknya).
-- Selama bermain, Q/W/E/R "ditelan" (Sink) agar karakter tidak berjalan dan E tidak memicu interaksi lain.

local ContentProvider = game:GetService("ContentProvider")
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GamelanConfig = require(Shared:WaitForChild("Config"):WaitForChild("GamelanConfig") :: ModuleScript)
local Remotes = require(Shared:WaitForChild("Remotes") :: ModuleScript)
local Theme = require(script.Parent.Parent:WaitForChild("UI"):WaitForChild("Theme") :: ModuleScript)

local Config = GamelanConfig
local ACTION_NAME = "GamelanLanes"
local RESULT_SECONDS = 5
local LOAD_TIMEOUT = 6 -- detik menunggu musik dimuat sebelum mulai tanpa menunggu
local HIT_LINE_Y = 0.92 -- posisi garis tekan (skala tinggi area kolom)
local NOTE_HEIGHT = 0.045
local FLASH_SECONDS = 0.45

local localPlayer = Players.LocalPlayer

local GamelanController = {}

type NoteState = "PENDING" | "HIT" | "MISSED"
type NoteView = { time: number, lane: number, state: NoteState, frame: Frame? }
type Phase = "LOADING" | "PLAYING" | "WAIT" | "RESULT"

local gui: ScreenGui
local panel: Frame
local laneArea: Frame
local cancelButton: TextButton
local scoreLabel: TextLabel
local timeLabel: TextLabel
local judgementLabel: TextLabel
local comboLabel: TextLabel
local infoLabel: TextLabel
local resultLabel: TextLabel
local laneFlashes: { Frame } = {}
local actionRemote: RemoteEvent

local open = false
local phase: Phase = "LOADING"
local token = 0 -- naikkan untuk membatalkan proses async yang sedang berjalan
local notes: { NoteView } = {}
local live: { NoteView } = {} -- not yang sedang tampil
local nextSpawn = 1
local duration = 0
local clockStart = 0
local sound: Sound? = nil
local renderConnection: RBXScriptConnection? = nil
local combo = 0
local flashToken = 0

-- ===== Util GUI =====

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

local function formatTime(seconds: number): string
	local whole = math.max(0, math.ceil(seconds))
	return string.format("%d:%02d", whole // 60, whole % 60)
end

-- ===== Umpan balik =====

local function showJudgement(text: string)
	flashToken += 1
	local myToken = flashToken
	judgementLabel.Text = text
	comboLabel.Text = if combo >= 2 then string.format("x%d", combo) else ""
	task.delay(FLASH_SECONDS, function()
		if flashToken == myToken then
			judgementLabel.Text = ""
			comboLabel.Text = ""
		end
	end)
end

local function flashLane(lane: number)
	local flash = laneFlashes[lane]
	if not flash then
		return
	end
	flash.BackgroundTransparency = 0.55
	task.delay(0.1, function()
		if flash.Parent then
			flash.BackgroundTransparency = 1
		end
	end)
end

-- Skor hanya ditampilkan; nilainya dari server.
local function setScore(score: number)
	scoreLabel.Text = string.format("SKOR %d", score)
end

-- ===== Not =====

local function destroyNoteFrame(note: NoteView)
	if note.frame then
		note.frame:Destroy()
		note.frame = nil
	end
end

local function spawnNoteFrame(note: NoteView)
	local frame = Instance.new("Frame")
	frame.Name = "Note"
	frame.AnchorPoint = Vector2.new(0, 0.5)
	local laneWidth = 1 / Config.LANE_COUNT
	frame.Size = UDim2.fromScale(laneWidth * 0.84, NOTE_HEIGHT)
	frame.Position = UDim2.fromScale((note.lane - 1) * laneWidth + laneWidth * 0.08, -0.1)
	frame.BackgroundColor3 = Theme.White
	frame.BorderSizePixel = 0
	frame.Active = false
	frame.Parent = laneArea
	note.frame = frame
end

local function clearNotes()
	for _, note in notes do
		destroyNoteFrame(note)
	end
	table.clear(notes)
	table.clear(live)
	nextSpawn = 1
end

-- Tekanan pemain: nilai instan di client + kirim ke server (server yang menilai resmi).
local function press(lane: number)
	if phase ~= "PLAYING" then
		return
	end
	local songTime = os.clock() - clockStart
	flashLane(lane)
	actionRemote:FireServer({ action = "Hit", lane = lane, t = songTime })

	local best: NoteView? = nil
	local bestDelta = math.huge
	for _, note in live do
		if note.lane == lane and note.state == "PENDING" then
			local delta = math.abs(note.time - songTime)
			if delta <= Config.GOOD_WINDOW and delta < bestDelta then
				best = note
				bestDelta = delta
			end
		end
	end
	if not best then
		return
	end

	best.state = "HIT"
	destroyNoteFrame(best)
	combo += 1
	showJudgement(if bestDelta <= Config.PERFECT_WINDOW then "PERFECT" else "GOOD")
end

-- ===== Loop render =====

local function stopRender()
	if renderConnection then
		renderConnection:Disconnect()
		renderConnection = nil
	end
end

local function onRender()
	if phase ~= "PLAYING" and phase ~= "WAIT" then
		return
	end
	local songTime = os.clock() - clockStart

	-- Munculkan not yang masuk jendela approach.
	while notes[nextSpawn] and notes[nextSpawn].time - songTime <= Config.APPROACH_SECONDS do
		local note = notes[nextSpawn]
		spawnNoteFrame(note)
		table.insert(live, note)
		nextSpawn += 1
	end

	for i = #live, 1, -1 do
		local note = live[i]
		if note.state == "PENDING" and songTime - note.time > Config.GOOD_WINDOW then
			note.state = "MISSED"
			combo = 0
			showJudgement("MISS")
			if note.frame then
				note.frame.BackgroundTransparency = 0.7
			end
		end

		local frame = note.frame
		if frame then
			local y = HIT_LINE_Y - (note.time - songTime) / Config.APPROACH_SECONDS * HIT_LINE_Y
			frame.Position = UDim2.new(frame.Position.X, UDim.new(y, 0))
			if y > 1.06 then
				destroyNoteFrame(note)
			end
		end
		if note.frame == nil then
			table.remove(live, i)
		end
	end

	if phase == "PLAYING" then
		timeLabel.Text = formatTime(duration - songTime)
		if songTime >= duration then
			phase = "WAIT"
			timeLabel.Text = "0:00"
			infoLabel.Text = "Menghitung skor..."
			cancelButton.Visible = false
		end
	end
end

-- ===== Input =====

local function bindKeys()
	ContextActionService:BindActionAtPriority(
		ACTION_NAME,
		function(_name: string, state: Enum.UserInputState, input: InputObject): Enum.ContextActionResult
			if state == Enum.UserInputState.Begin then
				local lane = table.find(Config.LANE_KEYCODES :: { Enum.KeyCode }, input.KeyCode)
				if lane then
					press(lane)
				end
			end
			return Enum.ContextActionResult.Sink
		end,
		false,
		Enum.ContextActionPriority.High.Value,
		table.unpack(Config.LANE_KEYCODES :: { Enum.KeyCode })
	)
end

local function unbindKeys()
	ContextActionService:UnbindAction(ACTION_NAME)
end

-- ===== Alur sesi =====

local function stopSound()
	if sound then
		sound:Stop()
		sound:Destroy()
		sound = nil
	end
end

local function closeLocal()
	if not open then
		return
	end
	open = false
	token += 1
	stopRender()
	unbindKeys()
	stopSound()
	clearNotes()
	gui.Enabled = false
end

local function cancel()
	if not open or phase == "RESULT" then
		return
	end
	actionRemote:FireServer({ action = "Cancel" })
	closeLocal()
end

-- Musik siap (atau timeout): mulai jam sesi, putar musik, beri tahu server.
local function beginPlaying(myToken: number)
	if token ~= myToken or phase ~= "LOADING" then
		return
	end
	phase = "PLAYING"
	clockStart = os.clock()
	if sound then
		sound:Play()
	end
	actionRemote:FireServer({ action = "Ready" })
	local touchOnly = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
	infoLabel.Text = if touchOnly
		then string.format("Ketuk kolom tepat waktu. Jaga skor di atas %d!", Config.REQUIRED_SCORE)
		else string.format("Tekan Q W E R (atau klik kolom) tepat waktu. Jaga skor di atas %d!", Config.REQUIRED_SCORE)
	stopRender()
	renderConnection = RunService.RenderStepped:Connect(onRender)
end

local function prepareSound(): Sound?
	local id = Config.SOUND_ID
	if id == "" or id == "rbxassetid://0" then
		return nil
	end
	local created = Instance.new("Sound")
	created.Name = "GamelanMusic"
	created.SoundId = id
	created.Volume = Config.SOUND_VOLUME
	created.Looped = false
	created.Parent = gui
	return created
end

local function readNotes(value: unknown): { NoteView }?
	if typeof(value) ~= "table" then
		return nil
	end
	local result: { NoteView } = {}
	for _, entry in value :: { any } do
		if typeof(entry) ~= "table" or typeof(entry[1]) ~= "number" or typeof(entry[2]) ~= "number" then
			return nil
		end
		table.insert(result, { time = entry[1], lane = entry[2], state = "PENDING", frame = nil })
	end
	table.sort(result, function(a: NoteView, b: NoteView)
		return a.time < b.time
	end)
	return result
end

local function onStart(data: { [string]: any })
	local newNotes = readNotes(data.notes)
	local newDuration = data.duration
	local startScore = data.score
	if not newNotes or typeof(newDuration) ~= "number" or typeof(startScore) ~= "number" then
		return
	end
	if open then
		closeLocal()
	end

	clearNotes()
	notes = newNotes
	duration = newDuration
	combo = 0
	setScore(startScore)
	judgementLabel.Text = ""
	comboLabel.Text = ""
	resultLabel.Text = ""
	timeLabel.Text = formatTime(duration)
	infoLabel.Text = "Memuat musik..."
	cancelButton.Visible = true

	open = true
	phase = "LOADING"
	token += 1
	local myToken = token
	gui.Enabled = true
	bindKeys()

	sound = prepareSound()
	local created = sound
	if created == nil then
		-- Musik belum dipasang (placeholder): lanjut tanpa suara.
		task.defer(beginPlaying, myToken)
		return
	end

	task.spawn(function()
		pcall(function()
			ContentProvider:PreloadAsync({ created })
		end)
		beginPlaying(myToken)
	end)
	task.delay(LOAD_TIMEOUT, function()
		beginPlaying(myToken) -- tidak berefek bila sudah mulai
	end)
end

local function onResult(data: { [string]: any })
	if not open then
		return
	end
	local score = data.score
	local perfect = data.perfect
	local good = data.good
	local miss = data.miss
	if
		typeof(score) ~= "number"
		or typeof(perfect) ~= "number"
		or typeof(good) ~= "number"
		or typeof(miss) ~= "number"
	then
		closeLocal()
		return
	end

	token += 1
	local myToken = token
	phase = "RESULT"
	stopRender()
	unbindKeys() -- tombol bebas lagi (hasil tampil beberapa detik)
	stopSound()
	clearNotes()
	cancelButton.Visible = false
	judgementLabel.Text = ""
	comboLabel.Text = ""
	scoreLabel.Text = string.format("SKOR %d", score)
	timeLabel.Text = ""

	-- Gagal (skor < batas) tidak lewat sini: server mengirim "Close" lalu jumpscare. Result hanya untuk sesi yang bertahan.
	if data.rewarded == true then
		resultLabel.Text = "KAIN KAFAN DIDAPAT"
	elseif data.passed == true then
		resultLabel.Text = "TERJADI MASALAH"
	else
		resultLabel.Text = "GAGAL"
	end
	infoLabel.Text = string.format("Perfect %d   Good %d   Miss %d", perfect, good, miss)

	task.delay(RESULT_SECONDS, function()
		if token == myToken then
			closeLocal()
		end
	end)
end

local function onUpdate(raw: unknown)
	if typeof(raw) ~= "table" then
		return
	end
	local data = raw :: { [string]: any }
	if data.action == "Start" then
		onStart(data)
	elseif data.action == "Score" then
		if open and typeof(data.score) == "number" then
			setScore(data.score)
		end
	elseif data.action == "Result" then
		onResult(data)
	elseif data.action == "Close" then
		closeLocal()
	end
end

-- ===== Bangun GUI =====

local function build()
	gui = Instance.new("ScreenGui")
	gui.Name = "GamelanGui"
	gui.ResetOnSpawn = false
	gui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.DisplayOrder = 20
	gui.Enabled = false

	local overlay = Instance.new("Frame")
	overlay.Name = "Overlay"
	overlay.Size = UDim2.fromScale(1, 1)
	overlay.BackgroundColor3 = Theme.Black
	overlay.BackgroundTransparency = 0.35
	overlay.BorderSizePixel = 0
	overlay.Active = true -- menahan ketukan agar tidak tembus ke dunia
	overlay.Parent = gui

	panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromScale(0.9, 0.96)
	panel.BackgroundColor3 = Theme.Black
	panel.BackgroundTransparency = 0.1
	panel.BorderSizePixel = 0
	panel.Parent = overlay

	local ratio = Instance.new("UIAspectRatioConstraint")
	ratio.AspectRatio = 0.8
	ratio.AspectType = Enum.AspectType.FitWithinMaxSize
	ratio.DominantAxis = Enum.DominantAxis.Width
	ratio.Parent = panel

	-- Header: BATAL | SKOR | WAKTU
	cancelButton = Instance.new("TextButton")
	cancelButton.Name = "Cancel"
	cancelButton.Position = UDim2.fromScale(0.04, 0.012)
	cancelButton.Size = UDim2.fromScale(0.2, 0.06)
	cancelButton.BackgroundColor3 = Theme.White
	cancelButton.BorderSizePixel = 0
	cancelButton.Font = Theme.FontBold
	cancelButton.TextColor3 = Theme.Black
	cancelButton.TextScaled = true
	cancelButton.Text = "BATAL"
	cancelButton.Parent = panel
	addTextConstraint(cancelButton, 10, 18)
	cancelButton.Activated:Connect(cancel)

	scoreLabel = makeLabel("Score", Theme.FontBold, panel)
	scoreLabel.Position = UDim2.fromScale(0.28, 0.012)
	scoreLabel.Size = UDim2.fromScale(0.38, 0.06)
	addTextConstraint(scoreLabel, 12, 24)

	timeLabel = makeLabel("Time", Theme.FontBold, panel)
	timeLabel.TextXAlignment = Enum.TextXAlignment.Right
	timeLabel.Position = UDim2.fromScale(0.7, 0.012)
	timeLabel.Size = UDim2.fromScale(0.26, 0.06)
	addTextConstraint(timeLabel, 12, 24)

	-- Area kolom
	laneArea = Instance.new("Frame")
	laneArea.Name = "Lanes"
	laneArea.Position = UDim2.fromScale(0.04, 0.09)
	laneArea.Size = UDim2.fromScale(0.92, 0.74)
	laneArea.BackgroundColor3 = Theme.Black
	laneArea.BackgroundTransparency = 0.3
	laneArea.BorderSizePixel = 0
	laneArea.ClipsDescendants = true
	laneArea.Parent = panel

	local laneWidth = 1 / Config.LANE_COUNT
	for lane = 1, Config.LANE_COUNT do
		-- Kilatan saat kolom ditekan.
		local flash = Instance.new("Frame")
		flash.Name = "Flash" .. lane
		flash.Position = UDim2.fromScale((lane - 1) * laneWidth, 0)
		flash.Size = UDim2.fromScale(laneWidth, 1)
		flash.BackgroundColor3 = Theme.White
		flash.BackgroundTransparency = 1
		flash.BorderSizePixel = 0
		flash.Active = false
		flash.Parent = laneArea
		laneFlashes[lane] = flash

		if lane > 1 then
			local divider = Instance.new("Frame")
			divider.Name = "Divider" .. lane
			divider.Position = UDim2.new((lane - 1) * laneWidth, 0, 0, 0)
			divider.Size = UDim2.new(0, 1, 1, 0)
			divider.BackgroundColor3 = Theme.Muted
			divider.BackgroundTransparency = 0.6
			divider.BorderSizePixel = 0
			divider.Active = false
			divider.Parent = laneArea
		end
	end

	local hitLine = Instance.new("Frame")
	hitLine.Name = "HitLine"
	hitLine.AnchorPoint = Vector2.new(0, 0.5)
	hitLine.Position = UDim2.fromScale(0, HIT_LINE_Y)
	hitLine.Size = UDim2.new(1, 0, 0, 2)
	hitLine.BackgroundColor3 = Theme.White
	hitLine.BorderSizePixel = 0
	hitLine.Active = false
	hitLine.Parent = laneArea

	judgementLabel = makeLabel("Judgement", Theme.FontBold, laneArea)
	judgementLabel.AnchorPoint = Vector2.new(0.5, 0.5)
	judgementLabel.Position = UDim2.fromScale(0.5, 0.45)
	judgementLabel.Size = UDim2.fromScale(0.8, 0.08)
	addTextConstraint(judgementLabel, 14, 32)

	comboLabel = makeLabel("Combo", Theme.FontBody, laneArea)
	comboLabel.TextColor3 = Theme.Muted
	comboLabel.AnchorPoint = Vector2.new(0.5, 0.5)
	comboLabel.Position = UDim2.fromScale(0.5, 0.53)
	comboLabel.Size = UDim2.fromScale(0.4, 0.05)
	addTextConstraint(comboLabel, 11, 20)

	resultLabel = makeLabel("Result", Theme.FontBold, laneArea)
	resultLabel.AnchorPoint = Vector2.new(0.5, 0.5)
	resultLabel.Position = UDim2.fromScale(0.5, 0.35)
	resultLabel.Size = UDim2.fromScale(0.9, 0.14)
	addTextConstraint(resultLabel, 14, 30)

	-- Tombol kolom: label tombol + area ketuk (seluruh tinggi kolom, termasuk area not).
	for lane = 1, Config.LANE_COUNT do
		local pad = Instance.new("TextButton")
		pad.Name = "Pad" .. lane
		pad.Position = UDim2.fromScale((lane - 1) * laneWidth, 0)
		pad.Size = UDim2.fromScale(laneWidth, 1)
		pad.BackgroundTransparency = 1
		pad.AutoButtonColor = false
		pad.Text = ""
		pad.ZIndex = 5
		pad.Parent = laneArea
		-- Input saat ditekan (bukan dilepas): tepat untuk ritme. Mouse dan sentuhan sama-sama didukung.
		pad.InputBegan:Connect(function(input: InputObject)
			if
				input.UserInputType == Enum.UserInputType.MouseButton1
				or input.UserInputType == Enum.UserInputType.Touch
			then
				press(lane)
			end
		end)

		local keyLabel = Instance.new("TextLabel")
		keyLabel.Name = "Key" .. lane
		keyLabel.Position = UDim2.fromScale(0.04 + (lane - 1) * laneWidth * 0.92, 0.84)
		keyLabel.Size = UDim2.fromScale(laneWidth * 0.92 - 0.01, 0.09)
		keyLabel.BackgroundColor3 = Theme.White
		keyLabel.BackgroundTransparency = 0.1
		keyLabel.BorderSizePixel = 0
		keyLabel.Font = Theme.FontBold
		keyLabel.TextColor3 = Theme.Black
		keyLabel.TextScaled = true
		keyLabel.Text = Config.LANE_LABELS[lane]
		keyLabel.Active = false
		keyLabel.Parent = panel
		addTextConstraint(keyLabel, 14, 34)
	end

	infoLabel = makeLabel("Info", Theme.FontBody, panel)
	infoLabel.TextColor3 = Theme.Muted
	infoLabel.Position = UDim2.fromScale(0.04, 0.94)
	infoLabel.Size = UDim2.fromScale(0.92, 0.045)
	addTextConstraint(infoLabel, 10, 18)

	gui.Parent = localPlayer:WaitForChild("PlayerGui")
end

function GamelanController.isOpen(): boolean
	return open
end

function GamelanController.init()
	actionRemote = Remotes.get(Remotes.Names.GamelanAction)
	build()
	Remotes.get(Remotes.Names.GamelanUpdate).OnClientEvent:Connect(onUpdate)
end

return GamelanController
