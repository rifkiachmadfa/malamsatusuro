--!strict
-- Remotes: satu-satunya tempat membuat dan mengambil RemoteEvent.
-- Server memanggil Remotes.init() sekali saat boot.
-- Server dan client mengambil remote lewat Remotes.get(Remotes.Names.X).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local FOLDER_NAME = "Remotes"
local WAIT_TIMEOUT = 10

local Remotes = {}

-- Daftar nama remote. Tambahkan di sini saat sistem barunya dibuat.
Remotes.Names = table.freeze({
	DebugPing = "DebugPing", -- SEMENTARA: hanya untuk tes Task 1.4, hapus di akhir Phase 1
})

-- Server only: buat folder dan semua RemoteEvent (aman dipanggil ulang).
function Remotes.init()
	assert(RunService:IsServer(), "Remotes.init hanya boleh dipanggil di server")

	local existing = ReplicatedStorage:FindFirstChild(FOLDER_NAME)
	local folder: Instance
	if existing then
		folder = existing
	else
		local created = Instance.new("Folder")
		created.Name = FOLDER_NAME
		created.Parent = ReplicatedStorage
		folder = created
	end

	for _, name in Remotes.Names do
		if not folder:FindFirstChild(name) then
			local remote = Instance.new("RemoteEvent")
			remote.Name = name
			remote.Parent = folder
		end
	end
end

-- Server dan client: ambil RemoteEvent berdasarkan nama.
function Remotes.get(name: string): RemoteEvent
	local folder = ReplicatedStorage:WaitForChild(FOLDER_NAME, WAIT_TIMEOUT)
	assert(folder, "Folder Remotes tidak ditemukan (apakah Remotes.init sudah dipanggil di server?)")

	local remote = folder:WaitForChild(name, WAIT_TIMEOUT)
	assert(remote and remote:IsA("RemoteEvent"), "RemoteEvent tidak ditemukan: " .. name)

	return remote :: RemoteEvent
end

return table.freeze(Remotes)