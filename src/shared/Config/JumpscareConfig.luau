--!strict
-- JumpscareConfig: definisi jumpscare (Phase 6, Task 6.2, ADR-031/033). Dipakai server (durasi) dan client (tampilan).
-- Model hantu: ServerStorage/GhostModels/<modelName>. Server menyalinnya saat boot ke
-- ReplicatedStorage/GhostModels agar client bisa membuat ViewportFrame.
-- Tambah hantu baru = tambah satu entri di Ghosts (model + animasi), tanpa mengubah kode.

export type GhostDef = {
	modelName: string, -- nama Model di ServerStorage/GhostModels
	animationId: string, -- animasi R15 yang diputar pada model di layar
	duration: number, -- detik total jumpscare (server menunggu selama ini sebelum hukuman)
	yawOffset: number, -- derajat; putar model jika wajahnya tidak menghadap kamera (mis. 180)
	fov: number,
	-- Jarak kamera dari kepala, dalam kelipatan tinggi model (agar tidak tergantung skala model).
	distanceStartScale: number, -- awal (jauh)
	distanceEndScale: number, -- akhir lonjakan (dekat)
	lungeTime: number, -- detik lonjakan dari jauh ke dekat
	lookOffsetScale: number, -- geser titik bidik vertikal (kelipatan tinggi model, negatif = ke bawah)
	shake: number, -- amplitudo goyang layar (pixel)
	flashTime: number, -- detik kilat putih di awal
	fadeOutTime: number, -- detik layar menggelap di akhir
	soundId: string, -- diputar saat jumpscare di client pemain itu; "" = tanpa suara; ganti ke rbxassetid://...
	soundVolume: number,
}

local JumpscareConfig = {}

JumpscareConfig.SOURCE_FOLDER = "GhostModels" -- di ServerStorage
JumpscareConfig.MODEL_FOLDER = "GhostModels" -- di ReplicatedStorage (salinan untuk client)

JumpscareConfig.Ghosts = table.freeze({
	Pocong = {
		modelName = "Pocong",
		animationId = "rbxassetid://121504540587696",
		duration = 2.0,
		yawOffset = 0,
		fov = 70,
		distanceStartScale = 1.6,
		distanceEndScale = 0.6,
		lungeTime = 0.35,
		lookOffsetScale = 0,
		shake = 14,
		flashTime = 0.25,
		fadeOutTime = 0.3,
		soundId = "rbxasset://sounds/bass.mp3", -- PLACEHOLDER (suara bawaan Roblox): ganti dengan aset jumpscare asli
		soundVolume = 1,
	} :: GhostDef,
} :: { [string]: GhostDef })

return table.freeze(JumpscareConfig)
