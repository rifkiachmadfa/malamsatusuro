--!strict
-- KnockConfig: pengaturan state knock (Phase 6, Task 6.1). SISI SERVER.
-- Penyebab knock = string `reason`; tambah penyebab baru di sini (mis. GHOST saat hantu penyerang dibuat).

local KnockConfig = {}

-- Penyebab knock. GHOST belum dipakai (serangan hantu belum dibuat; lihat TASKS Phase 6 "Catatan masa depan").
KnockConfig.Reason = table.freeze({
	WRONG_FLOWER = "WRONG_FLOWER", -- bunga salah di makam (quest Kantil)
	GHOST = "GHOST", -- RESERVED: diserang hantu
})

-- Pose berbaring (telentang, menghadap atas). Posisi dihitung dari lantai di bawah pemain (raycast).
KnockConfig.FLOOR_RAY_LENGTH = 12 -- studs ke bawah dari HumanoidRootPart
KnockConfig.LIE_HEIGHT = 0.6 -- tinggi pusat HumanoidRootPart dari lantai saat berbaring
KnockConfig.FALLBACK_DROP = 2.2 -- turun sekian studs jika raycast tidak menemukan lantai

return table.freeze(KnockConfig)
