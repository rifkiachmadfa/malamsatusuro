--!strict
-- CursorUnlock: membebaskan kursor mouse saat sebuah GUI terbuka walaupun game memakai first person terkunci
-- (StarterPlayer.CameraMode = LockFirstPerson, atau zoom first person). Di mode itu Roblox mengunci mouse ke tengah
-- layar sehingga tombol GUI tidak bisa diklik. TextButton dengan Modal = true adalah mekanisme resmi Roblox untuk itu.
--
-- Pemakaian: CursorUnlock.attach(screenGui) sekali saat membangun GUI. Efeknya otomatis hanya selama ScreenGui
-- Enabled; saat GUI ditutup kursor kembali terkunci dan kamera bergerak lagi. Tidak mengubah kamera/PlayerModule.

local CursorUnlock = {}

function CursorUnlock.attach(gui: ScreenGui): TextButton
	local button = Instance.new("TextButton")
	button.Name = "CursorUnlock"
	button.Text = ""
	button.Size = UDim2.fromOffset(0, 0)
	button.BackgroundTransparency = 1
	button.BorderSizePixel = 0
	button.AutoButtonColor = false
	button.Modal = true -- inti perbaikan: membebaskan mouse selama tombol ini terlihat
	button.Selectable = false
	button.Parent = gui
	return button
end

return table.freeze(CursorUnlock)
