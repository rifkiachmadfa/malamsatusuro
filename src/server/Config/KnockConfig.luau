--!strict
-- KnockConfig: pengaturan state knock (Phase 6, Task 6.1). SISI SERVER.
-- Penyebab knock = string `reason`; tambah penyebab baru di sini (mis. GHOST saat hantu penyerang dibuat).

local KnockConfig = {}

-- Penyebab knock/gagal. Satu penyebab per hantu (ADR-048) agar jumpscare dan kebijakan hukuman bisa dibedakan per hantu.
KnockConfig.Reason = table.freeze({
	WRONG_FLOWER = "WRONG_FLOWER", -- bunga salah di makam (quest Kantil)
	GHOST = "GHOST", -- RESERVED: hantu umum (belum dipakai; hantu nyata memakai alasan per hantu di bawah)
	GHOST_POCONG = "GHOST_POCONG", -- ditangkap Pocong (quest Kantil, memegang bunga); jumpscare lalu knock lewat FailureService
	GHOST_KUNTILANAK = "GHOST_KUNTILANAK", -- ditangkap Kuntilanak (quest Keris, Daun Kelor); dipakai GhostConfig.Ghosts.Kuntilanak.failureReason
})

-- Pose berbaring (telentang, menghadap atas). Posisi dihitung dari lantai di bawah pemain (raycast).
KnockConfig.FLOOR_RAY_LENGTH = 12 -- studs ke bawah dari HumanoidRootPart
KnockConfig.LIE_HEIGHT = 0.6 -- tinggi pusat HumanoidRootPart dari lantai saat berbaring
KnockConfig.FALLBACK_DROP = 2.2 -- turun sekian studs jika raycast tidak menemukan lantai

return table.freeze(KnockConfig)
