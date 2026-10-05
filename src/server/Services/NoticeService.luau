--!strict
-- NoticeService: SATU-SATUNYA jalur notifikasi ke pemain (toast). Hanya tampilan; tidak membawa keputusan gameplay.
--
-- ATURAN PROYEK (ADR-025): semua pemberitahuan gameplay lewat service ini. Termasuk:
--   pemain/rekan mendapat item, progres party, kunci/keris berpindah, knock, revive, party wipe,
--   quest selesai, pemain keluar yang memengaruhi quest, dan penolakan aksi yang perlu penjelasan.
-- Jangan membuat toast/label/print/GUI notifikasi sendiri di service atau controller lain.
-- Gunakan notifyParty agar pelaku mendapat kalimat "Kamu ..." dan rekan mendapat "<nama> ...".

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Log = require(Shared:WaitForChild("Util"):WaitForChild("Log") :: ModuleScript)
local Remotes = require(Shared:WaitForChild("Remotes") :: ModuleScript)

local TAG = "NoticeService"

local NoticeService = {}

local remote: RemoteEvent

function NoticeService.send(player: Player, text: string)
	remote:FireClient(player, text)
end

function NoticeService.broadcast(text: string)
	remote:FireAllClients(text)
end

-- Pelaku menerima selfText, semua pemain lain menerima othersText.
function NoticeService.notifyParty(actor: Player, selfText: string, othersText: string)
	for _, member in Players:GetPlayers() do
		remote:FireClient(member, if member == actor then selfText else othersText)
	end
end

function NoticeService.init()
	remote = Remotes.get(Remotes.Names.Notice)
	Log.info(TAG, "siap")
end

return table.freeze(NoticeService)
